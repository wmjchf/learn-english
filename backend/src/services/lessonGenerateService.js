const config = require('../config');
const { chatCompletion, parseJsonContent } = require('./llmClient');
const { tokenizeEnglish, coverageScore, cleanLemma } = require('./lessonTokenize');
const profileService = require('./profileService');
const planService = require('./planService');
const bankService = require('./bankService');
const bankWordService = require('./bankWordService');
const catalogService = require('./catalogService');
const wordDictService = require('./wordDictService');
const wordLifecycleService = require('./wordLifecycleService');

function asArray(v) {
  return Array.isArray(v) ? v : [];
}

function asString(v, fallback = '') {
  return v == null ? fallback : String(v).trim();
}

async function labelsFor(kind, codes) {
  const list = [...new Set((codes || []).map(String))];
  if (!list.length) return [];
  const { items } = await catalogService.listByKind(kind);
  const dict = Object.fromEntries(items.map((r) => [r.code, r.label]));
  return list.map((c) => dict[c] || c);
}

async function resolveLabels(profile) {
  const scenes = await labelsFor('scene', profile.scenes);
  const interests = await labelsFor('interest', profile.interests);
  let jobLabel = profile.jobRaw || '职场人士';
  if (profile.jobCode) {
    const jobs = await labelsFor('job', [profile.jobCode]);
    jobLabel = profile.jobRaw || jobs[0] || profile.jobCode;
  }
  return { scenes, jobLabel, interests };
}

function buildPrompt({
  level,
  jobLabel,
  scenes,
  interests,
  bankTitle,
  targetLemmas,
  reviewLemmas,
  dayIndex,
}) {
  const sceneLine = scenes.length ? scenes.join('、') : '通用职场';
  const interestLine = interests.length ? interests.join('、') : '无';
  const reviewLine =
    reviewLemmas?.length > 0
      ? `\n复习词（自然复现1次即可，勿做成目标词/回填）：${reviewLemmas.join(', ')}`
      : '';
  return `写 Day ${dayIndex} 日课 JSON（紧凑，勿解释）。

画像：${level}；${jobLabel}；场景 ${sceneLine}；兴趣 ${interestLine}；${bankTitle}
目标词须覆盖（每词≤2次）：${targetLemmas.join(', ')}${reviewLine}

字段：
theme(中文标题 4-10 字：必须概括本篇短文的具体事件/话题，内容不同则 theme 必须不同；禁止「今日职场」「商务英语」「职场沟通」等空泛词),
title(英文短标题，同样要具体、贴合本篇内容),
scene:{roleBackground(中文1-2句),tasks[3]},
article:{title(可贴合短文的英文题),zhLead(中文≤40字，点出本篇具体事),enPlain(英文50-70词)},
dialog:{zhLead,turns:[{who,en}] 恰好3轮},
cloze:[{sentence含________,hintZh,answer,before,after}] 恰好8题；answer∈目标词且互不重复

难度贴合 ${level}；职场自然；禁止堆词；先想清本篇具体故事再写 theme/title。`;
}

const GENERIC_THEMES = new Set([
  '今日职场',
  '职场英语',
  '商务英语',
  '职场沟通',
  '商务沟通',
  '今日学习',
  '日常工作',
  '办公室',
  '工作日常',
]);

/** 用中文导读抽一句作标题兜底，避免空泛 theme */
function themeFromLead(zhLead) {
  const lead = asString(zhLead)
    .replace(/[""「」]/g, '')
    .trim();
  if (!lead) return '';
  const cut = lead.split(/[，。！？；、\n]/)[0] || lead;
  return cut.slice(0, 10).trim();
}

function refineTheme(rawTheme, zhLead) {
  let theme = asString(rawTheme).slice(0, 12);
  if (!theme || GENERIC_THEMES.has(theme) || theme.length < 2) {
    const fromLead = themeFromLead(zhLead);
    if (fromLead) theme = fromLead;
  }
  return theme || '今日短文';
}

function normalizeLesson(raw, { targetLemmas, reviewLemmas = [], level, dayIndex }) {
  // 列表展示用 Day N；listLabel 固定，避免模型写成「Day 1 日课」
  const listLabel = `Day ${dayIndex}`;
  const title = asString(raw.title || raw.article?.title, 'Today');
  const scene = {
    title: asString(raw.scene?.title, '① 场景导入'),
    roleBackground: asString(raw.scene?.roleBackground || raw.scene?.role_background),
    tasks: asArray(raw.scene?.tasks).map((t) => asString(t)).filter(Boolean).slice(0, 3),
  };
  if (scene.tasks.length < 2) {
    scene.tasks = ['读懂今日短文', '听懂对话', '完成底部回填'];
  }

  const articlePlain = asString(raw.article?.enPlain || raw.article?.en_plain);
  const zhLead = asString(raw.article?.zhLead || raw.article?.zh_lead);
  const theme = refineTheme(raw.theme, zhLead);
  const article = {
    title: asString(raw.article?.title, title),
    zhLead,
    enPlain: articlePlain,
    enTokens: tokenizeEnglish(articlePlain, targetLemmas, reviewLemmas),
  };

  const turnsRaw = asArray(raw.dialog?.turns);
  const turns = turnsRaw.map((t) => {
    const en = asString(t.en);
    return {
      who: asString(t.who, 'A'),
      en,
      enTokens: tokenizeEnglish(en, targetLemmas, reviewLemmas),
    };
  }).filter((t) => t.en);

  const dialogPlain =
    asString(raw.dialog?.enPlain || raw.dialog?.en_plain) ||
    turns.map((t) => `${t.who}: ${t.en}`).join(' ');

  const dialog = {
    title: asString(raw.dialog?.title, "Let's Talk"),
    zhLead: asString(raw.dialog?.zhLead || raw.dialog?.zh_lead),
    enPlain: dialogPlain,
    turns,
  };

  let cloze = asArray(raw.cloze)
    .slice(0, 8)
    .map((c) => ({
      before: asString(c.before),
      sentence: asString(c.sentence),
      hintZh: asString(c.hintZh || c.hint_zh),
      answer: cleanLemma(asString(c.answer)),
      after: asString(c.after),
    }));
  cloze = padCloze(cloze, targetLemmas);

  // 释义由 bank_words 查库灌入，不依赖模型
  const defs = {};

  return {
    dayIndex,
    theme,
    listLabel,
    title,
    generationLevel: level,
    scene,
    article,
    dialog,
    cloze,
    targetLemmas,
    reviewLemmas: (reviewLemmas || []).map(cleanLemma).filter(Boolean),
    defs,
  };
}

/** 模型少给几题时用目标词补齐，减少整篇重跑 */
function padCloze(cloze, targetLemmas) {
  const out = [...(cloze || [])].filter((c) => c.answer);
  const used = new Set(out.map((c) => cleanLemma(c.answer)));
  for (const raw of targetLemmas || []) {
    if (out.length >= 8) break;
    const a = cleanLemma(raw);
    if (!a || used.has(a)) continue;
    used.add(a);
    out.push({
      before: '',
      sentence: `Please write the word ________ in this sentence.`,
      hintZh: a,
      answer: a,
      after: '',
    });
  }
  return out.slice(0, 8);
}

function validateLesson(lesson) {
  const errors = [];
  if (!lesson.article?.enPlain || lesson.article.enPlain.split(/\s+/).length < 25) {
    errors.push('短文过短');
  }
  if (!lesson.dialog?.turns?.length) errors.push('缺少对话');
  if (!lesson.cloze || lesson.cloze.length < 8) {
    errors.push(`回填不足 8 题（现 ${lesson.cloze?.length || 0}）`);
  }

  const targetSet = new Set(lesson.targetLemmas.map(cleanLemma));
  const clozeAnswers = new Set();
  for (const c of lesson.cloze || []) {
    const a = cleanLemma(c.answer);
    if (!targetSet.has(a)) {
      errors.push(`回填答案不在目标词: ${c.answer}`);
    }
    if (a) {
      if (clozeAnswers.has(a)) errors.push(`回填答案重复: ${a}`);
      clozeAnswers.add(a);
    }
  }

  const corpus = `${lesson.article.enPlain}\n${lesson.dialog.enPlain}`;
  const cov = coverageScore(corpus, lesson.targetLemmas);
  if (cov.ratio < 0.7) {
    errors.push(`目标词覆盖率 ${(cov.ratio * 100).toFixed(0)}% < 70%（缺: ${cov.miss.slice(0, 5).join(', ')}）`);
  }

  return { ok: errors.length === 0, errors, coverage: cov };
}

async function generateOnce(ctx) {
  const prompt = buildPrompt(ctx);
  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content: 'Return one JSON object only.',
      },
      { role: 'user', content: prompt },
    ],
    temperature: 0.35,
    maxTokens: 1600,
    jsonMode: true,
  });

  const raw = parseJsonContent(result.content);
  const lesson = normalizeLesson(raw, {
    targetLemmas: ctx.targetLemmas,
    reviewLemmas: ctx.reviewLemmas || [],
    level: ctx.level,
    dayIndex: ctx.dayIndex,
  });
  const check = validateLesson(lesson);
  return {
    lesson,
    check,
    usage: result.usage,
    model: result.model,
    latencyMs: result.latencyMs,
  };
}

/**
 * 按画像 + 词库生成日课包；失败重试后抛错（由调用方降级种子）。
 */
async function generateLessonForUser(
  userId,
  { dayIndex = 1, lemmaOffset = 0, targetCount = 12 } = {},
) {
  if (!config.llm.apiKey) {
    const err = new Error('未配置 LLM');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }

  const profile = await profileService.ensureProfile(userId);
  const plan = await planService.getActivePlan(userId);
  const bankId = plan?.bankId || profile.primaryBankId;
  const bank = bankId ? await bankService.getBank(bankId) : null;
  const bankCode = bank?.code || 'business';
  const level = profile.generationLevel || profile.abilityLevel || 'B1';
  const reviewLemmas = await wordLifecycleService.pickDueForLesson(userId, {
    limit: wordLifecycleService.IN_ARTICLE_REVIEW_CAP,
  });
  const newCount = Math.max(
    8,
    Math.min(15, Number(targetCount) || 12) - reviewLemmas.length,
  );
  const cursorOrd = (plan?.cursorOrd || 0) + lemmaOffset;
  const picked = await bankWordService.pickTargetLemmas(
    bankCode,
    cursorOrd,
    newCount,
  );
  const targetLemmas = picked.filter(
    (l) => !reviewLemmas.includes(cleanLemma(l)),
  );

  const { scenes, jobLabel, interests } = await resolveLabels(profile);

  const ctx = {
    level,
    jobLabel,
    scenes,
    interests,
    bankTitle: bank?.title || '商务英语',
    targetLemmas,
    reviewLemmas,
    dayIndex,
  };

  const retryMax = Math.max(1, config.generate.retryMax || 1);
  let lastErrors = [];
  for (let attempt = 1; attempt <= retryMax; attempt++) {
    try {
      const { lesson, check, usage, model, latencyMs } = await generateOnce(ctx);
      if (check.ok) {
        await wordDictService.attachDefsToLesson(lesson);
        console.log(
          `[lesson] ok day=${dayIndex} attempt=${attempt} llm=${latencyMs || '?'}ms model=${model}`,
        );
        return {
          lesson,
          bankId: bank?.id || null,
          level,
          meta: {
            model,
            usage,
            attempt,
            latencyMs,
            coverage: check.coverage.ratio,
            targetLemmas,
          },
        };
      }
      lastErrors = check.errors;
      console.warn(`[lesson] validate fail attempt=${attempt}:`, check.errors);
      ctx._lastErrors = check.errors;
    } catch (err) {
      lastErrors = [err.message];
      // 超时 / 网关错误不再重试，避免连等数分钟
      if (err.code === 'LLM_TIMEOUT' || err.code === 'LLM_ERROR') throw err;
      if (attempt === retryMax) throw err;
    }
  }

  const err = new Error(`日课生成未通过校验: ${lastErrors.join('; ')}`);
  err.status = 502;
  err.code = 'LESSON_VALIDATE_FAILED';
  throw err;
}

module.exports = {
  generateLessonForUser,
  validateLesson,
  normalizeLesson,
};
