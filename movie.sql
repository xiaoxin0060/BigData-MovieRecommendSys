/*
 Navicat Premium Dump SQL

 Source Server         : remote_sql
 Source Server Type    : MySQL
 Source Server Version : 80043 (8.0.43-0ubuntu0.22.04.2)
 Source Host           : 110.42.61.85:6001
 Source Schema         : movie

 Target Server Type    : MySQL
 Target Server Version : 80043 (8.0.43-0ubuntu0.22.04.2)
 File Encoding         : 65001

 Date: 28/10/2025 17:28:30
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for movie
-- ----------------------------
DROP TABLE IF EXISTS `movie`;
CREATE TABLE `movie`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `title` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '电影标题',
  `originalTitle` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '原始标题（可选，英文或原语种）',
  `genres` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '类型（多个用|分隔，如：动作|冒险|科幻）',
  `year` int NULL DEFAULT NULL COMMENT '上映年份',
  `director` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '导演',
  `actors` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '演员（多个用|分隔）',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '电影简介',
  `posterUrl` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '海报URL',
  `mlMovieId` bigint NULL DEFAULT NULL COMMENT 'MovieLens 电影ID（仅导入用）',
  `imdbId` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT 'IMDB ID（来自 links.csv）',
  `tmdbId` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT 'TMDB ID（来自 links.csv）',
  `source` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'ML' COMMENT '数据来源（ML=MovieLens, CRAWL=抓取）',
  `avgRating` decimal(3, 2) NULL DEFAULT 0.00 COMMENT '平均评分（0.00-5.00）',
  `ratingCount` int NULL DEFAULT 0 COMMENT '评分人数',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_mlMovieId`(`mlMovieId` ASC) USING BTREE,
  INDEX `idx_year`(`year` ASC) USING BTREE,
  INDEX `idx_avgRating`(`avgRating` ASC) USING BTREE,
  INDEX `idx_genres`(`genres` ASC) USING BTREE,
  INDEX `idx_imdbId`(`imdbId` ASC) USING BTREE,
  INDEX `idx_tmdbId`(`tmdbId` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 187421 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '电影信息表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for rating
-- ----------------------------
DROP TABLE IF EXISTS `rating`;
CREATE TABLE `rating`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `userId` bigint NOT NULL COMMENT '用户ID',
  `movieId` bigint NOT NULL COMMENT '电影ID',
  `rating` decimal(2, 1) NOT NULL COMMENT '评分（1.0-5.0）',
  `timestamp` bigint NULL DEFAULT NULL COMMENT '评分时间戳（用于 Spark 算法）',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_movie`(`userId` ASC, `movieId` ASC) USING BTREE COMMENT '一个用户对一部电影只能评分一次',
  INDEX `idx_userId`(`userId` ASC) USING BTREE,
  INDEX `idx_movieId`(`movieId` ASC) USING BTREE,
  INDEX `idx_timestamp`(`timestamp` ASC) USING BTREE,
  CONSTRAINT `fk_rating_movie` FOREIGN KEY (`movieId`) REFERENCES `movie` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_rating_user` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 37190172 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户评分表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for rec_model_meta
-- ----------------------------
DROP TABLE IF EXISTS `rec_model_meta`;
CREATE TABLE `rec_model_meta`  (
  `id` tinyint NOT NULL DEFAULT 1 COMMENT '固定为1的单行表',
  `active_version` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '当前对外生效的模型版本',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '推荐模型元信息（当前激活版本）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for recommendation
-- ----------------------------
DROP TABLE IF EXISTS `recommendation`;
CREATE TABLE `recommendation`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `userId` bigint NOT NULL COMMENT '用户ID',
  `movieId` bigint NOT NULL COMMENT '推荐的电影ID',
  `score` decimal(10, 8) NOT NULL COMMENT '推荐分数（越高越推荐）',
  `rank` int NULL DEFAULT NULL COMMENT '推荐排名（1=最推荐）',
  `model_version` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'v0' COMMENT '模型版本号',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '推荐生成时间',
  `algorithm` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'ALS' COMMENT '推荐算法名称',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_userId_score`(`userId` ASC, `score` DESC) USING BTREE COMMENT '按用户查询推荐结果并按分数降序',
  INDEX `idx_movieId`(`movieId` ASC) USING BTREE,
  CONSTRAINT `fk_recommendation_movie` FOREIGN KEY (`movieId`) REFERENCES `movie` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_recommendation_user` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 3332565 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '推荐结果表（由 Spark 离线计算生成）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for stg_ratings
-- ----------------------------
DROP TABLE IF EXISTS `stg_ratings`;
CREATE TABLE `stg_ratings`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `mlUserId` bigint NOT NULL,
  `mlMovieId` bigint NOT NULL,
  `rating` decimal(2, 1) NOT NULL,
  `timestamp` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user
-- ----------------------------
DROP TABLE IF EXISTS `user`;
CREATE TABLE `user`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `userName` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '用户昵称',
  `userAccount` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户账号',
  `gender` tinyint NULL DEFAULT NULL COMMENT '性别(0-女 1-男)',
  `userPassword` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户密码',
  `mlUserId` bigint NULL DEFAULT NULL COMMENT 'MovieLens 用户ID（仅导入用）',
  `source` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '数据来源（ML=MovieLens, CRAWL=抓取）',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uni_userAccount`(`userAccount` ASC) USING BTREE,
  UNIQUE INDEX `uk_mlUserId`(`mlUserId` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 322543 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Procedure structure for migrate_movie_to_init
-- ----------------------------
DROP PROCEDURE IF EXISTS `migrate_movie_to_init`;
delimiter ;;
CREATE PROCEDURE `migrate_movie_to_init`()
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  /* =========================
     0) 安全：仅在表存在时操作
     ========================= */

  /* =========================
     1) recommendation 表升级
     - 新增列 model_version（不为空，默认 v0）
     - 为避免唯一键冲突，先将历史数据回填为 legacy_<algorithm>
     - 新增唯一索引 (userId, movieId, model_version)
     - 新增普通索引 idx_model_version(model_version)
     - 移除旧唯一索引 uk_user_movie_algo（若存在）
     ========================= */
  SELECT COUNT(*) INTO v_exists
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation';
  IF v_exists = 1 THEN

    -- 1.1 新增列（若不存在）
    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND COLUMN_NAME = 'model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD COLUMN `model_version` varchar(64) NOT NULL DEFAULT 'v0' COMMENT '模型版本号'
        , ALGORITHM=INSTANT, LOCK=NONE;
    END IF;

    -- 1.2 回填安全值：将现有数据的 model_version 设置为 legacy_<algorithm>（避免后续唯一索引冲突）
    UPDATE `recommendation`
       SET `model_version` = CONCAT('legacy_', LOWER(COALESCE(`algorithm`, 'unknown')))
     WHERE (`model_version` IS NULL OR `model_version` = 'v0');

    -- 1.3 新增普通索引（若不存在）
    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND INDEX_NAME = 'idx_model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_model_version`(`model_version`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- 1.4 新增新唯一索引（若不存在）
    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND INDEX_NAME = 'ux_user_movie_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD UNIQUE KEY `ux_user_movie_version` (`userId`, `movieId`, `model_version`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- 1.5 兼容校验：补齐重要索引（若缺失）
    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND INDEX_NAME = 'idx_userId_score';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_userId_score`(`userId`, `score` DESC)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND INDEX_NAME = 'idx_movieId';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_movieId`(`movieId`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- 1.6 移除旧唯一索引（若存在）
    SELECT COUNT(*) INTO v_exists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recommendation' AND INDEX_NAME = 'uk_user_movie_algo';
    IF v_exists > 0 THEN
      ALTER TABLE `recommendation`
        DROP INDEX `uk_user_movie_algo`
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

  END IF;

  /* =========================
     2) rec_model_meta 表（若不存在则创建 + 种子数据）
     ========================= */
  CREATE TABLE IF NOT EXISTS `rec_model_meta` (
    `id` tinyint NOT NULL DEFAULT 1 COMMENT '固定为1的单行表',
    `active_version` varchar(64) NOT NULL COMMENT '当前对外生效的模型版本',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='推荐模型元信息（当前激活版本）';

  INSERT INTO `rec_model_meta` (`id`, `active_version`)
  SELECT 1, 'v0'
  WHERE NOT EXISTS (SELECT 1 FROM `rec_model_meta` WHERE `id` = 1);

  /* =========================
     3) 补齐 movie / rating 的关键索引（若缺失）
     ========================= */
  -- movie
  SELECT COUNT(*) INTO v_exists
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie';
  IF v_exists = 1 THEN
    -- idx_year
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie' AND INDEX_NAME = 'idx_year';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_year`(`year`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
    -- idx_avgRating
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie' AND INDEX_NAME = 'idx_avgRating';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_avgRating`(`avgRating`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
    -- idx_genres
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie' AND INDEX_NAME = 'idx_genres';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_genres`(`genres`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
    -- idx_imdbId
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie' AND INDEX_NAME = 'idx_imdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_imdbId`(`imdbId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
    -- idx_tmdbId
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movie' AND INDEX_NAME = 'idx_tmdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_tmdbId`(`tmdbId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
  END IF;

  -- rating（唯一键补齐）
  SELECT COUNT(*) INTO v_exists
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rating';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rating' AND INDEX_NAME = 'uk_user_movie';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD UNIQUE KEY `uk_user_movie`(`userId`, `movieId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
  END IF;

END
;;
delimiter ;

-- ----------------------------
-- Procedure structure for sp_safe_migrate_to_init_v20251028
-- ----------------------------
DROP PROCEDURE IF EXISTS `sp_safe_migrate_to_init_v20251028`;
delimiter ;;
CREATE PROCEDURE `sp_safe_migrate_to_init_v20251028`()
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  /* =========================
     1) recommendation 表升级
     - 补充列 algorithm、model_version
     - 回填 model_version = legacy_<algorithm>
     - 为避免唯一索引冲突，对重复键追加序号后缀
     - 新增必要索引和唯一约束
     ========================= */
  SELECT COUNT(*) INTO v_exists
  FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'recommendation';
  IF v_exists = 1 THEN

    -- 1.1 algorithm 列（若缺失则新增）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND column_name = 'algorithm';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD COLUMN `algorithm` varchar(50) DEFAULT 'ALS' COMMENT '推荐算法名称'
        , ALGORITHM=INSTANT, LOCK=NONE;
    END IF;

    -- 1.2 model_version 列（若缺失则新增）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND column_name = 'model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD COLUMN `model_version` varchar(64) NOT NULL DEFAULT 'v0' COMMENT '模型版本号'
        , ALGORITHM=INSTANT, LOCK=NONE;
    END IF;

    -- 1.3 回填 model_version：将 NULL 或 'v0' 的历史数据标记为 legacy_<algorithm>
    UPDATE `recommendation`
       SET `model_version` = CONCAT('legacy_', LOWER(COALESCE(`algorithm`, 'unknown')))
     WHERE (`model_version` IS NULL OR `model_version` = 'v0');

    -- 1.4 为避免后续唯一索引失败：对重复键追加序号后缀（不删除数据）
    UPDATE `recommendation` r
    JOIN (
      SELECT id,
             ROW_NUMBER() OVER (PARTITION BY userId, movieId, model_version ORDER BY id) AS rn
      FROM `recommendation`
    ) t ON t.id = r.id
    SET r.model_version = CONCAT(r.model_version, '_', t.rn)
    WHERE t.rn > 1;

    -- 1.5 必要二级索引补齐
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_model_version`(`model_version`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_userId_score';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_userId_score`(`userId`, `score` DESC)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_movieId';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD INDEX `idx_movieId`(`movieId`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- 1.6 清理历史唯一索引（如存在）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'uk_user_movie_algo';
    IF v_exists > 0 THEN
      ALTER TABLE `recommendation`
        DROP INDEX `uk_user_movie_algo`
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- 1.7 新唯一约束：同一版本对同一用户同一电影只保留一条
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'ux_user_movie_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD UNIQUE KEY `ux_user_movie_version` (`userId`, `movieId`, `model_version`)
        , ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

  END IF;

  /* =========================
     2) rec_model_meta 表（若不存在则创建 + 种子数据）
     ========================= */
  CREATE TABLE IF NOT EXISTS `rec_model_meta` (
    `id` tinyint NOT NULL DEFAULT 1 COMMENT '固定为1的单行表',
    `active_version` varchar(64) NOT NULL COMMENT '当前对外生效的模型版本',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='推荐模型元信息（当前激活版本）';

  INSERT INTO `rec_model_meta` (`id`, `active_version`)
  SELECT 1, 'v0'
  WHERE NOT EXISTS (SELECT 1 FROM `rec_model_meta` WHERE `id` = 1);

  /* =========================
     3) movie / rating / user 关键索引补齐（仅缺失时补）
     ========================= */
  -- movie
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'movie';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_year';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_year`(`year`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_avgRating';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_avgRating`(`avgRating`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_genres';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_genres`(`genres`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_imdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_imdbId`(`imdbId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_tmdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_tmdbId`(`tmdbId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
  END IF;

  -- rating
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'rating';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'uk_user_movie';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD UNIQUE KEY `uk_user_movie`(`userId`, `movieId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_userId';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_userId`(`userId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_movieId';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_movieId`(`movieId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_timestamp';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_timestamp`(`timestamp`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
  END IF;

  -- user
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'user';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'user' AND index_name = 'uni_userAccount';
    IF v_exists = 0 THEN
      ALTER TABLE `user` ADD UNIQUE KEY `uni_userAccount`(`userAccount`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'user' AND index_name = 'uk_mlUserId';
    IF v_exists = 0 THEN
      ALTER TABLE `user` ADD UNIQUE KEY `uk_mlUserId`(`mlUserId`), ALGORITHM=INPLACE, LOCK=NONE;
    END IF;
  END IF;

END
;;
delimiter ;

-- ----------------------------
-- Procedure structure for sp_safe_migrate_to_init_v20251028a
-- ----------------------------
DROP PROCEDURE IF EXISTS `sp_safe_migrate_to_init_v20251028a`;
delimiter ;;
CREATE PROCEDURE `sp_safe_migrate_to_init_v20251028a`()
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  /* =========================
     1) recommendation 表升级
     ========================= */
  SELECT COUNT(*) INTO v_exists
  FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'recommendation';
  IF v_exists = 1 THEN

    -- 1.1 algorithm 列（若缺失则新增）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND column_name = 'algorithm';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD COLUMN `algorithm` varchar(50) DEFAULT 'ALS' COMMENT '推荐算法名称'
        , ALGORITHM=INSTANT;
    END IF;

    -- 1.2 model_version 列（若缺失则新增）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND column_name = 'model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD COLUMN `model_version` varchar(64) NOT NULL DEFAULT 'v0' COMMENT '模型版本号'
        , ALGORITHM=INSTANT;
    END IF;

    -- 1.3 回填 model_version
    UPDATE `recommendation`
       SET `model_version` = CONCAT('legacy_', LOWER(COALESCE(`algorithm`, 'unknown')))
     WHERE (`model_version` IS NULL OR `model_version` = 'v0');

    -- 1.4 无损“去重”：为重复键追加序号后缀
    UPDATE `recommendation` r
    JOIN (
      SELECT id,
             ROW_NUMBER() OVER (PARTITION BY userId, movieId, model_version ORDER BY id) AS rn
      FROM `recommendation`
    ) t ON t.id = r.id
    SET r.model_version = CONCAT(r.model_version, '_', t.rn)
    WHERE t.rn > 1;

    -- 1.5 索引补齐（去掉显式 LOCK/ALGORITHM，兼容性更好）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_model_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation` ADD INDEX `idx_model_version`(`model_version`);
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_userId_score';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation` ADD INDEX `idx_userId_score`(`userId`, `score` DESC);
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'idx_movieId';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation` ADD INDEX `idx_movieId`(`movieId`);
    END IF;

    -- 1.6 清理历史唯一索引（如存在）
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'uk_user_movie_algo';
    IF v_exists > 0 THEN
      ALTER TABLE `recommendation` DROP INDEX `uk_user_movie_algo`;
    END IF;

    -- 1.7 新唯一约束
    SELECT COUNT(*) INTO v_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'recommendation' AND index_name = 'ux_user_movie_version';
    IF v_exists = 0 THEN
      ALTER TABLE `recommendation`
        ADD UNIQUE KEY `ux_user_movie_version` (`userId`, `movieId`, `model_version`);
    END IF;

  END IF;

  /* =========================
     2) rec_model_meta 表（若不存在则创建 + 种子数据）
     ========================= */
  CREATE TABLE IF NOT EXISTS `rec_model_meta` (
    `id` tinyint NOT NULL DEFAULT 1 COMMENT '固定为1的单行表',
    `active_version` varchar(64) NOT NULL COMMENT '当前对外生效的模型版本',
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='推荐模型元信息（当前激活版本）';

  INSERT INTO `rec_model_meta` (`id`, `active_version`)
  SELECT 1, 'v0'
  WHERE NOT EXISTS (SELECT 1 FROM `rec_model_meta` WHERE `id` = 1);

  /* =========================
     3) movie / rating / user 关键索引补齐
     ========================= */
  -- movie
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'movie';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_year';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_year`(`year`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_avgRating';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_avgRating`(`avgRating`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_genres';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_genres`(`genres`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_imdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_imdbId`(`imdbId`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'movie' AND index_name = 'idx_tmdbId';
    IF v_exists = 0 THEN
      ALTER TABLE `movie` ADD INDEX `idx_tmdbId`(`tmdbId`);
    END IF;
  END IF;

  -- rating
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'rating';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'uk_user_movie';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD UNIQUE KEY `uk_user_movie`(`userId`, `movieId`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_userId';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_userId`(`userId`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_movieId';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_movieId`(`movieId`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'rating' AND index_name = 'idx_timestamp';
    IF v_exists = 0 THEN
      ALTER TABLE `rating` ADD INDEX `idx_timestamp`(`timestamp`);
    END IF;
  END IF;

  -- user
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'user';
  IF v_exists = 1 THEN
    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'user' AND index_name = 'uni_userAccount';
    IF v_exists = 0 THEN
      ALTER TABLE `user` ADD UNIQUE KEY `uni_userAccount`(`userAccount`);
    END IF;

    SELECT COUNT(*) INTO v_exists FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'user' AND index_name = 'uk_mlUserId';
    IF v_exists = 0 THEN
      ALTER TABLE `user` ADD UNIQUE KEY `uk_mlUserId`(`mlUserId`);
    END IF;
  END IF;

END
;;
delimiter ;

SET FOREIGN_KEY_CHECKS = 1;
