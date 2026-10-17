#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"
#import "LauncherPreferences.h"
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <os/proc.h>
#include "bridge_tbl.h"
#include "environ.h"
#include "gl_bridge.h"
#include "utils.h"

static EGLDisplay g_EglDisplay;
static egl_library handle;
static void* ltw_handle;
static void* g_mgl_handle = NULL;  // MobileGL handle for direct GL resolution

// MTLCompileOptions.mathMode / mathFloatingPointFunctions exist only on
// iOS 18+. ANGLE binaries built with minos 18+ call setMathMode: unconditionally
// (the @available guard compiles out), which raises NSInvalidArgumentException
// on iOS 16/17 inside newLibraryWithSource: during EGL_Initialize.
// Belt-and-braces alongside the minos-16.0 ANGLE rebuild: if the selectors are
// missing at runtime, install harmless no-ops so ANY present-or-future ANGLE
// binary degrades to default (safe) math mode instead of crashing.
// Getters return 0 == MTLMathModeSafe / precise-functions default.
static void mathModeNoOp(id self, SEL _cmd, NSInteger value) {
    (void)self; (void)_cmd; (void)value;
}
static NSInteger mathModeZero(id self, SEL _cmd) {
    (void)self; (void)_cmd; return 0;
}

static void installMetalMathModeCompat(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;
    // Private subclass first (the actual runtime class on iOS 16/17), then the
    // public superclass so subclass instances inherit via the normal chain.
    const char *classNames[] = { "MTLCompileOptionsInternal", "MTLCompileOptions" };
    const char *setSels[] = { "setMathMode:", "setMathFloatingPointFunctions:" };
    const char *getSels[] = { "mathMode", "mathFloatingPointFunctions" };
    for (size_t c = 0; c < sizeof(classNames) / sizeof(classNames[0]); c++) {
        Class cls = objc_getClass(classNames[c]);
        if (!cls) continue;
        for (size_t i = 0; i < sizeof(setSels) / sizeof(setSels[0]); i++) {
            SEL sel = NSSelectorFromString(@(setSels[i]));
            if (![cls instancesRespondToSelector:sel]) {
                class_addMethod(cls, sel, (IMP)mathModeNoOp, "v@:q");
                NSLog(@"[EGLBridge] installed no-op %@ on %@ (iOS <18 compat)",
                      @(setSels[i]), @(classNames[c]));
            }
        }
        for (size_t i = 0; i < sizeof(getSels) / sizeof(getSels[0]); i++) {
            SEL sel = NSSelectorFromString(@(getSels[i]));
            if (![cls instancesRespondToSelector:sel]) {
                class_addMethod(cls, sel, (IMP)mathModeZero, "q@:");
            }
        }
    }
}

// dlopen with a one-line success/failure log. ANGLE/MoltenVK/MobileGL
// mismatches are silent by default (NULL handle + later 0x300B), so every
// backend load must be visible in latestlog.txt.
static void* checked_dlopen(NSString *path, int mode, const char *label) {
    if (!path) {
        NSLog(@"[EGLBridge] dlopen %s: nil path, skipped", label);
        return NULL;
    }
    void *h = dlopen(path.UTF8String, mode);
    if (h) {
        NSLog(@"[EGLBridge] dlopen %s OK: %@", label, path.lastPathComponent);
    } else {
        NSLog(@"[EGLBridge] dlopen %s FAILED: %@ (%s)", label, path, dlerror());
    }
    return h;
}

static NSString* preferredMoltenVKPath(void) {
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    id ver = getPrefObject(@"video.moltenvk_version");
    NSString *version = (ver && [ver isKindOfClass:[NSString class]]) ? (NSString *)ver : @"1.4";
    if ([version isEqualToString:@"1.2"]) {
        NSString *p12 = [frameworks stringByAppendingPathComponent:@"libMoltenVK12.dylib"];
        if ([NSFileManager.defaultManager fileExistsAtPath:p12]) {
            return p12;
        }
        NSLog(@"[EGLBridge] libMoltenVK12.dylib missing, falling back to libMoltenVK.dylib (check video.moltenvk_version pref)");
    }
    return [frameworks stringByAppendingPathComponent:@"libMoltenVK.dylib"];
}

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
        // Pref order: video.moltenvk_version (1.2 vs 1.4) -> libvulkan.1.dylib
        // (thin re-export of MoltenVK) -> ANGLE's custom libvulkan.dylib.
        // NOTE: MOBILEGL_BACKEND_TYPE defaults to DirectVulkan in MobileGLConfig,
        // but the native default is DirectGLES — env must already be set by
        // egl_bridge.m / JavaLauncher before this runs.
        NSString *mvkPath = preferredMoltenVKPath();
        void* mvk = checked_dlopen(mvkPath, RTLD_LAZY | RTLD_GLOBAL, "MoltenVK");
        if (!mvk) {
            // Fallback: libvulkan.1.dylib is a thin re-export wrapper for MoltenVK.
            mvk = checked_dlopen([fwPath stringByAppendingPathComponent:@"libvulkan.1.dylib"],
                                 RTLD_LAZY | RTLD_GLOBAL, "libvulkan.1 (MoltenVK re-export)");
        }
        if (!mvk) {
            mvk = checked_dlopen([fwPath stringByAppendingPathComponent:@"libvulkan.dylib"],
                                 RTLD_LAZY | RTLD_GLOBAL, "libvulkan (ANGLE custom)");
        }

        // MobileGL implements the whole EGL/GL layer on top of Vulkan/MoltenVK.
        // dlopen it and resolve every EGL entry point from its own handle.
        mgl_handle = checked_dlopen([fwPath stringByAppendingPathComponent:@"libMobileGL.dylib"],
                                    RTLD_LAZY | RTLD_GLOBAL, "libMobileGL");
        if (!mgl_handle) {
            NSLog(@"[EGLBridge] FATAL: libMobileGL.dylib could not be loaded, rendering is impossible");
        }
        g_mgl_handle = mgl_handle;
        // Only load ANGLE wrapper for DirectGLES backend (fallback).
        // DirectVulkan renders through Vulkan/MoltenVK directly.
        // IMPORTANT: MobileGL's own Loader.cpp already opens the matching
        // libGLESv2_angle_{metal,vulkan} directly (bypassing the libEGL
        // front-end whose fixed Frameworks path may hold the OTHER backend).
        // This dl_handle is ONLY a fallback for resolve_egl when MobileGL
        // does not export a given symbol — it must match MOBILEGL_ANGLE_BACKEND
        // or eglCreateWindowSurface will hit EGL_BAD_NATIVE_WINDOW (0x300B).
        const char *backendType = getenv("MOBILEGL_BACKEND_TYPE");
        if (!backendType) {
            NSLog(@"[EGLBridge] MOBILEGL_BACKEND_TYPE unset, assuming DirectVulkan (MobileGLConfig default)");
        }
        if (backendType && strcmp(backendType, "DirectGLES") == 0) {
            const char *angleBackend = getenv("MOBILEGL_ANGLE_BACKEND");
            // MobileGLConfig default is tgles; egl_bridge forces the env before us.
            // "metal" is the legacy MetalANGLE value (removed) and maps to TGLES.
            BOOL useTgles = (angleBackend == NULL) ||
                            (strcmp(angleBackend, "tgles") == 0) ||
                            (strcmp(angleBackend, "metal") == 0);
            if (useTgles) {
                NSLog(@"[EGLBridge] DirectGLES backend: TGLES");
                dl_handle = checked_dlopen([fwPath stringByAppendingPathComponent:@"libtgles.dylib"],
                                           RTLD_LAZY | RTLD_GLOBAL, "libtgles");
            } else {
                const char *eglLibName = "libEGL_angle_vulkan";
                NSLog(@"[EGLBridge] DirectGLES ANGLE backend: %s", angleBackend);
                dl_handle = checked_dlopen([fwPath stringByAppendingPathComponent:@(eglLibName)],
                                           RTLD_LAZY | RTLD_GLOBAL, eglLibName);
            }
            if (!dl_handle) {
                dl_handle = checked_dlopen([fwPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"],
                                           RTLD_LAZY | RTLD_GLOBAL, "libtinygl4angle (fallback)");
            }
            if (!dl_handle) {
                NSLog(@"[EGLBridge] WARNING: no GLES fallback library; EGL symbols resolve from libMobileGL only");
            }
        }
    } else if (useMG) {
        // MobileGlues implements the whole EGL/GL layer on top of the GLES
        // backend the launcher pre-loaded into the global scope (see
        // pojavInitOpenGL). dlopen it first — its static init runs
        // init_target_egl, which probes EGL through RTLD_DEFAULT — then
        // resolve every EGL entry point from MG's own handle so the whole
        // context/surface lifecycle runs through MG's wrappers.
        mg_handle = dlopen("@rpath/libmobileglues.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (!mg_handle) mg_handle = dlopen([fwPath stringByAppendingPathComponent:@"libmobileglues.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (!mg_handle) {
            NSLog(@"EGLBridge: Failed to load libmobileglues.dylib: %s", dlerror());
        }
        // Backend image for resolve_egl's fallback. It must match what
        // pojavInitOpenGL pre-loaded: TGLES for the tgles backend (MobileGlues
        // now translates GLES through TGLES instead of MetalANGLE), the
        // libtinygl4angle/ANGLE stack when TGLES was not available.
        const char *angleBackend = getenv("MOBILEGL_ANGLE_BACKEND");
        if (angleBackend && strcmp(angleBackend, "tgles") == 0) {
            dl_handle = checked_dlopen([fwPath stringByAppendingPathComponent:@"libtgles.dylib"],
                                       RTLD_LAZY | RTLD_GLOBAL, "libtgles");
        } else {
            dl_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
            if (!dl_handle) dl_handle = dlopen([fwPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"].UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            if (!dl_handle) {
                dl_handle = dlopen("@rpath/libEGL.framework/libEGL", RTLD_GLOBAL);
            }
        }
        if (!dl_handle) {
            NSLog(@"EGLBridge: Failed to load the GLES backend library for MobileGlues");
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

// ── Which image really implements EGL? ─────────────────────────────────────
// ANGLE is shipped twice here (Metal build = Frameworks/libEGL_angle_metal +
// libGLESv2_angle_metal, Vulkan build = libEGL.framework/libEGL +
// libGLESv2.framework/libGLESv2).  Both builds export the *same* forwarder
// symbols (EGL_CreateWindowSurface, EGL_GetDisplay, ...) and both carry the same
// canonical install name, while the libEGL wrapper resolves its libGLESv2
// companion by the canonical framework path.  If that path holds the other
// backend's build, the "metal" renderer silently drives the Vulkan backend,
// which cannot bind an iOS CAMetalLayer: eglCreateWindowSurface() then fails
// with EGL_BAD_NATIVE_WINDOW (0x300B) and Minecraft aborts window creation.
// These two log lines make that swap visible in the log (path of the image that
// actually answers each entry point), so the pairing can be verified in one run.
static void log_egl_implementation(const char* tag) {
    Dl_info info;
    struct { const char* name; void* fn; } probes[] = {
        { "eglCreateWindowSurface",  (void*)handle.eglCreateWindowSurface },
        { "eglGetDisplay",           (void*)handle.eglGetDisplay },
        { "EGL_CreateWindowSurface", dlsym(RTLD_DEFAULT, "EGL_CreateWindowSurface") },
        { "EGL_GetDisplay",          dlsym(RTLD_DEFAULT, "EGL_GetDisplay") },
        { "eglInitialize",           (void*)handle.eglInitialize },
    };
    for (size_t i = 0; i < sizeof(probes) / sizeof(probes[0]); i++) {
        const char* img = "(unresolved)";
        if (probes[i].fn && dladdr(probes[i].fn, &info) && info.dli_fname) {
            img = info.dli_fname;
        }
        NSLog(@"[EGLBridge] %s impl %s -> %s", tag, probes[i].name, img);
    }
}

static bool gl_init() {
    // Must run before any ANGLE entry point: ANGLE compiles its default Metal
    // shader library during eglInitialize, which is where the iOS <18
    // setMathMode: crash happens.
    installMetalMathModeCompat();
    NSLog(@"[EGLBridge] gl_init: calling dlsym_EGL");
    dlsym_EGL();
    // Always log the implementation image: a metal/vulkan ANGLE swap is the
    // #1 cause of 0x300B and is invisible otherwise. Cheap (5 dladdr calls).
    log_egl_implementation("gl_init");

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

// ── TGLES present glue (launcher-side) ─────────────────────────────────────
// TGLES draws through its in-dylib Metal bridge, but nothing inside the dylib
// owns the game's CAMetalLayer: the host must attach it via
// tglHostAttachMetalLayer() once per window surface (and resize it via
// tglHostResizeMetalLayer() when the layer size changes; see GameSurfaceView).
// Neither MobileGL nor MobileGlues knows about these entry points, so the
// launcher performs the attach right after its window surface is created.
//
// Error attribution (see also the [TGLES] log lines below):
//   * attach FAILED (launcher)  -> launcher glue issue (dylib missing, wrong
//     layer/size). Fix in the launcher.
//   * attach OK but black screen / present errors -> TGLES-side. Report to
//     the TGLES owner with the [TGLES] + frontend log lines.
// Bump when the TGLES glue changes so a log line tells which build is on
// device (avoids diagnosing a stale install).
static const char *kTglesGlueVersion = "v16-mobileglues";
static void *gTglesLib = NULL;
static int (*gTglesAttachFn)(void *, int, int) = NULL;
static int (*gTglesReadbackFn)(int, int, unsigned char[4]) = NULL;
static void (*gTglesSetDebugLogFn)(int) = NULL;
static int (*gTglesGetDebugLogFn)(char *, int) = NULL;
static int (*gTglesEglGetErrorFn)(void) = NULL;
static CALayer *gTglesAttachedLayer = NULL;

// Cached: env + renderer never change at runtime.
//
// TGLES is the GLES backend of two renderers: MobileGL's DirectGLES path
// (chosen through MOBILEGL_BACKEND_TYPE / MOBILEGL_ANGLE_BACKEND) and
// MobileGlues, which now translates GLES through TGLES instead of
// MetalANGLE. For MobileGlues the launcher publishes the same
// MOBILEGL_ANGLE_BACKEND=tgles, and only when libtgles.dylib actually
// loaded -- an unset value means the MetalANGLE fallback is in use and the
// glue must stay off.
static BOOL tgles_is_active(void) {
    static BOOL checked = NO;
    static BOOL active = NO;
    if (checked) return active;
    checked = YES;
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL isMobileGL = [renderer isEqualToString:@ RENDERER_NAME_MOBILEGL];
    BOOL isMobileGlues = [renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES];
    if (!isMobileGL && !isMobileGlues) return active;
    const char *angleBackend = getenv("MOBILEGL_ANGLE_BACKEND");
    if (angleBackend && strcmp(angleBackend, "vulkan") == 0) return active;  // VulkanANGLE path
    if (isMobileGL) {
        const char *backendType = getenv("MOBILEGL_BACKEND_TYPE");
        if (!backendType || strcmp(backendType, "DirectGLES") != 0) return active;
    } else if (!angleBackend || strcmp(angleBackend, "tgles") != 0) {
        return active;
    }
    active = YES;
    return active;
}

static void tgles_resolve(void) {
    if (gTglesLib) return;
    NSString *tglesPath = [NSBundle.mainBundle.privateFrameworksPath
                               stringByAppendingPathComponent:@"libtgles.dylib"];
    gTglesLib = dlopen(tglesPath.UTF8String, RTLD_NOLOAD);
    if (!gTglesLib) gTglesLib = dlopen("@rpath/libtgles.dylib", RTLD_NOLOAD);
    if (!gTglesLib) gTglesLib = dlopen(tglesPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    if (gTglesLib) {
        gTglesAttachFn =
            (int (*)(void *, int, int))dlsym(gTglesLib, "tglHostAttachMetalLayer");
        gTglesReadbackFn =
            (int (*)(int, int, unsigned char[4]))dlsym(gTglesLib, "tglHostReadbackPixel");
        gTglesSetDebugLogFn =
            (void (*)(int))dlsym(gTglesLib, "tglHostSetDebugLog");
        gTglesGetDebugLogFn =
            (int (*)(char *, int))dlsym(gTglesLib, "tglHostGetDebugLog");
        gTglesEglGetErrorFn =
            (int (*)(void))dlsym(gTglesLib, "eglGetError");
    }
}

static void tgles_attach_metal_layer_if_needed(CALayer *layer) {
    if (!tgles_is_active()) return;
    if (![layer isKindOfClass:CAMetalLayer.class]) {
        NSLog(@"[TGLES] attach skipped (launcher): surface layer is %@, not CAMetalLayer",
              NSStringFromClass(layer.class));
        return;
    }
    tgles_resolve();
    if (!gTglesLib) {
        NSLog(@"[TGLES] attach FAILED (launcher): libtgles.dylib not loaded: %s", dlerror());
        return;
    }
    if (!gTglesAttachFn) {
        NSLog(@"[TGLES] attach FAILED (launcher): tglHostAttachMetalLayer missing in loaded libtgles");
        return;
    }
    CAMetalLayer *ml = (CAMetalLayer *)layer;
    CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
    int w = (int)MAX(2, ml.bounds.size.width * scale);
    int h = (int)MAX(2, ml.bounds.size.height * scale);
    if (gTglesAttachFn((__bridge void *)ml, w, h)) {
        gTglesAttachedLayer = layer;
        // Keep TGLES's fail-closed channel fully on (stderr + memory ring);
        // the launcher drains the ring in tgles_probe_diagnostics below.
        if (gTglesSetDebugLogFn) gTglesSetDebugLogFn(3);
        NSLog(@"[TGLES] attach OK: layer=%p size=%dx%d", ml, w, h);
        NSLog(@"[TGLES] glue %s caps: readback=%d dbglog=%d eglerr=%d watchdog=1",
              kTglesGlueVersion, gTglesReadbackFn ? 1 : 0,
              gTglesGetDebugLogFn ? 1 : 0, gTglesEglGetErrorFn ? 1 : 0);
        if (gTglesGetDebugLogFn) {
            NSLog(@"[TGLES] debug channel ON: TGLES fail-closed reasons will appear as [TGL-DEBUG] lines");
        } else {
            NSLog(@"[TGLES] debug channel MISSING (launcher/packaging): loaded libtgles has no tglHostGetDebugLog - stale dylib on device? Rebuild payload so Frameworks/libtgles.dylib is refreshed");
        }
    } else {
        NSLog(@"[TGLES] attach FAILED (TGLES-side): tglHostAttachMetalLayer(%p, %d, %d) returned 0 - no Metal device or bad size",
              ml, w, h);
    }
}

// Per-swap guard: if the surface view/layer was recreated after the attach
// (rotation, external display, view re-parenting), TGLES would keep
// presenting to the detached layer -> black screen. Re-attach on change.
static void tgles_ensure_attached(void) {
    if (!tgles_is_active()) return;
    CALayer *now = SurfaceViewController.surface.layer;
    if (now && now != gTglesAttachedLayer) {
        NSLog(@"[TGLES] layer changed (%p -> %p), re-attaching (launcher)",
              gTglesAttachedLayer, now);
        tgles_attach_metal_layer_if_needed(now);
    }
    // Presenting into a layer that left the window (or was hidden/opacity 0)
    // is a frozen screen where every present still "succeeds". Log the first
    // time it is seen so a freeze has a launcher-side reason in the log.
    static BOOL layerAnomalyLogged = NO;
    if (!layerAnomalyLogged) {
        CALayer *att = gTglesAttachedLayer;
        UIView *sv = SurfaceViewController.surface;
        BOOL detached = (att != nil && att.superlayer == nil);
        BOOL hidden = (att != nil && (att.hidden || att.opacity <= 0.0));
        BOOL noWindow = (sv != nil && sv.window == nil);
        if (att != nil && (detached || hidden || noWindow)) {
            layerAnomalyLogged = YES;
            NSLog(@"[TGLES] attached layer anomaly: hidden=%d super=%p opacity=%.2f surface_in_window=%d -> presents reach nothing",
                  (att.hidden || att.opacity <= 0.0) ? 1 : 0, att.superlayer,
                  att.opacity, noWindow ? 0 : 1);
        }
    }
}

// Render-log-gated diagnostics (Developer "Render error logging", default
// OFF): bridge-side pixel probe + TGLES gap-ledger dump. Answers the black
// screen split decisively:
//   * bridge pixels BLACK + screen black  -> TGLES draws nothing (TGLES-side)
//   * bridge pixels NON-BLACK + screen black -> present/compositing never
//     reaches the visible layer (launcher-side)
static void tgles_dump_gap_ledger(void) {
    if (!gTglesLib) return;
    unsigned (*countFn)(void) =
        (unsigned (*)(void))dlsym(gTglesLib, "tglesAbiGapCount");
    const char* (*nameFn)(unsigned) =
        (const char* (*)(unsigned))dlsym(gTglesLib, "tglesAbiGapName");
    unsigned long long (*callsFn)(const char*) =
        (unsigned long long (*)(const char*))dlsym(gTglesLib, "tglesAbiGapCalls");
    if (!countFn || !nameFn || !callsFn) {
        NSLog(@"[TGLES] gap dump skipped (launcher): ledger symbols missing in loaded libtgles");
        return;
    }
    unsigned total = countFn();
    unsigned hit = 0;
    for (unsigned i = 0; i < total; i++) {
        const char *n = nameFn(i);
        if (n && callsFn(n) > 0) hit++;
    }
    NSLog(@"[TGLES] gap ledger: %u/%u declared gaps called at least once (TGLES-side validation-only entry points)", hit, total);
    unsigned logged = 0;
    for (unsigned i = 0; i < total && logged < 30; i++) {
        const char *n = nameFn(i);
        unsigned long long c = n ? callsFn(n) : 0;
        if (c > 0) {
            NSLog(@"[TGLES] gap[%u] %s calls=%llu", i, n, c);
            logged++;
        }
    }
}

static void tgles_probe_diagnostics(int swapCount) {
    if (!tgles_is_active()) return;
    tgles_resolve();
    // Drain TGLES's own fail-closed ring first: it names WHY validation-only
    // paths ran (TGLES-side reasons, verbatim).
    if (gTglesGetDebugLogFn) {
        int pending = gTglesGetDebugLogFn(NULL, 0);
        if (pending > 0) {
            char dbg[4096];
            int got = gTglesGetDebugLogFn(dbg, (int)sizeof(dbg));
            if (got > 0) {
                dbg[sizeof(dbg) - 1] = '\0';
                NSLog(@"[TGL-DEBUG] %s", dbg);
            }
        }
    }
    if (gTglesReadbackFn && currentBundle) {
        EGLint w = 0, h = 0;
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_WIDTH, &w);
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_HEIGHT, &h);
        if (w <= 0 || h <= 0) {
            // Fallback: if attach/resize has not run yet (or an old dylib is
            // still on device), probe the CAMetalLayer so readback hits real
            // pixels instead of (0,0)/(-1,-1).
            CALayer *layer = SurfaceViewController.surface.layer;
            if ([layer isKindOfClass:CAMetalLayer.class]) {
                CAMetalLayer *ml = (CAMetalLayer *)layer;
                CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
                w = (EGLint)MAX(2, ml.bounds.size.width * scale);
                h = (EGLint)MAX(2, ml.bounds.size.height * scale);
            }
        }
        // 5x3 grid (coords in each tag): content can sit in any band — the
        // old 3 fixed points only saw splash corners + center.
        const int cols = 5, rows = 3;
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                const int gx = (int)((long long)(w - 1) * c / (cols - 1));
                const int gy = (int)((long long)(h - 1) * r / (rows - 1));
                unsigned char px[4] = {0};
                int ok = gTglesReadbackFn(gx, gy, px);
                NSLog(@"[TGLES] bridge pixel @%d,%d R=%u G=%u B=%u A=%u ok=%d (swap #%d)",
                      gx, gy, px[0], px[1], px[2], px[3], ok, swapCount);
            }
        }
    }
    if (swapCount == 100 || swapCount == 600) {
        tgles_dump_gap_ledger();
    }
}

// ── Swap-stall watchdog (TGLES path) ───────────────────────────────────────
// Symptom seen on-device: swaps stop mid-boot, the log goes silent and CPU
// idles — the render thread is blocked somewhere above the swap, and a hang
// leaves no stack in latestlog. The watchdog fires once per stall episode
// and drains everything attributable: last swap #, stall seconds, TGLES
// fail-closed ring + gap summary. Always on for the TGLES path (one timer
// fire per 5 s, silent while frames flow).
static uint64_t tgles_lastSwapNs = 0;
static int tgles_lastSwapCount = 0;
static BOOL tgles_watchdogArmed = NO;
static BOOL tgles_stallReported = NO;
// The timer MUST be retained: a dispatch source with no strong reference is
// released (and cancelled) as soon as the creating scope exits. A local
// variable here silently killed the watchdog in v5.
static dispatch_source_t gTglesWatchdogTimer = NULL;

static uint64_t tgles_now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static void tgles_watchdog_fire(void) {
    if (!tgles_is_active() || !currentBundle) return;
    // Benign race: written on the render thread, read here; a stale read
    // only delays the report by one interval, never invents a stall.
    uint64_t last = tgles_lastSwapNs;
    if (last == 0) return;
    uint64_t ageSec = (tgles_now_ns() - last) / 1000000000ull;
    // Stall report threshold: 20s let a freeze the user closed by hand slip
    // through. 5s matches the timer interval, so any freeze the user can
    // see still produces a [WATCHDOG] line + TGLES ring dump.
    if (ageSec < 5) {
        tgles_stallReported = NO;  // frames flowing again; re-arm
        return;
    }
    if (tgles_stallReported) return;
    tgles_stallReported = YES;
    NSLog(@"[WATCHDOG] no swap for %llu s (last swap #%d) - render thread stalled; draining TGLES state",
          ageSec, tgles_lastSwapCount);
    tgles_resolve();
    if (gTglesGetDebugLogFn) {
        int pending = gTglesGetDebugLogFn(NULL, 0);
        if (pending > 0) {
            char dbg[4096];
            int got = gTglesGetDebugLogFn(dbg, (int)sizeof(dbg));
            if (got > 0) {
                dbg[sizeof(dbg) - 1] = '\0';
                NSLog(@"[TGL-DEBUG] %s", dbg);
            }
        } else {
            NSLog(@"[WATCHDOG] TGLES debug ring empty at stall (no fail-closed reason recorded)");
        }
    }
    tgles_dump_gap_ledger();
}

static void tgles_watchdog_note_swap(int swapCount) {
    if (!tgles_is_active()) return;
    tgles_lastSwapNs = tgles_now_ns();
    tgles_lastSwapCount = swapCount;
    // Memory: the device killed the process with reason "per-process-limit"
    // (rpages = 134272 x 16 KB = exactly the 2 GiB cap, with and without the
    // increased-memory-limit entitlement) and a Jetsam kill writes nothing to
    // latestlog. Log the footprint while frames flow so the next run shows
    // which phase eats the budget and how fast. Bounded: every 3 s for the
    // first 120 samples (~6 min), then every 30 s.
    static CFAbsoluteTime tgles_lastMemLog = 0;
    static int tgles_memLogCount = 0;
    CFAbsoluteTime tgles_memNow = CFAbsoluteTimeGetCurrent();
    double tgles_memPeriod = (tgles_memLogCount < 120) ? 3.0 : 30.0;
    if (tgles_memNow - tgles_lastMemLog >= tgles_memPeriod) {
        tgles_lastMemLog = tgles_memNow;
        ++tgles_memLogCount;
        mach_task_basic_info_data_t tgles_memInfo;
        mach_msg_type_number_t tgles_memCnt = MACH_TASK_BASIC_INFO_COUNT;
        long long tgles_residentMb = -1;
        if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                      (task_info_t)&tgles_memInfo, &tgles_memCnt) == KERN_SUCCESS) {
            tgles_residentMb = (long long)(tgles_memInfo.resident_size / (1024 * 1024));
        }
        // task_vm_info splits the footprint the kill actually charges:
        // internal (anonymous: JVM heap, native heaps, facade CPU buffers) vs
        // compressed (evicted pages still owned) vs external (IOKit/GPU).
        // phys_footprint is what Jetsam compares against the limit. The count
        // from a newer SDK can exceed what the running kernel exposes, so
        // retry with an older revision before giving up (an all-failed call
        // here is why the earlier sampler emitted zero lines).
        long long tgles_footprintMb = -1, tgles_internalMb = -1;
        long long tgles_compressedMb = -1, tgles_externalMb = -1;
        int tgles_tviOk = 0;
        {
            task_vm_info_data_t vmInfo;
            mach_msg_type_number_t vmCnt = TASK_VM_INFO_COUNT;
            if (task_info(mach_task_self(), TASK_VM_INFO,
                          (task_info_t)&vmInfo, &vmCnt) != KERN_SUCCESS) {
                vmCnt = TASK_VM_INFO_REV1_COUNT;
                if (task_info(mach_task_self(), TASK_VM_INFO,
                              (task_info_t)&vmInfo, &vmCnt) != KERN_SUCCESS) {
                    vmInfo = (task_vm_info_data_t){0};
                } else {
                    tgles_tviOk = 2;
                }
            } else {
                tgles_tviOk = 1;
            }
            if (tgles_tviOk) {
                tgles_footprintMb = (long long)(vmInfo.phys_footprint / (1024 * 1024));
                tgles_internalMb = (long long)(vmInfo.internal / (1024 * 1024));
                tgles_compressedMb = (long long)(vmInfo.compressed / (1024 * 1024));
                tgles_externalMb = (long long)(vmInfo.external / (1024 * 1024));
                if (tgles_residentMb < 0) {
                    tgles_residentMb = (long long)(vmInfo.resident_size / (1024 * 1024));
                }
            }
        }
        long long tgles_availMb = -1;
        size_t tgles_avail = os_proc_available_memory();
        if (tgles_avail > 0) {
            tgles_availMb = (long long)(tgles_avail / (1024 * 1024));
        }
        NSLog(@"[MEM] #%d resident=%lldMB footprint=%lldMB internal=%lldMB "
              @"compressed=%lldMB external=%lldMB tvi=%d avail_of_cap=%lldMB swap=%d",
              tgles_memLogCount, tgles_residentMb, tgles_footprintMb,
              tgles_internalMb, tgles_compressedMb, tgles_externalMb,
              tgles_tviOk, tgles_availMb, swapCount);
    }
    if (tgles_watchdogArmed) return;
    tgles_watchdogArmed = YES;
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    gTglesWatchdogTimer =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    if (!gTglesWatchdogTimer) return;
    dispatch_source_set_timer(gTglesWatchdogTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                              (uint64_t)(5 * NSEC_PER_SEC), (uint64_t)(1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(gTglesWatchdogTimer, ^{ tgles_watchdog_fire(); });
    dispatch_resume(gTglesWatchdogTimer);
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
    // Safety net for ANGLE's iOS WSI (mirrors GameSurfaceView): the layer must
    // be a CAMetalLayer with BGRA8 + framebufferOnly=NO + non-zero drawableSize
    // at eglCreateWindowSurface time, or ANGLE returns EGL_BAD_NATIVE_WINDOW.
    // GameSurfaceView already sets these in init/layout, but the surface view
    // can be recreated (rotation / external display) after that.
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        if (ml.pixelFormat != MTLPixelFormatBGRA8Unorm) {
            ml.pixelFormat = MTLPixelFormatBGRA8Unorm;
            NSLog(@"[EGLBridge] metal layer pixelFormat corrected to BGRA8Unorm for ANGLE");
        }
        if (ml.framebufferOnly != NO) {
            ml.framebufferOnly = NO;
        }
        CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
        CGSize wantSize = CGSizeMake(MAX(2, ml.bounds.size.width * scale),
                                     MAX(2, ml.bounds.size.height * scale));
        if (ml.drawableSize.width < 2 || ml.drawableSize.height < 2) {
            ml.drawableSize = wantSize;
            NSLog(@"[EGLBridge] drawableSize was %.0fx%.0f, set to %@ before surface creation",
                  ml.drawableSize.width, ml.drawableSize.height, NSStringFromCGSize(ml.drawableSize));
        }
        if (!ml.superlayer) {
            NSLog(@"[EGLBridge] WARNING: CAMetalLayer has no superlayer yet (view not attached); surface creation may fail with 0x300B");
        }
    } else {
        NSLog(@"[EGLBridge] WARNING: surface layer is %@, not CAMetalLayer - GLES-on-Metal backends (TGLES/ANGLE) require CAMetalLayer",
              NSStringFromClass(layer.class));
    }

    bundle->surface = handle.eglCreateWindowSurface(g_EglDisplay, bundle->config, (__bridge EGLNativeWindowType)SurfaceViewController.surface.layer, NULL);
    if (!bundle->surface) {
        EGLint err = handle.eglGetError();
        NSLog(@"[EGLBridge] eglCreateWindowSurface failed: 0x%x (EGL_BAD_NATIVE_WINDOW=0x300b, EGL_BAD_MATCH=0x3009)", err);
        if (err == EGL_BAD_NATIVE_WINDOW) {
            // Either the layer handed over was not a valid CAMetalLayer, or the EGL
            // implementation we resolved is not the one matching the loaded ANGLE
            // backend (see log_egl_implementation above).
            // For MobileGL DirectGLES: check MOBILEGL_ANGLE_BACKEND (metal vs vulkan)
            // matches the actually-loaded libGLESv2_angle_* image below. A swap means
            // both backends got dlopened in one process (dyld dedup by install_name)
            // — changing angle_backend requires a full app restart.
            NSLog(@"[EGLBridge] native window = %@ (bounds=%@ scale=%.2f, class=%@)",
                  SurfaceViewController.surface.layer, NSStringFromCGRect(SurfaceViewController.surface.layer.bounds),
                  SurfaceViewController.surface.layer.contentsScale,
                  NSStringFromClass(SurfaceViewController.surface.layer.class));
            NSLog(@"[EGLBridge] MOBILEGL_BACKEND_TYPE=%s MOBILEGL_ANGLE_BACKEND=%s (DirectGLES: tgles=TGLES libtgles.dylib, vulkan=VulkanANGLE - changing angle_backend requires a full app restart)",
                  getenv("MOBILEGL_BACKEND_TYPE") ?: "(unset)",
                  getenv("MOBILEGL_ANGLE_BACKEND") ?: "(unset)");
            log_egl_implementation("surface-failure");
        }
        free(bundle);
        return NULL;
    }

    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *ml = (CAMetalLayer *)layer;
        CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
        CGSize wantSize = CGSizeMake(MAX(2, ml.bounds.size.width * scale),
                                     MAX(2, ml.bounds.size.height * scale));
        if (ml.drawableSize.width < 2 || ml.drawableSize.height < 2) {
            ml.drawableSize = wantSize;
        }
    }

    // TGLES (MobileGL DirectGLES / MobileGlues): the window surface exists
    // now, so attach the CAMetalLayer to TGLES's in-dylib Metal bridge. No-op
    // for every other renderer/backend.
    tgles_attach_metal_layer_if_needed(layer);

    if (EGLRenderLogEnabled()) {
    EGLint surfW = 0, surfH = 0;
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_WIDTH, &surfW);
    handle.eglQuerySurface(g_EglDisplay, bundle->surface, EGL_HEIGHT, &surfH);
    if (surfW <= 0 || surfH <= 0) {
        // Frontend MobileGL SurfaceObject starts Width=0 until ResizeSurface;
        // probe the CAMetalLayer so the diag names real drawable pixels.
        if ([layer isKindOfClass:CAMetalLayer.class]) {
            CAMetalLayer *ml2 = (CAMetalLayer *)layer;
            CGFloat sc = ml2.contentsScale > 0 ? ml2.contentsScale : UIScreen.mainScreen.scale;
            surfW = (EGLint)MAX(2, ml2.bounds.size.width * sc);
            surfH = (EGLint)MAX(2, ml2.bounds.size.height * sc);
        }
    }
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
            // Query the real integer version (GL_MAJOR/MINOR_VERSION), not
            // GL_VERSION (0x1F02, string-only — Integerv on it always yields
            // INVALID_ENUM 0x500 and confuses log triage).
            int major = 0, minor = 0;
            testGetIntegerv(0x821B /* GL_MAJOR_VERSION */, &major);
            testGetIntegerv(0x821C /* GL_MINOR_VERSION */, &minor);
            EGLint glErr = testGetError ? testGetError() : -1;
            NSLog(@"[EGLBridge] DIAG GL_VERSION(int)=%d.%d err=0x%x", major, minor, glErr);
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
    if (w <= 0 || h <= 0) {
        // Window surfaces report 0x0 before tglHostAttachMetalLayer /
        // tglHostResizeMetalLayer mirrors the drawable size (and old dylibs
        // on device may still lack that fix). Probing (0,0)/(-1,-1) then
        // always yields INVALID_FRAMEBUFFER_OPERATION with untouched 0xAB..
        // pattern — pure log noise. Skip; tgles_probe_diagnostics already
        // falls back to the CAMetalLayer size for the authoritative pixels.
        NSLog(@"EGLBridge: [readback] skipped, egl surface %dx%d has no size (window surface, see TGLES bridge pixels)", w, h);
        return;
    }
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
    // 5x3 grid (coords in each tag): menu/loading content can occupy any
    // band — the old 3 fixed points only ever saw splash corners + center.
    const int cols = 5, rows = 3;
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            const int x = (int)((long long)(w - 1) * c / (cols - 1));
            const int y = (int)((long long)(h - 1) * r / (rows - 1));
            unsigned char px[4] = { 0xAB, 0xCD, 0xEF, 0x12 };
            readPixels(x, y, 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, px);
            NSLog(@"EGLBridge: [readback @%d,%d] R=%u G=%u B=%u A=%u err=0x%x",
                  x, y, px[0], px[1], px[2], px[3], getError ? getError() : 0);
        }
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
    tgles_watchdog_note_swap(swapCount);
    // TGLES: re-attach if the surface layer was recreated since the attach
    // (rotation / external display / re-parenting). Pointer compare per swap
    // is trivial; the attach itself runs only on change.
    tgles_ensure_attached();
    if (EGLRenderLogEnabled() &&
        (swapCount == 2 || swapCount == 3 || swapCount == 4 || swapCount == 5 ||
         swapCount == 10 || swapCount == 20 || swapCount == 50 || swapCount == 100 ||
         swapCount == 200 || swapCount == 300 || swapCount == 600)) {
        EGLint w = 0, h = 0;
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_WIDTH, &w);
        handle.eglQuerySurface(g_EglDisplay, currentBundle->gl.surface, EGL_HEIGHT, &h);
        if (w <= 0 || h <= 0) {
            // Frontend SurfaceObject may still be 0x0 if backend attach has
            // not published size yet; probe the CAMetalLayer for real pixels.
            CALayer *layer3 = SurfaceViewController.surface.layer;
            if ([layer3 isKindOfClass:CAMetalLayer.class]) {
                CAMetalLayer *ml3 = (CAMetalLayer *)layer3;
                CGFloat sc3 = ml3.contentsScale > 0 ? ml3.contentsScale : UIScreen.mainScreen.scale;
                w = (EGLint)MAX(2, ml3.bounds.size.width * sc3);
                h = (EGLint)MAX(2, ml3.bounds.size.height * sc3);
            }
        }
        NSLog(@"EGLBridge: [readback] egl surface %dx%d before swap #%d", w, h, swapCount);
        diag_read_pixels(w, h);
        // TGLES bridge-side pixels + (at #600) gap ledger: tells black-screen
        // apart (TGLES draws nothing vs present never reaches the screen).
        tgles_probe_diagnostics(swapCount);
    }
    if (!handle.eglSwapBuffers(g_EglDisplay, currentBundle->gl.surface)) {
        if (handle.eglGetError() == EGL_BAD_SURFACE)
            NSLog(@"eglSwapBuffers error 0x%x", handle.eglGetError());
    } else if (EGLRenderLogEnabled() && (swapCount <= 5 || (swapCount % 300) == 0)) {
        NSLog(@"EGLBridge: swap #%d ok", swapCount);
    }
    // TGLES host error poll (render-log only): the backend's host swap runs
    // inside the frontend swap above on this same thread. A latched host
    // error (e.g. 0x3003 BAD_ALLOC from an empty TGLES Present) names the
    // failing stage; draining it also keeps stale errors out of later probes.
    if (EGLRenderLogEnabled() && tgles_is_active() && gTglesEglGetErrorFn) {
        int hostErr = gTglesEglGetErrorFn();
        if (hostErr != 0x3000 /*EGL_SUCCESS*/) {
            NSLog(@"[TGLES] host egl error after swap #%d: 0x%x (0x3003=BAD_ALLOC empty present, 0x300d=BAD_SURFACE, 0x300b=BAD_NATIVE_WINDOW)",
                  swapCount, hostErr);
        }
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
