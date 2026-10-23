-- 词库目录 + 用户计划指针（MVP 单计划）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `word_banks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(64) NOT NULL,
  `type` ENUM('exam','business') NOT NULL,
  `title` VARCHAR(64) NOT NULL,
  `subtitle` VARCHAR(128) DEFAULT NULL,
  `target_size` INT UNSIGNED NOT NULL DEFAULT 0,
  `word_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `sort` INT NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_word_banks_code` (`code`),
  KEY `idx_word_banks_enabled_sort` (`enabled`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_plans` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `bank_id` BIGINT UNSIGNED NOT NULL,
  `cursor_ord` INT UNSIGNED NOT NULL DEFAULT 0,
  `status` ENUM('active','paused') NOT NULL DEFAULT 'active',
  `daily_minutes` INT DEFAULT NULL,
  `target_days` INT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_plans_user` (`user_id`),
  KEY `idx_user_plans_bank` (`bank_id`),
  CONSTRAINT `fk_user_plans_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_plans_bank` FOREIGN KEY (`bank_id`) REFERENCES `word_banks` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `word_banks` (`code`, `type`, `title`, `subtitle`, `target_size`, `word_count`, `sort`, `enabled`) VALUES
  ('business', 'business', '商务英语', '约 800 词 · 通用商务', 800, 0, 10, 1),
  ('cet4', 'exam', '四级', '约 4500 词', 4500, 0, 20, 1),
  ('cet6', 'exam', '六级', '约 5500 词', 5500, 0, 30, 1),
  ('kaoyan', 'exam', '考研', '约 5500 词', 5500, 0, 40, 1)
ON DUPLICATE KEY UPDATE
  `title` = VALUES(`title`),
  `subtitle` = VALUES(`subtitle`),
  `target_size` = VALUES(`target_size`),
  `sort` = VALUES(`sort`),
  `enabled` = VALUES(`enabled`);
