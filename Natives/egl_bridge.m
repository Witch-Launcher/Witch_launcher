#import "SurfaceViewController.h"
#import "LauncherPreferences.h"

#include "jni.h"
#include <assert.h>
#include <dlfcn.h>

#include <dispatch/dispatch.h>
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
#include "ctxbridges/tglmt_bridge.h"
#include "utils.h"
#include "ZinkConfig.h"
#include "MobileGLConfig.h"
#include "TGLMTConfig.h"
#include "PLProfiles.h"

void aasdl_setMainReady(NSString *nativesDir);

int clientAPI;
__thread basic_render_window_t* currentBundle;

// FPS is counted only at the final presentation layer, never at the
// render-side swap. Metal-backed backends (MobileGlues/TGLES, ANGLE-Metal,
// TGLMT) present through -[CAMetalLayer nextDrawable], so the swizzle below
// sees exactly one call per displayed frame. Zink/Mesa is the exception: its
// Vulkan commands still reach Metal via MoltenVK/KosmicKrisp, but the finished
// frame is read back and handed to Core Animation through CALayer.contents
// (GameSurfaceView uses a plain CALayer, there is no drawable). Its final
// presentation is that contents assignment, counted by
// pojavNoteFinalPresent(). The old render-side counters (pojavSwapBuffers
// swaps, mobileglues_swap_count dlsym) remain removed.
#include <dlfcn.h>
#include <stdatomic.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static atomic_uint_fast64_t widgetMetalFrameCount;
static atomic_uint_fast64_t widgetFinalPresentFrameCount;

void pojavNoteFinalPresent(void) {
    atomic_fetch_add_explicit(&widgetFinalPresentFrameCount, 1, memory_order_relaxed);
}

static BOOL widgetUsesFinalPresentCounter(void) {
    const char *renderer = getenv("AMETHYST_RENDERER");
    return renderer != NULL && strncmp(renderer, "libOSMesa", 9) == 0;
}

// Installed at image load, before any window exists.
static id (*widgetOriginalNextDrawable)(id, SEL);

static id widgetCountedNextDrawable(id self, SEL _cmd) {
    atomic_fetch_add_explicit(&widgetMetalFrameCount, 1, memory_order_relaxed);
    return widgetOriginalNextDrawable(self, _cmd);
}

__attribute__((constructor)) static void installMetalFrameCounter(void) {
    Method nextDrawable = class_getInstanceMethod(CAMetalLayer.class, @selector(nextDrawable));
    if (nextDrawable == NULL) {
        NSLog(@"[WidgetFPS] CAMetalLayer nextDrawable missing, Metal frame counting disabled");
        return;
    }
    widgetOriginalNextDrawable = (id (*)(id, SEL))method_getImplementation(nextDrawable);
    method_setImplementation(nextDrawable, (IMP)widgetCountedNextDrawable);
}

static void* egl_checked_dlopen(NSString *path, const char *label) {
    if (!path) {
        NSLog(@"[EGLBridge] dlopen %s: nil path, skipped", label);
        return NULL;
    }
    void *h = dlopen(path.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    if (h) {
        NSLog(@"[EGLBridge] dlopen %s OK: %@", label, path.lastPathComponent);
    } else {
        NSLog(@"[EGLBridge] dlopen %s FAILED: %@ (%s)", label, path, dlerror());
    }
    return h;
}

static NSString* getMoltenVKDylibPath(void) {
    id ver = getPrefObject(@"video.moltenvk_version");
    NSString *version = (ver && [ver isKindOfClass:[NSString class]]) ? (NSString *)ver : @"1.4";
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    if ([version isEqualToString:@"1.2"]) {
        NSString *p12 = [frameworks stringByAppendingPathComponent:@"libMoltenVK12.dylib"];
        if ([NSFileManager.defaultManager fileExistsAtPath:p12]) {
            return p12;
        }
        NSLog(@"[EGLBridge] libMoltenVK12.dylib not shipped, falling back to libMoltenVK.dylib");
    }
    return [frameworks stringByAppendingPathComponent:@"libMoltenVK.dylib"];
}

// Vulkan loader selector: libvulkan.1.dylib is the thin re-export of the
// selected MoltenVK, ANGLE's custom libvulkan.dylib is the full loader.
// Prefer the re-export (matches every other call site), fall back to custom.
static void egl_preloadVulkanLoader(NSString *frameworks) {
    if (egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libvulkan.1.dylib"],
                           "vulkan loader (libvulkan.1)")) {
        return;
    }
    egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libvulkan.dylib"],
                       "vulkan loader (ANGLE custom)");
}

// ANGLE's bundled Vulkan loader (Frameworks/libvulkan.dylib) only finds a
// driver through an ICD manifest. The MoltenVK iOS dylib is already shipped,
// but no JSON points at it, so eglInitialize() returns EGL_NOT_INITIALIZED
// (0x3001). Write the manifest at runtime: the app bundle is read-only and the
// install container path changes on every install. Both loader variables are
// set because VK_DRIVER_FILES wins on newer loaders and VK_ICD_FILENAMES is
// the legacy name. Must run before ANGLE's first eglInitialize().
static void ensureMoltenVKICD(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        NSString *mvk = [frameworks stringByAppendingPathComponent:@"libMoltenVK.dylib"];
        if (![NSFileManager.defaultManager fileExistsAtPath:mvk]) {
            NSLog(@"[EGLBridge] MoltenVK ICD skipped: %@ is missing", mvk);
            return;
        }
        NSDictionary *manifest = @{
            @"file_format_version": @"1.0.0",
            @"ICD": @{
                @"library_path": mvk,
                @"api_version": @"1.4.0",
                @"is_portability_driver": @YES,
            },
        };
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:manifest
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        NSString *jsonPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MoltenVK_icd.json"];
        if (!data || ![data writeToFile:jsonPath atomically:YES]) {
            NSLog(@"[EGLBridge] MoltenVK ICD write failed: %@ (%@)", jsonPath, error.localizedDescription);
            return;
        }
        setenv("VK_ICD_FILENAMES", jsonPath.fileSystemRepresentation, 1);
        setenv("VK_DRIVER_FILES", jsonPath.fileSystemRepresentation, 1);
        NSLog(@"[EGLBridge] MoltenVK ICD ready: %@ (driver: %@)", jsonPath, mvk);
    });
}

// Pre-load LTW's ANGLE backend and export LIBGL_EGL before libltw is dlopened.
// libltw's constructor runs during JVM startup on MC 26.3 (LWJGL loads
// opengl.libname), long before pojavInitOpenGL; its proc.c aborts when
// LIBGL_EGL cannot be opened. Keep this idempotent: both JavaLauncher and the
// GLFW window hook call it.
void PLPreloadLTWBackend(void) {
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    id ltwAnglePref = getPrefObject(@"video.ltw_angle_backend");
    NSString *backend = (ltwAnglePref && [ltwAnglePref isKindOfClass:[NSString class]])
        ? (NSString *)ltwAnglePref : @"vulkan";
    BOOL useMetal = [backend isEqualToString:@"metal"];
    if (!useMetal) backend = @"vulkan";

    NSString *glesPath;
    NSString *eglPath;
    const char *glesLabel;
    if (useMetal) {
        NSLog(@"[EGLBridge] LTW + ANGLE Metal (ES 3.0)");
        // libEGL_angle_metal dispatches through ANGLE_CUSTOM_DISPATCH_LIBRARY
        // and opens the .dylib by exact name. Preload that same image; the
        // extensionless copy is a separate image and would split EGL/GL state.
        glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal.dylib"];
        if (![NSFileManager.defaultManager fileExistsAtPath:glesPath]) {
            glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal"];
        }
        eglPath = [frameworks stringByAppendingPathComponent:@"libEGL_angle_metal"];
        glesLabel = "LTW ANGLE GLES (metal)";
    } else {
        NSLog(@"[EGLBridge] LTW + ANGLE Vulkan (ES 3.2, via MoltenVK)");
        // ANGLE's bundled Vulkan loader finds MoltenVK only through the
        // runtime ICD manifest; without it eglInitialize() fails 0x3001.
        ensureMoltenVKICD();
        egl_checked_dlopen(getMoltenVKDylibPath(), "MoltenVK (LTW VulkanANGLE)");
        egl_preloadVulkanLoader(frameworks);
        glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_vulkan"];
        eglPath = [frameworks stringByAppendingPathComponent:@"libEGL_angle_vulkan"];
        glesLabel = "LTW ANGLE GLES (vulkan)";
    }

    egl_checked_dlopen(glesPath, glesLabel);
    egl_checked_dlopen(eglPath, "LTW host EGL");
    setenv("LIBGL_EGL", eglPath.fileSystemRepresentation, 1);
    setenv("LTW_ANGLE_BACKEND", backend.UTF8String, 1);
    NSLog(@"[EGLBridge] LTW preload ready: backend=%@ LIBGL_EGL=%@", backend, eglPath);
}

// Pre-load the GLES backend that libmobileglues.dylib resolves in load_libs().
// Must run before MobileGlues is dlopened:
//  - MC 26.2's NativeLibrariesBootstrap loads it during JVM startup, before
//    any GLFW/SDL window hook, so JavaLauncher.m calls this right before
//    JLI_Launch;
//  - the GLFW path calls it again from pojavInitOpenGL.
// Idempotent: dlopen() returns the same handle for an already-loaded image
// and setenv() just overwrites, so running it twice is harmless.
//
// Besides pre-loading, this hands MobileGlues the exact backend paths via
// MOBILEGL_IOS_HOST_GLES / MOBILEGL_IOS_HOST_EGL. MG's loader used to resolve
// its host through dlsym(RTLD_DEFAULT), which is load-order first-match:
// WebKit's libANGLE-shared.dylib (in the process default scope since app
// launch) always beat the backend pre-loaded here, so MG silently drove
// WebKit's ANGLE and crashed in glGetString(GL_RENDERER) -> std::string(NULL).
// With the env paths MG opens the selected backend directly.
//
// Backend selection is the mobileglues.angle_backend picker (single control):
//  - tgles (default): TGLES (libtgles.dylib), a GLES 3.2 -> Metal layer that
//    exports the public egl*/gl* names directly. It replaces MetalANGLE,
//    which used to arrive via libtinygl4angle and its libEGL/libGLESv2
//    framework dependencies.
//  - vulkan: ANGLE translates GLES -> Vulkan -> MoltenVK -> Metal (ES 3.2).
//    ensureMoltenVKICD() (GL4ES session helper) is required because ANGLE's
//    bundled Vulkan loader only finds a driver through the manifest, else
//    eglInitialize() fails with 0x3001.
//  - metal: ANGLE translates GLES -> Metal. libEGL_angle_metal is built with
//    ANGLE_CUSTOM_DISPATCH_LIBRARY=libGLESv2_angle_metal.dylib (ModuleDir
//    lookup), so MG is pointed at that .dylib — preloading the extensionless
//    copy instead would create a separate image and split EGL state from GL.
void PLPreloadMobileGluesBackend(void) {
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;

    id backendPref = getPrefObject(@"mobileglues.angle_backend");
    NSString *backend = (backendPref && [backendPref isKindOfClass:[NSString class]])
        ? (NSString *)backendPref : @"tgles";
    BOOL useANGLE = [backend isEqualToString:@"metal"] || [backend isEqualToString:@"vulkan"];

    if (useANGLE) {
        NSString *glesPath;
        NSString *eglPath;
        if ([backend isEqualToString:@"vulkan"]) {
            NSLog(@"[EGLBridge] MobileGlues + ANGLE Vulkan (ES 3.2, via MoltenVK)");
            ensureMoltenVKICD();
            egl_checked_dlopen(getMoltenVKDylibPath(), "MoltenVK (MobileGlues VulkanANGLE)");
            egl_preloadVulkanLoader(frameworks);
            glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_vulkan"];
            eglPath = [frameworks stringByAppendingPathComponent:@"libEGL_angle_vulkan"];
        } else {
            NSLog(@"[EGLBridge] MobileGlues + ANGLE Metal (ES 3.0-era)");
            // libEGL_angle_metal dispatches through ANGLE_CUSTOM_DISPATCH_LIBRARY
            // = libGLESv2_angle_metal.dylib. Point MG at the exact same file:
            // opening the extensionless copy would be a second image, so EGL
            // would make a context current in one image while MG calls GL in
            // the other (glGetString returns NULL, all limits read 0).
            glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal.dylib"];
            if (![NSFileManager.defaultManager fileExistsAtPath:glesPath]) {
                glesPath = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal"];
            }
            eglPath = [frameworks stringByAppendingPathComponent:@"libEGL_angle_metal"];
        }
        egl_checked_dlopen(glesPath, "MobileGlues ANGLE GLES");
        egl_checked_dlopen(eglPath, "MobileGlues ANGLE EGL");
        setenv("MOBILEGL_IOS_HOST_GLES", glesPath.fileSystemRepresentation, 1);
        setenv("MOBILEGL_IOS_HOST_EGL", eglPath.fileSystemRepresentation, 1);
        setenv("MOBILEGL_ANGLE_BACKEND", backend.UTF8String, 1);
        setenv("MOBILEGL_ESPRYT_USE_ANGLE", "1", 1);
        NSLog(@"[EGLBridge] MG host override: GLES=%@ EGL=%@", glesPath, eglPath);
        return;
    }

    // TGLES default: one dylib exports both the egl* and gl* entry points.
    NSString *tglesPath = [frameworks stringByAppendingPathComponent:@"libtgles.dylib"];
    void *tgles = dlopen(tglesPath.fileSystemRepresentation, RTLD_LAZY | RTLD_GLOBAL);
    if (tgles) {
        setenv("MOBILEGL_IOS_HOST_GLES", tglesPath.fileSystemRepresentation, 1);
        setenv("MOBILEGL_IOS_HOST_EGL", tglesPath.fileSystemRepresentation, 1);
        setenv("MOBILEGL_ANGLE_BACKEND", "tgles", 1);
        NSLog(@"[EGLBridge] MobileGlues + TGLES (ES 3.2, GLES->Metal direct)");
    } else {
        // No libtgles in this build: fall back to the MetalANGLE stack so the
        // game still renders. The host override stays unset so MG rewinds to
        // the plain RTLD_DEFAULT lookup; MOBILEGL_ANGLE_BACKEND stays unset
        // too, which is what keeps the TGLES present glue (attach/resize/
        // watchdog) off.
        NSLog(@"[EGLBridge] TGLES unavailable (%s); falling back to MetalANGLE (libtinygl4angle)",
              dlerror() ?: "no dlerror");
        NSString *anglePath = [frameworks stringByAppendingPathComponent:@"libtinygl4angle.dylib"];
        dlopen(anglePath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    }
}

uint64_t pojavSwapCount(void) {
    if (widgetUsesFinalPresentCounter()) {
        return atomic_load_explicit(&widgetFinalPresentFrameCount, memory_order_relaxed);
    }
    return atomic_load_explicit(&widgetMetalFrameCount, memory_order_relaxed);
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
    // The Metal path exposes the host CAMetalLayer through SDL; a
    // user-installed Metal mod owns the SDL window and renders into that
    // single layer. There is no launcher GL context to create; loading a GL
    // backend here would only fight the mod for the layer.
    if ([renderer isEqualToString:@ RENDERER_NAME_METAL] ||
        [renderer isEqualToString:@ RENDERER_NAME_METAL_MACOS]) {
        NSLog(@"[EGLBridge] Metal renderer (%@): launcher GL context disabled "
              @"(mod owns SDL + CAMetalLayer)", renderer);
        return JNI_TRUE;
    }
    BOOL isAuto = [renderer isEqualToString:@"auto"];
    if (isAuto || [renderer isEqualToString:@ RENDERER_NAME_GL4ES]) {
        // At this point, if renderer is still auto (unspecified major version), pick gl4es
        renderer = @ RENDERER_NAME_GL4ES;
        setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);
        // GL4ES uses the private Metal ANGLE pair. libEGL_angle_metal is built
        // with ANGLE_CUSTOM_DISPATCH_LIBRARY=libGLESv2_angle_metal.dylib, so it
        // resolves the Metal companion directly instead of the shared framework
        // pair (which stays Vulkan for LTW/MobileGL). Preload the GLES image
        // first so dyld keeps Metal for GL4ES's own install_name lookups.
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        NSLog(@"[EGLBridge] GL4ES + ANGLE Metal (private companion)");
        NSString *metalGles = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal.dylib"];
        if (![NSFileManager.defaultManager fileExistsAtPath:metalGles]) {
            metalGles = [frameworks stringByAppendingPathComponent:@"libGLESv2_angle_metal"];
        }
        egl_checked_dlopen(metalGles, "GL4ES ANGLE GLES (metal)");
        egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libEGL_angle_metal"],
                           "GL4ES ANGLE EGL (metal)");
        // Keep the ICD manifest as a fallback for the tinygl4angle/Vulkan path
        // in case the custom Metal EGL is missing.
        ensureMoltenVKICD();
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES]) {
        renderer = @ RENDERER_NAME_MOBILEGLUES;
        setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);
        // Pre-load the GLES backend before MobileGlues so its static init
        // (init_target_egl) can find EGL symbols via RTLD_DEFAULT. The same
        // idempotent preload also runs from JavaLauncher before JLI_Launch,
        // because MC 26.2 dlopens MobileGlues during JVM startup, before any
        // GLFW hook can fire.
        PLPreloadMobileGluesBackend();
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE]) {
        ensureMoltenVKICD();
        set_gl_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_LTW]) {
        // libltw's constructor dlopens LIBGL_EGL during JVM startup, before
        // this window hook. JavaLauncher performs the early preload; repeat it
        // here for GLFW-path launches (idempotent).
        PLPreloadLTWBackend();
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
    } else if ([renderer isEqualToString:@ RENDERER_NAME_TGLMT]) {
        // TGLMT: OpenGL 4.6 Core -> Metal (libtglmt.dylib). Không EGL,
        // không MoltenVK/ANGLE — context/swap qua TGLMT C API, LWJGL dlsym
        // gl* thẳng từ dylib (C exports). A11+ đầy đủ, dưới A11 cảnh báo.
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        NSString *tglmtPath = [frameworks stringByAppendingPathComponent:@ RENDERER_NAME_TGLMT];
        if (!egl_checked_dlopen(tglmtPath, "TGLMT (libtglmt.dylib)")) {
            NSLog(@"[EGLBridge] FATAL libtglmt.dylib missing in Frameworks — "
                  @"rebuild payload (make dep_tglmt) or pick another renderer");
        }
        if (![TGLMTConfig deviceSupportsTGLMT]) {
            NSLog(@"[EGLBridge] TGLMT WARNING: %@", [TGLMTConfig deviceSupportNote]);
        }
        set_tglmt_bridge_tbl();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGL]) {
        [MobileGLConfig applyEnvironmentFromPreferences];
        MobileGLBackendType backendType = [MobileGLConfig selectedBackendType];
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        if (backendType == MobileGLBackendTypeDirectVulkan) {
            // DirectVulkan: Vulkan-backed GL via MobileGL. Load Vulkan + MoltenVK.
            // Order matters: MoltenVK first (provides vk* symbols GLOBAL),
            // then the loader re-export.
            egl_checked_dlopen(getMoltenVKDylibPath(), "MoltenVK (DirectVulkan)");
            egl_preloadVulkanLoader(frameworks);
        } else {
            // DirectGLES: TGLES- or ANGLE-backed GLES via MobileGL.
            // NOTE (ANGLE only): both ANGLE builds share the same install_name
            // (@rpath/libEGL.framework/libEGL), so dyld dedups by image — loading
            // metal AND vulkan in one process silently keeps the first one and the
            // second backend's eglCreateWindowSurface fails with 0x300B.
            // TGLES (libtgles.dylib) has its own install_name and never collides.
            // Changing mobilegl.angle_backend still requires a full app restart
            // because MobileGL resolves its host library once at init.
            MobileGLAngleBackend angleBackend = [MobileGLConfig selectedAngleBackend];
            if (angleBackend == MobileGLAngleBackendVulkan) {
                // VulkanANGLE: ANGLE translates GLES → Vulkan → MoltenVK → Metal.
                // ES 3.2 capable. Heavier on A11 (MoltenVK 1.4 degraded) — experimental there.
                NSLog(@"[EGLBridge] MobileGL DirectGLES + VulkanANGLE (ES 3.2, via MoltenVK)");
                egl_checked_dlopen(getMoltenVKDylibPath(), "MoltenVK (VulkanANGLE)");
                egl_preloadVulkanLoader(frameworks);
                egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libGLESv2_angle_vulkan"],
                                   "VulkanANGLE GLES");
                egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libEGL_angle_vulkan"],
                                   "VulkanANGLE EGL");
                setenv("MOBILEGL_ANGLE_BACKEND", "vulkan", 1);
                setenv("MOBILEGL_ESPRYT_USE_ANGLE", "1", 1);
            } else {
                // TGLES: GLES 3.2 -> Metal directly (libtgles.dylib, no
                // MoltenVK, no ANGLE). ES 3.2 capable including compute v1,
                // MRT+MSAA, per-buffer blend. This replaces MetalANGLE
                // (ES 3.0-only, removed).
                NSLog(@"[EGLBridge] MobileGL DirectGLES + TGLES (ES 3.2, GLES->Metal direct)");
                egl_checked_dlopen([frameworks stringByAppendingPathComponent:@"libtgles.dylib"],
                                   "TGLES");
                setenv("MOBILEGL_ANGLE_BACKEND", "tgles", 1);
                setenv("MOBILEGL_ESPRYT_USE_ANGLE", "1", 1);
            }
        }
        set_gl_bridge_tbl();
    }
    // NOTE: never publish a bare "libMoltenVK.dylib" as org.lwjgl.opengl.libname.
    // MoltenVK is a Vulkan loader, not a GL implementation: LWJGL resolves a
    // bare name via org.lwjgl.librarypath (libs/lwjgl41_natives), where a
    // macOS-platform libMoltenVK.dylib copy exists (Makefile blind *.dylib
    // copy) that can never dlopen on iOS -> UnsatisfiedLinkError via
    // GL.create() on MC 26.x (which inits GL regardless of backend).
    // JavaLauncher already points opengl.libname at MobileGlues for MoltenVK
    // setups; keep that here too.
    if ([renderer isEqualToString:@ RENDERER_NAME_MOLTENVK]) {
        JNI_LWJGL_changeRenderer(RENDERER_NAME_MOBILEGLUES);
    } else {
        JNI_LWJGL_changeRenderer(renderer.UTF8String);
    }
    // Preload renderer library.
    // Skip only for the Mesa 26.2.2 EGL renderer itself — its library
    // (libEGL_Mesa26.dylib) was already loaded above and loading the old
    // libOSMesa.8.dylib would clash symbols under -flat_namespace. The Mesa
    // preference is global, so do NOT let it suppress preload for LTW,
    // GL4ES or MTL_ANGLE: that left those EGL backends half-initialized.
    // MobileGL is always preloaded (its dlsym_EGL handle is separate from
    // the preload RTLD_GLOBAL handle).
    BOOL mesaEGLSelected = [renderer hasPrefix:@"libOSMesa"] && [ZinkConfig isZinkUsingEGL];
    if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGL] ||
        [renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES] ||
        [renderer isEqualToString:@ RENDERER_NAME_TGLMT] ||
        !mesaEGLSelected) {
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
    // The launcher's VSync switch is authoritative (Settings > Game). Off by
    // default: never ask the driver to wait for vblank, so the render loop is
    // paced only by the presentation engine instead of a software sleep.
    int forced = getPrefBool(@"video.vsync") ? 1 : 0;
    static int lastForced = -1;
    if (forced != lastForced) {
        NSLog(@"[Vsync] swap interval %d -> %d (requested %d)", lastForced, forced, interval);
        lastForced = forced;
    }
    br_swap_interval(forced);
}
