#!/usr/bin/env python3
"""Analyze Witch launcher memory logs.

Reads a device/user log (typically Documents/latestlog.txt) and reports the
trend for:
  - native footprint / internal / compressed / external / malloc zone (mz)
  - JVM heap used and committed
  - direct/mapped buffer pools ([JVM-Mem] probe)

Use it after a 30-minute Sodium + Iris session to distinguish:
  internal grows, mz flat      -> JVM heap/committed heap growth
  mz grows                     -> native malloc (log pump, LWJGL, ObjC objects)
  external grows               -> GPU/IOKit (renderer caches/buffers)
  direct pools grow            -> LWJGL/Sodium/Iris direct buffer pressure
"""

import argparse
import re
import sys

BOOT_RE = re.compile(r"\[MemSample\]\[boot\].*?footprint=(\d+)MB \(internal=(\d+)MB compressed=(\d+)MB external=(\d+)MB mz=(\d+)MB.*?avail=(\d+)MB")
SAMPLE_RE = re.compile(r"\[MemSample\].*?footprint=(\d+)MB \(internal=(\d+)MB compressed=(\d+)MB external=(\d+)MB mz=(\d+)MB.*?avail=(\d+)MB.*?used=([0-9.]+)%")
MEM_RE = re.compile(r"\[MEM\] .*?footprint=(\d+)MB .*?internal=(\d+)MB .*?compressed=(\d+)MB .*?external=(\d+)MB .*?avail_of_cap=(\d+)MB .*?swap=(\d+)")
JVMEM_RE = re.compile(r"\[JVM-Mem\] heap used=(\d+)MB committed=(\d+)MB max=(\d+)MB(?: pools=(.*))?$")
POOL_RE = re.compile(r"(\w+)=(\d+)MB/\d+MB")


def parse(path):
    mem_samples = []
    mem_lines = []
    jvm_samples = []
    with open(path, "r", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            m = BOOT_RE.search(line)
            if m:
                mem_samples.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6))))
                continue
            m = SAMPLE_RE.search(line)
            if m:
                mem_samples.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6))))
                continue
            m = MEM_RE.search(line)
            if m:
                # Map the [MEM] format onto the same tuple (avail -> avail_of_cap)
                mem_samples.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), 0, int(m.group(5))))
                continue
            m = JVMEM_RE.search(line)
            if m:
                used, committed, max_heap = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
                direct = 0
                for pm in POOL_RE.finditer(m.group(4) or ""):
                    direct += int(pm.group(2))
                jvm_samples.append((used, committed, max_heap, direct))
    return mem_samples, jvm_samples


def linreg_slope(values):
    n = len(values)
    if n < 2:
        return 0.0
    x = list(range(n))
    sx = sum(x)
    sy = sum(values)
    sxy = sum(xi * yi for xi, yi in zip(x, values))
    sxx = sum(xi * xi for xi in x)
    denom = n * sxx - sx * sx
    if denom == 0:
        return 0.0
    return (n * sxy - sx * sy) / denom


def report_series(name, values, interval_s):
    if not values:
        print(f"{name:28s} no data")
        return None
    delta = values[-1] - values[0]
    peak = max(values)
    slope = linreg_slope(values)
    per_min = slope * (60.0 / interval_s) if interval_s else 0.0
    print(f"{name:28s} start={values[0]:5d}MB  end={values[-1]:5d}MB  delta={delta:+5d}MB  peak={peak:5d}MB  ~{per_min:+.1f}MB/min")
    return delta, per_min


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log", help="Path to latestlog.txt or a copied log file")
    ap.add_argument("--mem-interval", type=float, default=2.0, help="Seconds between [MemSample]/[MEM] lines (default 2.0)")
    ap.add_argument("--jvm-interval", type=float, default=10.0, help="Seconds between [JVM-Mem] lines (default 10.0)")
    args = ap.parse_args()

    mem_samples, jvm_samples = parse(args.log)
    print(f"[JVM-Mem] probe may also appear in a separate latestlog.txt\n")
    print(f"Native samples: {len(mem_samples)} (assuming {args.mem_interval:.1f}s interval)")
    print(f"JVM samples:    {len(jvm_samples)} (assuming {args.jvm_interval:.1f}s interval)\n")

    if mem_samples:
        labels = ["footprint", "internal", "compressed", "external", "malloc zone", "avail"]
        mz = [m[4] for m in mem_samples]
        skip_mz = sum(mz) == 0  # [MEM] lines from gl_bridge.m don't carry mz
        for i, label in enumerate(labels):
            if skip_mz and i == 4:
                continue
            report_series(label, [m[i] for m in mem_samples], args.mem_interval)
    else:
        print("No [MemSample]/[MEM] lines found. Enable debug.mem_sample_log and play for 30 minutes.")

    if jvm_samples:
        print()
        for label, index in [
            ("heap used", 0),
            ("heap committed", 1),
            ("heap max", 2),
            ("direct pools", 3),
        ]:
            report_series(label, [m[index] for m in jvm_samples], args.jvm_interval)
    else:
        print("\nNo [JVM-Mem] lines found. Set WITCH_MEM_PROBE=1 (enable debug.mem_sample_log) and re-run.")

    print("\nVerdict hints:")
    print("  internal grows, mz flat     -> JVM heap/committed growth (lower -Xmx or rely on MaxDirectMemorySize)")
    print("  mz grows                    -> native malloc leak (log pump, LWJGL direct dup, ObjC retain)")
    print("  external grows               -> renderer GPU buffers/textures (Zink/MobileGL/ANGLE cache)")
    print("  direct pools grow to cap    -> LWJGL/Sodium/Iris direct-buffer pressure (tune MaxDirectMemorySize)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
