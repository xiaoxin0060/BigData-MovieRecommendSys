#!/usr/bin/env bash
#############################################
# 电影推荐系统 - 批量 ALS 训练脚本
# 功能：执行 ALS 推荐算法训练
#############################################

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  开始 ALS 训练...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

PROJECT_DIR=$(cd $(dirname $0)/..; pwd)
APP_JAR=$PROJECT_DIR/target/recsys-processor-1.0.0.jar

if [ ! -f "$APP_JAR" ]; then
    echo -e "${RED}❌ 错误: 找不到 JAR 包${NC}"
    exit 1
fi

echo -e "${YELLOW}训练参数（YARN 8GB集群 - 稳定优化模式）:${NC}"
echo -e "  - 模式: YARN 集群 (2 Executors × 2 cores)"
echo -e "  - 内存: Driver 2GB, Executor 2GB + 512MB overhead × 2"
echo -e "  - 总需求: ~7GB (安全余量，防止 OOM)"
echo -e "  - 数据: 前 8万用户 (约 800-1000万评分)"
echo -e "  - 读取: 40并行分区 + 内存缓存 + Kryo序列化"
echo -e "  - 训练: 自适应查询 + Checkpoint + 压缩"
echo -e "  - 写入: 动态分区 + 批量提交(5000条/批)"
echo -e "  - ALS: Rank=30, RegParam=0.1, MaxIter=10"
echo -e "  - 预计耗时: 10-15 分钟 ⚡"
echo ""

START_TIME=$(date +%s)

spark-submit \
  --master yarn \
  --deploy-mode client \
  --class com.yourorg.recsys.batch.BatchAlsJob \
  --num-executors 2 \
  --executor-cores 2 \
  --executor-memory 2g \
  --driver-memory 2g \
  --jars $APP_JAR \
  --conf spark.sql.shuffle.partitions=80 \
  --conf spark.executor.memoryOverhead=512m \
  --conf spark.yarn.am.memory=512m \
  --conf spark.driver.extraClassPath=$APP_JAR \
  --conf spark.executor.extraClassPath=$APP_JAR \
  --conf spark.default.parallelism=16 \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryoserializer.buffer.max=512m \
  --conf spark.shuffle.compress=true \
  --conf spark.shuffle.spill.compress=true \
  --conf spark.io.compression.codec=snappy \
  --conf spark.memory.fraction=0.8 \
  --conf spark.memory.storageFraction=0.3 \
  $APP_JAR

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ ALS 训练完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "耗时: $ELAPSED 秒"
echo ""
echo -e "查看推荐结果:"
echo -e "  mysql -u root -p movie -e \"SELECT * FROM recommendation WHERE algorithm='ALS' LIMIT 10;\""
echo ""

