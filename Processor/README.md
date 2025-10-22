# 电影推荐系统 - 数据处理端 (Processor)

## 架构总览

```
┌─────────────────┐
│  MovieLens CSV  │  (一次性冷启动数据)
└────────┬────────┘
         │
         ↓ (一次性导入脚本)
┌─────────────────────────────────────────────────────────┐
│                        MySQL                             │
│  ┌──────┐  ┌──────┐  ┌────────┐  ┌────────────────┐   │
│  │ user │  │movie │  │ rating │  │recommendation │   │
│  └──────┘  └──────┘  └────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────┘
         ↑                    ↑                    ↑
         │                    │                    │
    (实时更新)            (实时写入)          (批量写入)
         │                    │                    │
┌────────┴────────┐  ┌────────┴────────┐  ┌───────┴───────┐
│  Spark Stream   │  │  Spark Stream   │  │  Spark Batch  │
│ (电影元数据)     │  │  (评分入库)      │  │  (ALS训练)    │
└────────┬────────┘  └────────┬────────┘  └───────────────┘
         │                    │                    
         │                    │                    
    ┌────┴────────────────────┴────┐              
    │          Kafka               │              
    │  ┌───────┐      ┌─────────┐ │              
    │  │movies │      │ ratings │ │              
    │  └───────┘      └─────────┘ │              
    └────┬────────────────┬────────┘              
         │                │                        
         │                │                        
┌────────┴────────┐  ┌────┴────────┐              
│  Python 爬虫    │  │  Python 爬虫 │              
│  (电影元数据)    │  │  (用户评分)  │              
└─────────────────┘  └──────────────┘              
         │                │                        
         └────────────────┴─────> 豆瓣/猫眼/IMDB   
```

---

## 组件与职责

### 1. 批处理（离线训练）
- **BatchAlsJob.java**
  - 从 MySQL `rating` 表读取历史评分
  - 使用 Spark MLlib ALS 算法训练推荐模型
  - 为每个用户生成 TopN 推荐，写入 `recommendation` 表（algorithm='ALS'）
  - 调度：每天定时触发（crontab/Airflow）

### 2. 流处理（实时数据）
- **MoviesIngestJob.java**
  - 从 Kafka `movies` 主题消费电影元数据事件
  - 幂等写入 `movie` 表（唯一键：tmdbId）
  - 实时更新电影详情（导演、演员、海报、描述等）
  - 使用 HDFS checkpoint，支持故障恢复
  - 运行模式：常驻 7x24

- **RatingsIngestJob.java**
  - 从 Kafka `ratings` 主题消费实时评分事件
  - 幂等写入 `rating` 表（唯一键：userId + movieId）
  - 增量更新 `movie.avgRating` 和 `movie.ratingCount`
  - 使用 HDFS checkpoint，支持故障恢复
  - 运行模式：常驻 7x24

### 3. 数据导入（一次性）
- **import_movielens.py**
  - 将 `archive/ml-25m/` 下的 CSV 导入 MySQL
  - 建立 MovieLens ID 与内部 ID 的映射
  - 计算初始的电影聚合指标

### 4. 实时数据源
- **tmdb_data_fetcher.py（TMDB API 数据拉取器）**⭐ **推荐使用**
  - 使用 TMDB 官方 API 获取真实电影数据（合法合规）
  - 拉取热门、高分、正在上映电影的元数据
  - 基于真实评分分布生成模拟评分流
  - 自动推送到 Kafka `movies` 和 `ratings` 主题
  - 详细文档：[TMDB_GUIDE.md](scripts/TMDB_GUIDE.md)
  
- **kafka_producer_test.py（测试工具）**
  - 模拟实时评分流，用于快速测试 Spark Streaming 功能
  - 每隔 N 秒生成随机评分事件并推送到 Kafka
  
- **Python 爬虫（可选，需自行实现）**
  - 定时爬取豆瓣/猫眼等平台的评分与电影信息
  - 将数据推送到 Kafka（`ratings` 和 `movies` 主题）
  - 推荐框架：Scrapy、Selenium
  - ⚠️ 注意遵守网站 robots.txt 与法律法规

---

## 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Hadoop | 3.3.6 | HDFS 存储 + YARN 资源管理 |
| Spark | 3.5.1 (Scala 2.12) | 批处理 + 流处理 |
| Kafka | 3.x | 实时消息队列 |
| MySQL | 8.x | 结果存储与前端数据源 |
| JDK | 11/17 | Java 运行环境 |
| Maven | 3.8+ | 项目构建 |

---

## 快速开始

### 环境准备

1. **安装 Spark**
```bash
# 下载预编译版（Hadoop 3）
wget https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz
tar -xzf spark-3.5.1-bin-hadoop3.tgz
export SPARK_HOME=/path/to/spark-3.5.1-bin-hadoop3
export PATH=$SPARK_HOME/bin:$PATH
```

2. **安装 Kafka**
```bash
# 下载并解压
wget https://archive.apache.org/dist/kafka/3.6.0/kafka_2.13-3.6.0.tgz
tar -xzf kafka_2.13-3.6.0.tgz
cd kafka_2.13-3.6.0

# 启动 Zookeeper（Kafka 依赖）
bin/zookeeper-server-start.sh config/zookeeper.properties &

# 启动 Kafka Broker
bin/kafka-server-start.sh config/server.properties &

# 创建主题
bin/kafka-topics.sh --create --topic ratings --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
bin/kafka-topics.sh --create --topic movies --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

3. **配置 MySQL**
```bash
# 执行表结构初始化
mysql -u root -p < ../Receiver/sql/init.sql
```

4. **修改配置文件**
```bash
# 编辑 src/main/resources/application.yaml
# 修改 mysql.host, mysql.user, mysql.password
# 修改 kafka.bootstrapServers
```

---

### 一次性数据导入

```bash
cd Processor

# 安装 Python 依赖
pip install pymysql

# 执行导入（需修改脚本中的 MySQL 配置）
python scripts/import_movielens.py

# 预计耗时：5-15 分钟（取决于硬件）
# 完成后：
#   - user 表：约 162,541 个用户
#   - movie 表：约 62,423 部电影
#   - rating 表：约 25,000,095 条评分
```

---

### 构建与打包

```bash
cd Processor
mvn clean package -DskipTests

# 生成：target/recsys-processor-1.0.0.jar
```

---

### 运行批训练 ALS

```bash
# 本地模式（开发测试）
spark-submit \
  --master local[*] \
  --class com.yourorg.recsys.batch.BatchAlsJob \
  --conf spark.sql.shuffle.partitions=200 \
  target/recsys-processor-1.0.0.jar

# YARN Cluster 模式（生产）
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --class com.yourorg.recsys.batch.BatchAlsJob \
  --conf spark.sql.shuffle.partitions=200 \
  --driver-memory 4g \
  --executor-memory 4g \
  --executor-cores 2 \
  --num-executors 4 \
  target/recsys-processor-1.0.0.jar

# 定时调度（crontab 示例）
# 每天凌晨 2 点执行
0 2 * * * /path/to/spark-submit ... >> /var/log/als-job.log 2>&1
```

---

### 运行流式电影元数据入库

```bash
# 本地模式（开发测试）
spark-submit \
  --master local[*] \
  --class com.yourorg.recsys.streaming.MoviesIngestJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --conf spark.sql.shuffle.partitions=50 \
  target/recsys-processor-1.0.0.jar

# YARN Cluster 模式（生产，常驻运行）
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --class com.yourorg.recsys.streaming.MoviesIngestJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --conf spark.sql.shuffle.partitions=50 \
  --conf spark.streaming.stopGracefullyOnShutdown=true \
  --driver-memory 2g \
  --executor-memory 2g \
  --executor-cores 2 \
  --num-executors 2 \
  target/recsys-processor-1.0.0.jar
```

---

### 运行流式评分入库

```bash
# 本地模式（开发测试）
spark-submit \
  --master local[*] \
  --class com.yourorg.recsys.streaming.RatingsIngestJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --conf spark.sql.shuffle.partitions=50 \
  target/recsys-processor-1.0.0.jar

# YARN Cluster 模式（生产，常驻运行）
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --class com.yourorg.recsys.streaming.RatingsIngestJob \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1 \
  --conf spark.sql.shuffle.partitions=50 \
  --conf spark.streaming.stopGracefullyOnShutdown=true \
  --driver-memory 2g \
  --executor-memory 2g \
  --executor-cores 2 \
  --num-executors 2 \
  target/recsys-processor-1.0.0.jar

# 查看 Spark UI 监控
# http://<yarn-rm-host>:8088
```

---

### 测试实时评分流

```bash
# 安装 Python Kafka 客户端
pip install kafka-python

# 启动测试 Producer（模拟实时评分）
python scripts/kafka_producer_test.py

# 输出示例：
# [0001] 14:35:22 | User  123 -> Movie   45 | Rating: 4.5
# [0002] 14:35:24 | User  456 -> Movie  789 | Rating: 3.0
# ...

# 验证数据写入 MySQL
mysql -u root -p movie -e "SELECT * FROM rating ORDER BY id DESC LIMIT 10;"
mysql -u root -p movie -e "SELECT id, title, avgRating, ratingCount FROM movie WHERE ratingCount > 0 LIMIT 10;"
```

---

## 实时数据流详解

### 数据流向
```
TMDB 拉取器
  ├─→ 电影元数据流
  │   {"tmdbId":"278", "title":"肖申克的救赎", "director":"弗兰克·德拉邦特"...}
  │   → Kafka movies 主题
  │   → Spark Streaming 消费（MoviesIngestJob）
  │   → 幂等写入 MySQL `movie` 表
  │
  └─→ 评分数据流
      {"userId":1, "movieId":123, "rating":4.5, "timestamp":1728600000}
      → Kafka ratings 主题
      → Spark Streaming 消费（RatingsIngestJob）
      → 幂等写入 MySQL `rating` 表
      → 同步更新 `movie` 聚合字段
      
最终 → 前端实时查询展示
```

### Kafka 消息格式

**ratings 主题（评分事件）**
```json
{
  "userId": 12345,          // 用户内部 ID（或外部 ID，需映射）
  "movieId": 6789,          // 电影内部 ID（或外部 ID，需映射）
  "rating": 4.5,            // 评分值（1.0-5.0）
  "timestamp": 1728600000   // Unix 时间戳（秒）
}
```

**movies 主题（电影元数据，可选）**
```json
{
  "movieId": 6789,
  "title": "肖申克的救赎",
  "genres": "剧情|犯罪",
  "year": 1994,
  "director": "弗兰克·德拉邦特",
  "actors": "蒂姆·罗宾斯|摩根·弗里曼",
  "posterUrl": "https://...",
  "description": "..."
}
```

### 爬虫实现建议

**使用 Scrapy 框架示例**
```python
# spider.py
import scrapy
from kafka import KafkaProducer
import json

class MovieRatingSpider(scrapy.Spider):
    name = 'douban_ratings'
    
    def __init__(self):
        self.producer = KafkaProducer(
            bootstrap_servers='localhost:9092',
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
    
    def parse(self, response):
        # 解析豆瓣电影评分页
        for rating in response.css('.rating-item'):
            event = {
                'userId': self.map_user(rating.css('.user-id::text').get()),
                'movieId': self.map_movie(response.url),
                'rating': float(rating.css('.rating-star::attr(class)').re_first(r'allstar(\d+)')) / 10,
                'timestamp': int(time.time())
            }
            # 推送到 Kafka
            self.producer.send('ratings', value=event)
```

---

## 监控与运维

### Spark UI
- Batch Job: `http://<driver-host>:4040`（任务运行期间）
- Streaming Job: `http://<driver-host>:4040`（常驻）
- History Server: `http://<history-server-host>:18080`

### Kafka 监控
```bash
# 查看消费者 Lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group spark-streaming-ratings

# 查看主题消息数
kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic ratings
```

### MySQL 验证
```sql
-- 查看最新评分
SELECT * FROM rating ORDER BY created_at DESC LIMIT 10;

-- 查看推荐结果
SELECT u.userAccount, m.title, r.score, r.rank 
FROM recommendation r
JOIN user u ON r.userId = u.id
JOIN movie m ON r.movieId = m.id
WHERE r.algorithm = 'ALS'
ORDER BY u.id, r.rank
LIMIT 20;

-- 查看电影聚合指标
SELECT title, avgRating, ratingCount 
FROM movie 
WHERE ratingCount > 100 
ORDER BY avgRating DESC 
LIMIT 10;
```

---

## 常见问题

### Q1: 流作业 checkpoint 恢复失败？
**A:** 确保 HDFS 路径 `hdfs:///checkpoints/recsys/ratings-ingest` 存在且可写。删除旧 checkpoint 可重新开始：
```bash
hdfs dfs -rm -r /checkpoints/recsys/ratings-ingest
```

### Q2: MySQL 外键约束导致写入失败？
**A:** 确保 `user` 和 `movie` 表已预先导入数据；或在测试阶段临时禁用外键：
```sql
SET FOREIGN_KEY_CHECKS=0;
```

### Q3: Kafka 消费延迟（Lag）过高？
**A:** 增加 Spark Streaming 并行度或 Kafka 分区数：
```bash
# 增加分区
kafka-topics.sh --alter --topic ratings --partitions 6 --bootstrap-server localhost:9092

# 提高 Spark executor 数量
--num-executors 8
```

### Q4: 如何实现 ID 映射（爬虫外部 ID → 内部 ID）？
**A:** 在爬虫侧查询 MySQL 或 Redis 缓存建立映射；或在 Streaming 侧 Join 维度表。

---

## 下一步增强

- [x] 实现电影元数据流（`movies` 主题消费）✅ 已完成
- [ ] 添加实时热门榜单（Trending 算法）
- [ ] 训练版本化与时间截断控制
- [ ] Airflow DAG 编排批训练
- [ ] Prometheus + Grafana 监控大盘
- [ ] 增量 ALS 训练（减少冷启动）

---

## 项目结构

```
Processor/
├── pom.xml                           # Maven 配置
├── README.md                         # 本文档
├── archive/                          # MovieLens 数据集
│   └── ml-25m/
│       ├── movies.csv
│       ├── ratings.csv
│       └── links.csv
├── src/main/
│   ├── java/com/yourorg/recsys/
│   │   ├── batch/
│   │   │   └── BatchAlsJob.java      # 批 ALS 训练
│   │   ├── streaming/
│   │   │   ├── MoviesIngestJob.java  # 流式电影元数据入库
│   │   │   └── RatingsIngestJob.java # 流式评分入库
│   │   └── util/
│   │       ├── Config.java           # 配置加载
│   │       └── JdbcUtils.java        # JDBC 工具
│   └── resources/
│       ├── application.yaml          # 应用配置
│       └── log4j2.xml                # 日志配置
└── scripts/
    ├── import_movielens.py           # CSV 导入脚本
    ├── kafka_producer_test.py        # Kafka 测试工具
    ├── tmdb_data_fetcher.py          # TMDB 数据拉取器
    ├── submit_batch_als.sh           # 批任务提交脚本
    ├── submit_streaming_movies.sh    # 流任务提交脚本（电影元数据）
    └── submit_streaming_ratings.sh   # 流任务提交脚本（评分）
```

---

## 联系与支持

如有问题或建议，请提交 Issue 或联系项目负责人。

