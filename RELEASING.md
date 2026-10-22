# 发布流程

## 原则

- **只有项目所有者明确说“上传 / 发布 / 推送”时才执行 GitHub 写操作**：`git push`、创建/删除 release、创建/删除 tag、评论/关闭 issue、修改仓库设置。
- 不删除历史 release/tag；修正用新版本。
- 一次只发一个版本；发布前先跑测试和 CI。
- Release 说明必须链接 `CHANGELOG.md`，写清平台状态和安装方式。
- macOS 当前为**实验性、暂停研发**；不要为 macOS 单独发版，除非明确恢复。

## 版本源

- **`version.json` 是唯一版本源**。
- 修改版本时：
  1. 改 `version.json`
  2. 运行 `node scripts/sync-version.mjs`，自动写回 `bin/fish-widget.ps1` 和 `mac/package.json`
  3. 运行 `node scripts/check-version.mjs`，确认 `version.json` / `bin/fish-widget.ps1` / `mac/package.json` 三处一致，且 `CHANGELOG.md` 有精确的 `## x.y.z` 标题
  4. 手动更新 `CHANGELOG.md` 和 `docs/releases/vx.y.z.md`（sync 只写代码版本，不改文档）
- 版本号必须与 release tag 一致。
- CI 会跑 `check-version`，不一致直接失败。

## 发布前检查

1. `CHANGELOG.md` 已写清本次新增/修复/文档。
2. Windows 挂件能启动，右键菜单、材质、余额、托盘正常。
3. `node scripts/check-version.mjs` 和 `node --test test/*.test.cjs` 通过。
4. `node --check` 通过：`mac/main.cjs`、`mac/preload.cjs`、`mac/renderer.js`、`mac/lib.cjs`、`bin/fish-core.mjs`、`bin/doctor.mjs`、`plugin/index.mjs`。
5. GitHub Actions（`.github/workflows/test.yml`）通过。
6. 已获得所有者对 **push + release** 的明确许可。

## 发布步骤

```bash
# 1. 确认版本源并同步（先获得许可）
node scripts/check-version.mjs
git add -A
git commit -m "release: v0.1.x"

# 2. 打 tag（先获得许可）
git tag -a v0.1.x -m "DSH 大肥鱼 v0.1.x"

# 3. 推送（先获得许可）
git push origin main
git push origin v0.1.x

# 4. 打包（统一放到归档目录，不要散落在 G:/Workspace 根目录）
RELEASE_DIR="$PWD/release-archives"
mkdir -p "$RELEASE_DIR"
git archive --format=zip --output="$RELEASE_DIR/dsh-fish-buddy-v0.1.x.zip" v0.1.x

# 5. 创建 release（先获得许可）
gh release create v0.1.x "$RELEASE_DIR/dsh-fish-buddy-v0.1.x.zip" \
  --title "DSH 大肥鱼 v0.1.x" \
  --notes-file docs/releases/v0.1.x.md \
  --latest
```

## 发布后

- 确认 release 是 Latest、资产可下载。
- 确认 `CHANGELOG.md` 链接可访问。
- 旧 release 保留，不删除。
- 如果发布说明有误：**编辑 release 说明**，不要删 release。

## macOS

- 当前只保留源码/实验版本，不再继续 Electron 研发。
- 如果未来恢复：优先纯 Swift 或 Tauri，并先解决签名/公证（见 `mac/SIGNING.md`）。
