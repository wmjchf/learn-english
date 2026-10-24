const config = require('../config');

/**
 * DashScope OpenAI-compatible chat completions.
 * @param {{ messages: Array<{role:string,content:string}>, temperature?: number, maxTokens?: number, jsonMode?: boolean }} opts
 */
async function chatCompletion({
  messages,
  temperature = 0.4,
  maxTokens = 2048,
  model,
  jsonMode = false,
} = {}) {
  if (!config.llm.apiKey) {
    const err = new Error('未配置 DASHSCOPE_API_KEY');
    err.status = 500;
    err.code = 'LLM_NOT_CONFIGURED';
    throw err;
  }

  const resolvedModel = model || config.llm.model;
  const url = `${config.llm.baseUrl}/chat/completions`;
  const controller = new AbortController();
  const timeoutMs = config.llm.timeoutMs || 90000;
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  const body = {
    model: resolvedModel,
    messages,
    temperature,
    max_tokens: maxTokens,
  };

  // Qwen3 默认可能开思考链，日课成文关掉以提速
  if (config.llm.enableThinking === false) {
    body.enable_thinking = false;
  }

  if (jsonMode) {
    body.response_format = { type: 'json_object' };
  }

  const started = Date.now();
  let res;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.llm.apiKey}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timer);
    if (err?.name === 'AbortError') {
      const e = new Error('LLM 请求超时');
      e.status = 504;
      e.code = 'LLM_TIMEOUT';
      throw e;
    }
    throw err;
  }
  clearTimeout(timer);

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg =
      data?.error?.message || data?.message || `LLM HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = 502;
    err.code = 'LLM_ERROR';
    err.detail = data;
    throw err;
  }

  const content = data?.choices?.[0]?.message?.content;
  if (content == null) {
    const err = new Error('LLM 返回空内容');
    err.status = 502;
    err.code = 'LLM_EMPTY';
    err.detail = data;
    throw err;
  }

  const ms = Date.now() - started;
  const usage = data.usage || null;
  console.log(
    `[llm] ${resolvedModel} ${ms}ms` +
      (usage?.total_tokens ? ` tokens=${usage.total_tokens}` : ''),
  );

  return {
    content: String(content),
    model: data.model || resolvedModel,
    usage,
    raw: data,
    latencyMs: ms,
  };
}

/** Extract JSON object/array from model text (tolerates markdown fences). */
function parseJsonContent(content) {
  const raw = String(content || '').trim();
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const text = fenced ? fenced[1].trim() : raw;
  return JSON.parse(text);
}

module.exports = { chatCompletion, parseJsonContent };
