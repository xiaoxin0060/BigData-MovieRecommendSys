#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
单独更新电影聚合指标的脚本
用于在主导入脚本失败后，单独完成聚合指标的更新
"""

import pymysql
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
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
    'connect_timeout': 60,
    'read_timeout': 1800,  # 30分钟
    'write_timeout': 1800,  # 30分钟
    'auth_plugin_map': {
        'caching_sha2_password': 'mysql_native_password'
    }
}


def update_movie_aggregates():
    """更新电影聚合字段（avgRating, ratingCount）"""
    logger.info("开始单独更新电影聚合指标...")
    
    try:
        conn = pymysql.connect(**MYSQL_CONFIG)
        cursor = conn.cursor()
        
        # 设置更长的超时时间
        cursor.execute("SET SESSION wait_timeout = 7200")  # 2小时
        cursor.execute("SET SESSION interactive_timeout = 7200")  # 2小时
        cursor.execute("SET SESSION net_read_timeout = 1200")  # 20分钟
        cursor.execute("SET SESSION net_write_timeout = 1200")  # 20分钟
        
        # 检查数据状态
        cursor.execute("SELECT COUNT(*) FROM rating")
        rating_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(DISTINCT movieId) FROM rating")
        movie_count = cursor.fetchone()[0]
        
        logger.info(f"📊 数据状态检查：")
        logger.info(f"   总评分数: {rating_count:,} 条")
        logger.info(f"   有评分的电影数: {movie_count:,} 部")
        
        if rating_count == 0:
            logger.error("❌ 没有找到评分数据，请先运行主导入脚本")
            return False
        
        # 执行聚合更新
        start_time = datetime.now()
        logger.info("🔄 开始计算聚合数据（预计需要15-20分钟，请耐心等待）...")
        
        # 第一步：创建临时表存储聚合结果
        logger.info("步骤 1/3: 计算每部电影的平均评分和评分数量...")
        cursor.execute("DROP TEMPORARY TABLE IF EXISTS temp_movie_stats")
        cursor.execute("""
            CREATE TEMPORARY TABLE temp_movie_stats (
                movieId BIGINT,
                avgR DECIMAL(3,2),
                cnt INT,
                INDEX idx_movieId (movieId)
            ) AS
            SELECT movieId, ROUND(AVG(rating), 2) AS avgR, COUNT(*) AS cnt
            FROM rating
            GROUP BY movieId
        """)
        
        # 检查临时表
        cursor.execute("SELECT COUNT(*) FROM temp_movie_stats")
        temp_count = cursor.fetchone()[0]
        logger.info(f"✓ 聚合计算完成，共 {temp_count:,} 部电影")
        
        # 第二步：更新电影表
        logger.info("步骤 2/3: 更新电影表的聚合字段...")
        cursor.execute("""
            UPDATE movie m
            INNER JOIN temp_movie_stats t ON t.movieId = m.id
            SET m.avgRating = t.avgR, m.ratingCount = t.cnt
        """)
        
        affected = cursor.rowcount
        logger.info(f"✓ 已更新 {affected:,} 部电影的聚合字段")
        
        # 第三步：提交事务
        logger.info("步骤 3/3: 提交数据库事务...")
        conn.commit()
        
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        logger.info("=" * 60)
        logger.info(f"🎉 聚合指标更新完成！")
        logger.info(f"   更新电影数: {affected:,} 部")
        logger.info(f"   总耗时: {duration/60:.1f} 分钟")
        logger.info("=" * 60)
        
        # 验证结果
        cursor.execute("""
            SELECT 
                COUNT(*) as total_movies,
                COUNT(CASE WHEN avgRating > 0 THEN 1 END) as movies_with_rating,
                MAX(avgRating) as max_rating,
                MIN(avgRating) as min_rating,
                AVG(avgRating) as avg_of_ratings
            FROM movie 
            WHERE source = 'ML'
        """)
        
        result = cursor.fetchone()
        logger.info("📈 验证结果：")
        logger.info(f"   总电影数: {result[0]:,}")
        logger.info(f"   有评分的电影: {result[1]:,}")
        logger.info(f"   最高评分: {result[2]}")
        logger.info(f"   最低评分: {result[3]}")
        logger.info(f"   平均评分: {result[4]:.2f}")
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        logger.error(f"❌ 更新聚合指标失败: {e}")
        try:
            conn.rollback()
            conn.close()
        except:
            pass
        return False


if __name__ == '__main__':
    logger.info("MovieLens 聚合指标更新工具")
    logger.info("=" * 50)
    
    success = update_movie_aggregates()
    
    if success:
        logger.info("✅ 聚合指标更新成功！")
    else:
        logger.error("❌ 聚合指标更新失败！")
        exit(1)
