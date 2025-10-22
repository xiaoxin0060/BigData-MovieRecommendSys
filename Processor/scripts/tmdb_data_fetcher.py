#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TMDB API 数据拉取器 - 获取真实电影数据并生成评分流
功能：
1. 从 TMDB 拉取热门/最新电影元数据
2. 推送电影信息到 Kafka movies 主题
3. 基于 TMDB 评分生成模拟用户评分流到 Kafka ratings 主题
"""

import requests
import json
import time
import random
from datetime import datetime
from kafka import KafkaProducer
import pymysql
import sys

# ==================== 配置区 ====================
# TMDB API 配置（请替换为你的 API Key）
TMDB_CONFIG = {
    'api_key': 'fa822083412489b87aa9e83665dc5b7d',  # 在 https://www.themoviedb.org/settings/api 获取
    'base_url': 'https://api.themoviedb.org/3',
    'language': 'zh-CN',  # 中文元数据
    'region': 'CN'
}

# Kafka 配置
KAFKA_CONFIG = {
    'bootstrap_servers': '10.1.20.11:9092',
    'topic_movies': 'movies',
    'topic_ratings': 'ratings'
}

# MySQL 配置（用于查询映射和避免重复）
MYSQL_CONFIG = {
    'host': '110.42.61.85',
    'port': 3306,
    'user': 'root',
    'password': '124578aA',
    'database': 'movie',
    'charset': 'utf8mb4'
}

# 拉取策略
FETCH_STRATEGY = {
    'popular_pages': 5,        # 拉取热门电影的页数（每页 20 部）
    'top_rated_pages': 3,      # 拉取高分电影的页数
    'now_playing_pages': 2,    # 拉取正在上映的电影
    'interval_seconds': 60,    # 每轮拉取间隔（秒）
    'ratings_per_movie': (5, 20),  # 每部电影生成的评分数范围
    'user_id_range': (1, 10000),   # 模拟用户 ID 范围
}

# ==================== TMDB API 客户端 ====================
class TMDBClient:
    def __init__(self, api_key, base_url, language='zh-CN', region='CN'):
        self.api_key = api_key
        self.base_url = base_url
        self.language = language
        self.region = region
        self.session = requests.Session()
    
    def _request(self, endpoint, params=None):
        """通用请求方法"""
        url = f"{self.base_url}{endpoint}"
        default_params = {
            'api_key': self.api_key,
            'language': self.language
        }
        if params:
            default_params.update(params)
        
        try:
            response = self.session.get(url, params=default_params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"  ❌ API 请求失败: {endpoint} - {e}")
            return None
    
    def get_popular_movies(self, page=1):
        """获取热门电影列表"""
        return self._request('/movie/popular', {'page': page, 'region': self.region})
    
    def get_top_rated_movies(self, page=1):
        """获取高分电影列表"""
        return self._request('/movie/top_rated', {'page': page, 'region': self.region})
    
    def get_now_playing_movies(self, page=1):
        """获取正在上映的电影"""
        return self._request('/movie/now_playing', {'page': page, 'region': self.region})
    
    def get_movie_details(self, movie_id):
        """获取电影详细信息（包含演员、导演等）"""
        return self._request(f'/movie/{movie_id}', {'append_to_response': 'credits'})


# ==================== 数据处理与推送 ====================
class DataPipeline:
    def __init__(self, tmdb_client, kafka_producer, mysql_conn):
        self.tmdb = tmdb_client
        self.producer = kafka_producer
        self.mysql_conn = mysql_conn
        self.processed_tmdb_ids = set()
        self._load_existing_tmdb_ids()
    
    def _load_existing_tmdb_ids(self):
        """从数据库加载已存在的 TMDB ID，避免重复处理"""
        try:
            cursor = self.mysql_conn.cursor()
            cursor.execute("SELECT tmdbId FROM movie WHERE tmdbId IS NOT NULL")
            self.processed_tmdb_ids = {str(row[0]) for row in cursor.fetchall()}
            cursor.close()
            print(f"  📌 已加载 {len(self.processed_tmdb_ids)} 个已存在的 TMDB 电影")
        except Exception as e:
            print(f"  ⚠️ 加载已有 TMDB ID 失败: {e}")
    
    def parse_movie_metadata(self, tmdb_movie):
        """解析 TMDB 电影数据为标准格式"""
        tmdb_id = str(tmdb_movie.get('id'))
        
        # 提取演员（前5位主演）
        actors = []
        if 'credits' in tmdb_movie and 'cast' in tmdb_movie['credits']:
            actors = [cast['name'] for cast in tmdb_movie['credits']['cast'][:5]]
        
        # 提取导演
        director = None
        if 'credits' in tmdb_movie and 'crew' in tmdb_movie['credits']:
            directors = [crew['name'] for crew in tmdb_movie['credits']['crew'] if crew['job'] == 'Director']
            director = directors[0] if directors else None
        
        # 提取类型
        genres = '|'.join([g['name'] for g in tmdb_movie.get('genres', [])])
        
        # 提取年份
        year = None
        release_date = tmdb_movie.get('release_date')
        if release_date:
            try:
                year = int(release_date.split('-')[0])
            except:
                pass
        
        # 海报 URL
        poster_path = tmdb_movie.get('poster_path')
        poster_url = f"https://image.tmdb.org/t/p/w500{poster_path}" if poster_path else None
        
        return {
            'tmdbId': tmdb_id,
            'title': tmdb_movie.get('title', ''),
            'originalTitle': tmdb_movie.get('original_title'),
            'genres': genres if genres else None,
            'year': year,
            'director': director,
            'actors': '|'.join(actors) if actors else None,
            'description': tmdb_movie.get('overview'),
            'posterUrl': poster_url,
            'avgRating': round(tmdb_movie.get('vote_average', 0) / 2, 2),  # TMDB 是 10 分制，转为 5 分制
            'ratingCount': tmdb_movie.get('vote_count', 0)
        }
    
    def send_movie_to_kafka(self, movie_data):
        """推送电影元数据到 Kafka"""
        try:
            self.producer.send(
                KAFKA_CONFIG['topic_movies'],
                value=movie_data
            )
            return True
        except Exception as e:
            print(f"  ❌ 推送电影失败: {e}")
            return False
    
    def generate_ratings_for_movie(self, tmdb_id, avg_rating, rating_count):
        """为一部电影生成模拟评分流"""
        if avg_rating <= 0:
            return 0
        
        # 根据 TMDB 评分人数决定生成数量（越热门生成越多）
        num_ratings = random.randint(*FETCH_STRATEGY['ratings_per_movie'])
        if rating_count > 10000:
            num_ratings = int(num_ratings * 1.5)
        elif rating_count > 50000:
            num_ratings = int(num_ratings * 2)
        
        # 查询数据库获取内部 movieId
        cursor = self.mysql_conn.cursor()
        cursor.execute("SELECT id FROM movie WHERE tmdbId = %s", (tmdb_id,))
        result = cursor.fetchone()
        cursor.close()
        
        if not result:
            return 0
        
        movie_id = result[0]
        sent_count = 0
        
        # 生成评分（基于 TMDB 均值，加入随机方差）
        for _ in range(num_ratings):
            # 正态分布生成评分，中心为 avg_rating，标准差 0.5
            rating = max(1.0, min(5.0, random.gauss(avg_rating, 0.5)))
            rating = round(rating * 2) / 2  # 取 0.5 精度
            
            user_id = random.randint(*FETCH_STRATEGY['user_id_range'])
            
            event = {
                'userId': user_id,
                'movieId': movie_id,
                'rating': rating,
                'timestamp': int(time.time())
            }
            
            try:
                self.producer.send(KAFKA_CONFIG['topic_ratings'], value=event)
                sent_count += 1
            except Exception as e:
                print(f"    ⚠️ 评分推送失败: {e}")
        
        return sent_count
    
    def process_movie(self, tmdb_movie_basic):
        """处理单部电影（获取详情、推送元数据、生成评分）"""
        tmdb_id = str(tmdb_movie_basic['id'])
        title = tmdb_movie_basic.get('title', 'Unknown')
        
        # 跳过已处理的电影（可选：注释掉此行以支持增量更新）
        if tmdb_id in self.processed_tmdb_ids:
            print(f"  ⏭️  跳过已处理: {title} (TMDB: {tmdb_id})")
            return False
        
        # 获取详细信息（包含演员、导演）
        print(f"  🎬 处理电影: {title} (TMDB: {tmdb_id})")
        details = self.tmdb.get_movie_details(tmdb_id)
        
        if not details:
            return False
        
        # 解析元数据
        movie_data = self.parse_movie_metadata(details)
        
        # 推送到 Kafka movies 主题
        if self.send_movie_to_kafka(movie_data):
            print(f"    ✅ 元数据已推送")
        
        # 生成评分流
        ratings_sent = self.generate_ratings_for_movie(
            tmdb_id,
            movie_data['avgRating'],
            movie_data['ratingCount']
        )
        
        if ratings_sent > 0:
            print(f"    ✅ 已生成 {ratings_sent} 条评分")
        
        # 标记为已处理
        self.processed_tmdb_ids.add(tmdb_id)
        
        # API 限流（TMDB 免费版限制 40 请求/10秒）
        time.sleep(0.3)
        
        return True


# ==================== 主程序 ====================
def create_kafka_producer():
    """创建 Kafka Producer"""
    return KafkaProducer(
        bootstrap_servers=KAFKA_CONFIG['bootstrap_servers'],
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode('utf-8'),
        acks='all',
        retries=3
    )


def fetch_movies_batch(tmdb_client, pipeline):
    """单次批量拉取电影"""
    total_processed = 0
    
    print("\n" + "=" * 60)
    print(f"开始拉取 TMDB 数据 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # 1. 热门电影
    print("\n📊 拉取热门电影...")
    for page in range(1, FETCH_STRATEGY['popular_pages'] + 1):
        data = tmdb_client.get_popular_movies(page)
        if data and 'results' in data:
            for movie in data['results']:
                if pipeline.process_movie(movie):
                    total_processed += 1
    
    # 2. 高分电影
    print("\n⭐ 拉取高分电影...")
    for page in range(1, FETCH_STRATEGY['top_rated_pages'] + 1):
        data = tmdb_client.get_top_rated_movies(page)
        if data and 'results' in data:
            for movie in data['results']:
                if pipeline.process_movie(movie):
                    total_processed += 1
    
    # 3. 正在上映
    print("\n🎞️  拉取正在上映...")
    for page in range(1, FETCH_STRATEGY['now_playing_pages'] + 1):
        data = tmdb_client.get_now_playing_movies(page)
        if data and 'results' in data:
            for movie in data['results']:
                if pipeline.process_movie(movie):
                    total_processed += 1
    
    print("\n" + "=" * 60)
    print(f"✅ 本轮完成，共处理 {total_processed} 部新电影")
    print("=" * 60)
    
    return total_processed


def main():
    print("=" * 60)
    print("TMDB 实时数据拉取器")
    print("=" * 60)
    
    # 检查 API Key
    if TMDB_CONFIG['api_key'] == 'YOUR_TMDB_API_KEY_HERE':
        print("❌ 错误: 请先在脚本中配置 TMDB API Key")
        print("   获取地址: https://www.themoviedb.org/settings/api")
        sys.exit(1)
    
    # 初始化组件
    print("\n🔧 初始化组件...")
    tmdb_client = TMDBClient(**TMDB_CONFIG)
    producer = create_kafka_producer()
    mysql_conn = pymysql.connect(**MYSQL_CONFIG)
    print(f"  ✅ TMDB API 客户端就绪")
    print(f"  ✅ Kafka Producer 已连接: {KAFKA_CONFIG['bootstrap_servers']}")
    print(f"  ✅ MySQL 已连接: {MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}/{MYSQL_CONFIG['database']}")
    
    pipeline = DataPipeline(tmdb_client, producer, mysql_conn)
    
    try:
        round_count = 0
        while True:
            round_count += 1
            print(f"\n\n{'='*60}")
            print(f"第 {round_count} 轮拉取")
            print(f"{'='*60}")
            
            # 执行拉取
            total = fetch_movies_batch(tmdb_client, pipeline)
            
            # 如果本轮无新电影，可能已拉完，降低频率
            if total == 0:
                print(f"\n⏸️  本轮无新电影，暂停 5 分钟...")
                time.sleep(300)
            else:
                print(f"\n⏳ 等待 {FETCH_STRATEGY['interval_seconds']} 秒后开始下一轮...")
                time.sleep(FETCH_STRATEGY['interval_seconds'])
    
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断，正在清理...")
    except Exception as e:
        print(f"\n\n❌ 发生错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        producer.close()
        mysql_conn.close()
        print("✅ 已关闭连接")


if __name__ == '__main__':
    main()

