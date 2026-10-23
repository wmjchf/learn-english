const { chatCompletion, parseJsonContent } = require('./llmClient');
const { cleanLemma } = require('./lessonTokenize');
const config = require('../config');

function asString(v, fallback = '') {
  return v == null ? fallback : String(v).trim();
}

function isWeakDef(def, lemma) {
  if (!def) return true;
  const gloss = asString(def.gloss);
  const context = asString(def.context);
  if (!gloss) return true;
  if (gloss.toLowerCase() === String(lemma).toLowerCase()) return true;
  if (!context || context === `本课中的 ${lemma}`) return true;
  return false;
}

function normalizeDef(raw, lemma) {
  return {
    gloss: asString(raw?.gloss, lemma),
    context: asString(raw?.context, `本课中的 ${lemma}`),
    root: asString(raw?.root, lemma),
  };
}

/**
 * 批量为目标词补释义（短调用，用于生成后）。
 * @returns {Record<string, {gloss,context,root}>}
 */
async function enrichDefsBatch({ lemmas, articlePlain, dialogPlain, theme }) {
  const list = [...new Set((lemmas || []).map(cleanLemma).filter(Boolean))];
  if (!list.length) return {};
  if (!config.llm.apiKey) {
    return Object.fromEntries(
      list.map((l) => [l, normalizeDef(null, l)]),
    );
  }

  const snippet = [articlePlain, dialogPlain]
    .filter(Boolean)
    .join('\n')
    .slice(0, 900);

  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content:
          'You write compact Chinese dictionary entries for English learners. JSON only.',
      },
      {
        role: 'user',
        content: `课文主题：${theme || ''}
课文摘录：
${snippet}

为下列英文词各写一条释义 JSON（键=原词）：
${list.join(', ')}

格式：
{"word":{"gloss":"直译中文","context":"本课语境一句中文","root":"词根/拆分或同族，无则写原词"}}

要求：gloss 必须是中文，不能只重复英文；context 结合课文；只输出 JSON。`,
      },
    ],
    temperature: 0.2,
    maxTokens: 1200,
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
    out[lemma] = normalizeDef(key ? raw[key] : null, lemma);
  }
  return out;
}

/** 单词汇释义（点词兜底） */
async function enrichDefOne({ lemma, surface, sentenceHint }) {
  const key = cleanLemma(lemma || surface);
  if (!key) {
    return normalizeDef(null, surface || '');
  }
  if (!config.llm.apiKey) {
    return normalizeDef(null, key);
  }

  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content: 'JSON only. Chinese gloss for English learners.',
      },
      {
        role: 'user',
        content: `词：${surface || key}
语境句：${sentenceHint || '（无）'}

输出：{"gloss":"直译中文","context":"结合语境的中文意思","root":"词根拆分或同族"}`,
      },
    ],
    temperature: 0.2,
    maxTokens: 220,
  });

  try {
    const raw = parseJsonContent(result.content);
    return normalizeDef(raw, key);
  } catch {
    return normalizeDef(null, key);
  }
}

function mergeDefs(base, patch) {
  const out = { ...(base || {}) };
  for (const [k, v] of Object.entries(patch || {})) {
    const lemma = cleanLemma(k);
    if (!lemma) continue;
    if (isWeakDef(out[lemma], lemma) || !out[lemma]) {
      out[lemma] = normalizeDef(v, lemma);
    } else if (v) {
      // 已有好释义则保留；缺字段时补齐
      out[lemma] = {
        gloss: asString(out[lemma].gloss) || asString(v.gloss, lemma),
        context: asString(out[lemma].context) || asString(v.context),
        root: asString(out[lemma].root) || asString(v.root, lemma),
      };
    }
  }
  return out;
}

module.exports = {
  isWeakDef,
  normalizeDef,
  enrichDefsBatch,
  enrichDefOne,
  mergeDefs,
  cleanLemma,
};
