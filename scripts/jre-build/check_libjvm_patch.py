#!/usr/bin/env python3
"""
Usage: check_libjvm_patch.py <path-to-libjvm.dylib>

Exit 0: the mirror-mapped JIT binary patches are present (brk #0x6a
replacing the printf, plus the brk #0xf00d jit-alloc hook).
Exit 3: libjvm is unpatched/unknown (warn only, used by the Makefile).
Exit 1: the file is missing/empty or a hard failure occurred.
"""
import struct
import sys


def u32le(b: bytes, off: int) -> int:
    try:
        return struct.unpack_from("<I", b, off)[0]
    except struct.error:
        return None


def scan_brk(b: bytes, imm: int) -> bool:
    # AArch64 brk #imm = 0xD4200000 | (imm << 5)
    target = 0xD4200000 | ((imm & 0xFFFF) << 5)
    word = struct.pack("<I", target)
    # only search executable pages; cheap probe over the whole file is fine
    return word in b


def main(argv) -> int:
    if len(argv) != 2:
        print("usage: check_libjvm_patch.py <libjvm.dylib>")
        return 1
    path = argv[1]
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        print(f"cannot read {path}")
        return 1
    if not data:
        print(f"empty file {path}")
        return 1

    has_mirror_log = b"[JIT26] mapping at RW=%p, RX=%p\n" in data
    has_brk6a = scan_brk(data, 0x6A)
    has_brkf00d = scan_brk(data, 0xF00D)

    # The mirror patch replaces the `bl printf` instruction with `brk #0x6a`;
    # the printf string literal stays in __cstring, so its presence is expected.
    if has_brk6a and has_brkf00d:
        print(f"{path}: mirror JIT patches OK (brk#0x6a={has_brk6a} brk#0xf00d={has_brkf00d})")
        return 0
    if has_brk6a or has_brkf00d:
        print(f"{path}: WARNING patches partially applied (brk#0x6a={has_brk6a} brk#0xf00d={has_brkf00d})")
        return 3
    print(f"{path}: NOT patched (no brk hooks; run scripts/patch_libjvm_mirror_brk.py + scripts/patch_libjvm_jit_alloc.py)")
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))