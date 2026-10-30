const { pool } = require('../db');
const bankService = require('./bankService');
const profileService = require('./profileService');
const {
  MINUTE_OPTIONS,
  DEFAULT_MINUTES,
  bankTotal,
  estimateKnown,
  computeEstimate,
} = require('./planEstimate');

function mapPlan(row) {
  if (!row) return null;
  return {
    id: row.id,
    bankId: row.bank_id,
    cursorOrd: row.cursor_ord,
    status: row.status,
    dailyMinutes: row.daily_minutes,
    targetDays: row.target_days,
  };
}

async function getActivePlan(userId) {
  const [rows] = await pool.query(
    `SELECT id, bank_id, cursor_ord, status, daily_minutes, target_days
     FROM user_plans WHERE user_id = :userId LIMIT 1`,
    { userId },
  );
  return mapPlan(rows[0]);
}

async function resolveBankForUser(userId) {
  const profile = await profileService.ensureProfile(userId);
  const plan = await getActivePlan(userId);
  const bankId = plan?.bankId || profile.primaryBankId;
  if (!bankId) {
    const err = new Error('请先选择词库');
    err.status = 400;
    err.code = 'BANK_REQUIRED';
    throw err;
  }
  const bank = await bankService.getBank(bankId);
  if (!bank) {
    const err = new Error('词库不存在或已下架');
    err.status = 404;
    err.code = 'BANK_NOT_FOUND';
    throw err;
  }
  return { profile, plan, bank };
}

async function sceneLabels(codes, sceneRaw) {
  const list = [...new Set((codes || []).map(String))];
  if (!list.length) return [];
  const params = {};
  list.forEach((c, i) => {
    params[`c${i}`] = c;
  });
  const [rows] = await pool.query(
    `SELECT code, label FROM option_catalog
     WHERE kind = 'scene' AND code IN (${list.map((_, i) => `:c${i}`).join(',')})`,
    params,
  );
  const map = Object.fromEntries(rows.map((r) => [r.code, r.label]));
  const raw = sceneRaw ? String(sceneRaw).trim() : '';
  return list.map((c) => {
    if (c === 'other' && raw) return raw;
    return map[c] || c;
  });
}

/**
 * 选定主词库：写 user_plans + profile.primary_bank_id，推进 onboarding_step=plan。
 */
async function selectBank(userId, bankIdRaw) {
  const bankId = Number(bankIdRaw);
  if (!bankId) {
    const err = new Error('请选择词库');
    err.status = 400;
    throw err;
  }
  const bank = await bankService.getBank(bankId);
  if (!bank) {
    const err = new Error('词库不存在或已下架');
    err.status = 404;
    err.code = 'BANK_NOT_FOUND';
    throw err;
  }

  const existing = await profileService.ensureProfile(userId);

  await pool.query(
    `INSERT INTO user_plans (user_id, bank_id, cursor_ord, status)
     VALUES (:userId, :bankId, 0, 'active')
     ON DUPLICATE KEY UPDATE
       bank_id = VALUES(bank_id),
       cursor_ord = 0,
       status = 'active'`,
    { userId, bankId },
  );

  const patch = { primaryBankId: bankId };
  // 已完成引导的用户换库不回退到 plan 步
  if (existing.onboardingStep !== 'done') {
    patch.onboardingStep = 'plan';
  }
  const profile = await profileService.patchProfile(userId, patch);

  return {
    bank,
    plan: await getActivePlan(userId),
    profile,
  };
}

/**
 * 画像内切换主词库：保留 onboarding_step=done，重算预估天数；cursor 归零（已学进度按词保留）。
 */
async function switchPrimaryBank(userId, bankIdRaw) {
  const bankId = Number(bankIdRaw);
  if (!bankId) {
    const err = new Error('请选择词库');
    err.status = 400;
    throw err;
  }
  const bank = await bankService.getBank(bankId);
  if (!bank) {
    const err = new Error('词库不存在或已下架');
    err.status = 404;
    err.code = 'BANK_NOT_FOUND';
    throw err;
  }

  const existing = await profileService.ensureProfile(userId);
  if (existing.primaryBankId === bankId) {
    return {
      bank,
      plan: await getActivePlan(userId),
      profile: existing,
      estimate: existing.dailyMinutes
        ? (await estimatePlan(userId, { minutes: existing.dailyMinutes })).estimate
        : null,
    };
  }

  await pool.query(
    `INSERT INTO user_plans (user_id, bank_id, cursor_ord, status)
     VALUES (:userId, :bankId, 0, 'active')
     ON DUPLICATE KEY UPDATE
       bank_id = VALUES(bank_id),
       cursor_ord = 0,
       status = 'active'`,
    { userId, bankId },
  );

  let profile = await profileService.patchProfile(userId, {
    primaryBankId: bankId,
  });

  let estimate = null;
  const minutes = profile.dailyMinutes || DEFAULT_MINUTES;
  const preview = await estimatePlan(userId, { minutes });
  estimate = preview.estimate;
  await pool.query(
    `UPDATE user_plans
     SET daily_minutes = :minutes, target_days = :days, status = 'active'
     WHERE user_id = :userId`,
    { userId, minutes: estimate.minutes, days: estimate.days },
  );
  profile = await profileService.patchProfile(userId, {
    dailyMinutes: estimate.minutes,
    targetDays: estimate.days,
  });

  return {
    bank,
    plan: await getActivePlan(userId),
    profile,
    estimate,
  };
}

async function getPlanContext(userId) {
  const { profile, plan, bank } = await resolveBankForUser(userId);
  const total = bankTotal(bank);
  const knownEstimate = estimateKnown(profile.abilityLevel, total);
  const remaining = Math.max(1, total - knownEstimate);
  const minutes =
    plan?.dailyMinutes || profile.dailyMinutes || DEFAULT_MINUTES;
  const estimate = computeEstimate({ remaining, minutes });
  const scenes = await sceneLabels(profile.scenes, profile.sceneRaw);

  return {
    bank,
    knownEstimate,
    remaining,
    minuteOptions: MINUTE_OPTIONS,
    defaultMinutes: DEFAULT_MINUTES,
    estimate,
    profile,
    plan,
    sceneLabels: scenes,
  };
}

async function estimatePlan(userId, { minutes, days } = {}) {
  const { profile, bank } = await resolveBankForUser(userId);
  const total = bankTotal(bank);
  const knownEstimate = estimateKnown(profile.abilityLevel, total);
  const remaining = Math.max(1, total - knownEstimate);
  const estimate = computeEstimate({ remaining, minutes, days });
  return {
    bank,
    knownEstimate,
    remaining,
    estimate,
  };
}

/**
 * 确认每日时间与计划天数 → 写画像/计划，onboarding_step=done。
 */
async function confirmPlan(userId, { minutes, days } = {}) {
  const preview = await estimatePlan(userId, { minutes, days });
  const { estimate, bank } = preview;

  await pool.query(
    `UPDATE user_plans
     SET daily_minutes = :minutes, target_days = :days, status = 'active'
     WHERE user_id = :userId`,
    { userId, minutes: estimate.minutes, days: estimate.days },
  );

  const profile = await profileService.patchProfile(userId, {
    dailyMinutes: estimate.minutes,
    targetDays: estimate.days,
    onboardingStep: 'done',
  });

  const scenes = await sceneLabels(profile.scenes, profile.sceneRaw);

  return {
    bank,
    knownEstimate: preview.knownEstimate,
    remaining: preview.remaining,
    estimate,
    profile,
    plan: await getActivePlan(userId),
    sceneLabels: scenes,
    ready: {
      title: `你的 ${estimate.days} 天计划已就绪`,
      subtitle: `每天 ${estimate.minutes} 分钟，把${bank.title}一点点变成自己的。`,
      bankLine: `${bank.title} · 约 ${bank.targetSize} 词`,
      days: estimate.days,
      minutes: estimate.minutes,
      level: profile.generationLevel || profile.abilityLevel || 'B1',
      dayProgress: `今天是 Day 1 / ${estimate.days}`,
      scenesLine: scenes.length
        ? `场景已锁定：${scenes.join(' · ')}`
        : null,
    },
  };
}

module.exports = {
  selectBank,
  switchPrimaryBank,
  getPlanContext,
  estimatePlan,
  confirmPlan,
  getActivePlan,
};
