const MINUTE_OPTIONS = [10, 15, 20, 30, 45, 60];
const DEFAULT_MINUTES = 20;
const WORDS_PER_LESSON = 12;
const MINUTES_PER_LESSON = 8;

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

function daysFromMinutes(remaining, minutes) {
  const daily = dailyWordsFromMinutes(minutes);
  if (daily <= 0) return 1;
  return Math.max(1, Math.ceil(remaining / daily));
}

function minutesFromDays(remaining, days) {
  const d = Math.max(1, Number(days) || 1);
  return Math.max(1, Math.ceil((remaining / d / WORDS_PER_LESSON) * MINUTES_PER_LESSON));
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

  const dailyWords = Math.round(dailyWordsFromMinutes(outMinutes));
  return {
    minutes: outMinutes,
    days: outDays,
    dailyWords,
    wordsPerLesson: WORDS_PER_LESSON,
    warning: warningForMinutes(outMinutes),
    source,
  };
}

module.exports = {
  MINUTE_OPTIONS,
  DEFAULT_MINUTES,
  WORDS_PER_LESSON,
  MINUTES_PER_LESSON,
  bankTotal,
  estimateKnown,
  computeEstimate,
  warningForMinutes,
};
