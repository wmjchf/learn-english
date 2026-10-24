const crypto = require('crypto');
const config = require('../config');

/** @type {Map<string, { urls: string[], expiresAt: number, voice: string, model: string }>} */
const cache = new Map();

const MAX_CHARS = 520; // qwen3-tts-flash 上限 600，留余量

function hashKey(text, voice, languageType) {
  return crypto
    .createHash('sha1')
    .update(`${voice}|${languageType}|${text}`)
    .digest('hex');
}

/**
 * 按句号/空格切分，单片不超过 MAX_CHARS。
 */
function chunkText(raw) {
  const text = String(raw || '').replace(/\s+/g, ' ').trim();
  if (!text) return [];
  if (text.length <= MAX_CHARS) return [text];

  const parts = [];
  let buf = '';
  const sentences = text.split(/(?<=[.!?。！？])\s+|\n+/);
  for (const s of sentences) {
    const piece = s.trim();
    if (!piece) continue;
    if (piece.length > MAX_CHARS) {
      if (buf) {
        parts.push(buf);
        buf = '';
      }
      for (let i = 0; i < piece.length; i += MAX_CHARS) {
        parts.push(piece.slice(i, i + MAX_CHARS));
      }
      continue;
    }
    if (!buf) {
      buf = piece;
    } else if (`${buf} ${piece}`.length <= MAX_CHARS) {
      buf = `${buf} ${piece}`;
    } else {
      parts.push(buf);
      buf = piece;
    }
  }
  if (buf) parts.push(buf);
  return parts;
}

function httpsUrl(url) {
  if (!url) return url;
  return String(url).replace(/^http:\/\//i, 'https://');
}

async function synthesizeOne(text, { voice, languageType, model }) {
  const url =
    'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60000);
  let res;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.llm.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        input: {
          text,
          voice,
          language_type: languageType,
        },
      }),
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timer);
    if (err?.name === 'AbortError') {
      const e = new Error('语音合成超时');
      e.status = 504;
      e.code = 'TTS_TIMEOUT';
      throw e;
    }
    throw err;
  }
  clearTimeout(timer);

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg =
      data?.message || data?.error?.message || `TTS HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = 502;
    err.code = 'TTS_ERROR';
    err.detail = data;
    throw err;
  }

  const audioUrl = httpsUrl(data?.output?.audio?.url);
  if (!audioUrl) {
    const err = new Error('语音合成未返回音频');
    err.status = 502;
    err.code = 'TTS_EMPTY';
    throw err;
  }

  const expiresAt = Number(data?.output?.audio?.expires_at) || 0;
  return { url: audioUrl, expiresAt };
}

/**
 * @param {string} text
 * @param {{ languageType?: string, voice?: string }} [opts]
 */
async function synthesize(text, opts = {}) {
  if (!config.llm.apiKey) {
    const err = new Error('未配置 DASHSCOPE_API_KEY');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }

  const voice = opts.voice || config.tts?.voice || 'Cherry';
  const languageType =
    opts.languageType || config.tts?.languageType || 'English';
  const model = config.tts?.model || 'qwen3-tts-flash';

  const normalized = String(text || '').replace(/\s+/g, ' ').trim();
  if (!normalized) {
    const err = new Error('请提供朗读文本');
    err.status = 400;
    throw err;
  }
  if (normalized.length > 12000) {
    const err = new Error('文本过长，请缩短后再试');
    err.status = 400;
    throw err;
  }

  const key = hashKey(normalized, voice, languageType);
  const hit = cache.get(key);
  const nowSec = Math.floor(Date.now() / 1000);
  if (hit && hit.expiresAt > nowSec + 60) {
    return {
      urls: hit.urls,
      voice: hit.voice,
      model: hit.model,
      cached: true,
      expiresAt: hit.expiresAt,
    };
  }

  const chunks = chunkText(normalized);
  const urls = [];
  let minExp = Number.MAX_SAFE_INTEGER;
  for (const chunk of chunks) {
    const { url, expiresAt } = await synthesizeOne(chunk, {
      voice,
      languageType,
      model,
    });
    urls.push(url);
    if (expiresAt > 0) minExp = Math.min(minExp, expiresAt);
  }

  const expiresAt =
    minExp === Number.MAX_SAFE_INTEGER ? nowSec + 3600 : minExp;
  cache.set(key, { urls, expiresAt, voice, model });

  // 简单防涨：超过 200 条清一半最旧的（Map 插入序）
  if (cache.size > 200) {
    let i = 0;
    for (const k of cache.keys()) {
      cache.delete(k);
      if (++i >= 100) break;
    }
  }

  return { urls, voice, model, cached: false, expiresAt };
}

module.exports = { synthesize, chunkText };
