#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"
#import <QuartzCore/QuartzCore.h>

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include "bridge_tbl.h"
#include "environ.h"
#include "utils.h"
#include "gl_bridge.h"

// ── EGL handle (resolved from Mesa's libEGL.1.dylib) ──────────────────────

static EGLDisplay  s_display = EGL_NO_DISPLAY;
static egl_library  egl;

// ── GL entry points resolved via eglGetProcAddress ─────────────────────────

static void (*p_glFinish)(void);
static void (*p_glReadPixels)(GLint, GLint, GLsizei, GLsizei,
                              GLenum, GLenum, const void*);
static void (*p_glViewport)(GLint, GLint, GLsizei, GLsizei);

static void resolve_gl_procs(void) {
    if (p_glFinish) return;
    if (!egl.eglGetProcAddress) return;
    p_glFinish   = (void(*)(void))
        egl.eglGetProcAddress("glFinish");
    p_glReadPixels = (void(*)(GLint,GLint,GLsizei,GLsizei,
                               GLenum,GLenum,const void*))
        egl.eglGetProcAddress("glReadPixels");
    p_glViewport = (void(*)(GLint,GLint,GLsizei,GLsizei))
        egl.eglGetProcAddress("glViewport");
    NSLog(@"[MesaEGL] GL procs resolved: glFinish=%p glReadPixels=%p glViewport=%p",
          (void*)p_glFinish, (void*)p_glReadPixels, (void*)p_glViewport);
}

// ── Pbuffer tracking (single render context, single-thread) ────────────────

static int s_pbW = 0, s_pbH = 0;   // current Pbuffer dimensions

static void destroy_pbuffer(gl_render_window_t *b) {
    if (b && b->surface != EGL_NO_SURFACE) {
        egl.eglMakeCurrent(s_display, EGL_NO_SURFACE,
                           EGL_NO_SURFACE, EGL_NO_CONTEXT);
        egl.eglDestroySurface(s_display, b->surface);
        b->surface = EGL_NO_SURFACE;
        s_pbW = s_pbH = 0;
    }
}

static void ensure_pbuffer(gl_render_window_t *b) {
    int wantW = windowWidth  > 0 ? windowWidth  : 16;
    int wantH = windowHeight > 0 ? windowHeight : 16;

    if (b->surface != EGL_NO_SURFACE && s_pbW == wantW && s_pbH == wantH)
        return;

    NSLog(@"[MesaEGL] Pbuffer resize: %dx%d → %dx%d", s_pbW, s_pbH, wantW, wantH);
    destroy_pbuffer(b);

    const EGLint pb[] = { EGL_WIDTH, wantW, EGL_HEIGHT, wantH, EGL_NONE };
    b->surface = egl.eglCreatePbufferSurface(s_display, b->config, pb);
    if (!b->surface) {
        NSLog(@"[MesaEGL] ✗ Pbuffer %dx%d creation FAILED: 0x%x",
              wantW, wantH, egl.eglGetError());
        return;
    }

    if (!egl.eglMakeCurrent(s_display, b->surface, b->surface, b->context)) {
        NSLog(@"[MesaEGL] ✗ eglMakeCurrent FAILED: 0x%x", egl.eglGetError());
        return;
    }

    resolve_gl_procs();
    if (p_glViewport) p_glViewport(0, 0, wantW, wantH);
    s_pbW = wantW;
    s_pbH = wantH;
    NSLog(@"[MesaEGL] ✓ Pbuffer %dx%d ready, context bound", wantW, wantH);
}

// ── bridge: init ───────────────────────────────────────────────────────────

static void *load_egl(const char *name) {
    static void *h = NULL;
    if (!h) h = dlopen("@rpath/libEGL_Mesa26.dylib", RTLD_LAZY | RTLD_GLOBAL);
    return h ? dlsym(h, name) : NULL;
}

static bool mesa_egl_init(void) {
    NSLog(@"[MesaEGL] ======== Mesa EGL Bridge Init ========");
    NSLog(@"[MesaEGL] Loading EGL functions from libEGL.1.dylib...");
#define LOAD(fn) egl.fn = (typeof(egl.fn))load_egl(#fn)
    LOAD(eglGetDisplay);        LOAD(eglInitialize);
    LOAD(eglChooseConfig);      LOAD(eglBindAPI);
    LOAD(eglCreateContext);      LOAD(eglDestroyContext);
    LOAD(eglCreatePbufferSurface); LOAD(eglDestroySurface);
    LOAD(eglMakeCurrent);       LOAD(eglGetError);
    LOAD(eglGetConfigAttrib);   LOAD(eglQueryString);
    LOAD(eglQuerySurface);      LOAD(eglSwapBuffers);
    LOAD(eglSwapInterval);      LOAD(eglTerminate);
    LOAD(eglReleaseThread);     LOAD(eglGetProcAddress);
    LOAD(eglGetCurrentContext);  LOAD(eglGetCurrentSurface);
    LOAD(eglGetConfigs);        LOAD(eglGetPlatformDisplay);
    LOAD(eglCreateWindowSurface);
#undef LOAD

    if (!egl.eglGetDisplay || !egl.eglInitialize) {
        NSLog(@"[MesaEGL] ✗ MISSING eglGetDisplay or eglInitialize — libEGL.1.dylib may not be Mesa 26.2.2");
        return false;
    }
    NSLog(@"[MesaEGL] EGL functions loaded OK");

    // Mesa 26.2.2 was built with -Dplatforms= (empty), so eglGetPlatformDisplay
    // returns NULL.  eglGetDisplay triggers DRI config cache init which has
    // option cache entries with NULL names.  The driQueryOptionb assertion was
    // binary-patched out of libEGL_Mesa26.dylib so this no longer crashes.

    s_display = egl.eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (s_display == EGL_NO_DISPLAY) {
        NSLog(@"[MesaEGL] ✗ eglGetDisplay returned EGL_NO_DISPLAY");
        return false;
    }
    NSLog(@"[MesaEGL] display=%p, calling eglInitialize...", s_display);

    if (!egl.eglInitialize(s_display, NULL, NULL)) {
        NSLog(@"[MesaEGL] ✗ eglInitialize FAILED: 0x%x", egl.eglGetError());
        return false;
    }

    NSLog(@"[MesaEGL] ✓ eglInitialize OK");
    NSLog(@"[MesaEGL]   VENDOR = %s", egl.eglQueryString(s_display, 0x3053));
    NSLog(@"[MesaEGL]   VERSION = %s", egl.eglQueryString(s_display, 0x3054));
    NSLog(@"[MesaEGL]   CLIENT_APIS = %s", egl.eglQueryString(s_display, 0x308D));
    NSLog(@"[MesaEGL]   EXTENSIONS = %s", egl.eglQueryString(s_display, 0x3055));
    NSLog(@"[MesaEGL] ======== Mesa EGL Bridge Init DONE ========");
    return true;
}

// ── bridge: init_context ───────────────────────────────────────────────────

static gl_render_window_t *mesa_egl_init_context(gl_render_window_t *share) {
    NSLog(@"[MesaEGL] Creating context (share=%p)...", share);
    gl_render_window_t *b = calloc(1, sizeof(gl_render_window_t));
    if (!b) {
        NSLog(@"[MesaEGL] ✗ calloc failed");
        return NULL;
    }

    const EGLint cfg_attribs[] = {
        EGL_RED_SIZE,       8,
        EGL_GREEN_SIZE,     8,
        EGL_BLUE_SIZE,      8,
        EGL_ALPHA_SIZE,     8,
        EGL_DEPTH_SIZE,    24,
        EGL_SURFACE_TYPE,  EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_NONE
    };

    EGLint n = 0;
    if (!egl.eglChooseConfig(s_display, cfg_attribs, &b->config, 1, &n)
        || !b->config || n == 0) {
        NSLog(@"[MesaEGL] ✗ eglChooseConfig FAILED (n=%d, err=0x%x)", n, egl.eglGetError());
        free(b);
        return NULL;
    }
    NSLog(@"[MesaEGL] eglChooseConfig OK: config=%p (n=%d)", b->config, n);

    if (!egl.eglBindAPI(EGL_OPENGL_API)) {
        NSLog(@"[MesaEGL] ✗ eglBindAPI(EGL_OPENGL) FAILED: 0x%x", egl.eglGetError());
        free(b);
        return NULL;
    }
    NSLog(@"[MesaEGL] eglBindAPI(EGL_OPENGL) OK");

    const EGLint ctx_attr[] = {
        EGL_CONTEXT_MAJOR_VERSION, 4,
        EGL_CONTEXT_MINOR_VERSION, 1,
        EGL_NONE
    };
    b->context = egl.eglCreateContext(s_display, b->config,
                                      share ? share->context : EGL_NO_CONTEXT,
                                      ctx_attr);
    if (!b->context) {
        NSLog(@"[MesaEGL] ✗ eglCreateContext(4.1) FAILED: 0x%x", egl.eglGetError());
        free(b);
        return NULL;
    }

    NSLog(@"[MesaEGL] ✓ Context created: %p (GL 4.1, share=%p)", b->context,
          share ? share->context : NULL);
    b->surface = EGL_NO_SURFACE;   // created lazily on make_current
    return b;
}

// ── bridge: make_current ───────────────────────────────────────────────────

static void mesa_egl_make_current(gl_render_window_t *b) {
    if (!b) {
        NSLog(@"[MesaEGL] make_current(NULL) — unbinding");
        if (currentBundle) {
            egl.eglMakeCurrent(s_display, EGL_NO_SURFACE,
                               EGL_NO_SURFACE, EGL_NO_CONTEXT);
            destroy_pbuffer(&currentBundle->gl);
            currentBundle = NULL;
        }
        return;
    }
    ensure_pbuffer(b);
    currentBundle = (basic_render_window_t *)b;
    NSLog(@"[MesaEGL] make_current: context=%p surface=%p → %dx%d",
          b->context, b->surface, s_pbW, s_pbH);
}

// ── bridge: swap_buffers ───────────────────────────────────────────────────
//
// Pbuffer → glReadPixels (bottom-up) → vertical flip → CGImage → main layer.
// Double-buffered static copy so the async dispatch never races the next frame.

static void mesa_egl_swap_buffers(void) {
    if (!currentBundle) return;

    gl_render_window_t *b = &currentBundle->gl;
    ensure_pbuffer(b);

    if (!p_glFinish || !p_glReadPixels) resolve_gl_procs();
    if (!p_glFinish || !p_glReadPixels) {
        NSLog(@"[MesaEGL] swap_buffers: GL procs not available, skip");
        return;
    }

    p_glFinish();

    int w = s_pbW, h = s_pbH;
    if (w <= 0 || h <= 0) return;

    size_t bytes = (size_t)w * (size_t)h * 4;
    void  *px    = malloc(bytes);
    if (!px) return;

    p_glReadPixels(0, 0, w, h,
                   0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, px);

    // flip vertically  (glReadPixels = bottom-up, CGImage = top-down)
    size_t row = (size_t)w * 4;
    uint8_t tmp[4096];
    uint8_t *stackBuf = (w <= 1024) ? tmp : malloc(row);
    if (!stackBuf) { free(px); return; }
    uint8_t *buf = (uint8_t *)px;
    for (int y = 0; y < h / 2; y++) {
        uint8_t *top = buf + y * row;
        uint8_t *bot = buf + (h - 1 - y) * row;
        memcpy(stackBuf, top, row);
        memcpy(top, bot, row);
        memcpy(bot, stackBuf, row);
    }
    if (stackBuf != tmp) free(stackBuf);

    // double-buffer the copy dispatched to the main queue
    static void  *s_buf[2]   = { NULL, NULL };
    static size_t s_sz[2]    = { 0, 0 };
    static int    s_idx       = 0;

    int i = s_idx;
    s_idx = (s_idx + 1) & 1;
    if (s_sz[i] < bytes) {
        s_buf[i] = reallocf(s_buf[i], bytes);
        s_sz[i]  = bytes;
    }
    if (!s_buf[i]) { free(px); return; }
    memcpy(s_buf[i], px, bytes);
    free(px);

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CGDataProviderRef dp =
            CGDataProviderCreateWithData(NULL, s_buf[i], bytes, NULL);
        if (dp) {
            CGImageRef img = CGImageCreate(
                w, h, 8, 32, 4 * w, cs,
                kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                dp, NULL, FALSE, kCGRenderingIntentDefault);
            if (img) {
                SurfaceViewController.surface.layer.contents =
                    (__bridge id)img;
                CGImageRelease(img);
            }
            CGDataProviderRelease(dp);
        }
        [CATransaction commit];
        CGColorSpaceRelease(cs);
    });
}

// ── bridge: swap_interval / terminate ──────────────────────────────────────

static void mesa_egl_swap_interval(int interval) {
    if (egl.eglSwapInterval)
        egl.eglSwapInterval(s_display, interval);
}

static void mesa_egl_terminate(void) {
    NSLog(@"[MesaEGL] Terminating Mesa EGL bridge...");
    if (currentBundle) {
        egl.eglMakeCurrent(s_display, EGL_NO_SURFACE,
                           EGL_NO_SURFACE, EGL_NO_CONTEXT);
        destroy_pbuffer(&currentBundle->gl);
        if (currentBundle->gl.context != EGL_NO_CONTEXT)
            egl.eglDestroyContext(s_display, currentBundle->gl.context);
        free(currentBundle);
        currentBundle = NULL;
    }
    if (s_display != EGL_NO_DISPLAY) {
        egl.eglTerminate(s_display);
        s_display = EGL_NO_DISPLAY;
    }
    if (egl.eglReleaseThread) egl.eglReleaseThread();
    NSLog(@"[MesaEGL] ✓ Mesa EGL bridge terminated");
}

// ── table install ──────────────────────────────────────────────────────────

void set_mesa_egl_bridge_tbl(void) {
    NSLog(@"[MesaEGL] Installing Mesa EGL bridge table:");
    NSLog(@"[MesaEGL]   br_init          = mesa_egl_init");
    NSLog(@"[MesaEGL]   br_init_context  = mesa_egl_init_context");
    NSLog(@"[MesaEGL]   br_make_current  = mesa_egl_make_current");
    NSLog(@"[MesaEGL]   br_swap_buffers  = mesa_egl_swap_buffers");
    NSLog(@"[MesaEGL]   br_swap_interval = mesa_egl_swap_interval");
    NSLog(@"[MesaEGL]   br_terminate     = mesa_egl_terminate");
    br_init          = mesa_egl_init;
    br_init_context  = (br_init_context_t)  mesa_egl_init_context;
    br_make_current  = (br_make_current_t)  mesa_egl_make_current;
    br_swap_buffers  = mesa_egl_swap_buffers;
    br_swap_interval = mesa_egl_swap_interval;
    br_terminate     = mesa_egl_terminate;
    NSLog(@"[MesaEGL] ✓ Bridge table installed");
}
