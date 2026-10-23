-- 手动生成日额度（免费 1 次/日）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `generate_quota` (
  `user_id` BIGINT UNSIGNED NOT NULL,
  `local_date` DATE NOT NULL,
  `manual_free_used` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`user_id`, `local_date`),
  CONSTRAINT `fk_generate_quota_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
