const express = require('express');
const { requireAuth } = require('../middleware/auth');
const planService = require('../services/planService');

const router = express.Router();

router.use(requireAuth);

/** 选定主词库并进入计划步 */
router.post('/', async (req, res, next) => {
  try {
    const bankId = req.body?.bankId ?? req.body?.bank_id;
    const result = await planService.selectBank(req.auth.userId, bankId);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/** 画像内切换主词库（不回退 onboarding） */
router.post('/switch-bank', async (req, res, next) => {
  try {
    const bankId = req.body?.bankId ?? req.body?.bank_id;
    const result = await planService.switchPrimaryBank(req.auth.userId, bankId);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/** 计划设置页上下文（词库、已知词、默认估算） */
router.get('/context', async (req, res, next) => {
  try {
    res.json(await planService.getPlanContext(req.auth.userId));
  } catch (err) {
    next(err);
  }
});

/** 双向联动预估 */
router.get('/estimate', async (req, res, next) => {
  try {
    const minutes =
      req.query.minutes != null ? Number(req.query.minutes) : undefined;
    const days = req.query.days != null ? Number(req.query.days) : undefined;
    res.json(
      await planService.estimatePlan(req.auth.userId, {
        minutes: Number.isFinite(minutes) ? minutes : undefined,
        days: Number.isFinite(days) ? days : undefined,
      }),
    );
  } catch (err) {
    next(err);
  }
});

/** 确认计划并完成 Onboarding */
router.post('/confirm', async (req, res, next) => {
  try {
    const minutes = req.body?.minutes ?? req.body?.dailyMinutes;
    const days = req.body?.days ?? req.body?.targetDays;
    const result = await planService.confirmPlan(req.auth.userId, {
      minutes: minutes != null ? Number(minutes) : undefined,
      days: days != null ? Number(days) : undefined,
    });
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
