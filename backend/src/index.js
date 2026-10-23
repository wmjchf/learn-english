const app = require('./app');
const config = require('./config');
const { ping } = require('./db');

async function start() {
  try {
    await ping();
    console.log(
      `[db] connected ${config.mysql.host}:${config.mysql.port}/${config.mysql.database}`,
    );
  } catch (err) {
    console.warn(`[db] not ready: ${err.message}`);
    console.warn('[db] API will start anyway; /api/health will report db status');
  }

  app.listen(config.port, '0.0.0.0', () => {
    console.log(`[server] http://0.0.0.0:${config.port}`);
    const aliyunSms = require('./services/aliyunSms');
    console.log(
      `[auth] smsDevMode=${config.auth.smsDevMode} aliyunConfigured=${aliyunSms.isConfigured()}`,
    );

    // 公共池种子
    try {
      const lessonPoolService = require('./services/lessonPoolService');
      lessonPoolService.ensureSeedPool().then(() => {
        console.log('[lesson] pool seed ready');
      });
    } catch (err) {
      console.warn('[lesson] pool seed failed:', err.message);
    }

    // 每小时扫一次：用户本地 0–1 点结算昨日未打卡（冻结 / 断签）
    const streakService = require('./services/streakService');
    const run = async () => {
      try {
        const r = await streakService.runFreezeJob();
        if (r.freeze || r.break) {
          console.log(`[streak] freezeJob freeze=${r.freeze} break=${r.break}`);
        }
      } catch (err) {
        console.warn('[streak] freezeJob failed:', err.message);
      }
    };
    setTimeout(run, 15_000);
    setInterval(run, 60 * 60 * 1000);
  });
}

start();
