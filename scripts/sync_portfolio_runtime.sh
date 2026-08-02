#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${BANG9_RUNTIME_DIR:-/Users/yeoduchi/.cache/bang9-portfolio/app-runtime}"

mkdir -p "$RUNTIME_DIR"

# The repository itself lives in a macOS-synced Documents folder. A shallow,
# read-only clone in the local cache avoids per-file hydration delays.
if [[ ! -f "$RUNTIME_DIR/.bang9-baseline-ready" ]]; then
  if [[ ! -d "$RUNTIME_DIR/.git" ]]; then
    git clone \
      --depth 1 \
      --filter=blob:none \
      --no-checkout \
      https://github.com/Y-duchi/ex3bang9.git \
      "$RUNTIME_DIR"
  fi
  git -c maintenance.auto=false -c gc.auto=0 -C "$RUNTIME_DIR" checkout HEAD -- \
    README.md analysis_options.yaml pubspec.yaml pubspec.lock .metadata \
    assets lib test backend/manage.py backend/main.py backend/config \
    backend/users backend/furniture backend/cart backend/community \
    backend/orders backend/reviews backend/report backend/inquiry \
    backend/notification backend/search \
    ios/Flutter ios/Podfile ios/Runner ios/Runner.xcodeproj ios/Runner.xcworkspace
  touch "$RUNTIME_DIR/.bang9-baseline-ready"
fi

OVERLAY_FILES=(
  PORTFOLIO_DEMO.md
  pubspec.yaml
  pubspec.lock
  backend/.env.example
  backend/.env.local
  backend/requirements.txt
  backend/config/local_env.py
  backend/config/settings.py
  backend/config/urls.py
  backend/main.py
  backend/scripts/seed_portfolio_demo.py
  lib/constants.dart
  lib/firebase_options.dart
  lib/login/login_screen.dart
  lib/main.dart
  lib/shopping/ar_page.dart
  lib/shopping/product_detail.dart
  lib/top_bar/top_bar.dart
  lib/user/Address_management_page.dart
  ios/Runner/AppDelegate.swift
  ios/Runner/Info.plist
  ios/Runner/models.scnassets
  ios/Runner.xcodeproj/project.pbxproj
  ios/Flutter/Debug.xcconfig
  ios/Flutter/Release.xcconfig
  ios/Flutter/Secrets.xcconfig
  android/app/build.gradle
  android/app/src/main/AndroidManifest.xml
  backend/media
  scripts/restore_portfolio_db.sh
  scripts/run_portfolio_ios.sh
  scripts/start_portfolio_backend.sh
  scripts/sync_portfolio_runtime.sh
)

EXISTING_OVERLAY_FILES=()
for path in "${OVERLAY_FILES[@]}"; do
  if [[ -e "$SOURCE_DIR/$path" ]]; then
    EXISTING_OVERLAY_FILES+=("$path")
  fi
done

(
  cd "$SOURCE_DIR"
  rsync -aR "${EXISTING_OVERLAY_FILES[@]}" "$RUNTIME_DIR/"
)
chmod +x "$RUNTIME_DIR"/scripts/*.sh

echo "$RUNTIME_DIR"
