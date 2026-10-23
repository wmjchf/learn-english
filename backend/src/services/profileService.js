const { pool } = require('../db');
const catalogService = require('./catalogService');

const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const ONBOARDING_STEPS = [
  'interest',
  'scene',
  'job',
  'assess',
  'bank',
  'plan',
  'done',
];

function parseJsonArray(value) {
  if (value == null) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function mapProfile(row) {
  if (!row) return null;
  return {
    abilityLevel: row.ability_level,
    generationLevel: row.generation_level,
    jobCode: row.job_code,
    jobRaw: row.job_raw,
    scenes: parseJsonArray(row.scenes),
    interests: parseJsonArray(row.interests),
    dailyMinutes: row.daily_minutes,
    targetDays: row.target_days,
    primaryBankId: row.primary_bank_id,
    onboardingStep: row.onboarding_step,
    timezone: row.timezone,
  };
}

async function ensureProfile(userId) {
  await pool.query(
    `INSERT IGNORE INTO user_profiles (user_id, onboarding_step)
     VALUES (:userId, 'interest')`,
    { userId },
  );
  return getProfile(userId);
}

async function getProfile(userId) {
  const [rows] = await pool.query(
    `SELECT * FROM user_profiles WHERE user_id = :userId LIMIT 1`,
    { userId },
  );
  if (!rows.length) return ensureProfile(userId);
  return mapProfile(rows[0]);
}

async function assertCodes(kind, codes, { allowDisabled = false } = {}) {
  const list = [...new Set((codes || []).map((c) => String(c).trim()).filter(Boolean))];
  const max = catalogService.MAX_SELECT[kind];
  if (list.length < 1) {
    const err = new Error(`${kind} 至少选 1 个`);
    err.status = 400;
    err.code = 'CATALOG_REQUIRED';
    throw err;
  }
  if (list.length > max) {
    const err = new Error(`${kind} 最多选 ${max} 个`);
    err.status = 400;
    err.code = 'CATALOG_TOO_MANY';
    throw err;
  }
  for (const code of list) {
    const ok = allowDisabled
      ? await catalogService.wasEverCode(kind, code)
      : await catalogService.isEnabledCode(kind, code);
    if (!ok) {
      const err = new Error(`无效选项: ${code}`);
      err.status = 400;
      err.code = 'CATALOG_INVALID';
      throw err;
    }
  }
  return list;
}

async function patchProfile(userId, patch = {}) {
  await ensureProfile(userId);
  const fields = [];
  const params = { userId };

  if (patch.interests !== undefined) {
    const interests = await assertCodes('interest', patch.interests);
    fields.push('interests = CAST(:interests AS JSON)');
    params.interests = JSON.stringify(interests);
  }
  if (patch.scenes !== undefined) {
    const scenes = await assertCodes('scene', patch.scenes);
    fields.push('scenes = CAST(:scenes AS JSON)');
    params.scenes = JSON.stringify(scenes);
  }
  if (patch.jobCode !== undefined) {
    const [jobCode] = await assertCodes('job', [patch.jobCode]);
    fields.push('job_code = :jobCode');
    params.jobCode = jobCode;
    if (patch.jobRaw !== undefined) {
      fields.push('job_raw = :jobRaw');
      params.jobRaw = patch.jobRaw ? String(patch.jobRaw).slice(0, 128) : null;
    }
  } else if (patch.jobRaw !== undefined) {
    fields.push('job_raw = :jobRaw');
    params.jobRaw = patch.jobRaw ? String(patch.jobRaw).slice(0, 128) : null;
  }
  if (patch.dailyMinutes !== undefined) {
    fields.push('daily_minutes = :dailyMinutes');
    params.dailyMinutes = Number(patch.dailyMinutes);
  }
  if (patch.targetDays !== undefined) {
    fields.push('target_days = :targetDays');
    params.targetDays = Number(patch.targetDays);
  }
  if (patch.primaryBankId !== undefined) {
    fields.push('primary_bank_id = :primaryBankId');
    params.primaryBankId = patch.primaryBankId;
  }
  if (patch.timezone !== undefined) {
    fields.push('timezone = :timezone');
    params.timezone = patch.timezone ? String(patch.timezone).slice(0, 64) : null;
  }
  if (patch.onboardingStep !== undefined) {
    if (!ONBOARDING_STEPS.includes(patch.onboardingStep)) {
      const err = new Error('无效 onboarding_step');
      err.status = 400;
      throw err;
    }
    fields.push('onboarding_step = :onboardingStep');
    params.onboardingStep = patch.onboardingStep;
  }

  if (!fields.length) return getProfile(userId);

  await pool.query(
    `UPDATE user_profiles SET ${fields.join(', ')} WHERE user_id = :userId`,
    params,
  );
  return getProfile(userId);
}

async function bumpGenerationLevel(userId, delta) {
  if (delta !== 1 && delta !== -1) {
    const err = new Error('delta 只能是 +1 或 -1');
    err.status = 400;
    throw err;
  }
  const profile = await ensureProfile(userId);
  const current = profile.generationLevel || profile.abilityLevel;
  if (!current) {
    const err = new Error('尚未定级，无法调节文章难度');
    err.status = 400;
    err.code = 'LEVEL_MISSING';
    throw err;
  }
  const idx = LEVELS.indexOf(current);
  const next = LEVELS[idx + delta];
  if (!next) {
    const err = new Error('已到边界档位');
    err.status = 400;
    err.code = 'LEVEL_BOUNDARY';
    throw err;
  }
  await pool.query(
    `UPDATE user_profiles SET generation_level = :next WHERE user_id = :userId`,
    { userId, next },
  );
  return getProfile(userId);
}

/**
 * 测评结算写水平：始终更新 ability_level；
 * generation_level 仅在首次（仍为空）时一并写入。
 */
async function applyAssessResult(userId, level, { advanceToBank = true } = {}) {
  if (!LEVELS.includes(level)) {
    const err = new Error('无效测评等级');
    err.status = 400;
    throw err;
  }
  await ensureProfile(userId);
  const profile = await getProfile(userId);
  const fields = ['ability_level = :level'];
  const params = { userId, level };
  if (!profile.generationLevel) {
    fields.push('generation_level = :level');
  }
  if (advanceToBank) {
    fields.push("onboarding_step = 'bank'");
  }
  await pool.query(
    `UPDATE user_profiles SET ${fields.join(', ')} WHERE user_id = :userId`,
    params,
  );
  return getProfile(userId);
}

async function completeOnboarding(userId) {
  const profile = await ensureProfile(userId);
  if (!profile.interests?.length) {
    const err = new Error('请先选择兴趣');
    err.status = 400;
    throw err;
  }
  if (!profile.scenes?.length) {
    const err = new Error('请先选择场景');
    err.status = 400;
    throw err;
  }
  if (!profile.jobCode) {
    const err = new Error('请先选择职业');
    err.status = 400;
    throw err;
  }
  if (!profile.abilityLevel || !profile.generationLevel) {
    const err = new Error('请先完成测评');
    err.status = 400;
    throw err;
  }
  if (!profile.dailyMinutes || !profile.targetDays) {
    const err = new Error('请先确认每日时间与计划天数');
    err.status = 400;
    throw err;
  }
  await pool.query(
    `UPDATE user_profiles SET onboarding_step = 'done' WHERE user_id = :userId`,
    { userId },
  );
  return getProfile(userId);
}

module.exports = {
  LEVELS,
  ONBOARDING_STEPS,
  ensureProfile,
  getProfile,
  patchProfile,
  bumpGenerationLevel,
  applyAssessResult,
  completeOnboarding,
};
