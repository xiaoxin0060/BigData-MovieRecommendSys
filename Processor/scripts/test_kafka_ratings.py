#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kafka 评分流测试工具
功能：向 Kafka ratings 主题推送模拟评分事件，用于测试流处理功能
适用场景：禁用 TMDB 拉取器后的系统测试
"""

import json
import time
import random
import sys
from datetime import datetime
from kafka import KafkaProducer

# Kafka 配置
KAFKA_CONFIG = {
    'bootstrap_servers': 'hadoop-master:9092,hadoop-worker1:9092,hadoop-worker2:9092',
    'topic': 'ratings'
}

# 测试参数
TEST_CONFIG = {
    'num_events': 100,              # 总共生成的评分数量
    'interval_ms': 1000,            # 事件间隔（毫秒）
    'user_id_range': (1, 1000),     # 用户 ID 范围（确保在 user 表中存在）
    'movie_id_range': (1, 1000),    # 电影 ID 范围（确保在 movie 表中存在）
    'rating_range': (1.0, 5.0),     # 评分范围
}


def create_producer():
    """创建 Kafka Producer"""
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_CONFIG['bootstrap_servers'],
            value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode('utf-8'),
            acks='all',
            retries=3,
            max_in_flight_requests_per_connection=1
        )
        print(f"✅ 已连接到 Kafka: {KAFKA_CONFIG['bootstrap_servers']}")
        return producer
    except Exception as e:
        print(f"❌ Kafka 连接失败: {e}")
        sys.exit(1)


def generate_rating_event():
    """生成随机评分事件"""
    user_id = random.randint(*TEST_CONFIG['user_id_range'])
    movie_id = random.randint(*TEST_CONFIG['movie_id_range'])
    
    # 生成评分（0.5 精度）
    rating = round(random.uniform(*TEST_CONFIG['rating_range']) * 2) / 2
    rating = max(1.0, min(5.0, rating))
    
    timestamp = int(time.time())
    
    return {
        'userId': user_id,
        'movieId': movie_id,
        'rating': rating,
        'timestamp': timestamp
    }


def send_rating(producer, event, index):
    """发送评分事件到 Kafka"""
    try:
        future = producer.send(KAFKA_CONFIG['topic'], value=event)
        # 等待发送确认
        record_metadata = future.get(timeout=10)
        
        print(f"[{index:04d}] {datetime.now().strftime('%H:%M:%S')} | "
              f"User {event['userId']:4d} → Movie {event['movieId']:4d} | "
              f"Rating: {event['rating']:.1f} | "
              f"Partition: {record_metadata.partition}, Offset: {record_metadata.offset}")
        
        return True
    except Exception as e:
        print(f"❌ 发送失败: {e}")
        return False


def run_continuous_test(producer):
    """持续发送评分（按 Ctrl+C 停止）"""
    print("\n" + "=" * 80)
    print("🔄 持续评分流测试（按 Ctrl+C 停止）")
    print("=" * 80)
    
    index = 1
    success_count = 0
    fail_count = 0
    
    try:
        while True:
            event = generate_rating_event()
            if send_rating(producer, event, index):
                success_count += 1
            else:
                fail_count += 1
            
            index += 1
            
            # 每 10 条显示统计
            if index % 10 == 0:
                print(f"📊 统计: 成功 {success_count}, 失败 {fail_count}")
            
            # 等待间隔
            time.sleep(TEST_CONFIG['interval_ms'] / 1000.0)
    
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断测试")
        print(f"📊 最终统计: 成功 {success_count}, 失败 {fail_count}")


def run_batch_test(producer):
    """批量发送指定数量的评分"""
    num_events = TEST_CONFIG['num_events']
    
    print("\n" + "=" * 80)
    print(f"📦 批量评分流测试（共 {num_events} 条）")
    print("=" * 80)
    
    success_count = 0
    fail_count = 0
    start_time = time.time()
    
    for i in range(1, num_events + 1):
        event = generate_rating_event()
        if send_rating(producer, event, i):
            success_count += 1
        else:
            fail_count += 1
        
        # 等待间隔
        if i < num_events:
            time.sleep(TEST_CONFIG['interval_ms'] / 1000.0)
    
    end_time = time.time()
    duration = end_time - start_time
    
    print("\n" + "=" * 80)
    print("✅ 测试完成")
    print("=" * 80)
    print(f"📊 统计信息:")
    print(f"   成功: {success_count} 条")
    print(f"   失败: {fail_count} 条")
    print(f"   耗时: {duration:.2f} 秒")
    print(f"   速率: {success_count / duration:.2f} 条/秒")
    print("")
    print(f"💡 验证方法:")
    print(f"   1. 查看 RatingsIngestJob 日志:")
    print(f"      tail -f ../logs/ratings-ingest.log")
    print(f"   2. 查询 MySQL rating 表:")
    print(f"      mysql -u root -p movie -e \"SELECT * FROM rating ORDER BY updated_at DESC LIMIT 10;\"")
    print(f"   3. 查询聚合数据:")
    print(f"      mysql -u root -p movie -e \"SELECT id, title, avgRating, ratingCount FROM movie WHERE ratingCount > 0 ORDER BY updated_at DESC LIMIT 10;\"")


def main():
    """主程序"""
    print("=" * 80)
    print("Kafka 评分流测试工具")
    print("=" * 80)
    print(f"Kafka Broker: {KAFKA_CONFIG['bootstrap_servers']}")
    print(f"Topic: {KAFKA_CONFIG['topic']}")
    print(f"用户 ID 范围: {TEST_CONFIG['user_id_range']}")
    print(f"电影 ID 范围: {TEST_CONFIG['movie_id_range']}")
    print(f"评分范围: {TEST_CONFIG['rating_range']}")
    print("")
    
    # 提示检查数据
    print("⚠️  注意事项:")
    print("   1. 确保 user 表中存在 ID 1-1000 的用户（通过 import_movielens.py 导入）")
    print("   2. 确保 movie 表中存在 ID 1-1000 的电影")
    print("   3. 确保 RatingsIngestJob 流作业正在运行")
    print("   4. 确保 Kafka 集群正常运行")
    print("")
    
    # 选择模式
    print("请选择测试模式:")
    print("  1. 批量测试（发送固定数量的评分）")
    print("  2. 持续测试（持续发送，按 Ctrl+C 停止）")
    print("")
    
    choice = input("请输入选项 (1 或 2，默认 1): ").strip()
    if not choice:
        choice = "1"
    
    # 创建 Producer
    producer = create_producer()
    
    try:
        if choice == "1":
            # 可选：修改事件数量
            custom_num = input(f"输入评分数量（默认 {TEST_CONFIG['num_events']}）: ").strip()
            if custom_num.isdigit():
                TEST_CONFIG['num_events'] = int(custom_num)
            
            run_batch_test(producer)
        elif choice == "2":
            run_continuous_test(producer)
        else:
            print("❌ 无效选项")
    finally:
        producer.flush()
        producer.close()
        print("✅ Kafka Producer 已关闭")


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"❌ 程序异常: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

