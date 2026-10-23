const { pool } = require('../db');
const profileService = require('./profileService');

const FREEZE_PER_MONTH = 2;

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

function shiftDate(iso, days) {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function monthKey(iso) {
  return String(iso).slice(0, 7);
}

function localHour(timezone) {
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone || 'Asia/Shanghai',
      hour: '2-digit',
      hour12: false,
    }).formatToParts(new Date());
    const h = parts.find((p) => p.type === 'hour')?.value;
    return Number(h);
  } catch {
    return new Date().getHours();
  }
}

async function ensureStreak(userId) {
  await pool.query(
    `INSERT IGNORE INTO user_streaks (user_id) VALUES (:userId)`,
    { userId },
  );
  const [rows] = await pool.query(
    `SELECT * FROM user_streaks WHERE user_id = :userId LIMIT 1`,
    { userId },
  );
  return rows[0];
}

function resetFreezeIfNeeded(row, today) {
  const mk = monthKey(today);
  if (row.freeze_month !== mk) {
    return { freezeUsed: 0, freezeMonth: mk };
  }
  return {
    freezeUsed: Number(row.freeze_used_month || 0),
    freezeMonth: mk,
  };
}

/**
 * 记录打卡（lesson / review）。同日已打卡则幂等返回。
 */
async function recordCheckin(userId, source = 'lesson') {
  if (!['lesson', 'review'].includes(source)) {
    source = 'lesson';
  }
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const yesterday = shiftDate(today, -1);

  const [existing] = await pool.query(
    `SELECT id, source FROM user_checkins
     WHERE user_id = :userId AND local_date = :today LIMIT 1`,
    { userId, today },
  );
  if (existing.length) {
    const streak = await getStreak(userId);
    return {
      already: true,
      streakDelta: 0,
      checkin: { localDate: today, source: existing[0].source },
      streak,
    };
  }

  await pool.query(
    `INSERT INTO user_checkins (user_id, local_date, source)
     VALUES (:userId, :today, :source)`,
    { userId, today, source },
  );

  const row = await ensureStreak(userId);
  const { freezeUsed, freezeMonth } = resetFreezeIfNeeded(row, today);
  let current = Number(row.current_streak || 0);
  const last = row.last_checkin_date
    ? row.last_checkin_date instanceof Date
      ? row.last_checkin_date.toISOString().slice(0, 10)
      : String(row.last_checkin_date).slice(0, 10)
    : null;

  if (last === yesterday || last === today) {
    current = last === today ? current : current + 1;
  } else if (!last) {
    current = 1;
  } else {
    current = 1;
  }
  if (current < 1) current = 1;

  const longest = Math.max(Number(row.longest_streak || 0), current);

  await pool.query(
    `UPDATE user_streaks SET
       current_streak = :current,
       longest_streak = :longest,
       freeze_used_month = :freezeUsed,
       freeze_month = :freezeMonth,
       last_checkin_date = :today
     WHERE user_id = :userId`,
    { userId, current, longest, freezeUsed, freezeMonth, today },
  );

  const streak = await getStreak(userId);
  return {
    already: false,
    streakDelta: 1,
    checkin: { localDate: today, source },
    streak,
  };
}

async function getStreak(userId) {
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const row = await ensureStreak(userId);
  const { freezeUsed, freezeMonth } = resetFreezeIfNeeded(row, today);
  if (row.freeze_month !== freezeMonth) {
    await pool.query(
      `UPDATE user_streaks
       SET freeze_used_month = 0, freeze_month = :freezeMonth
       WHERE user_id = :userId`,
      { userId, freezeMonth },
    );
  }

  const last = row.last_checkin_date
    ? row.last_checkin_date instanceof Date
      ? row.last_checkin_date.toISOString().slice(0, 10)
      : String(row.last_checkin_date).slice(0, 10)
    : null;
  const yesterday = shiftDate(today, -1);
  let current = Number(row.current_streak || 0);
  // 若昨日也未打卡且今天未打，当前连胜对外视为 0（冻结尚未跑）
  if (last && last !== today && last !== yesterday) {
    current = 0;
  }

  const [checked] = await pool.query(
    `SELECT 1 FROM user_checkins
     WHERE user_id = :userId AND local_date = :today LIMIT 1`,
    { userId, today },
  );

  return {
    currentStreak: current,
    longestStreak: Number(row.longest_streak || 0),
    freezeUsedMonth: freezeUsed,
    freezeRemaining: Math.max(0, FREEZE_PER_MONTH - freezeUsed),
    checkedInToday: checked.length > 0,
    lastCheckinDate: last,
  };
}

/**
 * 对单个用户做「昨日未打卡」结算（本地 23:00 后跑）。
 */
async function settleMissedDay(userId, missedDate) {
  const [already] = await pool.query(
    `SELECT 1 FROM user_checkins
     WHERE user_id = :userId AND local_date = :missedDate LIMIT 1`,
    { userId, missedDate },
  );
  if (already.length) return { action: 'ok' };

  const [logged] = await pool.query(
    `SELECT 1 FROM streak_freeze_logs
     WHERE user_id = :userId AND local_date = :missedDate LIMIT 1`,
    { userId, missedDate },
  );
  if (logged.length) return { action: 'already' };

  const row = await ensureStreak(userId);
  const { freezeUsed, freezeMonth } = resetFreezeIfNeeded(row, missedDate);
  const current = Number(row.current_streak || 0);
  if (current <= 0) {
    await pool.query(
      `INSERT IGNORE INTO streak_freeze_logs (user_id, local_date, action)
       VALUES (:userId, :missedDate, 'break')`,
      { userId, missedDate },
    );
    return { action: 'noop' };
  }

  if (freezeUsed < FREEZE_PER_MONTH) {
    await pool.query(
      `INSERT INTO user_checkins (user_id, local_date, source)
       VALUES (:userId, :missedDate, 'freeze')
       ON DUPLICATE KEY UPDATE source = source`,
      { userId, missedDate },
    );
    await pool.query(
      `UPDATE user_streaks SET
         freeze_used_month = :used,
         freeze_month = :freezeMonth,
         last_checkin_date = GREATEST(COALESCE(last_checkin_date, :missedDate), :missedDate)
       WHERE user_id = :userId`,
      { userId, used: freezeUsed + 1, freezeMonth, missedDate },
    );
    await pool.query(
      `INSERT INTO streak_freeze_logs (user_id, local_date, action)
       VALUES (:userId, :missedDate, 'freeze')`,
      { userId, missedDate },
    );
    return { action: 'freeze' };
  }

  await pool.query(
    `UPDATE user_streaks SET current_streak = 0 WHERE user_id = :userId`,
    { userId },
  );
  await pool.query(
    `INSERT INTO streak_freeze_logs (user_id, local_date, action)
     VALUES (:userId, :missedDate, 'break')`,
    { userId, missedDate },
  );
  return { action: 'break' };
}

/**
 * 扫描：本地小时 ≥ 23 的用户，结算「今天」若未打卡则记为待冻结日；
 * 更稳妥：结算「昨天」——在新一天开始后结算前一日。
 */
async function runFreezeJob() {
  const [users] = await pool.query(
    `SELECT u.id AS user_id, p.timezone
     FROM users u
     LEFT JOIN user_profiles p ON p.user_id = u.id`,
  );
  let freeze = 0;
  let brk = 0;
  for (const u of users) {
    const tz = u.timezone || 'Asia/Shanghai';
    const hour = localHour(tz);
    if (hour < 0) continue;
    // 每天 0–1 点窗口结算「昨天」
    if (hour > 1) continue;
    const today = todayLocalDate(tz);
    const missed = shiftDate(today, -1);
    try {
      const r = await settleMissedDay(u.user_id, missed);
      if (r.action === 'freeze') freeze += 1;
      if (r.action === 'break') brk += 1;
    } catch (err) {
      console.warn('[streak] settle failed', u.user_id, err.message);
    }
  }
  return { scanned: users.length, freeze, break: brk };
}

module.exports = {
  FREEZE_PER_MONTH,
  recordCheckin,
  getStreak,
  settleMissedDay,
  runFreezeJob,
  todayLocalDate,
};
