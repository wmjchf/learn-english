/**
 * 从 Markdown 词表（表格）导入 bank_words。
 *
 * 兼容「英语词库合集」常见表头：
 *   | 序号 | 单词 | 音标/释义 | 中文释义 | ... |
 *   | 序号 | 单词 | 释义 | ... |
 *
 * 用法：
 *   node scripts/import-bank-from-md.js --file=/path/to/大学英语四级.md --bank=cet4
 *   node scripts/import-bank-from-md.js --file=./四级核心词.md --bank=cet4 --replace
 *   node scripts/import-bank-from-md.js --file=./x.md --bank=cet4 --dry-run
 *
 * 导入后仍需为新词补详解（成文依赖 word_gloss）：
 *   pnpm db:seed-gloss -- --bank=cet4
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

function parseArgs(argv) {
  const out = {
    file: null,
    bank: 'cet4',
    replace: false,
    dryRun: false,
    shuffle: true,
    minLen: 2,
  };
  for (const a of argv) {
    if (a === '--replace') out.replace = true;
    else if (a === '--dry-run') out.dryRun = true;
    else if (a === '--no-shuffle') out.shuffle = false;
    else if (a.startsWith('--file=')) out.file = a.slice(7).trim();
    else if (a.startsWith('--bank=')) out.bank = a.slice(7).trim() || 'cet4';
    else if (a.startsWith('--min-len=')) {
      out.minLen = Math.max(1, Number(a.slice(10)) || 2);
    } else if (!a.startsWith('-') && !out.file) {
      out.file = a;
    }
  }
  return out;
}

function shuffleInPlace(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

function splitTableRow(line) {
  const raw = line.trim();
  if (!raw.startsWith('|')) return null;
  const parts = raw.split('|').map((c) => c.trim());
  // 首尾空段来自两侧 |
  if (parts.length && parts[0] === '') parts.shift();
  if (parts.length && parts[parts.length - 1] === '') parts.pop();
  return parts;
}

function isSeparatorRow(cells) {
  return cells.every((c) => /^:?-{3,}:?$/.test(c.replace(/\s/g, '')));
}

function normalizeLemma(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ');
}

function isValidLemma(lemma, minLen) {
  if (!lemma || lemma.length < minLen) return false;
  if (lemma.length > 64) return false;
  // 只要英文字母 / 连字符 / 撇号；过滤中文标题行
  if (!/^[a-z][a-z'-]*$/i.test(lemma)) return false;
  return true;
}

function shortenGloss(raw) {
  let s = String(raw || '')
    .replace(/\\r\\n/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .trim();
  s = s.replace(/\[[^\]]*\]/g, '').trim();
  s = (s.split('\n').find((line) => line.trim()) || '').trim();
  s = s.replace(/\s+/g, ' ');
  // 去掉词性前缀过长时仍保留；截断入库上限
  return s.slice(0, 256);
}

/**
 * 解析 MD 表格 → [{ lemma, gloss }]
 */
function parseMarkdownBank(text, { minLen = 2 } = {}) {
  const lines = String(text || '').split(/\n/);
  let headers = null;
  const items = [];
  const seen = new Set();

  for (const line of lines) {
    const cells = splitTableRow(line);
    if (!cells || !cells.length) continue;
    if (isSeparatorRow(cells)) continue;

    if (!headers) {
      const joined = cells.join('|');
      if (!/单词|lemma|word/i.test(joined)) continue;
      headers = cells.map((h) => h.toLowerCase());
      continue;
    }

    const idxLemma = headers.findIndex((h) => /^(单词|lemma|word)$/i.test(h));
    if (idxLemma < 0) {
      throw new Error('表头未找到「单词」列');
    }
    // 优先短释义列：音标/释义 → 释义 → 中文释义
    let idxGloss = headers.findIndex((h) => /音标/.test(h) && /释义/.test(h));
    if (idxGloss < 0) idxGloss = headers.findIndex((h) => h === '释义');
    if (idxGloss < 0) idxGloss = headers.findIndex((h) => /中文释义|gloss|释义/.test(h));

    const lemma = normalizeLemma(cells[idxLemma]);
    if (!isValidLemma(lemma, minLen)) continue;
    if (seen.has(lemma)) continue;
    seen.add(lemma);

    const glossRaw = idxGloss >= 0 ? cells[idxGloss] : '';
    const gloss = shortenGloss(glossRaw) || lemma;
    items.push({ lemma, gloss });
  }

  return items;
}

async function upsertWords(bankCode, items, { replace }) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    if (replace) {
      const [del] = await conn.query(
        `DELETE FROM bank_words WHERE bank_code = :bankCode`,
        { bankCode },
      );
      console.log(
        `[import-md] replaced: deleted ${del.affectedRows || 0} old rows (${bankCode})`,
      );
    }

    let n = 0;
    for (let ord = 0; ord < items.length; ord++) {
      const item = items[ord];
      await conn.query(
        `INSERT INTO bank_words (bank_code, lemma, gloss, root, \`ord\`)
         VALUES (:bankCode, :lemma, :gloss, NULL, :ord)
         ON DUPLICATE KEY UPDATE
           gloss = VALUES(gloss),
           \`ord\` = VALUES(\`ord\`)`,
        {
          bankCode,
          lemma: item.lemma,
          gloss: item.gloss,
          ord,
        },
      );
      n += 1;
      if (n % 500 === 0) {
        console.log(`[import-md] upserted ${n}/${items.length}…`);
      }
    }

    await conn.query(
      `UPDATE word_banks SET word_count = :n WHERE code = :code`,
      { n: items.length, code: bankCode },
    );
    await conn.commit();
    return n;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.file) {
    console.error(
      '用法: node scripts/import-bank-from-md.js --file=/path/to/词表.md --bank=cet4 [--replace] [--dry-run]',
    );
    process.exit(1);
  }

  const abs = path.resolve(args.file);
  if (!fs.existsSync(abs)) {
    throw new Error(`文件不存在: ${abs}`);
  }

  const text = fs.readFileSync(abs, 'utf8');
  let items = parseMarkdownBank(text, { minLen: args.minLen });
  if (!items.length) {
    throw new Error('未解析到任何单词（请确认是带「单词」列的 Markdown 表格）');
  }
  if (args.shuffle) shuffleInPlace(items);

  console.log(
    `[import-md] file=${abs} bank=${args.bank} words=${items.length}` +
      ` replace=${args.replace} shuffle=${args.shuffle}`,
  );
  console.log(
    `[import-md] sample: ${items
      .slice(0, 5)
      .map((x) => `${x.lemma}=${x.gloss.slice(0, 24)}`)
      .join(' | ')}`,
  );

  if (args.dryRun) {
    console.log('[import-md] dry-run，未写库');
    return;
  }

  const n = await upsertWords(args.bank, items, { replace: args.replace });
  console.log(`[import-md] done: ${n} rows → bank_words (${args.bank})`);
  console.log(
    '[import-md] 下一步补详解（成文需要）: pnpm db:seed-gloss -- --bank=' +
      args.bank,
  );
}

main()
  .catch(async (err) => {
    console.error('[import-md] failed:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await pool.end();
    } catch {
      /* ignore */
    }
  });
