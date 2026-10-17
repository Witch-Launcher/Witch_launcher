#!/bin/bash
# FrameGen JNI Signature Verification
# Verifies the JNI method signatures match between Java and native code

echo "=== JNI Signature Verification ==="

JAVA_FILE="/Volumes/D/Angel-Aura-Amethyst-iOS/Angel-Aura-Amethyst-iOS/JavaApp/src/agent/net/kdt/pojavlaunch/framegen/FrameGenBridge.java"
NATIVE_FILE="/Volumes/D/Angel-Aura-Amethyst-iOS/Angel-Aura-Amethyst-iOS/Natives/framegen/framegen_jni_bridge.c"

echo "Checking Java native methods..."
grep -n "native " "$JAVA_FILE" | while read line; do
    echo "  Java: $line"
done

echo ""
echo "Checking JNI registrations..."
grep -n "Java_net_kdt_pojavlaunch" "$NATIVE_FILE" | while read line; do
    echo "  Native: $line"
done

echo ""
echo "Verifying signatures..."

# Extract Java method signatures
echo "Java signatures:"
grep -A1 "native " "$JAVA_FILE" | grep -E "updateCamera|isEnabled|setEnabled|isSupported" | sed 's/.*native //; s/;//'

# Extract native function names
echo "Native functions:"
grep "JNIEXPORT.*Java_net_kdt_pojavlaunch" "$NATIVE_FILE" | sed 's/.*Java_/Java_/' | sed 's/(.*//'

echo ""
echo "=== Verification Complete ==="