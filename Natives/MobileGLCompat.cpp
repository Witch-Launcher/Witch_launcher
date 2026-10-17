// Provide std::__1::bad_expected_access<void> RTTI + vtable symbols that
// iOS 16.7 libc++ lacks.  Compiled with the build-machine's C++23 headers
// the symbols are force-loaded into libMobileGL.dylib so dlopen() succeeds.

#include <__expected/bad_expected_access.h>

namespace std {
namespace __1 {

// Define the key function (what()) so the compiler emits the vtable and
// typeinfo into THIS translation unit rather than referencing libc++.
const char* bad_expected_access<void>::what() const noexcept {
    return "bad access to std::expected";
}

} // namespace __1
} // namespace std
