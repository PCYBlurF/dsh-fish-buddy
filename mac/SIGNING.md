# macOS 签名与公证说明

## 现状

当前 macOS 版是**源码 + npm 安装的 Electron**：

- 没有打包成独立的 `.app`
- 没有用 Apple Developer ID 签名
- 没有经过 Apple 公证（notarization）

所以首次运行时 Gatekeeper 可能拦截 Electron，提示“未识别开发者”或“包含恶意软件”。本地测试可以按 [`README.md`](README.md) 的“macOS 拦截 Electron”一节处理，但**这不适合正式分发给别人**。

## 正式分发需要什么

1. **Apple Developer Program** 账号（个人/公司，年费）
2. **Developer ID Application** 证书
3. Team ID
4. 公证凭据：App Store Connect API Key，或 Apple ID + app-specific password

## 流程

### 1. 打包成 .app

目前仓库还没有把 `bin/`、`assets/`、`config.json` 和 `mac/` 一起打进 `.app` 的构建配置。正式签名前需要先补一个打包脚本（`@electron/packager` 或 `electron-builder`），并把相对路径从“仓库根目录”改为 `process.resourcesPath`。

> 直接对 `mac/node_modules/electron/dist/Electron.app` 签名没有意义：那不是你的应用，而且源码运行方式也没有稳定的 app bundle 可分发。

### 2. 签名

```bash
codesign --deep --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  "DSH 大肥鱼.app"
```

检查：

```bash
codesign -dv --verbose=4 "DSH 大肥鱼.app"
spctl -a -vv "DSH 大肥鱼.app"
```

### 3. 公证

```bash
xcrun notarytool submit "DSH 大肥鱼.zip" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait
```

或使用 App Store Connect API Key：

```bash
xcrun notarytool submit "DSH 大肥鱼.zip" \
  --key AuthKey_XXX.p8 \
  --key-id "KEYID" \
  --issuer "ISSUER" \
  --wait
```

### 4. Staple 与验收

```bash
xcrun stapler staple "DSH 大肥鱼.app"
spctl -a -vv "DSH 大肥鱼.app"
```

理想结果：

```text
accepted
source=Notarized Developer ID
```

## 本地测试 vs 正式分发

| 方式 | 适合 | 签名/公证 |
| --- | --- | --- |
| `./start-mac.command` + npm Electron | 自己/朋友测试 | 否 |
| `fix-macos-gatekeeper.sh` | 本地修复 quarantine | 否，仅 ad-hoc |
| 打包 `.app` + Developer ID + 公证 | 公开发布 | 是 |

在没有证书之前，建议继续把 macOS 版标注为“源码运行/测试版”，不要承诺双击即用。

## 参考

- Electron: Code Signing / Notarization 官方文档
- Apple: Notarizing macOS software before distribution
