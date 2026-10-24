const { pool } = require('../db');
const { cleanLemma } = require('./lessonTokenize');
const wordDefService = require('./wordDefService');

/** 进行中的补全，避免并发重复打 LLM */
const pending = new Set();

function emptyEntry(lemma) {
  return {
    lemma,
    pos: null,
    gloss: null,
    sense: null,
    root: lemma,
    exampleEn: null,
    exampleZh: null,
    context: null,
    source: null,
    rich: false,
  };
}

function mapRow(row) {
  if (!row) return null;
  const lemma = cleanLemma(row.lemma);
  const gloss = String(row.gloss || '').trim();
  const sense = String(row.sense || '').trim();
  const exampleEn = String(row.example_en || '').trim();
  return {
    lemma,
    pos: String(row.pos || '').trim() || null,
    gloss: gloss || null,
    sense: sense || null,
    root: String(row.root || lemma).trim() || lemma,
    exampleEn: exampleEn || null,
    exampleZh: String(row.example_zh || '').trim() || null,
    context: String(row.context || '').trim() || null,
    source: row.source || null,
    rich: Boolean(gloss && sense && exampleEn),
  };
}

function needsEnrich(entry, lemma) {
  if (!entry?.gloss) return true;
  if (entry.gloss.toLowerCase() === String(lemma).toLowerCase()) return true;
  // 要「更详细」：缺详解或例句也补
  if (!entry.sense || !entry.exampleEn) return true;
  return false;
}

function toLessonDef(entry, lemma) {
  const e = entry || emptyEntry(lemma);
  return {
    gloss: e.gloss || lemma,
    pos: e.pos || '',
    sense: e.sense || '',
    context: e.context || e.sense || '',
    root: e.root || lemma,
    exampleEn: e.exampleEn || '',
    exampleZh: e.exampleZh || '',
  };
}

async function getMany(lemmas) {
  const list = [...new Set((lemmas || []).map(cleanLemma).filter(Boolean))];
  const out = {};
  list.forEach((l) => {
    out[l] = emptyEntry(l);
  });
  if (!list.length) return out;

  const placeholders = list.map((_, i) => `:l${i}`).join(',');
  const params = {};
  list.forEach((l, i) => {
    params[`l${i}`] = l;
  });
  const [rows] = await pool.query(
    `SELECT * FROM word_gloss WHERE lemma IN (${placeholders})`,
    params,
  );
  for (const row of rows) {
    const mapped = mapRow(row);
    if (mapped) out[mapped.lemma] = mapped;
  }
  return out;
}

async function getOne(lemmaRaw) {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return emptyEntry('');
  const map = await getMany([lemma]);
  return map[lemma];
}

async function upsert(lemmaRaw, def, source = 'llm') {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return;
  const gloss = String(def.gloss || '').trim().slice(0, 512);
  if (!gloss) return;
  await pool.query(
    `INSERT INTO word_gloss
       (lemma, pos, gloss, sense, root, example_en, example_zh, context, source)
     VALUES
       (:lemma, :pos, :gloss, :sense, :root, :exampleEn, :exampleZh, :context, :source)
     ON DUPLICATE KEY UPDATE
       pos = COALESCE(VALUES(pos), pos),
       gloss = VALUES(gloss),
       sense = COALESCE(VALUES(sense), sense),
       root = COALESCE(VALUES(root), root),
       example_en = COALESCE(VALUES(example_en), example_en),
       example_zh = COALESCE(VALUES(example_zh), example_zh),
       context = COALESCE(VALUES(context), context),
       source = VALUES(source)`,
    {
      lemma,
      pos: def.pos ? String(def.pos).slice(0, 64) : null,
      gloss,
      sense: def.sense ? String(def.sense).slice(0, 768) : null,
      root: def.root ? String(def.root).slice(0, 128) : lemma,
      exampleEn: def.exampleEn ? String(def.exampleEn).slice(0, 512) : null,
      exampleZh: def.exampleZh ? String(def.exampleZh).slice(0, 512) : null,
      context: def.context ? String(def.context).slice(0, 512) : null,
      source,
    },
  );
  // 顺带回写 bank_words 短释义，列表兜底仍可用
  await pool.query(
    `UPDATE bank_words
     SET gloss = :gloss, root = COALESCE(:root, root)
     WHERE lemma = :lemma AND (gloss IS NULL OR gloss = '' OR gloss = lemma)`,
    { lemma, gloss, root: def.root || null },
  );
}

/**
 * 同步补一条（点词用）：库有详解则返回，否则 LLM 后入库。
 */
async function ensureOne(lemmaRaw, { surface, sentenceHint } = {}) {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return emptyEntry('');
  const existing = await getOne(lemma);
  if (!needsEnrich(existing, lemma)) return existing;

  if (pending.has(lemma)) {
    // 已有任务在跑：稍等再读库
    await sleep(800);
    return getOne(lemma);
  }

  pending.add(lemma);
  try {
    const def = await wordDefService.enrichDefDetailed({
      lemma,
      surface: surface || lemma,
      sentenceHint,
    });
    await upsert(lemma, def, 'llm');
    return getOne(lemma);
  } catch (err) {
    console.warn('[word_gloss] ensureOne failed:', lemma, err.message);
    return existing;
  } finally {
    pending.delete(lemma);
  }
}

/**
 * 异步批量补全：不阻塞调用方。
 */
function ensureManyAsync(lemmas, { sentenceHint } = {}) {
  const list = [...new Set((lemmas || []).map(cleanLemma).filter(Boolean))];
  if (!list.length) return;
  setImmediate(() => {
    enrichMissing(list, { sentenceHint }).catch((err) => {
      console.warn('[word_gloss] ensureManyAsync:', err.message);
    });
  });
}

async function enrichMissing(lemmas, { sentenceHint } = {}) {
  const map = await getMany(lemmas);
  const need = lemmas.filter((l) => needsEnrich(map[l], l) && !pending.has(l));
  if (!need.length) return;

  // 分批，每批最多 8 个，控制单次 token
  for (let i = 0; i < need.length; i += 8) {
    const batch = need.slice(i, i + 8);
    batch.forEach((l) => pending.add(l));
    try {
      const patch = await wordDefService.enrichDefsDetailedBatch({
        lemmas: batch,
        sentenceHint,
      });
      for (const lemma of batch) {
        if (patch[lemma]?.gloss) {
          await upsert(lemma, patch[lemma], 'llm');
        }
      }
    } catch (err) {
      console.warn('[word_gloss] batch failed:', err.message);
    } finally {
      batch.forEach((l) => pending.delete(l));
    }
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = {
  getMany,
  getOne,
  upsert,
  ensureOne,
  ensureManyAsync,
  needsEnrich,
  toLessonDef,
  emptyEntry,
};
