#!/usr/bin/env bash
# 웹 미리보기: 웹 빌드 후 포트(기본 8080)로 서빙. 코드를 바꾸면 다시 실행.
#   tool/serve_web.sh [포트]
set -e
PORT="${1:-8080}"
cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/flutter/bin"
flutter build web --release --no-wasm-dry-run >/dev/null
pkill -f "http.server $PORT" 2>/dev/null || true
if [ -n "$CODESPACE_NAME" ]; then
  echo "미리보기: https://$CODESPACE_NAME-$PORT.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
else
  echo "미리보기: http://localhost:$PORT"
fi
exec python3 -m http.server "$PORT" --bind 0.0.0.0 -d build/web
