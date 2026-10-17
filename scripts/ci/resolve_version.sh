#!/usr/bin/env bash
# Resolve app version for Witch auto-release bot.
# Reads CFBundleShortVersionString from Natives/Info.plist (via python plistlib,
# works on macOS + Linux runners where `plutil` is unavailable), then appends
# branch / short SHA / date / run number metadata.
#
# Outputs (to $GITHUB_OUTPUT and $GITHUB_ENV when present, else stdout):
#   APP_VERSION  e.g. 0.0.2-beta.429536e-20260926-b42
#   BASE_VERSION e.g. 0.0.2
#   SHORT_SHA    e.g. 429536e
#   BUILD_DATE   e.g. 20260926
#   BUILD_TAG    e.g. beta-429536e-42  (branch-sha-run)
#
# Usage:
#   bash scripts/ci/resolve_version.sh
# Env overrides: BRANCH_NAME, COMMIT_SHA, RUN_NUMBER
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLIST="$REPO_ROOT/Natives/Info.plist"

BRANCH="${BRANCH_NAME:-${GITHUB_REF_NAME:-beta}}"
SHA_FULL="${COMMIT_SHA:-${GITHUB_SHA:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}}"
RUN_NUM="${RUN_NUMBER:-${GITHUB_RUN_NUMBER:-0}}"
SHORT_SHA="$(echo "$SHA_FULL" | cut -c1-7)"
BUILD_DATE="$(date -u +%Y%m%d)"

BASE_VERSION="$(python3 -c "
import plistlib, sys
try:
    with open('$PLIST','rb') as f:
        print(plistlib.load(f).get('CFBundleShortVersionString','0.0.2'))
except Exception as e:
    print('0.0.2', file=sys.stderr)
    print('0.0.2')
")"

# Normalize branch: beta -> beta, main/master -> stable
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  APP_VERSION="${BASE_VERSION}-${SHORT_SHA}-${BUILD_DATE}"
  BUILD_TAG="stable-${SHORT_SHA}-${RUN_NUM}"
else
  APP_VERSION="${BASE_VERSION}-beta.${SHORT_SHA}-${BUILD_DATE}-b${RUN_NUM}"
  BUILD_TAG="beta-${SHORT_SHA}-${RUN_NUM}"
fi

emit() {
  local k="$1" v="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$k=$v" >> "$GITHUB_OUTPUT"; fi
  if [ -n "${GITHUB_ENV:-}" ]; then echo "$k=$v" >> "$GITHUB_ENV"; fi
  echo "$k=$v"
}

emit "BASE_VERSION" "$BASE_VERSION"
emit "APP_VERSION" "$APP_VERSION"
emit "SHORT_SHA" "$SHORT_SHA"
emit "BUILD_DATE" "$BUILD_DATE"
emit "BUILD_TAG" "$BUILD_TAG"
