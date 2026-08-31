#import "SurfaceViewController.h"
#import "framegen/framegen.h"
#import "LauncherPreferences.h"

#include "jni.h"
#include <assert.h>
#include <dlfcn.h>

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "EGL/egl.h"
#include "EGL/eglext.h"
#include "GL/osmesa.h"

#include "glfw_keycodes.h"
#include "ctxbridges/bridge_tbl.h"
#include "ctxbridges/osmesa_internal.h"
#include "utils.h"
#include "ZinkConfig.h"

void aasdl_setMainReady(NSString *nativesDir);

int clientAPI;
__thread basic_render_window_t* currentBundle;

// Counts every game frame swap so the in-game widget can show real FPS.
// The game may present through different paths depending on renderer:
//   * pojavSwapBuffers() called straight from the game's JNI (GL renderers)
//   * libmobileglues.dylib's exported eglSwapBuffers (mobileglues_swap_count)
//   * MoltenVK/Vulkan (e.g. Minecraft 26.3 snapshot): frames bypass the bridge
//     entirely and only surface as a Metal drawable, so we also count
//     CAMetalLayer -nextDrawable calls, which every renderer makes once per
//     presented frame. MAX() is safe: for GL renderers the drawable count is
//     identical to the swap count, and for Vulkan the swap counts stay 0.
#include <dlfcn.h>
#include <stdatomic.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static atomic_uint_fast64_t widgetSwapCountOwn;
static atomic_uint_fast64_t widgetMetalFrameCount;

static IMP origNextDrawable;
static IMP origNextDrawableWithSize;

static id widgetSwizzledNextDrawable(id self, SEL _cmd) {
    atomic_fetch_add_explicit(&widgetMetalFrameCount, 1, memory_order_relaxed);
    id drawable = ((id (*)(id, SEL))origNextDrawable)(self, _cmd);
    if (fg_is_enabled() && fg_is_supported()) {
        fg_on_next_drawable(drawable, (CAMetalLayer*)self);
    }
    return drawable;
}

static id widgetSwizzledNextDrawableWithSize(id self, SEL _cmd, CGSize size) {
    atomic_fetch_add_explicit(&widgetMetalFrameCount, 1, memory_order_relaxed);
    id drawable = ((id (*)(id, SEL, CGSize))origNextDrawableWithSize)(self, _cmd, size);
    if (fg_is_enabled() && fg_is_supported()) {
        fg_on_next_drawable(drawable, (CAMetalLayer*)self);
    }
    return drawable;
}

static void widgetHookMetalOnce(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Only install the CAMetalLayer swizzle when Frame Generation is ON.
        // The swizzle intercepts MoltenVK's nextDrawable globally — even as a
        // passthrough it can interfere with the rendering pipeline, causing
        // black screens when FG is OFF.
        if (getPrefBool(@"video.frame_generation")) {
            Class cls = CAMetalLayer.class;
            Method m = class_getInstanceMethod(cls, @selector(nextDrawable));
            if (m) {
                origNextDrawable = method_getImplementation(m);
                method_setImplementation(m, (IMP)widgetSwizzledNextDrawable);
            }
            SEL sizeSel = NSSelectorFromString(@"nextDrawableWithSize:");
            Method m2 = class_getInstanceMethod(cls, sizeSel);
            if (m2) {
                origNextDrawableWithSize = method_getImplementation(m2);
                method_setImplementation(m2, (IMP)widgetSwizzledNextDrawableWithSize);
            }
            fg_hook_metal_layer((CAMetalLayer*)SurfaceViewController.surface.layer);
            NSLog(@"[FrameGen] widgetHookMetalOnce: swizzle+hooks installed, FG ON");
        } else {
            NSLog(@"[FrameGen] widgetHookMetalOnce: skipped (FG OFF, no swizzle)");
        }
    });
}

// Called from fg_hook_metal_layer when FG is enabled at runtime
// (e.g. user toggles FG ON from Settings after launching with FG OFF).
// Installs the class-level CAMetalLayer swizzle if not already installed.
void widgetEnsureMetalSwizzle(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;

    Class cls = CAMetalLayer.class;
    Method m = class_getInstanceMethod(cls, @selector(nextDrawable));
    if (m) {
        origNextDrawable = method_getImplementation(m);
        method_setImplementation(m, (IMP)widgetSwizzledNextDrawable);
    }
    SEL sizeSel = NSSelectorFromString(@"nextDrawableWithSize:");
    Method m2 = class_getInstanceMethod(cls, sizeSel);
    if (m2) {
        origNextDrawableWithSize = method_getImplementation(m2);
        method_setImplementation(m2, (IMP)widgetSwizzledNextDrawableWithSize);
    }
    NSLog(@"[FrameGen] widgetEnsureMetalSwizzle: swizzle installed at runtime");
}

uint64_t pojavSwapCount(void) {
    widgetHookMetalOnce();
    static uint64_t (*mobilegluesSwapCountFn)(void);
    if (!mobilegluesSwapCountFn) {
        mobilegluesSwapCountFn = (uint64_t (*)(void))dlsym(RTLD_DEFAULT, "mobileglues_swap_count");
    }
    uint64_t mg = mobilegluesSwapCountFn ? mobilegluesSwapCountFn() : 0;
    uint64_t own = atomic_load_explicit(&widgetSwapCountOwn, memory_order_relaxed);
    uint64_t metal = atomic_load_explicit(&widgetMetalFrameCount, memory_order_relaxed);
    static BOOL loggedSource;
    if (!loggedSource) {
        loggedSource = YES;
        NSLog(@"[WidgetFPS] mobileglues=%llu own=%llu metal=%llu", mg, own, metal);
    }
    return MAX(MAX(mg, own), metal);
}

void JNI_LWJGL_changeRenderer(const char* value_c) {
    JNIEnv *env;
    (*runtimeJavaVMPtr)->GetEnv(runtimeJavaVMPtr, (void **)&env, JNI_VERSION_1_4);
    jstring key = (*env)->NewStringUTF(env, "org.lwjgl.opengl.libname");
    jstring value = (*env)->NewStringUTF(env, value_c);
    jclass clazz = (*env)->FindClass(env, "java/lang/System");
    jmethodID method = (*env)->GetStaticMethodID(env, clazz, "setProperty", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;");
    (*env)->CallStaticObjectMethod(env, clazz, method, key, value);
}

void pojavTerminate() {
    CallbackBridge_nativeSetInputReady(NO);
    if (!br_terminate) return;
    br_terminate();
}

void* pojavGetCurrentContext() {
    return br_get_current();
}

int pojavInit(BOOL useStackQueue) {
    clientAPI = GLFW_OPENGL_API;
    isInputReady = 1;
    isUseStackQueueCall = useStackQueue;
    aasdl_setMainReady(@"lwjgl41_natives");
    return JNI_TRUE;
}

int pojavInitOpenGL() {
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL isAuto = [renderer isEqualToString:@"auto"];
    if (isAuto || [renderer isEqualToString:@ RENDERER_NAME_GL4ES]) {
        // At this point, if renderer is still auto (unspecified major version), pick gl4es
        renderer = @ RENDERER_NAME_GL4ES;
        setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES]) {
        renderer = @ RENDERER_NAME_MOBILEGLUES;
        setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE]) {
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_LTW]) {
        // Pre-load ANGLE as host EGL before LTW, so LTW's constructor
        // finds eglGetProcAddress via RTLD_DEFAULT.
        dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
        set_gl_bridge_tbl();
    } else if ([renderer hasPrefix:@"libOSMesa"]) {
        setenv("GALLIUM_DRIVER","zink",1);
        [ZinkConfig applyZinkEnvironmentFromPreferences];
        // Pre-load Vulkan loader for Zink before Mesa initializes
        NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libvulkan.1.dylib"];
        dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        set_osm_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOLTENVK]) {
        set_vk_bridge_tbl();
    }
    JNI_LWJGL_changeRenderer(renderer.UTF8String);
    // Preload renderer library
    dlopen([NSString stringWithFormat:@"@rpath/%@", renderer].UTF8String, RTLD_GLOBAL);

    return !br_init();
    //return 0;
}

void pojavSetWindowHint(int hint, int value) {
    if (hint == GLFW_CLIENT_API) {
        clientAPI = value;
    } else if (strcmp(getenv("AMETHYST_RENDERER"), "auto")==0 && hint == GLFW_CONTEXT_VERSION_MAJOR) {
        switch (value) {
            case 1:
            case 2:
                setenv("AMETHYST_RENDERER", RENDERER_NAME_GL4ES, 1);
                JNI_LWJGL_changeRenderer(RENDERER_NAME_GL4ES);
                break;
            // case 4: use Zink?
            default:
                setenv("AMETHYST_RENDERER", RENDERER_NAME_MOBILEGLUES, 1);
                JNI_LWJGL_changeRenderer(RENDERER_NAME_MOBILEGLUES);
                break;
        }
    }
}

void pojavSwapBuffers() {
    atomic_fetch_add_explicit(&widgetSwapCountOwn, 1, memory_order_relaxed);
    if (!br_swap_buffers) return;
    br_swap_buffers();
}

void pojavMakeCurrent(basic_render_window_t* window) {
    if (!br_make_current) return;
    br_make_current(window);
}

void* pojavCreateContext(basic_render_window_t* contextSrc) {
    if (clientAPI == GLFW_NO_API) {
        // Game has selected Vulkan API to render
        return (__bridge void *)SurfaceViewController.surface.layer;
    }

    static BOOL inited = NO;
    if (!inited) {
        inited = YES;
        pojavInitOpenGL();
    }

    basic_render_window_t* ctx = br_init_context(contextSrc);
    if (ctx) {
        pojavMakeCurrent(ctx);
    }
    return ctx;
}

void pojavSwapInterval(int interval) {
    if (!br_swap_interval) return;
    br_swap_interval(interval);
}
