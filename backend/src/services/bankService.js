const { pool } = require('../db');

function mapBank(row) {
  return {
    id: row.id,
    code: row.code,
    type: row.type,
    title: row.title,
    subtitle: row.subtitle || undefined,
    targetSize: row.target_size,
    wordCount: row.word_count,
  };
}

async function listBanks() {
  const [rows] = await pool.query(
    `SELECT id, code, type, title, subtitle, target_size, word_count
     FROM word_banks
     WHERE enabled = 1
     ORDER BY sort ASC, id ASC`,
  );
  return { items: rows.map(mapBank) };
}

async function getBank(bankId) {
  const [rows] = await pool.query(
    `SELECT id, code, type, title, subtitle, target_size, word_count
     FROM word_banks
     WHERE id = :id AND enabled = 1
     LIMIT 1`,
    { id: bankId },
  );
  return rows[0] ? mapBank(rows[0]) : null;
}

module.exports = {
  listBanks,
  getBank,
};
