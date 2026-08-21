#!/bin/bash
# Set environment variables for the OpenJDK iOS build scripts.
# Merged from:
#   - AngelAuraMC/angelauramc-openjdk-build (buildjre8)   for JDK 8
#   - PojavLauncherTeam/android-openjdk-build-multiarch   for 17/21
#   - AngelAuraMC/angelauramc-openjdk-build (duy/buildjre17-21-25-ios) for 25
# Simplified: this vendored copy targets iOS aarch64 only.

if [[ -z "$TARGET_VERSION" ]]; then
  echo "ERROR: TARGET_VERSION is not set (8, 17, 21 or 25)" >&2
  exit 1
fi

export TARGET_JDK=aarch64

if [[ -z "$JVM_VARIANTS" ]]; then
  export JVM_VARIANTS=server
fi

if [[ -z "$JDK_DEBUG_LEVEL" ]]; then
  export JDK_DEBUG_LEVEL=release
fi

if [[ -z "$BUILD_FREETYPE_VERSION" ]]; then
  if [[ "$TARGET_VERSION" -eq 8 ]]; then
    export BUILD_FREETYPE_VERSION="2.10.4"
  else
    export BUILD_FREETYPE_VERSION="2.10.0"
  fi
fi

# Boot JDK resolution. Same-major boot JDKs reproduce the upstream artifacts
# (jdk-jdk8u/corretto for 8, temurin/any 17/21/25 for the rest). Override each
# with JRE_BOOT_8 / JRE_BOOT_17 / JRE_BOOT_21 / JRE_BOOT_25 or set BOOT_JDK.
if [[ -z "$BOOT_JDK" ]]; then
  case "$TARGET_VERSION" in
    8)  BOOT_JDK=${JRE_BOOT_8:-$(/usr/libexec/java_home -v 1.8 2>/dev/null)} ;;
    17) BOOT_JDK=${JRE_BOOT_17:-$(/usr/libexec/java_home -v 17 2>/dev/null)} ;;
    21) BOOT_JDK=${JRE_BOOT_21:-$(/usr/libexec/java_home -v 21 2>/dev/null)} ;;
    25) BOOT_JDK=${JRE_BOOT_25:-$(/usr/libexec/java_home -v 25 2>/dev/null)} ;;
  esac
fi
if [[ -z "$BOOT_JDK" || ! -x "$BOOT_JDK/bin/javac" ]]; then
  echo "ERROR: boot JDK $TARGET_VERSION not found (BOOT_JDK=$BOOT_JDK). Install it or set JRE_BOOT_$TARGET_VERSION." >&2
  exit 1
fi
export BOOT_JDK
export JAVA_HOME=$BOOT_JDK

# Host + iOS SDK toolchain
export thecc=$(xcrun -find -sdk iphoneos clang)
export thecxx=$(xcrun -find -sdk iphoneos clang++)
export thesysroot=$(xcrun --sdk iphoneos --show-sdk-path)
export themacsysroot=$(xcrun --sdk macosx --show-sdk-path)

export thehostcxx=$PWD/lib/macos-host-cc
export CC=$PWD/lib/ios-arm64-clang
export CXX=$PWD/lib/ios-arm64-clang++
export CXXCPP="$CXX -E"
export LD=$(xcrun -find -sdk iphoneos ld)

export HOTSPOT_DISABLE_DTRACE_PROBES=1

export ANDROID_INCLUDE=$PWD/lib/ios-missing-include
export TARGET_OS=ios
export JVM_PLATFORM=macosx
export TARGET_SHORT=arm64