#!/usr/bin/env node
/**
 * DSH 大肥鱼 · 进度后端
 *
 * 实时读取 DSH 会话日志（分帧 zstd JSONL），计算当前任务进度，
 * 并原子写入 state.json 供桌面挂件轮询。
 *
 * 无第三方依赖，仅使用 Node 内置模块。
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { CONFIG_DEFAULTS, validateConfigValue } from './config-schema.mjs';

const BIN_DIR = path.dirname(fileURLToPath(import.meta.url));
const APP_DIR = path.resolve(BIN_DIR, '..');
const ZSTD_MAGIC = 0xfd2fb528;
const MAX_DECOMPRESSED = 256 * 1024 * 1024;
const ZSTD_MAGIC_BUFFER = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);

const DEFAULTS = CONFIG_DEFAULTS;

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const body = a.slice(2);
    if (body.includes('=')) {
      const eq = body.indexOf('=');
      out[body.slice(0, eq)] = body.slice(eq + 1);
      continue;
    }
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) out[body] = true;
    else {
      out[body] = next;
      i++;
    }
  }
  return out;
}

const ARGS = parseArgs(process.argv.slice(2));
if (ARGS.config === true || ARGS.state === true) {
  console.error('--config/--state 需要一个路径参数');
  process.exit(1);
}
for (const key of Object.keys(ARGS)) {
  if (key !== 'config' && key !== 'state') console.error(`warning: unknown argument --${key}`);
}
const CONFIG_PATH = ARGS.config ? path.resolve(ARGS.config) : path.join(APP_DIR, 'config.json');
const STATE_PATH = ARGS.state ? path.resolve(ARGS.state) : path.join(APP_DIR, 'state.json');
const LOG_PATH = path.join(APP_DIR, 'logs', 'core.log');

const CONFIG_WARNINGS = [];

function loadConfig() {
  let user = {};
  try {
    user = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    /* 首次运行没有配置 */
  }
  const source = user && typeof user === 'object' ? user : {};
  const numberOption = (key) => {
    const raw = source[key];
    if (raw === undefined) return DEFAULTS[key];
    const check = validateConfigValue(key, raw);
    if (!check.ok) CONFIG_WARNINGS.push(`config.${key}=${JSON.stringify(raw)} 非法，回退 ${DEFAULTS[key]}`);
    return check.value;
  };
  const cfg = {
    pollMs: numberOption('pollMs'),
    maxSessionAgeHours: numberOption('maxSessionAgeHours'),
    tailBytes: numberOption('tailBytes'),
    completionWindowMinutes: numberOption('completionWindowMinutes'),
    activeWindowMinutes: numberOption('activeWindowMinutes'),
    logMaxBytes: numberOption('logMaxBytes'),
    dshUrl: DEFAULTS.dshUrl,
  };
  if (source.dshUrl !== undefined && typeof source.dshUrl !== 'string') {
    CONFIG_WARNINGS.push('config.dshUrl 非法，回退空值');
  } else if (typeof source.dshUrl === 'string') {
    cfg.dshUrl = source.dshUrl;
  }
  if (process.env.DSH_WEB_URL) cfg.dshUrl = process.env.DSH_WEB_URL;
  else if (!cfg.dshUrl) cfg.dshUrl = 'http://127.0.0.1:11821';
  return cfg;
}

const CONFIG = loadConfig();
const DSH_HOME = process.env.DSH_HOME || path.join(os.homedir(), '.dsh');
const SESSIONS_DIR = path.join(DSH_HOME, 'sessions');

function log(message) {
  try {
    fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
    try {
      const st = fs.statSync(LOG_PATH);
      if (st.size > CONFIG.logMaxBytes) {
        const keep = fs.readFileSync(LOG_PATH, 'utf8').slice(-Math.floor(CONFIG.logMaxBytes / 2));
        fs.writeFileSync(LOG_PATH, keep);
      }
    } catch {
      /* ignore */
    }
    fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${message}\n`);
  } catch {
    /* ignore */
  }
}

for (const warning of CONFIG_WARNINGS) log(warning);

// ── zstd 分帧解析 ────────────────────────────────────────────────────────
/** 跳过一个 zstd 帧，返回帧结束偏移；帧不完整时返回 -1。 */
function skipFrame(buf, start) {
  if (start + 5 > buf.length) return -1;
  if (buf.readUInt32LE(start) !== ZSTD_MAGIC) return -1;
  const fhd = buf[start + 4];
  const fcsFlag = (fhd >> 6) & 3;
  const singleSegment = (fhd >> 5) & 1;
  const dictFlag = fhd & 3;
  let pos = start + 5;
  if (!singleSegment) pos += 1; // window descriptor
  pos += [0, 1, 2, 4][dictFlag];
  const fcsLen = fcsFlag === 0 ? (singleSegment ? 1 : 0) : [0, 2, 4, 8][fcsFlag];
  pos += fcsLen;
  if (pos > buf.length) return -1;
  for (;;) {
    if (pos + 3 > buf.length) return -1;
    const h = buf[pos] | (buf[pos + 1] << 8) | (buf[pos + 2] << 16);
    pos += 3;
    const last = h & 1;
    const type = (h >> 1) & 3;
    const size = h >>> 3;
    if (type === 3) return -1;
    if (type === 0 || type === 2) pos += size;
    else if (type === 1) pos += 1;
    if (pos > buf.length) return -1;
    if (last) break;
  }
  if ((fhd >> 2) & 1) pos += 4; // content checksum
  if (pos > buf.length) return -1;
  return pos;
}

/** 解压一段（可能是多个）zstd 帧拼接的文本。 */
function decodeZstdFrames(buf, startAt) {
  const chunks = [];
  let total = 0;
  let off = startAt;
  while (off + 4 <= buf.length) {
    if (buf.readUInt32LE(off) !== ZSTD_MAGIC) break;
    const end = skipFrame(buf, off);
    if (end < 0) break;
    let chunk;
    try {
      chunk = zlib.zstdDecompressSync(buf.subarray(off, end), { maxOutputLength: MAX_DECOMPRESSED });
    } catch (error) {
      // 帧边界已知时跳过坏帧，继续解析后续帧，避免一条坏帧永久卡死进度。
      log(`zstd 坏帧 offset=${off} end=${end}: ${error.message}`);
      off = end;
      continue;
    }
    if (total + chunk.length > MAX_DECOMPRESSED) {
      log(`zstd 解压内容超过 ${MAX_DECOMPRESSED} 字节，停止解析`);
      break;
    }
    chunks.push(chunk);
    total += chunk.length;
    off = end;
  }
  return { text: Buffer.concat(chunks).toString('utf8'), end: off };
}

/** 读取文件尾部（最多 tailBytes），在首个完整帧边界开始解析。 */
function decodeZstdChunk(file, start, end, carry, useCarry) {
  const length = end - start;
  if (length <= 0) return { events: [], carry, frameEnd: start };
  const buf = Buffer.alloc(length);
  const fd = fs.openSync(file, 'r');
  try {
    fs.readSync(fd, buf, 0, length, start);
  } finally {
    fs.closeSync(fd);
  }
  let frameStart = 0;
  if (start > 0) {
    const idx = buf.indexOf(ZSTD_MAGIC_BUFFER);
    if (idx < 0) return { events: [], carry, frameEnd: start };
    frameStart = idx;
  }
  const decoded = decodeZstdFrames(buf, frameStart);
  const text = (useCarry ? carry : '') + decoded.text;
  const lines = text.split('\n');
  const nextCarry = lines.pop() || '';
  const events = [];
  for (const line of lines) {
    if (!line) continue;
    try {
      events.push(JSON.parse(line));
    } catch {
      /* 忽略半行 */
    }
  }
  return { events, carry: nextCarry, frameEnd: start + decoded.end };
}

function readSessionEvents(file, options = {}) {
  const st = fs.statSync(file);
  if (options.from !== undefined) {
    return decodeZstdChunk(file, Math.max(0, options.from), st.size, options.carry || '', true);
  }
  const tailStart = Math.max(0, st.size - CONFIG.tailBytes);
  if (tailStart > 256 * 1024) {
    // 长会话：读取头部元数据/标题 + 尾部最近事件，避免 #39 的标题丢失。
    const head = decodeZstdChunk(file, 0, 256 * 1024, '', false);
    const tail = decodeZstdChunk(file, tailStart, st.size, '', true);
    return { events: head.events.concat(tail.events), carry: tail.carry, frameEnd: tail.frameEnd };
  }
  return decodeZstdChunk(file, 0, st.size, '', false);
}

// ── 会话模型 ────────────────────────────────────────────────────────────
function shortText(value, max = 80) {
  if (typeof value !== 'string') return '';
  const clean = value.replace(/\s+/g, ' ').trim();
  return clean.length > max ? clean.slice(0, max - 1) + '…' : clean;
}

function toolSummary(name, argsText) {
  let args = null;
  try {
    args = typeof argsText === 'string' ? JSON.parse(argsText) : argsText;
  } catch {
    /* ignore */
  }
  const pick = (v) => (typeof v === 'string' && v.trim() ? shortText(v, 64) : '');
  if (args && typeof args === 'object') {
    const candidates = [
      args.description,
      args.command,
      args.path,
      args.file_path,
      args.query,
      args.pattern,
      args.url,
      args.prompt,
    ];
    for (const c of candidates) {
      const s = pick(c);
      if (s) return s;
    }
  }
  return name ? shortText(name, 40) : '';
}

function createModel() {
  return {
    id: null,
    cwd: null,
    depth: 0,
    title: null,
    provider: null,
    llmModel: null,
    running: false,
    turn: null,
    turnStartedAt: null,
    step: 0,
    stepsThisTurn: 0,
    todos: [],
    todosAt: 0,
    lastEventAt: 0,
    lastEventType: null,
    lastTool: null,
    retrying: 0,
    goal: null,
    lastTurn: null,
    lastUserAt: 0,
    errorMessage: null,
  };
}

function applyEvent(model, o) {
  if (!o || typeof o !== 'object') return;
  const t = o.type;
    const at = typeof o.time === 'number' ? o.time : 0;
    if (at > model.lastEventAt) {
      model.lastEventAt = at;
      model.lastEventType = t;
    }
    const data = o.data && typeof o.data === 'object' ? o.data : {};

    switch (t) {
      case 'session': {
        model.id = o.id ?? data.id ?? model.id;
        model.cwd = o.cwd ?? data.cwd ?? model.cwd;
        model.depth = Number(o.delegationDepth ?? data.delegationDepth ?? 0) || 0;
        break;
      }
      case 'session/title': {
        if (data.title) model.title = data.title;
        const src = data.source && data.source.model;
        if (src && src.provider && !model.provider) model.provider = String(src.provider);
        if (src && src.model && !model.llmModel) model.llmModel = String(src.model);
        break;
      }
      case 'request/context': {
        if (data.provider) model.provider = String(data.provider);
        if (data.model) model.llmModel = String(data.model);
        break;
      }
      case 'request/header': {
        const cfg = (data.header && data.header.config) || {};
        if (cfg.provider) model.provider = String(cfg.provider);
        if (cfg.model) model.llmModel = String(cfg.model);
        break;
      }
      case 'assistant/message': {
        model.retrying = 0;
        const source = (data.message && data.message.source) || {};
        if (source.provider) model.provider = String(source.provider);
        if (source.model) model.llmModel = String(source.model);
        break;
      }
      case 'assistant/attempt': {
        model.retrying = 0;
        break;
      }
      case 'user/message': {
        model.lastUserAt = at;
        if (!model.title) {
          const content = Array.isArray(data.content) ? data.content : [];
          const text = content.map((p) => (p && typeof p.text === 'string' ? p.text : '')).join(' ');
          if (text.trim()) model.title = shortText(text, 42);
        }
        break;
      }
      case 'turn/start': {
        model.running = true;
        model.turn = data.turn ?? model.turn;
        model.turnStartedAt = at;
        model.stepsThisTurn = 0;
        model.step = 0;
        model.retrying = 0;
        model.errorMessage = null;
        model.todos = []; // 新回合开始时 todo 投影被清空
        model.todosAt = 0;
        break;
      }
      case 'step/start': {
        model.retrying = 0;
        model.step = data.step ?? model.step + 1;
        model.stepsThisTurn = Math.max(model.stepsThisTurn, model.step);
        break;
      }
      case 'tool/call': {
        model.retrying = 0;
        model.lastTool = {
          name: data.name || 'tool',
          summary: toolSummary(data.name, data.arguments),
          at,
        };
        break;
      }
      case 'llm/retry': {
        model.retrying += 1;
        break;
      }
      case 'todo/write': {
        const todos = Array.isArray(data.todos) ? data.todos : [];
        model.todos = todos
          .filter((x) => x && typeof x.content === 'string')
          .map((x) => ({ content: x.content, status: x.status }));
        model.todosAt = at;
        break;
      }
      case 'goal/change': {
        const goal = data.goal;
        if (goal && goal.phase === 'active') {
          model.goal = {
            objective: shortText(goal.objective || '', 120),
            phase: goal.phase,
            rounds: Number(data.roundsStarted ?? 0),
          };
        } else {
          model.goal = null;
        }
        break;
      }
      case 'turn/end': {
        model.running = false;
        const reason = data.reason || { kind: 'completed' };
        model.lastTurn = {
          turn: data.turn ?? model.turn,
          reason: reason.kind || 'completed',
          detail: reason.reason?.kind || reason.error?.message || null,
          endedAt: at,
          startedAt: model.turnStartedAt,
          durationMs: model.turnStartedAt ? at - model.turnStartedAt : null,
        };
        if (reason.kind === 'error') {
          model.errorMessage = shortText(reason.error?.message || '未知错误', 140);
        }
        model.retrying = 0;
        break;
      }
      default:
        break;
    }
}

function modelFromEvents(events) {
  const model = createModel();
  for (const o of events) applyEvent(model, o);
  return model;
}

function counts(todos) {
  let pending = 0;
  let inProgress = 0;
  let completed = 0;
  for (const t of todos) {
    if (t.status === 'completed') completed++;
    else if (t.status === 'in_progress') inProgress++;
    else pending++;
  }
  return { pending, inProgress, completed, total: todos.length };
}

function activityLabel(model) {
  if (!model.running) return null;
  const type = model.lastEventType;
  if (model.retrying > 0) return { kind: 'retry', text: '网络重试中…' };
  if (typeof type === 'string' && type.startsWith('job/')) {
    if (type === 'job/registered' || type === 'job/queued') return { kind: 'job', text: '后台任务排队中…' };
    if (type === 'job/started' || type === 'job/running') return { kind: 'job', text: '后台任务执行中…' };
    if (type === 'job/settled' || type === 'job/completed') return { kind: 'job', text: '后台任务已完成…' };
    if (type === 'job/failed' || type === 'job/error') return { kind: 'job', text: '后台任务失败…' };
    return { kind: 'job', text: '后台任务处理中…' };
  }
  if (type === 'tool/call') {
    return { kind: 'tool', text: `执行 ${model.lastTool?.name || '工具'}`, detail: model.lastTool?.summary || '' };
  }
  if (type === 'assistant/message' || type === 'assistant/attempt') return { kind: 'writing', text: '整理输出…' };
  if (type === 'step/start' || type === 'turn/start' || type === 'user/message') return { kind: 'thinking', text: '思考中…' };
  if (type === 'tool/result') {
    return { kind: 'tool', text: `执行 ${model.lastTool?.name || '工具'}`, detail: model.lastTool?.summary || '' };
  }
  return { kind: 'thinking', text: '思考中…' };
}

function currentTodo(model) {
  const active = model.todos.find((t) => t.status === 'in_progress');
  if (active) return active.content;
  const next = model.todos.find((t) => t.status === 'pending');
  return next ? next.content : null;
}

// ── 会话扫描 ────────────────────────────────────────────────────────────
const cache = new Map();
// 全局上限要足够大，避免 40 条子代理日志把主会话挤出候选；
// 同时按 workspace 限流，防止单个工作区独占候选列表。
const MAX_SESSION_FILES = 200;
const MAX_SESSION_FILES_PER_WORKSPACE = 50;

let sessionFilesCache = { at: 0, files: [] };

function listSessionFiles() {
  if (sessionFilesCache.at && Date.now() - sessionFilesCache.at < 5000) return sessionFilesCache.files;
  const files = [];
  let workspaces;
  try {
    workspaces = fs.readdirSync(SESSIONS_DIR, { withFileTypes: true });
  } catch {
    return files;
  }
  const cutoff = Date.now() - CONFIG.maxSessionAgeHours * 3600 * 1000;
  for (const ws of workspaces) {
    if (!ws.isDirectory()) continue;
    const wsDir = path.join(SESSIONS_DIR, ws.name);
    let sessions;
    try {
      sessions = fs.readdirSync(wsDir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const s of sessions) {
      if (!s.isDirectory()) continue;
      const file = path.join(wsDir, s.name, 'session.v4.jsonl.zstd');
      try {
        const st = fs.statSync(file);
        if (st.mtimeMs < cutoff) continue;
        files.push({ file, mtimeMs: st.mtimeMs, size: st.size });
      } catch {
        /* ignore */
      }
    }
  }
  const byWorkspace = new Map();
  for (const f of files) {
    const ws = path.dirname(path.dirname(f.file));
    if (!byWorkspace.has(ws)) byWorkspace.set(ws, []);
    byWorkspace.get(ws).push(f);
  }
  const selected = [];
  for (const list of byWorkspace.values()) {
    list.sort((a, b) => b.mtimeMs - a.mtimeMs);
    selected.push(...list.slice(0, MAX_SESSION_FILES_PER_WORKSPACE));
  }
  selected.sort((a, b) => b.mtimeMs - a.mtimeMs);
  const result = selected.slice(0, MAX_SESSION_FILES);
  sessionFilesCache = { at: Date.now(), files: result };
  return result;
}

function loadModel(file, mtimeMs, size) {
  const hit = cache.get(file);
  if (hit && hit.mtimeMs === mtimeMs && hit.size === size) return hit.model;
  if (hit && hit.frameEnd > 0 && hit.frameEnd <= size) {
    try {
      const delta = readSessionEvents(file, { from: hit.frameEnd, carry: hit.carry });
      for (const o of delta.events) applyEvent(hit.model, o);
      cache.set(file, { mtimeMs, size, model: hit.model, carry: delta.carry, frameEnd: delta.frameEnd });
      return hit.model;
    } catch {
      /* 回退到全量读取 */
    }
  }
  const full = readSessionEvents(file);
  const model = modelFromEvents(full.events);
  if (!model.id) model.id = path.basename(path.dirname(file));
  cache.set(file, { mtimeMs, size, model, carry: full.carry, frameEnd: full.frameEnd });
  return model;
}

function buildState(now) {
  const files = listSessionFiles();
  const seen = new Set();
  const models = [];
  for (const f of files) {
    seen.add(f.file);
    try {
      models.push(loadModel(f.file, f.mtimeMs, f.size));
    } catch (error) {
      log(`读取会话失败 ${f.file}: ${error.message}`);
    }
  }
  for (const key of cache.keys()) if (!seen.has(key)) cache.delete(key);

  const mains = models.filter((m) => (CONFIG.includeSubagents ? true : m.depth === 0));
  const activeWindow = CONFIG.activeWindowMinutes * 60 * 1000;
  const recent = mains.filter((m) => m.lastEventAt && now - m.lastEventAt < activeWindow);

  // running 必须从全部 mains 中筛，activeWindow 只用于展示排序；
  // 否则长时间无事件但仍在运行的任务会被误判为 idle。
  const running = mains.filter((m) => m.running).sort((a, b) => b.lastEventAt - a.lastEventAt);
  const primary = running[0] || recent.sort((a, b) => b.lastEventAt - a.lastEventAt)[0] || null;

  // 最近一次“完成”的回合（用于提醒）
  const completionWindow = CONFIG.completionWindowMinutes * 60 * 1000;
  const completions = [];
  for (const m of recent) {
    const last = m.lastTurn;
    if (!last || !last.endedAt) continue;
    if (now - last.endedAt > completionWindow) continue;
    if (!['completed', 'aborted', 'error', 'interrupted'].includes(last.reason)) continue;
    completions.push({
      id: `${m.id}:${last.turn}:${last.endedAt}`,
      at: last.endedAt,
      title: shortText(m.title || '当前任务', 100),
      reason: last.reason,
      durationMs: last.durationMs,
      sessionId: m.id,
      turn: last.turn,
    });
  }
  completions.sort((a, b) => b.at - a.at);
  const completion = completions[0] || null;

  const phase = !primary ? 'idle' : primary.running ? 'working' : 'done';

  const viewOf = (m) => {
    const c = counts(m.todos);
    const todoProgress = c.total > 0 ? { ...c, current: currentTodo(m) } : null;
    return {
      id: m.id,
      title: m.title || '新的任务',
      provider: m.provider || '',
      llmModel: m.llmModel || '',
      cwd: m.cwd || '',
      running: m.running,
      turn: m.turn,
      turnStartedAt: m.turnStartedAt,
      lastEventAt: m.lastEventAt,
      lastEventType: m.lastEventType,
      activity: activityLabel(m),
      step: m.step,
      steps: m.stepsThisTurn,
      goal: m.goal,
      todos: m.todos,
      progress: todoProgress,
      lastTurn: m.lastTurn,
      errorMessage: m.errorMessage,
      depth: m.depth,
    };
  };

  let ordered = recent
    .slice()
    .sort((a, b) => Number(b.running) - Number(a.running) || b.lastEventAt - a.lastEventAt);
  try {
    const ui = JSON.parse(fs.readFileSync(path.join(APP_DIR, 'ui.json'), 'utf8'));
    if (ui && ui.pinned) {
      const pinnedModel = models.find((m) => m.id === ui.pinned);
      if (pinnedModel && !ordered.some((m) => m.id === pinnedModel.id)) ordered = [pinnedModel, ...ordered];
    }
  } catch {
    /* ignore */
  }

  const state = {
    v: 1,
    now,
    phase,
    dshUrl: CONFIG.dshUrl,
    activeSessions: running.length,
    session: primary === null ? null : viewOf(primary),
    completion,
    completions: completions.slice(0, 8),
    sessions: ordered.slice(0, 6).map(viewOf),
  };
  return state;
}

// ── 主循环 ──────────────────────────────────────────────────────────────
let lastSerialized = '';
let writeFailures = 0;
let lastWriteAt = 0;

function writeState(state) {
  const text = JSON.stringify(state);
  const signature = JSON.stringify({ ...state, now: 0 });
  const nowMs = Date.now();
  // 状态没变时最多每 15 秒写一次心跳，避免 widget 把空闲误判为 stale。
  if (signature === lastSerialized && nowMs - lastWriteAt < 15000) return;
  if (Buffer.byteLength(text, 'utf8') > 512 * 1024) {
    log('state.json 超过 512KB，跳过本次写入');
    return;
  }
  const tmp = `${STATE_PATH}.tmp.${process.pid}`;
  try {
    fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
    fs.writeFileSync(tmp, text, 'utf8');
    try {
      fs.renameSync(tmp, STATE_PATH);
    } catch {
      fs.writeFileSync(STATE_PATH, text, 'utf8');
      try {
        fs.unlinkSync(tmp);
      } catch {
        /* ignore */
      }
    }
    lastSerialized = signature;
    lastWriteAt = nowMs;
    writeFailures = 0;
  } catch (error) {
    writeFailures += 1;
    if (writeFailures === 1 || writeFailures % 60 === 0) log(`写入 state.json 失败: ${error.message}`);
  }
}

function tick() {
  try {
    const state = buildState(Date.now());
    writeState(state);
  } catch (error) {
    log(`tick 失败: ${error.stack || error.message}`);
  }
}

if (process.env.DSH_FISH_TEST !== '1') {
try {
  fs.writeFileSync(path.join(APP_DIR, 'core.pid'), String(process.pid));
} catch {
  /* ignore */
}
log(`启动 fish-core pid=${process.pid} home=${DSH_HOME}`);
tick();
const timer = setInterval(tick, Math.max(200, Number(CONFIG.pollMs) || 600));
function shutdown() {
  clearInterval(timer);
  try {
    fs.rmSync(path.join(APP_DIR, 'core.pid'), { force: true });
  } catch {
    /* ignore */
  }
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
process.on('exit', () => {
  try {
    fs.rmSync(path.join(APP_DIR, 'core.pid'), { force: true });
  } catch {
    /* ignore */
  }
});
process.on('SIGINT', () => {
  clearInterval(timer);
  process.exit(0);
});
}

export { modelFromEvents, applyEvent, activityLabel, shortText };
