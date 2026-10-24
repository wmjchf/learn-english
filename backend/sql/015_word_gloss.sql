-- 词条详细释义缓存（按 lemma；库空则 LLM 异步补）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `word_gloss` (
  `lemma` VARCHAR(64) NOT NULL,
  `pos` VARCHAR(64) DEFAULT NULL COMMENT '词性，如 n. / v. / adj.',
  `gloss` VARCHAR(512) NOT NULL DEFAULT '' COMMENT '简明中文释义',
  `sense` VARCHAR(768) DEFAULT NULL COMMENT '用法详解 1-2 句',
  `root` VARCHAR(128) DEFAULT NULL,
  `example_en` VARCHAR(512) DEFAULT NULL,
  `example_zh` VARCHAR(512) DEFAULT NULL,
  `context` VARCHAR(512) DEFAULT NULL COMMENT '常见语境提示',
  `source` ENUM('seed','llm','manual') NOT NULL DEFAULT 'llm',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`lemma`),
  KEY `idx_word_gloss_source` (`source`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
