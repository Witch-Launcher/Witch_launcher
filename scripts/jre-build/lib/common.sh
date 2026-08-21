#!/bin/bash
# Shared helpers for the JRE build scripts.
set -euo pipefail

log()  { echo -e "\033[1;34m[jre-build]\033[0m $*"; }
warn() { echo -e "\033[1;33m[jre-build][warn]\033[0m $*"; }
fail() { echo -e "\033[1;31m[jre-build][error]\033[0m $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

# Resolve the number of parallel jobs.
jobs_count() {
  if [[ -n "${JRE_JOBS:-}" ]]; then
    echo "$JRE_JOBS"
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.logicalcpu 2>/dev/null || echo 4
  elif command -v nproc >/dev/null 2>&1; then
    nproc 2>/dev/null || echo 4
  else
    echo 4
  fi
}

# Verify we are on macOS with the iPhoneOS SDK available.
require_ios_toolchain() {
  require_cmd xcrun
  xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1 \
    || fail "iPhoneOS SDK not found (run xcodebuild -runFirstLaunch or install Xcode)"
}

# Convert a version to its OpenJDK configure target triple, matching upstream.
target_triple() {
  case "$1" in
    8)  echo "aarch64-apple-darwin18.2" ;;
    17|21|25) echo "aarch64-apple-ios" ;;
    *)  fail "unsupported TARGET_VERSION: $1" ;;
  esac
}

# Where the JDK source for a version is cloned (shared cache, survives `make clean`).
src_dir() { echo "$(repo_root)/depends/jre-src/openjdk-$1"; }

# Work directory for a single version (extracted into depends/java-<ver>-openjdk).
work_dir() { echo "$(repo_root)/depends/jre-work/$1"; }

repo_root() {
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  echo "$d"
}