const express = require('express');
const { requireAuth } = require('../middleware/auth');
const profileService = require('../services/profileService');

const router = express.Router();

router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const profile = await profileService.getProfile(req.auth.userId);
    res.json({ profile });
  } catch (err) {
    next(err);
  }
});

router.patch('/', async (req, res, next) => {
  try {
    const body = req.body || {};
    const profile = await profileService.patchProfile(req.auth.userId, {
      interests: body.interests,
      scenes: body.scenes,
      sceneRaw: body.sceneRaw ?? body.scene_raw,
      jobCode: body.jobCode ?? body.job_code,
      jobRaw: body.jobRaw ?? body.job_raw,
      dailyMinutes: body.dailyMinutes ?? body.daily_minutes,
      targetDays: body.targetDays ?? body.target_days,
      primaryBankId: body.primaryBankId ?? body.primary_bank_id,
      timezone: body.timezone,
      onboardingStep: body.onboardingStep ?? body.onboarding_step,
    });
    res.json({ profile });
  } catch (err) {
    next(err);
  }
});

router.post('/generation-level', async (req, res, next) => {
  try {
    const delta = Number(req.body?.delta);
    const profile = await profileService.bumpGenerationLevel(
      req.auth.userId,
      delta,
    );
    res.json({ profile });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
