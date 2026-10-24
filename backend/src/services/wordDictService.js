const { cleanLemma } = require('./lessonTokenize');
const bankWordService = require('./bankWordService');
const wordGlossService = require('./wordGlossService');

function normalizeEntry(lemma, row) {
  const gloss = String(row?.gloss || '').trim();
  const root = String(row?.root || lemma).trim() || lemma;
  return {
    gloss: gloss || null,
    pos: row?.pos || null,
    sense: row?.sense || null,
    context: row?.context || null,
    root,
    exampleEn: row?.exampleEn || null,
    exampleZh: row?.exampleZh || null,
  };
}

function fromGloss(entry, lemma) {
  if (!entry) return normalizeEntry(lemma, null);
  return wordGlossService.toLessonDef(entry, lemma);
}

/** 批量查释义：优先 word_gloss 详解，否则 bank_words 短释义 */
async function getMany(lemmas) {
  const list = [...new Set((lemmas || []).map(cleanLemma).filter(Boolean))];
  const out = {};
  if (!list.length) return out;

  const glossMap = await wordGlossService.getMany(list);
  const needBank = list.filter((l) => !glossMap[l]?.gloss);
  const bankMap = needBank.length
    ? await bankWordService.getDefs(needBank)
    : {};

  for (const lemma of list) {
    const g = glossMap[lemma];
    if (g?.gloss) {
      out[lemma] = fromGloss(g, lemma);
    } else {
      out[lemma] = normalizeEntry(lemma, bankMap[lemma]);
    }
  }
  return out;
}

async function getOne(lemmaRaw) {
  const lemma = cleanLemma(lemmaRaw);
  if (!lemma) return normalizeEntry('', null);
  const map = await getMany([lemma]);
  return map[lemma];
}

/**
 * 把词库/详解写入日课 defs，并异步补全缺详解的词。
 */
async function attachDefsToLesson(lesson) {
  const lemmas = [
    ...(lesson.targetLemmas || []),
    ...(lesson.reviewLemmas || []),
  ];
  const map = await getMany(lemmas);
  const defs = { ...(lesson.defs || {}) };
  for (const raw of lemmas) {
    const lemma = cleanLemma(raw);
    if (!lemma) continue;
    const d = map[lemma] || normalizeEntry(lemma, null);
    defs[lemma] = {
      gloss: d.gloss || lemma,
      pos: d.pos || '',
      sense: d.sense || '',
      context: d.context || d.sense || '',
      root: d.root || lemma,
      exampleEn: d.exampleEn || '',
      exampleZh: d.exampleZh || '',
    };
  }
  lesson.defs = defs;

  // 异步：库空或缺详解 → LLM 补并写 word_gloss（不阻塞成文）
  const hint = [
    lesson.theme,
    typeof lesson.articlePlain === 'string'
      ? lesson.articlePlain.slice(0, 160)
      : '',
  ]
    .filter(Boolean)
    .join(' · ');
  wordGlossService.ensureManyAsync(lemmas, { sentenceHint: hint });

  return lesson;
}

module.exports = {
  getMany,
  getOne,
  attachDefsToLesson,
  normalizeEntry,
};
