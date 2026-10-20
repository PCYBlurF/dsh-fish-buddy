const { app, BrowserWindow, ipcMain, Menu, shell, screen, Tray, nativeImage } = require('electron');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const MAC = __dirname;
const ROOT = path.resolve(MAC, '..');
const STATE = path.join(ROOT, 'state.json');
const UI = path.join(MAC, 'ui-mac.json');
const CORE = path.join(ROOT, 'bin', 'fish-core.mjs');
const CONFIG = path.join(ROOT, 'config.json');
const README = path.join(MAC, 'README.md');
const W = 360;
const H = 430;

let win = null;
let tray = null;
let coreProc = null;
let drag = null;
let lastState = null;
let saveTimer = null;
let pollTimer = null;

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; }
}
function writeJson(file, value) {
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(value, null, 2));
  } catch (error) {
    console.error('write', file, error);
  }
}

let ui = readJson(UI, { left: null, top: null, material: 'white', scale: 0.9 });
if (!ui || typeof ui !== 'object') ui = { left: null, top: null, material: 'white', scale: 0.9 };
if (!['default', 'white', 'glass'].includes(ui.material)) ui.material = 'white';
if (typeof ui.scale !== 'number') ui.scale = 0.9;
function saveUi() { writeJson(UI, ui); }

function resolveNode() {
  const candidates = [
    process.env.DSH_NODE,
    path.join(os.homedir(), '.dsh', 'dsh-runtimes', 'dsh-primary-runtime', 'dependencies', 'node', 'bin', 'node'),
    '/opt/homebrew/bin/node',
    '/usr/local/bin/node',
  ];
  for (const candidate of candidates) {
    if (candidate && fs.existsSync(candidate)) return candidate;
  }
  return process.execPath;
}

function startCore() {
  try {
    const pidFile = path.join(ROOT, 'core.pid');
    const pid = parseInt(fs.readFileSync(pidFile, 'utf8'), 10);
    if (pid) {
      try { process.kill(pid, 0); return; } catch { /* stale */ }
    }
  } catch { /* no pid */ }
  const node = resolveNode();
  const env = { ...process.env };
  if (node === process.execPath) env.ELECTRON_RUN_AS_NODE = '1';
  try {
    coreProc = spawn(node, [CORE, '--state', STATE, '--config', CONFIG], {
      cwd: ROOT,
      env,
      stdio: 'ignore',
    });
    coreProc.unref();
  } catch (error) {
    console.error('core start', error);
  }
}

function stopCore() {
  try { if (coreProc && !coreProc.killed) coreProc.kill(); } catch { /* ignore */ }
}

function readState() {
  const state = readJson(STATE, null);
  if (state) lastState = state;
  return state;
}

function poll() {
  const state = readState();
  if (win && !win.isDestroyed()) win.webContents.send('state', state);
}

function activeModel() {
  const state = lastState || readState() || {};
  const session = state.session || {};
  let provider = String(session.provider || '');
  let model = String(session.llmModel || '');
  if (!provider) {
    try {
      const profile = path.join(os.homedir(), '.dsh', 'profiles', 'desktop', 'cordis.patch.yml');
      const text = fs.readFileSync(profile, 'utf8');
      const match = text.match(/- id: agent-default-model[\s\S]*?provider:\s*([^\s]+)[\s\S]*?model:\s*([^\s]+)/);
      if (match) { provider = match[1]; model = match[2]; }
    } catch { /* ignore */ }
  }
  if (!provider) provider = 'deepseek-official';
  if (!model) model = 'deepseek-flash';
  return { provider, model };
}

function credential(name) {
  const env = process.env[name];
  if (env) return String(env).trim();
  try {
    const file = path.join(os.homedir(), '.dsh', '.credentials.yaml');
    const text = fs.readFileSync(file, 'utf8');
    const re = new RegExp('^\\s*' + name + ':\\s*(\\S+)', 'm');
    const match = text.match(re);
    if (match) return match[1].replace(/^["']|["']$/g, '');
  } catch { /* ignore */ }
  return '';
}

async function queryBalance() {
  const { provider, model } = activeModel();
  let title = '';
  let url = '';
  let keyName = '';
  let kind = '';
  if (/deepseek/i.test(provider)) {
    title = 'DeepSeek 余额'; url = 'https://api.deepseek.com/user/balance'; keyName = 'DEEPSEEK_API_KEY'; kind = 'deepseek';
  } else if (/openrouter/i.test(provider)) {
    title = 'OpenRouter 余额'; url = 'https://openrouter.ai/api/v1/credits'; keyName = 'OPENROUTER_API_KEY'; kind = 'openrouter';
  } else if (/moonshot|kimi/i.test(provider)) {
    title = 'Moonshot 余额'; url = 'https://api.moonshot.cn/v1/users/me/balance'; keyName = 'MOONSHOT_API_KEY'; kind = 'moonshot';
  } else {
    return { title: provider + ' 余额', text: '该 provider 暂无余额接口', meta: '当前模型：' + model, ok: false };
  }
  const key = credential(keyName);
  if (!key) return { title, text: '未找到 ' + keyName, meta: '当前模型：' + model, ok: false };
  try {
    const response = await fetch(url, {
      headers: { Authorization: 'Bearer ' + key, Accept: 'application/json' },
      signal: AbortSignal.timeout(12000),
    });
    if (!response.ok) throw new Error('HTTP ' + response.status);
    const data = await response.json();
    let text = '';
    let ok = true;
    if (kind === 'deepseek') {
      const infos = Array.isArray(data.balance_infos) ? data.balance_infos : [];
      text = infos.map((item) => {
        const symbol = item.currency === 'CNY' ? '¥' : item.currency === 'USD' ? '$' : item.currency + ' ';
        return symbol + item.total_balance;
      }).join('  ·  ') || '暂无余额信息';
      ok = data.is_available === true;
    } else if (kind === 'openrouter') {
      const left = Number(data?.data?.total_credits || 0) - Number(data?.data?.total_usage || 0);
      text = '$' + left.toFixed(2);
      ok = left > 0;
    } else {
      text = '¥' + (data?.data?.available_balance ?? '--');
    }
    return {
      title,
      text,
      meta: model + ' · ' + (ok ? '可用' : '不可用') + ' · 双击刷新',
      ok,
    };
  } catch (error) {
    const message = String(error && error.message ? error.message : error).slice(0, 60);
    return { title, text: '查询失败：' + message, meta: '双击重试', ok: false };
  }
}

function scheduleSave() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(savePosition, 300);
}
function savePosition() {
  if (!win || win.isDestroyed()) return;
  const [x, y] = win.getPosition();
  ui.left = x;
  ui.top = y;
  saveUi();
}

function visibleOnSomeDisplay(x, y) {
  return screen.getAllDisplays().some((display) => {
    const area = display.workArea;
    return x + W > area.x + 40 && x < area.x + area.width - 40 && y + H > area.y + 40 && y < area.y + area.height - 40;
  });
}

function createWindow() {
  const area = screen.getPrimaryDisplay().workArea;
  let x = Number(ui.left);
  let y = Number(ui.top);
  if (!Number.isFinite(x) || !Number.isFinite(y) || !visibleOnSomeDisplay(x, y)) {
    x = area.x + area.width - W - 16;
    y = area.y + area.height - H - 6;
  }
  win = new BrowserWindow({
    x: Math.round(x),
    y: Math.round(y),
    width: W,
    height: H,
    transparent: true,
    frame: false,
    resizable: false,
    hasShadow: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    fullscreenable: false,
    show: false,
    webPreferences: {
      preload: path.join(MAC, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
    },
  });
  win.setAlwaysOnTop(true, 'floating');
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.loadFile(path.join(MAC, 'index.html'));
  win.once('ready-to-show', () => win.show());
  win.on('move', scheduleSave);
  win.on('closed', () => { win = null; });

  startCore();
  poll();
  clearInterval(pollTimer);
  pollTimer = setInterval(poll, 500);
}

function sendCommand(command, value) {
  if (win && !win.isDestroyed()) win.webContents.send('command', command, value);
}

function menuTemplate() {
  const material = ui.material || 'white';
  const scale = ui.scale || 0.9;
  const setMaterial = (value) => {
    ui.material = value;
    saveUi();
    sendCommand('material', value);
  };
  const setScale = (value) => {
    ui.scale = value;
    saveUi();
    sendCommand('scale', value);
  };
  return [
    { label: '打开 DSH', click: () => { const state = lastState || readState() || {}; if (state.dshUrl) shell.openExternal(String(state.dshUrl)); } },
    { label: '摸摸头', click: () => sendCommand('pet') },
    { type: 'separator' },
    {
      label: '材质',
      submenu: [
        { label: '深蓝色', type: 'radio', checked: material === 'default', click: () => setMaterial('default') },
        { label: '白色磨砂', type: 'radio', checked: material === 'white', click: () => setMaterial('white') },
        { label: '透明玻璃', type: 'radio', checked: material === 'glass', click: () => setMaterial('glass') },
      ],
    },
    {
      label: '大小',
      submenu: [0.8, 1.0, 1.2].map((value) => ({
        label: Math.round(value * 100) + '%',
        type: 'radio',
        checked: Math.abs(scale - value) < 0.05,
        click: () => setScale(value),
      })),
    },
    {
      label: '重置位置',
      click: () => {
        if (!win) return;
        const area = screen.getPrimaryDisplay().workArea;
        win.setPosition(Math.round(area.x + area.width - W - 16), Math.round(area.y + area.height - H - 6));
      },
    },
    { label: '打开说明', click: () => shell.openPath(README) },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ];
}

function showMenu() {
  if (!win) return;
  Menu.buildFromTemplate(menuTemplate()).popup({ window: win });
}

function toggleWindow() {
  if (!win) return;
  if (win.isVisible()) win.hide();
  else { win.show(); win.focus(); }
}

function createTray() {
  try {
    const image = nativeImage.createFromPath(path.join(MAC, 'trayTemplate.png'));
    if (process.platform === 'darwin') image.setTemplateImage(true);
    tray = new Tray(image);
    tray.setToolTip('DSH 大肥鱼');
    tray.setContextMenu(Menu.buildFromTemplate([
      { label: '显示 / 隐藏大肥鱼', click: toggleWindow },
      { type: 'separator' },
      ...menuTemplate(),
    ]));
  } catch (error) {
    console.error('tray', error);
  }
}

ipcMain.handle('bootstrap', () => ({
  material: ui.material || 'white',
  scale: ui.scale || 0.9,
}));

ipcMain.handle('balance', () => queryBalance());
ipcMain.on('menu', () => showMenu());

ipcMain.on('drag-start', (_event, point) => {
  if (!win) return;
  const [x, y] = win.getPosition();
  drag = { x, y, sx: Number(point.x), sy: Number(point.y) };
});
ipcMain.on('drag-move', (_event, point) => {
  if (!win || !drag) return;
  const x = drag.x + Number(point.x) - drag.sx;
  const y = drag.y + Number(point.y) - drag.sy;
  win.setPosition(Math.round(x), Math.round(y));
});
ipcMain.on('drag-end', () => {
  drag = null;
  savePosition();
});
ipcMain.on('save-ui', (_event, patch) => {
  if (!patch || typeof patch !== 'object') return;
  if (['default', 'white', 'glass'].includes(patch.material)) ui.material = patch.material;
  if (Number.isFinite(Number(patch.scale))) ui.scale = Math.max(0.7, Math.min(1.3, Number(patch.scale)));
  saveUi();
});

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) { win.show(); win.focus(); }
  });
  app.whenReady().then(() => {
    if (process.platform === 'darwin' && app.dock) app.dock.hide();
    createWindow();
  });
  app.on('activate', () => {
    if (!win) createWindow();
  });
  app.on('before-quit', () => {
    try { if (tray) tray.destroy(); } catch { /* ignore */ }
    savePosition();
    stopCore();
    clearInterval(pollTimer);
  });
  app.on('window-all-closed', () => app.quit());
}
