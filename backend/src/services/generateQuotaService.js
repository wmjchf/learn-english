const { pool } = require('../db');
const config = require('../config');
const profileService = require('./profileService');

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

async function getQuota(userId) {
  const profile = await profileService.ensureProfile(userId);
  const localDate = todayLocalDate(profile.timezone);
  const dailyFree = Math.max(1, config.generate.dailyQuota || 1);

  const [rows] = await pool.query(
    `SELECT manual_free_used FROM generate_quota
     WHERE user_id = :userId AND local_date = :localDate
     LIMIT 1`,
    { userId, localDate },
  );
  const used = rows[0]?.manual_free_used || 0;
  const remaining = Math.max(0, dailyFree - used);
  return {
    localDate,
    dailyFree,
    used,
    remaining,
    canGenerateFree: remaining > 0,
    hint:
      remaining > 0
        ? `今天还可免费生成 ${remaining} 次，之后需付费。`
        : '今日免费次数已用完，付费生成即将开放。',
  };
}

async function consumeFree(userId) {
  const quota = await getQuota(userId);
  if (!quota.canGenerateFree) {
    const err = new Error(quota.hint);
    err.status = 402;
    err.code = 'QUOTA_EXCEEDED';
    throw err;
  }
  await pool.query(
    `INSERT INTO generate_quota (user_id, local_date, manual_free_used)
     VALUES (:userId, :localDate, 1)
     ON DUPLICATE KEY UPDATE
       manual_free_used = manual_free_used + 1`,
    { userId, localDate: quota.localDate },
  );
  return getQuota(userId);
}

module.exports = { getQuota, consumeFree, todayLocalDate };
