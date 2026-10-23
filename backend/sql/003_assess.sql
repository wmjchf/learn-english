-- 词成文 · CEFR 测评题库与会话
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `assess_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lemma` VARCHAR(64) NOT NULL,
  `phonetic` VARCHAR(64) DEFAULT NULL,
  `prompt` VARCHAR(128) NOT NULL DEFAULT '这个词更接近哪个意思？',
  `options_json` JSON NOT NULL,
  `correct_index` TINYINT UNSIGNED NOT NULL,
  `cefr_level` ENUM('A1','A2','B1','B2','C1','C2') NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_assess_items_level` (`cefr_level`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `assess_sessions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `start_level` ENUM('A1','A2','B1','B2','C1','C2') NOT NULL DEFAULT 'B1',
  `current_level` ENUM('A1','A2','B1','B2','C1','C2') NOT NULL DEFAULT 'B1',
  `status` ENUM('active','finished','abandoned') NOT NULL DEFAULT 'active',
  `trail_json` JSON NOT NULL,
  `asked_item_ids` JSON NOT NULL,
  `result_level` ENUM('A1','A2','B1','B2','C1','C2') DEFAULT NULL,
  `estimated_vocab` INT DEFAULT NULL,
  `finished_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_assess_sessions_user` (`user_id`, `status`),
  CONSTRAINT `fk_assess_sessions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `assess_items` (`lemma`, `phonetic`, `prompt`, `options_json`, `correct_index`, `cefr_level`) VALUES
  ('apple', '/ˈæpl/', '这个词更接近哪个意思？', '["苹果","桌子","跑步"]', 0, 'A1'),
  ('book', '/bʊk/', '这个词更接近哪个意思？', '["书","杯子","窗户"]', 0, 'A1'),
  ('water', '/ˈwɔːtər/', '这个词更接近哪个意思？', '["水","风","火"]', 0, 'A1'),
  ('happy', '/ˈhæpi/', '这个词更接近哪个意思？', '["开心的","沉重的","遥远的"]', 0, 'A1'),
  ('family', '/ˈfæməli/', '这个词更接近哪个意思？', '["家庭","工厂","森林"]', 0, 'A1'),
  ('travel', '/ˈtrævl/', '这个词更接近哪个意思？', '["旅行","修理","计算"]', 0, 'A2'),
  ('busy', '/ˈbɪzi/', '这个词更接近哪个意思？', '["忙碌的","安静的","锋利的"]', 0, 'A2'),
  ('meeting', '/ˈmiːtɪŋ/', '这个词更接近哪个意思？', '["会议","菜单","镜子"]', 0, 'A2'),
  ('price', '/praɪs/', '这个词更接近哪个意思？', '["价格","礼物","桥"]', 0, 'A2'),
  ('choose', '/tʃuːz/', '这个词更接近哪个意思？', '["选择","关闭","抄写"]', 0, 'A2'),
  ('negotiate', '/nɪˈɡoʊʃieɪt/', '这个词更接近哪个意思？', '["谈判；协商","忽视；放弃","搬运；投递"]', 0, 'B1'),
  ('deadline', '/ˈdedlaɪn/', '这个词更接近哪个意思？', '["截止日期","起跑线","边界墙"]', 0, 'B1'),
  ('confirm', '/kənˈfɜːrm/', '这个词更接近哪个意思？', '["确认","否认","推迟"]', 0, 'B1'),
  ('budget', '/ˈbʌdʒɪt/', '这个词更接近哪个意思？', '["预算","包裹","按钮"]', 0, 'B1'),
  ('reliable', '/rɪˈlaɪəbl/', '这个词更接近哪个意思？', '["可靠的","稀有的","迅速的"]', 0, 'B1'),
  ('shipment', '/ˈʃɪpmənt/', '这个词更接近哪个意思？', '["货运；发货","奖学金","日程表"]', 0, 'B2'),
  ('incentive', '/ɪnˈsentɪv/', '这个词更接近哪个意思？', '["激励；诱因","事故","发票"]', 0, 'B2'),
  ('compromise', '/ˈkɑːmprəmaɪz/', '这个词更接近哪个意思？', '["妥协；折中","承诺","抱怨"]', 0, 'B2'),
  ('outline', '/ˈaʊtlaɪn/', '这个词更接近哪个意思？', '["提纲；概述","外线","超时"]', 0, 'B2'),
  ('feasible', '/ˈfiːzəbl/', '这个词更接近哪个意思？', '["可行的","易碎的","时尚的"]', 0, 'B2'),
  ('leverage', '/ˈlevərɪdʒ/', '这个词更接近哪个意思？', '["利用；杠杆作用","平均","泄漏"]', 0, 'C1'),
  ('nuance', '/ˈnuːɑːns/', '这个词更接近哪个意思？', '["细微差别","噪音","小说"]', 0, 'C1'),
  ('mitigate', '/ˈmɪtɪɡeɪt/', '这个词更接近哪个意思？', '["缓解；减轻","迁移","模仿"]', 0, 'C1'),
  ('scrutiny', '/ˈskruːtəni/', '这个词更接近哪个意思？', '["仔细审查","雕塑","捷径"]', 0, 'C1'),
  ('pragmatic', '/præɡˈmætɪk/', '这个词更接近哪个意思？', '["务实的","诗意的","被动的"]', 0, 'C1'),
  ('ephemeral', '/ɪˈfemərəl/', '这个词更接近哪个意思？', '["短暂的","永恒的","巨大的"]', 0, 'C2'),
  ('ubiquitous', '/juːˈbɪkwɪtəs/', '这个词更接近哪个意思？', '["无处不在的","独一无二的","模棱两可的"]', 0, 'C2'),
  ('idiosyncrasy', '/ˌɪdiəˈsɪŋkrəsi/', '这个词更接近哪个意思？', '["特质；癖性","成语","身份证明"]', 0, 'C2'),
  ('obfuscate', '/ˈɑːbfəskeɪt/', '这个词更接近哪个意思？', '["使模糊；使人困惑","使喜悦","使加速"]', 0, 'C2'),
  ('sycophant', '/ˈsɪkəfænt/', '这个词更接近哪个意思？', '["阿谀奉承者","哲学家","实验者"]', 0, 'C2');
