# 集群启动和停止命令手册

## 📋 目录

1. [集群架构](#集群架构)
2. [完整启动流程](#完整启动流程)
3. [完整停止流程](#完整停止流程)
4. [常用命令](#常用命令)
5. [故障排查](#故障排查)

---

## 🏗 集群架构

### 节点配置
- **hadoop-master**: Master 节点
- **hadoop-worker1**: Worker 节点 1
- **hadoop-worker2**: Worker 节点 2

### 组件分布

| 组件 | Master | Worker1 | Worker2 | 说明 |
|------|--------|---------|---------|------|
| Flink | ✓ | ✓ | ✓ | 分布式计算框架 |
| ZooKeeper | ✓ | ✓ | ✓ | 集群模式（3节点） |
| Kafka | ✓ | ✓ | ✓ | 集群模式（3节点） |
| HDFS NameNode | ✓ | - | - | 主节点 |
| HDFS DataNode | ✓ | ✓ | ✓ | 数据节点 |
| HDFS SecondaryNameNode | ✓ | - | - | 备份节点 |
| YARN ResourceManager | ✓ | - | - | 资源管理 |
| YARN NodeManager | ✓ | ✓ | ✓ | 任务执行 |
| Spark History Server | ✓ | - | - | 可选 |

---

## 🚀 完整启动流程

### 方式一：使用脚本（推荐）

#### 1. 启动集群基础设施
```bash
# 在 hadoop-master 上执行
cd /opt/Processor/scripts
./cluster_start.sh
```

#### 2. 启动应用服务
```bash
# 在 hadoop-master 上执行
cd /opt/Processor/scripts
./start_all.sh
```

### 方式二：手动启动（详细步骤）

#### 步骤 1：启动 ZooKeeper（在所有节点）

**在 hadoop-master 上：**
```bash
cd /opt/kafka
nohup bin/zookeeper-server-start.sh config/zookeeper.properties > logs/zookeeper.log 2>&1 &
```

**在 hadoop-worker1 上：**
```bash
ssh hadoop-worker1
cd /opt/kafka
nohup bin/zookeeper-server-start.sh config/zookeeper.properties > logs/zookeeper.log 2>&1 &
```

**在 hadoop-worker2 上：**
```bash
ssh hadoop-worker2
cd /opt/kafka
nohup bin/zookeeper-server-start.sh config/zookeeper.properties > logs/zookeeper.log 2>&1 &
```

#### 步骤 2：启动 Hadoop（在 master 节点）

```bash
# 启动 HDFS
start-dfs.sh

# 启动 YARN
start-yarn.sh

# 或者一次性启动（不推荐生产环境）
# start-all.sh
```

#### 步骤 3：启动 Kafka（在所有节点）

**在 hadoop-master 上：**
```bash
cd /opt/kafka
nohup bin/kafka-server-start.sh config/server.properties > logs/kafka-master.log 2>&1 &
```

**在 hadoop-worker1 上：**
```bash
ssh hadoop-worker1
cd /opt/kafka
nohup bin/kafka-server-start.sh config/server.properties > logs/kafka-worker1.log 2>&1 &
```

**在 hadoop-worker2 上：**
```bash
ssh hadoop-worker2
cd /opt/kafka
nohup bin/kafka-server-start.sh config/server.properties > logs/kafka-worker2.log 2>&1 &
```

#### 步骤 4：启动 Flink

```bash
# 在 hadoop-master 上启动 Flink 集群
cd /opt/flink-1.17.0
nohup bin/start-cluster.sh > logs/flink-start.log 2>&1 &
```

#### 步骤 5：启动 Spark History Server（可选）

```bash
/opt/spark/sbin/start-history-server.sh
```

#### 步骤 6：验证服务状态

```bash
# 在 master 节点
jps

# 应该看到：
# - StandaloneSessionClusterEntrypoint (Flink JobManager)
# - TaskManagerRunner (Flink TaskManager)
# - QuorumPeerMain (ZooKeeper)
# - NameNode
# - DataNode
# - SecondaryNameNode
# - ResourceManager
# - NodeManager
# - Kafka
# - HistoryServer (如果启动了)
```

#### 步骤 7：启动应用服务

```bash
cd /opt/Processor/scripts
./start_all.sh
```

---

## 🛑 完整停止流程

### 方式一：使用脚本（推荐）

#### 1. 停止应用服务
```bash
# 在 hadoop-master 上执行
cd /opt/Processor/scripts
./stop_all.sh
```

#### 2. 停止集群基础设施
```bash
# 在 hadoop-master 上执行
cd /opt/Processor/scripts
./cluster_stop.sh
```

### 方式二：手动停止（详细步骤）

#### 步骤 1：停止应用服务
```bash
cd /opt/Processor/scripts
./stop_all.sh
```

#### 步骤 2：停止 Flink
```bash
cd /opt/flink-1.17.0
bin/stop-cluster.sh
```

#### 步骤 3：停止 Spark History Server
```bash
/opt/spark/sbin/stop-history-server.sh
```

#### 步骤 4：停止 Kafka（在所有节点）

**在所有节点上执行：**
```bash
cd /opt/kafka
bin/kafka-server-stop.sh
```

#### 步骤 5：停止 Hadoop（在 master 节点）

```bash
# 停止 YARN
stop-yarn.sh

# 停止 HDFS
stop-dfs.sh

# 或者一次性停止
# stop-all.sh
```

#### 步骤 6：停止 ZooKeeper（在所有节点）

**在所有节点上执行：**
```bash
cd /opt/kafka
bin/zookeeper-server-stop.sh
```

---

## 🔧 常用命令

### 查看服务状态

```bash
# 查看所有 Java 进程
jps

# 查看 HDFS 状态
hdfs dfsadmin -report

# 查看 YARN 节点状态
yarn node -list

# 查看 Kafka 主题
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server hadoop-master:9092

# 查看 Kafka 消费组
/opt/kafka/bin/kafka-consumer-groups.sh --list --bootstrap-server hadoop-master:9092
```

### 检查集群健康状态

```bash
# 在所有节点上检查进程
for node in hadoop-master hadoop-worker1 hadoop-worker2; do
    echo "=== $node ==="
    ssh $node jps
    echo ""
done
```

### Web 界面访问

- **Flink Web UI**: http://hadoop-master:8081
- **HDFS NameNode UI**: http://hadoop-master:9870
- **YARN ResourceManager UI**: http://hadoop-master:8088
- **Spark History Server**: http://hadoop-master:18080
- **Spark Application UI**: http://hadoop-master:4040 (应用运行时)

### 日志查看

```bash
# Hadoop 日志
tail -f $HADOOP_HOME/logs/hadoop-*-namenode-*.log
tail -f $HADOOP_HOME/logs/hadoop-*-resourcemanager-*.log

# Kafka 日志
tail -f /opt/kafka/logs/server.log
tail -f /opt/kafka/logs/zookeeper.log

# Flink 日志
tail -f /opt/flink-1.17.0/log/flink-*.log

# 应用日志
tail -f /opt/Processor/logs/movies-ingest.log
tail -f /opt/Processor/logs/ratings-ingest.log
tail -f /opt/Processor/logs/tmdb-fetcher.log
```

---

## 🔍 故障排查

### 1. ZooKeeper 无法启动

**检查端口占用：**
```bash
netstat -tuln | grep 2181
```

**检查日志：**
```bash
tail -100 /opt/kafka/logs/zookeeper.log
```

### 2. Kafka 无法启动

**常见原因：**
- ZooKeeper 未启动
- broker.id 重复
- 端口冲突

**检查配置：**
```bash
grep broker.id /opt/kafka/config/server.properties
grep zookeeper.connect /opt/kafka/config/server.properties
```

### 3. HDFS SafeMode 问题

```bash
# 查看 SafeMode 状态
hdfs dfsadmin -safemode get

# 手动离开 SafeMode（谨慎使用）
hdfs dfsadmin -safemode leave
```

### 4. YARN 应用提交失败

```bash
# 查看 YARN 日志
yarn logs -applicationId <application_id>

# 检查可用资源
yarn node -list -all
```

### 5. 强制清理所有进程（谨慎使用）

```bash
# 停止所有 Java 进程
pkill -9 java

# 清理临时文件
rm -f /tmp/*.pid
rm -f /opt/Processor/logs/*.pid
```

---

## 📝 注意事项

1. **启动顺序很重要**：必须按照 Flink → ZooKeeper → Hadoop → Kafka → 应用 的顺序启动
2. **集群模式**：在 worker 节点上也需要启动相应的服务
3. **防火墙**：确保节点之间的端口互通
4. **磁盘空间**：定期清理日志文件，避免磁盘占满
5. **内存管理**：注意 Java 堆内存配置，避免 OOM

---

## 📞 快速参考

### 一键启动（全部）
```bash
# 在 hadoop-master 执行
cd /opt/Processor/scripts
./cluster_start.sh && ./start_all.sh
```

### 一键停止（全部）
```bash
# 在 hadoop-master 执行
cd /opt/Processor/scripts
./stop_all.sh && ./cluster_stop.sh
```

### 重启集群
```bash
# 停止
cd /opt/Processor/scripts
./stop_all.sh && ./cluster_stop.sh

# 等待 10 秒
sleep 10

# 启动
./cluster_start.sh && ./start_all.sh
```

---

**最后更新时间**: 2025-11-11

