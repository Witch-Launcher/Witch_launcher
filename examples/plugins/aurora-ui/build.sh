#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
clang -arch arm64 -miphoneos-version-min=14.0 -isysroot "$SDKROOT" \
  -dynamiclib -fobjc-arc -fmodules \
  -I "$ROOT/Natives/PluginKit" -I "$ROOT/UI/App" -I "$ROOT/UI/Root" \
  -framework UIKit -framework Foundation -framework QuartzCore \
  -Wl,-undefined,dynamic_lookup \
  -o "$(dirname "$0")/AuroraUI.dylib" \
  "$(dirname "$0")/AuroraUI.m"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$(dirname "$0")/AuroraUI.dylib"
fi
