/**
 * 基于 bank_words 批量预生成 LLM 详细释义 → word_gloss
 *
 * 用法：
 *   node scripts/seed-word-gloss.js
 *   node scripts/seed-word-gloss.js --bank=business --limit=50
 *   node scripts/seed-word-gloss.js --batch=6 --delay=800
 *   node scripts/seed-word-gloss.js --force          # 已有详解也重跑
 *   node scripts/seed-word-gloss.js --dry-run        # 只统计不写库
 *
 * 待处理按 bank_words.ord 推进（非字母序）。
 * 需要：DASHSCOPE_API_KEY，且已 migrate 015_word_gloss
 */
require('dotenv').config();
const { pool } = require('../src/db');
const config = require('../src/config');
const wordDefService = require('../src/services/wordDefService');
const wordGlossService = require('../src/services/wordGlossService');
const { cleanLemma } = require('../src/services/lessonTokenize');

function parseArgs(argv) {
  const out = {
    bank: null,
    limit: 0,
    batch: 8,
    delay: 600,
    force: false,
    dryRun: false,
    hint: '职场 / 商务英语学习',
  };
  for (const a of argv) {
    if (a === '--force') out.force = true;
    else if (a === '--dry-run') out.dryRun = true;
    else if (a.startsWith('--bank=')) out.bank = a.slice(7).trim() || null;
    else if (a.startsWith('--limit=')) out.limit = Math.max(0, Number(a.slice(8)) || 0);
    else if (a.startsWith('--batch=')) {
      out.batch = Math.min(12, Math.max(1, Number(a.slice(8)) || 8));
    } else if (a.startsWith('--delay=')) {
      out.delay = Math.max(0, Number(a.slice(8)) || 0);
    } else if (a.startsWith('--hint=')) {
      out.hint = a.slice(7).trim() || out.hint;
    }
  }
  return out;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function loadLemmas({ bank, force, limit }) {
  const params = {};
  // 用 MIN(ord) 聚合，兼容 MySQL DISTINCT + ORDER BY 限制
  let sql = `
    SELECT b.lemma, MIN(b.\`ord\`) AS ord_min, MIN(b.id) AS id_min
    FROM bank_words b
    LEFT JOIN word_gloss g ON g.lemma = b.lemma
    WHERE b.lemma IS NOT NULL AND b.lemma <> ''
  `;
  if (bank) {
    sql += ' AND b.bank_code = :bank';
    params.bank = bank;
  }
  if (!force) {
    sql += ` AND (
      g.lemma IS NULL
      OR g.gloss IS NULL OR g.gloss = ''
      OR g.sense IS NULL OR g.sense = ''
      OR g.example_en IS NULL OR g.example_en = ''
    )`;
  }
  sql += ' GROUP BY b.lemma';
  // 跟打乱后的学习序一致，避免按首字母先灌详解
  sql += ' ORDER BY ord_min ASC, id_min ASC';
  if (limit > 0) {
    sql += ' LIMIT :lim';
    params.lim = limit;
  }

  const [rows] = await pool.query(sql, params);
  return rows.map((r) => cleanLemma(r.lemma)).filter(Boolean);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  console.log('[seed-word-gloss] options', opts);

  if (!config.llm.apiKey) {
    throw new Error('未配置 DASHSCOPE_API_KEY');
  }

  const lemmas = await loadLemmas(opts);
  console.log(`[seed-word-gloss] pending lemmas: ${lemmas.length}`);
  if (!lemmas.length) {
    console.log('[seed-word-gloss] nothing to do');
    await pool.end();
    return;
  }
  if (opts.dryRun) {
    console.log('[seed-word-gloss] dry-run sample:', lemmas.slice(0, 20));
    await pool.end();
    return;
  }

  let ok = 0;
  let fail = 0;
  let skip = 0;

  for (let i = 0; i < lemmas.length; i += opts.batch) {
    const batch = lemmas.slice(i, i + opts.batch);
    const n = Math.floor(i / opts.batch) + 1;
    const totalBatches = Math.ceil(lemmas.length / opts.batch);
    process.stdout.write(
      `[seed-word-gloss] batch ${n}/${totalBatches} (${batch.join(', ')}) … `,
    );

    try {
      const patch = await wordDefService.enrichDefsDetailedBatch({
        lemmas: batch,
        sentenceHint: opts.hint,
      });
      for (const lemma of batch) {
        const def = patch[lemma];
        if (!def?.gloss || !String(def.sense || '').trim() || !String(def.exampleEn || '').trim()) {
          skip += 1;
          continue;
        }
        await wordGlossService.upsert(lemma, def, 'llm');
        ok += 1;
      }
      console.log('ok');
    } catch (err) {
      fail += batch.length;
      console.log(`FAIL ${err.message}`);
    }

    if (opts.delay > 0 && i + opts.batch < lemmas.length) {
      await sleep(opts.delay);
    }
  }

  console.log(
    `[seed-word-gloss] done ok=${ok} skip=${skip} fail=${fail} total=${lemmas.length}`,
  );
  await pool.end();
}

main().catch(async (err) => {
  console.error('[seed-word-gloss] failed:', err.message);
  try {
    await pool.end();
  } catch {
    /* ignore */
  }
  process.exit(1);
});
