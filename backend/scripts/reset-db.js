/**
 * 清空并重建数据库，再 migrate + seed-bank-words。
 * 用法：node scripts/reset-db.js
 */
require('dotenv').config();
const { spawnSync } = require('child_process');
const path = require('path');
const mysql = require('mysql2/promise');

async function main() {
  const {
    MYSQL_HOST,
    MYSQL_PORT,
    MYSQL_USER,
    MYSQL_PASSWORD,
    MYSQL_DATABASE,
  } = process.env;
  const dbName = MYSQL_DATABASE || 'english_learn';

  const conn = await mysql.createConnection({
    host: MYSQL_HOST || '127.0.0.1',
    port: Number(MYSQL_PORT) || 3306,
    user: MYSQL_USER || 'root',
    password: MYSQL_PASSWORD || '',
    multipleStatements: true,
  });

  await conn.query(`DROP DATABASE IF EXISTS \`${dbName}\``);
  await conn.query(
    `CREATE DATABASE \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
  );
  console.log(`[reset-db] recreated ${dbName}`);
  await conn.end();

  const cwd = path.join(__dirname, '..');
  for (const script of ['migrate.js', 'seed-bank-words.js']) {
    const r = spawnSync(process.execPath, [path.join(__dirname, script)], {
      cwd,
      stdio: 'inherit',
      env: process.env,
    });
    if (r.status !== 0) {
      process.exit(r.status || 1);
    }
  }
  console.log('[reset-db] done');
}

main().catch((err) => {
  console.error('[reset-db] failed:', err.message);
  process.exit(1);
});
