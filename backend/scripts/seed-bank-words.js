/**
 * 把 JS 种子灌进 bank_words（可重复执行）。
 * 用法：node scripts/seed-bank-words.js
 *
 * 运行时抽词/释义只查数据库；本脚本仅用于初始化或扩词导入。
 */
require('dotenv').config();
const { pool } = require('../src/db');
const { POOLS } = require('../src/data/bankWordPools');

async function main() {
  let total = 0;
  for (const [bankCode, list] of Object.entries(POOLS)) {
    let ord = 0;
    for (const item of list) {
      const lemma = String(item.lemma || '')
        .trim()
        .toLowerCase();
      if (!lemma) continue;
      await pool.query(
        `INSERT INTO bank_words (bank_code, lemma, gloss, root, \`ord\`)
         VALUES (:bankCode, :lemma, :gloss, :root, :ord)
         ON DUPLICATE KEY UPDATE
           gloss = VALUES(gloss),
           root = VALUES(root),
           \`ord\` = VALUES(\`ord\`)`,
        {
          bankCode,
          lemma,
          gloss: String(item.gloss || '').slice(0, 256),
          root: item.root ? String(item.root).slice(0, 128) : null,
          ord,
        },
      );
      ord += 1;
      total += 1;
    }
    await pool.query(
      `UPDATE word_banks SET word_count = :n WHERE code = :code`,
      { n: list.length, code: bankCode },
    );
    console.log(`[seed-bank-words] ${bankCode}: ${list.length}`);
  }
  console.log(`[seed-bank-words] upserted ${total} rows into bank_words`);
  await pool.end();
}

main().catch(async (err) => {
  console.error('[seed-bank-words] failed:', err.message);
  try {
    await pool.end();
  } catch {
    /* ignore */
  }
  process.exit(1);
});
