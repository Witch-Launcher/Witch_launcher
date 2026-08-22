#!/bin/bash
# Build a JRE for iOS arm64 from OpenJDK source and produce
#   depends/jre<ver>-ios-arm64-<date>-release.tar.xz
# in the exact layout the launcher Makefile expects.
#
# Usage:
#   ./scripts/jre-build/build.sh [8] [17] [21] [25]   (or "all")
#
# Environment:
#   JRE_BOOT_8/17/21/25   boot JDK home per version (default: /usr/libexec/java_home -v X)
#   JRE_JOBS              parallel jobs (default: hw.logicalcpu)
#   JRE_FORCE_REFRESH=1   force re-clone/re-patch
#   JRE_VERBOSE=1         verbose output
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT/scripts/jre-build"
THIRDPARTY="$ROOT/depends/jre-src/third_party"

source "$BUILD_DIR/lib/common.sh"

JOBS=$(jobs_count)
export JOB_COUNT=$JOBS

# Subphase root used while assembling the JRE image.
WORK="$ROOT/depends/jre-work"

clone_url() {
  case "$1" in
    8)  echo "--depth 1 --branch 8.472.08.1 https://github.com/corretto/corretto-8" ;;
    17) echo "--depth 1 https://github.com/openjdk/jdk17u" ;;
    21) echo "--branch jdk-21.0.8+7 --depth 1 https://github.com/openjdk/jdk21u" ;;
    25) echo "--depth 1 https://github.com/openjdk/jdk25u" ;;
  esac
}

fetch_thirdparty() {
  local ver="$1"
  mkdir -p "$THIRDPARTY"
  if [[ ! -d "$THIRDPARTY/cups-2.2.4" ]]; then
    log "[$ver] fetching cups-2.2.4 ..."
    ( cd "$THIRDPARTY" \
      && curl -fsSL -o cups.tar.gz \
          https://github.com/apple/cups/releases/download/v2.2.4/cups-2.2.4-source.tar.gz \
      && tar xzf cups.tar.gz && rm -f cups.tar.gz )
  fi
  if [[ "$ver" == "8" && ! -d "$THIRDPARTY/freetype-$BUILD_FREETYPE_VERSION" ]]; then
    log "[$ver] fetching freetype-$BUILD_FREETYPE_VERSION ..."
    ( cd "$THIRDPARTY" \
      && curl -fsSL -o ft.tar.gz \
          "https://downloads.sourceforge.net/project/freetype/freetype2/$BUILD_FREETYPE_VERSION/freetype-$BUILD_FREETYPE_VERSION.tar.gz" \
      && tar xzf ft.tar.gz && rm -f ft.tar.gz )
  fi
}

clonejdk() {
  local ver="$1"
  local dst="$ROOT/depends/jre-src/openjdk-$ver"
  if [[ -d "$dst/.git" && "${JRE_FORCE_REFRESH:-0}" != "1" ]]; then
    log "[$ver] using cached source at $dst"
    return
  fi
  rm -rf "$dst"
  log "[$ver] cloning OpenJDK $ver ..."
  # shellcheck disable=SC2086
  git clone -q $(clone_url "$ver") "$dst"
}

apply_patches() {
  local ver="$1"
  local srcdir="$2"
  cd "$srcdir"
  git reset --hard >/dev/null 2>&1 || true
  git clean -fdqx >/dev/null 2>&1 || true
  log "[$ver] applying iOS patches"
  case "$ver" in
    8)
      for p in jdk8u_ios.diff jdk8u_ios_xattr.diff jdk8u_ios_fix_clang.diff jdk8u_ios_mirror_mapping.diff; do
        log "[$ver]   patches/jre_8/ios/$p"
        git apply --reject --whitespace=fix "$BUILD_DIR/patches/jre_8/ios/$p" \
          || fail "git apply failed: $p"
      done
      ;;
    17)
      log "[$ver]   patches/jre_17/ios/jdk17u_ios.diff"
      git apply --reject --whitespace=fix "$BUILD_DIR/patches/jre_17/ios/jdk17u_ios.diff" \
        || fail "git apply failed"
      ;;
    21)
      log "[$ver]   patches/jre_21/ios/jdk21u_ios.diff"
      git apply --reject --whitespace=fix "$BUILD_DIR/patches/jre_21/ios/jdk21u_ios.diff" \
        || fail "git apply failed"
      ;;
    25)
      # No upstream iOS diff exists for 25; reuse the 21u set (mostly applies
      # with rejects) then force the remaining hunks and run the JDK25 fixups
      # that complete the mirror_w/mirror_x wrapping for the JIT.
      log "[$ver]   patches/jre_21/ios/jdk21u_ios.diff (rejects expected)"
      git apply --reject --whitespace=fix "$BUILD_DIR/patches/jre_21/ios/jdk21u_ios.diff" || true
      log "[$ver]   apply_rejs.py (force-apply leftover hunks)"
      ( cd "$srcdir" && python3 "$BUILD_DIR/apply_rejs.py" ) || fail "apply_rejs failed"
      log "[$ver]   jdk25_ios_fixups.py (mirror wrapping + macosx_NOTIOS)"
      ( cd "$srcdir" && python3 "$BUILD_DIR/jdk25_ios_fixups.py" ) || fail "jdk25_ios_fixups failed"
      ;;
  esac

  # Excluding the macOS desktop natives mirrors upstream and avoids pulling in
  # AppKit/ApplicationServices symbols that do not exist on iOS.
  local dsrc="$srcdir/src/java.desktop/macosx"
  if [[ -d "$dsrc" ]]; then
    mv "$dsrc" "$dsrc"_NOTIOS
    mkdir -p "$dsrc/native"
    if [[ -d "$dsrc"_NOTIOS/native/libjsound ]]; then
      mv "$dsrc"_NOTIOS/native/libjsound "$dsrc/native/"
    fi
  fi
}

build_freetype_8() {
  local ftdir="$THIRDPARTY/freetype-$BUILD_FREETYPE_VERSION"
  local prefix="$ftdir/build_android-arm64"
  local liba="$prefix/lib/libfreetype.a"
  [[ -f "$liba" ]] && { log "[8] freetype cached at $liba"; return; }
  log "[8] building freetype-$BUILD_FREETYPE_VERSION (static)"
  ( cd "$ftdir" \
      && ./configure --host="$TARGET" --prefix="$PWD/build_android-arm64" \
          --enable-shared=no --enable-static=yes \
          --without-zlib --with-brotli=no --with-png=no --with-harfbuzz=no \
          "CFLAGS=-arch arm64 -pipe -std=c99 -Wno-trigraphs -fpascal-strings -Os -Wreturn-type -Wunused-variable -fmessage-length=0 -fvisibility=hidden -miphoneos-version-min=14.0 -I$thesysroot/usr/include/libxml2/ -isysroot $thesysroot -DByte=uint8_t" \
          "LDFLAGS=-arch arm64 -isysroot $thesysroot -miphoneos-version-min=14.0" \
          AR=/usr/bin/ar \
      && CFLAGS=-fno-rtti CXXFLAGS=-fno-rtti make -j"$JOBS" \
      && make install )
  [[ -f "$liba" ]] || fail "freetype static build failed"
}

build_version() {
  local ver="$1"
  case "$ver" in 8|17|21|25) : ;; *) fail "unsupported version: $ver (want 8|17|21|25)" ;; esac

  log "==================== Building JRE $ver ===================="
  require_ios_toolchain
  export TARGET_VERSION="$ver"
  cd "$BUILD_DIR"
  # shellcheck disable=SC1091
  source "$BUILD_DIR/setdevkitpath.sh"
  TARGET="$(target_triple "$ver")"
  export TARGET TARGET_PHYS="$TARGET"

  log "[$ver] TARGET=$TARGET boot=$BOOT_JDK jobs=$JOBS"
  fetch_thirdparty "$ver"
  clonejdk "$ver"

  local srcdir="$ROOT/depends/jre-src/openjdk-$ver"
  apply_patches "$ver" "$srcdir"

  if [[ "$ver" == "8" ]]; then
    build_freetype_8
  fi

  local FREETYPE_DIR="$THIRDPARTY/freetype-$BUILD_FREETYPE_VERSION/build_android-arm64"
  local CUPS_DIR="$THIRDPARTY/cups-2.2.4"
  ln -sfn "$CUPS_DIR/cups" "$BUILD_DIR/lib/ios-missing-include/cups" || true

  # jdk8u honours user-supplied pkg-config style variables and skips its own
  # (cross-unfriendly) freetype probing when these are present. Point them at
  # the vendored static build explicitly.
  if [[ "$ver" == "8" ]]; then
    export FREETYPE_CFLAGS="-I$FREETYPE_DIR/include/freetype2 -arch arm64 -isysroot $thesysroot -miphoneos-version-min=14.0"
    export FREETYPE_LIBS="$FREETYPE_DIR/lib/libfreetype.a -arch arm64 -isysroot $thesysroot"
  fi

  # ---- configure ----
  local CFLAGS="-arch arm64 -DHEADLESS=1 -I$BUILD_DIR/lib/ios-missing-include -Wno-implicit-function-declaration"
  [[ "$ver" == "8" ]] && CFLAGS+=" -Wno-c++11-narrowing -Wno-reserved-user-defined-literal -Wno-shift-negative-value"

  cd "$srcdir"
  local common=(
    --openjdk-target="$TARGET"
    --with-extra-cflags="$CFLAGS"
    --with-extra-cxxflags="$CFLAGS"
    --with-extra-ldflags="-arch arm64"
    --disable-precompiled-headers
    --enable-option-checking=fatal
    --with-jvm-variants="$JVM_VARIANTS"
    --with-native-debug-symbols=external
    --with-debug-level="$JDK_DEBUG_LEVEL"
    --x-includes="$BUILD_DIR/lib/ios-missing-include"
  )
  # JDK 9+ configure-only flags; Corretto/OpenJDK 8 rejects them outright.
  if [[ "$ver" != "8" ]]; then
    common+=( --disable-warnings-as-errors
              --enable-headless-only=yes )
  fi
  local extra=()
  if [[ "$ver" == "8" ]]; then
    extra=( --with-toolchain-type=clang SDKNAME=iphoneos
            --with-freetype-include="$FREETYPE_DIR/include/freetype2"
            --with-freetype-lib="$FREETYPE_DIR/lib"
            --with-cups-include="$CUPS_DIR" )
  else
    extra=( --with-toolchain-type=clang
            --with-sysroot="$thesysroot"
            --with-boot-jdk="$BOOT_JDK"
            --with-freetype=bundled
            --with-jvm-features=-dtrace,-zero,-vm-structs,-epsilongc )
  fi
  log "[$ver] configuring ..."
  bash ./configure "${common[@]}" "${extra[@]}" --x-libraries=/usr/lib || {
    echo "CONFIGURE ERROR; dumping config.log:"; cat config.log 2>/dev/null || true; exit 1
  }

  # ---- build images ----
  local builddir="build/${JVM_PLATFORM}-${TARGET_JDK}-${JVM_VARIANTS}-${JDK_DEBUG_LEVEL}"
  [[ "$ver" == "8" ]] && builddir="build/${JVM_PLATFORM}-${TARGET_JDK}-normal-${JVM_VARIANTS}-${JDK_DEBUG_LEVEL}"
  local images="$srcdir/$builddir/images"
  log "[$ver] building images (dir=$builddir, $JOBS jobs) ..."
  cd "$srcdir/$builddir"
  make JOBS=$JOBS images || { warn "[$ver] first attempt failed, retrying (upstream quirk)"; make JOBS=$JOBS images; }

  # ---- assemble JRE ----
  rm -rf "$WORK/$ver"
  mkdir -p "$WORK/$ver"
  local jdkout="$WORK/$ver/jdkout"
  local jreout="$WORK/$ver/jreout"
  if [[ "$ver" == "8" ]]; then
    cp -r "$images/j2re-image" "$jreout"
  else
    cp -r "$images/jdk" "$jdkout"
    local modules="java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,jdk.accessibility,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.httpserver,jdk.jdwp.agent,jdk.jfr,jdk.jsobject,jdk.localedata,jdk.management,jdk.management.agent,jdk.management.jfr,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.nio.mapmode,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs,jdk.internal.vm.ci"
    jlink \
      --module-path="$jdkout/jmods" \
      --add-modules "$modules" \
      --output "$jreout" \
      --strip-debug \
      --no-man-pages \
      --no-header-files \
      --release-info="$jdkout/release" \
      --compress=0
  fi

  # ---- override fonts/fontconfig ----
  cp -R "$BUILD_DIR/jre_override/lib/." "$jreout/lib/"

  # ---- dylib identity + signing ----
  local freetype_dylib="$FREETYPE_DIR/lib/libfreetype.dylib"
  if [[ "$ver" == "8" ]]; then
    local jrelib="$jreout/lib"
    install_name_tool -id @rpath/libfreetype.dylib "$jrelib/libfreetype.dylib" || true
    install_name_tool -change "$freetype_dylib" @rpath/libfreetype.dylib "$jrelib/libfontmanager.dylib" || true
  else
    install_name_tool -id @rpath/libfreetype.dylib "$jdkout/lib/libfreetype.dylib" || true
    install_name_tool -id @rpath/libfreetype.dylib "$jreout/lib/libfreetype.dylib" || true
    install_name_tool -change "$freetype_dylib" @rpath/libfreetype.dylib "$jdkout/lib/libfontmanager.dylib" || true
    install_name_tool -change "$freetype_dylib" @rpath/libfreetype.dylib "$jreout/lib/libfontmanager.dylib" || true
  fi
  for dafile in $(find "$jdkout" "$jreout" -name "*.dylib" 2>/dev/null); do
    install_name_tool -add_rpath @loader_path -add_rpath @loader_path/jli -add_rpath @loader_path/server \
      -add_rpath @loader_path/.. -add_rpath @loader_path/../jli -add_rpath @loader_path/../server "$dafile" || true
    ldid -S"$BUILD_DIR/ios-sign-entitlements.xml" "$dafile" || true
  done
  for f in "$jdkout"/bin/* "$jreout"/bin/* ; do
    ldid -S"$BUILD_DIR/ios-sign-entitlements.xml" "$f" || true
  done

  # ---- package tar.xz (consumed by the Makefile) ----
  local outdate; outdate=$(date +%Y%m%d)
  local tarball="$ROOT/depends/jre${ver}-ios-arm64-${outdate}-${JDK_DEBUG_LEVEL}.tar.xz"
  log "[$ver] packaging $tarball"
  cd "$jreout"
  rm -f "$tarball"
  tar cJf "$tarball" .
  log "[$ver] done -> $tarball"
  rm -rf "$WORK/$ver"
}

main() {
  local vers=()
  for a in "$@"; do
    if [[ "$a" == "all" ]]; then vers+=(8 17 21 25); else vers+=("$a"); fi
  done
  if [[ ${#vers[@]} -eq 0 ]]; then
    echo "usage: $0 [8] [17] [21] [25] | all" >&2
    exit 1
  fi
  for v in "${vers[@]}"; do
    build_version "$v"
  done
}

main "$@"