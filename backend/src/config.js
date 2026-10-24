require('dotenv').config();

module.exports = {
  port: Number(process.env.PORT) || 3001,
  mysql: {
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT) || 3306,
    user: process.env.MYSQL_USER || 'root',
    password: process.env.MYSQL_PASSWORD || '',
    database: process.env.MYSQL_DATABASE || 'app_starter',
  },
  auth: {
    jwtSecret: process.env.JWT_SECRET || 'dev-change-me',
    jwtAccessExpires: process.env.JWT_ACCESS_EXPIRES || '7d',
    refreshExpiresDays: Number(process.env.REFRESH_EXPIRES_DAYS) || 30,
    smsDevMode: process.env.SMS_DEV_MODE !== 'false',
    smsDevCode: process.env.SMS_DEV_CODE || '123456',
    smsReviewPhone: process.env.SMS_REVIEW_PHONE || '',
    smsReviewCode: process.env.SMS_REVIEW_CODE || '888888',
  },
  aliyun: {
    accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || '',
    accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || '',
    signName: process.env.ALIYUN_SMS_SIGN_NAME || '',
    templateCode: process.env.ALIYUN_SMS_TEMPLATE_CODE || '',
    templateParam:
      process.env.ALIYUN_SMS_TEMPLATE_PARAM ||
      JSON.stringify({ code: '##code##', min: '5' }),
  },
  llm: {
    apiKey:
      process.env.DASHSCOPE_API_KEY || process.env.LLM_API_KEY || '',
    baseUrl: (
      process.env.DASHSCOPE_BASE_URL ||
      process.env.LLM_API_BASE ||
      'https://dashscope.aliyuncs.com/compatible-mode/v1'
    ).replace(/\/$/, ''),
    model:
      process.env.ALIYUN_AI_MODEL || process.env.LLM_MODEL || 'qwen3.8-27b',
    timeoutMs: Number(process.env.LLM_TIMEOUT_MS) || 180000,
    /** false=关闭 Qwen3 思考链（成文场景） */
    enableThinking: process.env.LLM_ENABLE_THINKING === 'true',
  },
  generate: {
    dailyQuota: Number(process.env.GENERATE_DAILY_QUOTA) || 1,
    retryMax: Number(process.env.LESSON_RETRY_MAX) || 1,
  },
  /** 百炼 Qwen-TTS（朗读） */
  tts: {
    model: process.env.TTS_MODEL || 'qwen3-tts-flash',
    voice: process.env.TTS_VOICE || 'Cherry',
    languageType: process.env.TTS_LANGUAGE_TYPE || 'English',
  },
};
