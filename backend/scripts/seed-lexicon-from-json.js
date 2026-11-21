/**
 * 把 App 侧 lemma_index.json（或同结构文件）灌进 lexicon_* 表。
 *
 * 用法：
 *   node scripts/seed-lexicon-from-json.js
 *   node scripts/seed-lexicon-from-json.js --file=../app/assets/lexicon/lemma_index.json
 *   node scripts/seed-lexicon-from-json.js --replace
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

function parseArgs(argv) {
  const out = {
    file: path.resolve(__dirname, '../../app/assets/lexicon/lemma_index.json'),
    replace: false,
  };
  for (const a of argv) {
    if (a === '--replace') out.replace = true;
    else if (a.startsWith('--file=')) out.file = path.resolve(a.slice(7).trim());
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.file)) {
    throw new Error(`找不到索引文件: ${args.file}`);
  }
  const payload = JSON.parse(fs.readFileSync(args.file, 'utf8'));
  const roots = payload.roots || {};
  const lemmas = payload.lemmas || {};

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    if (args.replace) {
      await conn.query('DELETE FROM lexicon_lemmas');
      await conn.query('DELETE FROM lexicon_roots');
      console.log('[seed-lexicon] cleared lexicon_*');
    }

    let rootN = 0;
    for (const [id, raw] of Object.entries(roots)) {
      const family = Array.isArray(raw.f) ? raw.f : [];
      await conn.query(
        `INSERT INTO lexicon_roots (id, root_key, meaning, etym, family_json)
         VALUES (:id, :rootKey, :meaning, :etym, CAST(:family AS JSON))
         ON DUPLICATE KEY UPDATE
           root_key = VALUES(root_key),
           meaning = VALUES(meaning),
           etym = VALUES(etym),
           family_json = VALUES(family_json)`,
        {
          id,
          rootKey: String(raw.k || '').slice(0, 128),
          meaning: String(raw.m || '').slice(0, 512),
          etym: String(raw.e || '').slice(0, 256),
          family: JSON.stringify(family),
        },
      );
      rootN += 1;
    }

    let lemmaN = 0;
    for (const [lemma, raw] of Object.entries(lemmas)) {
      const key = String(lemma || '')
        .trim()
        .toLowerCase();
      if (!key) continue;
      await conn.query(
        `INSERT INTO lexicon_lemmas
           (lemma, breakdown, gloss, root_id, synonyms_json, confusables_json, senses_json)
         VALUES
           (:lemma, :breakdown, :gloss, :rootId,
            CAST(:synonyms AS JSON), CAST(:confusables AS JSON), CAST(:senses AS JSON))
         ON DUPLICATE KEY UPDATE
           breakdown = VALUES(breakdown),
           gloss = VALUES(gloss),
           root_id = VALUES(root_id),
           synonyms_json = VALUES(synonyms_json),
           confusables_json = VALUES(confusables_json),
           senses_json = VALUES(senses_json)`,
        {
          lemma: key.slice(0, 64),
          breakdown: String(raw.b || '').slice(0, 256),
          gloss: String(raw.g || '').slice(0, 512),
          rootId: raw.r ? String(raw.r).slice(0, 64) : null,
          synonyms: JSON.stringify(raw.s || null),
          confusables: JSON.stringify(raw.c || null),
          senses: JSON.stringify(raw.m || null),
        },
      );
      lemmaN += 1;
      if (lemmaN % 1000 === 0) {
        console.log(`[seed-lexicon] lemmas ${lemmaN}…`);
      }
    }

    await conn.commit();
    console.log(
      `[seed-lexicon] done roots=${rootN} lemmas=${lemmaN} file=${args.file}`,
    );
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

main()
  .catch(async (err) => {
    console.error('[seed-lexicon] failed:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await pool.end();
    } catch {
      /* ignore */
    }
  });
