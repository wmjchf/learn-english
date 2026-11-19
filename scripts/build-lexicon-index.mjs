#!/usr/bin/env node
/**
 * 从词根词缀全库 + 同形同义汇总生成 App 可查 JSON。
 * 用法：node scripts/build-lexicon-index.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const attachDir = path.resolve(
  process.env.HOME,
  '.cursor/projects/Users-douge-Desktop-workspace-english-learn/attachments/d461cf73-ae57-4959-82df-b5281fecb536',
);

const rootMd = path.join(attachDir, '_________A-Z.md');
const synMd = path.join(attachDir, '_________.md');
const outPath = path.join(root, 'app/assets/lexicon/lemma_index.json');

function cleanLemma(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[*`]/g, '')
    .replace(/\([^)]*\)/g, '')
    .split(/[/,、]/)[0]
    .trim()
    .replace(/[^a-z'-]/g, '');
}

function ensureLemma(map, lemma) {
  if (!lemma) return null;
  if (!map[lemma]) {
    map[lemma] = {
      breakdown: '',
      gloss: '',
      rootId: '',
      synonyms: [],
      confusables: [],
      senses: [],
    };
  }
  return map[lemma];
}

function addSynonym(map, lemma, other, zh = '') {
  if (!lemma || !other || lemma === other) return;
  const entry = ensureLemma(map, lemma);
  if (!entry.synonyms.some((s) => s.w === other)) {
    entry.synonyms.push({ w: other, zh });
  }
  entry.synonyms = entry.synonyms.slice(0, 8);
}

/** 把 A→B 的近义补成双向，避免只挂在头词上 */
function reverseSynonyms(map) {
  const snapshot = Object.entries(map).map(([k, v]) => [
    k,
    v.synonyms.map((s) => ({ ...s })),
  ]);
  for (const [lemma, syns] of snapshot) {
    for (const s of syns) {
      addSynonym(map, s.w, lemma, s.zh);
    }
  }
}

function parseRoots(md) {
  const roots = {};
  const lemmas = {};
  const lines = md.split(/\r?\n/);
  let cur = null;

  const headRe = /^###\s+(\d+)\s*·\s*(.+?)\s*——\s*[「"](.+?)[」"]\s*$/;
  const rowRe = /^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|$/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const hm = headRe.exec(line.trim());
    if (hm) {
      const id = `r${hm[1].padStart(3, '0')}`;
      const key = hm[2].trim();
      const meaning = hm[3].trim();
      let etym = '';
      const next = lines[i + 1] || '';
      if (next.startsWith('*') && next.endsWith('*')) {
        etym = next.replace(/^\*|\*$/g, '').trim();
      }
      cur = { id, key, meaning, etym, family: [] };
      roots[id] = cur;
      continue;
    }
    if (!cur) continue;
    if (line.startsWith('### ')) {
      cur = null;
      continue;
    }
    const rm = rowRe.exec(line.trim());
    if (!rm) continue;
    const w = rm[1].trim();
    if (w === '单词' || w.startsWith('---') || w.includes('---')) continue;
    const lemma = cleanLemma(w);
    if (!lemma) continue;
    const breakdown = rm[2].trim();
    const gloss = rm[3].trim();
    cur.family.push({ w: lemma, b: breakdown, g: gloss });
    const entry = ensureLemma(lemmas, lemma);
    entry.breakdown = breakdown;
    entry.gloss = gloss;
    entry.rootId = cur.id;
  }
  return { roots, lemmas };
}

function parseSynonyms(md, lemmas) {
  const lines = md.split(/\r?\n/);
  let section = ''; // syn | poly | near | nearAdv
  const synHead = /^##\s*第一部分/;
  const polyHead = /^##\s*第二部分/;
  const nearHead = /^##\s*第三部分/;
  const examHead = /^##\s*第四部分/;
  const nearAdv = /高级形近|形近\s*\/\s*易混/;

  const rowRe = /^\|\s*(.+?)\s*\|$/;

  for (const raw of lines) {
    const line = raw.trim();
    if (synHead.test(line)) {
      section = 'syn';
      continue;
    }
    if (polyHead.test(line)) {
      section = 'poly';
      continue;
    }
    if (nearHead.test(line)) {
      section = 'near';
      continue;
    }
    if (examHead.test(line)) {
      section = 'exam';
      continue;
    }
    if (nearAdv.test(line)) {
      section = 'nearAdv';
      continue;
    }
    if (line.startsWith('## ')) {
      section = '';
      continue;
    }
    if (!line.startsWith('|')) continue;
    if (line.includes('---')) continue;

    const cells = line
      .replace(/^\|/, '')
      .replace(/\|$/, '')
      .split('|')
      .map((c) => c.trim());
    if (cells.length < 2) continue;
    if (/^(中文|单词|形近词组|英文)/.test(cells[0].replace(/\*/g, ''))) continue;

    if (section === 'syn' && cells.length >= 2) {
      const zh = cells[0].replace(/\*/g, '').trim();
      const engs = cells[1]
        .split(/[,，]/)
        .map((s) => cleanLemma(s))
        .filter(Boolean);
      if (engs.length < 2) continue;
      for (const e of engs) {
        for (const o of engs) {
          if (e !== o) addSynonym(lemmas, e, o, zh);
        }
      }
    }

    if (section === 'poly' && cells.length >= 2) {
      const lemma = cleanLemma(cells[0]);
      if (!lemma) continue;
      const senses = cells
        .slice(1)
        .map((c) => c.replace(/\*/g, '').trim())
        .filter((c) => c && c !== '—' && c !== '-');
      if (senses.length < 2) continue;
      const entry = ensureLemma(lemmas, lemma);
      entry.senses = senses.slice(0, 4);
    }

    // 形近：| **a / b** | ... | 区别说明 |
    if (
      (section === 'near' || section === 'nearAdv' || section === 'exam') &&
      cells[0].includes('/')
    ) {
      const left = cells[0].replace(/\*/g, '').trim();
      const note = cells[cells.length - 1].replace(/\*/g, '').trim();
      const parts = left
        .split(/\s*\/\s*/)
        .map((p) => cleanLemma(p))
        .filter(Boolean);
      if (parts.length >= 2 && note && note !== '—') {
        for (const e of parts) {
          const entry = ensureLemma(lemmas, e);
          const others = parts.filter((x) => x !== e);
          const item = { words: others, note };
          if (!entry.confusables.some((c) => c.note === note)) {
            entry.confusables.push(item);
          }
          entry.confusables = entry.confusables.slice(0, 4);
        }
        continue;
      }
    }

    // 等价近义：| word | 中文 | a, b, c |（第一部分之外的表也收）
    if (
      cells.length >= 3 &&
      !cells[0].includes('/') &&
      /[a-zA-Z]/.test(cells[2]) &&
      (section === 'exam' || section === 'nearAdv' || section === 'syn')
    ) {
      const lemma = cleanLemma(cells[0]);
      if (!lemma) continue;
      const zh = cells[1].replace(/\*/g, '').trim();
      if (/^(中文|含义)/.test(zh)) continue;
      const others = cells[2]
        .split(/[,，]/)
        .map((s) => cleanLemma(s))
        .filter(Boolean)
        .slice(0, 6);
      if (!others.length) continue;
      for (const o of others) {
        addSynonym(lemmas, lemma, o, zh);
        addSynonym(lemmas, o, lemma, zh);
      }
    }
  }
}

function compactLemmas(lemmas) {
  const out = {};
  for (const [k, v] of Object.entries(lemmas)) {
    const o = {};
    if (v.breakdown) o.b = v.breakdown;
    if (v.gloss) o.g = v.gloss;
    if (v.rootId) o.r = v.rootId;
    if (v.synonyms?.length) {
      o.s = v.synonyms.map((x) => (x.zh ? [x.w, x.zh] : [x.w]));
    }
    if (v.confusables?.length) {
      o.c = v.confusables.map((x) => [x.words, x.note]);
    }
    if (v.senses?.length) o.m = v.senses;
    if (Object.keys(o).length) out[k] = o;
  }
  return out;
}

function compactRoots(roots) {
  const out = {};
  for (const [id, r] of Object.entries(roots)) {
    out[id] = {
      k: r.key,
      m: r.meaning,
      e: r.etym || '',
      f: r.family.slice(0, 16).map((x) => [x.w, x.b, x.g]),
    };
  }
  return out;
}

if (!fs.existsSync(rootMd) || !fs.existsSync(synMd)) {
  console.error('找不到源 Markdown，请确认 attachments 路径');
  process.exit(1);
}

const rootText = fs.readFileSync(rootMd, 'utf8');
const synText = fs.readFileSync(synMd, 'utf8');
const { roots, lemmas } = parseRoots(rootText);
parseSynonyms(synText, lemmas);
reverseSynonyms(lemmas);

const payload = {
  v: 1,
  roots: compactRoots(roots),
  lemmas: compactLemmas(lemmas),
};

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(payload));
const sizeKb = Math.round(fs.statSync(outPath).size / 1024);
console.log(
  `wrote ${outPath} (${sizeKb} KB) roots=${Object.keys(payload.roots).length} lemmas=${Object.keys(payload.lemmas).length}`,
);
console.log('sample comprehensive:', JSON.stringify(payload.lemmas.comprehensive, null, 2));
