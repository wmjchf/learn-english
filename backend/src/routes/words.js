const express = require('express');
const { requireAuth } = require('../middleware/auth');
const wordLookupService = require('../services/wordLookupService');
const wordLifecycleService = require('../services/wordLifecycleService');

const router = express.Router();

router.use(requireAuth);

/** 点词释义：日课 defs → word_gloss → bank_words → LLM 详解 */
router.post('/lookup', async (req, res, next) => {
  try {
    const surface = req.body?.surface;
    const lemma = req.body?.lemma;
    const lessonId = req.body?.lessonId ?? req.body?.lesson_id;
    const entry = await wordLookupService.lookup(req.auth.userId, {
      surface,
      lemma,
      lessonId,
    });
    res.json({ entry });
  } catch (err) {
    next(err);
  }
});

/** 生词本：分桶列表 + 今日到期摘要 */
router.get('/', async (req, res, next) => {
  try {
    const bucket = req.query.bucket || 'consolidating';
    const data = await wordLifecycleService.listVocab(req.auth.userId, {
      bucket: String(bucket),
    });
    res.json(data);
  } catch (err) {
    next(err);
  }
});

/** 到期闪卡队列 */
router.get('/due', async (req, res, next) => {
  try {
    const data = await wordLifecycleService.listDueReviews(req.auth.userId);
    res.json(data);
  } catch (err) {
    next(err);
  }
});

/** 闪卡作答 */
router.post('/review', async (req, res, next) => {
  try {
    const lemma = req.body?.lemma;
    const know = req.body?.know === true || req.body?.know === 1;
    const word = await wordLifecycleService.answerReview(req.auth.userId, lemma, {
      know,
    });
    res.json({ word });
  } catch (err) {
    next(err);
  }
});

/** 复习会话结束 → 打卡（只复习也可保连胜） */
router.post('/review/complete', async (req, res, next) => {
  try {
    const streakService = require('../services/streakService');
    const checkin = await streakService.recordCheckin(
      req.auth.userId,
      'review',
    );
    res.json({ checkin });
  } catch (err) {
    next(err);
  }
});

router.post('/:lemma/know', async (req, res, next) => {
  try {
    const lessonId = req.body?.lessonId ?? req.body?.lesson_id;
    const word = await wordLifecycleService.markKnown(
      req.auth.userId,
      decodeURIComponent(req.params.lemma),
      { lessonId },
    );
    res.json({ word });
  } catch (err) {
    next(err);
  }
});

router.post('/:lemma/vocab', async (req, res, next) => {
  try {
    const lessonId = req.body?.lessonId ?? req.body?.lesson_id;
    const gloss = req.body?.gloss;
    const word = await wordLifecycleService.markVocab(
      req.auth.userId,
      decodeURIComponent(req.params.lemma),
      { lessonId, gloss },
    );
    res.json({ word });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
