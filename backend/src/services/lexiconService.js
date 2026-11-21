const { pool } = require('../db');
const { cleanLemma } = require('./lessonTokenize');

function parseJsonField(raw, fallback) {
  if (raw == null) return fallback;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

function mapFamily(raw) {
  const list = Array.isArray(raw) ? raw : [];
  return list
    .filter((row) => Array.isArray(row) && row.length > 0)
    .map((row) => ({
      word: String(row[0] || ''),
      breakdown: String(row[1] || ''),
      gloss: String(row[2] || ''),
    }))
    .filter((x) => x.word);
}

function mapSynonyms(raw) {
  const list = Array.isArray(raw) ? raw : [];
  return list
    .filter((row) => Array.isArray(row) && row.length > 0)
    .map((row) => ({
      word: String(row[0] || ''),
      zh: String(row[1] || ''),
    }))
    .filter((x) => x.word);
}

function mapConfusables(raw) {
  const list = Array.isArray(raw) ? raw : [];
  const out = [];
  for (const row of list) {
    if (!Array.isArray(row) || row.length < 2) continue;
    const wordsRaw = row[0];
    const words = Array.isArray(wordsRaw)
      ? wordsRaw.map((w) => String(w)).filter(Boolean)
      : [];
    out.push({ words, note: String(row[1] || '') });
  }
  return out;
}

async function getRootById(rootId) {
  if (!rootId) return null;
  const [rows] = await pool.query(
    `SELECT id, root_key, meaning, etym, family_json
     FROM lexicon_roots WHERE id = :id LIMIT 1`,
    { id: rootId },
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    key: row.root_key || '',
    meaning: row.meaning || '',
    etym: row.etym || '',
    family: mapFamily(parseJsonField(row.family_json, [])),
  };
}

/**
 * 按 lemma 查词根/同义/易混；无记录返回 null。
 */
async function lookup(lemmaRaw) {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return null;

  const [rows] = await pool.query(
    `SELECT lemma, breakdown, gloss, root_id, synonyms_json, confusables_json, senses_json
     FROM lexicon_lemmas WHERE lemma = :lemma LIMIT 1`,
    { lemma },
  );
  const row = rows[0];
  if (!row) return null;

  const rootId = row.root_id || '';
  const root = rootId ? await getRootById(rootId) : null;
  const sensesRaw = parseJsonField(row.senses_json, []);

  return {
    lemma: row.lemma,
    breakdown: row.breakdown || '',
    gloss: row.gloss || '',
    rootId,
    synonyms: mapSynonyms(parseJsonField(row.synonyms_json, [])),
    confusables: mapConfusables(parseJsonField(row.confusables_json, [])),
    senses: Array.isArray(sensesRaw) ? sensesRaw.map((s) => String(s)) : [],
    root,
  };
}

module.exports = {
  lookup,
  getRootById,
};
