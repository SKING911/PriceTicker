#!/usr/bin/env bash
set -euo pipefail

XCODEGEN_VERSION="2.38.0"
XCODEGEN_BIN="/tmp/xcodegen/bin/xcodegen"

if [ ! -f "$XCODEGEN_BIN" ]; then
  echo "→ Downloading XcodeGen $XCODEGEN_VERSION..."
  mkdir -p /tmp/xcodegen
  curl -L "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" \
    -o /tmp/xcodegen.zip
  unzip -q /tmp/xcodegen.zip -d /tmp/xcodegen
  chmod +x "$XCODEGEN_BIN"
fi

echo "→ Generating Xcode project..."
"$XCODEGEN_BIN" generate

echo "→ Building..."
xcodebuild -scheme PriceTicker -configuration Debug build | grep -E "error:|BUILD|warning:"

echo "✓ Done. App at: build/Debug/PriceTicker.app"
