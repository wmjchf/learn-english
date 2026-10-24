/**
 * 把 JS 种子灌进 bank_words（可重复执行）。
 * 写入前打乱顺序再赋 ord，避免按首字母扎堆抽词。
 *
 * 用法：
 *   node scripts/seed-bank-words.js
 *   node scripts/seed-bank-words.js --reshuffle   # 只重排已有行的 ord，不改 gloss
 *
 * 运行时抽词/释义只查数据库；本脚本仅用于初始化或扩词导入。
 */
require('dotenv').config();
const { pool } = require('../src/db');
const { POOLS } = require('../src/data/bankWordPools');

function shuffleInPlace(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

async function reshuffleExisting() {
  const [banks] = await pool.query(
    `SELECT DISTINCT bank_code FROM bank_words ORDER BY bank_code`,
  );
  let total = 0;
  for (const row of banks) {
    const bankCode = row.bank_code;
    const [rows] = await pool.query(
      `SELECT id FROM bank_words WHERE bank_code = :bankCode ORDER BY id ASC`,
      { bankCode },
    );
    const ids = rows.map((r) => r.id);
    shuffleInPlace(ids);
    for (let ord = 0; ord < ids.length; ord++) {
      await pool.query(
        `UPDATE bank_words SET \`ord\` = :ord WHERE id = :id`,
        { ord, id: ids[ord] },
      );
    }
    total += ids.length;
    console.log(`[seed-bank-words] reshuffle ${bankCode}: ${ids.length}`);
  }
  console.log(`[seed-bank-words] reshuffled ord for ${total} rows`);
}

async function seedFromPools() {
  let total = 0;
  for (const [bankCode, list] of Object.entries(POOLS)) {
    const items = list
      .map((item) => {
        const lemma = String(item.lemma || '')
          .trim()
          .toLowerCase();
        if (!lemma) return null;
        return {
          lemma,
          gloss: String(item.gloss || '').slice(0, 256),
          root: item.root ? String(item.root).slice(0, 128) : null,
        };
      })
      .filter(Boolean);

    shuffleInPlace(items);

    for (let ord = 0; ord < items.length; ord++) {
      const item = items[ord];
      await pool.query(
        `INSERT INTO bank_words (bank_code, lemma, gloss, root, \`ord\`)
         VALUES (:bankCode, :lemma, :gloss, :root, :ord)
         ON DUPLICATE KEY UPDATE
           gloss = VALUES(gloss),
           root = VALUES(root),
           \`ord\` = VALUES(\`ord\`)`,
        {
          bankCode,
          lemma: item.lemma,
          gloss: item.gloss,
          root: item.root,
          ord,
        },
      );
      total += 1;
    }
    await pool.query(
      `UPDATE word_banks SET word_count = :n WHERE code = :code`,
      { n: items.length, code: bankCode },
    );
    console.log(`[seed-bank-words] ${bankCode}: ${items.length} (shuffled ord)`);
  }
  console.log(`[seed-bank-words] upserted ${total} rows into bank_words`);
}

async function main() {
  const reshuffle = process.argv.includes('--reshuffle');
  if (reshuffle) {
    await reshuffleExisting();
  } else {
    await seedFromPools();
  }
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
