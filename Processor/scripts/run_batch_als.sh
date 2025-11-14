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
echo -e "${GREEN}  开始 ALS 训练（含模型持久化）...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

PROJECT_DIR=$(cd $(dirname $0)/..; pwd)
APP_JAR=$PROJECT_DIR/target/recsys-processor-1.0.0.jar
LOG_DIR=$PROJECT_DIR/logs
mkdir -p "$LOG_DIR"

# 可选参数：DEPLOY_MODE=client|cluster（默认 client），DETACH=1 后台运行
DEPLOY_MODE=${DEPLOY_MODE:-client}
DETACH=${DETACH:-0}
CONF_FILE=${CONF_FILE:-application.yaml}

TS=$(date +%F-%H%M%S)
LOG_FILE="$LOG_DIR/batch-als-$TS.log"

if [ ! -f "$APP_JAR" ]; then
    echo -e "${RED}❌ 错误: 找不到 JAR 包${NC}"
    exit 1
fi

echo -e "${YELLOW}训练参数（三节点集群 4c10g+4c8g+4c8g - 均衡优化 + 防倾斜模式）:${NC}"
echo -e "  - 模式: YARN 集群 (3 Executors × 3 cores，强制预分配)"
echo -e "  - 内存: Driver 2GB, Executor 3GB + 512MB overhead × 3"
echo -e "  - 总需求: ~13GB / 9 cores (三节点均衡分布)"
echo -e "  - 数据: 前 8万用户 (约 800-1000万评分)"
echo -e "  - 读取: 40并行分区 + 动态边界查询 + 强制重分区 + 内存缓存"
echo -e "  - 训练: 自适应查询 + Checkpoint + 压缩 + 推测执行"
echo -e "  - 写入: 动态分区 + 批量提交(5000条/批)"
echo -e "  - 持久化: 模型+item_factors 保存至 als.modelBasePath/{modelVersion}"
echo -e "  - ALS: Rank=30, RegParam=0.1, MaxIter=10"
echo -e "  - 容错: 心跳超时5分钟 + 网络超时5分钟 + 推测执行"
echo -e "  - 预计耗时: 8-12 分钟 ⚡ (三节点加速)"
echo ""

START_TIME=$(date +%s)

SUBMIT_CMD=(
  spark-submit
  --master yarn
  --deploy-mode "$DEPLOY_MODE"
  --class com.yourorg.recsys.batch.BatchAlsJob
  --num-executors 3
  --executor-cores 3
  --executor-memory 3g
  --driver-memory 2g
  --jars "$APP_JAR"
  
  # 🔧 核心：禁用动态分配，强制预分配所有 Executor
  --conf spark.dynamicAllocation.enabled=false
  --conf spark.executor.instances=3
  
  # 🔧 核心：推测执行（处理慢任务/数据倾斜）
  --conf spark.speculation=true
  --conf spark.speculation.interval=1000ms
  --conf spark.speculation.multiplier=1.5
  --conf spark.speculation.quantile=0.75
  
  # 🔧 核心：超时配置（防止心跳超时）
  --conf spark.executor.heartbeatInterval=10s
  --conf spark.network.timeout=300s
  --conf spark.rpc.askTimeout=300s
  --conf spark.rpc.lookupTimeout=300s
  
  # 🔧 任务调度优化
  --conf spark.scheduler.mode=FAIR
  --conf spark.locality.wait=1s
  --conf spark.task.maxFailures=4
  
  # Shuffle 和并行度配置
  --conf spark.sql.shuffle.partitions=90
  --conf spark.executor.memoryOverhead=512m
  --conf spark.yarn.am.memory=512m
  --conf spark.driver.extraClassPath="$APP_JAR"
  --conf spark.executor.extraClassPath="$APP_JAR"
  --conf spark.default.parallelism=27
  
  # 自适应查询优化
  --conf spark.sql.adaptive.enabled=true
  --conf spark.sql.adaptive.coalescePartitions.enabled=true
  --conf spark.sql.adaptive.skewJoin.enabled=true
  
  # 序列化和压缩
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer
  --conf spark.kryoserializer.buffer.max=512m
  --conf spark.shuffle.compress=true
  --conf spark.shuffle.spill.compress=true
  --conf spark.io.compression.codec=snappy
  
  # 内存管理
  --conf spark.memory.fraction=0.8
  --conf spark.memory.storageFraction=0.3
  
  "$APP_JAR" --config "$CONF_FILE"
)

echo -e "${YELLOW}Submit Command (DEPLOY_MODE=$DEPLOY_MODE, DETACH=$DETACH)${NC}"
echo "${SUBMIT_CMD[@]}"

APP_ID_FILE="$LOG_DIR/batch-als-$TS.appid"

if [ "$DETACH" = "1" ]; then
  echo -e "${YELLOW}以后台模式运行，日志: $LOG_FILE${NC}"
  nohup "${SUBMIT_CMD[@]}" > "$LOG_FILE" 2>&1 &
  PID=$!
  echo $PID > "$LOG_DIR/batch-als-$TS.pid"
  echo -e "PID: $PID"
  if [ "$DEPLOY_MODE" = "cluster" ]; then
    echo -e "${YELLOW}尝试捕获 YARN ApplicationId...${NC}"
    sleep 5
    # 从日志中抓取 applicationId
    APP_ID=$(grep -oE 'application_[0-9_]+' "$LOG_FILE" | head -1)
    if [ -n "$APP_ID" ]; then
      echo "$APP_ID" > "$APP_ID_FILE"
      echo -e "ApplicationId: $APP_ID (保存在 $APP_ID_FILE)"
      echo -e "查看日志: yarn logs -applicationId $APP_ID"
    else
      echo -e "${YELLOW}未在日志中找到 ApplicationId，请稍后使用 yarn app -list 查看${NC}"
    fi
  fi
  echo -e "${GREEN}提交完成，作业在后台运行${NC}"
  exit 0
else
  if [ "$DEPLOY_MODE" = "cluster" ]; then
    # 前台 + cluster 模式：stdout 没有 Driver 日志，仅显示 submit 过程
    "${SUBMIT_CMD[@]}"
  else
    # client 模式：前台运行，输出实时日志
    "${SUBMIT_CMD[@]}" 2>&1 | tee "$LOG_FILE"
  fi
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ ALS 训练完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "耗时: $ELAPSED 秒"
echo ""
echo -e "查看推荐结果:"
echo -e "  mysql -u root -p movie -e \"SELECT * FROM recommendation WHERE algorithm='ALS' ORDER BY created_at DESC LIMIT 10;\""
echo -e "模型存储路径: 在 application.yaml 的 als.modelBasePath 下按版本号保存"
if [ -f "$APP_ID_FILE" ]; then
  echo -e "YARN ApplicationId: $(cat "$APP_ID_FILE")"
fi
echo ""

