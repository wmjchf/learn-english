const express = require('express');
const { requireAuth } = require('../middleware/auth');
const profileService = require('../services/profileService');

const router = express.Router();

router.post('/complete', requireAuth, async (req, res, next) => {
  try {
    const profile = await profileService.completeOnboarding(req.auth.userId);
    res.json({ profile });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
