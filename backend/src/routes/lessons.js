const express = require('express');
const { requireAuth } = require('../middleware/auth');
const lessonService = require('../services/lessonService');
const generateQuotaService = require('../services/generateQuotaService');

const router = express.Router();

router.use(requireAuth);

/** 今日 / 首篇日课（无则 AI 生成，失败降级种子） */
router.get('/today', async (req, res, next) => {
  try {
    const lesson = await lessonService.getTodayLesson(req.auth.userId);
    res.json({ lesson });
  } catch (err) {
    next(err);
  }
});

/** AI 重写今日未读日课 */
router.post('/today/regenerate', async (req, res, next) => {
  try {
    const lesson = await lessonService.regenerateToday(req.auth.userId);
    res.json({ lesson });
  } catch (err) {
    next(err);
  }
});

/** 文章库列表 */
router.get('/', async (req, res, next) => {
  try {
    const status = String(req.query.status || 'all');
    const result = await lessonService.listLessons(req.auth.userId, { status });
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/** 手动生成额度 */
router.get('/quota', async (req, res, next) => {
  try {
    const quota = await generateQuotaService.getQuota(req.auth.userId);
    res.json({ quota });
  } catch (err) {
    next(err);
  }
});

/** 手动生成新文章（扣日免费额度，并设为今日篇） */
router.post('/generate', async (req, res, next) => {
  try {
    const result = await lessonService.manualGenerate(req.auth.userId);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const lesson = await lessonService.getById(
      Number(req.params.id),
      req.auth.userId,
    );
    res.json({ lesson });
  } catch (err) {
    next(err);
  }
});

router.post('/:id/open', async (req, res, next) => {
  try {
    const lesson = await lessonService.markReading(
      Number(req.params.id),
      req.auth.userId,
    );
    res.json({ lesson });
  } catch (err) {
    next(err);
  }
});

router.post('/:id/complete', async (req, res, next) => {
  try {
    const wrongLemmas =
      req.body?.wrongLemmas || req.body?.wrong_lemmas || [];
    const result = await lessonService.markDone(
      Number(req.params.id),
      req.auth.userId,
      { wrongLemmas },
    );
    res.json({
      lesson: result.lesson,
      checkin: {
        already: result.checkin.already,
        streakDelta: result.checkin.streakDelta,
        streak: result.checkin.streak,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
