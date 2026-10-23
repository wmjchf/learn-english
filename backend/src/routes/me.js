const express = require('express');
const { requireAuth } = require('../middleware/auth');
const meService = require('../services/meService');

const router = express.Router();

router.use(requireAuth);

/** 「我的」页聚合：画像英雄区 + 词汇量/连胜 */
router.get('/', async (req, res, next) => {
  try {
    const me = await meService.getMeSummary(
      req.auth.userId,
      req.auth.phone,
    );
    res.json({ me });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
