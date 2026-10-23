const express = require('express');
const { requireAuth } = require('../middleware/auth');
const assessService = require('../services/assessService');

const router = express.Router();

router.use(requireAuth);

router.post('/sessions', async (req, res, next) => {
  try {
    const startLevel = req.body?.startLevel ?? req.body?.start_level;
    const result = await assessService.startSession(req.auth.userId, startLevel);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/:id/answer', async (req, res, next) => {
  try {
    const sessionId = Number(req.params.id);
    if (!sessionId) {
      return res.status(400).json({ message: '无效会话' });
    }
    const optionId = req.body?.optionId ?? req.body?.option_id;
    if (optionId == null || String(optionId).trim() === '') {
      return res.status(400).json({ message: '请选择一个选项' });
    }
    const result = await assessService.answerSession(
      req.auth.userId,
      sessionId,
      optionId,
    );
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/:id/finish', async (req, res, next) => {
  try {
    const sessionId = Number(req.params.id);
    if (!sessionId) {
      return res.status(400).json({ message: '无效会话' });
    }
    const result = await assessService.forceFinish(req.auth.userId, sessionId);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
