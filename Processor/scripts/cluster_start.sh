#!/usr/bin/env bash
#############################################
# 大数据集群 - 基础设施启动脚本
# 功能：启动 Hadoop、Kafka 等基础组件
# 使用：在 hadoop-master 节点执行
#############################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  大数据集群 - 基础设施启动中...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查是否在 master 节点
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" != *"master"* ]]; then
    echo -e "${YELLOW}⚠️  警告: 建议在 master 节点执行此脚本${NC}"
    echo -e "${YELLOW}   当前主机: $HOSTNAME${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

#############################################
# 1. 启动 Hadoop (HDFS + YARN)
#############################################
echo -e "${YELLOW}[1/4] 启动 Hadoop 集群...${NC}"

# 检查 HDFS 是否已运行
if jps | grep -q "NameNode"; then
    echo -e "${GREEN}   ✓ HDFS 已在运行${NC}"
else
    echo -e "   启动 HDFS (NameNode, DataNode, SecondaryNameNode)..."
    if command -v start-dfs.sh &> /dev/null; then
        start-dfs.sh
        sleep 5
        echo -e "${GREEN}   ✓ HDFS 启动完成${NC}"
    else
        echo -e "${RED}   ❌ 找不到 start-dfs.sh 命令${NC}"
        echo -e "   请检查 HADOOP_HOME 是否配置正确: $HADOOP_HOME"
        exit 1
    fi
fi

# 检查 YARN 是否已运行
if jps | grep -q "ResourceManager"; then
    echo -e "${GREEN}   ✓ YARN 已在运行${NC}"
else
    echo -e "   启动 YARN (ResourceManager, NodeManager)..."
    if command -v start-yarn.sh &> /dev/null; then
        start-yarn.sh
        sleep 5
        echo -e "${GREEN}   ✓ YARN 启动完成${NC}"
    else
        echo -e "${RED}   ❌ 找不到 start-yarn.sh 命令${NC}"
        exit 1
    fi
fi

#############################################
# 2. 启动 ZooKeeper (如果未运行)
#############################################
echo ""
echo -e "${YELLOW}[2/4] 检查 ZooKeeper 状态...${NC}"

if jps | grep -q "QuorumPeerMain"; then
    echo -e "${GREEN}   ✓ ZooKeeper 已在运行${NC}"
else
    echo -e "   ZooKeeper 未运行，尝试启动..."
    if [ -d "/opt/kafka" ]; then
        cd /opt/kafka
        if [ -f "config/zookeeper.properties" ]; then
            nohup bin/zookeeper-server-start.sh config/zookeeper.properties > logs/zookeeper.log 2>&1 &
            sleep 5
            echo -e "${GREEN}   ✓ ZooKeeper 启动完成${NC}"
        else
            echo -e "${YELLOW}   ⚠️  找不到 zookeeper.properties，请手动启动 ZooKeeper${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  找不到 Kafka 目录，请手动启动 ZooKeeper${NC}"
    fi
fi

#############################################
# 3. 启动 Kafka
#############################################
echo ""
echo -e "${YELLOW}[3/4] 检查 Kafka 状态...${NC}"

if jps | grep -q "Kafka"; then
    echo -e "${GREEN}   ✓ Kafka 已在运行${NC}"
else
    echo -e "   Kafka 未运行，尝试启动..."
    if [ -d "/opt/kafka" ]; then
        cd /opt/kafka
        if [ -f "config/server.properties" ]; then
            nohup bin/kafka-server-start.sh config/server.properties > logs/kafka-master.log 2>&1 &
            sleep 8
            echo -e "${GREEN}   ✓ Kafka 启动完成${NC}"
        else
            echo -e "${RED}   ❌ 找不到 server.properties${NC}"
            exit 1
        fi
    else
        echo -e "${RED}   ❌ 找不到 Kafka 目录${NC}"
        exit 1
    fi
fi

#############################################
# 4. 启动 Spark History Server (可选)
#############################################
echo ""
echo -e "${YELLOW}[4/4] 启动 Spark History Server...${NC}"

if jps | grep -q "HistoryServer"; then
    echo -e "${GREEN}   ✓ Spark History Server 已在运行${NC}"
else
    if [ -n "$SPARK_HOME" ] && [ -d "$SPARK_HOME" ]; then
        if [ -f "$SPARK_HOME/sbin/start-history-server.sh" ]; then
            $SPARK_HOME/sbin/start-history-server.sh
            sleep 3
            echo -e "${GREEN}   ✓ Spark History Server 启动完成${NC}"
        else
            echo -e "${YELLOW}   ⚠️  找不到 start-history-server.sh，跳过${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  SPARK_HOME 未配置，跳过 History Server${NC}"
    fi
fi

#############################################
# 验证服务状态
#############################################
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ✅ 集群基础设施启动完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}运行中的服务：${NC}"
jps | grep -v "Jps"
echo ""

# 提供访问链接
echo -e "${GREEN}Web 界面：${NC}"
echo -e "  HDFS NameNode:        http://hadoop-master:9870"
echo -e "  YARN ResourceManager: http://hadoop-master:8088"
echo -e "  Spark History:        http://hadoop-master:18080"
echo ""

echo -e "${YELLOW}⚠️  注意事项：${NC}"
echo -e "  1. 如果是集群模式，请确保 worker 节点上的服务也已启动"
echo -e "  2. 可以在 worker 节点上单独启动 ZooKeeper 和 Kafka"
echo -e "  3. 检查各节点状态: ssh hadoop-worker1 jps"
echo ""

echo -e "${GREEN}下一步：${NC}"
echo -e "  启动应用服务: cd /opt/Processor/scripts && ./start_all.sh"
echo ""

