// cxx23_compat.cpp
// Provides C++23 typeinfo symbols for libMobileGL.dylib on iOS < 17.
//
// Problem: the system libc++ on iOS 16.x lacks std::bad_expected_access<void>.
// MobileGL references __ZTINSt3__119bad_expected_accessIvEE at dlopen time.
// With -flat_namespace, dyld resolves symbols from all loaded images.
//
// Approach: define the symbol using dlsym-resolved pointers at runtime,
// so there are ZERO undefined references at link time / dyld bind time.

#include <dlfcn.h>
#include <stdint.h>
#include <string.h>

// ---- Itanium ABI constants (defined in libc++abi, always present) ----
// We resolve them at runtime via dlsym to avoid undefined references
// that would crash dyld on iOS 16.x with -flat_namespace.

// Mangled symbol names
static const char* const SYM_SI_CLASS_TYPEINFO_VTABLE =
    "_ZTVN10__cxxabiv120__si_class_type_infoE";
static const char* const SYM_RUNTIME_ERROR_TYPEINFO =
    "_ZTINSt3__113runtime_errorE";

// ---- The typeinfo name string (embedded in our binary) ----
// "NSt3__119bad_expected_accessIvEE" = std::__1::bad_expected_access<void>
extern "C" __attribute__((used, visibility("default")))
const char _ZTSNSt3__119bad_expected_accessIvEE[] =
    "NSt3__119bad_expected_accessIvEE";

// ---- The typeinfo object (mutable, initialized at runtime) ----
// Itanium ABI layout for __si_class_type_info (single inheritance):
//   [0] vtable_ptr  = &__ZTV... + 16 (skip top-level type_info vtable entries)
//   [1] __type_name = &_ZTSN...
//   [2] __base_type = &_ZTI...
struct abi_si_class_typeinfo {
    const void* vtable_ptr;
    const char* type_name;
    const void* base_type;
};

// Define as a strong symbol with the exact mangled name.
// Initialize fields to zero; will be filled by the init function.
extern "C" __attribute__((used, visibility("default")))
abi_si_class_typeinfo _ZTINSt3__119bad_expected_accessIvEE = {
    nullptr,
    _ZTSNSt3__119bad_expected_accessIvEE,
    nullptr
};

// ---- The key-function: what() method ----
// libMobileGL.dylib calls std::__1::bad_expected_access<void>::what().
// iOS 16.x libc++ lacks this C++23 symbol.
extern "C" __attribute__((used, visibility("default")))
const char* _ZNKSt3__119bad_expected_accessIvE4whatEv() {
    return "bad access to std::expected";
}

// ---- Runtime initialization ----
// Called early in the Witch binary lifecycle (before MobileGL is dlopen'd).
// Uses dlsym to resolve libc++abi / libc++ symbols without creating
// undefined references at link time.
extern "C" __attribute__((constructor))
void _mgl_cxx23_compat_init() {
    // Resolve __si_class_type_info vtable from libc++abi
    void* si_vtable = dlsym(RTLD_DEFAULT, SYM_SI_CLASS_TYPEINFO_VTABLE);
    if (si_vtable) {
        // vtable_ptr = vtable + 16 (skip the two top-level type_info pointers)
        _ZTINSt3__119bad_expected_accessIvEE.vtable_ptr =
            (const char*)si_vtable + 16;
    }

    // Resolve std::runtime_error typeinfo from libc++
    void* rt_ti = dlsym(RTLD_DEFAULT, SYM_RUNTIME_ERROR_TYPEINFO);
    if (rt_ti) {
        _ZTINSt3__119bad_expected_accessIvEE.base_type = rt_ti;
    }
}
