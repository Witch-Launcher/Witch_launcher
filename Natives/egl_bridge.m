#import "SurfaceViewController.h"
#import "LauncherPreferences.h"

#include "jni.h"
#include <assert.h>
#include <dlfcn.h>

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include "EGL/egl.h"
#include "EGL/eglext.h"
#include "GL/osmesa.h"

#include "glfw_keycodes.h"
#include "ctxbridges/bridge_tbl.h"
#include "ctxbridges/osmesa_internal.h"
#include "ctxbridges/mesa_egl_bridge.h"
#include "utils.h"
#include "ZinkConfig.h"
#include "MobileGLConfig.h"
#include "PLProfiles.h"

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

static NSString* getMoltenVKDylibPath(void) {
    id ver = getPrefObject(@"video.moltenvk_version");
    NSString *version = (ver && [ver isKindOfClass:[NSString class]]) ? (NSString *)ver : @"1.4";
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    if ([version isEqualToString:@"1.2"]) {
        return [frameworks stringByAppendingPathComponent:@"libMoltenVK12.dylib"];
    }
    return [frameworks stringByAppendingPathComponent:@"libMoltenVK.dylib"];
}

static NSString* getANGLEHostEGLDylibPath(void) {
    id ver = getPrefObject(@"video.ltw_angle_backend");
    NSString *backend = (ver && [ver isKindOfClass:[NSString class]]) ? (NSString *)ver : @"metal";
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    if ([backend isEqualToString:@"vulkan"]) {
        return [frameworks stringByAppendingPathComponent:@"libEGL_angle_vulkan"];
    }
    return [frameworks stringByAppendingPathComponent:@"libEGL_angle_metal"];
}

uint64_t pojavSwapCount(void) {
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
        // Pre-load ANGLE backend before MobileGlues so its static init
        // (init_target_egl) can find EGL symbols via RTLD_DEFAULT.
        NSString *anglePath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libtinygl4angle.dylib"];
        dlopen(anglePath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE]) {
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_LTW]) {
        // Pre-load ANGLE as host EGL before LTW, so LTW's constructor
        // finds eglGetProcAddress via RTLD_DEFAULT.
        NSString *anglePath = getANGLEHostEGLDylibPath();
        dlopen(anglePath.UTF8String, RTLD_GLOBAL);
        set_gl_bridge_tbl();
    } else if ([renderer hasPrefix:@"libOSMesa"]) {
        NSLog(@"[EGLBridge] Zink renderer detected, checking Mesa version...");
        [ZinkConfig applyZinkEnvironmentFromPreferences];

        NSString *mesaVersion = [ZinkConfig selectedMesaVersion];
        ZinkVulkanBackend backend = [ZinkConfig selectedVulkanBackend];
        BOOL kosmicSupported = [ZinkConfig deviceSupportsKosmicKrisp];

        NSLog(@"[EGLBridge] Mesa %@, backend=%@, KosmicKrisp=%@",
              mesaVersion, [ZinkConfig vulkanBackendName],
              kosmicSupported ? @"YES" : @"NO");

        if ([ZinkConfig isZinkUsingEGL]) {
            // ── Mesa 26.2.2 (EGL) — KosmicKrisp ONLY ──
            if (!kosmicSupported) {
                NSLog(@"[EGLBridge] ✗ Mesa 26.2.2 REQUIRES KosmicKrisp (A13+). "
                      @"This device does NOT support KosmicKrisp. "
                      @"Attempting to continue — expect crash.");
            }

            // Load Vulkan loader for Zink → KosmicKrisp
            NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath
                                   stringByAppendingPathComponent:@"libvulkan.1.dylib"];
            dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            setenv("GALLIUM_DRIVER", "zink", 1);

            if (kosmicSupported && [ZinkConfig deviceSupportsKosmicKrispFull]) {
                NSLog(@"[EGLBridge] → KosmicKrisp Full (VK 1.4, A14+)");
            } else if (kosmicSupported) {
                NSLog(@"[EGLBridge] → KosmicKrisp Reduced (VK 1.2, A13)");
            }

            NSLog(@"[EGLBridge] → Mesa 26.2.2: loading libEGL_Mesa26.dylib");
            NSString *mesaPath = [NSBundle.mainBundle.privateFrameworksPath
                                     stringByAppendingPathComponent:@"libEGL_Mesa26.dylib"];
            dlopen(mesaPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            set_mesa_egl_bridge_tbl();
            NSLog(@"[EGLBridge] → mesa_egl_bridge_tbl installed");
        } else {
            // ── Mesa 25.0.7 (OSMesa) — choose between MoltenVK and KosmicKrisp ──
            if (backend == ZinkVulkanBackendKosmicKrisp ||
                (backend == ZinkVulkanBackendAuto && kosmicSupported)) {
                // KosmicKrisp path: load Vulkan loader + libOSMesa
                NSLog(@"[EGLBridge] → Mesa 25.0.7 + KosmicKrisp");
                NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath
                                       stringByAppendingPathComponent:@"libvulkan.1.dylib"];
                dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
                setenv("GALLIUM_DRIVER", "zink", 1);
                NSLog(@"[EGLBridge] → GALLIUM_DRIVER=zink (KosmicKrisp backend)");
            } else if (backend == ZinkVulkanBackendMoltenVK ||
                       (backend == ZinkVulkanBackendAuto && !kosmicSupported)) {
                // MoltenVK path: load Vulkan loader + libOSMesa
                NSLog(@"[EGLBridge] → Mesa 25.0.7 + MoltenVK");
                NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath
                                       stringByAppendingPathComponent:@"libvulkan.1.dylib"];
                dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
                setenv("GALLIUM_DRIVER", "zink", 1);
                NSLog(@"[EGLBridge] → GALLIUM_DRIVER=zink (MoltenVK backend)");
            } else {
                // Fallback: softpipe (CPU-only, no Vulkan)
                NSLog(@"[EGLBridge] → Mesa 25.0.7: softpipe fallback (CPU-only)");
                setenv("GALLIUM_DRIVER", "softpipe", 1);
            }

            NSString *mesaLib = [ZinkConfig zinkLibraryName];
            NSString *mesaPath = [NSBundle.mainBundle.privateFrameworksPath
                                     stringByAppendingPathComponent:mesaLib];
            dlopen(mesaPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            NSLog(@"[EGLBridge] → %@ loaded, installing osm_bridge_tbl", mesaLib);
            set_osm_bridge_tbl();
            NSLog(@"[EGLBridge] → osm_bridge_tbl installed");
        }
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOLTENVK]) {
        // Pre-load MoltenVK version-specific dylib
        NSString *mvkPath = getMoltenVKDylibPath();
        dlopen(mvkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        set_vk_bridge_tbl();
        } else if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGL]) {
        [MobileGLConfig applyEnvironmentFromPreferences];
        MobileGLBackendType backendType = [MobileGLConfig selectedBackendType];
        if (backendType == MobileGLBackendTypeDirectVulkan) {
            // DirectVulkan: Vulkan-backed GL via MobileGL. Load Vulkan + MoltenVK.
            NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libvulkan.1.dylib"];
            dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            NSString *mvkPath = getMoltenVKDylibPath();
            dlopen(mvkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        } else {
            // DirectGLES: ANGLE-backed GLES via MobileGL. Load the ANGLE backend.
            MobileGLAngleBackend angleBackend = [MobileGLConfig selectedAngleBackend];
            if (angleBackend == MobileGLAngleBackendVulkan) {
                // VulkanANGLE: ANGLE translates GLES → Vulkan → MoltenVK → Metal
                NSString *vkPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libvulkan.dylib"];
                dlopen(vkPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
                NSString *eglPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libEGL_angle_vulkan"];
                dlopen(eglPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            } else {
                // MetalANGLE: ANGLE translates GLES → Metal directly
                NSString *eglPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libEGL_angle_metal"];
                dlopen(eglPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            }
        }
        set_gl_bridge_tbl();
    }
    JNI_LWJGL_changeRenderer(renderer.UTF8String);
    // Preload renderer library.
    // Skip for Mesa 26.2.2 EGL — its library (libEGL.1.dylib) was already
    // loaded above and loading the old libOSMesa.8.dylib would clash symbols
    // under -flat_namespace.  MobileGL is always preloaded (its dlsym_EGL
    // handle is separate from the preload RTLD_GLOBAL handle).
    if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGL] ||
        [renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES] ||
        ![ZinkConfig isZinkUsingEGL]) {
        NSLog(@"[EGLBridge] Preloading renderer library: @rpath/%@", renderer);
        dlopen([NSString stringWithFormat:@"@rpath/%@", renderer].UTF8String, RTLD_GLOBAL);
    } else {
        NSLog(@"[EGLBridge] Skipping renderer preload (Mesa EGL mode)");
    }

    if (!br_init) {
        NSLog(@"[EGLBridge] FATAL br_init is NULL for renderer: %@", renderer);
        return JNI_FALSE;
    }
    return br_init();
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
        if (!pojavInitOpenGL()) {
            NSLog(@"[EGLBridge] pojavInitOpenGL failed, cannot create GL context");
            return NULL;
        }
    }

    if (!br_init_context) {
        NSLog(@"[EGLBridge] br_init_context is NULL");
        return NULL;
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
