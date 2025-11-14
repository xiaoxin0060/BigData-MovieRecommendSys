#!/usr/bin/env bash
#############################################
# 电影推荐系统 - 一键停止脚本
# 功能：停止所有运行中的组件
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

# 停止 TMDB 拉取器
echo -e "${YELLOW}[1/3] 停止 TMDB 拉取器...${NC}"
if [ -f "$LOG_DIR/tmdb-fetcher.pid" ]; then
    TMDB_PID=$(cat $LOG_DIR/tmdb-fetcher.pid)
    if kill -0 $TMDB_PID 2>/dev/null; then
        kill $TMDB_PID
        echo -e "${GREEN}   ✓ TMDB 拉取器已停止 (PID: $TMDB_PID)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  TMDB 拉取器未运行${NC}"
    fi
    rm -f $LOG_DIR/tmdb-fetcher.pid
else
    echo -e "${YELLOW}   ⚠️  找不到 TMDB 拉取器 PID 文件${NC}"
fi

# 停止 RatingsIngestJob
echo ""
echo -e "${YELLOW}[2/4] 停止 RatingsIngestJob...${NC}"
if [ -f "$LOG_DIR/ratings-ingest.pid" ]; then
    RATINGS_PID=$(cat $LOG_DIR/ratings-ingest.pid)
    if kill -0 $RATINGS_PID 2>/dev/null; then
        kill $RATINGS_PID
        echo -e "${GREEN}   ✓ RatingsIngestJob 已停止 (PID: $RATINGS_PID)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  RatingsIngestJob 未运行${NC}"
    fi
    rm -f $LOG_DIR/ratings-ingest.pid
else
    echo -e "${YELLOW}   ⚠️  找不到 RatingsIngestJob PID 文件${NC}"
fi

# 停止 MoviesIngestJob
echo ""
echo -e "${YELLOW}[3/4] 停止 MoviesIngestJob...${NC}"
if [ -f "$LOG_DIR/movies-ingest.pid" ]; then
    MOVIES_PID=$(cat $LOG_DIR/movies-ingest.pid)
    if kill -0 $MOVIES_PID 2>/dev/null; then
        kill $MOVIES_PID
        echo -e "${GREEN}   ✓ MoviesIngestJob 已停止 (PID: $MOVIES_PID)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  MoviesIngestJob 未运行${NC}"
    fi
    rm -f $LOG_DIR/movies-ingest.pid
else
    echo -e "${YELLOW}   ⚠️  找不到 MoviesIngestJob PID 文件${NC}"
fi

# 停止 RealtimeRecBackfillJob
echo ""
echo -e "${YELLOW}[4/4] 停止 RealtimeRecBackfillJob...${NC}"
if [ -f "$LOG_DIR/realtime-rec-backfill.pid" ]; then
    REALTIME_PID=$(cat $LOG_DIR/realtime-rec-backfill.pid)
    if kill -0 $REALTIME_PID 2>/dev/null; then
        kill $REALTIME_PID
        echo -e "${GREEN}   ✓ RealtimeRecBackfillJob 已停止 (PID: $REALTIME_PID)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  RealtimeRecBackfillJob 未运行${NC}"
    fi
    rm -f $LOG_DIR/realtime-rec-backfill.pid
else
    echo -e "${YELLOW}   ⚠️  找不到 RealtimeRecBackfillJob PID 文件${NC}"
fi

# 额外清理：停止所有相关的 Spark 进程（可选，谨慎使用）
# 如果 PID 文件丢失，可以取消下面的注释来强制停止
# echo ""
# echo -e "${YELLOW}清理残留的 Spark 进程...${NC}"
# pkill -f "recsys-processor" || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 所有组件已停止！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "提示: Kafka 仍在运行（需要手动停止）"
echo -e "提示: MySQL 仍在运行（需要手动停止）"
echo ""

