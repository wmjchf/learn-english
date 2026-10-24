const { pool } = require('../db');
const profileService = require('./profileService');

/** SRS 间隔天数：step 0→1, 1→2, 2→4, 3→7, 4→15 */
const SRS_INTERVALS = [1, 2, 4, 7, 15];
const IN_ARTICLE_REVIEW_CAP = 4;

const BUCKETS = {
  learning: ['learning', 'vocab'],
  consolidating: ['consolidating'],
  mastered: ['mastered', 'known'],
};

function todayLocalDate(timezone) {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone || 'Asia/Shanghai',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());
  } catch {
    return new Date().toISOString().slice(0, 10);
  }
}

function addDays(iso, days) {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function normalizeLemma(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z'-]/g, '');
}

function parseLessonContent(raw) {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function pickDefEntry(defs, lemma) {
  if (!defs || typeof defs !== 'object' || !lemma) return null;
  if (defs[lemma]) return defs[lemma];
  const key = Object.keys(defs).find((k) => normalizeLemma(k) === lemma);
  return key ? defs[key] : null;
}

/** @returns {{gloss:string|null, context:string|null, root:string|null}} */
function defFromDefs(defs, lemma) {
  const entry = pickDefEntry(defs, lemma);
  if (!entry) {
    return { gloss: null, context: null, root: null };
  }
  let gloss = String(entry.gloss || '').trim().slice(0, 256);
  if (!gloss || gloss.toLowerCase() === lemma) gloss = null;
  let context = String(entry.context || '').trim().slice(0, 512);
  if (!context || context === `本课中的 ${lemma}`) context = null;
  let root = String(entry.root || '').trim().slice(0, 256);
  if (!root) root = null;
  return { gloss, context, root };
}

function glossFromDefs(defs, lemma) {
  return defFromDefs(defs, lemma).gloss;
}

/** 从出处日课 defs 取中文释义（写入或列表回填） */
async function resolveGlossFromLesson(lessonId, lemma) {
  if (!lessonId || !lemma) return null;
  const [rows] = await pool.query(
    `SELECT content_json FROM lessons WHERE id = :id LIMIT 1`,
    { id: lessonId },
  );
  const content = parseLessonContent(rows[0]?.content_json);
  return glossFromDefs(content.defs, lemma);
}

function mapRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    lemma: row.lemma,
    status: row.status,
    srsStep: row.srs_step,
    nextReviewAt: row.next_review_at
      ? row.next_review_at instanceof Date
        ? row.next_review_at.toISOString().slice(0, 10)
        : String(row.next_review_at).slice(0, 10)
      : null,
    passCount: row.pass_count,
    sourceLessonId: row.source_lesson_id,
    bankId: row.bank_id,
    gloss: row.gloss || null,
    context: null,
    root: null,
    sourceTitle: row.source_title || null,
  };
}

function dueAccent(nextReviewAt, today) {
  if (!nextReviewAt) return 'later';
  if (nextReviewAt <= today) return 'today';
  if (nextReviewAt === addDays(today, 1)) return 'tomorrow';
  return 'later';
}

function dueLabel(nextReviewAt, today) {
  if (!nextReviewAt) return null;
  if (nextReviewAt <= today) return '下次复习今天';
  if (nextReviewAt === addDays(today, 1)) return '下次复习明天';
  const a = new Date(`${today}T12:00:00`);
  const b = new Date(`${nextReviewAt}T12:00:00`);
  const days = Math.round((b - a) / 86400000);
  if (days > 0) return `下次复习 ${days} 天后`;
  return '下次复习今天';
}

function statusLabel(status) {
  if (status === 'learning' || status === 'vocab') return '学习中';
  if (status === 'consolidating') return '待巩固';
  if (status === 'mastered' || status === 'known') return '已掌握';
  return status;
}

function bucketOf(status) {
  if (status === 'learning' || status === 'vocab') return 'learning';
  if (status === 'consolidating') return 'consolidating';
  return 'mastered';
}

async function getWord(userId, lemma) {
  const [rows] = await pool.query(
    `SELECT * FROM user_words WHERE user_id = :userId AND lemma = :lemma LIMIT 1`,
    { userId, lemma },
  );
  return mapRow(rows[0]);
}

/**
 * 日课目标词进入「学习中」（已有更高状态不降级）。
 */
async function ensureLearning(userId, lemmas, { lessonId, bankId } = {}) {
  const list = [...new Set((lemmas || []).map(normalizeLemma).filter(Boolean))];
  if (!list.length) return;
  for (const lemma of list) {
    await pool.query(
      `INSERT INTO user_words (user_id, lemma, status, source_lesson_id, bank_id)
       VALUES (:userId, :lemma, 'learning', :lessonId, :bankId)
       ON DUPLICATE KEY UPDATE
         source_lesson_id = COALESCE(source_lesson_id, VALUES(source_lesson_id)),
         bank_id = COALESCE(bank_id, VALUES(bank_id)),
         status = IF(status IN ('mastered','known','consolidating','vocab'), status, 'learning')`,
      {
        userId,
        lemma,
        lessonId: lessonId || null,
        bankId: bankId || null,
      },
    );
  }
}

/** 认识 → 已掌握 */
async function markKnown(userId, lemmaRaw, { lessonId } = {}) {
  const lemma = normalizeLemma(lemmaRaw);
  if (!lemma) {
    const err = new Error('无效单词');
    err.status = 400;
    throw err;
  }
  await pool.query(
    `INSERT INTO user_words (user_id, lemma, status, source_lesson_id, next_review_at, srs_step)
     VALUES (:userId, :lemma, 'mastered', :lessonId, NULL, 0)
     ON DUPLICATE KEY UPDATE
       status = 'mastered',
       next_review_at = NULL,
       source_lesson_id = COALESCE(source_lesson_id, VALUES(source_lesson_id))`,
    { userId, lemma, lessonId: lessonId || null },
  );
  return getWord(userId, lemma);
}

/** 加入生词本 → 待巩固 + SRS */
async function markVocab(userId, lemmaRaw, { lessonId, gloss } = {}) {
  const lemma = normalizeLemma(lemmaRaw);
  if (!lemma) {
    const err = new Error('无效单词');
    err.status = 400;
    throw err;
  }
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const next = addDays(today, SRS_INTERVALS[0]);

  let glossText = gloss ? String(gloss).trim().slice(0, 256) : '';
  if (!glossText || glossText.toLowerCase() === lemma) {
    glossText =
      (await resolveGlossFromLesson(lessonId, lemma)) ||
      '';
  }

  await pool.query(
    `INSERT INTO user_words
       (user_id, lemma, status, srs_step, next_review_at, source_lesson_id, gloss)
     VALUES
       (:userId, :lemma, 'consolidating', 0, :next, :lessonId, :gloss)
     ON DUPLICATE KEY UPDATE
       status = 'consolidating',
       srs_step = 0,
       next_review_at = :next,
       gloss = COALESCE(VALUES(gloss), gloss),
       source_lesson_id = COALESCE(source_lesson_id, VALUES(source_lesson_id)),
       pass_count = 0`,
    {
      userId,
      lemma,
      next,
      lessonId: lessonId || null,
      gloss: glossText || null,
    },
  );
  return getWord(userId, lemma);
}

async function countBuckets(userId) {
  const [rows] = await pool.query(
    `SELECT status, COUNT(*) AS c FROM user_words
     WHERE user_id = :userId
     GROUP BY status`,
    { userId },
  );
  const byStatus = Object.fromEntries(rows.map((r) => [r.status, Number(r.c)]));
  return {
    learning: (byStatus.learning || 0) + (byStatus.vocab || 0),
    consolidating: byStatus.consolidating || 0,
    mastered: (byStatus.mastered || 0) + (byStatus.known || 0),
  };
}

async function countDue(userId) {
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS c FROM user_words
     WHERE user_id = :userId
       AND status = 'consolidating'
       AND next_review_at IS NOT NULL
       AND next_review_at <= :today`,
    { userId, today },
  );
  return Number(rows[0]?.c || 0);
}

/**
 * 选取可进文章的到期复习词（允许 ±windowDays）。
 * @returns {string[]} lemmas
 */
async function pickDueForLesson(userId, { limit = 4, windowDays = 2 } = {}) {
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const from = addDays(today, -windowDays);
  const to = addDays(today, windowDays);
  const lim = Math.max(1, Math.min(8, Number(limit) || 4));
  const [rows] = await pool.query(
    `SELECT lemma FROM user_words
     WHERE user_id = :userId
       AND status = 'consolidating'
       AND next_review_at IS NOT NULL
       AND next_review_at BETWEEN :from AND :to
     ORDER BY next_review_at ASC, id ASC
     LIMIT ${lim}`,
    { userId, from, to },
  );
  return rows.map((r) => r.lemma).filter(Boolean);
}

/** 批量加入生词本（回填错词等） */
async function markVocabMany(userId, lemmas, { lessonId } = {}) {
  const list = [...new Set((lemmas || []).map(normalizeLemma).filter(Boolean))];
  const out = [];
  for (const lemma of list) {
    out.push(await markVocab(userId, lemma, { lessonId }));
  }
  return out;
}

function formatItem(row, today) {
  const word = mapRow(row);
  if (row.content_json) {
    const fromLesson = defFromDefs(
      parseLessonContent(row.content_json).defs,
      word.lemma,
    );
    if (!word.gloss) word.gloss = fromLesson.gloss;
    word.context = fromLesson.context;
    word.root = fromLesson.root || word.lemma;
  } else if (!word.root) {
    word.root = word.lemma;
  }
  const bucket = bucketOf(word.status);
  const due = dueLabel(word.nextReviewAt, today);
  const parts = [statusLabel(word.status)];
  if (due && bucket === 'consolidating') parts.push(due);
  if (word.sourceTitle) parts.push(`《${word.sourceTitle}》`);
  return {
    ...word,
    bucket,
    accent: dueAccent(word.nextReviewAt, today),
    metaLine: parts.join(' · '),
  };
}

/**
 * 生词本列表 + 今日到期摘要。
 * @param {string} bucket learning|consolidating|mastered
 */
async function listVocab(userId, { bucket = 'consolidating' } = {}) {
  const statuses = BUCKETS[bucket] || BUCKETS.consolidating;
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);

  const placeholders = statuses.map((_, i) => `:s${i}`).join(',');
  const params = { userId };
  statuses.forEach((s, i) => {
    params[`s${i}`] = s;
  });

  const [rows] = await pool.query(
    `SELECT w.*, l.title AS source_title, l.content_json
     FROM user_words w
     LEFT JOIN lessons l ON l.id = w.source_lesson_id
     WHERE w.user_id = :userId AND w.status IN (${placeholders})
     ORDER BY
       CASE
         WHEN w.next_review_at IS NULL THEN 2
         WHEN w.next_review_at <= :today THEN 0
         ELSE 1
       END,
       w.next_review_at ASC,
       w.updated_at DESC
     LIMIT 200`,
    { ...params, today },
  );

  const counts = await countBuckets(userId);
  const dueCount = await countDue(userId);
  const inLessonCount = Math.min(IN_ARTICLE_REVIEW_CAP, dueCount);
  const flashCount = Math.max(0, dueCount - inLessonCount);

  return {
    bucket,
    counts,
    due: {
      dueCount,
      inLessonCount,
      flashCount,
      title:
        dueCount > 0 ? `${dueCount} 个词该见面了` : '今天没有到期词',
      subtitle:
        dueCount > 0
          ? `文章里会先塞 ${inLessonCount} 个，其余走闪卡。`
          : '读文章时点「不认识」可加入生词本。',
      ctaLabel: dueCount > 0 ? '开始复习' : null,
    },
    items: rows.map((r) => formatItem(r, today)),
  };
}

/** 到期闪卡队列（不含已塞进文章配额的展示，MVP 返回全部到期） */
async function listDueReviews(userId) {
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const [rows] = await pool.query(
    `SELECT w.*, l.title AS source_title, l.content_json
     FROM user_words w
     LEFT JOIN lessons l ON l.id = w.source_lesson_id
     WHERE w.user_id = :userId
       AND w.status = 'consolidating'
       AND w.next_review_at IS NOT NULL
       AND w.next_review_at <= :today
     ORDER BY w.next_review_at ASC, w.id ASC
     LIMIT 50`,
    { userId, today },
  );
  return {
    dueCount: rows.length,
    items: rows.map((r) => formatItem(r, today)),
  };
}

/**
 * 闪卡作答：know=true 推进 SRS；false 重置。
 */
async function answerReview(userId, lemmaRaw, { know } = {}) {
  const lemma = normalizeLemma(lemmaRaw);
  if (!lemma) {
    const err = new Error('无效单词');
    err.status = 400;
    throw err;
  }
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const word = await getWord(userId, lemma);
  if (!word || word.status !== 'consolidating') {
    const err = new Error('该词不在待巩固队列');
    err.status = 400;
    throw err;
  }

  if (know) {
    const nextStep = Math.min(word.srsStep + 1, SRS_INTERVALS.length - 1);
    const interval = SRS_INTERVALS[nextStep];
    const next = addDays(today, interval);
    // step 满且 pass 够 → mastered（MVP：step 到顶即掌握）
    if (word.srsStep >= SRS_INTERVALS.length - 1) {
      await pool.query(
        `UPDATE user_words
         SET status = 'mastered', next_review_at = NULL, srs_step = :step, pass_count = pass_count + 1
         WHERE user_id = :userId AND lemma = :lemma`,
        { userId, lemma, step: nextStep },
      );
    } else {
      await pool.query(
        `UPDATE user_words
         SET srs_step = :step, next_review_at = :next, pass_count = pass_count + 1
         WHERE user_id = :userId AND lemma = :lemma`,
        { userId, lemma, step: nextStep, next },
      );
    }
  } else {
    const next = addDays(today, SRS_INTERVALS[0]);
    await pool.query(
      `UPDATE user_words
       SET status = 'consolidating', srs_step = 0, next_review_at = :next, pass_count = 0
       WHERE user_id = :userId AND lemma = :lemma`,
      { userId, lemma, next },
    );
  }
  return getWord(userId, lemma);
}

module.exports = {
  SRS_INTERVALS,
  IN_ARTICLE_REVIEW_CAP,
  normalizeLemma,
  ensureLearning,
  markKnown,
  markVocab,
  markVocabMany,
  listVocab,
  listDueReviews,
  answerReview,
  countDue,
  pickDueForLesson,
  getWord,
};
