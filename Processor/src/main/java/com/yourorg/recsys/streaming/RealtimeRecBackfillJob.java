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
import java.sql.ResultSet;
import java.util.*;

import static org.apache.spark.sql.functions.*;

/**
 * RealtimeRecBackfillJob
 * 监听 ratings 事件，为“新用户”快速回填 recommendation 表。
 * - 若评分条数 < 阈值，回退热门榜单
 * - 否则，基于 nightly ALS 模型的 item_factors 做一次 fold-in 求 user 向量，并对候选集打分
 */
public class RealtimeRecBackfillJob {
    private static final Logger log = LoggerFactory.getLogger(RealtimeRecBackfillJob.class);

    // 简单的版本缓存与因子缓存（仅在 Driver 端使用）
    private static volatile String cachedVersion = null;
    private static volatile Dataset<Row> cachedItemFactors = null;

    public static void main(String[] args) throws Exception {
        String configPath = "application.yaml";
        for (int i = 0; i < args.length - 1; i++) {
            if ("--config".equals(args[i])) configPath = args[i + 1];
        }
        Config cfg = new Config(configPath);

        SparkSession spark = SparkSession.builder()
                .appName("RealtimeRecBackfillJob")
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
                .option("kafka.group.id", "realtime-rec-backfill-group")  // 独立 Consumer Group
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

        Dataset<Row> withEventTime = parsed
                .withColumn("eventTime", to_timestamp(from_unixtime(col("timestamp"))))
                .withWatermark("eventTime", "10 minutes");

        String trigger = cfg.getString("realtime.microBatch", "5 seconds");

        StreamingQuery query = withEventTime.writeStream()
                .outputMode(OutputMode.Update())
                .trigger(Trigger.ProcessingTime(trigger))
                .foreachBatch((batch, batchId) -> {
                    if (batch.isEmpty()) return;

                    batch.persist();
                    long batchStartMs = System.currentTimeMillis();
                    long batchSize = batch.count();
                    log.info("Realtime backfill processing batch {} with {} rows", batchId, batchSize);

                    // 聚合到用户维度：收集该批用户的评分列表
                    Dataset<Row> perUser = batch
                            .groupBy(col("userId"))
                            .agg(collect_list(struct(col("movieId"), col("rating"))).alias("ratings"));

                    List<Row> userRows = perUser.collectAsList();
                    if (userRows.isEmpty()) {
                        batch.unpersist();
                        return;
                    }

                    // 基础配置
                    int topN = cfg.getInt("als.topN", 30);
                    int minRatings = cfg.getInt("realtime.minRatingsForFoldIn", 3);
                    int candidateLimit = cfg.getInt("realtime.candidateLimit", 10000);
                    double regParam = Double.parseDouble(cfg.getString("als.regParam", "0.1"));

                    // MySQL 连接信息
                    String host = cfg.getString("mysql.host", "127.0.0.1");
                    int port = cfg.getInt("mysql.port", 3306);
                    String db = cfg.getString("mysql.database", "movie");
                    String user = cfg.getString("mysql.user", "root");
                    String pwd = cfg.getString("mysql.password", "root_password");
                    String params = cfg.getString("mysql.params", "useSSL=false&serverTimezone=UTC");

                    // 当前激活版本
                    String activeVersion = getActiveModelVersion(host, port, db, params, user, pwd);
                    if (activeVersion == null) activeVersion = "v0";

                    // 懒加载 / 切版本重载 item_factors
                    String modelBasePath = cfg.getString("als.modelBasePath", "hdfs:///apps/recsys/models/als");
                    if (!activeVersion.equals(cachedVersion) || cachedItemFactors == null) {
                        String itemFactorsPath = modelBasePath + "/" + activeVersion + "/item_factors";
                        log.info("Loading item_factors from {}", itemFactorsPath);
                        Dataset<Row> itemFactors = spark.read().parquet(itemFactorsPath);
                        // 仅缓存一次，供后续 micro-batch 复用
                        cachedItemFactors = itemFactors.cache();
                        // 触发缓存
                        cachedItemFactors.count();
                        cachedVersion = activeVersion;
                    }

                    // 处理每个用户
                    for (Row ur : userRows) {
                        long userId = ur.getLong(ur.fieldIndex("userId"));
                        List<Row> ratingList = ur.getList(ur.fieldIndex("ratings"));
                        if (ratingList == null) ratingList = Collections.emptyList();

                        // 若此版本已存在推荐，则跳过
                        if (hasRecommendationForVersion(host, port, db, params, user, pwd, userId, activeVersion)) {
                            continue;
                        }

                        // 构造该用户的评分对
                        List<Long> ratedMovieIds = new ArrayList<>();
                        List<Double> ratedScores = new ArrayList<>();
                        for (Row r : ratingList) {
                            Long mid = r.isNullAt(r.fieldIndex("movieId")) ? null : r.getLong(r.fieldIndex("movieId"));
                            Double rt = r.isNullAt(r.fieldIndex("rating")) ? null : r.getDouble(r.fieldIndex("rating"));
                            if (mid != null && rt != null) {
                                ratedMovieIds.add(mid);
                                ratedScores.add(rt);
                            }
                        }

                        List<long[]> recs; // each: [movieId, rank]
                        List<Double> recScores;

                        if (ratedMovieIds.size() >= minRatings) {
                            // fold-in 求解用户向量并打分
                            FoldInResult foldRes = foldInAndScore(spark, cachedItemFactors, ratedMovieIds, ratedScores, candidateLimit, topN, regParam);
                            recs = foldRes.movieRanks;
                            recScores = foldRes.scores;
                        } else {
                            // 冷启动热门回填
                            List<Long> popular = topPopularCandidates(host, port, db, params, user, pwd, candidateLimit);
                            recs = new ArrayList<>();
                            recScores = new ArrayList<>();
                            int limit = Math.min(topN, popular.size());
                            for (int i = 0; i < limit; i++) {
                                long mid = popular.get(i);
                                if (ratedMovieIds.contains(mid)) continue;
                                recs.add(new long[]{mid, i + 1});
                                recScores.add(1.0 / (i + 1));
                            }
                        }

                        // 落库（幂等 Upsert）
                        upsertRecommendations(host, port, db, params, user, pwd, userId, activeVersion, recs, recScores);
                    }

                    long durationMs = System.currentTimeMillis() - batchStartMs;
                    try {
                        upsertJobHeartbeat(host, port, db, params, user, pwd,
                                "realtime_rec_backfill", "RUNNING",
                                null, null,
                                batchSize, durationMs,
                                activeVersion,
                                null);
                    } catch (Exception e) {
                        log.warn("Failed to update monitor_job_heartbeat for RealtimeRecBackfillJob", e);
                    }
                    batch.unpersist();
                })
                .option("checkpointLocation", cfg.getString("spark.checkpointBase", "hdfs:///checkpoints/recsys") + "/realtime-rec-backfill")
                .start();

        log.info("RealtimeRecBackfillJob started, awaiting termination...");
        query.awaitTermination();
    }

    private static String getActiveModelVersion(String host, int port, String db, String params, String user, String pwd) throws Exception {
        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
        try (Connection conn = jdbc.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT active_version FROM rec_model_meta WHERE id=1");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) return rs.getString(1);
            return null;
        }
    }

    private static boolean hasRecommendationForVersion(String host, int port, String db, String params, String user, String pwd, long userId, String version) throws Exception {
        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
        try (Connection conn = jdbc.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM recommendation WHERE userId=? AND model_version=? LIMIT 1")) {
            ps.setLong(1, userId);
            ps.setString(2, version);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    private static List<Long> topPopularCandidates(String host, int port, String db, String params, String user, String pwd, int limit) throws Exception {
        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
        List<Long> ids = new ArrayList<>();
        try (Connection conn = jdbc.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT id FROM movie ORDER BY ratingCount DESC LIMIT ?")) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) ids.add(rs.getLong(1));
            }
        }
        return ids;
    }

    private static class FoldInResult {
        List<long[]> movieRanks;
        List<Double> scores;
    }

    private static FoldInResult foldInAndScore(SparkSession spark,
                                               Dataset<Row> itemFactors,
                                               List<Long> ratedMovieIds,
                                               List<Double> ratedScores,
                                               int candidateLimit,
                                               int topN,
                                               double regParam) {
        // 1) 取已评分物品的因子
        List<Integer> ratedIdsInt = new ArrayList<>();
        for (Long m : ratedMovieIds) ratedIdsInt.add(m.intValue());
        Dataset<Row> ratedIdsDF = spark.createDataset(ratedIdsInt, Encoders.INT()).toDF("id");
        Dataset<Row> ratedFactors = itemFactors.join(ratedIdsDF, "id");
        List<Row> ratedRows = ratedFactors.collectAsList();

        // 2) 组装 A 与 b：A = λI + Σ y y^T, b = Σ y * r
        if (ratedRows.isEmpty()) {
            FoldInResult r = new FoldInResult();
            r.movieRanks = new ArrayList<>();
            r.scores = new ArrayList<>();
            return r;
        }

        // 取 rank 维度
        int rank = ((scala.collection.mutable.WrappedArray<?>) ratedRows.get(0).get(1)).length();
        double[][] A = new double[rank][rank];
        double[] b = new double[rank];

        for (int i = 0; i < ratedRows.size(); i++) {
            Row rr = ratedRows.get(i);
            @SuppressWarnings("unchecked")
            scala.collection.mutable.WrappedArray<Object> featArr = (scala.collection.mutable.WrappedArray<Object>) rr.get(1);
            double[] y = new double[rank];
            for (int k = 0; k < rank; k++) y[k] = ((Number) featArr.apply(k)).doubleValue();
            double r = ratedScores.get(i);
            // b += y * r
            for (int a = 0; a < rank; a++) b[a] += y[a] * r;
            // A += y y^T
            for (int a = 0; a < rank; a++) {
                double ya = y[a];
                for (int c = 0; c < rank; c++) {
                    A[a][c] += ya * y[c];
                }
            }
        }
        // A += λI
        for (int d = 0; d < A.length; d++) A[d][d] += regParam;

        // 3) 解 u: A u = b（Cholesky）
        double[] u = solveSymmetricPositiveDefinite(A, b);

        // 4) 候选集（热门 TopK）
        // 这里从 itemFactors 中随机采样 candidateLimit 行的 id（近似）或全量，再在 Driver 上过滤与打分。
        // 简化：从 itemFactors 取前 candidateLimit（与热门并不完全一致，但可行），再排除已评分。
        Dataset<Row> candDF = itemFactors.limit(candidateLimit);
        List<Row> candRows = candDF.collectAsList();
        List<long[]> movieRanks = new ArrayList<>();
        List<Double> scores = new ArrayList<>();

        // 计算分数并排序
        List<long[]> tmp = new ArrayList<>();
        List<Double> tmpScores = new ArrayList<>();
        for (Row rRow : candRows) {
            int mid = rRow.getInt(0);
            if (ratedMovieIds.contains((long) mid)) continue;
            @SuppressWarnings("unchecked")
            scala.collection.mutable.WrappedArray<Object> featArr = (scala.collection.mutable.WrappedArray<Object>) rRow.get(1);
            double s = 0.0;
            for (int k = 0; k < u.length; k++) {
                s += u[k] * ((Number) featArr.apply(k)).doubleValue();
            }
            tmp.add(new long[]{mid, 0});
            tmpScores.add(s);
        }

        // 选 TopN
        List<Integer> idx = new ArrayList<>();
        for (int i = 0; i < tmp.size(); i++) idx.add(i);
        idx.sort((a, b2) -> Double.compare(tmpScores.get(b2), tmpScores.get(a)));
        int limit = Math.min(topN, idx.size());
        for (int i = 0; i < limit; i++) {
            int j = idx.get(i);
            long[] pair = tmp.get(j);
            pair[1] = i + 1; // rank
            movieRanks.add(pair);
            scores.add(tmpScores.get(j));
        }

        FoldInResult res = new FoldInResult();
        res.movieRanks = movieRanks;
        res.scores = scores;
        return res;
    }

    private static double[] solveSymmetricPositiveDefinite(double[][] A, double[] b) {
        int n = b.length;
        double[][] L = new double[n][n];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j <= i; j++) {
                double sum = A[i][j];
                for (int k = 0; k < j; k++) sum -= L[i][k] * L[j][k];
                if (i == j) {
                    sum = Math.max(sum, 1e-8); // 数值稳定
                    L[i][j] = Math.sqrt(sum);
                } else {
                    L[i][j] = sum / L[j][j];
                }
            }
        }
        // 解 Ly = b
        double[] y = new double[n];
        for (int i = 0; i < n; i++) {
            double sum = b[i];
            for (int k = 0; k < i; k++) sum -= L[i][k] * y[k];
            y[i] = sum / L[i][i];
        }
        // 解 L^T x = y
        double[] x = new double[n];
        for (int i = n - 1; i >= 0; i--) {
            double sum = y[i];
            for (int k = i + 1; k < n; k++) sum -= L[k][i] * x[k];
            x[i] = sum / L[i][i];
        }
        return x;
    }

    private static void upsertRecommendations(String host, int port, String db, String params, String user, String pwd,
                                              long userId, String version,
                                              List<long[]> movieRanks, List<Double> scores) throws Exception {
        if (movieRanks == null || movieRanks.isEmpty()) return;
        JdbcUtils jdbc = new JdbcUtils(host, port, db, params, user, pwd);
        Connection conn = null;
        PreparedStatement ps = null;
        try {
            conn = jdbc.getConnection();
            conn.setAutoCommit(false);
            String sql = "INSERT INTO recommendation (userId, movieId, score, `rank`, algorithm, model_version, created_at) " +
                    "VALUES (?, ?, ?, ?, 'ALS', ?, NOW()) " +
                    "ON DUPLICATE KEY UPDATE score=VALUES(score), `rank`=VALUES(`rank`), algorithm=VALUES(algorithm), created_at=VALUES(created_at)";
            ps = conn.prepareStatement(sql);
            for (int i = 0; i < movieRanks.size(); i++) {
                long[] mr = movieRanks.get(i);
                ps.setLong(1, userId);
                ps.setLong(2, mr[0]);
                ps.setDouble(3, scores.get(i));
                ps.setInt(4, (int) mr[1]);
                ps.setString(5, version);
                ps.addBatch();
            }
            ps.executeBatch();
            conn.commit();
        } catch (Exception e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            JdbcUtils.quietClose(ps);
            JdbcUtils.quietClose(conn);
        }
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


