const { pool } = require('../db');
const wordDefService = require('./wordDefService');
const { cleanLemma } = require('./lessonTokenize');

function parseJson(value) {
  if (value == null) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return {};
  }
}

async function loadLesson(lessonId, userId) {
  if (!lessonId) return null;
  const [rows] = await pool.query(
    `SELECT * FROM lessons
     WHERE id = :id AND (user_id = :userId OR user_id IS NULL)
     LIMIT 1`,
    { id: lessonId, userId },
  );
  if (!rows.length) return null;
  const row = rows[0];
  return {
    id: row.id,
    content: parseJson(row.content_json),
  };
}

async function persistDef(lessonId, lemma, def) {
  const [rows] = await pool.query(
    `SELECT content_json FROM lessons WHERE id = :id LIMIT 1`,
    { id: lessonId },
  );
  if (!rows.length) return;
  const content = parseJson(rows[0].content_json);
  content.defs = content.defs || {};
  content.defs[lemma] = def;
  await pool.query(
    `UPDATE lessons SET content_json = CAST(:content AS JSON) WHERE id = :id`,
    { id: lessonId, content: JSON.stringify(content) },
  );
}

/**
 * 点词查询：日课内嵌 defs 优先 → 弱释义则 LLM 补并回写日课。
 */
async function lookup(userId, { surface, lemma, lessonId } = {}) {
  const surfaceText = String(surface || '').trim();
  const resolvedLemma =
    cleanLemma(lemma) ||
    cleanLemma(surfaceText) ||
    surfaceText.toLowerCase();

  if (!resolvedLemma) {
    const err = new Error('请提供单词');
    err.status = 400;
    throw err;
  }

  const lesson = await loadLesson(lessonId ? Number(lessonId) : null, userId);
  const content = lesson?.content || {};
  const targets = Array.isArray(content.targetLemmas)
    ? content.targetLemmas.map(cleanLemma)
    : [];
  const isTarget = targets.includes(resolvedLemma);

  let def = content.defs?.[resolvedLemma] || null;
  // 兼容 defs 键大小写不一致
  if (!def && content.defs) {
    const key = Object.keys(content.defs).find(
      (k) => cleanLemma(k) === resolvedLemma,
    );
    if (key) def = content.defs[key];
  }

  let source = def && !wordDefService.isWeakDef(def, resolvedLemma)
    ? 'lesson'
    : null;

  if (!source) {
    // 从短文中抽一句含该词的片段作语境提示
    const corpus = `${content.article?.enPlain || ''}\n${
      content.dialog?.enPlain || ''
    }`;
    const re = new RegExp(
      `[^.!?\\n]*\\b${resolvedLemma.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\w*\\b[^.!?\\n]*[.!?]?`,
      'i',
    );
    const m = corpus.match(re);
    const sentenceHint = m ? m[0].trim() : '';

    try {
      def = await wordDefService.enrichDefOne({
        lemma: resolvedLemma,
        surface: surfaceText || resolvedLemma,
        sentenceHint,
      });
      source = wordDefService.isWeakDef(def, resolvedLemma) ? 'stub' : 'llm';
      if (lesson?.id && source === 'llm') {
        await persistDef(lesson.id, resolvedLemma, def);
      }
    } catch {
      def = wordDefService.normalizeDef(def, resolvedLemma);
      source = 'stub';
    }
  }

  return {
    surface: surfaceText || resolvedLemma,
    lemma: resolvedLemma,
    isTarget,
    gloss: def.gloss,
    context: def.context,
    root: def.root,
    source,
  };
}

module.exports = { lookup };
