-- 用户词生命周期（生词本 / SRS）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `user_words` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `lemma` VARCHAR(64) NOT NULL,
  `status` ENUM('learning','vocab','consolidating','mastered','known') NOT NULL DEFAULT 'learning',
  `srs_step` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `next_review_at` DATE DEFAULT NULL,
  `pass_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `source_lesson_id` BIGINT UNSIGNED DEFAULT NULL,
  `bank_id` BIGINT UNSIGNED DEFAULT NULL,
  `gloss` VARCHAR(256) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_lemma` (`user_id`, `lemma`),
  KEY `idx_user_words_bucket` (`user_id`, `status`, `next_review_at`),
  KEY `idx_user_words_due` (`user_id`, `next_review_at`),
  CONSTRAINT `fk_user_words_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_words_lesson` FOREIGN KEY (`source_lesson_id`) REFERENCES `lessons` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
