#!/usr/bin/env bash
#############################################
# 电影推荐系统 - 一键停止脚本（基于YARN）
# 功能：通过YARN API停止所有运行中的Spark作业
#############################################

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  电影推荐系统 - 停止中...${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

PROJECT_DIR=$(cd $(dirname $0)/..; pwd)
LOG_DIR=$PROJECT_DIR/logs

# 检查YARN是否可用
if ! command -v yarn &> /dev/null; then
    echo -e "${RED}❌ 错误: yarn命令未找到${NC}"
    echo -e "${YELLOW}尝试使用进程名停止...${NC}"
    pkill -f "recsys-processor"
    exit 1
fi

# 定义要停止的作业名称
JOB_NAMES=("RatingsIngestJob" "RealtimeRecBackfillJob" "MoviesIngestJob")
Stopped_count=0

echo -e "${YELLOW}[1/4] 查询YARN上运行中的应用...${NC}"
YARN_APPS=$(yarn application -list -appStates RUNNING 2>/dev/null | grep -E "RatingsIngestJob|RealtimeRecBackfillJob|MoviesIngestJob")

if [ -z "$YARN_APPS" ]; then
    echo -e "${YELLOW}   ℹ️  未发现运行中的推荐系统作业${NC}"
else
    echo -e "${GREEN}   ✓ 发现以下运行中的作业：${NC}"
    echo "$YARN_APPS" | awk '{print "     - " $2 " (" $1 ")"}'
fi

echo ""
echo -e "${YELLOW}[2/4] 停止Spark Streaming作业...${NC}"

# 遍历每个作业类型
for JOB_NAME in "${JOB_NAMES[@]}"; do
    # 查找该作业的Application ID
    APP_IDS=$(yarn application -list -appStates RUNNING 2>/dev/null | grep "$JOB_NAME" | awk '{print $1}')
    
    if [ -n "$APP_IDS" ]; then
        echo -e "${YELLOW}   停止 $JOB_NAME...${NC}"
        # 可能有多个相同名称的应用，逐个停止
        echo "$APP_IDS" | while read APP_ID; do
            if [ -n "$APP_ID" ]; then
                echo -e "     杀死应用: $APP_ID"
                yarn application -kill "$APP_ID" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}     ✓ 已停止 $APP_ID${NC}"
                    Stopped_count=$((Stopped_count + 1))
                else
                    echo -e "${RED}     ✗ 停止失败 $APP_ID${NC}"
                fi
            fi
        done
    fi
done

# 等待应用完全停止
sleep 2

echo ""
echo -e "${YELLOW}[3/4] 清理本地SparkSubmit进程...${NC}"
# 查找本地的SparkSubmit进程（driver进程）
SPARK_PIDS=$(jps 2>/dev/null | grep -E "SparkSubmit" | awk '{print $1}')
if [ -n "$SPARK_PIDS" ]; then
    echo "$SPARK_PIDS" | while read PID; do
        # 检查是否是我们的recsys作业
        CMD=$(ps -p $PID -o cmd= 2>/dev/null | grep -E "recsys-processor|RatingsIngestJob|RealtimeRecBackfillJob|MoviesIngestJob")
        if [ -n "$CMD" ]; then
            echo -e "   停止本地Driver进程: $PID"
            kill -15 $PID 2>/dev/null
            sleep 1
            # 如果还存在，强制杀死
            if kill -0 $PID 2>/dev/null; then
                echo -e "   强制停止: $PID"
                kill -9 $PID 2>/dev/null
            fi
            echo -e "${GREEN}   ✓ 已停止本地进程 $PID${NC}"
        fi
    done
else
    echo -e "${YELLOW}   ℹ️  未发现本地SparkSubmit进程${NC}"
fi

echo ""
echo -e "${YELLOW}[4/4] 停止TMDB拉取器（Python进程）...${NC}"
# 停止TMDB拉取器（如果有）
if pgrep -f "tmdb_data_fetcher.py" > /dev/null; then
    pkill -f "tmdb_data_fetcher.py"
    echo -e "${GREEN}   ✓ TMDB拉取器已停止${NC}"
else
    echo -e "${YELLOW}   ℹ️  TMDB拉取器未运行${NC}"
fi

# 清理所有PID文件
echo ""
echo -e "${YELLOW}清理PID文件...${NC}"
rm -f $LOG_DIR/*.pid 2>/dev/null
echo -e "${GREEN}   ✓ PID文件已清理${NC}"

# 最终验证
echo ""
echo -e "${YELLOW}验证停止结果...${NC}"
REMAINING=$(yarn application -list -appStates RUNNING 2>/dev/null | grep -E "RatingsIngestJob|RealtimeRecBackfillJob|MoviesIngestJob")
if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}   ✓ 所有Spark作业已完全停止${NC}"
else
    echo -e "${RED}   ⚠️  仍有作业在运行：${NC}"
    echo "$REMAINING" | awk '{print "     - " $2 " (" $1 ")"}'
    echo -e "${YELLOW}   请手动执行: yarn application -kill <application_id>${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 停止流程完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "查看YARN应用状态："
echo -e "  yarn application -list"
echo ""
echo -e "查看本地Spark进程："
echo -e "  jps | grep Spark"
echo ""
echo -e "提示: Kafka 仍在运行（需要手动停止）"
echo -e "提示: MySQL 仍在运行（需要手动停止）"
echo ""

