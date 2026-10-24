const { pool } = require('../db');
const profileService = require('./profileService');
const bankService = require('./bankService');
const authService = require('./authService');

const VOCAB_ESTIMATE = {
  A1: 600,
  A2: 1200,
  B1: 2500,
  B2: 4500,
  C1: 8000,
  C2: 12000,
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

function shiftDate(iso, days) {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function formatVocab(n) {
  const s = String(Math.max(0, Number(n) || 0));
  return s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

async function latestEstimatedVocab(userId, abilityLevel) {
  const [rows] = await pool.query(
    `SELECT estimated_vocab, result_level FROM assess_sessions
     WHERE user_id = :userId AND status = 'finished' AND estimated_vocab IS NOT NULL
     ORDER BY id DESC LIMIT 1`,
    { userId },
  );
  if (rows[0]?.estimated_vocab) return Number(rows[0].estimated_vocab);
  return VOCAB_ESTIMATE[abilityLevel] || VOCAB_ESTIMATE.B1;
}

async function computeStreak(userId) {
  const streakService = require('./streakService');
  const streak = await streakService.getStreak(userId);
  return {
    current: streak.currentStreak,
    longest: streak.longestStreak,
    footnote:
      streak.currentStreak > 0 ? '今日完成可保连胜' : '完成日课可打卡',
    freezeRemaining: streak.freezeRemaining,
  };
}

async function weekVocabDelta(userId) {
  const profile = await profileService.ensureProfile(userId);
  const today = todayLocalDate(profile.timezone);
  const weekAgo = shiftDate(today, -6);
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS c FROM lessons
     WHERE user_id = :userId AND status = 'done'
       AND local_date BETWEEN :from AND :to`,
    { userId, from: weekAgo, to: today },
  );
  const lessons = Number(rows[0]?.c || 0);
  return lessons * 12; // 粗估：每篇约 12 目标词
}

async function getMeSummary(userId, phone) {
  const profile = await profileService.ensureProfile(userId);
  let bankTitle = '未选词库';
  if (profile.primaryBankId) {
    const bank = await bankService.getBank(profile.primaryBankId);
    if (bank) bankTitle = bank.title;
  }

  const ability = profile.abilityLevel || '—';
  const generation = profile.generationLevel || ability;
  const estimatedVocab = await latestEstimatedVocab(
    userId,
    profile.abilityLevel || 'B1',
  );
  const weekDelta = await weekVocabDelta(userId);
  const streak = await computeStreak(userId);

  let userPhone = phone || '';
  let nickname = '';
  try {
    const user = phone
      ? await authService.findUserByPhone(phone)
      : null;
    if (user) {
      userPhone = user.phone;
      nickname = user.nickname || '';
    }
  } catch {
    /* ignore */
  }

  return {
    user: {
      phone: userPhone,
      nickname,
    },
    profile,
    hero: {
      title: `${generation} · ${bankTitle}`,
      abilityLine: `能力水平 ${ability} · 文章难度基准 ${generation}`,
      note: '改动只影响之后的文章。',
      bankTitle,
      abilityLevel: ability,
      generationLevel: generation,
    },
    stats: {
      vocab: estimatedVocab,
      vocabLabel: formatVocab(estimatedVocab),
      weekDelta,
      weekDeltaLabel: weekDelta > 0 ? `本周 +${weekDelta}` : '本周暂无增长',
      streakDays: streak.current,
      streakLabel: `${streak.current} 天`,
      streakFootnote: streak.footnote,
      longestStreak: streak.longest,
    },
  };
}

module.exports = { getMeSummary, VOCAB_ESTIMATE };
