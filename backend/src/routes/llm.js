const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { chatCompletion } = require('../services/llmClient');
const config = require('../config');

const router = express.Router();

/** Dev/ops probe：确认百炼连通（需登录） */
router.get('/ping', requireAuth, async (_req, res, next) => {
  try {
    if (!config.llm.apiKey) {
      return res.status(500).json({
        ok: false,
        code: 'LLM_NOT_CONFIGURED',
        message: '未配置 DASHSCOPE_API_KEY',
      });
    }
    const result = await chatCompletion({
      messages: [
        { role: 'system', content: 'Reply with exactly: pong' },
        { role: 'user', content: 'ping' },
      ],
      temperature: 0,
      maxTokens: 16,
    });
    res.json({
      ok: true,
      model: result.model,
      content: result.content.trim(),
      usage: result.usage,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
