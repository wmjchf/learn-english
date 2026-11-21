const express = require('express');
const { requireAuth } = require('../middleware/auth');
const lexiconService = require('../services/lexiconService');

const router = express.Router();

router.use(requireAuth);

/** GET /api/lexicon/:lemma — 词根词缀 / 同义易混 */
router.get('/:lemma', async (req, res, next) => {
  try {
    const entry = await lexiconService.lookup(req.params.lemma);
    res.json({ entry });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
