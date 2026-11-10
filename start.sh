#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# Ensure ~/.local/bin (default install path for agy CLI on Linux) is in PATH
export PATH="$HOME/.local/bin:$PATH"

PID_FILE=".agy2api.pid"
LOG_FILE="agy2api.log"
ACTION="${1:-start}"

stop_service() {
  local stopped=0
  if [ -f "$PID_FILE" ]; then
    local old_pid
    old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "[INFO] 正在停止旧的常驻进程 (PID: $old_pid)..."
      kill "$old_pid" 2>/dev/null || true
      sleep 1
      kill -9 "$old_pid" 2>/dev/null || true
      stopped=1
    fi
    rm -f "$PID_FILE"
  fi

  if pkill -f "src/index.ts" 2>/dev/null || pkill -f "dist/index.js" 2>/dev/null; then
    stopped=1
    sleep 1
  fi
  pkill -f "agy acp --sandbox" 2>/dev/null || true

  return $stopped
}

check_env() {
  if ! command -v node >/dev/null 2>&1; then
    echo "[ERROR] 未检测到 Node.js，请先安装 Node.js (>= 22.5.0): https://nodejs.org/"
    exit 1
  fi

  if ! command -v "${AGY_BIN:-agy}" >/dev/null 2>&1; then
    echo "[WARN] 未在 PATH 中检测到 agy 命令，请确认已安装 Antigravity CLI。"
  fi

  if [ ! -d "node_modules" ]; then
    echo "[INFO] 首次运行，正在自动安装依赖 (npm install)..."
    npm install
  fi
}

case "$ACTION" in
  stop)
    stop_service || true
    echo "[OK] agy-acp2api 后台服务已停止。"
    ;;

  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
      echo "[OK] agy-acp2api 正在后台常驻运行 (PID: $(cat "$PID_FILE"))"
    else
      echo "[WARN] agy-acp2api 当前未运行。"
    fi
    if [ -f "$LOG_FILE" ]; then
      echo "--- 最近日志 ($LOG_FILE) ---"
      tail -n 20 "$LOG_FILE"
    fi
    ;;

  logs|log)
    touch "$LOG_FILE"
    tail -n 50 -f "$LOG_FILE"
    ;;

  fg)
    echo "========================================================"
    echo "  agy-acp2api - 前台调试模式 (按 Ctrl+C 退出)"
    echo "========================================================"
    check_env
    stop_service || true
    shift || true
    exec npx tsx --no-warnings src/index.ts --no-open "$@"
    ;;

  start|restart|*)
    echo "========================================================"
    echo "  agy-acp2api - Antigravity ACP to OpenAI API Gateway"
    echo "========================================================"
    check_env
    stop_service || true

    echo "[INFO] 正在以常驻守护模式后台启动 agy-acp2api..."
    nohup npx tsx --no-warnings src/index.ts --no-open > "$LOG_FILE" 2>&1 < /dev/null &
    NEW_PID=$!
    disown "$NEW_PID" 2>/dev/null || true
    echo "$NEW_PID" > "$PID_FILE"

    sleep 2
    if kill -0 "$NEW_PID" 2>/dev/null; then
      echo "[OK] 启动成功！已在后台常驻运行 (PID: $NEW_PID)，断开 SSH 不会掉线。"
      echo "  - 查看状态: ./start.sh status"
      echo "  - 实时日志: ./start.sh logs"
      echo "  - 停止服务: ./start.sh stop"
      echo "  - 前台运行: ./start.sh fg"
    else
      echo "[ERROR] 启动失败，最近日志如下："
      cat "$LOG_FILE" 2>/dev/null || true
      rm -f "$PID_FILE"
      exit 1
    fi
    ;;
esac
