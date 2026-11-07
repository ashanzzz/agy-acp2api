#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "========================================================"
echo "  agy-acp2api - Antigravity ACP to OpenAI API Gateway"
echo "========================================================"

if ! command -v node >/dev/null 2>&1; then
  echo "[ERROR] 未检测到 Node.js，请先安装 Node.js (>= 22.5.0): https://nodejs.org/"
  exit 1
fi

if ! command -v "${AGY_BIN:-agy}" >/dev/null 2>&1; then
  echo "[WARN] 未在 PATH 中检测到 agy 命令，请确认已安装 Antigravity CLI 或已设置 AGY_BIN 环境变量。"
fi

if [ ! -d "node_modules" ]; then
  echo "[INFO] 首次运行，正在自动安装依赖 (npm install)..."
  npm install
fi

echo "[INFO] 正在启动 agy-acp2api 网关..."
exec npx tsx --no-warnings src/index.ts --open "$@"
