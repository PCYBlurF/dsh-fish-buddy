#!/bin/bash
# DSH 大肥鱼 · 自检
set -e
cd "$(dirname "$0")"
NODE="${DSH_NODE:-}"
if [ -z "$NODE" ] && [ -x "$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node" ]; then
  NODE="$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node"
fi
if [ -z "$NODE" ]; then
  NODE="$(command -v node || true)"
fi
if [ -z "$NODE" ]; then
  echo "找不到 Node.js。"
  exit 1
fi
exec "$NODE" ../bin/doctor.mjs
