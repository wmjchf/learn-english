const { pool } = require('../db');
const config = require('../config');
const profileService = require('./profileService');
const lessonGenerateService = require('./lessonGenerateService');
const generateQuotaService = require('./generateQuotaService');

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

function parseContent(row) {
  let content = row.content_json;
  if (typeof content === 'string') {
    try {
      content = JSON.parse(content);
    } catch {
      content = {};
    }
  }
  return {
    id: row.id,
    userId: row.user_id,
    bankId: row.bank_id,
    dayIndex: row.day_index,
    localDate: row.local_date,
    theme: row.theme,
    listLabel: row.list_label,
    title: row.title,
    source: row.source,
    status: row.status,
    generationLevel: row.generation_level,
    content,
  };
}

async function insertLesson(userId, {
  bankId,
  dayIndex,
  localDate,
  pack,
  source,
  level,
}) {
  const day = Math.max(1, Number(dayIndex) || 1);
  const listLabel = `Day ${day}`;
  const content = {
    ...pack,
    dayIndex: day,
    listLabel,
  };
  const [result] = await pool.query(
    `INSERT INTO lessons
      (user_id, bank_id, day_index, local_date, theme, list_label, title,
       content_json, source, status, generation_level)
     VALUES
      (:userId, :bankId, :dayIndex, :localDate, :theme, :listLabel, :title,
       CAST(:content AS JSON), :source, 'unread', :level)`,
    {
      userId,
      bankId: bankId || null,
      dayIndex: day,
      localDate,
      theme: content.theme,
      listLabel,
      title: content.title,
      content: JSON.stringify(content),
      source,
      level: level || content.generationLevel || 'B1',
    },
  );
  return getById(result.insertId, userId);
}

async function createFromAi(userId, { dayIndex = 1 } = {}) {
  if (!config.llm.apiKey) {
    const err = new Error('未配置 DASHSCOPE_API_KEY，无法生成日课');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const generated = await lessonGenerateService.generateLessonForUser(userId, {
    dayIndex,
  });
  const lesson = await insertLesson(userId, {
    bankId: generated.bankId,
    dayIndex,
    localDate,
    pack: generated.lesson,
    source: 'personalized',
    level: generated.level,
  });
  // 成文即推进词窗（勿等完课）：否则未读完的多天会抽到同一批词
  await advanceCursor(userId, generated.lesson?.targetLemmas);
  return lesson;
}

async function advanceCursor(userId, targetLemmas) {
  const n = Array.isArray(targetLemmas) ? targetLemmas.length : 0;
  if (!n) return;
  await pool.query(
    `UPDATE user_plans
     SET cursor_ord = cursor_ord + :n
     WHERE user_id = :userId`,
    { userId, n },
  );
}

/** 只走 AI 按画像生成；无 key / 失败直接抛错。 */
async function createTodayLesson(userId, dayIndex = 1) {
  return createFromAi(userId, { dayIndex });
}

async function getById(lessonId, userId) {
  const [rows] = await pool.query(
    `SELECT * FROM lessons
     WHERE id = :id AND (user_id = :userId OR user_id IS NULL)
     LIMIT 1`,
    { id: lessonId, userId },
  );
  if (!rows.length) {
    const err = new Error('日课不存在');
    err.status = 404;
    throw err;
  }
  return parseContent(rows[0]);
}

function localDateKey(value) {
  if (value == null) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return String(value).slice(0, 10);
}

async function applyDayIndex(id, day) {
  const label = `Day ${day}`;
  await pool.query(
    `UPDATE lessons
     SET day_index = :day,
         list_label = :label,
         content_json = JSON_SET(
           COALESCE(content_json, JSON_OBJECT()),
           '$.dayIndex', :day,
           '$.listLabel', :label
         )
     WHERE id = :id`,
    { day, label, id },
  );
}

/**
 * Day 序号 = 学习日序号（按 local_date），不是「第几篇生成文章」。
 * - 该日已有日课 → 复用当天的 day_index（换一篇 / 手动再生成仍是同一天）
 * - 新的一天 → 历史最大 day_index + 1
 */
async function resolveDayIndex(userId, localDate) {
  await repairDayIndexes(userId);
  const [sameDay] = await pool.query(
    `SELECT day_index FROM lessons
     WHERE user_id = :userId AND local_date = :localDate
     ORDER BY id ASC LIMIT 1`,
    { userId, localDate },
  );
  if (sameDay.length) {
    return Math.max(1, Number(sameDay[0].day_index) || 1);
  }
  const [rows] = await pool.query(
    `SELECT COALESCE(MAX(day_index), 0) AS m
     FROM lessons WHERE user_id = :userId`,
    { userId },
  );
  return Number(rows[0]?.m || 0) + 1;
}

/** @deprecated 用 resolveDayIndex；保留别名避免外部误用 */
async function nextDayIndex(userId) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  return resolveDayIndex(userId, localDate);
}

/**
 * 修正 day_index：
 * 1) 同一 local_date 的多篇文章必须同一 Day（手动生成/换一篇不算新一天）
 * 2) 仅当「跨多天却全是 Day 1」时，按日期序重排（修历史塌缩）；同日多篇全是 1 不拆开
 */
async function repairDayIndexes(userId) {
  const [rows] = await pool.query(
    `SELECT id, day_index, local_date, created_at FROM lessons
     WHERE user_id = :userId
     ORDER BY COALESCE(local_date, DATE(created_at)) ASC, id ASC`,
    { userId },
  );
  if (rows.length <= 1) return;

  // —— 同日对齐：取该日最小 day_index 作为正本 ——
  const byDate = new Map();
  for (const r of rows) {
    const key = localDateKey(r.local_date) || localDateKey(r.created_at);
    if (!byDate.has(key)) byDate.set(key, []);
    byDate.get(key).push(r);
  }
  for (const group of byDate.values()) {
    if (group.length <= 1) continue;
    const day = Math.max(
      1,
      Math.min(...group.map((r) => Number(r.day_index) || 1)),
    );
    for (const r of group) {
      if (Number(r.day_index) !== day) {
        await applyDayIndex(r.id, day);
        r.day_index = day;
      }
    }
  }

  // —— 跨日全是 1：按日期序赋 Day 1..N（每天内共用同一序号） ——
  const dateKeys = [...byDate.keys()].filter(Boolean).sort();
  if (dateKeys.length <= 1) return;
  const stillAllOne = rows.every((r) => Number(r.day_index) === 1);
  if (!stillAllOne) return;

  for (let i = 0; i < dateKeys.length; i++) {
    const day = i + 1;
    for (const r of byDate.get(dateKeys[i]) || []) {
      if (Number(r.day_index) !== day) {
        await applyDayIndex(r.id, day);
      }
    }
  }
}

/** @deprecated 兼容旧名 */
async function repairCollapsedDayIndexes(userId) {
  return repairDayIndexes(userId);
}

/** 仅查今日已有日课，不触发生成（避免 /api/today 被 LLM 拖死）。 */
async function findTodayLesson(userId) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  await repairDayIndexes(userId);

  const [rows] = await pool.query(
    `SELECT * FROM lessons
     WHERE user_id = :userId AND local_date = :localDate
     ORDER BY id DESC LIMIT 1`,
    { userId, localDate },
  );
  if (!rows.length) return null;
  return parseContent(rows[0]);
}

/** 同用户并发进「今日生成」时复用同一 Promise，避免重复打 LLM。 */
const _todayGenerateInflight = new Map();

/**
 * 今日日课：已有则返回；否则按下一 Day 生成。
 */
async function getTodayLesson(userId) {
  const existing = await findTodayLesson(userId);
  if (existing) return existing;

  if (_todayGenerateInflight.has(userId)) {
    return _todayGenerateInflight.get(userId);
  }

  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const dayIndex = await resolveDayIndex(userId, localDate);
  const task = createTodayLesson(userId, dayIndex).finally(() => {
    _todayGenerateInflight.delete(userId);
  });
  _todayGenerateInflight.set(userId, task);
  return task;
}

/**
 * 用 AI 重写今日未读日课（替换种子或旧篇）。
 * 已 done 的不覆盖。
 */
async function regenerateToday(userId) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);

  const [rows] = await pool.query(
    `SELECT * FROM lessons
     WHERE user_id = :userId AND local_date = :localDate
     ORDER BY id DESC LIMIT 1`,
    { userId, localDate },
  );

  if (rows.length && rows[0].status === 'done') {
    const err = new Error('今日日课已完成，不能重生成');
    err.status = 400;
    err.code = 'LESSON_DONE';
    throw err;
  }

  if (!config.llm.apiKey) {
    const err = new Error('未配置 DASHSCOPE_API_KEY，无法生成');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }

  const dayIndex = rows[0]?.day_index || 1;
  // 换一篇时错开词窗，避免总抽到同一批词
  const lemmaOffset = Math.floor(Math.random() * 24);
  const generated = await lessonGenerateService.generateLessonForUser(userId, {
    dayIndex,
    lemmaOffset,
    exceptLessonId: rows[0]?.id || null,
  });

  if (rows.length) {
    await pool.query(
      `UPDATE lessons SET
         bank_id = :bankId,
         theme = :theme,
         list_label = :listLabel,
         title = :title,
         content_json = CAST(:content AS JSON),
         source = 'personalized',
         status = 'unread',
         generation_level = :level
       WHERE id = :id AND user_id = :userId`,
      {
        id: rows[0].id,
        userId,
        bankId: generated.bankId,
        theme: generated.lesson.theme,
        listLabel: generated.lesson.listLabel,
        title: generated.lesson.title,
        content: JSON.stringify(generated.lesson),
        level: generated.level,
      },
    );
    // 换一篇：不重复推进 cursor（词窗已在首成时推进）
    return getById(rows[0].id, userId);
  }

  const lesson = await insertLesson(userId, {
    bankId: generated.bankId,
    dayIndex,
    localDate,
    pack: generated.lesson,
    source: 'personalized',
    level: generated.level,
  });
  await advanceCursor(userId, generated.lesson?.targetLemmas);
  return lesson;
}

async function markReading(lessonId, userId) {
  await pool.query(
    `UPDATE lessons SET status = 'reading'
     WHERE id = :id AND user_id = :userId AND status = 'unread'`,
    { id: lessonId, userId },
  );
  const lesson = await getById(lessonId, userId);
  const targets = Array.isArray(lesson?.content?.targetLemmas)
    ? lesson.content.targetLemmas
    : [];
  if (targets.length) {
    const wordLifecycleService = require('./wordLifecycleService');
    await wordLifecycleService.ensureLearning(userId, targets, {
      lessonId,
      bankId: lesson.bankId,
    });
  }
  return lesson;
}

/**
 * 完课：标记 done、推进计划 cursor、错词入生词本、打卡。
 * @param {{ wrongLemmas?: string[] }} [opts]
 */
async function markDone(lessonId, userId, opts = {}) {
  const lesson = await getById(lessonId, userId);
  const wasDone = lesson.status === 'done';

  await pool.query(
    `UPDATE lessons SET status = 'done'
     WHERE id = :id AND user_id = :userId`,
    { id: lessonId, userId },
  );

  const targets = Array.isArray(lesson.content?.targetLemmas)
    ? lesson.content.targetLemmas
    : [];
  const wrongLemmas = Array.isArray(opts.wrongLemmas) ? opts.wrongLemmas : [];

  const wordLifecycleService = require('./wordLifecycleService');
  if (wrongLemmas.length) {
    await wordLifecycleService.markVocabMany(userId, wrongLemmas, {
      lessonId,
    });
  }

  // 词库指针在成文时已推进，完课不再重复 +n

  const streakService = require('./streakService');
  const checkin = wasDone
    ? { already: true, streakDelta: 0, streak: await streakService.getStreak(userId) }
    : await streakService.recordCheckin(userId, 'lesson');

  const next = await getById(lessonId, userId);
  return { lesson: next, checkin };
}

function toCard(row, today, knownCountOverride) {
  const lesson = parseContent(row);
  const targets = Array.isArray(lesson.content?.targetLemmas)
    ? lesson.content.targetLemmas
    : [];
  const targetWordCount = targets.length;
  const knownCount =
    knownCountOverride != null
      ? Math.min(targetWordCount, Number(knownCountOverride) || 0)
      : lesson.status === 'done'
        ? targetWordCount
        : 0;
  const dateIso =
    lesson.localDate instanceof Date
      ? lesson.localDate.toISOString().slice(0, 10)
      : lesson.localDate
        ? String(lesson.localDate).slice(0, 10)
        : null;
  const isToday = dateIso === today;
  const unread = lesson.status !== 'done';
  let statusLabel = '已读';
  if (unread && isToday) statusLabel = '未读 · 今日可继续';
  else if (unread) statusLabel = '未读';

  const dayLabel = `Day ${lesson.dayIndex || 1}`;

  return {
    id: lesson.id,
    theme: lesson.theme,
    title: lesson.title,
    status: lesson.status,
    source: lesson.source,
    dayIndex: lesson.dayIndex,
    localDate: dateIso,
    isToday,
    statusLabel,
    targetWordCount,
    knownCount,
    sceneTag: dayLabel,
    metaLine: `目标词 ${knownCount} / ${targetWordCount} · ${dayLabel}`,
  };
}

/** 统计每篇目标词中已掌握（mastered/known）的数量 */
async function knownCountsByLesson(userId, rows) {
  const map = {};
  if (!rows.length) return map;

  const lemmaSet = new Set();
  const lessonTargets = new Map();
  for (const row of rows) {
    const lesson = parseContent(row);
    const targets = (lesson.content?.targetLemmas || [])
      .map((t) => String(t || '').toLowerCase().replace(/[^a-z'-]/g, ''))
      .filter(Boolean);
    lessonTargets.set(lesson.id, targets);
    targets.forEach((t) => lemmaSet.add(t));
    map[lesson.id] = 0;
  }

  if (!lemmaSet.size) return map;

  const lemmas = [...lemmaSet];
  const params = { userId };
  lemmas.forEach((l, i) => {
    params[`l${i}`] = l;
  });
  const [knownRows] = await pool.query(
    `SELECT lemma FROM user_words
     WHERE user_id = :userId
       AND status IN ('mastered', 'known')
       AND lemma IN (${lemmas.map((_, i) => `:l${i}`).join(',')})`,
    params,
  );
  const known = new Set(knownRows.map((r) => String(r.lemma).toLowerCase()));

  for (const [id, targets] of lessonTargets) {
    map[id] = targets.filter((t) => known.has(t)).length;
  }
  return map;
}

/**
 * 文章库列表。status: all | unread | done
 */
async function listLessons(userId, { status = 'all' } = {}) {
  await repairDayIndexes(userId);
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);

  let sql = `SELECT * FROM lessons WHERE user_id = :userId`;
  const params = { userId };
  if (status === 'unread') {
    sql += ` AND status IN ('unread','reading')`;
  } else if (status === 'done') {
    sql += ` AND status = 'done'`;
  }
  sql += ` ORDER BY id DESC LIMIT 100`;

  const [rows] = await pool.query(sql, params);
  const knownMap = await knownCountsByLesson(userId, rows);
  return {
    items: rows.map((r) => toCard(r, today, knownMap[r.id])),
    quota: await generateQuotaService.getQuota(userId),
  };
}

/**
 * 手动生成新文章：扣免费额度 → AI 生成 → 设为今日篇。
 */
async function manualGenerate(userId) {
  if (!config.llm.apiKey) {
    const err = new Error('未配置 DASHSCOPE_API_KEY，无法生成');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }

  const quotaAfter = await generateQuotaService.consumeFree(userId);
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const lemmaOffset = Math.floor(Math.random() * 40);

  try {
    // 与「今日」同一天共用 Day N，避免手动生成变成 Day N+1
    const dayIndex = await resolveDayIndex(userId, localDate);
    const generated = await lessonGenerateService.generateLessonForUser(
      userId,
      { dayIndex, lemmaOffset },
    );
    const lesson = await insertLesson(userId, {
      bankId: generated.bankId,
      dayIndex,
      localDate,
      pack: generated.lesson,
      source: 'personalized',
      level: generated.level,
    });
    await advanceCursor(userId, generated.lesson?.targetLemmas);
    return { lesson, quota: quotaAfter };
  } catch (err) {
    // 生成失败退还额度
    await pool.query(
      `UPDATE generate_quota
       SET manual_free_used = GREATEST(manual_free_used - 1, 0)
       WHERE user_id = :userId AND local_date = :localDate`,
      { userId, localDate },
    );
    throw err;
  }
}

module.exports = {
  findTodayLesson,
  getTodayLesson,
  getById,
  nextDayIndex,
  resolveDayIndex,
  createFromAi,
  createTodayLesson,
  regenerateToday,
  markReading,
  markDone,
  listLessons,
  manualGenerate,
};
