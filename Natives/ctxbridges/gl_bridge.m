#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"
#import <QuartzCore/QuartzCore.h>

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include "bridge_tbl.h"
#include "environ.h"
#include "gl_bridge.h"
#include "utils.h"

static EGLDisplay g_EglDisplay;
static egl_library handle;
static void* ltw_handle;
static void* g_mgl_handle = NULL;  // MobileGL handle for direct GL resolution

// Render-log gate (Developer option "Render error logging", default OFF).
// When OFF, all per-frame diagnostics (glReadPixels readbacks, swap logs,
// layer/window dumps) are skipped so logging can never throttle the
// CPU/GPU or pollute the GL error state mid-frame.
static BOOL EGLRenderLogEnabled(void) {
    static BOOL checked = NO;
    static BOOL enabled = NO;
    if (!checked) {
        checked = YES;
        const char *v = getenv("AMETHYST_RENDER_LOG");
        enabled = (v && v[0] == '1');
    }
    return enabled;
}

static void* resolve_egl(void* from, void* fallback, const char* name) {
    void* fn = from ? dlsym(from, name) : NULL;
    if (!fn && fallback && fallback != from) fn = dlsym(fallback, name);
    if (!fn) fn = dlsym(RTLD_DEFAULT, name);
    return fn;
}

// Resolve a GL function, preferring MobileGL's own symbol to avoid
// flat_namespace collision with MobileGlues/libtinygl4angle.
static void* resolve_gl(const char* name) {
    if (g_mgl_handle) {
        void* fn = dlsym(g_mgl_handle, name);
        if (fn) return fn;
    }
    return handle.eglGetProcAddress ? handle.eglGetProcAddress(name) : NULL;
}

void dlsym_EGL() {
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL useLTW = [@ RENDERER_NAME_LTW isEqualToString: renderer];
    BOOL useMG = [@ RENDERER_NAME_MOBILEGLUES isEqualToString: renderer];
    BOOL useMGL = [@ RENDERER_NAME_MOBILEGL isEqualToString: renderer];

    void* dl_handle = NULL;   // ANGLE backend
    void* mg_handle = NULL;   // MobileGlues layer (MG renderer only)
    void* mgl_handle = NULL;  // MobileGL layer (MGL renderer only)
    NSString *fwPath = NSBundle.mainBundle.privateFrameworksPath;

    if (useMGL) {
        // MobileGL links Vulkan symbols (vkCreateInstance etc.) at build time
        // but does NOT link a Vulkan library on iOS (MOBILEGL_VULKAN_LIBRARY was empty).
        // We must load MoltenVK FIRST with RTLD_GLOBAL so its Vulkan symbols are
        // in the global symbol table when MobileGL's VulkanRenderer resolves them.
        void* mvk = dlopen("@rpath/libMoltenVK.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (!mvk) mvk = dlopen([fwPath stringByAppendingPathComponent:@"libMoltenVK.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!mvk) {
            // Fallback: libvulkan.dylib is a thin loader wrapper
            mvk = dlopen("@rpath/libvulkan.dylib", RTLD_LAZY | RTLD_GLOBAL);
            if (!mvk) mvk = dlopen([fwPath stringByAppendingPathComponent:@"libvulkan.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        }
        NSLog(@"[EGLBridge] MoltenVK preload: %s", mvk ? "OK" : dlerror());

        // MobileGL implements the whole EGL/GL layer on top of Vulkan/MoltenVK.
        // dlopen it and resolve every EGL entry point from its own handle.
        mgl_handle = dlopen("@rpath/libMobileGL.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (!mgl_handle) mgl_handle = dlopen([fwPath stringByAppendingPathComponent:@"libMobileGL.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!mgl_handle) {
            NSLog(@"EGLBridge: Failed to load libMobileGL.dylib: %s", dlerror());
        }
        g_mgl_handle = mgl_handle;
        // Only load ANGLE wrapper for DirectGLES backend (fallback).
        // DirectVulkan renders through Vulkan/MoltenVK directly.
        const char *backendType = getenv("MOBILEGL_BACKEND_TYPE");
        if (backendType && strcmp(backendType, "DirectGLES") == 0) {
            dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
            if (!dl_handle) dl_handle = dlopen([fwPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        }
    } else if (useMG) {
        // MobileGlues implements the whole EGL/GL layer on top of the ANGLE
        // frameworks. dlopen it first — its static init loads and binds the
        // ANGLE backend (libGLESv2/libEGL) itself, so load order does not
        // matter — then resolve every EGL entry point from MG's own handle so
        // the whole context/surface lifecycle runs through MG's wrappers.
        mg_handle = dlopen("@rpath/libmobileglues.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (!mg_handle) mg_handle = dlopen([fwPath stringByAppendingPathComponent:@"libmobileglues.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!mg_handle) {
            NSLog(@"EGLBridge: Failed to load libmobileglues.dylib: %s", dlerror());
        }
        // Make sure the ANGLE backend is present for fallback resolution.
        dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
        if (!dl_handle) dl_handle = dlopen([fwPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!dl_handle) {
            dl_handle = dlopen("@rpath/libEGL.framework/libEGL", RTLD_GLOBAL);
        }
        if (!dl_handle) {
            NSLog(@"EGLBridge: Failed to load ANGLE EGL library");
        }
    } else {
        dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
        if (!dl_handle) dl_handle = dlopen([fwPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!dl_handle) {
            dl_handle = dlopen("@rpath/libEGL.framework/libEGL", RTLD_LOCAL);
        }
        if (!dl_handle) {
            NSLog(@"EGLBridge: Failed to load ANGLE EGL library");
            return;
        }
    }

    void* primary_handle = useMGL ? mgl_handle : (useMG ? mg_handle : NULL);
    handle.eglBindAPI = resolve_egl(primary_handle, dl_handle, "eglBindAPI");
    handle.eglChooseConfig = resolve_egl(primary_handle, dl_handle, "eglChooseConfig");
    handle.eglCreateContext = resolve_egl(primary_handle, dl_handle, "eglCreateContext");
    handle.eglDestroyContext = resolve_egl(primary_handle, dl_handle, "eglDestroyContext");
    handle.eglMakeCurrent = resolve_egl(primary_handle, dl_handle, "eglMakeCurrent");
    handle.eglGetProcAddress = resolve_egl(primary_handle, dl_handle, "eglGetProcAddress");
    handle.eglCreateWindowSurface = resolve_egl(primary_handle, dl_handle, "eglCreateWindowSurface");
    handle.eglDestroySurface = resolve_egl(primary_handle, dl_handle, "eglDestroySurface");
    handle.eglGetConfigAttrib = resolve_egl(primary_handle, dl_handle, "eglGetConfigAttrib");
    handle.eglGetCurrentContext = resolve_egl(primary_handle, dl_handle, "eglGetCurrentContext");
    handle.eglGetDisplay = resolve_egl(primary_handle, dl_handle, "eglGetDisplay");
    handle.eglGetError = resolve_egl(primary_handle, dl_handle, "eglGetError");
    handle.eglGetPlatformDisplay = resolve_egl(primary_handle, dl_handle, "eglGetPlatformDisplay");
    handle.eglInitialize = resolve_egl(primary_handle, dl_handle, "eglInitialize");
    handle.eglSwapBuffers = resolve_egl(primary_handle, dl_handle, "eglSwapBuffers");
    handle.eglReleaseThread = resolve_egl(primary_handle, dl_handle, "eglReleaseThread");
    handle.eglSwapInterval = resolve_egl(primary_handle, dl_handle, "eglSwapInterval");
    handle.eglTerminate = resolve_egl(primary_handle, dl_handle, "eglTerminate");
    handle.eglGetCurrentSurface = resolve_egl(primary_handle, dl_handle, "eglGetCurrentSurface");
    handle.eglGetConfigs = resolve_egl(primary_handle, dl_handle, "eglGetConfigs");
    handle.eglQueryString = resolve_egl(primary_handle, dl_handle, "eglQueryString");
    handle.eglQuerySurface = resolve_egl(primary_handle, dl_handle, "eglQuerySurface");
    handle.eglCreatePbufferSurface = resolve_egl(primary_handle, dl_handle, "eglCreatePbufferSurface");

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

    if (useMGL && mgl_handle) {
        // MobileGL exports GL functions via eglGetProcAddress.
        // Resolve eglGetProcAddress from MobileGL so GL lookups go through its dispatch.
        handle.eglGetProcAddress = dlsym(mgl_handle, "eglGetProcAddress");
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
        glGetStringFn glGetString = (glGetStringFn)resolve_gl("glGetString");
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
    NSLog(@"[EGLBridge] gl_init: calling dlsym_EGL");
    dlsym_EGL();

    if (!handle.eglGetDisplay) {
        NSLog(@"[EGLBridge] FATAL eglGetDisplay not resolved");
        return false;
    }
    NSLog(@"[EGLBridge] gl_init: calling eglGetDisplay");
    g_EglDisplay = handle.eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_EglDisplay == EGL_NO_DISPLAY) {
        NSLog(@"[EGLBridge] eglGetDisplay(EGL_DEFAULT_DISPLAY) returned EGL_NO_DISPLAY");
        return false;
    }
    if (!handle.eglInitialize) {
        NSLog(@"[EGLBridge] FATAL eglInitialize not resolved");
        return false;
    }
    NSLog(@"[EGLBridge] gl_init: calling eglInitialize");
    if (!handle.eglInitialize(g_EglDisplay, NULL, NULL)) {
        NSLog(@"[EGLBridge] eglInitialize() failed: 0x%x", handle.eglGetError());
        return false;
    }
    NSLog(@"[EGLBridge] gl_init: success");
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
        NSLog(@"[EGLBridge] Error couldn't get an EGL visual config: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    if (!bundle->config || num_configs == 0) {
        NSLog(@"[EGLBridge] No suitable EGL config found (num_configs=%d, config=%p)", num_configs, bundle->config);
        diag_dump_configs();
        free(bundle);
        return NULL;
    }

    if (!handle.eglGetConfigAttrib(g_EglDisplay, bundle->config, EGL_NATIVE_VISUAL_ID, &vid)) {
        NSLog(@"[EGLBridge] Error eglGetConfigAttrib() failed: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    EGLBoolean bindResult;
    if (angleDesktopGL) {
        NSLog(@"[EGLBridge] Binding to desktop OpenGL");
        bindResult = handle.eglBindAPI(EGL_OPENGL_API);
    } else {
        NSLog(@"[EGLBridge] Binding to OpenGL ES");
        bindResult = handle.eglBindAPI(EGL_OPENGL_ES_API);
    }
    if (!bindResult) NSLog(@"[EGLBridge] bind failed: %p\n", handle.eglGetError());

    CALayer *layer = SurfaceViewController.surface.layer;
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        CGSize wantSize = CGSizeMake(ml.bounds.size.width * ml.contentsScale,
                                     ml.bounds.size.height * ml.contentsScale);
        if (ml.drawableSize.width == 0 || ml.drawableSize.height == 0) {
            ml.drawableSize = wantSize;
            if (EGLRenderLogEnabled())
            NSLog(@"EGLBridge: [diag] drawableSize was zero, set to %@ before surface creation", NSStringFromCGSize(ml.drawableSize));
        }
    }

    bundle->surface = handle.eglCreateWindowSurface(g_EglDisplay, bundle->config, (__bridge EGLNativeWindowType)SurfaceViewController.surface.layer, NULL);
    if (!bundle->surface) {
        NSLog(@"[EGLBridge] eglCreateWindowSurface failed: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        CGSize wantSize = CGSizeMake(ml.bounds.size.width * ml.contentsScale,
                                     ml.bounds.size.height * ml.contentsScale);
        if (ml.drawableSize.width == 0 || ml.drawableSize.height == 0) {
            ml.drawableSize = wantSize;
        }
    }

    if (EGLRenderLogEnabled()) {
    EGLint surfW = 0, surfH = 0;
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_WIDTH, &surfW);
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_HEIGHT, &surfH);
    NSLog(@"EGLBridge: [diag] egl surface %dx%d layer=%@ bounds=%@ scale=%.2f opaque=%d hidden=%d superlayer=%@",
          surfW, surfH, NSStringFromClass(layer.class), NSStringFromCGRect(layer.bounds),
          layer.contentsScale, layer.opaque, layer.hidden, layer.superlayer);
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
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
    }

    const EGLint ctx_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
    bundle->context = handle.eglCreateContext(g_EglDisplay, bundle->config, share ? share->context : EGL_NO_CONTEXT, ctx_attribs);
    if (!bundle->context) {
        NSLog(@"[EGLBridge] eglCreateContext failed: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    NSLog(@"[EGLBridge] gl_init_context: OK surface=%p context=%p", bundle->surface, bundle->context);
    //NSDebugLog(@"EGLBridge: Created CTX pointer = %p (source = %p)", bundle->context, share?share->context:0);

    return bundle;
}

void gl_make_current(gl_render_window_t* bundle) {
    if(!bundle) {
        NSLog(@"[EGLBridge] gl_make_current: unbinding");
        if(handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {
            currentBundle = NULL;
        }
        return;
    }

    NSLog(@"[EGLBridge] gl_make_current: display=%p surface=%p context=%p",
          (void*)g_EglDisplay, (void*)bundle->surface, (void*)bundle->context);
    if(handle.eglMakeCurrent(g_EglDisplay, bundle->surface, bundle->surface, bundle->context)) {
        currentBundle = (basic_render_window_t *)bundle;
        NSLog(@"[EGLBridge] gl_make_current: OK, currentBundle=%p", currentBundle);

        // --- Deep diagnostic: verify MobileGL EGL state ---
        typedef void* (*eglGetCurrentContextFn)(void);
        eglGetCurrentContextFn gCtx = (eglGetCurrentContextFn)handle.eglGetCurrentContext;
        NSLog(@"[EGLBridge] DIAG eglGetCurrentContext=%p", gCtx ? gCtx() : NULL);

        // --- Test VK function availability (Vulkan symbols from MoltenVK) ---
        void* vkLib = dlopen("@rpath/libMoltenVK.dylib", RTLD_NOLOAD);
        if (vkLib) {
            void* vkCreate = dlsym(vkLib, "vkCreateInstance");
            void* vkGetProc = dlsym(vkLib, "vkGetInstanceProcAddr");
            NSLog(@"[EGLBridge] DIAG MoltenVK vkCreateInstance=%p vkGetInstanceProcAddr=%p", vkCreate, vkGetProc);
            dlclose(vkLib);
        }

        // --- Test GL functions (via MobileGL dlsym, bypassing flat_namespace collision) ---
        typedef const unsigned char* (*glGetStringFn)(unsigned int);
        typedef int (*glGetErrorFn)(void);
        typedef void (*glGetIntegervFn)(unsigned int, int*);
        glGetStringFn testGetString = (glGetStringFn)resolve_gl("glGetString");
        glGetErrorFn testGetError = (glGetErrorFn)resolve_gl("glGetError");
        glGetIntegervFn testGetIntegerv = (glGetIntegervFn)resolve_gl("glGetIntegerv");
        NSLog(@"[EGLBridge] DIAG resolve_gl: glGetError=%p glGetString=%p glGetIntegerv=%p",
              testGetError, testGetString, testGetIntegerv);

        if (testGetError) NSLog(@"[EGLBridge] DIAG glGetError()=0x%x", testGetError());
        if (testGetIntegerv) {
            int major = 0, minor = 0;
            testGetIntegerv(0x1F02 /* GL_VERSION */, &major); // intentionally wrong enum to test
            NSLog(@"[EGLBridge] DIAG GL_VERSION(int)=%d err=0x%x", major, testGetError ? testGetError() : -1);
        }
        if (testGetString) {
            const unsigned char* ver = testGetString(0x1F02 /* GL_VERSION */);
            NSLog(@"[EGLBridge] DIAG GL_VERSION(str)=%s", ver ? (const char*)ver : "(null)");
            const unsigned char* vendor = testGetString(0x1F00 /* GL_VENDOR */);
            NSLog(@"[EGLBridge] DIAG GL_VENDOR=%s", vendor ? (const char*)vendor : "(null)");
            const unsigned char* renderer = testGetString(0x1F01 /* GL_RENDERER */);
            NSLog(@"[EGLBridge] DIAG GL_RENDERER=%s", renderer ? (const char*)renderer : "(null)");
        }
    } else {
        NSLog(@"[EGLBridge] eglMakeCurrent returned with error: 0x%x", handle.eglGetError());
    }
}

static void diag_read_pixels(EGLint w, EGLint h) {
    typedef void (*glReadPixelsFn)(int, int, int, int, unsigned int, unsigned int, void*);
    typedef unsigned int (*glGetErrorFn)(void);
    static glReadPixelsFn readPixels = NULL;
    static glGetErrorFn getError = NULL;
    if (!readPixels) {
        readPixels = (glReadPixelsFn)resolve_gl("glReadPixels");
        getError = (glGetErrorFn)resolve_gl("glGetError");
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
    typedef void (*glGetIntegervFn)(unsigned int, int *);
    static glBindFramebufferFn bindFB = NULL;
    static glGetIntegervFn getIntegerv = NULL;
    if (!bindFB) {
        bindFB = (glBindFramebufferFn)resolve_gl("glBindFramebuffer");
        getIntegerv = (glGetIntegervFn)resolve_gl("glGetIntegerv");
    }
    if (bindFB) {
        // Save the game's READ_FRAMEBUFFER binding and restore it afterwards
        // so the probe can never disturb game rendering or leave a GL error
        // behind for the game's own glGetError checks.
        int prevReadFB = 0;
        if (getIntegerv) getIntegerv(0x8CA6 /*GL_READ_FRAMEBUFFER_BINDING*/, &prevReadFB);
        unsigned char px2[4] = { 0xAB, 0xCD, 0xEF, 0x12 };
        bindFB(0x8CA8 /*GL_READ_FRAMEBUFFER*/, 2);
        readPixels(0, 0, 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, px2);
        NSLog(@"EGLBridge: [readback-fb2 @0,0] R=%u G=%u B=%u A=%u err=0x%x",
              px2[0], px2[1], px2[2], px2[3], getError ? getError() : 0);
        bindFB(0x8CA8 /*GL_READ_FRAMEBUFFER*/, (unsigned int)prevReadFB);
        // Drain any error the probe itself produced.
        if (getError) while (getError() != 0) {}
    }
}

void gl_swap_buffers() {
    if (!currentBundle) return;
    static int swapCount = 0;
    swapCount++;
    if (EGLRenderLogEnabled() &&
        (swapCount == 2 || swapCount == 3 || swapCount == 4 || swapCount == 5 ||
         swapCount == 10 || swapCount == 20 || swapCount == 50 || swapCount == 100 ||
         swapCount == 200 || swapCount == 300 || swapCount == 600)) {
        EGLint w = 0, h = 0;
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_WIDTH, &w);
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_HEIGHT, &h);
        NSLog(@"EGLBridge: [readback] egl surface %dx%d before swap #%d", w, h, swapCount);
        diag_read_pixels(w, h);
    }
    if (!handle.eglSwapBuffers(g_EglDisplay, currentBundle->gl.surface)) {
        if (handle.eglGetError() == EGL_BAD_SURFACE)
            NSLog(@"eglSwapBuffers error 0x%x", handle.eglGetError());
    } else if (EGLRenderLogEnabled() && (swapCount <= 5 || (swapCount % 300) == 0)) {
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
