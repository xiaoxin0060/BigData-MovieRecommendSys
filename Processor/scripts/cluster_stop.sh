#!/usr/bin/env bash
#############################################
# 大数据集群 - 基础设施停止脚本
# 功能：停止 Hadoop、Kafka 等基础组件
# 使用：在 hadoop-master 节点执行
#############################################

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  大数据集群 - 基础设施停止中...${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# 检查是否在 master 节点
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" != *"master"* ]]; then
    echo -e "${YELLOW}⚠️  警告: 建议在 master 节点执行此脚本${NC}"
    echo -e "${YELLOW}   当前主机: $HOSTNAME${NC}"
fi

#############################################
# 1. 停止 Spark History Server
#############################################
echo -e "${YELLOW}[1/4] 停止 Spark History Server...${NC}"

if jps | grep -q "HistoryServer"; then
    if [ -n "$SPARK_HOME" ] && [ -f "$SPARK_HOME/sbin/stop-history-server.sh" ]; then
        $SPARK_HOME/sbin/stop-history-server.sh
        sleep 2
        echo -e "${GREEN}   ✓ Spark History Server 已停止${NC}"
    else
        echo -e "${YELLOW}   ⚠️  找不到停止脚本，尝试手动停止...${NC}"
        pkill -f "org.apache.spark.deploy.history.HistoryServer" || true
    fi
else
    echo -e "${GREEN}   ✓ Spark History Server 未运行${NC}"
fi

#############################################
# 2. 停止 Kafka
#############################################
echo ""
echo -e "${YELLOW}[2/4] 停止 Kafka...${NC}"

if jps | grep -q "Kafka"; then
    if [ -d "/opt/kafka" ]; then
        cd /opt/kafka
        bin/kafka-server-stop.sh
        sleep 5
        echo -e "${GREEN}   ✓ Kafka 已停止${NC}"
    else
        echo -e "${YELLOW}   ⚠️  找不到 Kafka 目录，尝试强制停止...${NC}"
        pkill -f "kafka.Kafka" || true
    fi
else
    echo -e "${GREEN}   ✓ Kafka 未运行${NC}"
fi

#############################################
# 3. 停止 Hadoop (YARN + HDFS)
#############################################
echo ""
echo -e "${YELLOW}[3/4] 停止 Hadoop 集群...${NC}"

# 停止 YARN
if jps | grep -q "ResourceManager\|NodeManager"; then
    echo -e "   停止 YARN..."
    if command -v stop-yarn.sh &> /dev/null; then
        stop-yarn.sh
        sleep 3
        echo -e "${GREEN}   ✓ YARN 已停止${NC}"
    else
        echo -e "${RED}   ❌ 找不到 stop-yarn.sh 命令${NC}"
    fi
else
    echo -e "${GREEN}   ✓ YARN 未运行${NC}"
fi

# 停止 HDFS
if jps | grep -q "NameNode\|DataNode"; then
    echo -e "   停止 HDFS..."
    if command -v stop-dfs.sh &> /dev/null; then
        stop-dfs.sh
        sleep 3
        echo -e "${GREEN}   ✓ HDFS 已停止${NC}"
    else
        echo -e "${RED}   ❌ 找不到 stop-dfs.sh 命令${NC}"
    fi
else
    echo -e "${GREEN}   ✓ HDFS 未运行${NC}"
fi

#############################################
# 4. 停止 ZooKeeper
#############################################
echo ""
echo -e "${YELLOW}[4/4] 停止 ZooKeeper...${NC}"

if jps | grep -q "QuorumPeerMain"; then
    if [ -d "/opt/kafka" ]; then
        cd /opt/kafka
        bin/zookeeper-server-stop.sh
        sleep 3
        echo -e "${GREEN}   ✓ ZooKeeper 已停止${NC}"
    else
        echo -e "${YELLOW}   ⚠️  找不到 Kafka 目录，尝试强制停止...${NC}"
        pkill -f "org.apache.zookeeper.server.quorum.QuorumPeerMain" || true
    fi
else
    echo -e "${GREEN}   ✓ ZooKeeper 未运行${NC}"
fi

#############################################
# 验证停止状态
#############################################
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ✅ 集群基础设施停止完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查是否还有残留进程
REMAINING=$(jps | grep -v "Jps" | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  仍有进程在运行：${NC}"
    jps | grep -v "Jps"
    echo ""
    echo -e "${YELLOW}如需强制停止所有 Java 进程（谨慎使用）：${NC}"
    echo -e "  pkill -9 java"
else
    echo -e "${GREEN}✓ 所有服务已停止${NC}"
fi
echo ""

echo -e "${YELLOW}提示：${NC}"
echo -e "  - 如果是集群模式，请在 worker 节点上也执行相应的停止操作"
echo -e "  - MySQL 等数据库服务不会被停止，需要手动管理"
echo ""

