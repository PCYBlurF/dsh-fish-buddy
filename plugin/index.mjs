/**
 * DSH 大肥鱼 · 启动插件
 *
 * DSH 启动时把桌面上的鲸鱼娘挂件拉起来（已运行则挂件自己会忽略重复启动）。
 * 挂件与进度后端都在 ~/.dsh/fish-buddy 下，本插件只负责“开机叫醒它”。
 *
 * 配置（cordis.patch.yml 的 config）：
 *   widgetDir  挂件目录，默认 ~/.dsh/fish-buddy
 *   enabled    设为 false 可临时禁用自动启动
 */
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const name = 'dsh-fish-buddy';

let watchdog = null;

function logWarn(ctx, message) {
  try {
    ctx?.logger?.('fish-buddy')?.warn?.(message);
  } catch {
    /* 日志不可用时保持安静 */
  }
}

function logInfo(ctx, message) {
  try {
    ctx?.logger?.('fish-buddy')?.info?.(message);
  } catch {
    /* ignore */
  }
}

function widgetPid(widgetDir) {
  try {
    return Number.parseInt(readFileSync(join(widgetDir, 'widget.pid'), 'utf8'), 10) || 0;
  } catch {
    return 0;
  }
}

function widgetProcessCount() {
  if (process.platform !== 'win32') return 0;
  try {
    const out = execFileSync('powershell.exe', ['-NoProfile', '-Command', "(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -match 'fish-widget\.ps1' } | Measure-Object).Count"], { encoding: 'utf8', timeout: 8000 });
    return Number(String(out).trim()) || 0;
  } catch {
    return 0;
  }
}

function isWidgetRunning(widgetDir) {
  const pid = widgetPid(widgetDir);
  if (pid) {
    try {
      process.kill(pid, 0);
      return true;
    } catch {
      /* fall through to a real process check */
    }
  }
  return widgetProcessCount() > 0;
}

function launchWindows(ctx, widgetDir) {
  const vbs = join(widgetDir, 'bin', 'fish-widget.vbs');
  if (!existsSync(vbs)) {
    logWarn(ctx, `找不到挂件启动器：${vbs}`);
    return false;
  }
  try {
    const child = spawn('wscript.exe', [vbs], {
      detached: true,
      stdio: 'ignore',
      windowsHide: true,
      cwd: widgetDir,
    });
    child.on('error', (error) => {
      logWarn(ctx, `启动挂件失败：${error.message}`);
    });
    child.unref();
    logInfo(ctx, 'DSH 大肥鱼已在桌面待命');
    return true;
  } catch (error) {
    logWarn(ctx, `启动挂件异常：${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

export function apply(ctx, config = {}) {
  // 配置热重载会重复 apply；只允许一次初始化 + 一个看门狗定时器。
  // 注意：disabled / 依赖缺失 / 启动失败时不要提前置位，否则热重载无法重试。
  if (config && config.enabled === false) {
    if (watchdog) {
      clearInterval(watchdog);
      watchdog = null;
    }
    logInfo(ctx, 'DSH 大肥鱼自动启动已禁用');
    return;
  }
  if (watchdog) return;

  try {

    const home = process.env.DSH_HOME || join(homedir(), '.dsh');
    const widgetDir = (config && config.widgetDir) || join(home, 'fish-buddy');

    if (process.platform === 'darwin') {
      const macDir = join(widgetDir, 'mac');
      const electron = join(macDir, 'node_modules', '.bin', 'electron');
      if (!existsSync(electron)) {
        logWarn(ctx, `macOS 版依赖未安装：请在 ${macDir} 下运行 ./install-mac.sh 或 npm install`);
        return;
      }
      const child = spawn(electron, [macDir], {
        detached: true,
        stdio: 'ignore',
        cwd: macDir,
      });
      child.on('error', (error) => {
        logWarn(ctx, `启动 macOS 版挂件失败：${error.message}`);
      });
      child.unref();
      logInfo(ctx, 'DSH 大肥鱼（macOS）已在桌面待命');
      return;
    }

    if (process.platform !== 'win32') {
      logWarn(ctx, `当前平台 ${process.platform} 暂不支持挂件`);
      return;
    }

    const quitFlag = join(widgetDir, 'quit.flag');
    try {
      if (existsSync(quitFlag)) unlinkSync(quitFlag);
    } catch {
      /* ignore */
    }

    launchWindows(ctx, widgetDir);

    const ensure = () => {
      try {
        if (existsSync(quitFlag)) return;
        if (!isWidgetRunning(widgetDir)) launchWindows(ctx, widgetDir);
      } catch (error) {
        logWarn(ctx, `自动拉起检查失败：${error instanceof Error ? error.message : String(error)}`);
      }
    };

    try {
      watchdog = setInterval(ensure, 15000);
      const stop = () => {
        if (watchdog) {
          clearInterval(watchdog);
          watchdog = null;
        }
      };
      if (typeof ctx.effect === 'function') ctx.effect(stop);
      else if (typeof ctx.on === 'function') ctx.on('dispose', stop);
    } catch {
      /* ignore */
    }
  } catch (error) {
    logWarn(ctx, `启动挂件异常：${error instanceof Error ? error.message : String(error)}`);
  }
}
