#!/bin/bash
# 卸载 macOS 版大肥鱼：退出、移除登录自启、清理本地运行文件
set -e
cd "$(dirname "$0")"

echo "停止大肥鱼…"
pkill -f "dsh-fish-buddy/mac" 2>/dev/null || true
pkill -f "dsh-fish-buddy-mac" 2>/dev/null || true

PLIST="$HOME/Library/LaunchAgents/com.dsh.fishbuddy.plist"
if [ -f "$PLIST" ]; then
  echo "移除登录自启…"
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
fi

rm -f ui-mac.json ../core.pid
echo "已清理 ui-mac.json / core.pid / LaunchAgent。"

if [ "$1" = "--purge" ]; then
  echo "删除 node_modules…"
  rm -rf node_modules
fi

echo "完成。仓库目录保留，可自行删除。"
