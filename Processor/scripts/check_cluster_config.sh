#!/usr/bin/env bash
##############################################
# 三节点集群配置验证脚本
# 功能：验证主机名、网络、服务状态
##############################################

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  三节点集群配置验证${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. 检查主机名解析
echo -e "${YELLOW}[1/6] 检查主机名解析...${NC}"
HOSTS=("hadoop-master" "hadoop-worker1" "hadoop-worker2")
HOSTS_OK=true

for host in "${HOSTS[@]}"; do
    if ping -c 1 -W 2 $host &> /dev/null; then
        IP=$(ping -c 1 $host | grep -oP '(?<=\().*?(?=\))' | head -1)
        echo -e "  ${GREEN}✓ $host ($IP)${NC}"
    else
        echo -e "  ${RED}✗ $host 无法解析或 ping 不通${NC}"
        HOSTS_OK=false
    fi
done

if ! $HOSTS_OK; then
    echo -e "${RED}主机名解析失败！请检查 /etc/hosts 配置${NC}"
    echo ""
fi

# 2. 检查 Hadoop/YARN
echo ""
echo -e "${YELLOW}[2/6] 检查 Hadoop/YARN 状态...${NC}"
if command -v hdfs &> /dev/null; then
    if hdfs dfsadmin -report &> /dev/null; then
        echo -e "  ${GREEN}✓ HDFS 运行正常${NC}"
        LIVE_NODES=$(hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -oP '\d+')
        echo -e "    活跃 DataNode: $LIVE_NODES"
    else
        echo -e "  ${RED}✗ HDFS 未运行或无法连接${NC}"
    fi
    
    if yarn node -list 2>/dev/null | grep -q "Total Nodes"; then
        echo -e "  ${GREEN}✓ YARN 运行正常${NC}"
        yarn node -list 2>/dev/null | grep "Total Nodes"
    else
        echo -e "  ${RED}✗ YARN 未运行或无法连接${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  未找到 Hadoop 命令，请检查 HADOOP_HOME 环境变量${NC}"
fi

# 3. 检查 Kafka
echo ""
echo -e "${YELLOW}[3/6] 检查 Kafka 集群...${NC}"
KAFKA_BOOTSTRAP="hadoop-master:9092,hadoop-worker1:9092,hadoop-worker2:9092"

if [ -n "$KAFKA_HOME" ]; then
    # 检查 Broker 连接
    for host in "${HOSTS[@]}"; do
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/9092" 2>/dev/null; then
            echo -e "  ${GREEN}✓ $host:9092 可连接${NC}"
        else
            echo -e "  ${RED}✗ $host:9092 连接失败${NC}"
        fi
    done
    
    # 列出 Broker
    if command -v zookeeper-shell.sh &> /dev/null; then
        BROKERS=$(echo "ls /brokers/ids" | $KAFKA_HOME/bin/zookeeper-shell.sh hadoop-master:2181 2>/dev/null | tail -1)
        echo -e "  Broker IDs: $BROKERS"
    fi
else
    echo -e "  ${YELLOW}⚠️  KAFKA_HOME 未设置${NC}"
fi

# 4. 检查 MySQL
echo ""
echo -e "${YELLOW}[4/6] 检查 MySQL 连接...${NC}"
if command -v mysql &> /dev/null; then
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/hadoop-master/3306" 2>/dev/null; then
        echo -e "  ${GREEN}✓ MySQL (hadoop-master:3306) 可连接${NC}"
        
        # 尝试连接数据库
        if mysql -h hadoop-master -u root -p -e "USE movie; SELECT 'OK';" &> /dev/null; then
            echo -e "  ${GREEN}✓ movie 数据库可访问${NC}"
        else
            echo -e "  ${YELLOW}⚠️  无法访问 movie 数据库（可能需要密码）${NC}"
        fi
    else
        echo -e "  ${RED}✗ MySQL 连接失败${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  未安装 MySQL 客户端${NC}"
fi

# 5. 检查配置文件
echo ""
echo -e "${YELLOW}[5/6] 验证配置文件...${NC}"
PROJECT_DIR=$(cd $(dirname $0)/..; pwd)

# 检查 application.yaml
if [ -f "$PROJECT_DIR/src/main/resources/application.yaml" ]; then
    KAFKA_CONFIG=$(grep "bootstrapServers:" "$PROJECT_DIR/src/main/resources/application.yaml")
    MYSQL_HOST=$(grep "host:" "$PROJECT_DIR/src/main/resources/application.yaml" | grep -v "#" | head -1)
    echo -e "  application.yaml:"
    echo -e "    Kafka: $KAFKA_CONFIG"
    echo -e "    MySQL: $MYSQL_HOST"
fi

# 6. 检查 JAR 包
echo ""
echo -e "${YELLOW}[6/6] 检查 JAR 包...${NC}"
if [ -f "$PROJECT_DIR/target/recsys-processor-1.0.0.jar" ]; then
    JAR_SIZE=$(du -h "$PROJECT_DIR/target/recsys-processor-1.0.0.jar" | awk '{print $1}')
    echo -e "  ${GREEN}✓ JAR 包存在 ($JAR_SIZE)${NC}"
else
    echo -e "  ${RED}✗ JAR 包不存在，需要执行 mvn clean package${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  验证完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if $HOSTS_OK; then
    echo -e "${GREEN}✅ 主机名配置正确，可以继续部署${NC}"
else
    echo -e "${RED}❌ 请先配置 /etc/hosts，参考 CLUSTER_SETUP.md${NC}"
fi

echo ""

