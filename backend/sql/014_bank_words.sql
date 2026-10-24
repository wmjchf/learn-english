-- 真词库词条：按词库 code 存 lemma + 中文释义 + 顺序
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `bank_words` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bank_code` VARCHAR(64) NOT NULL,
  `lemma` VARCHAR(64) NOT NULL,
  `gloss` VARCHAR(256) NOT NULL DEFAULT '',
  `root` VARCHAR(128) DEFAULT NULL,
  `ord` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bank_lemma` (`bank_code`, `lemma`),
  KEY `idx_bank_words_ord` (`bank_code`, `ord`),
  KEY `idx_bank_words_lemma` (`lemma`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
