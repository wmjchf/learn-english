/**
 * 从自定义路径的 Markdown 导入词根词缀 + 同义易混 → lexicon_*。
 * 用法对齐 import-bank-from-md（自定义 --file 路径，可选 --replace / --dry-run）。
 *
 * 用法：
 *   node scripts/import-lexicon-from-md.js \
 *     --roots=/path/to/roots-az.md \
 *     --synonyms=/path/to/synonyms.md
 *
 *   node scripts/import-lexicon-from-md.js \
 *     --roots=./roots.md --synonyms=./syn.md --replace
 *
 *   node scripts/import-lexicon-from-md.js \
 *     --roots=./roots.md --synonyms=./syn.md --dry-run
 *
 * 或：pnpm db:import-lexicon -- --roots=... --synonyms=...
 */
require('dotenv').config();
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

function parseArgs(argv) {
  const out = {
    roots: null,
    synonyms: null,
    replace: false,
    dryRun: false,
  };
  for (const a of argv) {
    if (a === '--replace') out.replace = true;
    else if (a === '--dry-run') out.dryRun = true;
    else if (a.startsWith('--roots=')) out.roots = a.slice(8).trim();
    else if (a.startsWith('--synonyms=')) out.synonyms = a.slice(11).trim();
    else if (a.startsWith('--file=')) {
      // 兼容误用：单文件时当 roots（仍需 synonyms）
      if (!out.roots) out.roots = a.slice(7).trim();
    }
  }
  return out;
}

function usage() {
  console.error(`用法:
  node scripts/import-lexicon-from-md.js --roots=/path/roots.md --synonyms=/path/syn.md [--replace] [--dry-run]

说明:
  --roots      词根词缀 MD（必填，自定义路径）
  --synonyms   同形同义/易混 MD（必填，自定义路径）
  --replace    先清空 lexicon_* 再灌入（上生产建议加）
  --dry-run    只构建中间 JSON，不写库`);
}

function run(label, cmd, args, opts = {}) {
  console.log(`[import-lexicon] ${label}: ${cmd} ${args.join(' ')}`);
  const r = spawnSync(cmd, args, {
    stdio: 'inherit',
    cwd: opts.cwd,
    env: process.env,
  });
  if (r.status !== 0) {
    throw new Error(`${label} failed (exit ${r.status})`);
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.roots || !args.synonyms) {
    usage();
    process.exit(1);
  }

  const rootsAbs = path.resolve(args.roots);
  const synAbs = path.resolve(args.synonyms);
  if (!fs.existsSync(rootsAbs)) {
    throw new Error(`词根文件不存在: ${rootsAbs}`);
  }
  if (!fs.existsSync(synAbs)) {
    throw new Error(`同义文件不存在: ${synAbs}`);
  }

  const backendRoot = path.resolve(__dirname, '..');
  const repoRoot = path.resolve(backendRoot, '..');
  const buildScript = path.join(repoRoot, 'scripts/build-lexicon-index.mjs');
  const seedScript = path.join(backendRoot, 'scripts/seed-lexicon-from-json.js');
  const jsonOut = path.join(
    os.tmpdir(),
    `lexicon-index-${Date.now()}.json`,
  );

  console.log(`[import-lexicon] roots=${rootsAbs}`);
  console.log(`[import-lexicon] synonyms=${synAbs}`);
  console.log(
    `[import-lexicon] replace=${args.replace} dryRun=${args.dryRun}`,
  );

  run(
    'build',
    process.execPath,
    [
      buildScript,
      `--roots=${rootsAbs}`,
      `--synonyms=${synAbs}`,
      `--out=${jsonOut}`,
    ],
    { cwd: repoRoot },
  );

  if (args.dryRun) {
    console.log(`[import-lexicon] dry-run，已生成 ${jsonOut}，未写库`);
    return;
  }

  const seedArgs = [`--file=${jsonOut}`];
  if (args.replace) seedArgs.push('--replace');
  run('seed', process.execPath, [seedScript, ...seedArgs], {
    cwd: backendRoot,
  });

  try {
    fs.unlinkSync(jsonOut);
  } catch {
    /* ignore */
  }
  console.log('[import-lexicon] done → lexicon_*');
}

try {
  main();
} catch (err) {
  console.error('[import-lexicon] failed:', err.message);
  process.exit(1);
}
