#pragma once

// TGLMT bridge: OpenGL 4.6 Core -> Metal (libtglmt.dylib) cho renderer picker.
// Không EGL: context/surface/swap chạy qua TGLMT C API (GLFWShim), LWJGL
// dlsym gl* thẳng từ libtglmt.dylib (C exports, không mangle).
void set_tglmt_bridge_tbl(void);

// Forward drawable resize (xoay màn hình) sang TGLMT target. No-op khi
// TGLMT không active hoặc lib chưa load — mọi renderer khác trả về ngay.
void tglmt_notify_resize(int width, int height);
