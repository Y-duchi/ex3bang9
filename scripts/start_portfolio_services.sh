#!/bin/zsh
set -euo pipefail

BANG9_RUNTIME_DIR="${BANG9_RUNTIME_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/app-runtime}"
BANG9_VENV_DIR="${BANG9_VENV_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/venv}"
DJANGO_LOG="/private/tmp/bang9-portfolio-django.log"
RECOMMENDER_LOG="/private/tmp/bang9-portfolio-recommender.log"

if [[ "$(docker inspect -f '{{.State.Running}}' bang9-portfolio-db 2>/dev/null || true)" != "true" ]]; then
  docker start bang9-portfolio-db >/dev/null
fi

if ! curl -fsS http://127.0.0.1:8010/health/ >/dev/null 2>&1; then
  (
    cd "$BANG9_RUNTIME_DIR/backend"
    nohup "$BANG9_VENV_DIR/bin/python" manage.py runserver 0.0.0.0:8010 --noreload \
      >"$DJANGO_LOG" 2>&1 &
  )
fi

if ! curl -fsS http://127.0.0.1:8001/health >/dev/null 2>&1; then
  (
    cd "$BANG9_RUNTIME_DIR/backend"
    nohup "$BANG9_VENV_DIR/bin/python" -m uvicorn main:app --host 0.0.0.0 --port 8001 \
      >"$RECOMMENDER_LOG" 2>&1 &
  )
fi

for _ in {1..20}; do
  if curl -fsS http://127.0.0.1:8010/health/ >/dev/null \
    && curl -fsS http://127.0.0.1:8001/health >/dev/null; then
    print "Bang9 portfolio services are ready (Django :8010, recommender :8001)."
    exit 0
  fi
  sleep 1
done

print -u2 "Services did not become healthy. Check $DJANGO_LOG and $RECOMMENDER_LOG."
exit 1
