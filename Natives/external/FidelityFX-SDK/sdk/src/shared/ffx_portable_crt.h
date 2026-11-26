// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#pragma once

// Portable replacements for the Windows CRT helpers (MSVC-only) used by the
// SDK host components on POSIX platforms. Windows keeps its native forms.

#ifndef _WIN32

#include <cwchar>
#include <cstddef>
#include <cstdint>
#include <cerrno>
// Xcode 26 SDK no longer exposes errno_t through <cerrno>.
#include <sys/types.h>

#ifndef _countof
#define _countof(arr) (sizeof(arr) / sizeof((arr)[0]))
#endif  // _countof

// wcscpy_s: MSVC secure copy. Called with an array destination in the SDK, so
// provide the template form (deduces the destination capacity). Copy semantics
// match the secure template: full copy when it fits, otherwise the destination
// is truncated and terminated with L'\0' (errno_t EOVERFLOW-style failure
// result is reported through the return value without aborting).
template <size_t N>
inline errno_t wcscpy_s(wchar_t (&dst)[N], const wchar_t* src)
{
    if (dst == nullptr || src == nullptr) {

        if (dst != nullptr) {

            dst[0] = L'\0';
        }
        return EINVAL;
    }

    const size_t srcLength = wcslen(src);
    if (srcLength >= N) {

        dst[0] = L'\0';
        return ERANGE;
    }

    wmemcpy(dst, src, srcLength + 1);
    return 0;
}

#endif  // !_WIN32
