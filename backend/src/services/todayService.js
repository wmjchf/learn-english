const lessonService = require('./lessonService');
const planService = require('./planService');
const profileService = require('./profileService');
const bankService = require('./bankService');
const wordLifecycleService = require('./wordLifecycleService');
const streakService = require('./streakService');
const { bankTotal, estimateKnown, computeEstimate } = require('./planEstimate');

function paceLabel(warning) {
  if (warning === 'aggressive') return '节奏偏紧';
  if (warning === 'too_short') return '节奏偏松';
  return '节奏正常';
}

/**
 * 今日任务页聚合：日课卡、复习占位、连胜占位、计划进度。
 */
async function getToday(userId) {
  const profile = await profileService.ensureProfile(userId);
  const lesson = await lessonService.getTodayLesson(userId);

  const plan = await planService.getActivePlan(userId);
  const bankId = plan?.bankId || profile.primaryBankId;
  let bank = null;
  if (bankId) {
    try {
      bank = await bankService.getBank(bankId);
    } catch {
      bank = null;
    }
  }

  const totalDays = plan?.targetDays || profile.targetDays || 1;
  const dayIndex = Math.min(
    Math.max(1, lesson.dayIndex || 1),
    Math.max(1, totalDays),
  );
  const dayLabel = `Day ${dayIndex}`;

  let pace = '节奏正常';
  if (bank) {
    const total = bankTotal(bank);
    const known = estimateKnown(profile.abilityLevel, total);
    const remaining = Math.max(1, total - known);
    const minutes = plan?.dailyMinutes || profile.dailyMinutes || 20;
    const est = computeEstimate({ remaining, minutes });
    pace = paceLabel(est.warning);
  }

  const content = lesson.content || {};
  const targetCount = Array.isArray(content.targetLemmas)
    ? content.targetLemmas.length
    : 0;

  const lessonDone = lesson.status === 'done';
  const dueCount = await wordLifecycleService.countDue(userId);
  const inLessonReview = Math.min(
    wordLifecycleService.IN_ARTICLE_REVIEW_CAP,
    dueCount,
  );
  const streak = await streakService.getStreak(userId);
  const reviewDone = dueCount === 0;
  const tasksDone = (lessonDone ? 1 : 0) + (reviewDone ? 1 : 0);

  return {
    streakDays: streak.currentStreak,
    streak,
    tasksDone,
    tasksTotal: 2,
    lesson: {
      id: lesson.id,
      theme: lesson.theme,
      title: lesson.title,
      status: lesson.status,
      source: lesson.source || 'seed',
      dayIndex,
      listLabel: dayLabel,
      sceneHint: dayLabel,
      targetWordCount: targetCount,
      estMinutes: Math.max(5, Math.round((targetCount || 12) * 0.7)),
      ctaLabel: lessonDone ? '再读一遍' : '开始阅读',
    },
    review: {
      dueCount,
      inLessonCount: inLessonReview,
      subtitle:
        dueCount > 0
          ? `文内复现 ${inLessonReview} 个，其余闪卡`
          : '读文章时点「不认识」会排到这里',
    },
    plan: {
      dayIndex,
      totalDays,
      bankTitle: bank?.title || '词库',
      paceLabel: pace,
      dayLine: `Day ${dayIndex} / ${totalDays}`,
      metaLine: `${bank?.title || '词库'} · ${pace}`,
    },
  };
}

module.exports = { getToday };
