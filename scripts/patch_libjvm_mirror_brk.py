#!/usr/bin/env python3
"""Replace libjvm's mirror-mapping printf call with brk #0x6a.

Amethyst's UniversalJIT26Extension.js handles brk 0x6a on the JVM thread
and calls prepare_memory_region for both RX and RW mirror views. Runtime
patches to libjvm __TEXT are rejected on iOS 27, so this is applied at
build/package time instead.

Idempotent — safe to re-run.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

MAPPING_LOG = b"[JIT26] mapping at RW=%p, RX=%p\n"
ORIG_BL = None  # discovered from file
BRK_0x6A = 0xD4200000 | (0x6A << 5)


def decode_adrp_add(data: bytes, pc: int) -> int | None:
    if pc + 12 > len(data):
        return None
    w0, w1, w2 = struct.unpack_from("<III", data, pc)
    if (w0 & 0x9F000000) != 0x90000000 or (w1 & 0xFF000000) != 0x91000000:
        return None
    if (w2 & 0xFC000000) != 0x94000000:
        return None
    immlo = (w0 >> 29) & 0x3
    immhi = (w0 >> 5) & 0x7FFFF
    imm21 = (immhi << 2) | immlo
    if imm21 & 0x100000:
        imm21 -= 0x200000
    page = (pc & ~0xFFF) + (imm21 << 12)
    imm12 = (w1 >> 10) & 0xFFF
    shift = (w1 >> 22) & 0x1
    return page + (imm12 << (12 if shift else 0))


def find_printf_bl(data: bytes) -> int | None:
    off = data.find(MAPPING_LOG)
    if off < 0:
        return None
    str_addr = off  # file offset == vmaddr for this dylib's __TEXT layout
    text_off = data.find(b"\xCF\xFA\xED\xFE")  # skip, use section bounds instead
    # Scan executable region where mirror setup lives (~0x4000 .. 0xc00000)
    start, end = 0x4000, min(len(data), 0xC00000)
    for pc in range(start, end - 12, 4):
        if decode_adrp_add(data, pc) != str_addr:
            continue
        bl_off = pc + 8
        insn = struct.unpack_from("<I", data, bl_off)[0]
        if (insn & 0xFC000000) == 0x94000000:
            return bl_off
    return None


def patch(path: Path) -> str:
    data = bytearray(path.read_bytes())
    bl_off = find_printf_bl(data)
    if bl_off is None:
        return "skip: mapping log call site not found"

    insn = struct.unpack_from("<I", data, bl_off)[0]
    if insn == BRK_0x6A:
        return "skip: already patched"
    if (insn & 0xFC000000) != 0x94000000:
        return f"warn: unexpected instruction {insn:#x} at {bl_off:#x}"

    data[bl_off : bl_off + 4] = struct.pack("<I", BRK_0x6A)
    path.write_bytes(data)
    return f"ok: bl @ {bl_off:#x} ({insn:#x}) -> brk #0x6a ({BRK_0x6A:#x})"


def main(argv: list[str]) -> int:
    paths = [Path(p) for p in argv[1:]] if len(argv) > 1 else []
    if not paths:
        root = Path(__file__).resolve().parents[1]
        paths = list(root.glob("depends/*/lib/server/libjvm.dylib"))
    if not paths:
        print("No libjvm.dylib paths given or found")
        return 1

    status = 0
    for path in paths:
        if not path.is_file():
            print(f"{path}: missing")
            status = 1
            continue
        print(f"{path}: {patch(path)}")
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
