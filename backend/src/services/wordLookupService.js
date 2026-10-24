const { pool } = require('../db');
const wordDictService = require('./wordDictService');
const wordDefService = require('./wordDefService');
const wordGlossService = require('./wordGlossService');
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

function pickSentenceHint(content, lemma) {
  const plain =
    content?.articlePlain ||
    (Array.isArray(content?.paragraphs)
      ? content.paragraphs.map((p) => p?.text || p).join(' ')
      : '');
  if (!plain) return content?.theme || '';
  const lower = String(plain);
  const idx = lower.toLowerCase().indexOf(String(lemma).toLowerCase());
  if (idx < 0) return String(plain).slice(0, 160);
  const start = Math.max(0, idx - 40);
  const end = Math.min(plain.length, idx + lemma.length + 80);
  return String(plain).slice(start, end);
}

function packEntry({ surface, lemma, isTarget, def, source }) {
  const d = def || {};
  // gloss 仅释义正文；pos 单独字段，前端再拼接，避免「n. n. 释义」
  let gloss = String(d.gloss || '').trim();
  const pos = String(d.pos || '').trim();
  if (pos && gloss.startsWith(pos)) {
    gloss = gloss.slice(pos.length).trim();
  }
  return {
    surface: surface || lemma,
    lemma,
    isTarget,
    gloss: gloss || lemma,
    pos: pos || null,
    sense: d.sense || null,
    context: d.context || d.sense || null,
    root: d.root || lemma,
    exampleEn: d.exampleEn || null,
    exampleZh: d.exampleZh || null,
    source,
  };
}

/**
 * 点词：日课 defs → word_gloss → bank_words → LLM 同步详解写库。
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
  const sentenceHint = pickSentenceHint(content, resolvedLemma);

  let def = content.defs?.[resolvedLemma] || null;
  if (!def && content.defs) {
    const key = Object.keys(content.defs).find(
      (k) => cleanLemma(k) === resolvedLemma,
    );
    if (key) def = content.defs[key];
  }

  let source =
    def && !wordDefService.isWeakDef(def, resolvedLemma) ? 'lesson' : null;

  // 有详解（sense + 例句）才算够用；否则走 gloss 库 / LLM
  const richEnough =
    source &&
    String(def.sense || '').trim() &&
    String(def.exampleEn || '').trim();

  if (!richEnough) {
    const glossEntry = await wordGlossService.ensureOne(resolvedLemma, {
      surface: surfaceText || resolvedLemma,
      sentenceHint,
    });
    if (glossEntry?.gloss) {
      def = wordGlossService.toLessonDef(glossEntry, resolvedLemma);
      source = glossEntry.source === 'llm' ? 'llm' : 'gloss';
      if (lesson?.id) {
        await persistDef(lesson.id, resolvedLemma, def);
      }
    } else if (!source) {
      const fromDict = await wordDictService.getOne(resolvedLemma);
      if (fromDict.gloss) {
        def = {
          gloss: fromDict.gloss,
          pos: fromDict.pos || '',
          sense: fromDict.sense || '',
          context: fromDict.context || '',
          root: fromDict.root || resolvedLemma,
          exampleEn: fromDict.exampleEn || '',
          exampleZh: fromDict.exampleZh || '',
        };
        source = 'pool';
        if (lesson?.id) await persistDef(lesson.id, resolvedLemma, def);
        // 后台继续补详解
        wordGlossService.ensureManyAsync([resolvedLemma], { sentenceHint });
      } else {
        def = wordDefService.normalizeDef(def, resolvedLemma);
        source = 'stub';
      }
    }
  }

  return packEntry({
    surface: surfaceText || resolvedLemma,
    lemma: resolvedLemma,
    isTarget,
    def,
    source,
  });
}

module.exports = { lookup };
