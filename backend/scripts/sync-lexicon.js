/**
 * @deprecated 请改用自定义路径导入（对齐 bank）：
 *   node scripts/import-lexicon-from-md.js --roots=... --synonyms=... --replace
 */
console.error(
  '[sync-lexicon] 已改为自定义路径导入，请用:\n' +
    '  node scripts/import-lexicon-from-md.js --roots=/path/roots.md --synonyms=/path/syn.md --replace\n' +
    '  或: pnpm db:import-lexicon -- --roots=... --synonyms=... --replace',
);
process.exit(1);
