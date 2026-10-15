require('dotenv').config();
const fs = require('fs');
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

  const dbName = MYSQL_DATABASE || 'app_starter';
  const conn = await mysql.createConnection({
    host: MYSQL_HOST || '127.0.0.1',
    port: Number(MYSQL_PORT) || 3306,
    user: MYSQL_USER || 'root',
    password: MYSQL_PASSWORD || '',
    multipleStatements: true,
  });

  await conn.query(
    `CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
  );
  await conn.query(`USE \`${dbName}\``);
  await conn.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name VARCHAR(128) NOT NULL PRIMARY KEY,
      applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  const name = '001_schema.sql';
  const [rows] = await conn.query(
    'SELECT 1 FROM schema_migrations WHERE name = ? LIMIT 1',
    [name],
  );
  if (rows.length) {
    console.log(`[db:migrate] skip ${name} (already applied)`);
  } else {
    const sql = fs.readFileSync(
      path.join(__dirname, '../sql', name),
      'utf8',
    );
    await conn.query(sql);
    await conn.query('INSERT INTO schema_migrations (name) VALUES (?)', [name]);
    console.log(`[db:migrate] applied ${name}`);
  }

  await conn.end();
}

main().catch((err) => {
  console.error('[db:migrate] failed:', err.message);
  process.exit(1);
});
