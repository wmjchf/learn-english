-- 职业 / 兴趣 / 场景选项刷新（旧项保留但停用，避免历史画像校验失败）
SET NAMES utf8mb4;

ALTER TABLE `user_profiles`
  ADD COLUMN `scene_raw` VARCHAR(128) DEFAULT NULL AFTER `job_raw`;

UPDATE `option_catalog`
SET `enabled` = 0
WHERE `kind` IN ('interest', 'scene', 'job');

INSERT INTO `option_catalog` (`kind`, `code`, `label`, `subtitle`, `sort`, `enabled`, `allow_custom`) VALUES
  -- 职业
  ('job', 'trade', '外贸/跨境电商', NULL, 10, 1, 0),
  ('job', 'engineer', '程序员/IT', NULL, 20, 1, 0),
  ('job', 'college', '大学生', NULL, 30, 1, 0),
  ('job', 'k12', '中小学', NULL, 40, 1, 0),
  ('job', 'office', '职场白领', NULL, 50, 1, 0),
  ('job', 'marketing', '市场/运营', NULL, 60, 1, 0),
  ('job', 'medical', '医护/科研', NULL, 70, 1, 0),
  ('job', 'hospitality', '酒店/旅游/空乘', NULL, 80, 1, 0),
  ('job', 'other', '自填', '可输入具体职业', 90, 1, 1),

  -- 兴趣：认知成长
  ('interest', 'tech', '科技', NULL, 10, 1, 0),
  ('interest', 'ai', 'AI', NULL, 20, 1, 0),
  ('interest', 'finance', '财经', NULL, 30, 1, 0),
  ('interest', 'startup', '创业', NULL, 40, 1, 0),
  ('interest', 'history', '历史', NULL, 50, 1, 0),
  ('interest', 'psych', '社科心理', NULL, 60, 1, 0),
  ('interest', 'self_improve', '自我提升', NULL, 70, 1, 0),
  -- 兴趣：生活
  ('interest', 'food', '美食', NULL, 80, 1, 0),
  ('interest', 'travel', '旅行', NULL, 90, 1, 0),
  -- 兴趣：运动
  ('interest', 'basketball', '篮球', NULL, 100, 1, 0),
  ('interest', 'football', '足球', NULL, 110, 1, 0),
  ('interest', 'tennis', '网球', NULL, 120, 1, 0),
  ('interest', 'fitness', '健身', NULL, 130, 1, 0),
  ('interest', 'yoga', '瑜伽', NULL, 140, 1, 0),
  ('interest', 'running', '跑步', NULL, 150, 1, 0),
  ('interest', 'camping', '露营', NULL, 160, 1, 0),
  -- 兴趣：娱乐
  ('interest', 'movie', '电影', NULL, 170, 1, 0),
  ('interest', 'music', '音乐', NULL, 180, 1, 0),
  ('interest', 'anime', '二次元', NULL, 190, 1, 0),
  ('interest', 'game', '游戏', NULL, 200, 1, 0),
  ('interest', 'variety', '综艺', NULL, 210, 1, 0),

  -- 场景
  ('scene', 'study_abroad', '留学', NULL, 10, 1, 0),
  ('scene', 'travel_abroad', '出国旅游', NULL, 20, 1, 0),
  ('scene', 'exam', '考试', NULL, 30, 1, 0),
  ('scene', 'daily', '日常生活', NULL, 40, 1, 0),
  ('scene', 'workplace', '职场商务', NULL, 50, 1, 0),
  ('scene', 'trade', '外贸/跨境电商', NULL, 60, 1, 0),
  ('scene', 'entertainment', '兴趣娱乐', NULL, 70, 1, 0),
  ('scene', 'professional', '专业行业', NULL, 80, 1, 0),
  ('scene', 'other', '自填', '可输入具体场景', 90, 1, 1)
ON DUPLICATE KEY UPDATE
  `label` = VALUES(`label`),
  `subtitle` = VALUES(`subtitle`),
  `sort` = VALUES(`sort`),
  `enabled` = VALUES(`enabled`),
  `allow_custom` = VALUES(`allow_custom`);
