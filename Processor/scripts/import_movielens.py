#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一次性导入 MovieLens 25M 数据集到 MySQL
运行前确保已执行 Receiver/sql/init.sql 创建表结构
"""

import csv
import re
import pymysql
from datetime import datetime

# MySQL 配置（请根据实际修改）
MYSQL_CONFIG = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',
    'password': '124578aA',
    'database': 'movie',
    'charset': 'utf8mb4'
}

# CSV 路径（相对于脚本执行目录）
CSV_BASE = './archive/ml-25m'
MOVIES_CSV = f'{CSV_BASE}/movies.csv'
LINKS_CSV = f'{CSV_BASE}/links.csv'
RATINGS_CSV = f'{CSV_BASE}/ratings.csv'

# 批量写入大小
BATCH_SIZE = 5000


def parse_title_year(title):
    """从标题中提取年份，例如 'Toy Story (1995)' -> ('Toy Story', 1995)"""
    match = re.search(r'\((\d{4})\)\s*$', title)
    if match:
        year = int(match.group(1))
        clean_title = title[:match.start()].strip()
        return clean_title, year
    return title, None


def import_movies(conn):
    """导入电影信息（movies.csv + links.csv）"""
    print("开始导入电影信息...")
    cursor = conn.cursor()
    
    # 读取 links.csv 建立 movieId -> (imdbId, tmdbId) 映射
    links_map = {}
    try:
        with open(LINKS_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                ml_movie_id = int(row['movieId'])
                imdb_id = row.get('imdbId', '').strip()
                tmdb_id = row.get('tmdbId', '').strip()
                links_map[ml_movie_id] = (imdb_id if imdb_id else None, tmdb_id if tmdb_id else None)
        print(f"  已加载 {len(links_map)} 条 links 记录")
    except FileNotFoundError:
        print(f"  警告: {LINKS_CSV} 不存在，跳过外部 ID")
    
    # 读取 movies.csv 并批量插入
    batch = []
    count = 0
    with open(MOVIES_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ml_movie_id = int(row['movieId'])
            title = row['title']
            genres = row['genres'] if row['genres'] != '(no genres listed)' else None
            
            clean_title, year = parse_title_year(title)
            imdb_id, tmdb_id = links_map.get(ml_movie_id, (None, None))
            
            batch.append((
                ml_movie_id,  # mlMovieId
                clean_title,  # title
                title,        # originalTitle（保留原始）
                genres,       # genres
                year,         # year
                imdb_id,      # imdbId
                tmdb_id,      # tmdbId
                'ML'          # source
            ))
            
            if len(batch) >= BATCH_SIZE:
                cursor.executemany("""
                    INSERT INTO movie (mlMovieId, title, originalTitle, genres, year, imdbId, tmdbId, source, avgRating, ratingCount)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 0.00, 0)
                    ON DUPLICATE KEY UPDATE title=VALUES(title), genres=VALUES(genres), year=VALUES(year),
                                             imdbId=VALUES(imdbId), tmdbId=VALUES(tmdbId)
                """, batch)
                count += len(batch)
                print(f"  已插入 {count} 部电影...")
                batch = []
    
    if batch:
        cursor.executemany("""
            INSERT INTO movie (mlMovieId, title, originalTitle, genres, year, imdbId, tmdbId, source, avgRating, ratingCount)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 0.00, 0)
            ON DUPLICATE KEY UPDATE title=VALUES(title), genres=VALUES(genres), year=VALUES(year),
                                     imdbId=VALUES(imdbId), tmdbId=VALUES(tmdbId)
        """, batch)
        count += len(batch)
    
    conn.commit()
    cursor.close()
    print(f"✅ 电影导入完成，共 {count} 部")


def import_users(conn, user_ids):
    """导入虚拟用户（仅 mlUserId，供训练使用）"""
    print(f"开始导入用户（共 {len(user_ids)} 个）...")
    cursor = conn.cursor()
    batch = []
    count = 0
    
    for ml_user_id in user_ids:
        batch.append((
            ml_user_id,                     # mlUserId
            f'ml_user_{ml_user_id}',        # userAccount
            f'MovieLens User {ml_user_id}', # userName
            'movielens',                    # userPassword（占位）
            'ML'                            # source
        ))
        
        if len(batch) >= BATCH_SIZE:
            cursor.executemany("""
                INSERT INTO user (mlUserId, userAccount, userName, userPassword, source)
                VALUES (%s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE mlUserId=VALUES(mlUserId)
            """, batch)
            count += len(batch)
            print(f"  已插入 {count} 个用户...")
            batch = []
    
    if batch:
        cursor.executemany("""
            INSERT INTO user (mlUserId, userAccount, userName, userPassword, source)
            VALUES (%s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE mlUserId=VALUES(mlUserId)
        """, batch)
        count += len(batch)
    
    conn.commit()
    cursor.close()
    print(f"✅ 用户导入完成，共 {count} 个")


def import_ratings(conn):
    """导入评分（ratings.csv），依赖 mlUserId/mlMovieId 映射为内部 id"""
    print("开始导入评分数据（可能需要较长时间）...")
    cursor = conn.cursor()
    
    # 预加载 mlUserId -> id 映射
    cursor.execute("SELECT id, mlUserId FROM user WHERE mlUserId IS NOT NULL")
    user_map = {ml_id: db_id for db_id, ml_id in cursor.fetchall()}
    
    # 预加载 mlMovieId -> id 映射
    cursor.execute("SELECT id, mlMovieId FROM movie WHERE mlMovieId IS NOT NULL")
    movie_map = {ml_id: db_id for db_id, ml_id in cursor.fetchall()}
    
    print(f"  已加载 {len(user_map)} 个用户映射，{len(movie_map)} 个电影映射")
    
    batch = []
    count = 0
    skipped = 0
    
    with open(RATINGS_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ml_user_id = int(row['userId'])
            ml_movie_id = int(row['movieId'])
            rating = float(row['rating'])
            timestamp = int(row['timestamp'])
            
            user_id = user_map.get(ml_user_id)
            movie_id = movie_map.get(ml_movie_id)
            
            if not user_id or not movie_id:
                skipped += 1
                continue
            
            batch.append((user_id, movie_id, rating, timestamp))
            
            if len(batch) >= BATCH_SIZE:
                cursor.executemany("""
                    INSERT INTO rating (userId, movieId, rating, timestamp)
                    VALUES (%s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE rating=VALUES(rating), timestamp=VALUES(timestamp)
                """, batch)
                count += len(batch)
                print(f"  已插入 {count} 条评分（跳过 {skipped} 条）...")
                batch = []
    
    if batch:
        cursor.executemany("""
            INSERT INTO rating (userId, movieId, rating, timestamp)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE rating=VALUES(rating), timestamp=VALUES(timestamp)
        """, batch)
        count += len(batch)
    
    conn.commit()
    cursor.close()
    print(f"✅ 评分导入完成，共 {count} 条（跳过 {skipped} 条无效映射）")


def update_movie_aggregates(conn):
    """更新电影聚合字段（avgRating, ratingCount）"""
    print("计算电影聚合指标...")
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE movie m
        JOIN (
            SELECT movieId, AVG(rating) AS avgR, COUNT(*) AS cnt
            FROM rating
            GROUP BY movieId
        ) r ON r.movieId = m.id
        SET m.avgRating = ROUND(r.avgR, 2), m.ratingCount = r.cnt
    """)
    conn.commit()
    affected = cursor.rowcount
    cursor.close()
    print(f"✅ 已更新 {affected} 部电影的聚合指标")


def main():
    print("=" * 60)
    print("MovieLens 25M 数据导入工具")
    print("=" * 60)
    
    # 连接 MySQL
    conn = pymysql.connect(**MYSQL_CONFIG)
    print(f"✅ 已连接到 MySQL: {MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}/{MYSQL_CONFIG['database']}\n")
    
    try:
        # 1. 导入电影
        import_movies(conn)
        
        # 2. 提取用户 ID 列表（从 ratings.csv 第一遍扫描）
        print("\n扫描用户 ID...")
        user_ids = set()
        with open(RATINGS_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                user_ids.add(int(row['userId']))
        print(f"✅ 发现 {len(user_ids)} 个唯一用户\n")
        
        # 3. 导入用户
        import_users(conn, sorted(user_ids))
        
        # 4. 导入评分
        print()
        import_ratings(conn)
        
        # 5. 更新聚合
        print()
        update_movie_aggregates(conn)
        
        print("\n" + "=" * 60)
        print("✅ 全部导入完成！")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ 导入失败: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == '__main__':
    main()

