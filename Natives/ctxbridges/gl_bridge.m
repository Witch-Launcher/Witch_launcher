#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"
#import <QuartzCore/QuartzCore.h>

#include <dlfcn.h>
#include "bridge_tbl.h"
#include "environ.h"
#include "gl_bridge.h"
#include "utils.h"

static EGLDisplay g_EglDisplay;
static egl_library handle;
static void* ltw_handle;

static void* resolve_egl(void* from, void* fallback, const char* name) {
    void* fn = from ? dlsym(from, name) : NULL;
    if (!fn && fallback && fallback != from) fn = dlsym(fallback, name);
    return fn;
}

void dlsym_EGL() {
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL useLTW = [@ RENDERER_NAME_LTW isEqualToString: renderer];
    BOOL useMG = [@ RENDERER_NAME_MOBILEGLUES isEqualToString: renderer];

    void* dl_handle = NULL;   // ANGLE backend
    void* mg_handle = NULL;   // MobileGlues layer (MG renderer only)

    if (useMG) {
        // MobileGlues implements the whole EGL/GL layer on top of the ANGLE
        // frameworks. dlopen it first — its static init loads and binds the
        // ANGLE backend (libGLESv2/libEGL) itself, so load order does not
        // matter — then resolve every EGL entry point from MG's own handle so
        // the whole context/surface lifecycle runs through MG's wrappers.
        mg_handle = dlopen("@rpath/libmobileglues.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (!mg_handle) {
            NSLog(@"EGLBridge: Failed to load libmobileglues.dylib: %s", dlerror());
        }
        // Make sure the ANGLE backend is present for fallback resolution.
        dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
        if (!dl_handle) {
            dl_handle = dlopen("@rpath/libEGL.framework/libEGL", RTLD_GLOBAL);
        }
        if (!dl_handle) {
            NSLog(@"EGLBridge: Failed to load ANGLE EGL library");
        }
    } else {
        dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
        if (!dl_handle) {
            dl_handle = dlopen("@rpath/libEGL.framework/libEGL", RTLD_LOCAL);
        }
        if (!dl_handle) {
            NSLog(@"EGLBridge: Failed to load ANGLE EGL library");
            return;
        }
    }

    handle.eglBindAPI = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglBindAPI");
    handle.eglChooseConfig = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglChooseConfig");
    handle.eglCreateContext = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglCreateContext");
    handle.eglDestroyContext = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglDestroyContext");
    handle.eglMakeCurrent = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglMakeCurrent");
    handle.eglGetProcAddress = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetProcAddress");
    handle.eglCreateWindowSurface = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglCreateWindowSurface");
    handle.eglDestroySurface = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglDestroySurface");
    handle.eglGetConfigAttrib = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetConfigAttrib");
    handle.eglGetCurrentContext = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetCurrentContext");
    handle.eglGetDisplay = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetDisplay");
    handle.eglGetError = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetError");
    handle.eglGetPlatformDisplay = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetPlatformDisplay");
    handle.eglInitialize = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglInitialize");
    handle.eglSwapBuffers = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglSwapBuffers");
    handle.eglReleaseThread = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglReleaseThread");
    handle.eglSwapInterval = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglSwapInterval");
    handle.eglTerminate = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglTerminate");
    handle.eglGetCurrentSurface = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetCurrentSurface");
    handle.eglGetConfigs = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglGetConfigs");
    handle.eglQueryString = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglQueryString");
    handle.eglQuerySurface = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglQuerySurface");
    handle.eglCreatePbufferSurface = resolve_egl(useMG ? mg_handle : NULL, dl_handle, "eglCreatePbufferSurface");

    if (useLTW) {
        // Load LTW with RTLD_GLOBAL so its symbols (including eglGetProcAddress
        // and all gl* wrappers) are visible globally for LWJGL's dlsym-based
        // symbol resolution.  Keep the handle around so we can re-dlsym later.
        ltw_handle = dlopen("@rpath/libltw.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (ltw_handle) {
            // Resolve EGL functions from LTW's own handle so its wrappers
            // (eglCreateContext, eglDestroyContext, eglMakeCurrent) are
            // picked up instead of ANGLE's.
            handle.eglCreateContext = dlsym(ltw_handle, "eglCreateContext");
            handle.eglDestroyContext = dlsym(ltw_handle, "eglDestroyContext");
            handle.eglMakeCurrent = dlsym(ltw_handle, "eglMakeCurrent");
            // Also resolve eglGetProcAddress from LTW so that all GL function
            // lookups go through LTW's wrapper → override → host resolution
            // chain rather than hitting ANGLE's eglGetProcAddress directly.
            handle.eglGetProcAddress = dlsym(ltw_handle, "eglGetProcAddress");
        }
        if (!handle.eglCreateContext) handle.eglCreateContext = dlsym(dl_handle, "eglCreateContext");
        if (!handle.eglDestroyContext) handle.eglDestroyContext = dlsym(dl_handle, "eglDestroyContext");
        if (!handle.eglMakeCurrent) handle.eglMakeCurrent = dlsym(dl_handle, "eglMakeCurrent");
        if (!handle.eglGetProcAddress) handle.eglGetProcAddress = dlsym(dl_handle, "eglGetProcAddress");
    }
}

static const char* diag_query_string(EGLint name) {
    const char* s = handle.eglQueryString ? handle.eglQueryString(g_EglDisplay, name) : NULL;
    return s ? s : "(null)";
}

static void diag_probe_context(EGLint renderableType, EGLint depthSize) {
    const EGLint attribs[] = {
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, depthSize,
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, renderableType,
        EGL_NONE
    };
    EGLConfig cfg = NULL;
    EGLint n = 0;
    if (!handle.eglChooseConfig(g_EglDisplay, attribs, &cfg, 1, &n) || n == 0 || !cfg) {
        NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] NO config", renderableType, depthSize);
        return;
    }
    const EGLint pbAttribs[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE };
    void* surface = handle.eglCreatePbufferSurface(g_EglDisplay, cfg, pbAttribs);
    if (!surface) {
        NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] pbuffer failed 0x%x", renderableType, depthSize, handle.eglGetError());
        return;
    }
    const EGLint ctxAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, renderableType == 0x40 ? 3 : 2, EGL_NONE };
    void* ctx = handle.eglCreateContext(g_EglDisplay, cfg, EGL_NO_CONTEXT, ctxAttribs);
    if (!ctx) {
        NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] context failed 0x%x", renderableType, depthSize, handle.eglGetError());
        handle.eglDestroySurface(g_EglDisplay, surface);
        return;
    }
    if (!handle.eglMakeCurrent(g_EglDisplay, surface, surface, ctx)) {
        NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] makeCurrent failed 0x%x", renderableType, depthSize, handle.eglGetError());
    } else {
        typedef const unsigned char* (*glGetStringFn)(unsigned int);
        glGetStringFn glGetString = (glGetStringFn)handle.eglGetProcAddress("glGetString");
        if (glGetString) {
            NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] GL_VERSION=%s", renderableType, depthSize, glGetString(0x1F02));
            NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] GL_RENDERER=%s", renderableType, depthSize, glGetString(0x1F01));
        } else {
            NSLog(@"EGLBridge: [probe rt=0x%x depth=%d] no glGetString via eglGetProcAddress", renderableType, depthSize);
        }
        handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }
    handle.eglDestroySurface(g_EglDisplay, surface);
    handle.eglDestroyContext(g_EglDisplay, ctx);
}

static void diag_dump_configs() {
    NSLog(@"EGLBridge: DIAG eglQueryString VENDOR=%s VERSION=%s CLIENT_APIS=%s",
          diag_query_string(0x3053), diag_query_string(0x3054), diag_query_string(0x308D));
    NSLog(@"EGLBridge: DIAG EXTENSIONS=%s", diag_query_string(0x3055));
    EGLConfig configs[64];
    EGLint n = 0;
    if (!handle.eglGetConfigs(g_EglDisplay, configs, 64, &n)) {
        NSLog(@"EGLBridge: DIAG eglGetConfigs failed 0x%x", handle.eglGetError());
        return;
    }
    NSLog(@"EGLBridge: DIAG total configs = %d", n);
    for (EGLint i = 0; i < n && i < 64; i++) {
        EGLint r=0,g=0,b=0,a=0,d=0,st=0,s=0,rt=0,samp=0,nvid=0;
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_RED_SIZE, &r);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_GREEN_SIZE, &g);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_BLUE_SIZE, &b);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_ALPHA_SIZE, &a);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_DEPTH_SIZE, &d);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_STENCIL_SIZE, &st);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_SURFACE_TYPE, &s);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_RENDERABLE_TYPE, &rt);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_SAMPLES, &samp);
        handle.eglGetConfigAttrib(g_EglDisplay, configs[i], EGL_NATIVE_VISUAL_ID, &nvid);
        NSLog(@"EGLBridge: DIAG cfg[%d] RGBA=%d/%d/%d/%d depth=%d stencil=%d surf=0x%x rt=0x%x samples=%d nvid=%d",
              i, r, g, b, a, d, st, s, rt, samp, nvid);
    }
    diag_probe_context(0x40 /*ES3*/, 24);
    diag_probe_context(0x40 /*ES3*/, 0);
    diag_probe_context(0x4 /*ES2*/, 24);
    diag_probe_context(0x2 /*GL*/, 24);
}

static bool gl_init() {
    dlsym_EGL();

    g_EglDisplay = handle.eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_EglDisplay == EGL_NO_DISPLAY) {
        NSDebugLog(@"EGLBridge: eglGetDisplay(EGL_DEFAULT_DISPLAY) returned EGL_NO_DISPLAY");
        return false;
    }
    if (!handle.eglInitialize(g_EglDisplay, NULL, NULL)) {
        NSDebugLog(@"EGLBridge: Error eglInitialize() failed: 0x%x", handle.eglGetError());
        return false;
    }
    return true;
}

gl_render_window_t* gl_init_context(gl_render_window_t *share) {
    gl_render_window_t* bundle = calloc(1, sizeof(gl_render_window_t));

    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL angleDesktopGL = [renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE];

    const EGLint attribs[] = {
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT|EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, angleDesktopGL ? EGL_OPENGL_BIT : EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };

    EGLint num_configs;
    EGLint vid;
    if (!handle.eglChooseConfig(g_EglDisplay, attribs, &bundle->config, 1, &num_configs)) {
        NSDebugLog(@"EGLBridge: Error couldn't get an EGL visual config: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    if (!bundle->config || num_configs == 0) {
        NSLog(@"EGLBridge: No suitable EGL config found (num_configs=%d, config=%p)", num_configs, bundle->config);
        diag_dump_configs();
        free(bundle);
        return NULL;
    }

    if (!handle.eglGetConfigAttrib(g_EglDisplay, bundle->config, EGL_NATIVE_VISUAL_ID, &vid)) {
        NSDebugLog(@"EGLBridge: Error eglGetConfigAttrib() failed: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    EGLBoolean bindResult;
    if (angleDesktopGL) {
        NSDebugLog(@"EGLBridge: Binding to desktop OpenGL");
        bindResult = handle.eglBindAPI(EGL_OPENGL_API);
    } else {
        NSDebugLog(@"EGLBridge: Binding to OpenGL ES");
        bindResult = handle.eglBindAPI(EGL_OPENGL_ES_API);
    }
    if (!bindResult) NSDebugLog(@"EGLBridge: bind failed: %p\n", handle.eglGetError());

    CALayer *layer = SurfaceViewController.surface.layer;
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        CGSize wantSize = CGSizeMake(ml.bounds.size.width * ml.contentsScale,
                                     ml.bounds.size.height * ml.contentsScale);
        if (ml.drawableSize.width == 0 || ml.drawableSize.height == 0) {
            ml.drawableSize = wantSize;
            NSLog(@"EGLBridge: [diag] drawableSize was zero, set to %@ before surface creation", NSStringFromCGSize(ml.drawableSize));
        }
    }

    bundle->surface = handle.eglCreateWindowSurface(g_EglDisplay, bundle->config, (__bridge EGLNativeWindowType)SurfaceViewController.surface.layer, NULL);
    if (!bundle->surface) {
        NSDebugLog(@"EGLBridge: eglCreateWindowSurface finished with error: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    EGLint surfW = 0, surfH = 0;
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_WIDTH, &surfW);
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_HEIGHT, &surfH);
    NSLog(@"EGLBridge: [diag] egl surface %dx%d layer=%@ bounds=%@ scale=%.2f opaque=%d hidden=%d superlayer=%@",
          surfW, surfH, NSStringFromClass(layer.class), NSStringFromCGRect(layer.bounds),
          layer.contentsScale, layer.opaque, layer.hidden, layer.superlayer);
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        CGSize wantSize = CGSizeMake(ml.bounds.size.width * ml.contentsScale,
                                     ml.bounds.size.height * ml.contentsScale);
        if (ml.drawableSize.width == 0 || ml.drawableSize.height == 0) {
            ml.drawableSize = wantSize;
            NSLog(@"EGLBridge: [diag] drawableSize was zero, set to %@", NSStringFromCGSize(ml.drawableSize));
        }
        NSLog(@"EGLBridge: [diag] metal layer pixelFormat=0x%x framebufferOnly=%d drawableSize=%@",
              (unsigned int)ml.pixelFormat, ml.framebufferOnly, NSStringFromCGSize(ml.drawableSize));
    }

    CALayer *cl = layer;
    NSMutableString *lchain = [NSMutableString string];
    while (cl) {
        [lchain appendFormat:@"[%@ frame=%@ hidden=%d opacity=%.2f zpos=%.2f] ", NSStringFromClass(cl.class),
                             NSStringFromCGRect(cl.frame), cl.hidden, cl.opacity, cl.zPosition];
        cl = cl.superlayer;
    }
    NSLog(@"EGLBridge: [diag] layer chain: %@", lchain);

    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    if (w) {
        NSLog(@"EGLBridge: [diag] keyWindow hidden=%d rootVC=%@", w.hidden, NSStringFromClass(w.rootViewController.class));
        NSMutableString *tree = [NSMutableString string];
        __block void (^walk)(UIView *, int) = nil;
        walk = ^(UIView *v, int depth) {
            [tree appendFormat:@"\n%@[%@ frame=%@ alpha=%.2f hidden=%d userInteraction=%d layer=%@]",
                               [@"" stringByPaddingToLength:(NSUInteger)(depth * 2) withString:@" " startingAtIndex:0],
                               NSStringFromClass(v.class), NSStringFromCGRect(v.frame), v.alpha, v.hidden,
                               v.userInteractionEnabled, NSStringFromClass(v.layer.class)];
            for (UIView *sv in v.subviews) walk(sv, depth + 1);
        };
        walk(w, 0);
        NSLog(@"EGLBridge: [diag] window tree:%@", tree);
    }

    const EGLint ctx_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
    bundle->context = handle.eglCreateContext(g_EglDisplay, bundle->config, share ? share->context : EGL_NO_CONTEXT, ctx_attribs);
    if (!bundle->context) {
        NSDebugLog(@"EGLBridge: Error eglCreateContext finished with error: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    //NSDebugLog(@"EGLBridge: Created CTX pointer = %p (source = %p)", bundle->context, share?share->context:0);

    return bundle;
}

void gl_make_current(gl_render_window_t* bundle) {
    if(!bundle) {
        if(handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {
            currentBundle = NULL;
        }
        return;
    }

    if(handle.eglMakeCurrent(g_EglDisplay, bundle->surface, bundle->surface, bundle->context)) {
        currentBundle = (basic_render_window_t *)bundle;
    } else {
        NSLog(@"EGLBridge: eglMakeCurrent returned with error: 0x%x", handle.eglGetError());
    }
}

static void diag_read_pixels(EGLint w, EGLint h) {
    typedef void (*glReadPixelsFn)(int, int, int, int, unsigned int, unsigned int, void*);
    typedef unsigned int (*glGetErrorFn)(void);
    static glReadPixelsFn readPixels = NULL;
    static glGetErrorFn getError = NULL;
    if (!readPixels) {
        readPixels = (glReadPixelsFn)handle.eglGetProcAddress("glReadPixels");
        getError = (glGetErrorFn)handle.eglGetProcAddress("glGetError");
    }
    if (!readPixels) {
        NSLog(@"EGLBridge: [readback] no glReadPixels");
        return;
    }
    const int pts[][2] = { {0, 0}, {w / 2, h / 2}, {w - 1, h - 1} };
    for (int i = 0; i < 3; i++) {
        unsigned char px[4] = { 0xAB, 0xCD, 0xEF, 0x12 };
        readPixels(pts[i][0], pts[i][1], 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, px);
        NSLog(@"EGLBridge: [readback @%d,%d] R=%u G=%u B=%u A=%u err=0x%x",
              pts[i][0], pts[i][1], px[0], px[1], px[2], px[3], getError ? getError() : 0);
    }
    typedef void (*glBindFramebufferFn)(unsigned int, unsigned int);
    static glBindFramebufferFn bindFB = NULL;
    if (!bindFB) bindFB = (glBindFramebufferFn)handle.eglGetProcAddress("glBindFramebuffer");
    if (bindFB) {
        unsigned char px2[4] = { 0xAB, 0xCD, 0xEF, 0x12 };
        bindFB(0x8CA8 /*GL_READ_FRAMEBUFFER*/, 2);
        readPixels(0, 0, 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, px2);
        NSLog(@"EGLBridge: [readback-fb2 @0,0] R=%u G=%u B=%u A=%u err=0x%x",
              px2[0], px2[1], px2[2], px2[3], getError ? getError() : 0);
        bindFB(0x8CA8 /*GL_READ_FRAMEBUFFER*/, 0);
    }
}

void gl_swap_buffers() {
    if (!currentBundle) return;
    static int swapCount = 0;
    swapCount++;
    if (swapCount == 2 || swapCount == 3 || swapCount == 4 || swapCount == 5 ||
        swapCount == 10 || swapCount == 20 || swapCount == 50 || swapCount == 100 ||
        swapCount == 200 || swapCount == 300 || swapCount == 600) {
        EGLint w = 0, h = 0;
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_WIDTH, &w);
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_HEIGHT, &h);
        NSLog(@"EGLBridge: [readback] egl surface %dx%d before swap #%d", w, h, swapCount);
        diag_read_pixels(w, h);
    }
    if (!handle.eglSwapBuffers(g_EglDisplay, currentBundle->gl.surface)) {
        if (handle.eglGetError() == EGL_BAD_SURFACE)
            NSLog(@"eglSwapBuffers error 0x%x", handle.eglGetError());
    } else if (swapCount <= 5 || (swapCount % 300) == 0) {
        NSLog(@"EGLBridge: swap #%d ok", swapCount);
    }
}

void gl_swap_interval(int swapInterval) {
    handle.eglSwapInterval(g_EglDisplay, swapInterval);
}

void gl_terminate() {
    if (currentBundle) {
        handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        handle.eglDestroySurface(g_EglDisplay, currentBundle->gl.surface);
        handle.eglDestroyContext(g_EglDisplay, currentBundle->gl.context);
        free(currentBundle);
        currentBundle = nil;
    }
    handle.eglTerminate(g_EglDisplay);
    handle.eglReleaseThread();
}

void set_gl_bridge_tbl() {
    br_init = gl_init;
    br_init_context = (br_init_context_t) gl_init_context;
    br_make_current = (br_make_current_t) gl_make_current;
    br_swap_buffers = gl_swap_buffers;
    br_swap_interval = gl_swap_interval;
    br_terminate = gl_terminate;
}
