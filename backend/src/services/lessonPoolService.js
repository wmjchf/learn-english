const { pool } = require('../db');
const seedDay1 = require('../data/seedLessonDay1');
const profileService = require('./profileService');

/**
 * 确保池中至少有一份 Day1 种子（各等级各一份简化版）。
 */
async function ensureSeedPool() {
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS c FROM lesson_pool WHERE enabled = 1`,
  );
  if (Number(rows[0]?.c || 0) > 0) return;

  const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  for (const level of levels) {
    const pack = {
      ...seedDay1,
      generationLevel: level,
      theme: seedDay1.theme,
    };
    await pool.query(
      `INSERT INTO lesson_pool
         (bank_id, generation_level, scene_codes, theme, list_label, title, content_json, enabled)
       VALUES
         (NULL, :level, NULL, :theme, :listLabel, :title, CAST(:content AS JSON), 1)`,
      {
        level,
        theme: pack.theme,
        listLabel: pack.listLabel,
        title: pack.title,
        content: JSON.stringify(pack),
      },
    );
  }
}

/**
 * 按用户等级 + 词库匹配公共池一篇。
 */
async function matchForUser(userId) {
  await ensureSeedPool();
  const profile = await profileService.ensureProfile(userId);
  const level = profile.generationLevel || profile.abilityLevel || 'B1';
  const bankId = profile.primaryBankId || null;

  // 优先同库+同级，再同级任意库，再任意
  const queries = [
    bankId
      ? {
          sql: `SELECT * FROM lesson_pool
                WHERE enabled = 1 AND generation_level = :level AND bank_id = :bankId
                ORDER BY id ASC LIMIT 1`,
          params: { level, bankId },
        }
      : null,
    {
      sql: `SELECT * FROM lesson_pool
            WHERE enabled = 1 AND generation_level = :level
            ORDER BY (bank_id IS NULL) DESC, id ASC LIMIT 1`,
      params: { level },
    },
    {
      sql: `SELECT * FROM lesson_pool
            WHERE enabled = 1
            ORDER BY id ASC LIMIT 1`,
      params: {},
    },
  ].filter(Boolean);

  for (const q of queries) {
    const [rows] = await pool.query(q.sql, q.params);
    if (rows.length) {
      let content = rows[0].content_json;
      if (typeof content === 'string') {
        try {
          content = JSON.parse(content);
        } catch {
          content = { ...seedDay1 };
        }
      }
      return {
        poolId: rows[0].id,
        bankId: rows[0].bank_id,
        level: rows[0].generation_level,
        pack: {
          ...content,
          generationLevel: rows[0].generation_level,
          theme: rows[0].theme || content.theme,
          listLabel: rows[0].list_label || content.listLabel,
          title: rows[0].title || content.title,
        },
      };
    }
  }
  return null;
}

module.exports = {
  ensureSeedPool,
  matchForUser,
};
