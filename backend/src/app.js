const express = require('express');
const path = require('path');
const cors = require('cors');
const healthRouter = require('./routes/health');
const authRouter = require('./routes/auth');
const catalogRouter = require('./routes/catalog');
const profileRouter = require('./routes/profile');
const onboardingRouter = require('./routes/onboarding');
const assessRouter = require('./routes/assess');
const banksRouter = require('./routes/banks');
const plansRouter = require('./routes/plans');
const lessonsRouter = require('./routes/lessons');
const todayRouter = require('./routes/today');
const wordsRouter = require('./routes/words');
const meRouter = require('./routes/me');
const streakRouter = require('./routes/streak');
const llmRouter = require('./routes/llm');
const ttsRouter = require('./routes/tts');

const app = express();
const publicDir = path.join(__dirname, '..', 'public');

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.static(publicDir));

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>词成文 API</title></head>
<body style="font-family:system-ui;padding:2rem">
  <h1>词成文 API</h1>
  <p>Health: <a href="/api/health">/api/health</a></p>
</body></html>`);
});

app.use('/api', healthRouter);
app.use('/api/auth', authRouter);
app.use('/api/catalog', catalogRouter);
app.use('/api/profile', profileRouter);
app.use('/api/onboarding', onboardingRouter);
app.use('/api/assess', assessRouter);
app.use('/api/banks', banksRouter);
app.use('/api/plans', plansRouter);
app.use('/api/lessons', lessonsRouter);
app.use('/api/today', todayRouter);
app.use('/api/words', wordsRouter);
app.use('/api/me', meRouter);
app.use('/api/streak', streakRouter);
app.use('/api/llm', llmRouter);
app.use('/api/tts', ttsRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  const status = err.status || 500;
  const body = { message: err.message || 'Internal Server Error' };
  if (err.code) body.code = err.code;
  res.status(status).json(body);
});

module.exports = app;
