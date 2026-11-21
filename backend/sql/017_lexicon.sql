-- 词根词缀 / 同义易混（原 App 本地 lemma_index.json）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `lexicon_roots` (
  `id` VARCHAR(64) NOT NULL,
  `root_key` VARCHAR(128) NOT NULL DEFAULT '',
  `meaning` VARCHAR(512) NOT NULL DEFAULT '',
  `etym` VARCHAR(256) NOT NULL DEFAULT '',
  `family_json` JSON NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lexicon_lemmas` (
  `lemma` VARCHAR(64) NOT NULL,
  `breakdown` VARCHAR(256) NOT NULL DEFAULT '',
  `gloss` VARCHAR(512) NOT NULL DEFAULT '',
  `root_id` VARCHAR(64) DEFAULT NULL,
  `synonyms_json` JSON DEFAULT NULL,
  `confusables_json` JSON DEFAULT NULL,
  `senses_json` JSON DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`lemma`),
  KEY `idx_lexicon_lemmas_root` (`root_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
