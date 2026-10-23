const express = require('express');
const { requireAuth } = require('../middleware/auth');
const streakService = require('../services/streakService');

const router = express.Router();

router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const streak = await streakService.getStreak(req.auth.userId);
    res.json({ streak });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
