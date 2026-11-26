// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2025 Advanced Micro Devices, Inc.
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

#include <FidelityFX/host/ffx_message.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>  // required for OutputDebugString()
#endif                // #ifdef _WIN32

#ifndef _WIN32
#include <cstdio>
#include <cwchar>
#include <cstring>  // strlen (wide->utf8 console fallback)
#endif  // !_WIN32

static ffxMessageCallback s_messageCallback;
static uint32_t s_debugLevel;

// set the printing callback function
void ffxSetPrintMessageCallback(ffxMessageCallback callback, uint32_t debugLevel)
{
    s_messageCallback = callback;
    s_debugLevel = debugLevel;
    return;
}

void ffxPrintMessage(uint32_t type, const wchar_t* message)
{
#ifdef _WIN32
    if (!s_messageCallback) {
        // Format the message string
        wchar_t buffer[512];
        if (type == FFX_MESSAGE_TYPE_ERROR) {
            swprintf_s(buffer, 512, L"FSR_API_DEBUG_ERROR: %ls\n", message);
        }
        else if (type == FFX_MESSAGE_TYPE_WARNING) {
            swprintf_s(buffer, 512, L"FSR_API_DEBUG_WARNING: %ls\n", message);
        }
        OutputDebugStringW(buffer);
    } else {
        s_messageCallback(type, message);
    }
#else
    if (s_messageCallback) {
        s_messageCallback(type, message);
        return;
    }
    if (!message) {
        return;
    }
    const char* prefix = "FSR_API_DEBUG: ";
    if (type == FFX_MESSAGE_TYPE_ERROR) {
        prefix = "FSR_API_DEBUG_ERROR: ";
    }
    else if (type == FFX_MESSAGE_TYPE_WARNING) {
        prefix = "FSR_API_DEBUG_WARNING: ";
    }
    char buffer[2048];
    size_t n = 0;
    for (; message[n] != L'\0' && n < (sizeof(buffer) - strlen(prefix) - 1); ++n) {
        buffer[n] = (message[n] <= 0x7F) ? static_cast<char>(message[n]) : '?';
    }
    buffer[n] = '\0';
    fprintf(stderr, "%s%s\n", prefix, buffer);
#endif
    return;
}