#!/usr/bin/env python3
"""Route libjvm JIT superpage allocation through brk #0xf00d (CMD_PREPARE_REGION).

BreakGetJITMapping uses brk #0x69, which depends on a StikDebug legacy handler that
many assigned scripts still implement incorrectly (returning 0x690000e0). Calling
JIT26PrepareRegion via brk #0xf00d matches the native Amethyst path and the base
UniversalJIT26.js command dispatcher.

Also saves the full mapping size on the stack before printf and reloads it before
the brk call. printf can clobber x19 on some iOS builds, which previously made the
240 MB mirror superpage request arrive as 0x10 bytes.

After brk succeeds, skip the original "Got JIT mapping" printf tail entirely and
branch straight to vm_remap. A PC-relative bl copied from the Requesting-log printf
was landing 4 bytes off the _printf stub and crashed in __isPlatformVersionAtLeast.

Idempotent — safe to re-run.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

BRK_F00D = 0xD4200000 | (0xF00D << 5)
MOV_X16_1 = 0xD2800030  # mov x16, #1 (NOT 0xD2800200 — that is mov x0, #16)
STP_X8_X19_SP = 0xA9004FE8  # stp x8, x19, [sp]
LDR_X1_SP8 = 0xF94007E1  # ldr x1, [sp, #8]
STR_X8_SP = 0xF90003E8  # str x8, [sp]
NOP = 0xD503201F
REQUEST_LOG = b"[JIT26] Requesting %zu MB for JIT mapping\n"
PATCH_WINDOW = 44  # 11 instructions
SUCCESS_BRANCH_OFF = 28  # patch_off + 28: b to vm_remap path
VMREMAP_PATH_OFF = 0x48  # patch_off + 0x48


def decode_adrp_add(data: bytes, pc: int) -> int | None:
    if pc + 8 > len(data):
        return None
    w0, w1 = struct.unpack_from("<II", data, pc)
    if (w0 & 0x9F000000) != 0x90000000 or (w1 & 0xFF000000) != 0x91000000:
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


def find_patch_offset(data: bytes) -> int | None:
    str_off = data.find(REQUEST_LOG)
    if str_off < 0:
        return None
    start, end = 0x4000, min(len(data), 0xC00000)
    for pc in range(start, end - 24, 4):
        if decode_adrp_add(data, pc) != str_off:
            continue
        w2 = struct.unpack_from("<I", data, pc + 8)[0]
        if (w2 & 0xFC000000) != 0x94000000:
            continue
        first = struct.unpack_from("<I", data, pc + 12)[0]
        second = struct.unpack_from("<I", data, pc + 16)[0]
        if first == 0xAA1303E0 and (second & 0xFC000000) == 0x94000000:
            return pc + 12
        if first in (0xAA1303E1, LDR_X1_SP8) and second == 0xD2800000:
            third = struct.unpack_from("<I", data, pc + 20)[0]
            if third in (MOV_X16_1, 0xD2800200) and struct.unpack_from("<I", data, pc + 24)[0] == BRK_F00D:
                return pc + 12
    return None


def success_branch_insn(patch_off: int) -> int:
    b_pc = patch_off + SUCCESS_BRANCH_OFF
    b_target = patch_off + VMREMAP_PATH_OFF
    b_imm = (b_target - b_pc) // 4
    if b_imm <= 0 or b_imm >= 0x4000000:
        raise ValueError(f"b offset out of range ({b_imm})")
    return 0x14000000 | (b_imm & 0x03FFFFFF)


def patch_brk_sequence(data: bytearray, patch_off: int) -> None:
    cbz_pc = patch_off + 16
    mmap_target = patch_off + PATCH_WINDOW
    cbz_imm = (mmap_target - cbz_pc) // 4
    if cbz_imm <= 0 or cbz_imm >= 0x40000:
        raise ValueError(f"cbz offset out of range ({cbz_imm})")

    patch_words = [
        LDR_X1_SP8,
        0xD2800000,
        MOV_X16_1,
        BRK_F00D,
        0xB4000000 | ((cbz_imm & 0x7FFFF) << 5),
        0xAA0003F4,
        0xF90003E0,
        success_branch_insn(patch_off),
        NOP,
        NOP,
        NOP,
    ]
    data[patch_off : patch_off + PATCH_WINDOW] = struct.pack(f"<{len(patch_words)}I", *patch_words)


def patch(path: Path) -> str:
    data = bytearray(path.read_bytes())
    patch_off = find_patch_offset(data)
    if patch_off is None:
        return "skip: get_debug_jit_mapping call site not found"

    size_store_off = patch_off - 0x10
    if size_store_off < 0:
        return f"warn: size store site before file start ({patch_off:#x})"

    notes: list[str] = []
    size_insn = struct.unpack_from("<I", data, size_store_off)[0]
    if size_insn == STR_X8_SP:
        data[size_store_off : size_store_off + 4] = struct.pack("<I", STP_X8_X19_SP)
        notes.append(f"size saved on stack @ {size_store_off:#x}")
    elif size_insn != STP_X8_X19_SP:
        return f"warn: unexpected size-store insn {size_insn:#x} @ {size_store_off:#x}"

    first = struct.unpack_from("<I", data, patch_off)[0]
    third = struct.unpack_from("<I", data, patch_off + 8)[0]
    brk_insn = struct.unpack_from("<I", data, patch_off + 12)[0]
    cbz_insn = struct.unpack_from("<I", data, patch_off + 16)[0]
    branch_insn = struct.unpack_from("<I", data, patch_off + SUCCESS_BRANCH_OFF)[0]
    tail_insn = struct.unpack_from("<I", data, patch_off + 32)[0]
    expected_cbz = 0xB4000000 | ((((patch_off + PATCH_WINDOW) - (patch_off + 16)) // 4) << 5)
    expected_branch = success_branch_insn(patch_off)
    already_ok = (
        first == LDR_X1_SP8
        and third == MOV_X16_1
        and brk_insn == BRK_F00D
        and cbz_insn == expected_cbz
        and branch_insn == expected_branch
        and tail_insn == NOP
        and size_insn == STP_X8_X19_SP
    )
    if already_ok:
        return f"skip: already patched @ {patch_off:#x}"

    if first == LDR_X1_SP8 and brk_insn == BRK_F00D:
        patch_brk_sequence(data, patch_off)
        notes.append(f"refreshed brk sequence @ {patch_off:#x}")
        path.write_bytes(data)
        return "ok: " + "; ".join(notes)

    original = bytes(data[patch_off : patch_off + PATCH_WINDOW])
    mov_insn, brk_call = struct.unpack_from("<II", original, 0)
    if mov_insn == 0xAA1303E0 and (brk_call & 0xFC000000) == 0x94000000:
        patch_brk_sequence(data, patch_off)
        notes.append(f"brk #0xf00d @ {patch_off:#x}")
    elif mov_insn in (0xAA1303E1, LDR_X1_SP8) and struct.unpack_from("<I", original, 8)[0] in (MOV_X16_1, 0xD2800200):
        patch_brk_sequence(data, patch_off)
        notes.append(f"updated brk sequence @ {patch_off:#x}")
    else:
        return f"warn: unexpected prologue at {patch_off:#x}: {original[:8].hex()}"

    path.write_bytes(data)
    return "ok: " + "; ".join(notes)


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
        try:
            print(f"{path}: {patch(path)}")
        except ValueError as exc:
            print(f"{path}: warn: {exc}")
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
