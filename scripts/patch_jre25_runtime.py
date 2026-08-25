#!/usr/bin/env python3
"""Patch known mirror-mapping faults in the published iOS JRE 25.

The published libjvm contains DeviceRequiresTXMWorkaround(), which calls
readdir(opendir("/private/preboot")) without checking whether opendir failed.
iOS 26.6 made that private directory unreadable, so HotSpot crashes before the
VM is initialized.

The same build also missed the mirror_w_set() conversion for nmethod::_gc_data.
On iOS 26.5 it therefore writes GC metadata through the executable alias and
raises SIGBUS in ScavengableNMethods::register_nmethod. A small trampoline
translates those writes to the writable alias.

The launcher now enables MirrorMappedCodeCache only after it has installed the
Universal JIT script and verified that ordinary executable mappings are not
available. Under that contract the detector must return true. These binary
fixups are a validated bridge for the pinned 2026-05-09 runtime; the matching
source-level changes live in jdk25_ios_fixups.py for the next rebuilt JRE.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys
from pathlib import Path


MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
LC_SEGMENT_64 = 0x19
LC_SYMTAB = 0x2
LC_UUID = 0x1B

EXPECTED_RUNTIME_UUID = bytes.fromhex(
    "63967bf353e2310fa9e7986685040dee"
)
ORIGINAL_RUNTIME_SHA256 = (
    "e249600d12bdb9390bbbf3c857a50ffa"
    "7dbea578f9120f3931ef8321bb459fd9"
)
PATCHED_RUNTIME_SHA256 = (
    "a5243228b420c4be91530ec742678c999"
    "ca6751c9b66e4b46af056748c7ca17f"
)

DETECTOR_SYMBOL = b"__Z27DeviceRequiresTXMWorkaroundv"
NEXT_SYMBOL = b"__Z21get_debug_jit_mappingm"
MIRROR_RW_SYMBOL = b"__ZN2os3Bsd16mirrored_find_rwEPh"
REGISTER_NMETHOD_SYMBOL = (
    b"__ZN19ScavengableNMethods16register_nmethodEP7nmethod"
)

# Current jre25-ios-arm64-20260509-release prologue. Checking the full prefix
# makes an unexpected JRE update fail loudly instead of modifying arbitrary
# instructions.
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

# DeviceRequiresTXMWorkaround's now-unreachable body is large enough for
# seven register-specialized entry stubs plus one common store helper.
# Words are copied from an arm64 assembly fixture and packed below.
TRAMPOLINE_WORDS = [
    # A: str x9, [x19, #0x78]
    0xA9BF07E0, 0x9101E260, 0xAA0903E1, 0x14000019,
    # B: str x8, [x9]
    0xA9BF07E0, 0xAA0903E0, 0xAA0803E1, 0x14000015,
    # C: str xzr, [x19, #0x78]
    0xA9BF07E0, 0x9101E260, 0xAA1F03E1, 0x14000011,
    # D: str x8, [x1]
    0xA9BF07E0, 0xAA0103E0, 0xAA0803E1, 0x1400000D,
    # E: str xzr, [x0, #0x78]
    0xA9BF07E0, 0x9101E000, 0xAA1F03E1, 0x14000009,
    # F: str x13, [x12]
    0xA9BF07E0, 0xAA0C03E0, 0xAA0D03E1, 0x14000005,
    # G: str xzr, [x10, #0x78]
    0xA9BF07E0, 0x9101E140, 0xAA1F03E1, 0x14000001,
    # Common helper. Preserve every register and NZCV value clobbered by the
    # exact mirrored_find_rw implementation in the pinned runtime so replacing
    # a single STR instruction has no observable side effects.
    # The BL placeholder at word 34 is filled dynamically.
    0xD10103FF, 0xA90027E8, 0xA9012FEA, 0xA9027BE1,
    0xD53B4208, 0xF9001BE8, 0x00000000, 0xF94013E1,
    0xF9000001, 0xF9401BE8, 0xD51B4208, 0xF94017FE,
    0xA9412FEA, 0xA94027E8, 0x910103FF, 0xA8C107E0,
    0xD65F03C0,
]
TRAMPOLINE_BL_WORD_INDEX = 34
TRAMPOLINE_ENTRY_OFFSETS = {
    "A": 0x00,
    "B": 0x10,
    "C": 0x20,
    "D": 0x30,
    "E": 0x40,
    "F": 0x50,
    "G": 0x60,
}

# Offsets are relative to ScavengableNMethods::register_nmethod in the pinned
# runtime. Each expected instruction is checked before any write occurs.
GC_STORE_SITES = [
    (0x054, "A", "693e00f9"),
    (0x184, "B", "280100f9"),
    (0x188, "C", "7f3e00f9"),
    (0x1A0, "C", "7f3e00f9"),
    (0x218, "B", "280100f9"),
    (0x21C, "C", "7f3e00f9"),
    (0x234, "C", "7f3e00f9"),
    (0x27C, "D", "280000f9"),
    (0x280, "E", "1f3c00f9"),
    (0x298, "E", "1f3c00f9"),
    (0x334, "B", "280100f9"),
    (0x338, "C", "7f3e00f9"),
    (0x350, "C", "7f3e00f9"),
    (0x3C8, "F", "8d0100f9"),
    (0x3CC, "G", "5f3d00f9"),
    (0x3E8, "G", "5f3d00f9"),
]


class PatchError(RuntimeError):
    pass


def _cstring(data: bytes, offset: int, limit: int) -> bytes:
    if offset < 0 or offset >= limit:
        raise PatchError(f"invalid Mach-O string offset: {offset}")
    end = data.find(b"\0", offset, limit)
    if end < 0:
        raise PatchError("unterminated Mach-O symbol name")
    return data[offset:end]


def _symbol_location(data: bytes, symbol: bytes) -> tuple[int, int]:
    if len(data) < 32:
        raise PatchError("file is too small to be a 64-bit Mach-O")

    magic, cpu_type, _, _, ncmds, sizeofcmds, _, _ = struct.unpack_from(
        "<IiiIIIII", data, 0
    )
    if magic != MH_MAGIC_64:
        raise PatchError("expected a little-endian 64-bit Mach-O")
    if cpu_type != CPU_TYPE_ARM64:
        raise PatchError("expected an arm64 Mach-O")
    if 32 + sizeofcmds > len(data):
        raise PatchError("truncated Mach-O load commands")

    segments: list[tuple[int, int, int, int]] = []
    symtab: tuple[int, int, int, int] | None = None
    runtime_uuid: bytes | None = None
    command_offset = 32

    for _ in range(ncmds):
        if command_offset + 8 > len(data):
            raise PatchError("truncated Mach-O load command")
        command, command_size = struct.unpack_from("<II", data, command_offset)
        if command_size < 8 or command_offset + command_size > len(data):
            raise PatchError("invalid Mach-O load command size")

        if command == LC_SEGMENT_64:
            if command_size < 72:
                raise PatchError("truncated LC_SEGMENT_64 command")
            vm_address, vm_size, file_offset, file_size = struct.unpack_from(
                "<QQQQ", data, command_offset + 24
            )
            segments.append((vm_address, vm_size, file_offset, file_size))
        elif command == LC_SYMTAB:
            if command_size < 24:
                raise PatchError("truncated LC_SYMTAB command")
            symtab = struct.unpack_from("<IIII", data, command_offset + 8)
        elif command == LC_UUID:
            if command_size < 24:
                raise PatchError("truncated LC_UUID command")
            runtime_uuid = data[command_offset + 8:command_offset + 24]

        command_offset += command_size

    if runtime_uuid != EXPECTED_RUNTIME_UUID:
        actual_uuid = runtime_uuid.hex() if runtime_uuid is not None else "missing"
        raise PatchError(
            "unsupported JRE build UUID "
            f"(expected {EXPECTED_RUNTIME_UUID.hex()}, got {actual_uuid})"
        )
    if symtab is None:
        raise PatchError("Mach-O has no symbol table")

    symbols_offset, symbol_count, strings_offset, strings_size = symtab
    symbols_end = symbols_offset + symbol_count * 16
    strings_end = strings_offset + strings_size
    if symbols_end > len(data) or strings_end > len(data):
        raise PatchError("truncated Mach-O symbol or string table")

    symbol_address: int | None = None
    for index in range(symbol_count):
        entry_offset = symbols_offset + index * 16
        string_index, _, _, _, value = struct.unpack_from(
            "<IBBHQ", data, entry_offset
        )
        if string_index == 0:
            continue
        name = _cstring(
            data,
            strings_offset + string_index,
            strings_end,
        )
        if name == symbol:
            symbol_address = value
            break

    if symbol_address is None:
        raise PatchError(f"required symbol not found: {symbol.decode()}")

    for vm_address, _, file_offset, file_size in segments:
        if vm_address <= symbol_address < vm_address + file_size:
            result = file_offset + symbol_address - vm_address
            if result + len(ORIGINAL_PREFIX) > len(data):
                raise PatchError("symbol points outside the Mach-O file")
            return symbol_address, result

    raise PatchError("symbol is not backed by a file segment")


def _branch(source: int, target: int, link: bool) -> bytes:
    delta = target - source
    if delta % 4 != 0:
        raise PatchError("unaligned arm64 branch target")
    immediate = delta // 4
    if not -(1 << 25) <= immediate < (1 << 25):
        raise PatchError("arm64 branch target is out of range")
    opcode = 0x94000000 if link else 0x14000000
    return struct.pack("<I", opcode | (immediate & 0x03FFFFFF))


def _trampoline(cave_address: int, mirror_address: int, size: int) -> bytes:
    words = TRAMPOLINE_WORDS.copy()
    bl_address = cave_address + TRAMPOLINE_BL_WORD_INDEX * 4
    words[TRAMPOLINE_BL_WORD_INDEX] = struct.unpack(
        "<I", _branch(bl_address, mirror_address, link=True)
    )[0]
    code = b"".join(struct.pack("<I", word) for word in words)
    if len(code) > size:
        raise PatchError("DeviceRequiresTXMWorkaround code cave is too small")
    nop = struct.pack("<I", 0xD503201F)
    return code + nop * ((size - len(code)) // 4)


def _patch_plan(data: bytes) -> list[tuple[int, bytes, bytes, str]]:
    detector_address, detector_offset = _symbol_location(data, DETECTOR_SYMBOL)
    next_address, _ = _symbol_location(data, NEXT_SYMBOL)
    mirror_address, _ = _symbol_location(data, MIRROR_RW_SYMBOL)
    register_address, register_offset = _symbol_location(
        data, REGISTER_NMETHOD_SYMBOL
    )

    prefix = data[detector_offset:detector_offset + len(ORIGINAL_PREFIX)]
    if prefix != ORIGINAL_PREFIX and not prefix.startswith(RETURN_TRUE):
        actual = prefix.hex()
        raise PatchError(
            "unsupported DeviceRequiresTXMWorkaround prologue "
            f"at file offset 0x{detector_offset:x}: {actual}"
        )

    cave_address = detector_address + len(RETURN_TRUE)
    cave_offset = detector_offset + len(RETURN_TRUE)
    cave_size = next_address - cave_address
    if cave_size <= 0 or cave_size % 4 != 0:
        raise PatchError("invalid DeviceRequiresTXMWorkaround code cave")
    trampoline = _trampoline(cave_address, mirror_address, cave_size)

    plan = [
        (
            detector_offset,
            prefix[:len(RETURN_TRUE)],
            RETURN_TRUE,
            "TXM detector",
        ),
        (
            cave_offset,
            data[cave_offset:cave_offset + cave_size],
            trampoline,
            "mirror-write trampoline",
        ),
    ]

    for relative_offset, entry, expected_hex in GC_STORE_SITES:
        site_address = register_address + relative_offset
        site_offset = register_offset + relative_offset
        expected = bytes.fromhex(expected_hex)
        patched = _branch(
            site_address,
            cave_address + TRAMPOLINE_ENTRY_OFFSETS[entry],
            link=True,
        )
        actual = data[site_offset:site_offset + 4]
        if actual not in (expected, patched):
            raise PatchError(
                "unsupported ScavengableNMethods instruction "
                f"at file offset 0x{site_offset:x}: {actual.hex()}"
            )
        plan.append((
            site_offset,
            actual,
            patched,
            f"nmethod GC store +0x{relative_offset:x}",
        ))

    return plan


def patch_jvm(path: Path, check_only: bool = False) -> str:
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest not in (ORIGINAL_RUNTIME_SHA256, PATCHED_RUNTIME_SHA256):
        raise PatchError(
            "unsupported JRE SHA-256 "
            f"(expected {ORIGINAL_RUNTIME_SHA256} or "
            f"{PATCHED_RUNTIME_SHA256}, got {digest})"
        )
    plan = _patch_plan(data)
    pending = [
        (offset, replacement, label)
        for offset, actual, replacement, label in plan
        if actual != replacement
    ]

    if not pending:
        return "already patched"
    if check_only:
        labels = ", ".join(label for _, _, label in pending)
        raise PatchError(f"JRE still needs runtime fixups: {labels}")

    with path.open("r+b") as stream:
        for offset, replacement, _ in pending:
            stream.seek(offset)
            stream.write(replacement)
        stream.flush()
        os.fsync(stream.fileno())

    verified = path.read_bytes()
    remaining = [
        label
        for offset, _, replacement, label in _patch_plan(verified)
        if verified[offset:offset + len(replacement)] != replacement
    ]
    if remaining:
        raise PatchError(
            "patched instructions did not persist: " + ", ".join(remaining)
        )
    patched_digest = hashlib.sha256(verified).hexdigest()
    if patched_digest != PATCHED_RUNTIME_SHA256:
        raise PatchError(
            "patched JRE SHA-256 mismatch "
            f"(expected {PATCHED_RUNTIME_SHA256}, got {patched_digest})"
        )
    return f"applied {len(pending)} runtime fixups"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify that the JRE is already patched without modifying it",
    )
    parser.add_argument("libjvm", type=Path)
    args = parser.parse_args()

    try:
        result = patch_jvm(args.libjvm, args.check)
    except (OSError, PatchError) as error:
        print(f"[jre25-patch] ERROR: {error}", file=sys.stderr)
        return 1

    print(f"[jre25-patch] {result}: {args.libjvm}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
