const { pool } = require('../db');
const { cleanLemma } = require('./lessonTokenize');

/**
 * 从 bank_words 按 ord 环形抽取目标词。
 * 仅取已有 LLM 详解（word_gloss：gloss + sense + example_en）的词。
 * @param {string[]} [excludeLemmas] 已在往日课出现过的词，优先跳过
 */
async function pickTargetLemmas(
  bankCode,
  cursorOrd = 0,
  count = 12,
  { excludeLemmas = [] } = {},
) {
  const code = bankCode || 'business';
  const [rows] = await pool.query(
    `SELECT b.lemma
     FROM bank_words b
     INNER JOIN word_gloss g ON g.lemma = b.lemma
     WHERE b.bank_code = :code
       AND g.gloss IS NOT NULL AND TRIM(g.gloss) <> ''
       AND g.sense IS NOT NULL AND TRIM(g.sense) <> ''
       AND g.example_en IS NOT NULL AND TRIM(g.example_en) <> ''
     ORDER BY b.\`ord\` ASC, b.id ASC`,
    { code },
  );
  if (!rows.length) {
    // 本库无详解词时再试 business
    if (code !== 'business') {
      return pickTargetLemmas('business', cursorOrd, count, { excludeLemmas });
    }
    // 区分：词库空 vs 详解未灌
    const [all] = await pool.query(
      `SELECT COUNT(*) AS c FROM bank_words WHERE bank_code = :code`,
      { code },
    );
    if (!Number(all[0]?.c || 0)) {
      const err = new Error(
        '词库 bank_words 为空，请先执行: node scripts/seed-bank-words.js',
      );
      err.status = 500;
      err.code = 'BANK_WORDS_EMPTY';
      throw err;
    }
    const err = new Error(
      '没有带详细释义的词可成文，请先执行: pnpm db:seed-gloss',
    );
    err.status = 500;
    err.code = 'WORD_GLOSS_EMPTY';
    throw err;
  }
  const exclude = new Set(
    (excludeLemmas || []).map((l) => cleanLemma(l)).filter(Boolean),
  );
  const allLemmas = rows.map((r) => r.lemma).filter(Boolean);
  // 优先从未用过的词里抽；不够再回退全库环形
  const fresh = exclude.size
    ? allLemmas.filter((l) => !exclude.has(cleanLemma(l)))
    : allLemmas;
  const lemmas = fresh.length >= Math.max(1, count) ? fresh : allLemmas;
  const n = Math.min(Math.max(1, count), lemmas.length);
  const start = ((cursorOrd % lemmas.length) + lemmas.length) % lemmas.length;
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(lemmas[(start + i) % lemmas.length]);
  }
  return out;
}

/**
 * 批量查释义。
 * @returns {Record<string, {gloss:string|null, context:null, root:string}>}
 */
async function getDefs(lemmas) {
  const list = [
    ...new Set((lemmas || []).map(cleanLemma).filter(Boolean)),
  ];
  const out = {};
  if (!list.length) return out;

  const placeholders = list.map((_, i) => `:l${i}`).join(',');
  const params = {};
  list.forEach((l, i) => {
    params[`l${i}`] = l;
  });
  const [rows] = await pool.query(
    `SELECT lemma, gloss, root FROM bank_words
     WHERE lemma IN (${placeholders})
     ORDER BY id ASC`,
    params,
  );
  for (const row of rows) {
    const lemma = cleanLemma(row.lemma);
    if (out[lemma]?.gloss) continue;
    const gloss = String(row.gloss || '').trim();
    out[lemma] = {
      gloss: gloss || null,
      context: null,
      root: String(row.root || lemma).trim() || lemma,
    };
  }
  for (const lemma of list) {
    if (!out[lemma]) {
      out[lemma] = { gloss: null, context: null, root: lemma };
    }
  }
  return out;
}

async function getDef(lemmaRaw) {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return { gloss: null, context: null, root: '' };
  const map = await getDefs([lemma]);
  return map[lemma];
}

async function countByBank(bankCode) {
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS c FROM bank_words WHERE bank_code = :code`,
    { code: bankCode },
  );
  return Number(rows[0]?.c || 0);
}

module.exports = {
  pickTargetLemmas,
  getDefs,
  getDef,
  countByBank,
};
