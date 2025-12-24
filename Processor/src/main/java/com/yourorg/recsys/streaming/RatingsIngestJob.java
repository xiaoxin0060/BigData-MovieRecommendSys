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
import java.sql.Timestamp;

import static org.apache.spark.sql.functions.*;

public class RatingsIngestJob {
    private static final Logger log = LoggerFactory.getLogger(RatingsIngestJob.class);

    public static void main(String[] args) throws Exception {
        String configPath = "application.yaml";
        for (int i = 0; i < args.length - 1; i++) {
            if ("--config".equals(args[i])) configPath = args[i + 1];
        }
        Config cfg = new Config(configPath);

        SparkSession spark = SparkSession.builder()
                .appName("RatingsIngestJob")
                .getOrCreate();
        spark.sqlContext().setConf("spark.sql.shuffle.partitions",
                String.valueOf(cfg.getInt("spark.shufflePartitions", 200)));

        String bootstrap = cfg.getString("kafka.bootstrapServers", "localhost:9092");
        String topic = cfg.getString("kafka.topicRatings", "ratings");

        Dataset<Row> raw = spark
                .readStream()
                .format("kafka")
                .option("kafka.bootstrap.servers", bootstrap)
                .option("subscribe", topic)
                .option("kafka.group.id", "ratings-ingest-group")  // 独立 Consumer Group
                .option("startingOffsets", "latest")
                .load();

        Dataset<Row> json = raw.selectExpr("cast(value as string) as json");
        Dataset<Row> parsed = json.select(functions.from_json(col("json"),
                new org.apache.spark.sql.types.StructType()
                        .add("userId", org.apache.spark.sql.types.DataTypes.LongType)
                        .add("movieId", org.apache.spark.sql.types.DataTypes.LongType)
                        .add("rating", org.apache.spark.sql.types.DataTypes.DoubleType)
                        .add("timestamp", org.apache.spark.sql.types.DataTypes.LongType)
        ).as("data")).select("data.*");

        // event time watermark + dedup
        Dataset<Row> withEventTime = parsed
                .withColumn("eventTime", to_timestamp(from_unixtime(col("timestamp"))))
                .withWatermark("eventTime", "10 minutes")
                .dropDuplicates("userId", "movieId");

        // Upsert into MySQL rating and update movie aggregates in foreachBatch
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
                    long batchStartMs = System.currentTimeMillis();
                    long batchSize = batch.count();
                    // 1) 先收集受影响的 movieId 列表
                    java.util.List<Long> affectedMovieIds = batch.select("movieId").distinct().as(Encoders.LONG()).collectAsList();

                    // 2) 分区内 upsert rating 表
                    batch.foreachPartition(iter -> {
                        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
                        Connection conn = null;
                        PreparedStatement upsert = null;
                        try {
                            conn = jdbc.getConnection();
                            conn.setAutoCommit(false);
                            String upsertSql = "INSERT INTO rating (userId, movieId, rating, timestamp, created_at, updated_at) " +
                                    "VALUES (?, ?, ?, ?, NOW(), NOW()) " +
                                    "ON DUPLICATE KEY UPDATE rating=VALUES(rating), timestamp=VALUES(timestamp), updated_at=NOW()";
                            upsert = conn.prepareStatement(upsertSql);

                            while (iter.hasNext()) {
                                Row r = iter.next();
                                long u = r.getLong(r.fieldIndex("userId"));
                                long m = r.getLong(r.fieldIndex("movieId"));
                                double rt = r.getDouble(r.fieldIndex("rating"));
                                long ts = r.getLong(r.fieldIndex("timestamp"));
                                upsert.setLong(1, u);
                                upsert.setLong(2, m);
                                upsert.setDouble(3, rt);
                                upsert.setLong(4, ts);
                                upsert.addBatch();
                            }
                            upsert.executeBatch();
                            conn.commit();
                        } catch (Exception e) {
                            if (conn != null) conn.rollback();
                            throw e;
                        } finally {
                            JdbcUtils.quietClose(upsert);
                            JdbcUtils.quietClose(conn);
                        }
                    });

                    // 3) 统一在 Driver 端更新 movie 聚合（avgRating、ratingCount）
                    if (affectedMovieIds != null && !affectedMovieIds.isEmpty()) {
                        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
                        Connection conn = null;
                        PreparedStatement stmt = null;
                        try {
                            conn = jdbc.getConnection();
                            StringBuilder sb = new StringBuilder();
                            sb.append("UPDATE movie m JOIN (SELECT movieId, AVG(rating) avgR, COUNT(*) cnt FROM rating WHERE movieId IN (");
                            for (int i = 0; i < affectedMovieIds.size(); i++) {
                                if (i > 0) sb.append(",");
                                sb.append("?");
                            }
                            sb.append(") GROUP BY movieId) r ON r.movieId = m.id SET m.avgRating = ROUND(r.avgR, 2), m.ratingCount = r.cnt");
                            stmt = conn.prepareStatement(sb.toString());
                            int idx = 1;
                            for (Long id : affectedMovieIds) {
                                stmt.setLong(idx++, id);
                            }
                            stmt.executeUpdate();
                        } finally {
                            JdbcUtils.quietClose(stmt);
                            JdbcUtils.quietClose(conn);
                        }
                    }
                    long durationMs = System.currentTimeMillis() - batchStartMs;
                    try {
                        upsertJobHeartbeat(host, port, db, params, user, pwd,
                                "ratings_ingest", "RUNNING",
                                null, null,
                                batchSize, durationMs,
                                null,
                                null);
                    } catch (Exception e) {
                        log.warn("Failed to update monitor_job_heartbeat for RatingsIngestJob", e);
                    }
                    batch.unpersist();
                })
                .option("checkpointLocation", cfg.getString("spark.checkpointBase", "hdfs:///checkpoints/recsys") + "/ratings-ingest")
                .start();

        query.awaitTermination();
    }

    private static void upsertJobHeartbeat(String host,
                                           int port,
                                           String db,
                                           String params,
                                           String user,
                                           String pwd,
                                           String jobName,
                                           String status,
                                           java.sql.Timestamp lastRunStartAt,
                                           java.sql.Timestamp lastRunEndAt,
                                           Long lastBatchSize,
                                           Long lastBatchDurationMs,
                                           String modelVersion,
                                           String metricsJson) throws Exception {
        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
        Connection conn = null;
        PreparedStatement ps = null;
        try {
            conn = jdbc.getConnection();
            String sql = "INSERT INTO monitor_job_heartbeat " +
                    "(job_name, status, last_heartbeat_at, last_run_start_at, last_run_end_at, " +
                    " last_batch_size, last_batch_duration_ms, model_version, metrics_json) " +
                    "VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?) " +
                    "ON DUPLICATE KEY UPDATE " +
                    "status = VALUES(status), " +
                    "last_heartbeat_at = NOW(), " +
                    "last_run_start_at = COALESCE(VALUES(last_run_start_at), last_run_start_at), " +
                    "last_run_end_at = COALESCE(VALUES(last_run_end_at), last_run_end_at), " +
                    "last_batch_size = VALUES(last_batch_size), " +
                    "last_batch_duration_ms = VALUES(last_batch_duration_ms), " +
                    "model_version = COALESCE(VALUES(model_version), model_version), " +
                    "metrics_json = VALUES(metrics_json)";
            ps = conn.prepareStatement(sql);
            ps.setString(1, jobName);
            ps.setString(2, status);
            if (lastRunStartAt != null) {
                ps.setTimestamp(3, lastRunStartAt);
            } else {
                ps.setNull(3, java.sql.Types.TIMESTAMP);
            }
            if (lastRunEndAt != null) {
                ps.setTimestamp(4, lastRunEndAt);
            } else {
                ps.setNull(4, java.sql.Types.TIMESTAMP);
            }
            if (lastBatchSize != null) {
                ps.setLong(5, lastBatchSize);
            } else {
                ps.setNull(5, java.sql.Types.BIGINT);
            }
            if (lastBatchDurationMs != null) {
                ps.setLong(6, lastBatchDurationMs);
            } else {
                ps.setNull(6, java.sql.Types.BIGINT);
            }
            if (modelVersion != null) {
                ps.setString(7, modelVersion);
            } else {
                ps.setNull(7, java.sql.Types.VARCHAR);
            }
            // MySQL JSON 列在某些 Connector/J + server-prepared 组合下对 VARCHAR 绑定会报错
            if (metricsJson != null) {
                ps.setObject(8, metricsJson, java.sql.Types.OTHER);
            } else {
                ps.setNull(8, java.sql.Types.OTHER);
            }
            ps.executeUpdate();
        } finally {
            JdbcUtils.quietClose(ps);
            JdbcUtils.quietClose(conn);
        }
    }
}


