#!/bin/zsh
set -euo pipefail

BANG9_RUNTIME_DIR="${BANG9_RUNTIME_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/app-runtime}"
MAC_LAN_IP="${BANG9_MAC_IP:-$(ipconfig getifaddr en0 2>/dev/null || true)}"

if [[ -z "$MAC_LAN_IP" ]]; then
  MAC_LAN_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

if [[ -z "$MAC_LAN_IP" ]]; then
  print -u2 "Mac LAN IP를 찾지 못했습니다. Mac과 iPhone을 같은 Wi-Fi에 연결하세요."
  exit 1
fi

DEVICE_ID="${1:-${BANG9_DEVICE_ID:-}}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(
    flutter devices --machine \
      | /usr/bin/ruby -rjson -e 'devices = JSON.parse(STDIN.read); ios = devices.find { |d| d["targetPlatform"].to_s.start_with?("ios") }; puts ios["id"] if ios'
  )"
fi

if [[ -z "$DEVICE_ID" ]]; then
  print -u2 "iPhone을 찾지 못했습니다. 잠금 해제 후 Mac을 신뢰하고 다시 실행하세요."
  exit 1
fi

cd "$BANG9_RUNTIME_DIR"
flutter build ios --profile \
  --dart-define=PORTFOLIO_DEMO=true \
  --dart-define="API_BASE_URL=http://$MAC_LAN_IP:8010"

xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  build/ios/iphoneos/Runner.app

exec xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  com.yeoduchi.bang9test
