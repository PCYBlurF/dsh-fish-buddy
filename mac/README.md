# DSH 大肥鱼 · macOS 版

macOS 上不能再使用原来的 WPF/PowerShell 挂件，所以这里用 **Electron** 重写了一个独立小应用：

- 透明、无边框、总在最前的桌面悬浮窗
- 复用仓库里的鲸鱼娘帧素材 `assets/whale/`
- 复用 `bin/fish-core.mjs` 读取 `~/.dsh` 会话日志并生成 `state.json`
- 任务进度气泡、完成庆祝、三种材质
- 双击角色查询当前模型 provider 余额（约 3 秒）
- 菜单栏图标（macOS 的托盘）：显示/隐藏、打开 DSH、摸摸头、材质、大小、重置位置、说明、退出
- 右键菜单：打开 DSH、摸摸头、材质、大小、重置位置、退出
- 拖动角色/气泡移动窗口，位置保存在 `mac/ui-mac.json`

## 环境要求

- macOS 12 或更高（Apple Silicon / Intel 都支持，Electron 会自动装对应架构）
- Node.js 22+（推荐直接用 DSH 自带的 Node）
- 首次需要 `npm install` 安装 Electron（约 100 MB）

## 安装与启动

```bash
cd mac
./install-mac.sh
./start-mac.command
```

也可以：

```bash
cd mac
npm install
npm start
```

启动后角色在屏幕右下角。没有 Dock 图标；菜单栏右上角会出现大肥鱼图标（macOS 的“托盘”），可以从那里显示/隐藏、退出，也可以右键角色退出。

## 与 DSH 一起用

`fish-core.mjs` 会读取 `~/.dsh` 下的会话日志，所以 Mac 上要先装好 DSH 并产生过会话。

推荐让 DSH 插件自动拉起 Mac 版：

1. 在 Mac 上装好 DSH，确认 `~/.dsh` 存在。
2. 把本仓库放到某个目录，例如 `~/dsh-fish-buddy`。
3. 在 `mac/` 下执行 `npm install`。
4. DSH 的 profile patch 指向本仓库的 `plugin/index.mjs`，并设置：

```yaml
config:
  widgetDir: /Users/你的用户名/dsh-fish-buddy
```

DSH 启动时，插件会在 macOS 上执行 `mac/node_modules/.bin/electron mac`。

如果不想让 DSH 拉起，也可以只手动运行 `mac/start-mac.command`；插件检测不到 Electron 时只会在日志里提示。

## 登录自启

```bash
cd mac
./install-autostart-mac.sh
```

会创建 `~/Library/LaunchAgents/com.dsh.fishbuddy.plist`。

取消：

```bash
launchctl unload ~/Library/LaunchAgents/com.dsh.fishbuddy.plist
rm ~/Library/LaunchAgents/com.dsh.fishbuddy.plist
```

## 使用

| 操作 | 功能 |
| --- | --- |
| 拖动角色/气泡 | 移动窗口，松手保存位置 |
| 单击 | 显示/隐藏气泡 |
| 双击 | 查询当前模型余额（3 秒） |
| 右键 | 菜单：打开 DSH / 摸摸头 / 材质 / 大小 / 重置位置 / 退出 |
| 滚轮 | 暂无（macOS 版未实现收起） |

## 文件

- `main.cjs`：Electron 主进程，窗口、状态轮询、余额请求、原生菜单、拖拽
- `preload.cjs`：`contextBridge` API
- `renderer.js` / `style.css` / `index.html`：悬浮窗 UI
- `ui-mac.json`：窗口位置、材质、大小（首次运行自动生成）
- `trayTemplate.png` / `trayTemplate@2x.png`：菜单栏模板图标
- `../state.json`：由 `fish-core.mjs` 写入
- `../logs/`：后端日志

## 已知差异 / 限制

- 透明玻璃是 **20% 白 + 白色描边** 的近似；macOS 的透明窗口同样没有真正的桌面 `backdrop-filter` 模糊（和 Windows 版一致）。
- 余额 provider 支持 DeepSeek / OpenRouter / Moonshot；其他 provider 会提示暂无余额接口。
- 这是新加的 macOS 版本，当前开发环境没有 Mac，HTML/JS 已做本地模拟预览，但 Electron 透明窗口、原生菜单、登录自启还需要在 Mac 上首次实测。
- 如果窗口跑到屏幕外，右键 → **重置位置**。
- 如果一直没有任务数据，检查 `~/.dsh/sessions` 是否有最近会话，以及 `mac` 启动时是否找到 Node 22+（`DSH_NODE` 可手动指定 Node 路径）。
