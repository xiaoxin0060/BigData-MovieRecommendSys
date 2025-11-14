package com.yourorg.recsys.batch;

import com.yourorg.recsys.util.Config;
import com.yourorg.recsys.util.JdbcUtils;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.ml.recommendation.ALS;
import org.apache.spark.ml.recommendation.ALSModel;
import org.apache.spark.sql.*;
 
import org.apache.spark.sql.expressions.WindowSpec;
import org.apache.spark.sql.types.DataTypes;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.Properties;
import java.text.SimpleDateFormat;
import java.util.Date;

import static org.apache.spark.sql.functions.*;

public class BatchAlsJob {
    private static final Logger log = LoggerFactory.getLogger(BatchAlsJob.class);

    public static void main(String[] args) {
        String configPath = "application.yaml";
        for (int i = 0; i < args.length - 1; i++) {
            if ("--config".equals(args[i])) {
                configPath = args[i + 1];
            }
        }

        Config cfg = new Config(configPath);

        SparkSession spark = SparkSession.builder()
                .appName("BatchAlsJob")
                .getOrCreate();
        // JavaSparkContext jsc = JavaSparkContext.fromSparkContext(spark.sparkContext());
        spark.sqlContext().setConf("spark.sql.shuffle.partitions",
                String.valueOf(cfg.getInt("spark.shufflePartitions", 200)));

        // MySQL connection props for Spark JDBC
        String host = cfg.getString("mysql.host", "127.0.0.1");
        int port = cfg.getInt("mysql.port", 3306);
        String db = cfg.getString("mysql.database", "movie");
        String user = cfg.getString("mysql.user", "root");
        String pwd = cfg.getString("mysql.password", "root_password");
        String params = cfg.getString("mysql.params", "useSSL=false&serverTimezone=UTC");
        String jdbcUrl = String.format("jdbc:mysql://%s:%d/%s?%s", host, port, db, params);
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", pwd);

        // Read rating table with optimized sampling for limited-memory clusters
        // Strategy: hash-based user sampling + optional popular item coverage
        int sampleModBase = cfg.getInt("als.sampleUserModBase", 100);
        int sampleModKeep = cfg.getInt("als.sampleUserModKeep", 40);
        int includeTopK = cfg.getInt("als.includeTopPopularK", 5000);
        int readPartitions = cfg.getInt("als.readPartitions", 40);
        int userIdUpperBound = cfg.getInt("als.partitionUpperBound", 5000000);

        String popularClause = includeTopK > 0
                ? " OR movieId IN (SELECT movieId FROM (SELECT movieId FROM rating GROUP BY movieId ORDER BY COUNT(*) DESC LIMIT " + includeTopK + ") AS popular)"
                : "";
        String samplingQuery = "(SELECT userId, movieId, rating, timestamp " +
                "FROM rating " +
                "WHERE (MOD(userId, " + sampleModBase + ") < " + sampleModKeep + ")" +
                popularClause +
                ") AS rating_sample";
        
        // 🔧 Step 1: Query actual userId boundaries to avoid empty partitions
        log.info("Querying actual userId range for optimal partitioning...");
        String boundsQuery = "(SELECT MIN(userId) as minId, MAX(userId) as maxId FROM rating " +
                "WHERE (MOD(userId, " + sampleModBase + ") < " + sampleModKeep + ")) AS bounds";
        Dataset<Row> boundsDF = spark.read().jdbc(jdbcUrl, boundsQuery, props);
        Row bounds = boundsDF.first();
        long actualMin = bounds.isNullAt(0) ? 0 : bounds.getLong(0);
        long actualMax = bounds.isNullAt(1) ? userIdUpperBound : bounds.getLong(1);
        log.info("Actual userId range: {} to {} (will use for JDBC partitioning)", actualMin, actualMax);
        
        // 🔧 Step 2: Optimized partitioned reading with actual boundaries
        // Key: More partitions = more parallelism, BUT must match actual data range
        Dataset<Row> ratings = spark.read()
                .option("numPartitions", String.valueOf(readPartitions))
                .option("partitionColumn", "userId")
                .option("lowerBound", String.valueOf(actualMin))  // 🔧 Use actual min
                .option("upperBound", String.valueOf(actualMax))  // 🔧 Use actual max
                .option("fetchsize", "10000")  // Larger fetch size for speed
                .jdbc(jdbcUrl, samplingQuery, props)
                .select(col("userId"), col("movieId"), col("rating"), col("timestamp"))
                .repartition(readPartitions, col("userId"))  // 🔧 Force uniform repartition after read
                .cache();  // Cache data in memory for iterative ALS

        if (ratings.isEmpty()) {
            log.warn("No ratings found, exiting.");
            spark.stop();
            return;
        }
        
        // Cap max ratings per user to reduce skew and memory footprint
        int maxRatingsPerUser = cfg.getInt("als.maxRatingsPerUser", 200);
        WindowSpec userWin = org.apache.spark.sql.expressions.Window
                .partitionBy("userId")
                .orderBy(col("timestamp").desc());
        Dataset<Row> ratingsCapped = ratings
                .withColumn("rn", row_number().over(userWin))
                .where(col("rn").leq(maxRatingsPerUser))
                .drop("rn");

        long totalRatings = ratingsCapped.count();
        long uniqueUsers = ratingsCapped.select("userId").distinct().count();
        long uniqueMovies = ratingsCapped.select("movieId").distinct().count();
        log.info("Loaded {} ratings from {} users and {} movies (sampled dataset)", 
                 totalRatings, uniqueUsers, uniqueMovies);

        // ALS expects int indices; cast safely and cache for performance
        Dataset<Row> training = ratingsCapped
                .withColumn("user", col("userId").cast(DataTypes.IntegerType))
                .withColumn("item", col("movieId").cast(DataTypes.IntegerType))
                .withColumn("label", col("rating").cast(DataTypes.FloatType))
                .select("user", "item", "label")
                .repartition(readPartitions)  // Repartition for better parallelism
                .cache();  // Cache training data for iterative algorithm
        
        // Trigger cache materialization
        long trainingCount = training.count();
        log.info("Training ALS model with {} ratings...", trainingCount);

        int rank = cfg.getInt("als.rank", 64);
        double regParam = Double.parseDouble(cfg.getString("als.regParam", "0.2"));
        int maxIter = cfg.getInt("als.maxIter", 15);

        ALS als = new ALS()
                .setUserCol("user")
                .setItemCol("item")
                .setRatingCol("label")
                .setImplicitPrefs(false)
                .setNonnegative(true)
                .setColdStartStrategy("drop")
                .setRank(rank)
                .setRegParam(regParam)
                .setMaxIter(maxIter)
                .setCheckpointInterval(5);  // Checkpoint every 5 iterations to avoid long lineage

        log.info("Starting ALS training (rank={}, regParam={}, maxIter={})...", rank, regParam, maxIter);
        ALSModel model = als.fit(training);
        log.info("ALS training completed successfully.");

        // Persist model and item factors for realtime backfill
        final String modelVersion = new SimpleDateFormat("yyyyMMddHHmmss").format(new Date());
        String modelBasePath = cfg.getString("als.modelBasePath", "hdfs:///apps/recsys/models/als");
        String modelPath = modelBasePath + "/" + modelVersion;
        try {
            log.info("Saving ALS model to {}", modelPath);
            model.write().overwrite().save(modelPath);
            log.info("Saving item factors to {}/item_factors", modelPath);
            model.itemFactors().write().mode(SaveMode.Overwrite).parquet(modelPath + "/item_factors");
        } catch (Exception e) {
            log.error("Failed to persist ALS model or item factors", e);
            throw new RuntimeException(e);
        }

        int topN = cfg.getInt("als.topN", 50);
        Dataset<Row> recs = model.recommendForAllUsers(topN)
                .select(col("user"), explode(col("recommendations")).as("rec"))
                .select(col("user").cast(DataTypes.LongType).as("userId"),
                        col("rec.item").cast(DataTypes.LongType).as("movieId"),
                        col("rec.rating").cast(DataTypes.DoubleType).as("score"));

        WindowSpec w = org.apache.spark.sql.expressions.Window
                .partitionBy("userId").orderBy(col("score").desc());
        Dataset<Row> ranked = recs
                .withColumn("rank", row_number().over(w))
                .withColumn("algorithm", lit("ALS"))
                .withColumn("model_version", lit(modelVersion))
                .withColumn("created_at", current_timestamp());

        // Write to MySQL recommendation via optimized batch upsert
        long recsCount = ranked.count();
        log.info("Writing {} recommendations to MySQL...", recsCount);
        
        // Force repartition and coalesce to optimal size for parallel writes
        int numWritePartitions = Math.max(40, (int)(recsCount / 50000));  // ~50k records per partition
        log.info("Repartitioning to {} partitions for parallel writing...", numWritePartitions);
        
        ranked.repartition(numWritePartitions)
                .foreachPartition(iter -> {
            JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
            Connection conn = null;
            PreparedStatement ps = null;
            try {
                conn = jdbc.getConnection();
                conn.setAutoCommit(false);
                
                // Optimize connection for batch insert
                java.sql.Statement stmt = conn.createStatement();
                stmt.execute("SET SESSION sql_log_bin = 0");  // Disable binary logging for speed
                stmt.execute("SET SESSION unique_checks = 0");  // Disable unique checks temporarily
                stmt.execute("SET SESSION foreign_key_checks = 0");  // Disable FK checks temporarily
                stmt.close();
                
                String sql = "INSERT INTO recommendation (userId, movieId, score, `rank`, algorithm, model_version, created_at) " +
                        "VALUES (?, ?, ?, ?, 'ALS', ?, ?) " +
                        "ON DUPLICATE KEY UPDATE score=VALUES(score), `rank`=VALUES(`rank`), algorithm=VALUES(algorithm), created_at=VALUES(created_at)";
                ps = conn.prepareStatement(sql);
                
                int batchSize = 0;
                while (iter.hasNext()) {
                    Row r = iter.next();
                    ps.setLong(1, r.getLong(r.fieldIndex("userId")));
                    ps.setLong(2, r.getLong(r.fieldIndex("movieId")));
                    ps.setDouble(3, r.getDouble(r.fieldIndex("score")));
                    ps.setInt(4, r.getInt(r.fieldIndex("rank")));
                    ps.setString(5, modelVersion);
                    ps.setTimestamp(6, new java.sql.Timestamp(System.currentTimeMillis()));
                    ps.addBatch();
                    batchSize++;
                    
                    // Execute batch every 5000 rows for maximum throughput
                    if (batchSize >= 5000) {
                        ps.executeBatch();
                        conn.commit();
                        batchSize = 0;
                    }
                }
                
                // Execute remaining batch
                if (batchSize > 0) {
                    ps.executeBatch();
                    conn.commit();
                }
                
                // Re-enable checks
                java.sql.Statement stmtEnd = conn.createStatement();
                stmtEnd.execute("SET SESSION unique_checks = 1");
                stmtEnd.execute("SET SESSION foreign_key_checks = 1");
                stmtEnd.close();
            } catch (Exception e) {
                if (conn != null) {
                    try { conn.rollback(); } catch (Exception ex) { /* ignore */ }
                }
                throw e;
            } finally {
                JdbcUtils.quietClose(ps);
                JdbcUtils.quietClose(conn);
            }
        });

        // After successful write, switch active_version
        try {
            JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
            Connection conn = jdbc.getConnection();
            try (PreparedStatement ps2 = conn.prepareStatement(
                    "INSERT INTO rec_model_meta (id, active_version) VALUES (1, ?) ON DUPLICATE KEY UPDATE active_version=VALUES(active_version)")) {
                ps2.setString(1, modelVersion);
                ps2.executeUpdate();
                log.info("Switched active model_version to {}", modelVersion);
            } finally {
                JdbcUtils.quietClose(conn);
            }
        } catch (Exception e) {
            log.error("Failed to update rec_model_meta", e);
            throw new RuntimeException(e);
        }

        log.info("ALS recommendations written to MySQL.");
        spark.stop();
    }
}


