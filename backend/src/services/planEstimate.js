const MINUTE_OPTIONS = [10, 15, 20, 30, 45, 60];
const DEFAULT_MINUTES = 20;
/** 基准：约 8 分钟写进一篇约 12 个目标词 */
const WORDS_PER_LESSON = 12;
const MINUTES_PER_LESSON = 8;
/** 单篇目标词区间（按每日时间缩放后夹紧；上限兼顾成文质量） */
const MIN_TARGETS_PER_LESSON = 8;
const MAX_TARGETS_PER_LESSON = 30;

/** 按能力水平粗估「已知词」占比（无词库命中抽样前的 MVP） */
const KNOWN_RATIO = {
  A1: 0.08,
  A2: 0.12,
  B1: 0.15,
  B2: 0.25,
  C1: 0.4,
  C2: 0.55,
};

function bankTotal(bank) {
  const n = Number(bank?.targetSize || bank?.target_size || bank?.wordCount || 0);
  return Math.max(1, n);
}

function estimateKnown(abilityLevel, total) {
  const ratio = KNOWN_RATIO[String(abilityLevel || 'B1').toUpperCase()] ?? 0.15;
  return Math.min(total - 1, Math.max(0, Math.round(total * ratio)));
}

function dailyWordsFromMinutes(minutes) {
  return (Number(minutes) / MINUTES_PER_LESSON) * WORDS_PER_LESSON;
}

/**
 * 按每日投入分钟算「一篇日课」目标词数；与成文选词同口径。
 * raw = minutes/8*12，再夹到 8–20。
 */
function targetCountFromMinutes(minutes) {
  const m = Math.max(1, Number(minutes) || DEFAULT_MINUTES);
  const raw = Math.round(dailyWordsFromMinutes(m));
  return Math.max(
    MIN_TARGETS_PER_LESSON,
    Math.min(MAX_TARGETS_PER_LESSON, raw),
  );
}

function daysFromMinutes(remaining, minutes) {
  const daily = targetCountFromMinutes(minutes);
  if (daily <= 0) return 1;
  return Math.max(1, Math.ceil(remaining / daily));
}

function minutesFromDays(remaining, days) {
  const d = Math.max(1, Number(days) || 1);
  const needPerDay = Math.max(1, remaining / d);
  return Math.max(
    1,
    Math.ceil((needPerDay / WORDS_PER_LESSON) * MINUTES_PER_LESSON),
  );
}

function warningForMinutes(minutes) {
  const m = Number(minutes);
  if (m > 45) return 'aggressive';
  if (m < 5) return 'too_short';
  return null;
}

/**
 * @param {{ remaining: number, minutes?: number, days?: number }} input
 * 优先用 minutes 算 days；若只给 days 则反算 minutes。
 */
function computeEstimate({ remaining, minutes, days }) {
  const rem = Math.max(1, Number(remaining) || 1);
  let outMinutes;
  let outDays;
  let source;

  if (minutes != null && minutes !== '' && !Number.isNaN(Number(minutes))) {
    outMinutes = Math.max(1, Math.round(Number(minutes)));
    outDays = daysFromMinutes(rem, outMinutes);
    source = 'minutes';
  } else if (days != null && days !== '' && !Number.isNaN(Number(days))) {
    outDays = Math.max(1, Math.round(Number(days)));
    outMinutes = minutesFromDays(rem, outDays);
    source = 'days';
  } else {
    outMinutes = DEFAULT_MINUTES;
    outDays = daysFromMinutes(rem, outMinutes);
    source = 'default';
  }

  const wordsPerLesson = targetCountFromMinutes(outMinutes);
  return {
    minutes: outMinutes,
    days: outDays,
    dailyWords: wordsPerLesson,
    wordsPerLesson,
    warning: warningForMinutes(outMinutes),
    source,
  };
}

module.exports = {
  MINUTE_OPTIONS,
  DEFAULT_MINUTES,
  WORDS_PER_LESSON,
  MINUTES_PER_LESSON,
  MIN_TARGETS_PER_LESSON,
  MAX_TARGETS_PER_LESSON,
  bankTotal,
  estimateKnown,
  dailyWordsFromMinutes,
  targetCountFromMinutes,
  computeEstimate,
  warningForMinutes,
};
