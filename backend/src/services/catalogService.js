const { pool } = require('../db');

const MAX_SELECT = {
  interest: 3,
  scene: 3,
  job: 1,
};

async function listByKind(kind) {
  const [rows] = await pool.query(
    `SELECT code, label, subtitle, allow_custom AS allowCustom
     FROM option_catalog
     WHERE kind = :kind AND enabled = 1
     ORDER BY sort ASC, id ASC`,
    { kind },
  );
  return {
    maxSelect: MAX_SELECT[kind] ?? 1,
    items: rows.map((r) => ({
      code: r.code,
      label: r.label,
      subtitle: r.subtitle || undefined,
      allowCustom: !!r.allowCustom,
    })),
  };
}

async function isEnabledCode(kind, code) {
  const [rows] = await pool.query(
    `SELECT 1 FROM option_catalog
     WHERE kind = :kind AND code = :code AND enabled = 1
     LIMIT 1`,
    { kind, code },
  );
  return rows.length > 0;
}

async function wasEverCode(kind, code) {
  const [rows] = await pool.query(
    `SELECT 1 FROM option_catalog
     WHERE kind = :kind AND code = :code
     LIMIT 1`,
    { kind, code },
  );
  return rows.length > 0;
}

module.exports = {
  MAX_SELECT,
  listByKind,
  isEnabledCode,
  wasEverCode,
};
