#!/usr/bin/env python3
"""Enable debugger-backed mirror mappings in the pinned JRE 17 and 21 builds.

Both bundled runtimes already contain Amethyst's MirrorMappedCodeCache support,
but their DeviceRequiresTXMWorkaround implementations predate the iOS 26.6
Preboot permission change. JRE 17 returns false and skips the debugger mapping;
JRE 21 dereferences the failed opendir result. The launcher only enables the
option after it has established the Universal JIT protocol, so the detector is
replaced with an unconditional true return.

The full-file hashes, patch offsets, and expected instruction bytes pin this
bridge to the exact published runtimes. Unknown or partially modified binaries
are rejected rather than patched heuristically.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from dataclasses import dataclass
from pathlib import Path


ORIGINAL_PREFIX = bytes.fromhex(
    "fc6fbda9"  # stp x28, x27, [sp, #-0x30]!
    "f44f01a9"  # stp x20, x19, [sp, #0x10]
    "fd7b02a9"  # stp x29, x30, [sp, #0x20]
    "fd830091"  # add x29, sp, #0x20
)
RETURN_TRUE = bytes.fromhex(
    "20008052"  # mov w0, #1
    "c0035fd6"  # ret
)
MARKER_NAME = ".witch-mirror-mapping"
MARKER_CONTENT = "witch-mirror-mapping-v1\n"


@dataclass(frozen=True)
class RuntimePatch:
    detector_offset: int
    original_sha256: str
    patched_sha256: str


RUNTIMES = {
    17: RuntimePatch(
        detector_offset=0x7B3CD0,
        original_sha256=(
            "c78b4d75f9ab385cf8c5c936bd925816"
            "31c4a1491ac0208d7e4519e1312b07ab"
        ),
        patched_sha256=(
            "84cc7bc661d27c04f9d1fd178cd258013"
            "3198826c811e52c16c428ee71c3de50"
        ),
    ),
    21: RuntimePatch(
        detector_offset=0x81FB8C,
        original_sha256=(
            "628ecae014da8029f4b9182ca4eacb53"
            "c71c42a95e66f88cb7f09164f76a2c35"
        ),
        patched_sha256=(
            "6c56f8af7b967088baf06ea812add9593"
            "d6b88fcb849a8afae0df688ba7264bd"
        ),
    ),
}


class PatchError(RuntimeError):
    pass


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _marker_path(libjvm: Path) -> Path:
    try:
        return libjvm.parents[2] / MARKER_NAME
    except IndexError as error:
        raise PatchError("libjvm path is not inside a Java runtime") from error


def patch_runtime(
    runtime_version: int,
    libjvm: Path,
    check_only: bool = False,
) -> str:
    profile = RUNTIMES[runtime_version]
    data = libjvm.read_bytes()
    digest = _sha256(data)
    marker = _marker_path(libjvm)

    if digest == profile.patched_sha256:
        if data[
            profile.detector_offset:
            profile.detector_offset + len(RETURN_TRUE)
        ] != RETURN_TRUE:
            raise PatchError("patched hash has an unexpected detector body")
        if check_only and marker.read_text(errors="replace") != MARKER_CONTENT:
            raise PatchError(f"runtime marker is missing or invalid: {marker}")
        if not check_only:
            marker.write_text(MARKER_CONTENT)
        return "already patched"

    if digest != profile.original_sha256:
        raise PatchError(
            f"unsupported JRE {runtime_version} SHA-256 "
            f"(expected {profile.original_sha256} or "
            f"{profile.patched_sha256}, got {digest})"
        )

    prefix = data[
        profile.detector_offset:
        profile.detector_offset + len(ORIGINAL_PREFIX)
    ]
    if prefix != ORIGINAL_PREFIX:
        raise PatchError(
            "unexpected DeviceRequiresTXMWorkaround prologue at "
            f"0x{profile.detector_offset:x}: {prefix.hex()}"
        )
    if check_only:
        raise PatchError("runtime still needs the mirror-mapping detector fix")

    with libjvm.open("r+b") as stream:
        stream.seek(profile.detector_offset)
        stream.write(RETURN_TRUE)
        stream.flush()
        os.fsync(stream.fileno())

    patched_digest = _sha256(libjvm.read_bytes())
    if patched_digest != profile.patched_sha256:
        raise PatchError(
            "patched runtime hash mismatch "
            f"(expected {profile.patched_sha256}, got {patched_digest})"
        )
    marker.write_text(MARKER_CONTENT)
    return "applied detector fix"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the runtime and marker without modifying them",
    )
    parser.add_argument("runtime_version", type=int, choices=sorted(RUNTIMES))
    parser.add_argument("libjvm", type=Path)
    args = parser.parse_args()

    try:
        result = patch_runtime(
            args.runtime_version,
            args.libjvm,
            args.check,
        )
    except (OSError, PatchError) as error:
        print(f"[jre-mirror-patch] ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"[jre-mirror-patch] JRE {args.runtime_version}: "
        f"{result}: {args.libjvm}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
