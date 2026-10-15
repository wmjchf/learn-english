-- App Starter · 最小表结构（手机号登录）
-- 库：app_starter

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `sms_send_logs`;
DROP TABLE IF EXISTS `user_sessions`;
DROP TABLE IF EXISTS `users`;

CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone` VARCHAR(20) NOT NULL,
  `nickname` VARCHAR(64) DEFAULT NULL,
  `avatar_url` VARCHAR(512) DEFAULT NULL,
  `status` ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
  `last_login_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_phone` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_sessions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `refresh_token_hash` CHAR(64) NOT NULL,
  `device_info` VARCHAR(255) DEFAULT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `revoked_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sessions_token_hash` (`refresh_token_hash`),
  KEY `idx_sessions_user_id` (`user_id`),
  KEY `idx_sessions_expires_at` (`expires_at`),
  CONSTRAINT `fk_sessions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `sms_send_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone` VARCHAR(20) NOT NULL,
  `scene` VARCHAR(32) NOT NULL DEFAULT 'login',
  `provider_request_id` VARCHAR(64) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_sms_phone_created` (`phone`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
