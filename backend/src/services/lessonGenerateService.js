const config = require('../config');
const { chatCompletion, parseJsonContent } = require('./llmClient');
const {
  tokenizeEnglish,
  coverageScore,
  cleanLemma,
  stripMarkdownEmphasis,
} = require('./lessonTokenize');
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
  let scenes = await labelsFor('scene', profile.scenes);
  // 场景「自填」用用户原文替换目录里的「自填」标签
  if (profile.sceneRaw && profile.scenes?.includes('other')) {
    scenes = scenes.map((s) => (s === '自填' ? profile.sceneRaw : s));
    if (!scenes.includes(profile.sceneRaw)) {
      scenes = [...scenes.filter((s) => s !== 'other'), profile.sceneRaw];
    }
  }
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
  repairHint,
  avoidThemes = [],
}) {
  const sceneLine = scenes.length ? scenes.join('、') : '通用职场';
  const interestLine = interests.length ? interests.join('、') : '无';
  const reviewLine =
    reviewLemmas?.length > 0
      ? `\n复习词（自然复现1次即可，勿做成目标词/回填）：${reviewLemmas.join(', ')}`
      : '';
  const repairLine = repairHint ? `\n上次未通过：${repairHint}。请修正。` : '';
  const avoidLine =
    avoidThemes?.length > 0
      ? `\n禁止复用这些已有主题（事件/情节也要换新）：${avoidThemes.join('、')}`
      : '';
  const targets = (targetLemmas || []).join(', ');
  return `写 Day ${dayIndex} 日课 JSON（紧凑，勿解释）。不要生成对话/dialog/turns。

画像：${level}；${jobLabel}；场景 ${sceneLine}；兴趣 ${interestLine}；${bankTitle}
目标词（必须全部出现在短文 enPlain 中，每词1-2次，勿堆砌列表）：${targets}${reviewLine}${avoidLine}${repairLine}

硬性要求：
- 仅短文须覆盖全部目标词（覆盖率≥70%，尽量100%）
- 先列好要用到的目标词再写故事，再写 theme/title
- theme 与故事必须是新事件，不得与近期日课雷同
- 主题/场景导读/短文必须明显贴合职业「${jobLabel}」与场景「${sceneLine}」（兴趣可作点缀：${interestLine}）；禁止写成与当前画像无关的通用职场鸡汤
- 中译必须忠实：zhPlain 是对 enPlain 的完整翻译，禁止摘要、改写剧情、用导读顶替；长度应覆盖原文信息点
- 英文正文禁止 Markdown：不要用 **word** 或 *word* 包目标词（App 会自行高亮）
- 禁止输出 dialog、turns、对话台词等字段

字段：
theme(中文标题 4-10 字：必须概括本篇短文的具体事件/话题，且能看出职业或场景；内容不同则 theme 必须不同；禁止「今日职场」「商务英语」「职场沟通」等空泛词),
title(英文短标题，同样要具体、贴合本篇内容与画像),
scene:{roleBackground(中文1-2句，点明身份与场景),tasks[3]（与阅读短文/点词/回填相关，勿提对话）},
article:{title(可贴合短文的英文题),zhTitle(title的中文译名，4-12字，具体),zhLead(中文≤40字，只作导读/摘要，不是全文翻译),enPlain(英文70-100词，自然写入全部目标词；纯文本勿加**),zhPlain(必须是 enPlain 的完整忠实中文翻译，一句不漏；禁止照搬 zhLead；目标词对应中文用【】包住，如【搬迁】；勿做成词表)},
cloze:[{sentence含________,hintZh,answer,before,after}] 尽量8题（可少）；answer必须∈上方目标词且互不重复；宁缺毋滥，勿编造目标词外的 answer

难度贴合 ${level}；职场自然；禁止只列单词；先想清本篇具体故事再写 theme/title；写完英文后务必另写完整中译。`;
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
  let sceneTitle = asString(raw.scene?.title, '① 场景导入（导读）');
  if (sceneTitle.includes('场景导入') && !sceneTitle.includes('导读')) {
    sceneTitle = sceneTitle.replace('场景导入', '场景导入（导读）');
  }
  const scene = {
    title: sceneTitle || '① 场景导入（导读）',
    roleBackground: asString(raw.scene?.roleBackground || raw.scene?.role_background),
    tasks: asArray(raw.scene?.tasks).map((t) => asString(t)).filter(Boolean).slice(0, 3),
  };
  if (scene.tasks.length < 2) {
    scene.tasks = ['读懂今日短文', '点开目标词看释义', '完成底部回填'];
  }

  const articlePlain = stripMarkdownEmphasis(
    asString(raw.article?.enPlain || raw.article?.en_plain),
  );
  const zhLead = asString(raw.article?.zhLead || raw.article?.zh_lead);
  // 勿用 zhLead 顶替 zhPlain：导读当译文会造成「翻译不准」
  let zhPlain = asString(raw.article?.zhPlain || raw.article?.zh_plain);
  if (zhPlain && zhLead && zhPlain === zhLead) zhPlain = '';
  const theme = refineTheme(raw.theme, zhLead || zhPlain);
  const articleTitle = asString(raw.article?.title, title);
  let zhTitle = asString(raw.article?.zhTitle || raw.article?.zh_title);
  // 无独立译名时用主题兜底（主题本身是中文）
  if (!zhTitle && theme && theme !== '今日短文') zhTitle = theme;
  const article = {
    title: articleTitle,
    zhTitle,
    zhLead,
    zhPlain,
    enPlain: articlePlain,
    enTokens: tokenizeEnglish(articlePlain, targetLemmas, reviewLemmas),
  };

  // 产品已去掉对话页：忽略模型偶发 dialog，固定空结构兼容旧客户端
  const dialog = {
    title: '',
    zhTitle: '',
    zhLead: '',
    enPlain: '',
    turns: [],
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
  // App 已按短文本地组回填；此处只保留合法目标词答案并补齐，避免模型写偏导致整篇校验失败
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

/** 丢掉非目标词答案，再用目标词补齐到 8 题，避免模型写偏整篇重跑 */
function padCloze(cloze, targetLemmas) {
  const targetSet = new Set(
    (targetLemmas || []).map(cleanLemma).filter(Boolean),
  );
  const out = [];
  const used = new Set();
  for (const c of cloze || []) {
    const a = cleanLemma(c.answer);
    if (!a || !targetSet.has(a) || used.has(a)) continue;
    used.add(a);
    out.push({ ...c, answer: a });
    if (out.length >= 8) break;
  }
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

/**
 * 模型常漏写目标词：把未覆盖词补进短文末句，保证覆盖率≥70%。
 * 优先补足到门槛即可，避免文末过长。
 */
function ensureTargetCoverage(lesson) {
  const targets = lesson.targetLemmas || [];
  if (!targets.length) return coverageScore('', []);

  const corpusOf = () => `${lesson.article?.enPlain || ''}`;
  let cov = coverageScore(corpusOf(), targets);
  if (cov.ratio >= 0.7) return cov;

  const need = Math.ceil(targets.length * 0.7) - cov.hit.length;
  const toAdd = cov.miss.slice(0, Math.max(need, 0));
  if (!toAdd.length) return cov;

  const bridge =
    toAdd.length === 1
      ? ` Keep the word "${toAdd[0]}" in mind today.`
      : ` Keep these words in mind today: ${toAdd.join(', ')}.`;
  const plain = asString(lesson.article?.enPlain).replace(/\s+$/, '');
  lesson.article.enPlain = `${plain}${bridge}`;
  lesson.article.enTokens = tokenizeEnglish(
    lesson.article.enPlain,
    targets,
    lesson.reviewLemmas || [],
  );
  return coverageScore(corpusOf(), targets);
}

function countCjk(text) {
  return (asString(text).match(/[\u4e00-\u9fff]/g) || []).length;
}

function enWordCount(text) {
  return asString(text)
    .split(/\s+/)
    .filter(Boolean).length;
}

/** 短文中译是否像完整翻译（而非导读） */
function isFaithfulArticleZh(lesson) {
  const en = asString(lesson.article?.enPlain);
  const zh = asString(lesson.article?.zhPlain);
  const lead = asString(lesson.article?.zhLead);
  if (!en || !zh) return false;
  if (lead && zh === lead) return false;
  const words = enWordCount(en);
  const cjk = countCjk(zh);
  // 英文约 70–100 词时，完整中译通常远长于导读（导读≤40字）
  if (cjk < Math.max(40, Math.floor(words * 0.7))) return false;
  if (lead && cjk <= countCjk(lead) + 8) return false;
  return true;
}

/**
 * 译文不合格时单独再译一轮（只出中文，不改英文故事）。
 */
async function ensureFaithfulTranslations(lesson) {
  if (isFaithfulArticleZh(lesson)) return { fixed: false };

  const targets = (lesson.targetLemmas || []).join(', ');
  const userParts = [
    '只做忠实中文翻译。禁止摘要、禁止改写剧情、禁止用导读代替。',
    '目标词对应的中文请用【】包住。',
    targets ? `目标词：${targets}` : '',
    `短文英文 enPlain：\n${lesson.article.enPlain}\n请输出完整中译到 zhPlain。`,
    '返回 JSON：{"zhPlain":"..."}',
  ]
    .filter(Boolean)
    .join('\n\n');

  const result = await chatCompletion({
    messages: [
      {
        role: 'system',
        content: 'You are a careful EN→ZH translator. Return one JSON object only.',
      },
      { role: 'user', content: userParts },
    ],
    temperature: 0.2,
    maxTokens: 900,
    jsonMode: true,
  });

  const raw = parseJsonContent(result.content);
  let fixed = false;
  const zh = asString(raw.zhPlain || raw.zh_plain);
  if (zh && (!lesson.article.zhLead || zh !== lesson.article.zhLead)) {
    lesson.article.zhPlain = zh;
    fixed = true;
  }
  return { fixed, latencyMs: result.latencyMs, model: result.model };
}

function validateLesson(lesson, { avoidThemes = [] } = {}) {
  const errors = [];
  if (!lesson.article?.enPlain || lesson.article.enPlain.split(/\s+/).length < 25) {
    errors.push('短文过短');
  }
  if (!isFaithfulArticleZh(lesson)) {
    errors.push('短文中译缺失或不像完整翻译（疑似导读顶替）');
  }
  // App 按短文本地组回填；服务端 cloze 仅兜底，题数随目标词走，不再死卡 8
  const needCloze = Math.min(8, (lesson.targetLemmas || []).length);
  if (needCloze > 0 && (!lesson.cloze || lesson.cloze.length < needCloze)) {
    errors.push(`回填不足 ${needCloze} 题（现 ${lesson.cloze?.length || 0}）`);
  }

  const theme = asString(lesson.theme);
  const avoidSet = new Set(
    (avoidThemes || []).map((t) => asString(t)).filter(Boolean),
  );
  if (theme && avoidSet.has(theme)) {
    errors.push(`主题与近期日课重复: ${theme}`);
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

  const cov = coverageScore(lesson.article.enPlain || '', lesson.targetLemmas);
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
    maxTokens: 1400,
    jsonMode: true,
  });

  const raw = parseJsonContent(result.content);
  const lesson = normalizeLesson(raw, {
    targetLemmas: ctx.targetLemmas,
    reviewLemmas: ctx.reviewLemmas || [],
    level: ctx.level,
    dayIndex: ctx.dayIndex,
  });
  ensureTargetCoverage(lesson);
  let translateMs = 0;
  try {
    const tr = await ensureFaithfulTranslations(lesson);
    if (tr.fixed) {
      translateMs = tr.latencyMs || 0;
      console.log(
        `[lesson] re-translate ok day=${ctx.dayIndex} llm=${translateMs}ms model=${tr.model || '?'}`,
      );
    }
  } catch (err) {
    console.warn('[lesson] re-translate failed:', err.message);
  }
  const check = validateLesson(lesson, {
    avoidThemes: ctx.avoidThemes || [],
  });
  return {
    lesson,
    check,
    usage: result.usage,
    model: result.model,
    latencyMs: (result.latencyMs || 0) + translateMs,
  };
}

async function recentThemesForUser(userId, limit = 12) {
  const { pool } = require('../db');
  const [rows] = await pool.query(
    `SELECT theme FROM lessons
     WHERE user_id = :userId AND theme IS NOT NULL AND theme <> ''
     ORDER BY id DESC LIMIT ${Math.max(1, Math.min(30, Number(limit) || 12))}`,
    { userId },
  );
  return [...new Set(rows.map((r) => asString(r.theme)).filter(Boolean))];
}

/** 用户已有日课里出现过的目标词（生成新篇时避开，避免天天同一批词）。 */
async function usedTargetLemmas(userId, { exceptLessonId = null } = {}) {
  const { pool } = require('../db');
  const [rows] = await pool.query(
    `SELECT id, content_json FROM lessons WHERE user_id = :userId`,
    { userId },
  );
  const used = [];
  for (const row of rows) {
    if (exceptLessonId && Number(row.id) === Number(exceptLessonId)) continue;
    let content = row.content_json;
    if (typeof content === 'string') {
      try {
        content = JSON.parse(content);
      } catch {
        content = {};
      }
    }
    const targets = content?.targetLemmas;
    if (Array.isArray(targets)) {
      for (const t of targets) {
        const l = cleanLemma(t);
        if (l) used.push(l);
      }
    }
  }
  return [...new Set(used)];
}

/**
 * 按画像 + 词库生成日课包；失败重试后抛错（由调用方降级种子）。
 */
async function generateLessonForUser(
  userId,
  { dayIndex = 1, lemmaOffset = 0, targetCount = 12, exceptLessonId = null } = {},
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
  // 目标词略少更易写进短文；复习词不占目标词名额、选词时一并排除
  const newCount = Math.max(
    8,
    Math.min(12, Number(targetCount) || 10) - reviewLemmas.length,
  );
  const usedLemmas = await usedTargetLemmas(userId, { exceptLessonId });
  const cursorOrd = (plan?.cursorOrd || 0) + lemmaOffset;
  const reviewSet = new Set(reviewLemmas.map(cleanLemma).filter(Boolean));
  const picked = await bankWordService.pickTargetLemmas(
    bankCode,
    cursorOrd,
    newCount,
    { excludeLemmas: [...usedLemmas, ...reviewSet] },
  );
  const targetLemmas = picked
    .map(cleanLemma)
    .filter((l) => l && !reviewSet.has(l));

  const { scenes, jobLabel, interests } = await resolveLabels(profile);
  const avoidThemes = await recentThemesForUser(userId, 12);

  const ctx = {
    level,
    jobLabel,
    scenes,
    interests,
    bankTitle: bank?.title || '商务英语',
    targetLemmas,
    reviewLemmas,
    dayIndex,
    avoidThemes,
    repairHint: '',
  };

  const retryMax = Math.max(1, config.generate.retryMax || 2);
  let lastErrors = [];
  for (let attempt = 1; attempt <= retryMax; attempt++) {
    try {
      const { lesson, check, usage, model, latencyMs } = await generateOnce(ctx);
      if (check.ok) {
        await wordDictService.attachDefsToLesson(lesson);
        lesson.profileFp = profileService.generationFingerprint(profile);
        console.log(
          `[lesson] ok day=${dayIndex} attempt=${attempt} llm=${latencyMs || '?'}ms model=${model} cov=${((check.coverage?.ratio || 0) * 100).toFixed(0)}%`,
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
      const miss = check.coverage?.miss?.slice(0, 8) || [];
      ctx.repairHint = miss.length
        ? `缺目标词 ${miss.join(', ')}；${check.errors.slice(0, 2).join('；')}`
        : check.errors.slice(0, 3).join('；');
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
  ensureTargetCoverage,
};
