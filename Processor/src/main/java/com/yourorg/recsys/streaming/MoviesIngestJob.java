package com.yourorg.recsys.streaming;

import com.yourorg.recsys.util.Config;
import com.yourorg.recsys.util.JdbcUtils;
import org.apache.spark.sql.*;
import org.apache.spark.sql.streaming.OutputMode;
import org.apache.spark.sql.streaming.StreamingQuery;
import org.apache.spark.sql.streaming.Trigger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.PreparedStatement;

import static org.apache.spark.sql.functions.*;

public class MoviesIngestJob {
    private static final Logger log = LoggerFactory.getLogger(MoviesIngestJob.class);

    public static void main(String[] args) throws Exception {
        String configPath = "application.yaml";
        for (int i = 0; i < args.length - 1; i++) {
            if ("--config".equals(args[i])) configPath = args[i + 1];
        }
        Config cfg = new Config(configPath);

        SparkSession spark = SparkSession.builder()
                .appName("MoviesIngestJob")
                .getOrCreate();
        spark.sqlContext().setConf("spark.sql.shuffle.partitions",
                String.valueOf(cfg.getInt("spark.shufflePartitions", 200)));

        String bootstrap = cfg.getString("kafka.bootstrapServers", "localhost:9092");
        String topic = cfg.getString("kafka.topicMovies", "movies");

        Dataset<Row> raw = spark
                .readStream()
                .format("kafka")
                .option("kafka.bootstrap.servers", bootstrap)
                .option("subscribe", topic)
                .option("startingOffsets", "latest")
                .load();

        Dataset<Row> json = raw.selectExpr("cast(value as string) as json");
        Dataset<Row> parsed = json.select(functions.from_json(col("json"),
                new org.apache.spark.sql.types.StructType()
                        .add("tmdbId", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("title", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("originalTitle", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("genres", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("year", org.apache.spark.sql.types.DataTypes.IntegerType)
                        .add("director", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("actors", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("description", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("posterUrl", org.apache.spark.sql.types.DataTypes.StringType)
                        .add("avgRating", org.apache.spark.sql.types.DataTypes.DoubleType)
                        .add("ratingCount", org.apache.spark.sql.types.DataTypes.IntegerType)
        ).as("data")).select("data.*");

        // 添加处理时间作为 watermark（基于 Kafka 消息时间）
        Dataset<Row> withEventTime = parsed
                .withColumn("eventTime", current_timestamp())
                .withWatermark("eventTime", "10 minutes")
                .dropDuplicates("tmdbId");

        // Upsert into MySQL movie table
        String host = cfg.getString("mysql.host", "127.0.0.1");
        int port = cfg.getInt("mysql.port", 3306);
        String db = cfg.getString("mysql.database", "movie");
        String user = cfg.getString("mysql.user", "root");
        String pwd = cfg.getString("mysql.password", "root_password");
        String params = cfg.getString("mysql.params", "useSSL=false&serverTimezone=UTC");

        StreamingQuery query = withEventTime.writeStream()
                .outputMode(OutputMode.Update())
                .trigger(Trigger.ProcessingTime("10 seconds"))
                .foreachBatch((batch, batchId) -> {
                    batch.persist();
                    log.info("Processing batch {}, count: {}", batchId, batch.count());
                    
                    batch.foreachPartition(iter -> {
                        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
                        Connection conn = null;
                        PreparedStatement upsert = null;
                        try {
                            conn = jdbc.getConnection();
                            conn.setAutoCommit(false);
                            
                            // Upsert movie metadata (基于 tmdbId 唯一键)
                            String upsertSql = "INSERT INTO movie " +
                                    "(tmdbId, title, originalTitle, genres, year, director, actors, description, posterUrl, avgRating, ratingCount, source, created_at, updated_at) " +
                                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'TMDB', NOW(), NOW()) " +
                                    "ON DUPLICATE KEY UPDATE " +
                                    "title=VALUES(title), originalTitle=VALUES(originalTitle), genres=VALUES(genres), " +
                                    "year=VALUES(year), director=VALUES(director), actors=VALUES(actors), " +
                                    "description=VALUES(description), posterUrl=VALUES(posterUrl), " +
                                    "avgRating=VALUES(avgRating), ratingCount=VALUES(ratingCount), " +
                                    "updated_at=NOW()";
                            
                            upsert = conn.prepareStatement(upsertSql);
                            int batchCount = 0;
                            
                            while (iter.hasNext()) {
                                Row r = iter.next();
                                String tmdbId = r.isNullAt(r.fieldIndex("tmdbId")) ? null : r.getString(r.fieldIndex("tmdbId"));
                                String title = r.isNullAt(r.fieldIndex("title")) ? null : r.getString(r.fieldIndex("title"));
                                String originalTitle = r.isNullAt(r.fieldIndex("originalTitle")) ? null : r.getString(r.fieldIndex("originalTitle"));
                                String genres = r.isNullAt(r.fieldIndex("genres")) ? null : r.getString(r.fieldIndex("genres"));
                                Integer year = r.isNullAt(r.fieldIndex("year")) ? null : r.getInt(r.fieldIndex("year"));
                                String director = r.isNullAt(r.fieldIndex("director")) ? null : r.getString(r.fieldIndex("director"));
                                String actors = r.isNullAt(r.fieldIndex("actors")) ? null : r.getString(r.fieldIndex("actors"));
                                String description = r.isNullAt(r.fieldIndex("description")) ? null : r.getString(r.fieldIndex("description"));
                                String posterUrl = r.isNullAt(r.fieldIndex("posterUrl")) ? null : r.getString(r.fieldIndex("posterUrl"));
                                Double avgRating = r.isNullAt(r.fieldIndex("avgRating")) ? 0.0 : r.getDouble(r.fieldIndex("avgRating"));
                                Integer ratingCount = r.isNullAt(r.fieldIndex("ratingCount")) ? 0 : r.getInt(r.fieldIndex("ratingCount"));
                                
                                if (tmdbId == null || title == null) {
                                    log.warn("Skipping movie with null tmdbId or title");
                                    continue;
                                }
                                
                                upsert.setString(1, tmdbId);
                                upsert.setString(2, title);
                                upsert.setString(3, originalTitle);
                                upsert.setString(4, genres);
                                if (year != null) {
                                    upsert.setInt(5, year);
                                } else {
                                    upsert.setNull(5, java.sql.Types.INTEGER);
                                }
                                upsert.setString(6, director);
                                upsert.setString(7, actors);
                                upsert.setString(8, description);
                                upsert.setString(9, posterUrl);
                                upsert.setDouble(10, avgRating);
                                upsert.setInt(11, ratingCount);
                                
                                upsert.addBatch();
                                batchCount++;
                            }
                            
                            if (batchCount > 0) {
                                upsert.executeBatch();
                                conn.commit();
                                log.info("Upserted {} movies to MySQL", batchCount);
                            }
                            
                        } catch (Exception e) {
                            log.error("Error upserting movies", e);
                            if (conn != null) conn.rollback();
                            throw e;
                        } finally {
                            JdbcUtils.quietClose(upsert);
                            JdbcUtils.quietClose(conn);
                        }
                    });
                    
                    batch.unpersist();
                })
                .option("checkpointLocation", cfg.getString("spark.checkpointBase", "hdfs:///checkpoints/recsys") + "/movies-ingest")
                .start();

        log.info("MoviesIngestJob started, awaiting termination...");
        query.awaitTermination();
    }
}

