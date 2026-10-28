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

#include "utils.h"

// NOTE(angel-aura-amethyst port): WinAPI WideCharToMultiByte/MultiByteToWideChar
// replaced with a portable converter that handles both wide encodings:
//   - Windows: sizeof(wchar_t) == 2, UTF-16 (with surrogate pairs)
//   - POSIX:   sizeof(wchar_t) == 4, UTF-32
// Behaviour matches the WinAPI CP_UTF8 calls for all well-formed strings used
// by the shader compiler (paths, defines and file names).

namespace
{
constexpr char32_t kUtf16SurrogateHighStart = 0xD800;
constexpr char32_t kUtf16SurrogateHighEnd   = 0xDBFF;
constexpr char32_t kUtf16SurrogateLowStart  = 0xDC00;
constexpr char32_t kUtf16SurrogateLowEnd    = 0xDFFF;

constexpr char32_t kUtf16SurrogateOffset = 0x10000 - (0xD800 << 10) - 0xDC00; // 0x10000 - (hi<<10) - lo

// Decodes the next code point from a UTF-8 string. Returns false on malformed input.
inline bool DecodeUTF8(const std::string& str, size_t& i, char32_t& out)
{
    const unsigned char c0 = static_cast<unsigned char>(str[i]);
    if (c0 < 0x80u)
    {
        out = c0;
        i += 1;
        return true;
    }
    else if ((c0 & 0xE0u) == 0xC0u && (i + 1) < str.size())
    {
        const unsigned char c1 = static_cast<unsigned char>(str[i + 1]);
        if ((c1 & 0xC0u) != 0x80u)
            return false;
        out = (static_cast<char32_t>(c0 & 0x1Fu) << 6) | static_cast<char32_t>(c1 & 0x3Fu);
        i += 2;
        return true;
    }
    else if ((c0 & 0xF0u) == 0xE0u && (i + 2) < str.size())
    {
        const unsigned char c1 = static_cast<unsigned char>(str[i + 1]);
        const unsigned char c2 = static_cast<unsigned char>(str[i + 2]);
        if ((c1 & 0xC0u) != 0x80u || (c2 & 0xC0u) != 0x80u)
            return false;
        out = (static_cast<char32_t>(c0 & 0x0Fu) << 12) | (static_cast<char32_t>(c1 & 0x3Fu) << 6) | static_cast<char32_t>(c2 & 0x3Fu);
        i += 3;
        return true;
    }
    else if ((c0 & 0xF8u) == 0xF0u && (i + 3) < str.size())
    {
        const unsigned char c1 = static_cast<unsigned char>(str[i + 1]);
        const unsigned char c2 = static_cast<unsigned char>(str[i + 2]);
        const unsigned char c3 = static_cast<unsigned char>(str[i + 3]);
        if ((c1 & 0xC0u) != 0x80u || (c2 & 0xC0u) != 0x80u || (c3 & 0xC0u) != 0x80u)
            return false;
        out = (static_cast<char32_t>(c0 & 0x07u) << 18) | (static_cast<char32_t>(c1 & 0x3Fu) << 12) | (static_cast<char32_t>(c2 & 0x3Fu) << 6) | static_cast<char32_t>(c3 & 0x3Fu);
        i += 4;
        return true;
    }
    return false;
}

inline void EncodeUTF8(std::string& out, char32_t cp)
{
    if (cp < 0x80u)
    {
        out.push_back(static_cast<char>(cp));
    }
    else if (cp < 0x800u)
    {
        out.push_back(static_cast<char>(0xC0u | (cp >> 6)));
        out.push_back(static_cast<char>(0x80u | (cp & 0x3Fu)));
    }
    else if (cp < 0x10000u)
    {
        out.push_back(static_cast<char>(0xE0u | (cp >> 12)));
        out.push_back(static_cast<char>(0x80u | ((cp >> 6) & 0x3Fu)));
        out.push_back(static_cast<char>(0x80u | (cp & 0x3Fu)));
    }
    else
    {
        out.push_back(static_cast<char>(0xF0u | (cp >> 18)));
        out.push_back(static_cast<char>(0x80u | ((cp >> 12) & 0x3Fu)));
        out.push_back(static_cast<char>(0x80u | ((cp >> 6) & 0x3Fu)));
        out.push_back(static_cast<char>(0x80u | (cp & 0x3Fu)));
    }
}

inline void EncodeWide(std::wstring& out, char32_t cp)
{
    if constexpr (sizeof(wchar_t) == 4)
    {
        out.push_back(static_cast<wchar_t>(cp));
    }
    else
    {
        if (cp >= 0x10000u)
        {
            const char32_t v = cp - 0x10000u;
            out.push_back(static_cast<wchar_t>(0xD800u | (v >> 10)));
            out.push_back(static_cast<wchar_t>(0xDC00u | (v & 0x3FFu)));
        }
        else
        {
            out.push_back(static_cast<wchar_t>(cp));
        }
    }
}
} // anonymous namespace

std::string WCharToUTF8(const std::wstring& wstr)
{
    std::string str;
    str.reserve(wstr.size());

    if constexpr (sizeof(wchar_t) == 4)
    {
        for (const wchar_t c : wstr)
            EncodeUTF8(str, static_cast<char32_t>(c));
    }
    else
    {
        for (size_t i = 0; i < wstr.size();)
        {
            const char32_t c = static_cast<char32_t>(wstr[i]);
            if (c >= kUtf16SurrogateHighStart && c <= kUtf16SurrogateHighEnd && (i + 1) < wstr.size())
            {
                const char32_t lo = static_cast<char32_t>(wstr[i + 1]);
                if (lo >= kUtf16SurrogateLowStart && lo <= kUtf16SurrogateLowEnd)
                {
                    EncodeUTF8(str, (c << 10) + lo + kUtf16SurrogateOffset);
                    i += 2;
                    continue;
                }
            }
            EncodeUTF8(str, c);
            i += 1;
        }
    }

    return str;
}

std::wstring UTF8ToWChar(const std::string& str)
{
    std::wstring wstr;
    wstr.reserve(str.size());

    size_t i = 0;
    char32_t cp = 0;
    while (i < str.size())
    {
        if (DecodeUTF8(str, i, cp))
            EncodeWide(wstr, cp);
        else
            EncodeWide(wstr, static_cast<char32_t>(static_cast<unsigned char>(str[i++]))); // latin-1 fallback for malformed bytes
    }

    return wstr;
}
