# Removes .class files whose bytecode version is newer than Java 8 (major
# version > 52) from an exploded jar directory.
#
# Why: some prebuilt LWJGL extension classes (org/lwjgl/openal/SOFTSystemEvent*)
# shipped in lwjgl.jar were compiled with a modern JDK (major version 69).
# When Forge puts the bundled LWJGL jar on its JPMS module path, modlauncher
# runs every class through its bundled ASM 9.5 while transforming; ASM < 9.9
# rejects major version 69 ("Unsupported class file major version 69") and
# crashes every Forge launch. Minecraft never touches those OpenAL extension
# classes, so dropping them is safe.
#
# Usage: python3 strip_v69_classes.py <dir>
import os
import struct
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: strip_v69_classes.py <dir>", file=sys.stderr)
        return 2
    root = sys.argv[1]
    removed = []
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if not fn.endswith(".class"):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, "rb") as f:
                head = f.read(8)
            if len(head) >= 8 and struct.unpack(">H", head[6:8])[0] > 52:
                os.remove(p)
                removed.append(os.path.relpath(p, root))
    detail = ": " + ", ".join(sorted(removed)) if removed else ""
    print(f"[strip-v69] removed {len(removed)} >Java8 class(es) under {root}{detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
