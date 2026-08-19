#!/usr/bin/env bash
# Downloads the iOS-built OpenJDK 25 from assets.angelauramc.dev
#
# The release is a .zip containing a .tar.xz with the JRE contents.

set -euo pipefail

JRE_URL="${JRE_URL:-https://assets.angelauramc.dev/openjdk/ios-arm64/jre25-ios-aarch64.zip}"
DEST_DIR="${DEST_DIR:-$(cd "$(dirname "$0")/.." && pwd)/depends/java-25-openjdk}"
WORK_DIR="${WORK_DIR:-$(mktemp -d -t jre25-XXXXXX)}"

if [ -f "$DEST_DIR/release" ] && [ -f "$DEST_DIR/lib/server/libjvm.dylib" ]; then
    echo "[jre25] $DEST_DIR already present, skipping download"
    exit 0
fi

echo "[jre25] downloading iOS-built OpenJDK 25..."
echo "[jre25]   $JRE_URL"
curl -L --fail -o "$WORK_DIR/jre25.zip" "$JRE_URL"

echo "[jre25] extracting zip..."
cd "$WORK_DIR"
unzip -o jre25.zip
rm -f jre25.zip

# The zip should contain a .tar.xz file
TARBALL=(jre25-*.tar.xz)
if [ ! -f "${TARBALL[0]}" ]; then
    echo "[jre25] ERROR: no jre25-*.tar.xz found inside the zip"
    ls -la "$WORK_DIR"
    exit 1
fi

mkdir -p "$DEST_DIR"
echo "[jre25] extracting ${TARBALL[0]} to $DEST_DIR..."
tar xf "${TARBALL[0]}" -C "$DEST_DIR"

# Sanity check: libjvm.dylib must exist and be tagged iOS.
JVM="$DEST_DIR/lib/server/libjvm.dylib"
JLI="$DEST_DIR/lib/libjli.dylib"
for required in "$JVM" "$JLI"; do
    if [ ! -f "$required" ]; then
        echo "[jre25] ERROR: required dylib missing: $required"
        find "$DEST_DIR" -name "libjvm*.dylib" -o -name "libjli*.dylib" 2>/dev/null
        exit 1
    fi
done

# Verify it's an iOS Mach-O (not macOS retag).
if vtool -show "$JVM" 2>/dev/null | grep -q "platform IOS"; then
    echo "[jre25] confirmed: libjvm.dylib has platform IOS"
else
    echo "[jre25] WARNING: libjvm.dylib is not tagged as iOS. vtool output:"
    vtool -show "$JVM" || true
fi

echo "[jre25] patching libjvm mirror prepare breakpoint..."
python3 "$(cd "$(dirname "$0")" && pwd)/patch_libjvm_mirror_brk.py" "$JVM"

echo "[jre25] patching libjvm JIT allocation breakpoint..."
python3 "$(cd "$(dirname "$0")" && pwd)/patch_libjvm_jit_alloc.py" "$JVM"

rm -rf "$WORK_DIR"
echo "[jre25] done. Final size:"
du -sh "$DEST_DIR"
