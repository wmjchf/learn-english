-- 日课表（种子内容由 lessonService 从代码模板克隆）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `lessons` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED DEFAULT NULL,
  `bank_id` BIGINT UNSIGNED DEFAULT NULL,
  `day_index` INT UNSIGNED NOT NULL DEFAULT 1,
  `local_date` DATE DEFAULT NULL,
  `theme` VARCHAR(128) NOT NULL,
  `list_label` VARCHAR(128) DEFAULT NULL,
  `title` VARCHAR(128) NOT NULL,
  `content_json` JSON NOT NULL,
  `source` ENUM('seed','pool','personalized','cache') NOT NULL DEFAULT 'seed',
  `status` ENUM('unread','reading','done') NOT NULL DEFAULT 'unread',
  `generation_level` ENUM('A1','A2','B1','B2','C1','C2') DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_lessons_user_date` (`user_id`, `local_date`),
  KEY `idx_lessons_user_day` (`user_id`, `day_index`),
  CONSTRAINT `fk_lessons_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
