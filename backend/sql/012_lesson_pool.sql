-- 公共日课池：首课秒出 / 生成失败降级
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `lesson_pool` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bank_id` BIGINT UNSIGNED DEFAULT NULL,
  `generation_level` ENUM('A1','A2','B1','B2','C1','C2') NOT NULL DEFAULT 'B1',
  `scene_codes` JSON DEFAULT NULL,
  `theme` VARCHAR(128) NOT NULL,
  `list_label` VARCHAR(128) DEFAULT NULL,
  `title` VARCHAR(128) NOT NULL,
  `content_json` JSON NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_pool_match` (`generation_level`, `enabled`, `bank_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
