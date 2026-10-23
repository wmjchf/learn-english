function cleanLemma(surface) {
  return String(surface || '')
    .toLowerCase()
    .replace(/[^a-z'-]/g, '');
}

function isTargetLemma(lemma, targetSet) {
  if (!lemma) return false;
  if (targetSet.has(lemma)) return true;
  for (const t of targetSet) {
    if (!t) continue;
    if (lemma === `${t}s` || lemma === `${t}ed` || lemma === `${t}ing`) {
      return true;
    }
    if (t.endsWith('e') && lemma === `${t.slice(0, -1)}ing`) return true;
    if (lemma.startsWith(t) && lemma.length - t.length <= 3) return true;
  }
  return false;
}

/**
 * 简易英文分词：保留标点为独立 token。
 * @param {string} text
 * @param {string[]} targetLemmas
 * @param {string[]} [reviewLemmas]
 */
function tokenizeEnglish(text, targetLemmas = [], reviewLemmas = []) {
  const targetSet = new Set(
    (targetLemmas || []).map((t) => cleanLemma(t)).filter(Boolean),
  );
  const reviewSet = new Set(
    (reviewLemmas || []).map((t) => cleanLemma(t)).filter(Boolean),
  );
  const parts = String(text || '').match(/[A-Za-z']+|[^\sA-Za-z']+/g) || [];
  return parts
    .map((surface) => surface.trim())
    .filter(Boolean)
    .map((surface) => {
      const lemma = cleanLemma(surface);
      const isTarget = isTargetLemma(lemma, targetSet);
      const isReview =
        !isTarget && isTargetLemma(lemma, reviewSet);
      return {
        surface,
        lemma: lemma || surface,
        isTarget,
        isReview,
      };
    });
}

function coverageScore(text, targetLemmas) {
  const lower = String(text || '').toLowerCase();
  const hit = [];
  const miss = [];
  for (const raw of targetLemmas || []) {
    const t = cleanLemma(raw);
    if (!t) continue;
    const re = new RegExp(`\\b${t.replace(/-/g, '[-]?')}\\w*\\b`, 'i');
    if (re.test(lower)) hit.push(raw);
    else miss.push(raw);
  }
  const total = hit.length + miss.length;
  return {
    hit,
    miss,
    ratio: total === 0 ? 0 : hit.length / total,
  };
}

module.exports = {
  cleanLemma,
  tokenizeEnglish,
  coverageScore,
};
