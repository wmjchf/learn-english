const express = require('express');
const { requireAuth } = require('../middleware/auth');
const catalogService = require('../services/catalogService');

const router = express.Router();

router.use(requireAuth);

router.get('/interests', async (_req, res, next) => {
  try {
    res.json(await catalogService.listByKind('interest'));
  } catch (err) {
    next(err);
  }
});

router.get('/scenes', async (_req, res, next) => {
  try {
    res.json(await catalogService.listByKind('scene'));
  } catch (err) {
    next(err);
  }
});

router.get('/jobs', async (_req, res, next) => {
  try {
    res.json(await catalogService.listByKind('job'));
  } catch (err) {
    next(err);
  }
});

/** Optional combined endpoint */
router.get('/', async (req, res, next) => {
  try {
    const kinds = String(req.query.kinds || 'interest,scene,job')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const out = {};
    for (const kind of kinds) {
      if (!['interest', 'scene', 'job'].includes(kind)) continue;
      out[kind === 'interest' ? 'interests' : kind === 'scene' ? 'scenes' : 'jobs'] =
        await catalogService.listByKind(kind);
    }
    res.json(out);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
