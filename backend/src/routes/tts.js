const express = require('express');
const { requireAuth } = require('../middleware/auth');
const ttsService = require('../services/ttsService');

const router = express.Router();

router.use(requireAuth);

/**
 * POST /api/tts
 * body: { text, languageType?, voice? }
 * → { urls, voice, model, cached, expiresAt }
 */
router.post('/', async (req, res, next) => {
  try {
    const text = req.body?.text;
    const languageType = req.body?.languageType || req.body?.language_type;
    const voice = req.body?.voice;
    const result = await ttsService.synthesize(text, {
      languageType,
      voice,
    });
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
