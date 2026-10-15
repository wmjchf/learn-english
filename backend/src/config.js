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
};
