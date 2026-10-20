#!/bin/bash
# 停止 macOS 版大肥鱼（从菜单退出更优雅）
pkill -f "dsh-fish-buddy/mac" 2>/dev/null || true
pkill -f "dsh-fish-buddy-mac" 2>/dev/null || true
echo "已尝试停止大肥鱼。"
