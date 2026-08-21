#!/usr/bin/env python3
# Usage: check_minos.py <minos-string>   e.g. "14.0" -> exit 0 if <= 14.0
import sys

def main() -> int:
    val = sys.argv[1] if len(sys.argv) > 1 else "0"
    try:
        major = int(val.split(".")[0])
    except ValueError:
        return 1
    return 0 if major <= 14 else 1

if __name__ == "__main__":
    sys.exit(main())