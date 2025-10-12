-- 创建主业务数据库
CREATE DATABASE IF NOT EXISTS `movie` 
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用数据库
USE `movie`;

-- ==============================================
-- 1. 用户表
-- ==============================================
CREATE TABLE IF NOT EXISTS `user` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `userName` varchar(256) DEFAULT NULL COMMENT '用户昵称',
    `userAccount` varchar(256) NOT NULL COMMENT '用户账号',
    `gender` tinyint DEFAULT NULL COMMENT '性别(0-女 1-男)',
    `userPassword` varchar(512) NOT NULL COMMENT '用户密码',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uni_userAccount` (`userAccount`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='用户表';

-- ==============================================
-- 2. 电影表
-- ==============================================
CREATE TABLE IF NOT EXISTS `movie` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `title` varchar(500) NOT NULL COMMENT '电影标题',
    `genres` varchar(200) DEFAULT NULL COMMENT '类型（多个用|分隔，如：动作|冒险|科幻）',
    `year` int DEFAULT NULL COMMENT '上映年份',
    `director` varchar(200) DEFAULT NULL COMMENT '导演',
    `actors` text DEFAULT NULL COMMENT '演员（多个用|分隔）',
    `description` text DEFAULT NULL COMMENT '电影简介',
    `posterUrl` varchar(500) DEFAULT NULL COMMENT '海报URL',
    `avgRating` decimal(3,2) DEFAULT 0.00 COMMENT '平均评分（0.00-5.00）',
    `ratingCount` int DEFAULT 0 COMMENT '评分人数',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_year` (`year`),
    KEY `idx_avgRating` (`avgRating`),
    KEY `idx_genres` (`genres`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='电影信息表';

-- ==============================================
-- 3. 用户评分表（Spark 算法的输入数据）
-- ==============================================
CREATE TABLE IF NOT EXISTS `rating` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `userId` bigint NOT NULL COMMENT '用户ID',
    `movieId` bigint NOT NULL COMMENT '电影ID',
    `rating` decimal(2,1) NOT NULL COMMENT '评分（1.0-5.0）',
    `timestamp` bigint DEFAULT NULL COMMENT '评分时间戳（用于 Spark 算法）',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_movie` (`userId`, `movieId`) COMMENT '一个用户对一部电影只能评分一次',
    KEY `idx_userId` (`userId`),
    KEY `idx_movieId` (`movieId`),
    KEY `idx_timestamp` (`timestamp`),
    CONSTRAINT `fk_rating_user` FOREIGN KEY (`userId`) REFERENCES `user`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_rating_movie` FOREIGN KEY (`movieId`) REFERENCES `movie`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='用户评分表';

-- ==============================================
-- 4. 推荐结果表（Spark 算法的输出数据）
-- ==============================================
CREATE TABLE IF NOT EXISTS `recommendation` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `userId` bigint NOT NULL COMMENT '用户ID',
    `movieId` bigint NOT NULL COMMENT '推荐的电影ID',
    `score` decimal(10,8) NOT NULL COMMENT '推荐分数（越高越推荐）',
    `rank` int DEFAULT NULL COMMENT '推荐排名（1=最推荐）',
    `algorithm` varchar(50) DEFAULT 'ALS' COMMENT '推荐算法名称',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '推荐生成时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_movie_algo` (`userId`, `movieId`, `algorithm`) COMMENT '同一算法对同一用户推荐同一电影只保留一条',
    KEY `idx_userId_score` (`userId`, `score` DESC) COMMENT '按用户查询推荐结果并按分数降序',
    KEY `idx_movieId` (`movieId`),
    CONSTRAINT `fk_recommendation_user` FOREIGN KEY (`userId`) REFERENCES `user`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_recommendation_movie` FOREIGN KEY (`movieId`) REFERENCES `movie`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='推荐结果表（由 Spark 离线计算生成）';

-- ==============================================
-- 插入测试数据（可选）
-- ==============================================

-- 测试电影数据
INSERT INTO `movie` (`id`, `title`, `genres`, `year`, `description`, `avgRating`, `ratingCount`) VALUES
(1, '肖申克的救赎', '剧情|犯罪', 1994, '一个关于希望和自由的故事', 4.8, 1500),
(2, '霸王别姬', '剧情|爱情', 1993, '两位京剧伶人半个世纪的悲欢离合', 4.7, 1200),
(3, '这个杀手不太冷', '剧情|动作|犯罪', 1994, '一个杀手和一个小女孩的故事', 4.6, 1100),
(4, '阿甘正传', '剧情|爱情', 1994, '智商75的阿甘创造的传奇人生', 4.5, 1000),
(5, '盗梦空间', '动作|科幻|悬疑', 2010, '梦境中的盗窃行动', 4.4, 950),
(6, '星际穿越', '科幻|冒险', 2014, '穿越虫洞寻找新家园', 4.5, 900),
(7, '楚门的世界', '剧情|科幻', 1998, '一个人的真实人生其实是一场真人秀', 4.3, 850),
(8, '海上钢琴师', '剧情|音乐', 1998, '一个从未踏上陆地的钢琴天才', 4.6, 800),
(9, '三傻大闹宝莱坞', '剧情|喜剧', 2009, '印度教育制度的讽刺喜剧', 4.4, 750),
(10, '放牛班的春天', '剧情|音乐', 2004, '一个代课老师改变孩子们的人生', 4.3, 700)
ON DUPLICATE KEY UPDATE `title`=VALUES(`title`);