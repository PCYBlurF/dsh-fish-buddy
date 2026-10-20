#!/bin/bash
# 安装 macOS 版依赖（Electron）
set -e
cd "$(dirname "$0")"

if ! command -v npm >/dev/null 2>&1; then
  echo "未找到 npm。请先安装 Node.js 22+（或使用 DSH 自带的 Node）。"
  exit 1
fi

echo "安装 Electron（首次约 100 MB）…"
npm install

chmod +x start-mac.command stop-mac.sh install-autostart-mac.sh 2>/dev/null || true
echo
echo "完成。运行 ./start-mac.command 或 npm start 启动大肥鱼。"
