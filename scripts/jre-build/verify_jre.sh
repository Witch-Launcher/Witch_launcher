#!/bin/bash
# Verify a built iOS JRE runtime matches what the launcher expects.
# Usage:
#   ./scripts/jre-build/verify_jre.sh <ver> [runtime-dir]
#   ver: 8 | 17 | 21 | 25
#   runtime-dir: default depends/java-<ver>-openjdk
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/jre-build/lib/common.sh"

VER="${1:-}"
[[ -n "$VER" ]] || fail "usage: $0 <8|17|21|25> [runtime-dir]"
case "$VER" in 8|17|21|25) : ;; *) fail "bad version $VER" ;; esac

DIR="${2:-$ROOT/depends/java-$VER-openjdk}"
[[ -d "$DIR" ]] || fail "runtime dir does not exist: $DIR"

fails="0"
ok()  { echo "  [ok] $*"; }
bad() { echo "  [FAIL] $*"; fails=$((fails+1)); }

echo "== Verify JRE $VER at $DIR"

# 1. release file
REL="$DIR/release"
[[ -f "$REL" ]] || { bad "missing release file"; exit 1; }
grep -q '^OS_NAME="Darwin"' "$REL" || bad "OS_NAME != Darwin"
grep -q '^OS_ARCH="aarch64"' "$REL" || bad "OS_ARCH != aarch64"
if grep -q '^JAVA_VERSION=' "$REL"; then
  ok "release: $(grep '^JAVA_VERSION=' "$REL" | head -1)"
else
  bad "missing JAVA_VERSION"
fi

# 2. libjvm / libjli layout
JVM="$DIR/lib/server/libjvm.dylib"
[[ -f "$JVM" ]] || { bad "missing lib/server/libjvm.dylib"; exit 1; }
ok "lib/server/libjvm.dylib present ($(du -h "$JVM" | cut -f1))"
if [[ "$VER" == "8" ]]; then
  [[ -f "$DIR/lib/jli/libjli.dylib" ]] && ok "lib/jli/libjli.dylib present (Java 8 layout)" || bad "missing lib/jli/libjli.dylib"
else
  [[ -f "$DIR/lib/libjli.dylib" ]] && ok "lib/libjli.dylib present" || bad "missing lib/libjli.dylib"
fi

# 3. Mach-O arch
if command -v lipo >/dev/null 2>&1; then
  ARCHS="$(lipo -archs "$JVM" 2>/dev/null || true)"
  case "$ARCHS" in
    *arm64*) ok "libjvm arch: $ARCHS" ;;
    *) bad "libjvm arch not arm64 ($ARCHS)" ;;
  esac
fi

# 4. Mach-O platform + min iOS (must be <= 14.0 to match the launcher target)
if command -v vtool >/dev/null 2>&1; then
  PLT="$(vtool -show-build -arch arm64 "$JVM" 2>/dev/null || true)"
  if echo "$PLT" | grep -q 'platform *IOS'; then
    ok "libjvm platform=IOS"
  else
    bad "libjvm platform != IOS"
  fi
  MINOS="$(echo "$PLT" | awk '/minos/{print $2; exit}')"
  if [[ -n "$MINOS" ]]; then
    if python3 "$ROOT/scripts/jre-build/check_minos.py" "$MINOS"; then
      ok "libjvm min iOS ${MINOS} (<= 14.0 required)"
    else
      bad "libjvm min iOS ${MINOS} > 14.0"
    fi
  else
    bad "could not read minos from vtool"
  fi
fi

# 5. mirror-mapping marker for 17/21/25 (launcher gates MirrorMappedCodeCache on it)
if [[ "$VER" != "8" ]]; then
  MARKER="$DIR/.witch-mirror-mapping"
  if [[ -f "$MARKER" ]] && [[ "$(cat "$MARKER")" == "witch-mirror-mapping-v1" ]]; then
    ok ".witch-mirror-mapping marker present (mirror mapped JIT)"
  else
    bad "missing/incorrect .witch-mirror-mapping"
  fi
else
  if [[ ! -e "$DIR/.witch-mirror-mapping" ]]; then
    ok "no mirror marker expected for Java 8"
  else
    bad "Java 8 must NOT carry .witch-mirror-mapping"
  fi
fi

# 6. patched libjvm for 21/25: printf replaced by brk #0x6a, and jit-alloc brk #0xf00d present
if [[ "$VER" == "21" || "$VER" == "25" ]]; then
  if python3 "$ROOT/scripts/jre-build/check_libjvm_patch.py" "$JVM"; then
    ok "libjvm binary-patched (mirror brk active)"
  else
    bad "libjvm binary-patch verification failed (run scripts/patch_libjvm_mirror_brk.py + scripts/patch_libjvm_jit_alloc.py)"
  fi
fi

if [[ "$fails" -gt 0 ]]; then
  echo "== VERIFY FAILED ($fails issue(s))" >&2
  exit 1
fi
echo "== VERIFY OK for JRE $VER"
exit 0