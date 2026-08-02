#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${BANG9_RUNTIME_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/app-runtime}"
"$PROJECT_DIR/scripts/sync_portfolio_runtime.sh" >/dev/null
BACKEND_DIR="$RUNTIME_DIR/backend"
PYTHON_BIN="${BANG9_PYTHON_BIN:-/Users/yeoduchi/.cache/bang9-portfolio/venv/bin/python}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Missing local runtime. See PORTFOLIO_DEMO.md."
  exit 1
fi

cd "$BACKEND_DIR"
"$PYTHON_BIN" manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
"$PYTHON_BIN" -m uvicorn main:app --host 0.0.0.0 --port 8001 &
RECOMMENDER_PID=$!

cleanup() {
  kill "$DJANGO_PID" "$RECOMMENDER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Django:     http://127.0.0.1:8000/health/"
echo "Recommender: http://127.0.0.1:8001/health"
wait "$DJANGO_PID" "$RECOMMENDER_PID"
