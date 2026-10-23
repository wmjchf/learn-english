const express = require('express');
const { isValidPhone, normalizePhone } = require('../utils/phone');
const authService = require('../services/authService');
const profileService = require('../services/profileService');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/sms/send', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    if (!isValidPhone(phone)) {
      return res.status(400).json({ message: '请输入正确的手机号' });
    }
    const result = await authService.sendLoginCode(phone);
    return res.json(result);
  } catch (err) {
    return next(err);
  }
});

router.post('/sms/login', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const code = String(req.body?.code || '').trim();
    if (!isValidPhone(phone)) {
      return res.status(400).json({ message: '请输入正确的手机号' });
    }
    if (!code) {
      return res.status(400).json({ message: '请输入验证码' });
    }
    const result = await authService.loginWithSms(phone, code);
    const profile = await profileService.ensureProfile(result.user.id);
    return res.json({ ...result, profile });
  } catch (err) {
    return next(err);
  }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const refreshToken = String(req.body?.refreshToken || '').trim();
    if (!refreshToken) {
      return res.status(401).json({ message: '登录已失效' });
    }
    const result = await authService.refreshSession(refreshToken);
    return res.json(result);
  } catch (err) {
    return next(err);
  }
});

router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await authService.findUserByPhone(req.auth.phone);
    if (!user) {
      return res.status(401).json({ message: '未登录' });
    }
    const profile = await profileService.ensureProfile(user.id);
    return res.json({
      user: {
        id: user.id,
        phone: user.phone,
        nickname: user.nickname,
        avatarUrl: user.avatar_url,
      },
      profile,
    });
  } catch (err) {
    return next(err);
  }
});

router.delete('/account', requireAuth, async (req, res, next) => {
  try {
    await authService.deleteAccount(req.auth.userId);
    return res.json({ ok: true, message: '账号已注销' });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
