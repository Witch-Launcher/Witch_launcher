#!/bin/bash
# Checks the Vietnamese (Telex) composition engine without a device.
#
# The engine (Natives/input/TelexComposer.m) is free of UIKit, so it can be
# compiled and run on the build host. The test simulates the game side text
# field: it removes one character per delete event, exactly like Minecraft's
# EditBox does when it receives a backspace key event.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INPUT_DIR="${ROOT_DIR}/Natives/input"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if ! command -v clang >/dev/null 2>&1; then
    echo "clang is required" >&2
    exit 1
fi

clang -fobjc-arc -I"${INPUT_DIR}" -framework Foundation \
    -o "${WORK_DIR}/telex_composition_test" \
    "${SCRIPT_DIR}/telex_composition_test.m" "${INPUT_DIR}/TelexComposer.m"

"${WORK_DIR}/telex_composition_test"
