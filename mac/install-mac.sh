#!/bin/bash
# 安装 macOS 版依赖（Electron）
set -e
cd "$(dirname "$0")"

if ! command -v npm >/dev/null 2>&1; then
  echo "未找到 npm。请先安装 Node.js 22+（或使用 DSH 自带的 Node）。"
  exit 1
fi

NODE_BIN="${DSH_NODE:-$(command -v node || true)}"
if [ -z "$NODE_BIN" ] && [ -x "$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node" ]; then
  NODE_BIN="$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node"
fi
if [ -z "$NODE_BIN" ]; then
  echo "未找到 Node.js。"
  exit 1
fi
if ! "$NODE_BIN" -e "process.exit(require('zlib').zstdDecompressSync ? 0 : 1)" 2>/dev/null; then
  echo "Node 版本过低：需要 22.15+（zstd 解码）。当前：$("$NODE_BIN" -p 'process.versions.node')"
  exit 1
fi

echo "安装 Electron（首次约 100 MB）…"
npm install

chmod +x start-mac.command stop-mac.sh install-autostart-mac.sh doctor.sh uninstall-mac.sh 2>/dev/null || true
echo
echo "完成。运行 ./start-mac.command 或 npm start 启动大肥鱼。"
