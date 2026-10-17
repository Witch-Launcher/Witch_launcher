// libcxx_compat.cpp
// Provides C++23 symbols missing from iOS 16.x libc++ for MobileGL.
// This dylib re-exports the real system libc++ and additionally provides
// std::__1::bad_expected_access<void> RTTI + vtable + what().
//
// Build: see Makefile in this directory.
// Usage: libMobileGL.dylib is patched to depend on @rpath/libc++_compat.dylib
//        instead of /usr/lib/libc++.1.dylib via install_name_tool.

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

// ---- The key-function: what() method ----
extern "C" __attribute__((used, visibility("default")))
const char* _ZNKSt3__119bad_expected_accessIvE4whatEv() {
    return "bad access to std::expected";
}

// ---- Runtime initialization ----
// Resolves vtable + base from libc++/libc++abi at load time.
__attribute__((constructor))
static void _libcxx_compat_init() {
    // Resolve __si_class_type_info vtable from libc++abi
    void* vtable = dlsym(RTLD_DEFAULT, "_ZTVN10__cxxabiv120__si_class_type_infoE");
    if (vtable)
        _ZTINSt3__119bad_expected_accessIvEE.vtable_ptr =
            (const char*)vtable + 16;

    // bad_expected_access<void> derives from std::exception
    void* base = dlsym(RTLD_DEFAULT, "_ZTISt9exception");
    if (!base)
        base = dlsym(RTLD_DEFAULT, "_ZTINSt3__19exceptionE");
    if (base)
        _ZTINSt3__119bad_expected_accessIvEE.base_type = base;
}
