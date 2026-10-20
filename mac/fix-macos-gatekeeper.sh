#!/bin/bash
# 仅用于本地测试：检查 Electron 来源，移除隔离属性并 ad-hoc 签名。
# 正式分发仍需 Apple Developer ID 签名 + 公证。
set -e
cd "$(dirname "$0")"

if [ ! -d node_modules/electron ]; then
  echo "还没安装 Electron，请先运行 ./install-mac.sh"
  exit 1
fi

APP=$(find node_modules/electron/dist -maxdepth 1 -name "*.app" -type d 2>/dev/null | head -1)
if [ -z "$APP" ]; then
  echo "在 node_modules/electron/dist 下找不到 .app。"
  echo "如果它已经被移到废纸篓，请先从废纸篓恢复，或重新 npm install。"
  exit 1
fi

echo "Electron.app: $APP"
echo
echo "== 签名信息 =="
codesign -dv --verbose=2 "$APP" 2>&1 | sed -n '1,8p' || true
echo
echo "== Gatekeeper 评估 =="
spctl -a -vv "$APP" 2>&1 || true
echo
echo "如果签名 Authority 不是 Electron 官方（Electron / GitHub），不要继续，"
echo "请删除 node_modules 并用官方 registry 重装："
echo "  npm config set registry https://registry.npmjs.org/"
echo "  unset ELECTRON_MIRROR"
echo "  rm -rf node_modules package-lock.json"
echo "  npm cache clean --force && npm install"
echo
read -r -p "签名看起来是 Electron 官方、只是被隔离？输入 yes 继续修复： " answer
if [ "$answer" != "yes" ]; then
  echo "已取消。"
  exit 1
fi

xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "已移除隔离并 ad-hoc 签名。现在运行 ./start-mac.command"
