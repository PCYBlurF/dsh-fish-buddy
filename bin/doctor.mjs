#!/usr/bin/env node
/**
 * DSH 大肥鱼 · doctor
 * 检查运行环境、DSH 会话、凭据、后端状态和 macOS 安装。
 * 不输出任何密钥内容。
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DSH_HOME = process.env.DSH_HOME || path.join(os.homedir(), '.dsh');
const results = [];
let failed = 0;

function add(name, ok, detail, critical = false) {
  results.push({ name, ok, detail, critical });
  if (critical && !ok) failed += 1;
}

function versionAtLeast(version, major, minor) {
  const parts = String(version).split('.').map(Number);
  return (parts[0] || 0) > major || ((parts[0] || 0) === major && (parts[1] || 0) >= minor);
}

function newestSession() {
  let newest = null;
  try {
    for (const ws of fs.readdirSync(path.join(DSH_HOME, 'sessions'), { withFileTypes: true })) {
      if (!ws.isDirectory()) continue;
      const wsDir = path.join(DSH_HOME, 'sessions', ws.name);
      for (const s of fs.readdirSync(wsDir, { withFileTypes: true })) {
        if (!s.isDirectory()) continue;
        const file = path.join(wsDir, s.name, 'session.v4.jsonl.zstd');
        try {
          const stat = fs.statSync(file);
          if (!newest || stat.mtimeMs > newest.mtimeMs) newest = { file, mtimeMs: stat.mtimeMs };
        } catch { /* ignore */ }
      }
    }
  } catch { /* ignore */ }
  return newest;
}

const nodeVersion = process.versions.node;
add('Node.js', versionAtLeast(nodeVersion, 22, 15), `v${nodeVersion}（需要 22.15+）`, true);
add('zstd 解码', typeof zlib.zstdDecompressSync === 'function', 'zlib.zstdDecompressSync', true);

add('DSH_HOME', fs.existsSync(DSH_HOME), DSH_HOME, true);
const sessionsDir = path.join(DSH_HOME, 'sessions');
let sessionCount = 0;
try {
  for (const ws of fs.readdirSync(sessionsDir, { withFileTypes: true })) {
    if (!ws.isDirectory()) continue;
    try {
      sessionCount += fs.readdirSync(path.join(sessionsDir, ws.name), { withFileTypes: true }).filter((s) => s.isDirectory()).length;
    } catch { /* ignore */ }
  }
} catch { /* ignore */ }
add('DSH 会话', sessionCount > 0, `${sessionCount} 个会话目录`, true);
const newest = newestSession();
add('最近会话', Boolean(newest), newest ? `${new Date(newest.mtimeMs).toLocaleString()} · ${path.basename(path.dirname(newest.file))}` : '没有找到 session.v4.jsonl.zstd');

let credentialKey = false;
const credentialFile = path.join(DSH_HOME, '.credentials.yaml');
try {
  const text = fs.readFileSync(credentialFile, 'utf8');
  credentialKey = /^\s*DEEPSEEK_API_KEY:\s*\S+/m.test(text);
  add('DSH 凭据', true, credentialFile);
} catch {
  add('DSH 凭据', false, `未找到 ${credentialFile}`);
}
add('DEEPSEEK_API_KEY', credentialKey, credentialKey ? '已配置（余额可查）' : '未配置（余额会提示未找到）');

const stateFile = path.join(ROOT, 'state.json');
try {
  const stat = fs.statSync(stateFile);
  const age = (Date.now() - stat.mtimeMs) / 1000;
  add('state.json', age < 120, `${age.toFixed(1)} 秒前更新`);
} catch {
  add('state.json', false, '还未生成');
}

try {
  const pid = parseInt(fs.readFileSync(path.join(ROOT, 'core.pid'), 'utf8'), 10);
  let alive = false;
  try { process.kill(pid, 0); alive = true; } catch { /* dead */ }
  add('fish-core', alive, `pid=${pid} ${alive ? '运行中' : '未运行'}`);
} catch {
  add('fish-core', false, '没有 core.pid');
}

add('配置文件', fs.existsSync(path.join(ROOT, 'config.json')), path.join(ROOT, 'config.json'));

if (process.platform === 'darwin') {
  const electron = path.join(ROOT, 'mac', 'node_modules', 'electron');
  add('Electron 依赖', fs.existsSync(electron), electron);
  const app = path.join(ROOT, 'mac', 'node_modules', 'electron', 'dist');
  add('Electron.app', fs.existsSync(app), app);
  add('菜单栏图标', fs.existsSync(path.join(ROOT, 'mac', 'trayTemplate.png')), 'mac/trayTemplate.png');
  add('ui-mac.json', fs.existsSync(path.join(ROOT, 'mac', 'ui-mac.json')), '窗口位置/材质设置');
}

console.log('DSH 大肥鱼 · doctor');
console.log(`platform: ${process.platform} · root: ${ROOT}`);
console.log('');
for (const item of results) {
  console.log(`${item.ok ? 'OK  ' : 'FAIL'}  ${item.name}: ${item.detail}`);
}
console.log('');
console.log(failed === 0 ? '结果: OK' : `结果: ${failed} 个关键项失败`);
process.exit(failed === 0 ? 0 : 1);
