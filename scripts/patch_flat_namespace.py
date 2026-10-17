#!/usr/bin/env python3
"""
Patch libMobileGL.dylib (and similar dlopen'd dylibs) to resolve the missing
_ZTINSt3__119bad_expected_accessIvEE symbol on iOS 16.x.

Root cause:
  libMobileGL.dylib links /usr/lib/libc++.1.dylib with two-level namespace.
  The libc++ on iOS 16.x lacks the C++23 symbol _ZTINSt3__119bad_expected_accessIvEE.
  dlopen fails because dyld validates two-level bind entries even with
  MH_DYLIB_IN_FLAT_NAMESPACE set.

Fix:
  1. Build a thin "compat shim" dylib that:
     - Re-exports every symbol from the real /usr/lib/libc++.1.dylib
     - Additionally provides _ZTINSt3__119bad_expected_accessIvEE
  2. Use install_name_tool to redirect libMobileGL.dylib's
     /usr/lib/libc++.1.dylib load-command to @rpath/libc++_compat.dylib

Usage:
  python3 patch_flat_namespace.py <frameworks_dir> [<ios_sdk>]
"""
import os
import subprocess
import sys
import tempfile
import shutil

REAL_LIBCXX = "/usr/lib/libc++.1.dylib"
SHIM_NAME = "libc++_compat.dylib"
SHIM_INSTALL_NAME = f"@rpath/{SHIM_NAME}"

# macOS host libc++ for reexport linking (the build machine's library)
HOST_LIBCXX = "/usr/lib/libc++.1.dylib"
# Fallback: use the iOS SDK's TBD stub
HOST_LIBCXX_FALLBACK = None  # resolved at runtime from SDK path

SHIM_SRC = r"""
// libc++_compat.cpp – thin shim that re-exports the real libc++ and
// additionally provides the C++23 symbol missing from iOS 16.x.

#include <dlfcn.h>
#include <stdint.h>

// ---- Itanium ABI layout for __si_class_type_info (single inheritance) ----
struct abi_si_class_typeinfo {
    const void* vtable_ptr;
    const char* type_name;
    const void* base_type;
};

// ---- The typeinfo name string ----
extern "C" __attribute__((used, visibility("default")))
const char _ZTSNSt3__119bad_expected_accessIvEE[] =
    "NSt3__119bad_expected_accessIvEE";

// ---- The typeinfo object ----
extern "C" __attribute__((used, visibility("default")))
abi_si_class_typeinfo _ZTINSt3__119bad_expected_accessIvEE = {
    nullptr,
    _ZTSNSt3__119bad_expected_accessIvEE,
    nullptr
};

// ---- The key-function symbol ----
// libMobileGL.dylib also calls std::__1::bad_expected_access<void>::what()
// directly. iOS 16.x libc++ lacks this C++23 symbol too, so dyld aborts with
// "Symbol not found: __ZNKSt3__119bad_expected_accessIvE4whatEv".
// Define it as a C-linkage function whose name (minus the Darwin leading
// underscore added by extern "C") matches the Itanium mangled name exactly.
extern "C" __attribute__((used, visibility("default")))
const char* _ZNKSt3__119bad_expected_accessIvE4whatEv() {
    return "bad access to std::expected";
}

// ---- Runtime init: resolve vtable + base from libc++/libc++abi ----
__attribute__((constructor))
static void _libcxx_compat_init() {
    void* vtable = dlsym(RTLD_DEFAULT, "_ZTVN10__cxxabiv120__si_class_type_infoE");
    if (vtable)
        _ZTINSt3__119bad_expected_accessIvEE.vtable_ptr =
            (const char*)vtable + 16;

    // bad_expected_access<void> derives from std::exception (global namespace
    // in libc++, mangled without the __1 versioning namespace).
    void* base = dlsym(RTLD_DEFAULT, "_ZTISt9exception");
    if (!base)
        base = dlsym(RTLD_DEFAULT, "_ZTINSt3__19exceptionE");
    if (base)
        _ZTINSt3__119bad_expected_accessIvEE.base_type = base;
}
"""


def find_ios_sdk():
    """Try to locate the iPhoneOS SDK."""
    try:
        r = subprocess.run(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-path"],
            capture_output=True, text=True, check=True,
        )
        return r.stdout.strip()
    except Exception:
        pass
    # Common locations
    for p in [
        "/Applications/Xcode.app/Contents/Developer/Platforms/"
        "iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk",
        "/Library/Developer/CommandLineTools/SDKs/iPhoneOS.sdk",
    ]:
        if os.path.isdir(p):
            return p
    return None


def build_shim(work_dir, sdk_path=None):
    """Compile the shim dylib."""
    src_path = os.path.join(work_dir, "libcxx_compat.cpp")
    obj_path = os.path.join(work_dir, "libcxx_compat.o")
    dylib_path = os.path.join(work_dir, SHIM_NAME)

    with open(src_path, "w") as f:
        f.write(SHIM_SRC)

    cc = os.environ.get("CC", "clang")
    cxx = os.environ.get("CXX", "clang++")

    common_flags = ["-arch", "arm64", "-std=c++23",
                    "-miphoneos-version-min=14.0", "-fPIC"]
    if sdk_path:
        common_flags += ["-isysroot", sdk_path]

    # Compile to object file
    subprocess.check_call(
        [cxx] + common_flags + ["-c", src_path, "-o", obj_path]
    )

    # Find the libc++ library for re-export
    # Try SDK path first (TBD stub), then host path
    libcxx_path = None
    candidates = []
    if sdk_path:
        candidates.append(os.path.join(sdk_path, "usr/lib/libc++.1.dylib"))
        candidates.append(os.path.join(sdk_path, "usr/lib/libc++.tbd"))
    candidates.append("/usr/lib/libc++.1.dylib")
    candidates.append("/usr/lib/libc++.tbd")
    # Also try the macOS SDK
    try:
        mac_sdk = subprocess.run(
            ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        candidates.append(os.path.join(mac_sdk, "usr/lib/libc++.1.dylib"))
        candidates.append(os.path.join(mac_sdk, "usr/lib/libc++.tbd"))
    except Exception:
        pass

    for c in candidates:
        if os.path.exists(c):
            libcxx_path = c
            break

    if not libcxx_path:
        # Fallback: just provide the symbol without reexport
        print("  WARN: libc++ not found, building shim without reexport")
        subprocess.check_call(
            [cc] + common_flags + [
                "-dynamiclib",
                "-flat_namespace",
                "-undefined", "dynamic_lookup",
                "-install_name", SHIM_INSTALL_NAME,
                "-o", dylib_path,
                obj_path,
            ]
        )
        return dylib_path

    # Link as dylib that re-exports everything from real libc++
    subprocess.check_call(
        [cc] + common_flags + [
            "-dynamiclib",
            "-flat_namespace",
            "-undefined", "dynamic_lookup",
            "-Wl,-reexport_library", libcxx_path,
            "-install_name", SHIM_INSTALL_NAME,
            "-o", dylib_path,
            obj_path,
        ]
    )

    return dylib_path


def patch_dylib(frameworks_dir, dylib_path, shim_path, sdk_path=None):
    """Redirect a dylib's /usr/lib/libc++.1.dylib reference to our shim."""
    target = os.path.join(frameworks_dir, dylib_path)
    if not os.path.isfile(target):
        print(f"  SKIP {dylib_path}: not found")
        return False

    install_name_tool = shutil.which("install_name_tool")
    if not install_name_tool:
        print("  ERROR: install_name_tool not found")
        return False

    # Check if already patched
    r = subprocess.run(
        [install_name_tool, "-id", target],
        capture_output=True, text=True,
    )
    if SHIM_NAME in (r.stdout + r.stderr):
        print(f"  OK   {dylib_path}: already patched")
        return True

    # Redirect libc++ to our shim
    subprocess.check_call([
        install_name_tool,
        "-change", REAL_LIBCXX, SHIM_INSTALL_NAME,
        target,
    ])
    print(f"  OK   {dylib_path}: redirected {REAL_LIBCXX} -> {SHIM_INSTALL_NAME}")
    return True


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <frameworks_dir> [<ios_sdk>]")
        sys.exit(1)

    frameworks_dir = sys.argv[1]
    sdk_path = sys.argv[2] if len(sys.argv) > 2 else find_ios_sdk()

    if not os.path.isdir(frameworks_dir):
        print(f"ERROR: {frameworks_dir} is not a directory")
        sys.exit(1)

    # Build the shim
    work_dir = tempfile.mkdtemp(prefix="libcxx_compat_")
    try:
        print("[patch] Building libc++ compat shim ...")
        shim_path = build_shim(work_dir, sdk_path)
        print(f"[patch] Shim built: {shim_path}")

        # Copy shim into Frameworks
        dest_shim = os.path.join(frameworks_dir, SHIM_NAME)
        shutil.copy2(shim_path, dest_shim)
        print(f"[patch] Copied shim to {dest_shim}")

        # Patch all dylibs that link libc++
        dylibs_to_check = []
        for name in sorted(os.listdir(frameworks_dir)):
            if name.endswith(".dylib") and name != SHIM_NAME:
                dylibs_to_check.append(name)

        patched = 0
        for name in dylibs_to_check:
            # Check if this dylib links libc++
            r = subprocess.run(
                ["otool", "-L", os.path.join(frameworks_dir, name)],
                capture_output=True, text=True,
            )
            if REAL_LIBCXX not in r.stdout:
                continue

            # Check if this dylib actually references the problematic C++23 symbol
            r2 = subprocess.run(
                ["dyld_info", "-fixups", os.path.join(frameworks_dir, name)],
                capture_output=True, text=True,
            )
            if "bad_expected_access" not in (r2.stdout + r2.stderr):
                continue

            if patch_dylib(frameworks_dir, name, shim_path, sdk_path):
                patched += 1

        print(f"[patch] Patched {patched} dylib(s)")
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
