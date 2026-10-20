# Changelog

> 本项目此前按增量修复发布过 v0.1.0–v0.1.11。现合并为 **0.1.11** 一个 release，旧 release/tag 已删除；完整 commit 历史仍在 git 中。
>
> macOS 版已标记为**实验性，暂停研发**。

## 0.1.11 — 2026-10-20

合并 v0.1.0–v0.1.10 的全部增量内容。

### Windows

- WPF 透明悬浮挂件：实时任务进度、`todo_write` 进度、当前工具/步骤、已用时间
- 状态动画：思考、工作、待命、打瞌睡、出错、完成
- 材质：深蓝色 / 白色磨砂 / 透明玻璃（20% 白）
- 右键菜单跟随材质切换主题（深色/白色/玻璃）
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
- 合并发布说明：`mac/SIGNING.md`、`mac/README.md`

### 合并说明

- v0.1.0–v0.1.10 的 release 和 tag 已删除，内容全部并入 0.1.11
- 旧版本的 commit 仍在 git 历史中，可按 commit 检出
- 旧版本的 release 说明备份在本地 `old-release-notes/`（未提交到仓库）
