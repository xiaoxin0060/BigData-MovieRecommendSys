#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一次性导入 MovieLens 25M 数据集到 MySQL
运行前确保已执行 the-backend/sql/init.sql 创建表结构
性能优化版本 - 支持大数据集快速导入
"""

import csv
import re
import pymysql
import logging
import os
import sys
from datetime import datetime
from tqdm import tqdm
import gc

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('movielens_import.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# MySQL 配置（请根据实际修改）
MYSQL_CONFIG = {
    'host': 'hadoop-master',
    'port': 3306,
    'user': 'root', 
    'password': 'YourStrongRootPassword123!',  # ⚠️ 请修改为实际密码
    'database': 'movie',
    'charset': 'utf8mb4',
    # 性能优化参数
    'autocommit': False,
    'local_infile': 1,
    'connect_timeout': 60,
    'read_timeout': 300,
    'write_timeout': 300,
    # 认证插件配置（解决 MySQL 8.0 认证问题）
    'auth_plugin_map': {
        'caching_sha2_password': 'mysql_native_password'
    }
}

# CSV 路径（相对于脚本执行目录）
CSV_BASE = './archive/ml-25m'
MOVIES_CSV = f'{CSV_BASE}/movies.csv'
LINKS_CSV = f'{CSV_BASE}/links.csv'
RATINGS_CSV = f'{CSV_BASE}/ratings.csv'

# 性能优化的批量写入大小
BATCH_SIZE = 20000  # 增大批处理大小
MEMORY_LIMIT_MB = 500  # 内存使用限制(MB)


def check_environment():
    """检查运行环境和必要文件"""
    logger.info("检查运行环境...")
    
    # 检查CSV文件
    required_files = [MOVIES_CSV, LINKS_CSV, RATINGS_CSV]
    missing_files = []
    
    for file_path in required_files:
        if not os.path.exists(file_path):
            missing_files.append(file_path)
        else:
            # 检查文件大小
            size_mb = os.path.getsize(file_path) / (1024 * 1024)
            logger.info(f"✓ {file_path} 存在 ({size_mb:.1f}MB)")
    
    if missing_files:
        logger.error(f"❌ 缺少必要的CSV文件: {missing_files}")
        logger.error("请确保MovieLens 25M数据集已下载并解压到正确位置")
        return False
    
    return True


def check_database_connection():
    """检查数据库连接和表结构"""
    logger.info("检查数据库连接和表结构...")
    
    try:
        # 测试连接（不指定数据库）
        test_config = MYSQL_CONFIG.copy()
        test_db = test_config.pop('database')
        
        conn = pymysql.connect(**test_config)
        cursor = conn.cursor()
        
        # 检查数据库是否存在
        cursor.execute("SHOW DATABASES LIKE %s", (test_db,))
        if not cursor.fetchone():
            logger.error(f"❌ 数据库 '{test_db}' 不存在")
            logger.error("请先执行 the-backend/sql/init.sql 创建数据库和表结构")
            cursor.close()
            conn.close()
            return False
        
        cursor.close()
        conn.close()
        
        # 连接到目标数据库
        conn = pymysql.connect(**MYSQL_CONFIG)
        cursor = conn.cursor()
        
        # 检查必要的表是否存在
        required_tables = ['user', 'movie', 'rating', 'recommendation']
        cursor.execute("SHOW TABLES")
        existing_tables = [table[0] for table in cursor.fetchall()]
        
        missing_tables = [table for table in required_tables if table not in existing_tables]
        if missing_tables:
            logger.error(f"❌ 缺少必要的表: {missing_tables}")
            logger.error("请先执行 the-backend/sql/init.sql 创建表结构")
            cursor.close()
            conn.close()
            return False
        
        logger.info("✓ 数据库连接正常，表结构完整")
        
        # 检查表是否为空（可选警告）
        for table in ['user', 'movie', 'rating']:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            if count > 0:
                logger.warning(f"⚠️  表 {table} 已有 {count} 条数据，将进行覆盖更新")
        
        cursor.close()
        conn.close()
        return True
        
    except pymysql.Error as e:
        logger.error(f"❌ 数据库连接失败: {e}")
        logger.error("请检查数据库配置和服务状态")
        return False


def get_file_line_count(file_path):
    """快速获取文件行数（用于进度条）"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return sum(1 for _ in f) - 1  # 减去标题行
    except:
        return 0


def optimize_mysql_session(conn):
    """优化MySQL会话参数"""
    cursor = conn.cursor()
    try:
        # 禁用自动提交，使用手动事务管理
        cursor.execute("SET autocommit = 0")
        # 禁用外键检查（导入完成后重新启用）
        cursor.execute("SET foreign_key_checks = 0")
        # 调整批量插入缓冲区
        cursor.execute("SET bulk_insert_buffer_size = 256*1024*1024")
        # 调整排序缓冲区
        cursor.execute("SET sort_buffer_size = 32*1024*1024")
        logger.info("✓ MySQL会话参数已优化")
    except Exception as e:
        logger.warning(f"⚠️  MySQL会话优化失败（可能影响性能）: {e}")
    finally:
        cursor.close()


def restore_mysql_session(conn):
    """恢复MySQL会话参数"""
    cursor = conn.cursor()
    try:
        # 重新启用外键检查
        cursor.execute("SET foreign_key_checks = 1")
        cursor.execute("SET autocommit = 1")
        logger.info("✓ MySQL会话参数已恢复")
    except Exception as e:
        logger.warning(f"⚠️  MySQL会话恢复失败: {e}")
    finally:
        cursor.close()


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
    logger.info("开始导入电影信息...")
    cursor = conn.cursor()
    
    # 读取 links.csv 建立 movieId -> (imdbId, tmdbId) 映射
    links_map = {}
    try:
        links_count = get_file_line_count(LINKS_CSV)
        logger.info(f"加载 links.csv 映射 ({links_count} 条记录)...")
        
        with open(LINKS_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            with tqdm(total=links_count, desc="加载Links", unit='条') as pbar:
                for row in reader:
                    ml_movie_id = int(row['movieId'])
                    imdb_id = row.get('imdbId', '').strip()
                    tmdb_id = row.get('tmdbId', '').strip()
                    links_map[ml_movie_id] = (imdb_id if imdb_id else None, tmdb_id if tmdb_id else None)
                    pbar.update(1)
        
        logger.info(f"✓ 已加载 {len(links_map)} 条 links 记录")
        
        # 内存使用检查
        import sys
        map_size_mb = sys.getsizeof(links_map) / (1024 * 1024)
        if map_size_mb > MEMORY_LIMIT_MB:
            logger.warning(f"⚠️  Links映射占用内存 {map_size_mb:.1f}MB，可能影响性能")
            
    except FileNotFoundError:
        logger.warning(f"⚠️  {LINKS_CSV} 不存在，跳过外部 ID 映射")
    
    # 读取 movies.csv 并批量插入
    movies_count = get_file_line_count(MOVIES_CSV)
    logger.info(f"开始导入电影数据 ({movies_count} 条记录)...")
    
    batch = []
    count = 0
    
    try:
        with open(MOVIES_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            with tqdm(total=movies_count, desc="导入电影", unit='部') as pbar:
                for row in reader:
                    try:
                        ml_movie_id = int(row['movieId'])
                        title = row['title'].strip()
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
                            conn.commit()  # 分批提交
                            count += len(batch)
                            pbar.update(len(batch))
                            batch = []
                            
                    except (ValueError, KeyError) as e:
                        logger.warning(f"跳过无效电影记录: {row} - {e}")
                        pbar.update(1)
                        continue
        
        # 处理剩余批次
        if batch:
            cursor.executemany("""
                INSERT INTO movie (mlMovieId, title, originalTitle, genres, year, imdbId, tmdbId, source, avgRating, ratingCount)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 0.00, 0)
                ON DUPLICATE KEY UPDATE title=VALUES(title), genres=VALUES(genres), year=VALUES(year),
                                         imdbId=VALUES(imdbId), tmdbId=VALUES(tmdbId)
            """, batch)
            conn.commit()
            count += len(batch)
    
    finally:
        cursor.close()
        # 释放内存
        del links_map
        gc.collect()
    
    logger.info(f"✅ 电影导入完成，共 {count} 部")


def import_users(conn, user_ids):
    """导入虚拟用户（仅 mlUserId，供训练使用）"""
    logger.info(f"开始导入用户（共 {len(user_ids)} 个）...")
    cursor = conn.cursor()
    batch = []
    count = 0
    
    try:
        with tqdm(total=len(user_ids), desc="导入用户", unit='个') as pbar:
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
                    conn.commit()  # 分批提交
                    count += len(batch)
                    pbar.update(len(batch))
                    batch = []
        
        # 处理剩余批次
        if batch:
            cursor.executemany("""
                INSERT INTO user (mlUserId, userAccount, userName, userPassword, source)
                VALUES (%s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE mlUserId=VALUES(mlUserId)
            """, batch)
            conn.commit()
            count += len(batch)
    
    finally:
        cursor.close()
    
    logger.info(f"✅ 用户导入完成，共 {count} 个")


def import_ratings(conn):
    """导入评分（ratings.csv），依赖 mlUserId/mlMovieId 映射为内部 id"""
    logger.info("开始导入评分数据（数据量大，请耐心等待）...")
    cursor = conn.cursor()
    
    try:
        # 预加载 mlUserId -> id 映射
        logger.info("加载用户ID映射...")
        cursor.execute("SELECT id, mlUserId FROM user WHERE mlUserId IS NOT NULL")
        user_map = {ml_id: db_id for db_id, ml_id in cursor.fetchall()}
        
        # 预加载 mlMovieId -> id 映射
        logger.info("加载电影ID映射...")
        cursor.execute("SELECT id, mlMovieId FROM movie WHERE mlMovieId IS NOT NULL")
        movie_map = {ml_id: db_id for db_id, ml_id in cursor.fetchall()}
        
        logger.info(f"✓ 已加载 {len(user_map)} 个用户映射，{len(movie_map)} 个电影映射")
        
        # 检查映射完整性
        if not user_map or not movie_map:
            raise ValueError("用户或电影映射为空，请先导入用户和电影数据")
        
        # 获取评分文件总行数
        ratings_count = get_file_line_count(RATINGS_CSV)
        logger.info(f"准备处理 {ratings_count:,} 条评分记录...")
        
        batch = []
        count = 0
        skipped = 0
        
        # 使用更大的批处理提高性能
        ratings_batch_size = BATCH_SIZE * 2  # 评分数据使用更大批次
        
        with open(RATINGS_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            with tqdm(total=ratings_count, desc="导入评分", unit='条') as pbar:
                for row in reader:
                    try:
                        ml_user_id = int(row['userId'])
                        ml_movie_id = int(row['movieId'])
                        rating = float(row['rating'])
                        timestamp = int(row['timestamp'])
                        
                        user_id = user_map.get(ml_user_id)
                        movie_id = movie_map.get(ml_movie_id)
                        
                        if not user_id or not movie_id:
                            skipped += 1
                            pbar.update(1)
                            continue
                        
                        batch.append((user_id, movie_id, rating, timestamp))
                        
                        if len(batch) >= ratings_batch_size:
                            cursor.executemany("""
                                INSERT INTO rating (userId, movieId, rating, timestamp)
                                VALUES (%s, %s, %s, %s)
                                ON DUPLICATE KEY UPDATE rating=VALUES(rating), timestamp=VALUES(timestamp)
                            """, batch)
                            conn.commit()  # 分批提交避免长事务
                            count += len(batch)
                            pbar.update(len(batch))
                            
                            # 每100万条记录报告一次进度
                            if count % 1000000 == 0:
                                logger.info(f"已处理 {count:,} 条评分，跳过 {skipped:,} 条")
                                # 强制垃圾回收
                                gc.collect()
                            
                            batch = []
                    
                    except (ValueError, KeyError) as e:
                        logger.warning(f"跳过无效评分记录: {row} - {e}")
                        skipped += 1
                        pbar.update(1)
                        continue
        
        # 处理剩余批次
        if batch:
            cursor.executemany("""
                INSERT INTO rating (userId, movieId, rating, timestamp)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE rating=VALUES(rating), timestamp=VALUES(timestamp)
            """, batch)
            conn.commit()
            count += len(batch)
    
    finally:
        cursor.close()
        # 释放映射占用的内存
        del user_map, movie_map
        gc.collect()
    
    logger.info(f"✅ 评分导入完成，共 {count:,} 条（跳过 {skipped:,} 条无效映射）")


def update_movie_aggregates(conn):
    """更新电影聚合字段（avgRating, ratingCount）"""
    logger.info("计算电影聚合指标...")
    cursor = conn.cursor()
    
    try:
        # 设置更长的超时时间
        cursor.execute("SET SESSION wait_timeout = 3600")  # 1小时
        cursor.execute("SET SESSION interactive_timeout = 3600")  # 1小时
        cursor.execute("SET SESSION net_read_timeout = 600")  # 10分钟
        cursor.execute("SET SESSION net_write_timeout = 600")  # 10分钟
        
        # 显示处理进度
        cursor.execute("SELECT COUNT(DISTINCT movieId) FROM rating")
        movie_count = cursor.fetchone()[0]
        logger.info(f"需要更新 {movie_count:,} 部电影的聚合指标...")
        
        # 执行聚合更新 - 使用批量更新避免长时间锁定
        start_time = datetime.now()
        logger.info("开始计算聚合数据（可能需要10-15分钟）...")
        
        # 分步骤执行，减少单个查询的复杂度
        cursor.execute("""
            CREATE TEMPORARY TABLE temp_movie_stats AS
            SELECT movieId, ROUND(AVG(rating), 2) AS avgR, COUNT(*) AS cnt
            FROM rating
            GROUP BY movieId
        """)
        logger.info("✓ 聚合数据计算完成，开始更新电影表...")
        
        cursor.execute("""
            UPDATE movie m
            INNER JOIN temp_movie_stats t ON t.movieId = m.id
            SET m.avgRating = t.avgR, m.ratingCount = t.cnt
        """)
        
        conn.commit()
        
        end_time = datetime.now()
        affected = cursor.rowcount
        duration = (end_time - start_time).total_seconds()
        
        logger.info(f"✅ 已更新 {affected:,} 部电影的聚合指标（耗时 {duration:.1f} 秒）")
        
    except Exception as e:
        logger.error(f"❌ 更新聚合指标失败: {e}")
        # 检查数据是否已部分导入
        try:
            cursor.execute("SELECT COUNT(*) FROM rating")
            rating_count = cursor.fetchone()[0]
            logger.info(f"📊 当前已有 {rating_count:,} 条评分数据")
        except:
            pass
        raise
    finally:
        cursor.close()


def scan_user_ids():
    """扫描ratings.csv获取所有唯一用户ID"""
    logger.info("扫描用户ID...")
    user_ids = set()
    
    ratings_count = get_file_line_count(RATINGS_CSV)
    
    try:
        with open(RATINGS_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            with tqdm(total=ratings_count, desc="扫描用户ID", unit='条') as pbar:
                for row in reader:
                    try:
                        user_ids.add(int(row['userId']))
                        pbar.update(1)
                    except (ValueError, KeyError):
                        pbar.update(1)
                        continue
    except Exception as e:
        logger.error(f"❌ 扫描用户ID失败: {e}")
        raise
    
    logger.info(f"✅ 发现 {len(user_ids):,} 个唯一用户")
    return sorted(user_ids)


def main():
    """主函数：执行完整的MovieLens数据导入流程"""
    start_time = datetime.now()
    
    logger.info("=" * 80)
    logger.info("MovieLens 25M 数据导入工具 - 性能优化版")
    logger.info("=" * 80)
    
    # 1. 环境检查
    logger.info("🔍 步骤 1/6: 环境检查")
    if not check_environment():
        logger.error("❌ 环境检查失败，请修复后重试")
        sys.exit(1)
    
    # 2. 数据库连接检查
    logger.info("\n🔍 步骤 2/6: 数据库连接检查")
    if not check_database_connection():
        logger.error("❌ 数据库检查失败，请修复后重试")
        sys.exit(1)
    
    # 建立数据库连接
    try:
        logger.info(f"🔗 连接到 MySQL: {MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}/{MYSQL_CONFIG['database']}")
        conn = pymysql.connect(**MYSQL_CONFIG)
        
        # 优化MySQL会话
        optimize_mysql_session(conn)
        
    except Exception as e:
        logger.error(f"❌ 数据库连接失败: {e}")
        sys.exit(1)
    
    try:
        # 3. 导入电影数据
        logger.info("\n🎬 步骤 3/6: 导入电影数据")
        import_movies(conn)
        
        # 4. 扫描用户ID
        logger.info("\n👥 步骤 4/6: 扫描用户数据")
        user_ids = scan_user_ids()
        
        # 5. 导入用户数据
        logger.info("\n👤 步骤 5/6: 导入用户数据") 
        import_users(conn, user_ids)
        
        # 6. 导入评分数据（最耗时）
        logger.info("\n⭐ 步骤 6/6: 导入评分数据")
        import_ratings(conn)
        
        # 7. 更新聚合指标
        logger.info("\n📊 最后步骤: 更新聚合指标")
        update_movie_aggregates(conn)
        
        # 计算总耗时
        end_time = datetime.now()
        total_duration = (end_time - start_time).total_seconds()
        
        logger.info("\n" + "=" * 80)
        logger.info(f"🎉 全部导入完成！总耗时: {total_duration/60:.1f} 分钟")
        logger.info("=" * 80)
        
        # 显示最终统计
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM movie WHERE source='ML'")
        movie_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM user WHERE source='ML'")
        user_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM rating")
        rating_count = cursor.fetchone()[0]
        cursor.close()
        
        logger.info(f"📈 导入统计：")
        logger.info(f"   电影: {movie_count:,} 部")
        logger.info(f"   用户: {user_count:,} 个") 
        logger.info(f"   评分: {rating_count:,} 条")
        logger.info(f"   平均导入速度: {rating_count/total_duration:.0f} 条评分/秒")
        
    except KeyboardInterrupt:
        logger.warning("\n⚠️  用户中断导入过程")
        conn.rollback()
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ 导入失败: {e}")
        logger.error("正在回滚事务...")
        conn.rollback()
        raise
    finally:
        # 恢复MySQL会话设置
        try:
            restore_mysql_session(conn)
        except:
            pass
        conn.close()
        logger.info("🔗 数据库连接已关闭")


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        logger.error(f"程序异常退出: {e}")
        sys.exit(1)
