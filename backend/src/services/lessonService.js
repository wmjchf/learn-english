const { pool } = require('../db');
const config = require('../config');
const profileService = require('./profileService');
const seedDay1 = require('../data/seedLessonDay1');
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

async function createFromSeed(userId, bankId, dayIndex = 1) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  return insertLesson(userId, {
    bankId,
    dayIndex,
    localDate,
    pack: seedDay1,
    source: 'seed',
    level: seedDay1.generationLevel || profile.generationLevel || 'B1',
  });
}

async function createFromAi(userId, { dayIndex = 1 } = {}) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const generated = await lessonGenerateService.generateLessonForUser(userId, {
    dayIndex,
  });
  return insertLesson(userId, {
    bankId: generated.bankId,
    dayIndex,
    localDate,
    pack: generated.lesson,
    source: 'personalized',
    level: generated.level,
  });
}

async function createFromPool(userId, dayIndex = 1) {
  const lessonPoolService = require('./lessonPoolService');
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const matched = await lessonPoolService.matchForUser(userId);
  if (!matched) return null;
  return insertLesson(userId, {
    bankId: matched.bankId || profile.primaryBankId,
    dayIndex,
    localDate,
    pack: matched.pack,
    source: 'pool',
    level: matched.level,
  });
}

/**
 * 优先公共池秒出 → AI → 种子。
 */
async function createTodayLesson(userId, dayIndex = 1) {
  const profile = await profileService.ensureProfile(userId);
  // Day1 / 无 LLM：优先池
  if (dayIndex === 1 || !config.llm.apiKey) {
    try {
      const fromPool = await createFromPool(userId, dayIndex);
      if (fromPool) return fromPool;
    } catch (err) {
      console.warn('[lesson] pool match failed:', err.message);
    }
  }
  if (!config.llm.apiKey) {
    return createFromSeed(userId, profile.primaryBankId, dayIndex);
  }
  try {
    return await createFromAi(userId, { dayIndex });
  } catch (err) {
    console.warn('[lesson] AI generate failed, fallback pool/seed:', err.message);
    try {
      const fromPool = await createFromPool(userId, dayIndex);
      if (fromPool) return fromPool;
    } catch (_) {
      /* ignore */
    }
    return createFromSeed(userId, profile.primaryBankId, dayIndex);
  }
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

/** 下一篇 Day 序号：历史最大 day_index + 1 */
async function nextDayIndex(userId) {
  await repairCollapsedDayIndexes(userId);
  const [rows] = await pool.query(
    `SELECT COALESCE(MAX(day_index), 0) AS m
     FROM lessons WHERE user_id = :userId`,
    { userId },
  );
  return Number(rows[0]?.m || 0) + 1;
}

/**
 * 历史 bug：多篇都写成 day_index=1 时，按创建时间重排为 Day 1..N。
 */
async function repairCollapsedDayIndexes(userId) {
  const [rows] = await pool.query(
    `SELECT id, day_index FROM lessons
     WHERE user_id = :userId
     ORDER BY COALESCE(local_date, DATE(created_at)) ASC, id ASC`,
    { userId },
  );
  if (rows.length <= 1) return;
  const allOne = rows.every((r) => Number(r.day_index) === 1);
  if (!allOne) return;
  for (let i = 0; i < rows.length; i++) {
    const day = i + 1;
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
      { day, label, id: rows[i].id },
    );
  }
}

/**
 * 今日日课：已有则返回；否则按下一 Day 生成。
 */
async function getTodayLesson(userId) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  await repairCollapsedDayIndexes(userId);

  const [rows] = await pool.query(
    `SELECT * FROM lessons
     WHERE user_id = :userId AND local_date = :localDate
     ORDER BY id DESC LIMIT 1`,
    { userId, localDate },
  );
  if (rows.length) return parseContent(rows[0]);

  const dayIndex = await nextDayIndex(userId);
  return createTodayLesson(userId, dayIndex);
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
    return getById(rows[0].id, userId);
  }

  return insertLesson(userId, {
    bankId: generated.bankId,
    dayIndex,
    localDate,
    pack: generated.lesson,
    source: 'personalized',
    level: generated.level,
  });
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

  // 推进词库指针（仅首次完课）
  if (!wasDone && targets.length) {
    await pool.query(
      `UPDATE user_plans
       SET cursor_ord = cursor_ord + :n
       WHERE user_id = :userId`,
      { userId, n: targets.length },
    );
  }

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
  await repairCollapsedDayIndexes(userId);
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
    const dayIndex = await nextDayIndex(userId);
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
  getTodayLesson,
  getById,
  nextDayIndex,
  createFromSeed,
  createFromAi,
  createTodayLesson,
  regenerateToday,
  markReading,
  markDone,
  listLessons,
  manualGenerate,
};
