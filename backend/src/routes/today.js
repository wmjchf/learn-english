const express = require('express');
const { requireAuth } = require('../middleware/auth');
const todayService = require('../services/todayService');

const router = express.Router();

router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const today = await todayService.getToday(req.auth.userId);
    res.json({ today });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
