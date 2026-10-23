-- 打卡与连胜
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `user_checkins` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `local_date` DATE NOT NULL,
  `source` ENUM('lesson','review','freeze') NOT NULL DEFAULT 'lesson',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_checkin_day` (`user_id`, `local_date`),
  KEY `idx_checkins_date` (`local_date`),
  CONSTRAINT `fk_checkins_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_streaks` (
  `user_id` BIGINT UNSIGNED NOT NULL,
  `current_streak` INT UNSIGNED NOT NULL DEFAULT 0,
  `longest_streak` INT UNSIGNED NOT NULL DEFAULT 0,
  `freeze_used_month` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `freeze_month` CHAR(7) DEFAULT NULL COMMENT 'YYYY-MM',
  `last_checkin_date` DATE DEFAULT NULL,
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_streaks_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `streak_freeze_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `local_date` DATE NOT NULL,
  `action` ENUM('freeze','break') NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_freeze_day` (`user_id`, `local_date`),
  CONSTRAINT `fk_freeze_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
