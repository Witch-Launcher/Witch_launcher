// tglmt_bridge.m — cài bridge_tbl cho renderer TGLMT (libtglmt.dylib).
// Luồng: egl_bridge pojavInitOpenGL → dlopen libtglmt → set_tglmt_bridge_tbl()
// → br_init (load C API) → br_init_context (CreateWindow trên CAMetalLayer)
// → br_make_current / br_swap_buffers (present) mỗi frame.
// LWJGL lấy gl* qua org.lwjgl.opengl.libname = Frameworks/libtglmt.dylib
// (JavaLauncher đặt đường tuyệt đối), không qua EGL.
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#include <dlfcn.h>
#include <stdlib.h>

#include "bridge_tbl.h"
#include "tglmt_bridge.h"
#include "SurfaceViewController.h"
#include "utils.h"
#include "TGLMTConfig.h"

// TGLMT C API (GLFWShim) — resolve runtime, không link cứng để app vẫn
// launch khi dylib vắng mặt (chọn renderer khác).
static void *g_tglmtLib = NULL;
static void *(*p_CreateWindow)(uint32_t, uint32_t, const char *, int) = NULL;
static void (*p_DestroyWindow)(void *) = NULL;
static int (*p_MakeCurrent)(void *) = NULL;
static void (*p_ClearCurrent)(void) = NULL;
static int (*p_SwapBuffers)(void *, void *) = NULL;
static void (*p_SwapInterval)(int) = NULL;
static void (*p_ResizeWindow)(void *, uint32_t, uint32_t) = NULL;
static int (*p_HasRealGPU)(void) = NULL;

static void *g_tglmtWin = NULL;
static __weak CALayer *g_tglmtLayer = nil;

static BOOL tglmt_is_active(void) {
    static BOOL checked = NO;
    static BOOL active = NO;
    if (checked) return active;
    checked = YES;
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    active = [renderer isEqualToString:@ RENDERER_NAME_TGLMT];
    return active;
}

void tglmt_notify_resize(int width, int height) {
    if (!tglmt_is_active() || !g_tglmtWin || !p_ResizeWindow) return;
    if (width < 2) width = 2;
    if (height < 2) height = 2;
    p_ResizeWindow(g_tglmtWin, (uint32_t)width, (uint32_t)height);
    NSLog(@"[TGLMT] resize -> %dx%d", width, height);
}

static void *tglmt_load(void) {
    if (g_tglmtLib) return g_tglmtLib;
    NSString *fw = NSBundle.mainBundle.privateFrameworksPath;
    NSString *path = [fw stringByAppendingPathComponent:@ RENDERER_NAME_TGLMT];
    g_tglmtLib = dlopen(path.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    if (!g_tglmtLib) {
        g_tglmtLib = dlopen("@rpath/" RENDERER_NAME_TGLMT, RTLD_LAZY | RTLD_GLOBAL);
    }
    if (!g_tglmtLib) {
        NSLog(@"[TGLMT] dlopen FAILED: %@ (%s)", path, dlerror());
        return NULL;
    }
    NSLog(@"[TGLMT] dlopen OK: %@", path.lastPathComponent);
#define TGLMT_SYM(n) p_##n = dlsym(g_tglmtLib, "TGLMT_" #n); \
    if (!p_##n) NSLog(@"[TGLMT] dlsym TGLMT_" #n " missing")
    TGLMT_SYM(CreateWindow);
    TGLMT_SYM(DestroyWindow);
    TGLMT_SYM(MakeCurrent);
    TGLMT_SYM(ClearCurrent);
    TGLMT_SYM(SwapBuffers);
    TGLMT_SYM(SwapInterval);
    TGLMT_SYM(ResizeWindow);
    TGLMT_SYM(HasRealGPU);
#undef TGLMT_SYM
    return g_tglmtLib;
}

static bool tglmt_init(void) {
    if (!tglmt_load() || !p_CreateWindow || !p_MakeCurrent || !p_SwapBuffers) {
        NSLog(@"[TGLMT] FATAL: C API incomplete, rendering is impossible");
        return false;
    }
    [TGLMTConfig applyEnvironmentFromPreferences];
    NSLog(@"[TGLMT] %@", [TGLMTConfig activeConfigSummary]);
    if (p_HasRealGPU && !p_HasRealGPU()) {
        NSLog(@"[TGLMT] WARNING: no MTLDevice (Null fallback) — frames will be trace-only");
    }
    return true;
}

static basic_render_window_t *tglmt_init_context(basic_render_window_t *share) {
    (void)share; // phase 1: đơn context serialize (chunk thread MakeCurrent xen kẽ)
    if (!g_tglmtLib && !tglmt_init()) return NULL;
    CALayer *layer = SurfaceViewController.surface.layer;
    // TGLMT present yêu cầu RGBA8Unorm khớp target (khác ANGLE BGRA8).
    // Sửa tại chỗ như gl_bridge làm cho ANGLE để eglCreate... không 0x300B.
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        if (ml.pixelFormat != MTLPixelFormatRGBA8Unorm) {
            ml.pixelFormat = MTLPixelFormatRGBA8Unorm;
            NSLog(@"[TGLMT] metal layer pixelFormat corrected to RGBA8Unorm");
        }
        ml.framebufferOnly = NO; // glReadPixels/readback diagnostics
        CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
        CGSize want = CGSizeMake(MAX(2, ml.bounds.size.width * scale),
                                 MAX(2, ml.bounds.size.height * scale));
        if (ml.drawableSize.width < 2 || ml.drawableSize.height < 2) {
            ml.drawableSize = want;
        }
        int w = (int)MAX(2, ml.bounds.size.width * scale);
        int h = (int)MAX(2, ml.bounds.size.height * scale);
        g_tglmtWin = p_CreateWindow((uint32_t)w, (uint32_t)h, "apple", 1);
        if (!g_tglmtWin) {
            NSLog(@"[TGLMT] TGLMT_CreateWindow(%dx%d) FAILED", w, h);
            return NULL;
        }
        g_tglmtLayer = layer;
        p_MakeCurrent(g_tglmtWin);
        NSLog(@"[TGLMT] context OK: window=%p %dx%d layer=%p", g_tglmtWin, w, h, layer);
    } else {
        NSLog(@"[TGLMT] WARNING: surface layer is %@, not CAMetalLayer — need CAMetalLayer",
              NSStringFromClass(layer.class));
        return NULL;
    }
    basic_render_window_t *bundle = calloc(1, sizeof(basic_render_window_t));
    return bundle;
}

static void tglmt_make_current(basic_render_window_t *bundle) {
    if (!bundle || !g_tglmtWin) {
        if (p_ClearCurrent) p_ClearCurrent();
        currentBundle = NULL;
        return;
    }
    // Re-attach khi layer đổi (xoay/external display) như TGLES glue.
    CALayer *now = SurfaceViewController.surface.layer;
    if (now && now != g_tglmtLayer && [now isKindOfClass:CAMetalLayer.class]) {
        g_tglmtLayer = now;
        CAMetalLayer *ml = (CAMetalLayer *)now;
        CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
        tglmt_notify_resize((int)MAX(2, ml.bounds.size.width * scale),
                            (int)MAX(2, ml.bounds.size.height * scale));
    }
    p_MakeCurrent(g_tglmtWin);
    currentBundle = bundle;
}

static void tglmt_swap_buffers(void) {
    if (!g_tglmtWin || !p_SwapBuffers) return;
    CALayer *layer = g_tglmtLayer ?: SurfaceViewController.surface.layer;
    if (![layer isKindOfClass:CAMetalLayer.class]) return;
    if (!p_SwapBuffers(g_tglmtWin, (__bridge void *)layer)) {
        NSLog(@"[TGLMT] present FAILED (format/size mismatch?)");
    }
}

static void tglmt_swap_interval(int interval) {
    if (p_SwapInterval) p_SwapInterval(interval);
}

static void tglmt_terminate(void) {
    if (g_tglmtWin && p_DestroyWindow) p_DestroyWindow(g_tglmtWin);
    g_tglmtWin = NULL;
    g_tglmtLayer = nil;
}

void set_tglmt_bridge_tbl(void) {
    br_init = tglmt_init;
    br_init_context = (br_init_context_t)tglmt_init_context;
    br_make_current = (br_make_current_t)tglmt_make_current;
    br_swap_buffers = tglmt_swap_buffers;
    br_swap_interval = tglmt_swap_interval;
    br_terminate = tglmt_terminate;
}
