const { pool } = require('../db');
const profileService = require('./profileService');

const LEVELS = profileService.LEVELS;
const MIN_QUESTIONS = 8;
const MAX_QUESTIONS = 12;
const UNKNOWN_OPTION_ID = 'unknown';

const VOCAB_ESTIMATE = {
  A1: 600,
  A2: 1200,
  B1: 2500,
  B2: 4500,
  C1: 8000,
  C2: 12000,
};

function normalizeLevel(level) {
  const raw = String(level || '').toUpperCase();
  return LEVELS.includes(raw) ? raw : 'B1';
}

function levelIndex(level) {
  return LEVELS.indexOf(normalizeLevel(level));
}

function shiftLevel(level, delta) {
  const idx = Math.min(
    LEVELS.length - 1,
    Math.max(0, levelIndex(level) + delta),
  );
  return LEVELS[idx];
}

function parseJson(value, fallback) {
  if (value == null) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function publicQuestion(item) {
  const options = parseJson(item.options_json, []);
  const labels = Array.isArray(options) ? options.map(String) : [];
  return {
    id: item.id,
    word: item.lemma,
    phonetic: item.phonetic || undefined,
    prompt: item.prompt || '这个词更接近哪个意思？',
    options: [
      ...labels.map((label, index) => ({
        id: String(index),
        label,
      })),
      { id: UNKNOWN_OPTION_ID, label: '不认识' },
    ],
  };
}

function progressPayload(askedCount) {
  return {
    current: askedCount + 1,
    total: MAX_QUESTIONS,
  };
}

async function listSetCodes() {
  const [rows] = await pool.query(
    `SELECT DISTINCT set_code AS setCode
     FROM assess_items
     WHERE enabled = 1
     ORDER BY set_code ASC`,
  );
  const codes = rows.map((r) => r.setCode).filter(Boolean);
  return codes.length ? codes : ['set_a'];
}

async function pickRandomSetCode() {
  const codes = await listSetCodes();
  return codes[Math.floor(Math.random() * codes.length)];
}

/**
 * 优先在会话绑定的套内抽；该套同档用尽 → 同档其他套 → 邻近档（仍优先本套）。
 */
async function pickItem(level, excludeIds, setCode) {
  const excluded = [...new Set((excludeIds || []).map(Number).filter(Boolean))];
  const params = { level, setCode: setCode || 'set_a' };
  let excludeSql = '';
  if (excluded.length) {
    excludeSql = `AND id NOT IN (${excluded.map((_, i) => `:ex${i}`).join(',')})`;
    excluded.forEach((id, i) => {
      params[`ex${i}`] = id;
    });
  }

  async function queryOne({ level: lv, preferSet }) {
    const q = {
      ...params,
      level: lv,
    };
    const setSql = preferSet
      ? 'AND set_code = :setCode'
      : 'AND set_code <> :setCode';
    const [rows] = await pool.query(
      `SELECT id, lemma, phonetic, prompt, options_json, correct_index, cefr_level, set_code
       FROM assess_items
       WHERE enabled = 1 AND cefr_level = :level ${setSql} ${excludeSql}
       ORDER BY RAND()
       LIMIT 1`,
      q,
    );
    return rows[0] || null;
  }

  // 1) 本套本档
  let item = await queryOne({ level, preferSet: true });
  if (item) return item;
  // 2) 其他套本档
  item = await queryOne({ level, preferSet: false });
  if (item) return item;

  // 3) 邻近档：先本套再外套
  const idx = levelIndex(level);
  for (const delta of [1, -1, 2, -2, 3, -3]) {
    const alt = LEVELS[idx + delta];
    if (!alt) continue;
    item = await queryOne({ level: alt, preferSet: true });
    if (item) return item;
    item = await queryOne({ level: alt, preferSet: false });
    if (item) return item;
  }

  const err = new Error('题库不足，请稍后重试');
  err.status = 503;
  throw err;
}

async function loadSession(sessionId, userId) {
  const [rows] = await pool.query(
    `SELECT * FROM assess_sessions
     WHERE id = :sessionId AND user_id = :userId
     LIMIT 1`,
    { sessionId, userId },
  );
  if (!rows.length) {
    const err = new Error('测评会话不存在');
    err.status = 404;
    throw err;
  }
  const row = rows[0];
  return {
    ...row,
    set_code: row.set_code || 'set_a',
    trail: parseJson(row.trail_json, []),
    askedItemIds: parseJson(row.asked_item_ids, []),
  };
}

async function saveSession(session) {
  await pool.query(
    `UPDATE assess_sessions
     SET current_level = :currentLevel,
         set_code = :setCode,
         status = :status,
         trail_json = CAST(:trail AS JSON),
         asked_item_ids = CAST(:asked AS JSON),
         result_level = :resultLevel,
         estimated_vocab = :estimatedVocab,
         finished_at = :finishedAt
     WHERE id = :id`,
    {
      id: session.id,
      currentLevel: session.current_level,
      setCode: session.set_code || 'set_a',
      status: session.status,
      trail: JSON.stringify(session.trail || []),
      asked: JSON.stringify(session.askedItemIds || []),
      resultLevel: session.result_level,
      estimatedVocab: session.estimated_vocab,
      finishedAt: session.finished_at,
    },
  );
}

function shouldFinish(trail) {
  if (trail.length >= MAX_QUESTIONS) return true;
  if (trail.length < MIN_QUESTIONS) return false;
  const last3 = trail.slice(-3);
  if (last3.length < 3) return false;
  const sameLevel = last3.every((a) => a.level === last3[0].level);
  if (!sameLevel) return false;
  const correctCount = last3.filter((a) => a.correct).length;
  const rate = correctCount / 3;
  return rate > 0.8 || rate < 0.2;
}

function estimateResultLevel(trail, currentLevel) {
  if (!trail.length) return normalizeLevel(currentLevel);
  const last3 = trail.slice(-3);
  if (last3.length === 3 && last3.every((a) => a.level === last3[0].level)) {
    const rate = last3.filter((a) => a.correct).length / 3;
    if (rate > 0.8) return last3[0].level;
    if (rate < 0.2) return shiftLevel(last3[0].level, -1);
  }
  // 加权：更看重后半段
  const weights = trail.map((_, i) => (i + 1) / trail.length);
  let score = 0;
  let wsum = 0;
  trail.forEach((a, i) => {
    const base = levelIndex(a.level) + (a.correct ? 0.35 : -0.35);
    score += base * weights[i];
    wsum += weights[i];
  });
  const avg = score / wsum;
  const idx = Math.min(LEVELS.length - 1, Math.max(0, Math.round(avg)));
  return LEVELS[idx];
}

async function finishSession(session, { abandoned = false } = {}) {
  const resultLevel = estimateResultLevel(session.trail, session.current_level);
  const estimatedVocab = VOCAB_ESTIMATE[resultLevel] || VOCAB_ESTIMATE.B1;
  session.status = abandoned ? 'abandoned' : 'finished';
  session.result_level = resultLevel;
  session.estimated_vocab = estimatedVocab;
  session.finished_at = new Date();
  await saveSession(session);

  const existing = await profileService.getProfile(session.user_id);
  const advanceToBank = existing?.onboardingStep !== 'done';
  const profile = await profileService.applyAssessResult(
    session.user_id,
    resultLevel,
    { advanceToBank },
  );

  return {
    finished: true,
    result: {
      level: resultLevel,
      estimatedVocab,
    },
    profile,
  };
}

async function startSession(userId, startLevelRaw) {
  const startLevel = normalizeLevel(startLevelRaw);
  // 放弃同用户未完成会话
  await pool.query(
    `UPDATE assess_sessions
     SET status = 'abandoned', finished_at = CURRENT_TIMESTAMP(3)
     WHERE user_id = :userId AND status = 'active'`,
    { userId },
  );

  const setCode = await pickRandomSetCode();
  const item = await pickItem(startLevel, [], setCode);
  const [result] = await pool.query(
    `INSERT INTO assess_sessions
      (user_id, start_level, current_level, set_code, status, trail_json, asked_item_ids)
     VALUES
      (:userId, :startLevel, :currentLevel, :setCode, 'active', CAST('[]' AS JSON), CAST(:asked AS JSON))`,
    {
      userId,
      startLevel,
      currentLevel: item.cefr_level,
      setCode,
      asked: JSON.stringify([item.id]),
    },
  );

  return {
    finished: false,
    sessionId: result.insertId,
    question: publicQuestion(item),
    progress: progressPayload(0),
  };
}

async function answerSession(userId, sessionId, optionIdRaw) {
  const session = await loadSession(sessionId, userId);
  if (session.status !== 'active') {
    const err = new Error('测评已结束');
    err.status = 400;
    throw err;
  }

  const asked = session.askedItemIds || [];
  const currentItemId = asked[asked.length - 1];
  if (!currentItemId) {
    const err = new Error('当前无题目');
    err.status = 400;
    throw err;
  }

  const [items] = await pool.query(
    `SELECT id, lemma, phonetic, prompt, options_json, correct_index, cefr_level
     FROM assess_items WHERE id = :id LIMIT 1`,
    { id: currentItemId },
  );
  const item = items[0];
  if (!item) {
    const err = new Error('题目不存在');
    err.status = 400;
    throw err;
  }

  const optionId = String(optionIdRaw || '').trim();
  let correct = false;
  if (optionId !== UNKNOWN_OPTION_ID && optionId !== '') {
    const chosen = Number(optionId);
    correct = Number.isInteger(chosen) && chosen === Number(item.correct_index);
  }

  const trail = [...(session.trail || [])];
  trail.push({
    itemId: item.id,
    level: item.cefr_level,
    correct,
    optionId,
  });

  const nextLevel = correct
    ? shiftLevel(item.cefr_level, 1)
    : shiftLevel(item.cefr_level, -1);

  session.trail = trail;
  session.current_level = nextLevel;
  session.askedItemIds = asked;

  if (shouldFinish(trail)) {
    return finishSession(session);
  }

  const nextItem = await pickItem(nextLevel, asked, session.set_code);
  session.askedItemIds = [...asked, nextItem.id];
  session.current_level = nextItem.cefr_level;
  await saveSession(session);

  return {
    finished: false,
    sessionId: session.id,
    question: publicQuestion(nextItem),
    progress: progressPayload(trail.length),
  };
}

async function forceFinish(userId, sessionId) {
  const session = await loadSession(sessionId, userId);
  if (session.status !== 'active') {
    return {
      finished: true,
      result: {
        level: session.result_level || session.current_level,
        estimatedVocab:
          session.estimated_vocab ||
          VOCAB_ESTIMATE[session.result_level] ||
          VOCAB_ESTIMATE.B1,
      },
      profile: await profileService.getProfile(userId),
    };
  }
  return finishSession(session, { abandoned: true });
}

module.exports = {
  LEVELS,
  MIN_QUESTIONS,
  MAX_QUESTIONS,
  UNKNOWN_OPTION_ID,
  startSession,
  answerSession,
  forceFinish,
};
