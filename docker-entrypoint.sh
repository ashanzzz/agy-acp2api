#!/usr/bin/env bash
set -e

echo "[agy-acp2api] Initializing environment..."

mkdir -p /app/data
mkdir -p /root/.gemini/antigravity-cli

# Initialize settings.json if missing
if [ ! -f /app/data/settings.json ]; then
  cat > /app/data/settings.json << 'EOF'
{
  "apiKey": "sk-agy-acp2api-key",
  "defaultModel": "gemini-3.8-flash",
  "defaultThinkingLevel": "medium",
  "exposeVariantModelsInList": false,
  "minWorkers": 1,
  "maxWorkers": 2,
  "workerIdleTtlMs": 180000,
  "sessionTtlMs": 600000,
  "requestTimeoutMs": 300000,
  "uiLayout": "side"
}
EOF
fi

ln -sf /app/data/settings.json /app/settings.json

# Install official Antigravity CLI if not present
if [ ! -x "/usr/local/bin/agy" ]; then
  echo "[agy-acp2api] Installing Antigravity CLI (agy)..."
  tmp=$(mktemp)
  curl -fsSL https://antigravity.google/cli/install.sh -o "$tmp"
  bash "$tmp" --dir "/usr/local/bin"
  rm -f "$tmp"
  chmod 755 /usr/local/bin/agy || true
fi

echo "[agy-acp2api] Starting Gateway on host=${AGY2API_HOST:-0.0.0.0} port=${AGY2API_PORT:-8787}..."
exec node --no-warnings dist/index.js --no-open "$@"
