#!/usr/bin/env bash
#############################################
# 电影推荐系统 - 一键启动脚本
# 功能：启动所有必要的组件
#############################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  电影推荐系统 - 启动中...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 项目根目录
PROJECT_DIR=$(cd $(dirname $0)/..; pwd)
SCRIPTS_DIR=$PROJECT_DIR/scripts
LOG_DIR=$PROJECT_DIR/logs
mkdir -p $LOG_DIR

# JAR 包路径
APP_JAR=$PROJECT_DIR/target/recsys-processor-1.0.0.jar

# 检查 JAR 是否存在
if [ ! -f "$APP_JAR" ]; then
    echo -e "${RED}❌ 错误: 找不到 JAR 包${NC}"
    echo "   请先执行: cd $PROJECT_DIR && mvn clean package"
    exit 1
fi

echo -e "${YELLOW}[1/5] 检查 Kafka 状态...${NC}"
# 检查 Kafka 是否运行
if ! jps | grep -q "Kafka"; then
    echo -e "${YELLOW}   Kafka 未运行，尝试启动...${NC}"
    # 你的 Kafka 路径是 /opt/kafka (从环境变量读取)
    if [ -d "$KAFKA_HOME" ]; then
        cd $KAFKA_HOME
        nohup bin/kafka-server-start.sh config/server.properties > $LOG_DIR/kafka.log 2>&1 &
        sleep 5
        echo -e "${GREEN}   ✓ Kafka 已启动${NC}"
    else
        echo -e "${RED}   ⚠️  请手动启动 Kafka${NC}"
    fi
else
    echo -e "${GREEN}   ✓ Kafka 已在运行${NC}"
fi

echo ""
echo -e "${YELLOW}[2/5] 检查并创建 Kafka 主题...${NC}"
# 创建 Kafka 主题（如果不存在）
KAFKA_BIN="${KAFKA_HOME:-/opt/kafka}/bin"  # 从环境变量读取，默认 /opt/kafka
BOOTSTRAP_SERVER="hadoop-master:9092,hadoop-worker1:9092,hadoop-worker2:9092"

# 检查 kafka-topics.sh 是否存在
if [ -f "$KAFKA_BIN/kafka-topics.sh" ]; then
    # 创建 movies 主题
    if ! $KAFKA_BIN/kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^movies$"; then
        $KAFKA_BIN/kafka-topics.sh --create --topic movies \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --partitions 3 --replication-factor 2 2>/dev/null || true
        echo -e "${GREEN}   ✓ 已创建 movies 主题${NC}"
    else
        echo -e "${GREEN}   ✓ movies 主题已存在${NC}"
    fi
    
    # 创建 ratings 主题
    if ! $KAFKA_BIN/kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^ratings$"; then
        $KAFKA_BIN/kafka-topics.sh --create --topic ratings \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --partitions 3 --replication-factor 2 2>/dev/null || true
        echo -e "${GREEN}   ✓ 已创建 ratings 主题${NC}"
    else
        echo -e "${GREEN}   ✓ ratings 主题已存在${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  请手动创建 Kafka 主题: movies, ratings${NC}"
fi

echo ""
echo -e "${YELLOW}[3/5] 跳过电影元数据流处理（仅使用本地 MovieLens 数据）${NC}"
echo -e "${GREEN}   ℹ️  MoviesIngestJob 已禁用（无需处理外部电影数据）${NC}"
# 如需启用 TMDB 拉取，取消注释以下代码：
# nohup spark-submit \
#   --master yarn \
#   --deploy-mode client \
#   --class com.yourorg.recsys.streaming.MoviesIngestJob \
#   --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
#   --num-executors 1 \
#   --executor-cores 1 \
#   --executor-memory 1g \
#   --driver-memory 1g \
#   --conf spark.sql.shuffle.partitions=30 \
#   $APP_JAR \
#   > $LOG_DIR/movies-ingest.log 2>&1 &
# MOVIES_JOB_PID=$!
# echo $MOVIES_JOB_PID > $LOG_DIR/movies-ingest.pid

sleep 1

echo ""
echo -e "${YELLOW}[4/5] 启动流处理作业 - 评分数据入库...${NC}"
# 启动 RatingsIngestJob（修复：移除 --jars 误用）
nohup spark-submit \
  --master yarn \
  --deploy-mode client \
  --class com.yourorg.recsys.streaming.RatingsIngestJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --num-executors 1 \
  --executor-cores 1 \
  --executor-memory 1g \
  --driver-memory 1g \
  --conf spark.sql.shuffle.partitions=30 \
  $APP_JAR \
  > $LOG_DIR/ratings-ingest.log 2>&1 &

RATINGS_JOB_PID=$!
echo $RATINGS_JOB_PID > $LOG_DIR/ratings-ingest.pid
echo -e "${GREEN}   ✓ RatingsIngestJob 已启动 (PID: $RATINGS_JOB_PID)${NC}"
echo -e "     日志: $LOG_DIR/ratings-ingest.log"

sleep 3

echo ""
echo -e "${YELLOW}[5/5] 启动实时推荐回填作业...${NC}"
# 启动 RealtimeRecBackfillJob（修复：移除 --jars 误用）
nohup spark-submit \
  --master yarn \
  --deploy-mode client \
  --class com.yourorg.recsys.streaming.RealtimeRecBackfillJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --num-executors 1 \
  --executor-cores 1 \
  --executor-memory 1g \
  --driver-memory 1g \
  --conf spark.sql.shuffle.partitions=30 \
  $APP_JAR \
  > $LOG_DIR/realtime-rec-backfill.log 2>&1 &

REALTIME_JOB_PID=$!
echo $REALTIME_JOB_PID > $LOG_DIR/realtime-rec-backfill.pid
echo -e "${GREEN}   ✓ RealtimeRecBackfillJob 已启动 (PID: $REALTIME_JOB_PID)${NC}"
echo -e "     日志: $LOG_DIR/realtime-rec-backfill.log"

sleep 3

echo ""
echo -e "${YELLOW}[已禁用] TMDB 数据拉取器${NC}"
echo -e "${GREEN}   ℹ️  TMDB 拉取器已禁用（仅使用本地 MovieLens 数据）${NC}"
# 如需启用，取消注释以下代码：
# cd $SCRIPTS_DIR
# nohup python3 tmdb_data_fetcher.py > $LOG_DIR/tmdb-fetcher.log 2>&1 &
# TMDB_PID=$!
# echo $TMDB_PID > $LOG_DIR/tmdb-fetcher.pid
# echo -e "${GREEN}   ✓ TMDB 拉取器已启动 (PID: $TMDB_PID)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 所有组件启动完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "运行中的服务："
echo -e "  - Kafka"
echo -e "  - RatingsIngestJob       (PID: $RATINGS_JOB_PID)"
echo -e "  - RealtimeRecBackfillJob (PID: $REALTIME_JOB_PID)"
echo ""
echo -e "已禁用的服务："
echo -e "  - MoviesIngestJob  (仅使用本地数据)"
echo -e "  - TMDB 拉取器      (仅使用本地数据)"
echo ""
echo -e "查看日志："
echo -e "  tail -f $LOG_DIR/ratings-ingest.log"
echo -e "  tail -f $LOG_DIR/realtime-rec-backfill.log"
echo ""
echo -e "停止所有服务："
echo -e "  $SCRIPTS_DIR/stop_all.sh"
echo ""
echo -e "监控 Spark UI："
echo -e "  http://localhost:4040  (RatingsIngestJob)"
echo -e "  http://localhost:4041  (RealtimeRecBackfillJob)"
echo ""
echo -e "${YELLOW}提示: MovieLens 数据已完整导入，现有 2500 万评分可用于训练${NC}"
echo -e "${YELLOW}提示: 可以运行批训练: $SCRIPTS_DIR/run_batch_als.sh${NC}"
echo -e "${YELLOW}提示: 如需实时评分流测试，请手动推送到 Kafka ratings 主题${NC}"
echo ""

