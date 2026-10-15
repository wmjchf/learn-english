const express = require('express');
const path = require('path');
const cors = require('cors');
const healthRouter = require('./routes/health');
const authRouter = require('./routes/auth');

const app = express();
const publicDir = path.join(__dirname, '..', 'public');

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.static(publicDir));

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>App Starter</title></head>
<body style="font-family:system-ui;padding:2rem">
  <h1>App Starter API</h1>
  <p>Health: <a href="/api/health">/api/health</a></p>
</body></html>`);
});

app.use('/api', healthRouter);
app.use('/api/auth', authRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  const status = err.status || 500;
  const body = { message: err.message || 'Internal Server Error' };
  if (err.code) body.code = err.code;
  res.status(status).json(body);
});

module.exports = app;
