const express = require('express');
const { requireAuth } = require('../middleware/auth');
const bankService = require('../services/bankService');

const router = express.Router();

router.use(requireAuth);

router.get('/', async (_req, res, next) => {
  try {
    res.json(await bankService.listBanks());
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const bank = await bankService.getBank(Number(req.params.id));
    if (!bank) {
      return res.status(404).json({ message: '词库不存在' });
    }
    res.json({ bank });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
