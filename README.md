<div align="center">
  <img src="assets/screenshots/banner.png" alt="DSH 大肥鱼" width="100%">
  <h1>DSH 大肥鱼 · 桌面鲸鱼娘进度挂件</h1>
  <p>常驻桌面的 Q 版 DeepSeek「鲸鱼娘」，实时显示 DeepSeek Harness 的任务进度；任务完成时她会跳起来、放星光、响一声，并弹完成提醒（Windows 桌面通知 / macOS 完成气泡）。</p>
  <p>
    <img alt="platform" src="https://img.shields.io/badge/platform-Windows%2010%2F11-4D6BFE">
    <img alt="platform" src="https://img.shields.io/badge/platform-macOS%20experimental-111111">
    <img alt="license" src="https://img.shields.io/badge/license-MIT-3DDC97">
    <img alt="powershell" src="https://img.shields.io/badge/PowerShell-5.1-5391FE">
    <img alt="dsh" src="https://img.shields.io/badge/DeepSeek%20Harness-Desktop-8FA6FF">
  </p>
</div>

> 非官方同人项目，与 DeepSeek 无隶属关系。「鲸鱼娘」是社区同人拟人形象。

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Windows | **稳定维护** | WPF 挂件，主要开发平台 |
| macOS | **实验性，暂停研发** | Electron 方案体积/内存/签名成本高；代码保留，后续可能换纯 Swift 或 Tauri |

macOS 版不再承诺双击即用；历史版本说明已合并到 [`CHANGELOG.md`](CHANGELOG.md)。

### 状态停留时长

| 状态 | Windows | macOS |
| --- | --- | --- |
| completed | 90s | 12s |
| error | 60s | 12s |
| aborted | 30s | 12s |

这是有意的平台差异：Windows 保留更久的完成态，macOS 更紧凑；macOS 已暂停，后续如恢复再考虑统一。

## 功能

- **实时进度**：直接读取 DSH 会话日志（分帧 zstd + JSONL），显示任务标题、`todo_write` 进度、当前工具/步骤、已用时间、目标轮次。
- **状态动画**：思考、工作、待命、打瞌睡、出错、完成都有对应的 Q 版帧动画。
- **材质切换**：右键 → 材质 ▸ 深蓝色 / 白色磨砂 / 透明玻璃（20% 白）。玻璃菜单为半透明分层玻璃，白色/深蓝保持不透明。
- **余额**：双击角色查询 DSH 当前模型所属 provider 的余额，显示约 3 秒后恢复任务进度；再次双击可刷新。provider/model 从会话日志读取，缺省回退到 profile 的 `agent-default-model`。支持 DeepSeek、OpenRouter、Moonshot/Kimi；其他 provider 会提示暂无余额接口。API Key 读取对应环境变量或 `~/.dsh/.credentials.yaml`。
- **完成提醒**：角色庆祝 + 星光 + 绿勾 + 提示音 + Windows 桌面通知（macOS 版为完成气泡 + 绿勾）。
- **多会话**：Windows 右键菜单 / macOS「会话」子菜单列出最近会话（`●` 运行中 / `○` 已结束），可固定显示某一个；默认跟随最近任务。
- **自定义大小**：Windows 70%–140%，角色、气泡、特效一起缩放；macOS 80% / 100% / 120%，窗口高度随角色缩放自动适配。
- **互动**：拖动、悬停放大、单击展开详情、双击查看当前模型余额、摸摸头、托盘菜单（Windows）/ 菜单栏图标 + 右键菜单（macOS）、滚轮收起（Windows）。
- **窗口位置自愈**：启动后检查所有显示器，窗口被拖到屏幕外或分辨率变化时自动回到主屏右下角。
- **Windows 快捷键**：`Ctrl+Alt+H` 显示/隐藏挂件；托盘菜单也可以直接“检查更新”。
- **自动恢复**：后端进程退出后自动重启（Windows/macOS）；不依赖 DSH API、端口或登录态，只读本机会话文件。
- **透明置顶**：Windows 版按角色/气泡矩形命中；macOS 版按角色/气泡矩形动态穿透（矩形内透明像素仍会拦截）。
- **macOS 版（实验性，暂停）**：同一套 `fish-core.mjs` 和鲸鱼娘素材，用 Electron 重写悬浮窗；双击余额、三档材质、拖动/位置保存、菜单栏图标、自检和卸载都已实现，但不再继续研发。详见 [`mac/README.md`](mac/README.md)。

<p align="center">
  <img src="assets/screenshots/working.png" alt="工作中" width="46%">
  <img src="assets/screenshots/complete.png" alt="完成提醒" width="46%">
</p>

## 安装

### 环境要求

- Windows 10 / 11，或 macOS 12+
- 已安装并启动过 **DSH Desktop**（挂件复用它的 Node 运行时和 desktop profile）
- Windows 需要 PowerShell 5.1（系统自带）；macOS 版需要 Node.js 22.15+（可用 DSH 自带 Node）

### 方式一：克隆到 DSH 默认目录（推荐）

```bat
git clone https://github.com/PCYBlurF/dsh-fish-buddy.git "%USERPROFILE%\.dsh\fish-buddy"
cd /d "%USERPROFILE%\.dsh\fish-buddy"
install.cmd
```

`install.cmd` 会：

1. 停止正在运行的旧实例；
2. 备份并把插件条目写入 `%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml`（绝对路径指向当前克隆目录）；
3. 拉起挂件。

然后**重启一次 DSH**，插件会在启动时自动拉起她。

### 方式二：克隆到任意目录

```bat
git clone https://github.com/PCYBlurF/dsh-fish-buddy.git D:\Tools\dsh-fish-buddy
cd /d D:\Tools\dsh-fish-buddy
install.cmd
```

安装脚本会把当前目录的绝对路径写进 profile，放在哪里都能用。

### 手动启动 / 停止

```bat
start-fish.cmd   :: 启动
stop-fish.cmd    :: 停止
```

### 关于版本与更新

- `version.json` 是唯一版本源；Windows 的“检查更新”优先读取它。
- 托盘菜单和右键 → 设置里都有“检查更新”。

### 关于 Node

挂件优先使用 DSH 自带的 `~/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node.exe`；找不到时回退到 `PATH` 里的 `node`。

## macOS 版

> **状态：实验性，暂停研发。** Electron 方案体积、内存和签名成本都偏高；代码保留，后续如恢复会优先考虑纯 Swift 或 Tauri。


> macOS 首次运行可能提示 Electron 被 Gatekeeper 拦截；这是 npm Electron 的签名/隔离问题，处理方式见 [`mac/README.md`](mac/README.md#macos-拦截-electron--包含恶意软件)。


WPF 只能在 Windows 上运行，macOS 使用独立的 Electron 挂件：

```bash
cd mac
./install-mac.sh
./start-mac.command
```

它复用同一份 `fish-core.mjs`、`state.json` 和 `assets/whale` 素材；支持拖动、位置保存、三档材质、双击查余额、会话选择、显示/隐藏详情、提醒音、系统通知、设置子菜单和菜单栏图标（macOS 的托盘）。DSH 插件在 macOS 上会自动拉起 `mac/node_modules/.bin/electron`。

详细安装、登录自启和已知差异见 [`mac/README.md`](mac/README.md)。

## 使用

| 操作 | 效果 |
| --- | --- |
| 拖动角色 / 气泡 | 移动位置（会记住） |
| 悬停 | 轻轻放大 |
| 单击 | 展开 / 收起详情 |
| 双击 | 查看当前模型余额 |
| 右键 | 打开 DSH / 摸摸头 / 大小 − 100% + / 材质 / 会话选择 / 详情 / 提醒音 / 重置位置 / 打开说明 / 设置 / 退出 |
| 托盘图标（Windows） | 双击打开 DSH；右键摸摸头、自定义大小、放大/缩小、显示隐藏、重置位置、说明、提醒音、退出 |
| 菜单栏图标（macOS） | 左键菜单：显示/隐藏、打开 DSH、摸摸头、会话、详情、提醒音、材质、大小、重置位置、说明、设置、退出 |
| 滚轮 | 展开 / 收起详情 |

### 大小

右键菜单里有一行 **大小：− 100% +**：

- 点 `−` / `+` 每次 ±10%，范围 70%–140%。
- 点中间的数字弹出输入框，可以填任意 70–140 的比例（填 100 即恢复默认）。
- 菜单打开期间先缩放画面，关闭菜单后再移动/缩放窗口，避免菜单跟着跳走。
- 选择保存在 `ui.json`；托盘菜单也有「自定义大小… / 放大一点 / 缩小一点」。

### 设置

右键 → **设置** ▸：

- **开机自启**：写入/移除 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`，只影响当前用户，不需要管理员权限。
- **桌面通知**：任务完成时的 Windows 通知开关，保存在 `ui.json`。
- **总在最前**：挂件是否始终置顶，保存在 `ui.json`。
- **重启后端**：重启 `fish-core.mjs`，进度卡住或重连失败时用。
- **打开日志 / 安装目录 / 配置文件**：排查问题或改 `config.json` 时直接打开。
- **检查更新**：查询 GitHub 最新 Release，和当前版本比较。
- **关于**：版本、仓库地址、许可证。

### 材质

右键 → **材质 ▸**：

- **深蓝色**：最初的深色渐变气泡，浅色文字。
- **白色磨砂**：接近不透明的浅色玻璃，深色文字、灰色描边和白色尾巴；整块颜色统一，不再出现左右两半颜色不一致。
- **透明玻璃**：只加 20% 白，80% 背景直接透出；颜色会随背景变化（左右可能不同），文字用白色+投影。

选择保存在 `ui.json` 的 `material`。

### 多会话与自动恢复

- 右键菜单的 **会话：…** 列表会显示 `自动（最近任务）` 和最近 4 个会话；点一下固定显示，选「自动」恢复跟随。
- 后端每 600ms 写一次 `state.json` 作为心跳；超过 9 秒没更新时挂件显示「正在重新连接…」并自动重启后端。
- 后端崩溃会被自动拉起（最多 5 次），原因记录在 `logs/widget.log`。

macOS 版用菜单栏图标代替托盘；滚轮收起暂未实现。右键角色同样有打开 DSH、摸摸头、会话、详情、提醒音、材质、大小、重置位置、说明和退出。macOS 研发已暂停，见上方平台状态。

## 角色状态

| DSH 状态 | 动作 |
| --- | --- |
| 思考 / 执行工具 | 托腮思考 + 小灯泡 |
| 待命 | 站立眨眼，久无任务后打瞌睡 |
| 任务完成 | 举手庆祝 + 星光 + 绿勾 + 提示音 + 通知 |
| 出错 | 惊讶表情 + 红色叹号 |
| 已停止 | 思考 / 待机 |

气泡里显示：任务标题、进度条 + `已完成/总数`、当前待办、已用时间与步骤数、目标轮次、多会话数量。

## 配置

首次运行会自动生成 `config.json`；也可以从示例复制：

```bat
copy config.example.json config.json
```

```json
{
  "mascot": "chibi",
  "scale": 1.0,
  "pollMs": 600,
  "completionWindowMinutes": 10,
  "activeWindowMinutes": 20,
  "dshUrl": "http://127.0.0.1:11821",
  "notify": true,
  "sound": true,
  "tray": true
}
```

| 字段 | 说明 |
| --- | --- |
| `mascot` | `chibi`（Q 版鲸鱼娘，默认）/ `whale`（全身立绘，需要自备 `assets/whale.png`）/ `fish`（矢量蓝色大肥鱼） |
| `scale` | 首次运行的默认大小，0.7–1.4；菜单里的选择会覆盖并记在 `ui.json` |
| `pollMs` | 后端扫描会话日志的间隔（毫秒） |
| `completionWindowMinutes` | 完成提醒的时间窗口（分钟） |
| `activeWindowMinutes` | 多久没有新事件就不再显示该会话（分钟） |
| `dshUrl` | 聚焦失败时兜底打开的地址（可选） |
| `notify` / `sound` / `tray` | Windows 通知 / 提示音 / 托盘图标 |

运行时生成、不入库的文件：`state.json`、`ui.json`、`logs/`、`*.pid`。

## 工作原理

```
DSH 会话日志 (~/.dsh/sessions/**/session.v4.jsonl.zstd)
        │  fish-core.mjs：分帧 zstd 解压 + 增量解析
        ▼
   state.json（标题 / turn / todo / tool / goal / 完成事件）
        │  fish-widget.ps1（WPF）/ mac/main.cjs（Electron），约 400ms 轮询
        ▼
   桌面透明置顶窗（Q 版鲸鱼娘 + 气泡；Windows 托盘/通知，macOS 右键菜单）
        ▲
        │  plugin/index.mjs（DSH 启动时拉起挂件）
```

- **进度读取**只读本机会话日志，不联网、不依赖 DSH API / 端口 / 登录态；**余额查询**会访问 DeepSeek / OpenRouter / Moonshot，**检查更新**会访问 GitHub API，均为手动触发。
- Windows 版透明区域鼠标穿透；macOS 版按角色/气泡矩形动态穿透（矩形内透明像素仍会拦截）；窗口按内容自适应。
- 插件只负责在 DSH 启动时叫醒挂件，重复启动会被单实例锁忽略。

## 项目结构

```
├─ install.cmd / install.ps1      写入 desktop profile 并启动
├─ uninstall.cmd / uninstall.ps1  停止并移除插件条目
├─ start-fish.cmd / stop-fish.cmd 手动启停
├─ config.example.json            配置示例
├─ bin/
│  ├─ fish-core.mjs               进度后端（Node，内置 zstd 分帧解析）
│  ├─ fish-widget.ps1             WPF 挂件 / 状态机 / 帧动画
│  ├─ chibi-ui.xaml               Q 版布局
│  ├─ whale-ui.xaml               全身立绘布局
│  ├─ fish-ui.xaml                矢量鱼布局
│  ├─ fish-widget.vbs             无控制台启动
│  └─ stop-fish.ps1               停止脚本
├─ plugin/index.mjs               DSH 启动插件
├─ mac/                           macOS Electron 版
│  ├─ main.cjs / preload.cjs      主进程 / 桥接
│  ├─ index.html / style.css      悬浮窗 UI
│  ├─ renderer.js                 状态 / 余额 / 拖拽
│  ├─ install-mac.sh              安装 Electron 依赖
│  └─ start-mac.command           启动
├─ assets/
│  ├─ whale/                      Q 版帧 + MIT LICENSE
│  ├─ screenshots/                README 预览图
│  ├─ chime.wav                   完成提示音
│  └─ fish.ico / fish.png         托盘图标
└─ THIRD_PARTY_NOTICES.md
```

## 常见问题

- **不更新进度**：查看 `logs/core.log` 是否有新的 `启动 fish-core`；或先 `stop-fish.cmd` 再 `start-fish.cmd`。
- **看不到她**：找任务栏托盘里的鱼图标；或重新运行 `start-fish.cmd`。
- **托盘图标在 `^` 溢出区里**：Windows 11 默认把新图标收进溢出区，图标本身是正常注册的。右键大肥鱼 → **把图标固定到任务栏…**，在打开的设置里进入 **个性化 → 任务栏 → 其他系统托盘图标**，找到带蓝色鲸鱼娘图标的 **Windows PowerShell**（挂件跑在 powershell.exe 下），把它打开即可常驻右下角。
- **插件没生效**：DSH 只在启动时读配置，装完/改完需要重启一次。
- **窗口位置跑偏**：右键 → 重置位置，或删除 `ui.json` 后重启。
- **想换全身立绘**：把图片放到 `assets/whale.png`（透明背景，竖图），把 `config.json` 的 `mascot` 改成 `whale` 后重启。该图片不随仓库分发。

## 卸载

```bat
uninstall.cmd
```

会停止挂件、备份并移除 `cordis.patch.yml` 里的插件段、清理开机自启；仓库目录保留，可自行删除。重启 DSH 后插件彻底消失。

macOS 版：右键角色退出，若装过登录自启先 `launchctl unload ~/Library/LaunchAgents/com.dsh.fishbuddy.plist`，再删除仓库目录即可。

## 致谢

- **Q 版鲸鱼娘帧**：来自 [vlln/whale-girl](https://github.com/vlln/whale-girl)，MIT License，Copyright (c) 2026 Sam Gao (vlln)。许可全文见 `assets/whale/LICENSE.txt`。
- 「鲸鱼娘」是社区同人形象，「DeepSeek」名称与商标归其所有者；本项目为非官方作品。

## 许可证

本项目代码以 [MIT License](LICENSE) 开源，可自由使用、修改和分发，保留版权与许可声明即可。

- 默认 Q 版鲸鱼娘素材同样为 MIT 授权，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 第三方素材的许可见各自说明。
