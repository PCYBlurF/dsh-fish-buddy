#!/bin/bash
# DSH 大肥鱼 macOS 启动器（可双击运行）
set -e
cd "$(dirname "$0")"

if [ ! -x "node_modules/.bin/electron" ]; then
  echo "还没有安装 Electron。请先运行："
  echo "  cd \"$(pwd)\" && ./install-mac.sh"
  read -r -p "按回车退出…" _
  exit 1
fi

exec ./node_modules/.bin/electron . "$@"
