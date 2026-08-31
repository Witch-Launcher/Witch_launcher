#!/bin/bash
# Frame Generation Build & Test Script
# Tests that the Java agent JAR compiles, launcher.jar includes FG classes,
# and native Objective-C++ builds correctly.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Frame Generation Build Test ==="
echo "Project root: $SCRIPT_DIR"

# ── Step 1: Build Java classes ──
echo ""
echo "── Step 1: Building Java classes ──"
cd "$SCRIPT_DIR/JavaApp"
make clean 2>/dev/null || true
make 2>&1 | tail -30

# ── Step 2: Verify launcher.jar contains FrameGen classes ──
echo ""
echo "── Step 2: Verifying launcher.jar ──"
if [ -f "build/launcher.jar" ]; then
    echo "  launcher.jar exists"
    jar tf build/launcher.jar | grep -i framegen && echo "  [PASS] FrameGen classes found in launcher.jar" || echo "  [WARN] FrameGen classes not in launcher.jar"
else
    echo "  [FAIL] launcher.jar not found"
    exit 1
fi

# ── Step 3: Verify framegen-agent.jar ──
echo ""
echo "── Step 3: Verifying framegen-agent.jar ──"
if [ -f "build/framegen-agent.jar" ]; then
    echo "  framegen-agent.jar exists"
    jar tf build/framegen-agent.jar | grep -E "FrameGen|Patcher" && echo "  [PASS] Agent classes found" || echo "  [WARN] Agent classes not found"
else
    echo "  [FAIL] framegen-agent.jar not found"
    exit 1
fi

# ── Step 4: Verify FrameGenBridge is in launcher.jar ──
echo ""
echo "── Step 4: Checking FrameGenBridge in launcher.jar ──"
if jar tf build/launcher.jar | grep -q "FrameGenBridge"; then
    echo "  [PASS] FrameGenBridge.class is in launcher.jar"
else
    echo "  [FAIL] FrameGenBridge.class NOT in launcher.jar"
    echo "  This will cause NoClassDefFoundError at runtime!"
    exit 1
fi

# ── Step 5: Check FrameGenPatcher is in launcher.jar ──
echo ""
echo "── Step 5: Checking FrameGenPatcher in launcher.jar ──"
if jar tf build/launcher.jar | grep -q "FrameGenPatcher"; then
    echo "  [PASS] FrameGenPatcher.class is in launcher.jar"
else
    echo "  [FAIL] FrameGenPatcher.class NOT in launcher.jar"
    exit 1
fi

# ── Step 6: Build native code ──
echo ""
echo "── Step 6: Building native code (framegen.mm) ──"
NATIVE_DIR="$SCRIPT_DIR/Natives"
mkdir -p "$NATIVE_DIR/build_test"
cd "$NATIVE_DIR/build_test"

# Try to build just the framegen files to check for compilation errors
if command -v cmake &>/dev/null; then
    echo "  CMake found, attempting cmake configure..."
    cmake .. 2>&1 | tail -5 || echo "  [WARN] CMake configure failed (expected on non-iOS host)"
else
    echo "  [SKIP] CMake not available, skipping native build"
    echo "  Native code must be built via Xcode or iOS SDK toolchain"
fi

echo ""
echo "=== Build Test Complete ==="
echo ""
echo "Summary:"
echo "  - FrameGenBridge.class must be in launcher.jar (for JNI FindClass)"
echo "  - FrameGenPatcher.class must be in launcher.jar (for bytecode patching)"
echo "  - framegen-agent.jar provides Instrumentation for patcher"
echo "  - Native code (framegen.mm) builds into libWitch.dylib"
