#!/bin/sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -dynamiclib -fobjc-arc -arch arm64 -miphoneos-version-min=14.0 -isysroot "$SDK" -I "$ROOT/Natives/PluginKit" -I "$ROOT/Natives" -framework UIKit -framework Foundation -Wl,-undefined,dynamic_lookup -o "$DIR/PEControls.dylib" "$DIR/PEControls.m"
codesign --force --sign - "$DIR/PEControls.dylib"
echo "$DIR/PEControls.dylib"
