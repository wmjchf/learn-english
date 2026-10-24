const { cleanLemma } = require('./lessonTokenize');
const bankWordService = require('./bankWordService');

function normalizeEntry(lemma, row) {
  const gloss = String(row?.gloss || '').trim();
  const root = String(row?.root || lemma).trim() || lemma;
  return {
    gloss: gloss || null,
    context: null,
    root,
  };
}

/** 批量查释义：读数据库 bank_words */
async function getMany(lemmas) {
  return bankWordService.getDefs(lemmas);
}

async function getOne(lemmaRaw) {
  return bankWordService.getDef(lemmaRaw);
}

/** 把词库释义写入日课 defs（目标词 + 复习词） */
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
      context: d.context || '',
      root: d.root || lemma,
    };
  }
  lesson.defs = defs;
  return lesson;
}

module.exports = {
  getMany,
  getOne,
  attachDefsToLesson,
  normalizeEntry,
};
