#!/usr/bin/env bash
# 创建/更新平台与状态标签。
# 需要项目所有者确认后再运行；不会改代码或 release。
set -euo pipefail

REPO="${1:-PCYBlurF/dsh-fish-buddy}"

gh label create "platform:windows" --repo "$REPO" \
  --color "4D6BFE" --description "Windows 平台（稳定维护）" --force
gh label create "platform:macos" --repo "$REPO" \
  --color "111111" --description "macOS 平台（实验性、暂停研发）" --force
gh label create "status:paused" --repo "$REPO" \
  --color "FBCA04" --description "暂停处理" --force
gh label create "status:experimental" --repo "$REPO" \
  --color "D4C5F9" --description "实验性功能" --force

echo "labels ready on $REPO"
