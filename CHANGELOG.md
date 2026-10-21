# Changelog

> v0.1.0–v0.1.14 全部保留；**v0.1.14 是当前版本**，原计划的 0.2.0 合并版已取消。完整 commit 历史仍在 git 中。
>
> macOS 版标记为**实验性，暂停研发**。
>
> 说明：v0.1.0–v0.1.5 的原始 release 说明在备份时出现编码损坏，以下为按 commit / 功能 / 重建记录整理的摘要；v0.1.6–v0.1.11 为原始说明。

## 0.1.14 — 2026-10-21

### Windows

- 启动后检查所有显示器：窗口不在任何屏幕工作区内时自动回到主屏右下角
- 托盘菜单圆角延迟到布局完成后再应用，修复托盘菜单被裁成 36×4、只剩一条的问题
- 主动“退出大肥鱼”写入 `quit.flag`，DSH 插件不会立即补拉
- 启动插件增加 15 秒看门狗：挂件异常退出自动补拉；DSH 启动时清除 `quit.flag` 并拉起

### macOS

- 暂停；无应用代码改动；`mac/package.json` 只跟随版本号到 0.1.14

## 0.1.13 — 2026-10-20

### Windows

- 玻璃右键菜单改为**真正的分层透明**（70% 不透明度），圆角 + 渐变，纯白 10pt 加粗、无描边
- 设置 / 材质 / 大小 / 会话子菜单在打开时应用同一套玻璃主题
- 全局快捷键 `Ctrl+Alt+H` 显示/隐藏挂件
- 托盘菜单增加“检查更新”
- “检查更新”优先读取 `version.json`，与单一版本源一致

## 0.1.12 — 2026-10-20

### 工程

- 新增 `version.json` 单一版本源、`scripts/sync-version.mjs`、`scripts/check-version.mjs`
- CI 增加版本一致性检查和 actions v5
- `doctor` 增加：配置未知键/范围、`dshUrl`、重复 fish-core、provider keys
- Windows “打开 DSH”增加 loopback URL 校验
- URL allowlist 纯函数与单测

### 文档

- README 增加 Windows/macOS 状态停留时长矩阵
- 发布流程、issue 模板、标签脚本已准备（未上传）

## 当前功能总览（0.1.14）

### Windows（稳定维护）

- WPF 透明悬浮挂件：实时任务进度、`todo_write` 进度、当前工具/步骤、已用时间
- 状态动画：思考、工作、待命、打瞌睡、出错、完成
- 材质：深蓝色 / 白色磨砂 / 透明玻璃（20% 白），右键菜单跟随材质切换主题
- 余额：双击查询 DeepSeek / OpenRouter / Moonshot 当前模型余额
- 完成提醒：角色庆祝 + 星光 + 绿勾 + 提示音 + Windows 桌面通知
- 多会话：最近会话列表、固定显示、自动跟随
- 详情显示/隐藏、提醒音、缩放（70%–140%）、拖动、位置保存、托盘菜单
- 单实例、后端重启、自动恢复、配置合并
- 安全与稳定性：CSP、单实例互斥、core 清理

### macOS（实验性，暂停研发）

- Electron 独立悬浮窗：透明置顶、三档材质、拖动/位置保存
- 菜单栏图标、右键菜单、会话、详情、提醒音、设置、完成通知
- 透明区域按角色/气泡矩形动态穿透
- 缩放 80% / 100% / 120%，窗口高度自适应
- 完成绿勾/星光，compact 模式下余额正常显示
- 固定会话 phase 重算，aborted 不再当完成
- 读取 `DSH_HOME` / `config.json`，Node 22.15+ 启动检查
- 后端 watchdog，fish-core 退出后自动拉起
- `doctor` 自检 + `--bundle` 诊断包
- `install-mac.sh` / `uninstall-mac.sh`
- Gatekeeper 处理、签名/公证说明（`mac/SIGNING.md`）

> macOS 版使用 npm Electron，体积、内存、Gatekeeper 和签名成本都偏高；目前暂停研发。代码保留，后续如恢复会优先考虑纯 Swift 或 Tauri。

### 工程

- 最小离线测试：状态机、固定会话、配置合并、路径解析、缩放、命中矩形
- GitHub Actions：Ubuntu / Windows / macOS + Node 22
- `SECURITY.md`、CSP、`openExternal` 仅允许 http/https
- 诊断包：`logs/dsh-fish-diagnostic-*.zip`（不包含凭据）

## 版本历史

### 0.1.11 — 2026-10-20

历史版本。

#### 新增

- 诊断包：`node bin/doctor.mjs --bundle` / `mac/doctor.sh --bundle`，生成 `logs/dsh-fish-diagnostic-*.zip`
- macOS 右键 → 设置 → **导出诊断包**
- 诊断包包含 doctor 报告、`state.json`、`config.json`、`mac/ui-mac.json` 和 `logs/*.log`
- 诊断包**不包含** API Key、凭据文件和会话正文

#### 文档

- 新增 `mac/SIGNING.md`：Developer ID 签名、`notarytool` 公证、`stapler` 验收步骤
- 说明当前源码运行方式没有打包 `.app`，正式分发需要 Apple Developer 证书和打包配置

#### 说明

- 包含 v0.1.10 的 doctor、离线测试/CI、macOS 安装/卸载、watchdog
- 包含 v0.1.9 的鼠标穿透
- 包含 v0.1.8 的 issue 修复

### 0.1.10 — 2026-10-20

#### 新增

- `bin/doctor.mjs` 自检：Node 22.15+、zstd、DSH_HOME、会话、API Key、`state.json`、fish-core、Electron 依赖
- macOS 右键 → 设置 → **运行自检 / doctor**；终端可用 `mac/doctor.sh`
- `mac/uninstall-mac.sh`：退出、移除登录自启、清理本地运行文件（`--purge` 删除 node_modules）
- `install-mac.sh` 增加 Node 22.15+ 检查
- 最小离线测试：`node --test test/*.test.cjs`，覆盖状态机、固定会话、配置合并、路径解析、缩放和鼠标命中矩形
- GitHub Actions：`.github/workflows/test.yml`，三平台跑测试和语法检查
- macOS 后端 watchdog：fish-core 退出后自动拉起
- macOS done/error/aborted 气泡统一约 12 秒后隐藏

#### 修复

- 固定会话 phase 重算
- 重启后端先清理旧 core
- 读取 `DSH_HOME` / `config.json`
- Node 版本不足时明确报错

#### 说明

- 包含 v0.1.9 的鼠标穿透
- 包含 v0.1.8 的 issue 修复
- 包含 v0.1.7 的右键菜单材质主题

### 0.1.9 — 2026-10-20

#### 新增

- macOS 透明区域鼠标穿透：按角色/气泡矩形动态 `setIgnoreMouseEvents`
- 窗口空白区域不再挡住桌面点击和右键
- 保留拖动、双击余额、右键菜单和菜单栏图标

#### 限制

- 当前是矩形近似；角色矩形内的透明像素和气泡尾巴间隙仍可能拦截点击

#### 说明

- 包含 v0.1.8 的 issue 修复：菜单栏图标、固定会话 phase、重启 core、DSH_HOME/config、Node 检查、缩放不裁切、完成绿勾/星光等
- 包含 v0.1.7 的右键菜单材质主题
- 包含 v0.1.6 的 macOS 菜单功能补齐

### 0.1.8 — 2026-10-20

#### 修复（对应 GitHub issues）

- #1 macOS 菜单栏图标：实际调用 `createTray()`
- #3 中止任务不再发完成通知，只对 `completed` 通知/响铃
- #4 固定非主会话后重算 phase，已结束会话不再显示“正在：思考中…”
- #5 重启后端前先杀掉 `core.pid`，避免两个 fish-core
- #6 120% 缩放时窗口高度自适应，气泡不再被裁切
- #7 读取 `DSH_HOME` 和 `config.json` 的 scale/notify/sound
- #8 Node 需 22.15+；启动时检查并明确报错，不再静默失败
- #9 macOS 完成绿勾/星光，compact 模式下余额也能正常显示
- #10 文档同步缩放、Node、托盘和完成反馈
- #13 增加 CSP、`openExternal` 仅允许 http/https、`SECURITY.md`

#### 排期

- #2 macOS 整窗透明区域拦截鼠标（后续在 0.1.9 做矩形近似）
- #11 离线测试套件与 CI（后续在 0.1.10 完成）
- #12 doctor / 诊断包（后续在 0.1.10 / 0.1.11 完成）

### 0.1.7 — 2026-10-20

#### 改进

- 右键菜单跟随当前材质：
  - 深蓝色 → 深色菜单
  - 白色磨砂 → 白色菜单
  - 透明玻璃 → 浅蓝玻璃菜单
- 菜单项、子菜单、大小控件、箭头和托盘菜单同步主题
- 白色/玻璃菜单使用深色文字，避免看不清

#### 说明

- 包含 v0.1.6 的 macOS 会话、详情、提醒音、设置和系统通知
- 包含 v0.1.5 的 macOS 菜单栏图标
- 包含 v0.1.4 的 README / banner macOS 同步

### 0.1.6 — 2026-10-20

#### 新增（macOS 功能补齐）

- 会话子菜单：自动 / 最近任务，可固定显示某一个会话
- 显示 / 隐藏详情
- 提醒音开关；任务完成时 macOS 系统通知 + 提示音
- 设置子菜单：总在最前、桌面通知、提示音、重启后端、打开日志/安装目录/配置文件、登录自启
- 菜单栏图标菜单同步这些入口

#### 说明

- 余额查询需要 `DEEPSEEK_API_KEY`（环境变量或 `~/.dsh/.credentials.yaml` 的 refs）；如果 DSH 是账号登录而没有 API Key，会提示“未找到 DEEPSEEK_API_KEY”，这不影响任务进度
- 包含 v0.1.5 的菜单栏图标、v0.1.4 的 README/banner macOS 同步
- 包含 `mac/fix-macos-gatekeeper.sh`：Electron 被 Gatekeeper 隔离时可本地修复

### 0.1.5 — 2026-10-20

#### 新增

- **macOS 菜单栏图标**：显示/隐藏、打开 DSH、摸摸头、材质、大小、重置位置、说明、退出
- 透明模板图标，自动适配菜单栏深浅色
- 没有 Dock 图标

#### 说明

- 包含 v0.1.4 的 README / banner 同步

### 0.1.4 — 2026-10-20

#### 文档

- README / banner 同步 macOS，底部改为 `for DeepSeek Harness · Windows & macOS`
- README 增加 Windows / macOS 平台差异、macOS 安装/卸载、Node 要求

### 0.1.3 — 2026-10-20

#### 新增

- **macOS 版（Electron）**：透明悬浮窗、鲸鱼娘帧素材、进度气泡、三种材质
- 双击查询余额、拖动/位置保存、原生右键菜单
- DSH 插件在 macOS 上自动拉起 `mac/node_modules/.bin/electron`

### 0.1.2 — 2026-10-20

#### 修复

- 窗口关闭后重启时恢复关闭前的窗口位置
- 支持多显示器；部分移出屏幕时回退到默认位置

### 0.1.1 — 2026-10-19

#### 新增

- 双击查看当前模型 provider 余额（DeepSeek / OpenRouter / Moonshot），约 3 秒后恢复进度
- 材质切换：深蓝色、白色磨砂、透明玻璃（20% 白）
- 白色磨砂改为白色文字，避免看不清
- 右键菜单：材质、大小、重置位置、说明、退出

### 0.1.0 — 2026-10-19

#### 新增

- 首个桌面鲸鱼娘进度挂件
- WPF 透明悬浮窗：实时任务进度、当前工具/步骤、已用时间
- 状态动画：思考、工作、待命、打瞌睡、出错、完成
- 材质：深蓝色 / 白色磨砂 / 透明玻璃
- 余额：双击查询当前模型 provider
- 完成提醒：庆祝、星光、绿勾、提示音、Windows 通知
- 拖动、位置保存
- DSH 插件自动拉起 / 单实例

## 版本说明

- v0.1.14 是当前版本，也是推荐下载
- v0.1.0–v0.1.13 历史 release/tag 保留
- 原 0.2.0 合并版已取消
- 旧版本 commit 仍在 git 历史中，可按 tag/commit 检出
- 旧版本 release 说明已尽量恢复；0.1.0–0.1.5 的原始说明在备份时出现编码损坏，当前为重建摘要
