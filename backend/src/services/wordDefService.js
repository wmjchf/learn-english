const { chatCompletion, parseJsonContent } = require('./llmClient');
const { cleanLemma } = require('./lessonTokenize');
const config = require('../config');

function asString(v, fallback = '') {
  return v == null ? fallback : String(v).trim();
}

function isWeakDef(def, lemma) {
  if (!def) return true;
  const gloss = asString(def.gloss);
  if (!gloss) return true;
  if (gloss.toLowerCase() === String(lemma).toLowerCase()) return true;
  // 缺详解或例句视为不够详细
  if (!asString(def.sense) && !asString(def.exampleEn)) {
    const context = asString(def.context);
    if (!context || context === `本课中的 ${lemma}`) return true;
  }
  return false;
}

function normalizeDef(raw, lemma) {
  return {
    pos: asString(raw?.pos),
    gloss: asString(raw?.gloss, lemma),
    sense: asString(raw?.sense || raw?.detail),
    context: asString(raw?.context),
    root: asString(raw?.root, lemma),
    exampleEn: asString(raw?.exampleEn || raw?.example_en),
    exampleZh: asString(raw?.exampleZh || raw?.example_zh),
  };
}

function normalizeDetailed(raw, lemma) {
  const d = normalizeDef(raw, lemma);
  // gloss 尽量带词性前缀展示友好
  if (d.pos && d.gloss && !d.gloss.startsWith(d.pos)) {
    // 保留分离字段；展示层可拼接
  }
  return d;
}

/**
 * 详细单条释义（点词同步补库）。
 */
async function enrichDefDetailed({ lemma, surface, sentenceHint }) {
  const key = cleanLemma(lemma || surface);
  if (!key) return normalizeDetailed(null, surface || '');
  if (!config.llm.apiKey) return normalizeDetailed(null, key);

  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content:
          'You write detailed Chinese dictionary entries for English learners. JSON only.',
      },
      {
        role: 'user',
        content: `英文词：${surface || key}
可选语境：${sentenceHint || '（无）'}

输出 JSON：
{
  "pos":"词性，如 n./v./adj./phr.",
  "gloss":"简明中文释义，可含近义，约 8-20 字",
  "sense":"用法详解 1-2 句中文，说明常见搭配或使用场合",
  "root":"词根/构词拆分或同族词，无则写原词",
  "exampleEn":"一句自然英文例句，含该词",
  "exampleZh":"例句中文翻译",
  "context":"常见场景提示，一句中文"
}

要求：gloss/sense/exampleZh 必须是中文；exampleEn 必须是英文；不要 markdown。`,
      },
    ],
    temperature: 0.3,
    maxTokens: 420,
    jsonMode: true,
  });

  try {
    return normalizeDetailed(parseJsonContent(result.content), key);
  } catch {
    return normalizeDetailed(null, key);
  }
}

/** @deprecated 兼容旧调用 */
async function enrichDefOne(opts) {
  return enrichDefDetailed(opts);
}

/**
 * 批量详细释义（异步灌库用）。
 */
async function enrichDefsDetailedBatch({ lemmas, sentenceHint }) {
  const list = [...new Set((lemmas || []).map(cleanLemma).filter(Boolean))];
  if (!list.length) return {};
  if (!config.llm.apiKey) {
    return Object.fromEntries(list.map((l) => [l, normalizeDetailed(null, l)]));
  }

  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content:
          'You write detailed Chinese dictionary entries for English learners. JSON object keyed by lemma only.',
      },
      {
        role: 'user',
        content: `为下列英文词各写详细释义（键=原词）：
${list.join(', ')}
可选语境：${sentenceHint || '职场/考试英语'}

每个值格式：
{"pos":"n.","gloss":"简明中文","sense":"用法详解1-2句","root":"词根","exampleEn":"English sentence","exampleZh":"中文翻译","context":"场景提示"}

要求：中文释义详细清楚；例句自然；只输出一个 JSON 对象。`,
      },
    ],
    temperature: 0.3,
    maxTokens: Math.min(3500, 280 * list.length + 200),
    jsonMode: true,
  });

  let raw = {};
  try {
    raw = parseJsonContent(result.content);
  } catch {
    raw = {};
  }
  if (!raw || typeof raw !== 'object') raw = {};

  const out = {};
  for (const lemma of list) {
    const key = Object.keys(raw).find((k) => cleanLemma(k) === lemma);
    out[lemma] = normalizeDetailed(key ? raw[key] : null, lemma);
  }
  return out;
}

/** @deprecated */
async function enrichDefsBatch(opts) {
  return enrichDefsDetailedBatch({
    lemmas: opts.lemmas,
    sentenceHint: [opts.theme, opts.articlePlain].filter(Boolean).join(' ').slice(0, 200),
  });
}

function mergeDefs(base, patch) {
  const out = { ...(base || {}) };
  for (const [k, v] of Object.entries(patch || {})) {
    const lemma = cleanLemma(k);
    if (!lemma) continue;
    if (isWeakDef(out[lemma], lemma) || !out[lemma]) {
      out[lemma] = normalizeDetailed(v, lemma);
    } else if (v) {
      out[lemma] = {
        pos: asString(out[lemma].pos) || asString(v.pos),
        gloss: asString(out[lemma].gloss) || asString(v.gloss, lemma),
        sense: asString(out[lemma].sense) || asString(v.sense),
        context: asString(out[lemma].context) || asString(v.context),
        root: asString(out[lemma].root) || asString(v.root, lemma),
        exampleEn: asString(out[lemma].exampleEn) || asString(v.exampleEn),
        exampleZh: asString(out[lemma].exampleZh) || asString(v.exampleZh),
      };
    }
  }
  return out;
}

module.exports = {
  isWeakDef,
  normalizeDef: normalizeDetailed,
  enrichDefDetailed,
  enrichDefOne,
  enrichDefsDetailedBatch,
  enrichDefsBatch,
  mergeDefs,
  cleanLemma,
};
