-- 词成文 · 画像 + 选项目录
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `user_profiles` (
  `user_id` BIGINT UNSIGNED NOT NULL,
  `ability_level` ENUM('A1','A2','B1','B2','C1','C2') DEFAULT NULL,
  `generation_level` ENUM('A1','A2','B1','B2','C1','C2') DEFAULT NULL,
  `job_code` VARCHAR(64) DEFAULT NULL,
  `job_raw` VARCHAR(128) DEFAULT NULL,
  `scenes` JSON DEFAULT NULL,
  `interests` JSON DEFAULT NULL,
  `daily_minutes` INT DEFAULT NULL,
  `target_days` INT DEFAULT NULL,
  `primary_bank_id` BIGINT UNSIGNED DEFAULT NULL,
  `onboarding_step` VARCHAR(32) NOT NULL DEFAULT 'interest',
  `timezone` VARCHAR(64) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `option_catalog` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kind` ENUM('interest','scene','job') NOT NULL,
  `code` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `subtitle` VARCHAR(128) DEFAULT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `allow_custom` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_catalog_kind_code` (`kind`, `code`),
  KEY `idx_catalog_kind_enabled_sort` (`kind`, `enabled`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `option_catalog` (`kind`, `code`, `label`, `subtitle`, `sort`, `enabled`, `allow_custom`) VALUES
  ('interest', 'tech', '科技', '数码 · 互联网', 10, 1, 0),
  ('interest', 'travel', '旅行', '出行 · 见闻', 20, 1, 0),
  ('interest', 'sports', '体育', '赛事 · 健身', 30, 1, 0),
  ('interest', 'movie', '电影', '影视 · 娱乐', 40, 1, 0),
  ('interest', 'food', '美食', '餐饮 · 文化', 50, 1, 0),
  ('scene', 'email', '邮件', '商务往来', 10, 1, 0),
  ('scene', 'expo', '展会谈判', '当面沟通', 20, 1, 0),
  ('scene', 'quote', '报价', '询盘还盘', 30, 1, 0),
  ('scene', 'meeting', '会议', '讨论汇报', 40, 1, 0),
  ('scene', 'contract', '合同', '条款约定', 50, 1, 0),
  ('job', 'trade', '外贸', '进出口 · 客户', 10, 1, 0),
  ('job', 'sales', '销售', '客户沟通', 20, 1, 0),
  ('job', 'engineer', '程序员', '研发协作', 30, 1, 0),
  ('job', 'student', '学生', '学业场景', 40, 1, 0),
  ('job', 'other', '其他', '稍后可改', 90, 1, 1)
ON DUPLICATE KEY UPDATE
  `label` = VALUES(`label`),
  `subtitle` = VALUES(`subtitle`),
  `sort` = VALUES(`sort`),
  `enabled` = VALUES(`enabled`),
  `allow_custom` = VALUES(`allow_custom`);
