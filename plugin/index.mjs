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
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const name = 'dsh-fish-buddy';

let launched = false;

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

export function apply(ctx, config = {}) {
  // 配置热重载会重复 apply；本次进程只拉起一次
  if (launched) return;
  launched = true;

  try {
    if (config && config.enabled === false) {
      logInfo(ctx, 'DSH 大肥鱼自动启动已禁用');
      return;
    }

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

    const vbs = join(widgetDir, 'bin', 'fish-widget.vbs');
    if (!existsSync(vbs)) {
      logWarn(ctx, `找不到挂件启动器：${vbs}`);
      return;
    }

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
  } catch (error) {
    logWarn(ctx, `启动挂件异常：${error instanceof Error ? error.message : String(error)}`);
  }
}
