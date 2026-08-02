#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${BANG9_RUNTIME_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/app-runtime}"
DEMO_HOST="${BANG9_DEMO_HOST:-}"

"$PROJECT_DIR/scripts/sync_portfolio_runtime.sh" >/dev/null

if [[ -z "$DEMO_HOST" ]]; then
  for interface in en0 en1; do
    DEMO_HOST="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
    [[ -n "$DEMO_HOST" ]] && break
  done
fi

if [[ -z "$DEMO_HOST" ]]; then
  echo "Mac LAN IP not found. Set BANG9_DEMO_HOST before running."
  exit 1
fi

cd "$RUNTIME_DIR"
echo "Using local API: http://${DEMO_HOST}:8000"
exec flutter run \
  --dart-define=PORTFOLIO_DEMO=true \
  --dart-define="API_BASE_URL=http://${DEMO_HOST}:8000" \
  "$@"
