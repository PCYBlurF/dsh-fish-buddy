#!/usr/bin/env node
/**
 * DSH 大肥鱼 · doctor
 * 检查运行环境、DSH 会话、凭据、后端状态和 macOS 安装。
 * 不输出任何密钥内容。
 *
 * 用法：
 *   node bin/doctor.mjs             只打印
 *   node bin/doctor.mjs --report    同时写 logs/doctor-*.txt
 *   node bin/doctor.mjs --bundle    写报告并打包 logs/dsh-fish-diagnostic-*.zip
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DSH_HOME = process.env.DSH_HOME || path.join(os.homedir(), '.dsh');
const require = createRequire(import.meta.url);
const { isAllowedDshUrl } = require(path.join(ROOT, 'bin', 'url-allowlist.cjs'));
const args = new Set(process.argv.slice(2));
const results = [];
let failed = 0;

function add(name, ok, detail, critical = false) {
  results.push({ name, ok, detail });
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
let credentialText = '';
const credentialFile = path.join(DSH_HOME, '.credentials.yaml');
try {
  credentialText = fs.readFileSync(credentialFile, 'utf8');
  credentialKey = /^\s*DEEPSEEK_API_KEY:\s*\S+/m.test(credentialText);
  add('DSH 凭据', true, credentialFile);
} catch {
  add('DSH 凭据', false, `未找到 ${credentialFile}`);
}
add('DEEPSEEK_API_KEY', credentialKey, credentialKey ? '已配置（余额可查）' : '未配置（余额会提示未找到）');
for (const key of ['OPENROUTER_API_KEY', 'MOONSHOT_API_KEY', 'KIMI_API_KEY']) {
  const found = new RegExp('^\\s*' + key + ':\\s*\\S+', 'm').test(credentialText);
  add(key, true, found ? '已配置' : '未配置');
}

function countFishCores() {
  try {
    if (process.platform === 'win32') {
      const out = execFileSync('powershell.exe', ['-NoProfile', '-Command', "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like '*fish-core.mjs*' } | Measure-Object | Select-Object -ExpandProperty Count"], { encoding: 'utf8', timeout: 8000 });
      return Number(String(out).trim()) || 0;
    }
    const out = execFileSync('ps', ['-axo', 'command'], { encoding: 'utf8', timeout: 8000 });
    return out.split('\n').filter((line) => line.includes('fish-core.mjs')).length;
  } catch {
    return -1;
  }
}

const stateFile = path.join(ROOT, 'state.json');
try {
  const stat = fs.statSync(stateFile);
  const age = (Date.now() - stat.mtimeMs) / 1000;
  add('state.json', age < 120, `${age.toFixed(1)} 秒前更新`);
} catch {
  add('state.json', false, '还未生成');
}
try {
  const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
  if (state.dshUrl) add('state.dshUrl', isAllowedDshUrl(state.dshUrl), String(state.dshUrl));
} catch { /* ignore */ }

try {
  const pid = parseInt(fs.readFileSync(path.join(ROOT, 'core.pid'), 'utf8'), 10);
  let alive = false;
  try { process.kill(pid, 0); alive = true; } catch { /* dead */ }
  add('fish-core', alive, `pid=${pid} ${alive ? '运行中' : '未运行'}`);
} catch {
  add('fish-core', false, '没有 core.pid');
}
const coreCount = countFishCores();
add('fish-core 实例', coreCount <= 1, coreCount < 0 ? '无法统计' : `${coreCount} 个`, coreCount > 1);

const configFile = path.join(ROOT, 'config.json');
if (!fs.existsSync(configFile)) {
  add('配置文件', false, configFile);
} else {
  try {
    const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
    add('配置文件', true, configFile);
    const known = new Set(['mascot', 'scale', 'pollMs', 'completionWindowMinutes', 'activeWindowMinutes', 'includeSubagents', 'maxSessionAgeHours', 'dshUrl', 'notify', 'sound', 'tray', 'compact']);
    const unknown = Object.keys(config).filter((key) => !known.has(key));
    add('配置键', unknown.length === 0, unknown.length ? `未知键: ${unknown.join(', ')}` : '无未知键');
    if (config.scale !== undefined) {
      const scale = Number(config.scale);
      add('config.scale', Number.isFinite(scale) && scale >= 0.7 && scale <= 1.4, String(config.scale));
    }
    if (config.dshUrl) add('config.dshUrl', isAllowedDshUrl(config.dshUrl), String(config.dshUrl));
  } catch (error) {
    add('配置文件', false, `解析失败: ${error.message}`);
  }
}

if (process.platform === 'darwin') {
  const electron = path.join(ROOT, 'mac', 'node_modules', 'electron');
  add('Electron 依赖', fs.existsSync(electron), electron);
  const app = path.join(ROOT, 'mac', 'node_modules', 'electron', 'dist');
  add('Electron.app', fs.existsSync(app), app);
  add('菜单栏图标', fs.existsSync(path.join(ROOT, 'mac', 'trayTemplate.png')), 'mac/trayTemplate.png');
  add('ui-mac.json', fs.existsSync(path.join(ROOT, 'mac', 'ui-mac.json')), '窗口位置/材质设置');
}

const lines = [
  'DSH 大肥鱼 · doctor',
  `platform: ${process.platform} · arch: ${process.arch} · root: ${ROOT}`,
  `time: ${new Date().toISOString()}`,
  '',
];
for (const item of results) {
  lines.push(`${item.ok ? 'OK  ' : 'FAIL'}  ${item.name}: ${item.detail}`);
}
lines.push('', failed === 0 ? '结果: OK' : `结果: ${failed} 个关键项失败`);
console.log(lines.join('\n'));

function diagnosticFiles(reportFile) {
  const files = [reportFile];
  for (const name of ['state.json', 'config.json']) {
    const file = path.join(ROOT, name);
    if (fs.existsSync(file)) files.push(file);
  }
  const ui = path.join(ROOT, 'mac', 'ui-mac.json');
  if (fs.existsSync(ui)) files.push(ui);
  const logsDir = path.join(ROOT, 'logs');
  try {
    for (const name of fs.readdirSync(logsDir)) {
      if (name.endsWith('.log')) files.push(path.join(logsDir, name));
    }
  } catch { /* ignore */ }
  return files;
}

function createBundle(reportFile, stamp) {
  const zipFile = path.join(ROOT, 'logs', `dsh-fish-diagnostic-${stamp}.zip`);
  const files = diagnosticFiles(reportFile);
  try {
    if (process.platform === 'win32') {
      const list = files.map((file) => `'${file.replace(/'/g, "''")}'`).join(',');
      const destination = zipFile.replace(/'/g, "''");
      execFileSync('powershell.exe', [
        '-NoProfile',
        '-Command',
        `Compress-Archive -LiteralPath @(${list}) -DestinationPath '${destination}' -Force`,
      ], { stdio: 'ignore' });
    } else {
      execFileSync('zip', ['-j', zipFile, ...files], { stdio: 'ignore' });
    }
    console.log(`诊断包: ${zipFile}`);
  } catch {
    console.log(`诊断包打包失败，可手动收集：${reportFile}`);
  }
}

if (args.has('--report') || args.has('--bundle')) {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const logsDir = path.join(ROOT, 'logs');
  fs.mkdirSync(logsDir, { recursive: true });
  const reportFile = path.join(logsDir, `doctor-${stamp}.txt`);
  try {
    fs.writeFileSync(reportFile, `${lines.join('\n')}\n`);
    console.log(`诊断报告: ${reportFile}`);
    if (args.has('--bundle')) createBundle(reportFile, stamp);
  } catch (error) {
    console.log(`诊断报告写入失败: ${error.message}`);
  }
}

process.exit(failed === 0 ? 0 : 1);
