#include <mach/mach.h>
#include <mach/task.h>
#include <os/proc.h>
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <libgen.h>
#include <mach/mach.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <signal.h>
#include <setjmp.h>
#include <unistd.h>

#include "utils.h"
#include "config.h"
#include "ZinkConfig.h"
#include "MobileGLConfig.h"
#include "TGLMTConfig.h"
#include "MemSampler.h"

// MetalBridgeKit.framework (vendored in Frameworks/, dlopened for the
// metal_macos renderer). Runtime link only: its ObjC classes do not exist
// until the dlopen below registers them, so the facade is reached strictly
// through NSClassFromString — a static class reference (e.g.
// MBProbe.frameworkVersion) would emit a strong _OBJC_CLASS_$_MBProbe that
// dyld cannot bind before main() and abort the launch.

#import "ios_uikit_bridge.h"
#import "JavaLauncher.h"
#import "LauncherPreferences.h"
#import "PLLogOutputView.h"
#import "PLProfiles.h"
#import "VersionDirectoryManager.h"
#import "TouchControllerManager.h"
#import "authenticator/BaseAuthenticator.h"
static NSString *dhNativeLibPath = nil;

// Forward declaration for DH fix
static void checkAndAddDhNativeLibPath(NSString *versionId);
static BOOL instanceHasTouchControllerMod(NSString *gameDir);

// JVM-startup watchdog (defined after launchJVMWithArgs). Surfaces a crash
// screen if the JVM stalls with no output and no rendering for 120s.
static void startJVMStartupWatchdog(BOOL jit26Active, uint64_t launchMs);
static uint64_t jitNowMs(void);
// Defined in egl_bridge.m — returns total swap/frame count (advanced by the
// game's CAMetalLayer once a window starts rendering).
extern uint64_t pojavSwapCount(void);

// Defined in main.m — monotonic ms of the last stdout/stderr flush.
uint64_t pojavLastLogWriteMs(void);

// Defined in input_bridge_v3.m — sets SDL3's SDL_MainIsReady flag. Called
// before JLI_Launch so SDL-based games (26.x / RenderPearl) can SDL_Init.
// nativesDir must match the game's org.lwjgl.librarypath (lwjgl33/36/41_natives).
void aasdl_setMainReady(NSString *nativesDir);

#define fm NSFileManager.defaultManager

extern char **environ;

// os_proc_available_memory() returns the bytes remaining before the current
// process hits its dirty memory (Jetsam) limit — the actual kill limit the
// OS applies to this process, unlike physical RAM or host free pages.
// Non-jailbroken apps run under a fixed, dynamically-shrinking Jetsam limit;
// when the process is JIT-debugged without the memorystatus entitlement, iOS
// pins that limit at roughly 1GB regardless of the device, which is exactly
// the "crash at 1GB on every device" symptom.
static size_t availableMemoryMB(void) {
    size_t avail = os_proc_available_memory();
    if (avail == 0) {
        return 0;
    }
    return (size_t)(avail / (1024 * 1024));
}

// Direct ByteBuffers (LWJGL/Sodium/Iris) default to a cap equal to -Xmx when
// MaxDirectMemorySize is absent, so heap + direct can silently use 2x -Xmx
// before the JVM even starts counting native/GPU memory. Reserve part of the
// budget for them and cap the rest explicitly.
static const int kDirectMemoryReserveMB = 320;
// JVM native arenas, CodeCache/JIT mirror, the launcher itself and the
// GL/Metal driver's own allocations. Kept deliberately conservative: the
// 2 GiB per-process Jetsam ceiling does not grow with physical RAM.
static const int kNativeReserveMB = 512;

static int maxDirectMemoryMB(int heapMB) {
    int direct = heapMB / 3;
    if (direct < 192) direct = 192;
    if (direct > 384) direct = 384;
    return direct;
}

// Caps the requested heap so Java heap + direct buffers + JVM native/GPU
// overhead fit under the real Jetsam kill allowance. Physical RAM alone is a
// bad basis: 6 GB devices were still killed after ~30 minutes with 1.5-1.8 GB
// heaps because direct memory scaled with -Xmx and the process ceiling did not.
static int capAllocationToJetsamAllowance(int allocmem) {
    double physicalMB = (double)NSProcessInfo.processInfo.physicalMemory / 1048576.0;
    size_t availableMem = availableMemoryMB();
    double budget;
    if (availableMem > 0) {
        budget = MIN((double)availableMem * 0.85, physicalMB * 0.5);
    } else {
        // Unknown Jetsam allowance: fall back to a conservative share of RAM.
        budget = physicalMB * 0.35;
    }
    int maxHeap = (int)budget - kDirectMemoryReserveMB - kNativeReserveMB;
    if (maxHeap < 384) maxHeap = 384;
    if (maxHeap > 1536) maxHeap = 1536;
    if (allocmem > maxHeap) {
        NSLog(@"[JavaLauncher] RAM capped: %d MB -> %d MB (budget=%.0f MB, available=%zu MB, physical=%.0f MB; direct/native reservation=%d MB)",
              allocmem, maxHeap, budget, availableMem, physicalMB,
              kDirectMemoryReserveMB + kNativeReserveMB);
        return maxHeap;
    }
    return allocmem;
}

BOOL validateVirtualMemorySpace(size_t size) {
    size <<= 20; // convert to MB
    void *map = mmap(0, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    // check if process successfully maps and unmaps a contiguous range
    if(map == MAP_FAILED || munmap(map, size) != 0)
        return NO;
    return YES;
}

void init_loadDefaultEnv() {
    /* Define default env */

    // Silent Caciocavallo NPE error in locating Android-only lib
    setenv("LD_LIBRARY_PATH", "", 1);

    // Point fontconfig to the app's bundled config directory so X11FontManager
    // doesn't search the macOS Fontconfig.framework path (which doesn't exist on iOS).
    NSString *fcDir = amethyst_hidden_dir(@"fontconfig");
    [fm createDirectoryAtPath:[fcDir stringByAppendingPathComponent:@"conf.d"]
        withIntermediateDirectories:YES attributes:nil error:nil];
    // Create a minimal fonts.conf so fontconfig initializes without errors
    NSString *fcConfPath = [fcDir stringByAppendingPathComponent:@"fonts.conf"];
    if (![fm fileExistsAtPath:fcConfPath]) {
        NSString *fcConf = @"<?xml version=\"1.0\"?>\n"
            @"<!DOCTYPE fontconfig SYSTEM \"fonts.dtd\">\n"
            @"<fontconfig>\n"
            @"  <dir>/System/Library/Fonts</dir>\n"
            @"  <dir>/System/Library/Fonts/Cache</dir>\n"
            @"  <cacheid>/System/Library/Caches/com.apple.fonts</cacheid>\n"
            @"  <match target=\"pattern\">\n"
            @"    <test name=\"family\"><string>sans-serif</string></test>\n"
            @"    <edit name=\"family\" mode=\"append\" binding=\"same\">\n"
            @"      <string>Helvetica</string>\n"
            @"    </edit>\n"
            @"  </match>\n"
            @"  <match target=\"pattern\">\n"
            @"    <test name=\"family\"><string>serif</string></test>\n"
            @"    <edit name=\"family\" mode=\"append\" binding=\"same\">\n"
            @"      <string>Times New Roman</string>\n"
            @"    </edit>\n"
            @"  </match>\n"
            @"  <match target=\"pattern\">\n"
            @"    <test name=\"family\"><string>monospace</string></test>\n"
            @"    <edit name=\"family\" mode=\"append\" binding=\"same\">\n"
            @"      <string>Menlo</string>\n"
            @"    </edit>\n"
            @"  </match>\n"
            @"</fontconfig>\n";
        [fcConf writeToFile:fcConfPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    setenv("FONTCONFIG_PATH", fcDir.UTF8String, 1);

    // Ignore mipmap for performance(?) seems does not affect iOS
    //setenv("LIBGL_MIPMAP", "3", 1);

    // Disable overloaded functions hack for Minecraft 1.17+
    setenv("LIBGL_NOINTOVLHACK", "1", 1);

    // Fix white color on banner and sheep, since GL4ES 1.1.5
    setenv("LIBGL_NORMALIZE", "1", 1);

    // Override OpenGL version to 4.1 for Zink
    setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);

    // Suppress [mvk-info] log spam (swapchain creation, etc.)
    setenv("MVK_CONFIG_LOG_LEVEL", getPrefBool(@"general.debug_logging") ? "2" : "0", 1);

    // MoltenVK 1.4.1 argument buffers break chunk lightmap texelFetch on A11
    // (world renders dark). Disable to keep lighting correct.
    setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "0", 1);

    // Runs JVM in a separate thread
    setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1);
}

void init_loadCustomEnv() {
    NSString *envvars = getPrefObject(@"java.env_variables");
    if (envvars == nil) return;
    NSLog(@"[JavaLauncher] Reading custom environment variables");
    for (NSString *line in [envvars componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]) {
        if (![line containsString:@"="]) {
            NSLog(@"[JavaLauncher] Warning: skipped empty value custom env variable: %@", line);
            continue;
        }
        NSRange range = [line rangeOfString:@"="];
        NSString *key = [line substringToIndex:range.location];
        NSString *value = [line substringFromIndex:range.location+range.length];
        setenv(key.UTF8String, value.UTF8String, 1);
        NSLog(@"[JavaLauncher] Added custom env variable: %@", line);
    }
}

void init_loadMobileGluesConfig() {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    BOOL usesMobileGlues = [renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES] ||
        [renderer isEqualToString:@"auto"] ||
        [renderer isEqualToString:@ RENDERER_NAME_MOLTENVK];

    if (!usesMobileGlues) {
        return;
    }

    NSString *mgDirPath = amethyst_hidden_dir(@"MG");
    setenv("MG_DIR_PATH", mgDirPath.UTF8String, 1);

    NSMutableDictionary *config = [NSMutableDictionary dictionary];

    config[@"enableExtGL43"] = @0;
    config[@"enableExtDirectStateAccess"] = @1;
    config[@"maxGlslCacheSize"] = @128;
    config[@"customGLVersion"] = @0x030100;

    id enableExtGL43 = getPrefObject(@"mobileglues.enable_ext_gl43");
    if (enableExtGL43) config[@"enableExtGL43"] = [enableExtGL43 boolValue] ? @1 : @0;

    id angleBackend = getPrefObject(@"mobileglues.angle_backend");
    NSString *backend = (angleBackend && [angleBackend isKindOfClass:[NSString class]])
        ? (NSString *)angleBackend : @"vulkan";
    BOOL angleEnabled = [backend isEqualToString:@"metal"] || [backend isEqualToString:@"vulkan"];
    // ForceEnable (3), not EnableIfPossible (1): MG's hasVulkan12() probe
    // returns false on iOS, so "if possible" always resolves to Disabled even
    // when the launcher explicitly selected an ANGLE host. Disabled also flips
    // MG into bufferCoherentAsFlush mode, which does not match an ANGLE host.
    config[@"enableANGLE"] = angleEnabled ? @3 : @0;
    config[@"angleBackend"] = angleEnabled ? backend : @"tgles";

    id enableNoError = getPrefObject(@"mobileglues.enable_no_error");
    if (enableNoError) config[@"enableNoError"] = @([enableNoError intValue]);

    id enableExtTimerQuery = getPrefObject(@"mobileglues.enable_ext_timer_query");
    if (enableExtTimerQuery) config[@"enableExtTimerQuery"] = [enableExtTimerQuery boolValue] ? @1 : @0;

    id enableExtComputeShader = getPrefObject(@"mobileglues.enable_ext_compute_shader");
    if (enableExtComputeShader) config[@"enableExtComputeShader"] = [enableExtComputeShader boolValue] ? @1 : @0;

    id enableExtDirectStateAccess = getPrefObject(@"mobileglues.enable_ext_direct_state_access");
    if (enableExtDirectStateAccess) config[@"enableExtDirectStateAccess"] = [enableExtDirectStateAccess boolValue] ? @1 : @0;

    id maxGlslCacheSize = getPrefObject(@"mobileglues.max_glsl_cache_size");
    if (maxGlslCacheSize) config[@"maxGlslCacheSize"] = @([maxGlslCacheSize intValue]);

    id multidrawMode = getPrefObject(@"mobileglues.multidraw_mode");
    if (multidrawMode) config[@"multidrawMode"] = @([multidrawMode intValue]);

    id angleDepthClearFixMode = getPrefObject(@"mobileglues.angle_depth_clear_fix_mode");
    if (angleDepthClearFixMode) config[@"angleDepthClearFixMode"] = [angleDepthClearFixMode boolValue] ? @1 : @0;

    id customGlVersion = getPrefObject(@"mobileglues.custom_gl_version");
    if (customGlVersion) {
        // Small int codes matching MobileGlues Version(int) digit parsing
        // (33 = 3.3.0, 40 = 4.0.0, ...). "0"/unknown means default: write 0
        // so native keeps custom_gl_version empty ("will go default").
        NSString *verStr = [customGlVersion description];
        if ([verStr isEqualToString:@"0"]) config[@"customGLVersion"] = @0;
        else if ([verStr isEqualToString:@"3.0"]) config[@"customGLVersion"] = @30;
        else if ([verStr isEqualToString:@"3.1"]) config[@"customGLVersion"] = @31;
        else if ([verStr isEqualToString:@"3.2"]) config[@"customGLVersion"] = @32;
        else if ([verStr isEqualToString:@"3.3"]) config[@"customGLVersion"] = @33;
        else if ([verStr isEqualToString:@"4.0"]) config[@"customGLVersion"] = @40;
        else if ([verStr isEqualToString:@"4.1"]) config[@"customGLVersion"] = @41;
        else if ([verStr isEqualToString:@"4.2"]) config[@"customGLVersion"] = @42;
        else if ([verStr isEqualToString:@"4.3"]) config[@"customGLVersion"] = @43;
        else if ([verStr isEqualToString:@"4.4"]) config[@"customGLVersion"] = @44;
        else if ([verStr isEqualToString:@"4.5"]) config[@"customGLVersion"] = @45;
        else if ([verStr isEqualToString:@"4.6"]) config[@"customGLVersion"] = @46;
    }

    id fsr1Setting = getPrefObject(@"mobileglues.fsr1_setting");
    if (fsr1Setting) config[@"fsr1Setting"] = @([fsr1Setting intValue]);

    // ANGLE hosts on iOS render the batched GUI pass incorrectly with the
    // auto-selected indirect/multi-draw backends. Keep the default on the
    // unrolled path (legacy MG: multidrawMode=DrawElements; current MG:
    // multidrawOrder=unroll) unless the user explicitly picked another mode.
    if (angleEnabled && (!multidrawMode || [multidrawMode intValue] == 0)) {
        config[@"multidrawMode"] = @4;
        config[@"multidrawOrder"] = @"unroll";
    }

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData) {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [fm createDirectoryAtPath:mgDirPath withIntermediateDirectories:YES attributes:nil error:nil];
        [jsonString writeToFile:[mgDirPath stringByAppendingPathComponent:@"config.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"[JavaLauncher] MobileGlues config written to %@/config.json", mgDirPath);
    } else {
        NSLog(@"[JavaLauncher] Failed to serialize MobileGlues config: %@", error);
    }

    // Set MoltenVK version env var for Java-side awareness
    id mvkVersion = getPrefObject(@"video.moltenvk_version");
    NSString *mvkVer = (mvkVersion && [mvkVersion isKindOfClass:[NSString class]]) ? (NSString *)mvkVersion : @"1.4";
    setenv("MOLTENVK_VERSION", mvkVer.UTF8String, 1);
    NSLog(@"[JavaLauncher] MoltenVK version: %@", mvkVer);
}

void init_loadMobileGLConfig() {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    if (![renderer isEqualToString:@ RENDERER_NAME_MOBILEGL]) {
        return;
    }

    // Apply MobileGL environment variables from preferences
    [MobileGLConfig applyEnvironmentFromPreferences];
    NSLog(@"[JavaLauncher] MobileGL config applied");
    NSLog(@"[MobileGL] %@", [MobileGLConfig activeConfigSummary]);
}

void init_loadTGLMTConfig() {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    if (![renderer isEqualToString:@ RENDERER_NAME_TGLMT]) {
        return;
    }

    // Apply TGLMT environment variables from preferences (vanilla GL 4.6 path)
    [TGLMTConfig applyEnvironmentFromPreferences];
    NSLog(@"[JavaLauncher] TGLMT config applied");
    NSLog(@"[TGLMT] %@", [TGLMTConfig activeConfigSummary]);
}

void init_loadLTWConfig() {
    // debug.debug_render_log (Developer option, default OFF):
    //   OFF = quiet mode. LTW ignores GL errors (same policy as MobileGlues
    //         enable_no_error) so a single unsupported call cannot abort the
    //         game (e.g. Minecraft 26 GlDevice.createTexture throwing
    //         "OpenGL error 1282"), and every per-frame render log is
    //         disabled to avoid CPU/GPU overhead from formatting + writing
    //         thousands of log lines (which froze the launcher on 26.x).
    //   ON  = strict + verbose. All render error logs are recorded for
    //         debugging (LTW wrapper logs, EGL readback/diag).
    BOOL renderLog = getPrefBool(@"debug.debug_render_log");
    if (renderLog) {
        unsetenv("LIBGL_NOERROR");
        setenv("LTW_DEBUG", "1", 1);
        setenv("LTW_RENDER_LOG", "1", 1);
        setenv("AMETHYST_RENDER_LOG", "1", 1);
        NSLog(@"[JavaLauncher] Render error logging ENABLED (LTW strict mode + verbose render logs)");
    } else {
        setenv("LIBGL_NOERROR", "1", 1);
        setenv("LTW_DEBUG", "0", 1);
        setenv("LTW_RENDER_LOG", "0", 1);
        setenv("AMETHYST_RENDER_LOG", "0", 1);
    }

    // ANGLE backend selection for LTW: metal (MetalANGLE, ES 3.0) or vulkan (VulkanANGLE, ES 3.2)
    id angleBackend = getPrefObject(@"video.ltw_angle_backend");
    NSString *backend = (angleBackend && [angleBackend isKindOfClass:[NSString class]]) ? (NSString *)angleBackend : @"vulkan";
    setenv("LTW_ANGLE_BACKEND", backend.UTF8String, 1);
    NSLog(@"[JavaLauncher] LTW ANGLE backend: %@", backend);
}

void init_loadCustomJvmFlags(int* argc, const char** argv) {
    NSString *jvmargs = [PLProfiles resolveKeyForCurrentProfile:@"javaArgs"];
    if (jvmargs == nil) return;
    // Make the separator happy
    jvmargs = [jvmargs stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    jvmargs = [@" " stringByAppendingString:jvmargs];

    NSLog(@"[JavaLauncher] Reading custom JVM flags");
    NSArray *argsToPurge = @[@"Xms", @"Xmx", @"d32", @"d64"];
    for (NSString *arg in [jvmargs componentsSeparatedByString:@" -"]) {
        NSString *jvmarg = [arg stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (jvmarg.length == 0) continue;
        BOOL ignore = NO;
        for (NSString *argToPurge in argsToPurge) {
            if ([jvmarg hasPrefix:argToPurge]) {
                NSLog(@"[JavaLauncher] Ignored JVM flag: -%@", jvmarg);
                ignore = YES;
                break;
            }
        }
        if (ignore) continue;

        ++*argc;
        argv[*argc] = [@"-" stringByAppendingString:jvmarg].UTF8String;

        NSLog(@"[JavaLauncher] Added custom JVM flag: %s", argv[*argc]);
    }
}

static BOOL processIsDebugged(void) {
    return processIsCurrentlyDebugged();
}

// The JIT26 / mirror brk stubs (#0xf00d, #0x6a) are serviced by StikDebug's
// exception server. When nothing services them the kernel raises SIGTRAP and
// the default action kills the app (crash straight back to the home screen).
// During the handshake window we catch SIGTRAP instead, ARMED as a bail-out:
// a synchronous brk trap resumes AT the faulting instruction, so returning
// from an empty handler would re-trap forever (black-screen spin, no dialog,
// no further log). siglongjmp lands back at the armed setjmp point with the
// call skipped, turning every unserviced brk into the diagnostic dialogs below.
static sigjmp_buf g_jitTrapJmp;
static volatile sig_atomic_t g_jitTrapArmed = 0;
static void onUnservicedBrk(int sig) {
    (void)sig;
    if (g_jitTrapArmed) {
        siglongjmp(g_jitTrapJmp, 1);
    }
}

// Send JIT26SetDetachAfterFirstBr (brk #0xf00d, command 3) under a SIGTRAP
// guard. A stale assigned base script may not implement command 3; the brk
// then either traps with the default disposition (debugger detached) or —
// worse — the script logs "Unknown command 3" and leaves the thread stopped
// forever. This guard catches the signal case; the callers below only send
// command 3 once the script has proven it services brks (probe + extension).
static void JIT26SetDetachAfterFirstBrGuarded(BOOL value) {
    struct sigaction sa = {0};
    struct sigaction oldSa;
    sa.sa_handler = onUnservicedBrk;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGTRAP, &sa, &oldSa);
    g_jitTrapArmed = 1;
    if (sigsetjmp(g_jitTrapJmp, 1) == 0) {
        JIT26SetDetachAfterFirstBr(value);
    } else {
        NSLog(@"[JavaLauncher] JIT26SetDetachAfterFirstBr(%d) brk was NOT serviced "
              @"(script lacks command 3); continuing with the script's own detach policy",
              value);
    }
    g_jitTrapArmed = 0;
    sigaction(SIGTRAP, &oldSa, NULL);
}

static BOOL JIT26ProbeLooksValid(void *result) {
    if (!result || result == MAP_FAILED) {
        return NO;
    }
    uintptr_t addr = (uintptr_t)result;
    uint32_t lo = (uint32_t)addr;
    uint32_t hi = (uint32_t)(addr >> 32);
    // Legacy / broken handlers return these instead of a real mapping.
    if (lo == 0x690000E0u || lo == 0xE0000069u) {
        return NO;
    }
    // Uninitialized register garbage seen when StikDebug did not set x0.
    if (hi == 0xCCCCCCCCu || hi == 0xDEADBEEFu || hi == 0xFFFFFFFFu) {
        return NO;
    }
    // Small probe allocations from _M are often outside the 240 MB superpage;
    // accept any page-aligned userspace RX pointer.
    if (addr < 0x10000 || (addr & (getpagesize() - 1)) != 0) {
        return NO;
    }
    return YES;
}

static BOOL RuntimeSupportsDebugJITMapping(NSString *javaHome) {
    NSString *marker = [javaHome
        stringByAppendingPathComponent:@".witch-mirror-mapping"];
    NSString *contents = [NSString stringWithContentsOfFile:marker
        encoding:NSUTF8StringEncoding error:nil];
    return [contents isEqualToString:@"witch-mirror-mapping-v1\n"];
}

int launchJVM(NSString *username, id launchTarget, int width, int height, int minVersion) {
    return launchJVMWithArgs(username, launchTarget, width, height, minVersion, nil);
}

int launchJVMWithArgs(NSString *username, id launchTarget, int width, int height, int minVersion, NSArray<NSString *> *jarArgs) {
    NSLog(@"[JavaLauncher] Beginning JVM launch");
    JITReportInit();
    JITReportLine(@"device=%@ ios=%@ flags=0x%X txm=%d memorystatus=%d",
        WitchHardwareMachine(), UIDevice.currentDevice.systemVersion,
        (unsigned)DeviceGetJITFlags(YES), DeviceHasTXM(),
        getEntitlementValue(@"com.apple.private.memorystatus"));

    init_loadDefaultEnv();
    init_loadCustomEnv();
    init_loadMobileGluesConfig();
    init_loadLTWConfig();
    init_loadMobileGLConfig();
    init_loadTGLMTConfig();

    DeviceGetJITFlags(YES);
    BOOL requiresDebugJITMapping = DeviceNeedsDebugJITMapping();
    BOOL jit26AlwaysAttached = getPrefBool(@"debug.debug_always_attached_jit");
    // Patched Java 8/17/21/25 runtimes always route code-cache allocation
    // through brk #0xf00d / brk #0x6a on iOS 26.6+/27 — even on TXM devices
    // where RX mappings work directly (see patch_libjvm_jit_alloc.py /
    // patch_libjvm_mirror_brk.py). The launcher must therefore run the full
    // JIT26 handshake (script upload + probe + exception ports) on every
    // iOS 26+ device, regardless of the TXM classification. Skipping it on
    // "blanket TXM" iOS 27 devices (iPhone 12/13 & co.) leaves the JVM's
    // first breakpoint unserviced: the JVM thread hangs inside JLI_Launch
    // before any Java output — the all-black, frozen-log screen.
    BOOL jit26Handshake = DeviceHasJITFlags(JIT_FLAG_IS_IOS_26);
    NSLog(@"[JavaLauncher] JIT flags 0x%X -> requiresDebugJITMapping=%d jit26Handshake=%d",
        (unsigned)DeviceGetJITFlags(NO), requiresDebugJITMapping, jit26Handshake);
    // Script liveness + preflight outcome. The handshake below only RECORDS them;
    // enforcement happens at the mirror decision (classic path needs an attached
    // debugger, not a script — so script failures must NOT abort a classic launch).
    BOOL jitScriptAlive = YES;
    BOOL preflightOK = NO;
    if (jit26Handshake) {
        // Ensure UniversalJIT26.js is synced to Documents, LCAppInfo.plist, and Clipboard
        init_setupUniversalJITScript(YES);

        // Keep StikDebug attached through probe, JVM init, and mirror prepare.
        // Catch unserviced handshake brks (SIGTRAP) so the app shows an error
        // dialog instead of dying to the home screen.
        BOOL traced = processIsDebugged();
        NSLog(@"[JavaLauncher] JIT26 handshake begin (debugger attached: %d, txm=%d, flags=0x%X)",
            traced, DeviceHasTXM(), (unsigned)DeviceGetJITFlags(NO));
        JITReportLine(@"handshake traced=%d", traced);
        if (!traced) {
            // No debugger servicing breakpoints. The patched JRE on iOS 26+/27
            // always routes code-cache allocation through brk #0xf00d / 0x6a;
            // without a debugger those brks raise SIGTRAP which loops forever
            // (PC stays at the faulting instruction). Show a clear error instead
            // of hanging with a black screen.
            init_setupUniversalJITScript(YES);
            showDialog(localize(@"Error", nil),
                @"JIT is required but no debugger is attached.\n\n"
                 @"1. Open StikDebug\n"
                 @"2. Enable JIT for Witch (toggle ON)\n"
                 @"3. UniversalJIT26.js has been copied to your clipboard & synced to Documents / LiveContainer\n"
                 @"4. Close and reopen Witch, then try again");
            [PLLogOutputView handleExitCode:1];
            return 1;
        }
        struct sigaction jitTrapSa = {0};
        struct sigaction oldTrapSa;
        jitTrapSa.sa_handler = onUnservicedBrk;
        sigemptyset(&jitTrapSa.sa_mask);
        jitTrapSa.sa_flags = 0;
        sigaction(SIGTRAP, &jitTrapSa, &oldTrapSa);
        // The FIRST brk must be the base-script probe: StikDebug attaches and
        // starts the assigned Universal JIT script while servicing that brk,
        // and a stale assigned script (from an older launcher) only knows the
        // probe/extension commands. Sending JIT26SetDetachAfterFirstBr (cmd 3)
        // here made such scripts log "Unknown command 3" and leave the thread
        // stopped forever — the black-screen freeze users hit with StikDebug.
        // The detach policy is applied later, after the extension re-registered
        // commands 3/4 (see JIT26SetDetachAfterFirstBrGuarded callers).
        // Use the same brk #0xf00d path as patched libjvm (not legacy brk #0x69).
        void *volatile probeMapping = NULL;
        g_jitTrapArmed = 1;
        if (sigsetjmp(g_jitTrapJmp, 1) == 0) {
            probeMapping = JIT26PrepareRegion(NULL, getpagesize());
        } else {
            NSLog(@"[JavaLauncher] JIT26 probe brk was NOT serviced on this thread "
                  @"(debugger detached or has no script). Failing loudly instead of spinning.");
        }
        g_jitTrapArmed = 0;
        NSLog(@"[JavaLauncher] JIT26 probe returned %p (txm=%d, flags=0x%X)", probeMapping,
            DeviceHasTXM(), (unsigned)DeviceGetJITFlags(NO));
        JITReportLine(@"probe=%p valid=%d", probeMapping, JIT26ProbeLooksValid(probeMapping));
        // Soft-fail: a dead script only matters for the mirror path (enforced at
        // the mirror decision). The classic path needs attach, not a script.
        BOOL probeValid = JIT26ProbeLooksValid(probeMapping);
        if (!probeValid) {
            NSLog(@"[JavaLauncher] probe not serviced (got %p) — recording script-dead, continuing to classic evaluation", probeMapping);
            init_setupUniversalJITScript(YES);
            jitScriptAlive = NO;
        }
        if (jitScriptAlive) {
        NSString *extPath = [NSBundle.mainBundle pathForResource:@"UniversalJIT26Extension" ofType:@"js"];
        NSString *extensionScript = extPath ? [NSString stringWithContentsOfFile:extPath encoding:NSUTF8StringEncoding error:nil] : nil;
        if (extensionScript.length > 0) {
            NSLog(@"[JavaLauncher] Loading UniversalJIT26Extension.js (%lu bytes)", (unsigned long)extensionScript.length);
            BOOL extensionDelivered = YES;
            g_jitTrapArmed = 1;
            if (sigsetjmp(g_jitTrapJmp, 1) == 0) {
                JIT26SendJITScript(extensionScript);
            } else {
                extensionDelivered = NO;
                NSLog(@"[JavaLauncher] Extension brk was NOT serviced — the StikDebug script "
                      @"does not implement command 2 (0x68). Assign UniversalJIT26.js in StikDebug.");
            }
            g_jitTrapArmed = 0;
            if (!extensionDelivered) {
                init_setupUniversalJITScript(YES);
                JITReportLine(@"extension=UNSERVICED");
                NSLog(@"[JavaLauncher] Extension brk was NOT serviced — the StikDebug script "
                      @"does not implement command 2 (0x68). Recording script-dead.");
                jitScriptAlive = NO;
            } else {
            NSLog(@"[JavaLauncher] Extension delivered; if the game later hangs, confirm "
                  @"'Amethyst UniversalJIT26 extension loaded' appears in the StikDebug log");
            JITReportLine(@"extension=delivered");
            }
        } else {
            NSLog(@"[JavaLauncher] UniversalJIT26Extension.js is missing or empty; using assigned base JIT script only");
        }
        } // end extension attempt (skipped entirely when probe already failed)
        // ALWAYS restore the pre-handshake SIGTRAP disposition before continuing.
        sigaction(SIGTRAP, &oldTrapSa, NULL);
        if (jitScriptAlive) {
        // Install the dyld LV bypass WHILE StikDebug is still attached. If we wait
        // until after detach-after-first-br, processIsCurrentlyDebugged() is false
        // and unsigned JNA / renderer dylibs fail with code-signature invalid.
        init_bypassDyldLibValidation();
        NSLog(@"[JavaLauncher] DyldLVBypass init completed during JIT26 handshake");
        JITReportLine(@"dyld mmap_matches=%d mmap_ok=%d fcntl_matches=%d fcntl_ok=%d",
            g_dyldMmapMatches, g_dyldMmapOK, g_dyldFcntlMatches, g_dyldFcntlOK);
        // Safe here: the probe above proved the script services brks and the
        // extension just re-registered command 3 even for stale base scripts.
        JIT26SetDetachAfterFirstBrGuarded(!jit26AlwaysAttached);
        init_jit_vm_remap_hook();
        // make sure we don't get stuck in EXC_BAD_ACCESS
        task_set_exception_ports(mach_task_self(), EXC_MASK_BAD_ACCESS, 0, EXCEPTION_DEFAULT, MACHINE_THREAD_STATE);
        // Pre-flight: prove debugger-blessed memory is really executable. A failure
        // is RECORDED, not fatal here: the mirror decision below is the single
        // enforcement point (classic path may still work via native MAP_JIT bless).
        preflightOK = JIT26ExecPreflight();
        JITReportLine(@"preflight=%d", preflightOK);
        if (!preflightOK) {
            NSLog(@"[JavaLauncher] preflight failed — recording; mirror gate decides");
            jitScriptAlive = NO;
        }
        } // end script-dependent section (dyld bypass + preflight need a live script)
        JITReportLine(@"script_alive=%d", jitScriptAlive);
    }
    // iOS 26/27 still needs the LV bypass for JNA, renderer dylibs, and mods
    // extracted to Documents. StikDebug keeps us CS_DEBUGGED so the mirrored
    // dyld patches are legal — do not leave this off just because
    // requiresDebugJITMapping is set. init_bypassDyldLibValidation is idempotent.
    BOOL debuggerAttached = processIsCurrentlyDebugged();
    // Skip the (debugger-dependent) bypass when the script is dead: its x16=4 brks
    // would otherwise trap with the default disposition. Unsigned runtime libs
    // then fail later with visible signature errors instead of silent death.
    if ((jit26Handshake || !requiresDebugJITMapping || jit26AlwaysAttached || debuggerAttached) &&
        (jitScriptAlive || !jit26Handshake)) {
        if (jit26AlwaysAttached) {
            // Only allow StikDebug to catch our breakpoints to prevent any stutters
            task_set_exception_ports(mach_task_self(), EXC_MASK_ALL & ~EXC_MASK_BREAKPOINT, 0,
                EXCEPTION_DEFAULT, THREAD_STATE_NONE);
        }
        init_bypassDyldLibValidation();
        NSLog(@"[JavaLauncher] DyldLVBypass init completed (debugger=%d handshake=%d)",
            debuggerAttached, jit26Handshake);
    } else {
        NSLog(@"[DyldLVBypass] Hook disabled! Loading unsigned dylib will cause code signature error.");
    }

    BOOL launchJar = ![launchTarget isKindOfClass:NSDictionary.class];
    NSString *gameDir;
    NSString *defaultJRETag;

    // Get preferred Java version from current profile
    int preferredJavaVersion = [PLProfiles resolveKeyForCurrentProfile:@"javaVersion"].intValue;
    if (preferredJavaVersion > 0) {
        if (minVersion > preferredJavaVersion) {
            NSLog(@"[JavaLauncher] Profile's preferred Java version (%d) does not meet the minimum version (%d), dropping request", preferredJavaVersion, minVersion);
        } else {
            NSDebugLog(@"[PLProfiles] Applying javaVersion");
            minVersion = preferredJavaVersion;
        }
    }
    if (launchJar) {
        defaultJRETag = @"execute_jar";
        // Create expected directory for OptiFine and other installers
        NSString *mcSupportDir = [NSString stringWithFormat:@"%s/Library/Application Support/minecraft", getenv("POJAV_HOME")];
        [fm createDirectoryAtPath:mcSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
    } else if (minVersion <= 8) {
        defaultJRETag = @"1_16_5_older";
    } else {
        defaultJRETag = @"1_17_newer";
    }

    // Setup AMETHYST_RENDERER
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    if (!isExperimentalMetalRendererEnabled() &&
        ([renderer isEqualToString:@ RENDERER_NAME_METAL] ||
         [renderer isEqualToString:@ RENDERER_NAME_METAL_MACOS])) {
        NSLog(@"[JavaLauncher] Experimental Metal renderer '%@' is disabled; falling back to auto (set WITCH_ENABLE_METAL_RENDERERS=1 to enable)", renderer);
        renderer = @"auto";
    }
    NSLog(@"[JavaLauncher] RENDERER is set to %@\n", renderer);
    setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);
    // MC 26.x graphics-API forcing policy (video.graphics_backend_forcing pref).
    // Values match `--graphicsBackend` semantics: vulkan|opengl force that API,
    // "none" appends nothing so MC honors its own in-game "Graphics Backend"
    // option, auto keeps the legacy renderer-derived choice (Tools.java).
    {
        id gbfPref = getPrefObject(@"video.graphics_backend_forcing");
        NSString *forcing = [gbfPref isKindOfClass:NSString.class] ? (NSString *)gbfPref : @"auto";
        NSString *envValue = @"auto";
        if ([forcing isEqualToString:@"vulkan"] || [forcing isEqualToString:@"opengl"]) {
            envValue = forcing;
        } else if ([forcing isEqualToString:@"none"]) {
            envValue = @"none";
        }
        setenv("WITCH_FORCE_BACKEND", envValue.UTF8String, 1);
        NSLog(@"[JavaLauncher] WITCH_FORCE_BACKEND → %@ (pref %@)", envValue, forcing);
    }
    if ([renderer isEqualToString:@ RENDERER_NAME_METAL_MACOS]) {
        // Opt-in marker for mods that were ported from macOS and need the
        // compatibility path. The plain "metal" renderer stays untouched.
        setenv("WITCH_METAL_MACOS", "1", 1);
        NSLog(@"[JavaLauncher] Metal macOS-port compatibility enabled");
        // MetalBridgeKit re-implements the macOS-only Metal API surface the
        // ported mod calls (managed storage, BC formats, tessellation patch,
        // sparse pages, argument replay) on top of iOS public APIs. Load it
        // RTLD_GLOBAL so its ObjC classes (MBProbe, ...) register in-process
        // before the mod's own dlopen/dlsym pass, and publish absolute paths
        // so the mod can reach the framework from any working directory.
        NSString *bridgeFrameworks = NSBundle.mainBundle.privateFrameworksPath;
        NSString *bridgeBundle = [bridgeFrameworks stringByAppendingPathComponent:@"MetalBridgeKit.framework"];
        NSString *bridgeBinary = [bridgeBundle stringByAppendingPathComponent:@"MetalBridgeKit"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:bridgeBinary]) {
            void *bridge = dlopen(bridgeBinary.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
            if (bridge != NULL) {
                setenv("WITCH_METAL_BRIDGE_PATH", bridgeBinary.UTF8String, 1);
                setenv("WITCH_METAL_BRIDGE_BUNDLE", bridgeBundle.UTF8String, 1);
                Class probeClass = NSClassFromString(@"MBProbe");
                if (probeClass && [probeClass respondsToSelector:@selector(frameworkVersion)]) {
                    NSString *version = [probeClass performSelector:@selector(frameworkVersion)];
                    NSLog(@"[MetalBridgeKit] Loaded %@ (v%@)", bridgeBinary, version);
                } else {
                    NSLog(@"[MetalBridgeKit] Loaded %@ (MBProbe class unavailable)", bridgeBinary);
                }
                // On-device verification of every service: set
                // WITCH_METAL_PROBE=0 to skip it on slow devices.
                const char *probeFlag = getenv("WITCH_METAL_PROBE");
                if (!probeFlag || strcmp(probeFlag, "0") != 0) {
                    Class probe = NSClassFromString(@"MBProbe");
                    if (probe && [probe respondsToSelector:@selector(runAllServices)]) {
                        NSString *report = [probe performSelector:@selector(runAllServices)];
                        NSLog(@"[MetalBridgeKit] Service probes:\n%@", report);
                    } else {
                        NSLog(@"[MetalBridgeKit] MBProbe class unavailable");
                    }
                }
            } else {
                NSLog(@"[MetalBridgeKit] dlopen %@ failed: %s", bridgeBinary, dlerror());
            }
        } else {
            NSLog(@"[MetalBridgeKit] Framework missing at %@ — the macOS Metal mod will not find its compatibility path", bridgeBundle);
        }
    }

    // MobileGlues resolves every EGL/GLES symbol with dlsym(RTLD_DEFAULT) at
    // load time, and MC 26.2's NativeLibrariesBootstrap dlopens it during JVM
    // startup (opengl.libname) before any GLFW/SDL window hook can run — the
    // old pojavInitOpenGL preload comes too late and the backend probe hangs.
    // Pre-load the backend now, while still before JLI_Launch. GLFW-path
    // games re-run the same idempotent preload from pojavInitOpenGL.
    // Explicit renderers only: "auto" can still resolve to GL4ES from the
    // game's context-version hint and must not inherit a MobileGlues backend.
    if ([renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES] ||
        [renderer isEqualToString:@ RENDERER_NAME_MOLTENVK]) {
        PLPreloadMobileGluesBackend();
    } else if ([renderer isEqualToString:@ RENDERER_NAME_LTW]) {
        // libltw's constructor dlopens LIBGL_EGL when LWJGL loads it during JVM
        // startup. MC 26.3 reaches that point before pojavInitOpenGL, so the
        // backend and environment must be ready here or proc_init() aborts.
        PLPreloadLTWBackend();
    }

    // The TouchController mod (0.3.1-alpha13+) only activates its iOS
    // platform when TOUCH_CONTROLLER_PROXY_SOCKET is set. It must be set
    // BEFORE the JVM starts: the JVM snapshots the environment at boot and
    // later setenv() calls are invisible to System.getenv(). The value is
    // not a real socket path (the transport is an in-process ring buffer),
    // so any non-empty value works. Only set it when the instance actually
    // ships the mod (mirrors Tools.hasModLibrary); otherwise leave it unset.
    NSString *tcGameDir = [NSString stringWithFormat:@"%s/instances/%@/%@",
        getenv("POJAV_HOME"), getPrefObject(@"general.game_directory"),
        [PLProfiles resolveKeyForCurrentProfile:@"gameDir"]]
        .stringByStandardizingPath;
    if (instanceHasTouchControllerMod(tcGameDir)) {
        setenv("TOUCH_CONTROLLER_PROXY_SOCKET", "inproc:touchcontroller", 1);
        NSLog(@"[JavaLauncher] TouchController mod detected: TOUCH_CONTROLLER_PROXY_SOCKET set");
    }

    // Apply Zink-specific environment variables if Zink renderer is selected
    if ([renderer hasPrefix:@"libOSMesa"]) {
        [ZinkConfig applyZinkEnvironmentFromPreferences];
        NSString *configSummary = [ZinkConfig activeConfigSummary];
        NSLog(@"[ZinkConfig] ========== Zink Renderer Active ==========");
        NSLog(@"[ZinkConfig] %@", configSummary);
        setenv("ZINK_ACTIVE_CONFIG", configSummary.UTF8String, 1);
    }
    // Setup gameDir
    gameDir = [NSString stringWithFormat:@"%s/instances/%@/%@",
        getenv("POJAV_HOME"), getPrefObject(@"general.game_directory"),
        [PLProfiles resolveKeyForCurrentProfile:@"gameDir"]]
        .stringByStandardizingPath;
    setenv("POJAV_GAME_DIR_PROFILE", gameDir.UTF8String, 1);
    NSLog(@"[JavaLauncher] Looking for Java %d or later", minVersion);
    NSString *javaHome = getSelectedJavaHome(defaultJRETag, minVersion);

    if (javaHome == nil) {
        UIKit_returnToSplitView();
        BOOL isExecuteJar = [defaultJRETag isEqualToString:@"execute_jar"];
        showDialog(localize(@"Error", nil), [NSString stringWithFormat:localize(@"java.error.missing_runtime", nil),
            isExecuteJar ? [launchTarget lastPathComponent] : PLProfiles.current.selectedProfile[@"lastVersionId"], minVersion]);
        return 1;
    }

    if (requiresDebugJITMapping && !RuntimeSupportsDebugJITMapping(javaHome)) {
        NSLog(@"[JavaLauncher] Missing mirror marker: javaHome=%@ marker=.witch-mirror-mapping (txm=%d, flags=0x%X). Pick a bundled Java 8/17/21/25 runtime rebuilt with `make jre`.",
            javaHome, DeviceHasTXM(), (unsigned)DeviceGetJITFlags(NO));
        UIKit_returnToSplitView();
        showDialog(localize(@"Error", nil),
            @"The selected Java runtime does not support JIT on this iOS version. "
             "Open Settings and choose a bundled Java 8, 17, 21 or 25 runtime.");
        return 1;
    }

    // Patched runtimes use mirror_w/x on every iOS 26.6+/27 device, TXM or
    // not (the JVM's code-cache path goes through brk #0xf00d/0x6a regardless
    // of the device's direct-RX capability). needsMirrorJITPrepare therefore
    // only requires iOS 26+ plus a mirror-capable runtime — not
    // requiresDebugJITMapping, which wrongly excluded "blanket TXM" iOS 27
    // devices (iPhone 12/13 & co.) and hung them inside JLI_Launch.
    BOOL needsMirrorJITPrepare = jit26Handshake && RuntimeSupportsDebugJITMapping(javaHome);
    if (needsMirrorJITPrepare) {
        // Mirror-capable patched runtimes use mirror_w/x on every iOS 26.6+/27
        // device. StikDebug must stay attached through vm_remap and follow-up
        // prepare calls. Only send the detach-policy command when the script
        // proved it services brks — with a dead script the brk would trap with
        // the default disposition (crash) or freeze a stale script thread.
        if (jitScriptAlive) {
            JIT26SetDetachAfterFirstBrGuarded(NO);
            NSLog(@"[JavaLauncher] Mirror-capable runtime: debugger kept attached for JIT prepare");
        } else {
            NSLog(@"[JavaLauncher] Mirror-capable runtime but script is dead; skipping detach-policy command (mirror gate will decide)");
        }
    } else if (requiresDebugJITMapping && !jit26AlwaysAttached && jitScriptAlive) {
        JIT26SetDetachAfterFirstBrGuarded(YES);
    }

    if ([javaHome hasPrefix:@(getenv("POJAV_HOME"))]) {
        // Symlink libawt_xawt.dylib
        NSString *dest = [NSString stringWithFormat:@"%@/lib/libawt_xawt.dylib", javaHome];
        NSString *source = [NSString stringWithFormat:@"%@/Frameworks/libawt_xawt.dylib", NSBundle.mainBundle.bundlePath];
        NSError *error;
        [fm createSymbolicLinkAtPath:dest withDestinationPath:source error:&error];
        if (error) {
            NSLog(@"[JavaLauncher] Symlink libawt_xawt.dylib failed: %@", error.localizedDescription);
        }
    }

    setenv("JAVA_HOME", javaHome.UTF8String, 1);
    NSLog(@"[JavaLauncher] JAVA_HOME has been set to %@", javaHome);

    // ==================== Distant Horizons Fix ====================
    // Pre-extract and sign zstd-jni native library to avoid code signature error on iOS
    NSString *versionId = [PLProfiles resolveKeyForCurrentProfile:@"lastVersionId"];
    if (versionId) {
        checkAndAddDhNativeLibPath(versionId);
    }

    int allocmem;
    NSLog(@"[JavaLauncher] Entitlements: memorystatus=%d increased-memory-limit=%d extended-virtual-addressing=%d disable-library-validation=%d",
        getEntitlementValue(@"com.apple.private.memorystatus"),
        getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit"),
        getEntitlementValue(@"com.apple.developer.kernel.extended-virtual-addressing"),
        getEntitlementValue(@"com.apple.security.cs.disable-library-validation"));
    BOOL manualAllocation = !getPrefBool(@"java.auto_ram");
    if (!manualAllocation) {
        CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
        allocmem = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
    } else {
        // Manual allocation: the JVM commits heap lazily, so -Xmx is a
        // ceiling, but a ceiling above the Jetsam budget still kills the
        // process before the game can plateau. Clamp it, don't just warn.
        allocmem = getPrefInt(@"java.allocated_memory");
    }
    int requestedAlloc = allocmem;
    allocmem = capAllocationToJetsamAllowance(allocmem);
    if (manualAllocation && allocmem != requestedAlloc) {
        showDialog(localize(@"Warning", nil),
            [NSString stringWithFormat:@"Your %d MB RAM setting exceeds the safe budget for this device/install. Witch reduced it to %d MB so Minecraft is not force-closed by iOS (Jetsam) mid-play. Lower the render distance or use Auto RAM for more headroom.",
                requestedAlloc, allocmem]);
    }
    int directmem = maxDirectMemoryMB(allocmem);
    NSLog(@"[JavaLauncher] Max RAM allocation is set to %d MB (direct buffer cap %d MB)", allocmem, directmem);
    if (!validateVirtualMemorySpace(allocmem)) {
        UIKit_returnToSplitView();
        if (getEntitlementValue(@"com.apple.developer.kernel.increased-memory-limit")) {
            showDialog(localize(@"Error", nil), @"Insufficient contiguous virtual memory space. Lower memory allocation and try again.");
        } else {
            showDialog(localize(@"Error", nil), @"Insufficient contiguous virtual memory space. Increased Memory Limit entitlement is missing, please add it via GetMoreRam app.");
        }
        return 1;
    }

    int margc = -1;
    const char *margv[1000];

    margv[++margc] = [NSString stringWithFormat:@"%@/bin/java", javaHome].UTF8String;
    margv[++margc] = "-XstartOnFirstThread";
    if (!launchJar) {
        margv[++margc] = "-Djava.system.class.loader=net.kdt.pojavlaunch.PojavClassLoader";
    }
    margv[++margc] = "-Xms128M";
    margv[++margc] = [NSString stringWithFormat:@"-Xmx%dM", allocmem].UTF8String;
    // Without this, HotSpot defaults the direct-buffer cap to Runtime.maxMemory()
    // (sun/misc/VM.java: directMemory = maxMemory), so LWJGL/Sodium/Iris direct
    // buffers can add another -Xmx of native memory on top of the Java heap.
    // That is the main cause of the ~30-minute Jetsam kill on both 4 GB and
    // 6 GB devices. Users can still override it from java.java_args.
    margv[++margc] = [NSString stringWithFormat:@"-XX:MaxDirectMemorySize=%dM", directmem].UTF8String;
    // One line per GC ("700M->300M(768M)") in latestlog: the only way to
    // see the JVM's used/committed heap without rebuilding MC's logging.
    // Accepted by every JDK we ship (JDK8 natively, JDK9+ as an alias of
    // -Xlog:gc), so it costs nothing on the MC versions that matter.
    margv[++margc] = "-verbose:gc";
    
    // Add DH native library path if available
    NSString *javaLibraryPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks"];
    NSString *lwjglVersion = [VersionDirectoryManager resolveEffectiveLwjglVersion];
    NSString *lwjglCode = [lwjglVersion isEqualToString:@"3.4.1"] ? @"41"
        : ([lwjglVersion isEqualToString:@"3.3.6"] ? @"36" : @"33");
    // User-installed LWJGL (Runtime Download screen) lives in
    // POJAV_HOME/lwjgl/lwjgl<code>/{lwjgl.jar,natives,version.txt}. It only
    // overrides the bundled copy when the full install marker exists.
    NSString *externalLwjglDir = [NSString stringWithFormat:@"%s/lwjgl/lwjgl%@", getenv("POJAV_HOME"), lwjglCode];
    NSString *externalLwjglJar = [externalLwjglDir stringByAppendingPathComponent:@"lwjgl.jar"];
    NSString *externalLwjglNatives = [externalLwjglDir stringByAppendingPathComponent:@"natives"];
    BOOL useExternalLwjgl =
        [NSFileManager.defaultManager fileExistsAtPath:[externalLwjglDir stringByAppendingPathComponent:@"version.txt"]]
        && [NSFileManager.defaultManager fileExistsAtPath:externalLwjglJar];
    NSString *lwjglNativesDir;
    if (useExternalLwjgl && [NSFileManager.defaultManager fileExistsAtPath:externalLwjglNatives]) {
        lwjglNativesDir = externalLwjglNatives;
    } else {
        lwjglNativesDir = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"libs/lwjgl%@_natives", lwjglCode]];
    }
    javaLibraryPath = [NSString stringWithFormat:@"%@:%@", lwjglNativesDir, javaLibraryPath];
    if (dhNativeLibPath) {
        javaLibraryPath = [NSString stringWithFormat:@"%@:%@", javaLibraryPath, dhNativeLibPath];
    }
    margv[++margc] = [NSString stringWithFormat:@"-Djava.library.path=%@", javaLibraryPath].UTF8String;
    // Mojang's LWJGL (loaded by Fabric/Knot from the game jar instead of our
    // shim) treats java.library.path as a SINGLE directory; a colon-joined
    // list fails its directory check ("Contents of java.library.path : <not a
    // directory>"). Point org.lwjgl.librarypath at exactly one natives dir —
    // LWJGL checks this property before java.library.path, so Fabric-launched
    // games (e.g. Sodium) can find liblwjgl.dylib and friends.
    margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.librarypath=%@", [javaLibraryPath componentsSeparatedByString:@":"].firstObject].UTF8String;

    // VulkanMod ships the macOS-arm64 Shaderc binary in its own jar. On an
    // iPhone 8 Plus (A11) that binary executes ARMv8.4 RCpc-immo instructions
    // (for example LDAPURSB) and dies with SIGILL while
    // shaderc_compiler_initialize() runs. Force LWJGL to use the matching
    // iOS Shaderc binary from the selected LWJGL natives directory instead
    // of extracting the mod's host-native copy. This is an LWJGL launcher
    // property; it leaves the VulkanMod jar intact.
    NSString *shadercPath = [[javaLibraryPath componentsSeparatedByString:@":"].firstObject
        stringByAppendingPathComponent:@"libshaderc.dylib"];
    margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.shaderc.libname=%@", shadercPath].UTF8String;
    
    margv[++margc] = [NSString stringWithFormat:@"-Duser.dir=%@", gameDir].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-Duser.home=%s", getenv("POJAV_HOME")].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-Duser.timezone=%@", NSTimeZone.localTimeZone.name].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-DUIScreen.maximumFramesPerSecond=%d", (int)UIScreen.mainScreen.maximumFramesPerSecond].UTF8String;
    margv[++margc] = "-Dorg.lwjgl.glfw.checkThread0=false";
    margv[++margc] = "-Dorg.lwjgl.system.allocator=system";
    //margv[++margc] = "-Dorg.lwjgl.util.NoChecks=true";
    margv[++margc] = "-Dlog4j2.formatMsgNoLookups=true";
    // Voxy sizes its geometry SSBO from GL_MAX_SHADER_STORAGE_BLOCK_SIZE by
    // rounding up to the next power of two and then doubling it. MobileGL
    // advertises at most 512MB, so Voxy asks for 1GB even though Metal's
    // maxBufferLength on A11 is ~747MB and the 2GB Jetsam budget cannot hold
    // it. Use Voxy's supported override, but scale it with the device instead
    // of pinning every iPhone to the 2GB-phone value.
    size_t physMB = (size_t)(NSProcessInfo.processInfo.physicalMemory / (1024 * 1024));
    size_t availMB = availableMemoryMB();
    // Lower defaults: the old 256/384/512 MB + Sodium/Iris buffers alone
    // exceed a 2 GiB Jetsam envelope. The user can still raise this via
    // java.java_args if Voxy is installed and the device has headroom.
    int voxyGeometryMB = 128;
    if (physMB >= 4096 && (availMB == 0 || availMB >= 1800)) {
        voxyGeometryMB = 256;
    } else if (physMB >= 3072 && (availMB == 0 || availMB >= 1400)) {
        voxyGeometryMB = 192;
    }
    NSLog(@"[JavaLauncher] Voxy geometry buffer: %d MB (physical=%zu MB, jetsam allowance=%zu MB)",
          voxyGeometryMB, physMB, availMB);
    margv[++margc] = [NSString stringWithFormat:@"-Dvoxy.geometryBufferSizeOverrideMB=%d", voxyGeometryMB].UTF8String;

    // Preset OpenGL libname
    const char *glLibName = getenv("AMETHYST_RENDERER");
    if (glLibName) {
        if (!strcmp(glLibName, "auto")) {
            // workaround only applies to 1.20.2+
            glLibName = RENDERER_NAME_MTL_ANGLE;
        }
        // libMoltenVK is a Vulkan loader, not a GL implementation; binding it as
        // opengl.libname makes LWJGL fail looking up GL symbols. The Vulkan
        // libname is set in PojavLauncher.java instead.
        //
        // BUT: Minecraft 26.2's NativeLibrariesBootstrap.loadOpenGL() initializes
        // org.lwjgl.opengl.GL during startup REGARDLESS of which renderer the
        // game ultimately uses. With opengl.libname unset, LWJGL falls back to
        // MacOSXLibraryBundle.getWithIdentifier("com.apple.opengl") which fails
        // on iOS (no system OpenGL framework) →
        //   java.lang.UnsatisfiedLinkError: Failed to retrieve bundle with
        //   identifier: com.apple.opengl
        // Point opengl.libname at libmobileglues.dylib for Vulkan setups —
        // MobileGlues is purpose-built for GL-on-Metal/Vulkan on mobile and
        // already uses our shipped libspirv-cross.dylib for shader translation.
        // GL.create() finds GL function pointers; if Minecraft ever does call
        // a GL entry point (compat code, shader build, etc.) MobileGlues can
        // route it through Vulkan rather than crashing like a context-less
        // gl4es would.
        const char *openglLibName;
        if (strcmp(glLibName, RENDERER_NAME_MOBILEGL) == 0) {
            // MobileGL exports GL functions via its own EGL implementation.
            // LWJGL must load libMobileGL.dylib directly so its GL function
            // pointers resolve from the library that owns the current context.
            openglLibName = RENDERER_NAME_MOBILEGL;
            NSLog(@"[JavaLauncher] opengl.libname → %s (MobileGL native)", openglLibName);
        } else if (strcmp(glLibName, RENDERER_NAME_TGLMT) == 0) {
            // TGLMT exports plain C gl* (701 symbols) + TGLMT_* window API.
            // LWJGL loads it directly; context/swap chạy qua tglmt_bridge
            // (br_* table), không qua EGL.
            openglLibName = RENDERER_NAME_TGLMT;
            NSLog(@"[JavaLauncher] opengl.libname → %s (TGLMT native GL 4.6)", openglLibName);
        } else if (strcmp(glLibName, RENDERER_NAME_METAL) == 0 ||
                   strcmp(glLibName, RENDERER_NAME_METAL_MACOS) == 0) {
            // MC 26.3's NativeLibrariesBootstrap calls GL.getFunctionProvider()
            // before any backend is picked. A Metal mod replaces the GPU
            // backend, so this library only has to export gl* symbols; no GL
            // context, bridge table or swapchain is created for it.
            openglLibName = RENDERER_NAME_TGLMT;
            NSLog(@"[JavaLauncher] opengl.libname → %s (Metal/%s mod: symbol provider only)",
                  openglLibName, glLibName);
        } else if (strcmp(glLibName, RENDERER_NAME_MOLTENVK) == 0) {
            // MoltenVK: use MobileGlues for GL entry points
            openglLibName = RENDERER_NAME_MOBILEGLUES;
            NSLog(@"[JavaLauncher] opengl.libname → %s (MoltenVK fallback)", openglLibName);
        } else if (strcmp(glLibName, RENDERER_NAME_MOBILEGLUES) == 0) {
            openglLibName = RENDERER_NAME_MOBILEGLUES;
            id angleBackendPref = getPrefObject(@"mobileglues.angle_backend");
            NSString *angleBackend = (angleBackendPref && [angleBackendPref isKindOfClass:[NSString class]])
                ? (NSString *)angleBackendPref : @"tgles";
            if ([angleBackend isEqualToString:@"metal"]) {
                // MC 26.x drives the new DSA/vertex-attrib renderer. Legacy MG
                // 1.3.5 predates those fixes and drops the whole GUI pass, so
                // use the current MG there. Keep legacy for 1.21.x, where the
                // current MG + ANGLE Metal combination was previously broken.
                BOOL useLegacyMetal = YES;
                if (versionId.length > 0) {
                    NSInteger major = [[versionId componentsSeparatedByString:@"."].firstObject integerValue];
                    if (major >= 26) useLegacyMetal = NO;
                }
                setenv("MOBILEGL_LEGACY_METAL", useLegacyMetal ? "1" : "0", 1);
                NSString *legacyPath = [[NSBundle mainBundle].privateFrameworksPath
                    stringByAppendingPathComponent:@ RENDERER_NAME_MOBILEGLUES_OLD];
                if (useLegacyMetal && [fm fileExistsAtPath:legacyPath]) {
                    openglLibName = RENDERER_NAME_MOBILEGLUES_OLD;
                    NSLog(@"[JavaLauncher] opengl.libname → %s (MobileGlues legacy + ANGLE Metal)", openglLibName);
                } else {
                    NSLog(@"[JavaLauncher] opengl.libname → %s (MobileGlues current + ANGLE Metal, legacy=%d)",
                          openglLibName, useLegacyMetal);
                }
            } else {
                NSLog(@"[JavaLauncher] opengl.libname → %s (MobileGlues current, backend=%@)",
                      openglLibName, angleBackend);
            }
        } else if (strcmp(glLibName, RENDERER_NAME_LTW) == 0) {
            // LTW exports both the GL wrappers and eglGetProcAddress; loading it
            // directly is what makes LD's gl* calls go through the LTW override
            // chain. Do NOT let the global Zink/Mesa preference below hijack
            // this with libEGL_Mesa26.dylib.
            openglLibName = RENDERER_NAME_LTW;
            NSLog(@"[JavaLauncher] opengl.libname → %s (LTW GL wrapper)", openglLibName);
        } else if (strncmp(glLibName, "libOSMesa", 9) == 0 && [ZinkConfig isZinkUsingEGL]) {
            // Mesa 26.2.2 (EGL): LWJGL must resolve GL procs from libEGL.1.dylib
            openglLibName = "libEGL_Mesa26.dylib";
            NSLog(@"[JavaLauncher] opengl.libname → %s (Mesa 26.2.2 EGL mode)", openglLibName);
        } else {
            openglLibName = glLibName;
            NSLog(@"[JavaLauncher] opengl.libname → %s (renderer default)", openglLibName);
        }
        // Absolute Frameworks path is required so LWJGL's Library.loadNative
        // takes the direct-load path and never resolves through
        // org.lwjgl.librarypath (the natives dirs). A bare name lets a stale
        // same-named file in the natives dir shadow the signed Frameworks copy
        // -> UnsatisfiedLinkError (error=null) in GL.create() on MC 26.x.
        {
            NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
            NSString *absPath = [frameworks stringByAppendingPathComponent:@(openglLibName)];
            if ([fm fileExistsAtPath:absPath]) {
                margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.opengl.libname=%@", absPath].UTF8String;
                NSLog(@"[JavaLauncher] opengl.libname absolute → %@", absPath);
            } else {
                margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.opengl.libname=%s", openglLibName].UTF8String;
                NSLog(@"[JavaLauncher] opengl.libname bare (not in Frameworks) → %s", openglLibName);
            }
        }
    }

    // VulkanMod / MC 26 vulkan backend always dlopen MoltenVK via LWJGL.
    // org.lwjgl.librarypath is the LWJGL natives dir, which does not contain
    // a signed libMoltenVK.dylib — LWJGL then fails with UnsatisfiedLinkError
    // (error=null) and the game crashes to the home screen. Point at the
    // Frameworks copy. Absolute path is required so LWJGL skips name-mapping.
    {
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        NSString *mvkPath = [frameworks stringByAppendingPathComponent:@"libMoltenVK.dylib"];
        id mvkVer = getPrefObject(@"video.moltenvk_version");
        if ([mvkVer isKindOfClass:NSString.class] && [mvkVer isEqualToString:@"1.2"]) {
            NSString *mvk12 = [frameworks stringByAppendingPathComponent:@"libMoltenVK12.dylib"];
            if ([fm fileExistsAtPath:mvk12]) {
                mvkPath = mvk12;
            }
        }
        if ([fm fileExistsAtPath:mvkPath]) {
            margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.vulkan.libname=%@", mvkPath].UTF8String;
            NSLog(@"[JavaLauncher] vulkan.libname → %@", mvkPath);
        }
        NSString *jnaBoot = [frameworks stringByAppendingPathComponent:@"libjnidispatch.dylib"];
        if ([fm fileExistsAtPath:jnaBoot]) {
            margv[++margc] = [NSString stringWithFormat:@"-Djna.boot.library.path=%@", frameworks].UTF8String;
            margv[++margc] = [NSString stringWithFormat:@"-Djna.library.path=%@", frameworks].UTF8String;
        }
    }

    // Point LWJGL spvc bindings at libspirv-cross-c-shared.0.dylib (the one
    // MobileGlues ships and that's already loaded into the process by the
    // time spvc.<clinit> runs). LWJGL's default would be to dlopen
    // "libspirv-cross.dylib"; if we ship a separate file with that filename
    // it collides at dyld registration because both share the install_name
    // @rpath/libspirv-cross-c-shared.0.dylib. Reusing the already-loaded
    // C library avoids the duplicate.
    //
    // NOTE: LWJGL's Library.loadNative passes the configured libname through
    // Platform.mapLibraryNameBundled which on macOS prefixes "lib" and
    // suffixes ".dylib". Pass just the base name "spirv-cross-c-shared.0"
    // so the result is libspirv-cross-c-shared.0.dylib (not
    // liblibspirv-cross-c-shared.0.dylib.dylib).
    margv[++margc] = "-Dorg.lwjgl.spvc.libname=spirv-cross-c-shared.0";

    NSString *librariesPath = [NSString stringWithFormat:@"%@/libs", NSBundle.mainBundle.bundlePath];
    margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/cacio-init-agent.jar=", librariesPath].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/patchjna_agent.jar=", librariesPath].UTF8String;

    // FidelityFX (FSR 1 / FSR 2 / FSR 3 upscaler / frame generation). The agent
    // jar is only attached when one of the features is enabled. The two are
    // independent and can be combined: fsr3.upscaler (0=off 1=FSR1 2=FSR2
    // 3=FSR3U) is mapped to the native upscaler modes (FSR1=2 FSR2=3 FSR3U=4),
    // fsr3.framegen enables frame interpolation.
    NSInteger fsr3Upscaler = getPrefInt(@"fsr3.upscaler");
    BOOL fsr3Framegen = getPrefBool(@"fsr3.framegen");
    if (fsr3Upscaler >= 1 && fsr3Upscaler <= 3) {
        fsr3Upscaler += 1;  // UI value -> native Fsr3Native mode (FSR1=2 ...).
    } else {
        fsr3Upscaler = 0;
    }
    const BOOL fsr3Active = (fsr3Upscaler > 0 || fsr3Framegen);
    setenv("WITCH_MVK_SUBGROUP_WORKGROUP", fsr3Active ? "1" : "0", 1);
    if (fsr3Active) {
        float fsr3Scale = getPrefFloat(@"fsr3.resolution_scale");
        if (fsr3Scale <= 0.0f || fsr3Scale > 1.0f) {
            fsr3Scale = 1.0f;
        }
        float fsr3Sharpness = getPrefFloat(@"fsr3.sharpness");
        if (fsr3Sharpness < 0.0f || fsr3Sharpness > 1.0f) {
            fsr3Sharpness = 0.6f;
        }
        // Frame generation multiplier: the number of frames displayed per real
        // frame (2 = classic x2, one generated frame). Values other than
        // 2/3/4/6 fall back to 2.
        NSInteger fsr3FgMultiplier = getPrefInt(@"fsr3.framegen_multiplier");
        if (fsr3FgMultiplier != 2 && fsr3FgMultiplier != 3 &&
            fsr3FgMultiplier != 4 && fsr3FgMultiplier != 6) {
            fsr3FgMultiplier = 2;
        }
        margv[++margc] = [NSString stringWithFormat:
            @"-javaagent:%@/fsr3-agent.jar=mode=%ld&fg=%d&fgx=%ld&scale=%.3f&sharp=%.3f&probe=%ld",
            librariesPath, (long)fsr3Upscaler, fsr3Framegen ? 1 : 0,
            (long)fsr3FgMultiplier, fsr3Scale, fsr3Sharpness,
            (long)getPrefInt(@"fsr3.probe")].UTF8String;
    }

    // F3 debug overlay metadata. The agent patches the game's debug screen at
    // class-load time (obfuscation-proof "Java: %s" marker); the values are
    // passed as system properties, one -D per enabled line. Gated per toggle
    // so a disabled line can never appear in-game.
    if (getPrefBool(@"f3.enabled")) {
        margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/f3agent.jar=", librariesPath].UTF8String;
        if (getPrefBool(@"f3.show_chip")) {
            NSString *chip = WitchChipName();
            if (chip.length > 0) {
                margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.chip=%@", chip].UTF8String;
            }
        }
        if (getPrefBool(@"f3.show_ios")) {
            NSString *ios = UIDevice.currentDevice.systemVersion;
            if (ios.length > 0) {
                margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.ios=%@", ios].UTF8String;
            }
        }
        NSDictionary *appInfo = NSBundle.mainBundle.infoDictionary;
        if (getPrefBool(@"f3.show_launcher_name")) {
            NSString *name = appInfo[@"CFBundleDisplayName"] ?: appInfo[@"CFBundleName"] ?: @"Witch";
            margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.launcher=%@", name].UTF8String;
        }
        if (getPrefBool(@"f3.show_launcher_version")) {
            NSString *version = appInfo[@"CFBundleShortVersionString"] ?: @"?";
            margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.version=%@", version].UTF8String;
        }
        if (getPrefBool(@"f3.show_build")) {
            NSString *build = appInfo[@"CFBundleVersion"] ?: @"?";
            margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.build=%@", build].UTF8String;
        }
        if (getPrefBool(@"f3.show_build_type")) {
            NSString *buildType = CONFIG_RELEASE ? @"Release" : @"Development";
            margv[++margc] = [NSString stringWithFormat:@"-Dwitch.f3.buildtype=%@", buildType].UTF8String;
        }
    }
    if(getPrefBool(@"general.cosmetica")) {
        margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/arc_dns_injector.jar=23.95.137.176", librariesPath].UTF8String;
    }
    if ([BaseAuthenticator.current.authData[@"accountType"] isEqualToString:@"elyby"]) {
        margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/authlib-injector.jar=ely.by", librariesPath].UTF8String;
    }

    // Workaround random stack guard allocation crashes
    margv[++margc] = "-XX:+UnlockExperimentalVMOptions";
    margv[++margc] = "-XX:+DisablePrimordialThreadGuardPages";

    // Use ParallelGC instead of G1GC. On mobile with limited heap (~922MB),
    // G1GC's Full GC can pause the app for 1-2 minutes, causing the "freeze
    // then resume" issue. ParallelGC is more efficient for small heaps and
    // avoids stop-the-world compaction stalls on iOS.
    margv[++margc] = "-XX:+UseParallelGC";
    margv[++margc] = "-XX:ParallelGCThreads=2";

    // iOS 26+ mirror-capable runtimes need the paired writable/executable
    // CodeCache mapping. The iPhone 13 / iOS 27 device log confirmed that the
    // standalone JIT preflight succeeds while the classic CodeCache later
    // SIGBUSes in StubRoutines::call_stub, so auto now selects mirror for a
    // runtime carrying the verified mirror marker. Set 0 to force classic for
    // diagnosis; set 1 to force mirror. A mirror launch still requires a live
    // StikDebug script and a passing executable-memory preflight (gated below).
    // debug.debug_mirror_mapped_code_cache: -1 = auto, 0 = classic, 1 = mirror.
    BOOL mirrorEnabled;
    id mirrorOverrideObj = getPrefObject(@"debug.debug_mirror_mapped_code_cache");
    NSInteger mirrorOverride = mirrorOverrideObj ? [mirrorOverrideObj integerValue] : -1;
    if (mirrorOverride >= 0) {
        mirrorEnabled = mirrorOverride > 0;
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache override set to %s", mirrorEnabled ? "ON" : "OFF");
    } else {
        mirrorEnabled = jit26Handshake && RuntimeSupportsDebugJITMapping(javaHome);
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache auto: %s (iOS26=%d mirrorRuntime=%d)",
            mirrorEnabled ? "ON" : "OFF", jit26Handshake,
            RuntimeSupportsDebugJITMapping(javaHome));
    }
    JITReportLine(@"mirror=%d script_alive=%d preflight=%d", mirrorEnabled, jitScriptAlive, preflightOK);
    // Single enforcement point: the mirror path NEEDS a live script (0x6a/prepare)
    // and a passing exec preflight. Classic only needs the attached debugger
    // (checked at handshake begin), so script problems must not block it.
    if (mirrorEnabled && !jitScriptAlive) {
        UIKit_returnToSplitView();
        showDialog(localize(@"Error", nil),
            @"The mirror JIT path needs a working StikDebug script, but none serviced Witch's breakpoints.\n\n"
             @"1. Update StikDebug to 3.1.6 or newer\n"
             @"2. Assign \"Universal JIT 26\" (UniversalJIT26.js) in StikDebug\n"
             @"3. Re-enable JIT for Witch, close and reopen Witch, then try again\n\n"
             @"(Or set debug.debug_mirror_mapped_code_cache=0 for the classic path.)\n\n"
             @"Please send Documents/JITReport-latest.txt with your report.");
        [PLLogOutputView handleExitCode:1];
        return 1;
    }
    if (mirrorEnabled && !preflightOK) {
        UIKit_returnToSplitView();
        showDialog(localize(@"Error", nil),
            @"JIT memory test failed: the debugger cannot provide executable memory "
             @"on this device, but the mirror path requires it.\n\n"
             @"1. Update StikDebug to 3.1.6 or newer\n"
             @"2. Assign \"Universal JIT 26\" (UniversalJIT26.js) in StikDebug\n"
             @"3. Re-enable JIT for Witch, close and reopen Witch, then try again\n\n"
             @"(Or set debug.debug_mirror_mapped_code_cache=0 for the classic path.)\n\n"
             @"Please send Documents/JITReport-latest.txt with your report.");
        [PLLogOutputView handleExitCode:1];
        return 1;
    }
    if (mirrorEnabled) {
        margv[++margc] = "-XX:+MirrorMappedCodeCache";
        // The mirror maps RW+RX aliases of the CodeCache; the default
        // ReservedCodeCacheSize (240 MB on JDK 17+) commits pages as JIT warms
        // up. 128 MB is ample for Minecraft + Iris and leaves headroom under
        // the 2 GiB Jetsam ceiling.
        margv[++margc] = "-XX:ReservedCodeCacheSize=128m";
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache enabled on iOS %ld.%ld (code cache capped at 128 MB)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, (long)NSProcessInfo.processInfo.operatingSystemVersion.minorVersion);

        // Big mirror preflight: reserve + PROVE the full-size mirror region
        // before the JVM exists and offer it to the script, so libjvm's own
        // CodeCache request (brk cmd 1, addr=0 at ~1.0 s) is served from this
        // region instead of a fresh _M mapping. The small preflight earlier
        // only proves 2 pages; on A13/A14/A15 TXM devices the JVM's own
        // request can land at 0x7000_0000_0000 where the exec blessing is
        // ineffective → SIGBUS in StubRoutines::call_stub (hs_err BUS_ADRALN
        // pc=0x70075340bc / 0x70075380bc). The offered size must be >= what
        // the JVM asks for: JDK 21 requests exactly 240 MB (0xF000000, served
        // OK — iPhone13,4 run of 2026-10-18) but JDK 25 requests 240 MB +
        // 16 KB (ReservedCodeCacheSize = 251674624 = 0xF004000,
        // hs_err_pid9437) and the script refuses to serve an offer smaller
        // than the request, so the old 240 MB offer made java-25 fall back to
        // the dead high band. JIT26_MIRROR_REGION_SIZE (244 MB) covers every
        // bundled runtime with margin; the script serves requests of at most
        // the offered size from this region.
        // Guarded: a stale/dead script that does not service the brk must not
        // kill the launch — mirror gates above already required a live script,
        // this only covers it dying in between.
        {
            struct sigaction bigSa = {0};
            struct sigaction bigOldSa;
            bigSa.sa_handler = onUnservicedBrk;
            sigemptyset(&bigSa.sa_mask);
            bigSa.sa_flags = 0;
            sigaction(SIGTRAP, &bigSa, &bigOldSa);
            void *mirrorRegion = NULL;
            CFAbsoluteTime bigStart = CFAbsoluteTimeGetCurrent();
            g_jitTrapArmed = 1;
            if (sigsetjmp(g_jitTrapJmp, 1) == 0) {
                JIT26MirrorRegionPreflight((size_t)JIT26_MIRROR_REGION_SIZE, &mirrorRegion);
            } else {
                NSLog(@"[JavaLauncher] mirror preflight brk was NOT serviced (script died mid-launch)");
            }
            g_jitTrapArmed = 0;
            sigaction(SIGTRAP, &bigOldSa, NULL);
            NSLog(@"[JavaLauncher] mirror preflight done in %.2fs: region=%p",
                  CFAbsoluteTimeGetCurrent() - bigStart, mirrorRegion);
        }
    } else {
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache disabled on iOS %ld.%ld (classic JIT26 path)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, (long)NSProcessInfo.processInfo.operatingSystemVersion.minorVersion);
    }

    // Disable Forge 1.16.x early progress window
    margv[++margc] = "-Dfml.earlyprogresswindow=false";

    // JNA on iOS must load libjnidispatch from jna.boot.library.path
    // (jna.nosys=true), so pre-copy the bundled 5.13.0 dylib into jna_tmp.
    // POJAV_HOME/jna_tmp is what PojavLauncher.main points jna.boot.library.path at.
    NSString *jnaTmpDir = amethyst_hidden_dir(@"jna_tmp");
    [fm createDirectoryAtPath:jnaTmpDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *jnidispatchSrc = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/libjnidispatch.dylib"];
    NSString *jnidispatchDst = [jnaTmpDir stringByAppendingPathComponent:@"libjnidispatch.dylib"];
    if ([fm fileExistsAtPath:jnidispatchSrc]) {
        // Always refresh: a leftover unsigned extract in jna_tmp (from an
        // earlier JNA unpack) is not loadable once DyldLVBypass is off.
        NSError *jnaCopyErr = nil;
        if ([fm fileExistsAtPath:jnidispatchDst]) {
            [fm removeItemAtPath:jnidispatchDst error:nil];
        }
        if ([fm copyItemAtPath:jnidispatchSrc toPath:jnidispatchDst error:&jnaCopyErr]) {
            NSLog(@"[JavaLauncher] Refreshed signed libjnidispatch.dylib at %@", jnidispatchDst);
        } else {
            NSLog(@"[JavaLauncher] Failed to copy libjnidispatch.dylib: %@", jnaCopyErr);
        }
    }

    // Load java
    NSString *libjlipath8 = [NSString stringWithFormat:@"%@/lib/jli/libjli.dylib", javaHome]; // java 8
    NSString *libjlipath11 = [NSString stringWithFormat:@"%@/lib/libjli.dylib", javaHome]; // java 11+
    BOOL isJava8 = [fm fileExistsAtPath:libjlipath8];
    setenv("INTERNAL_JLI_PATH", (isJava8 ? libjlipath8 : libjlipath11).UTF8String, 1);
    NSLog(@"[Bisect] About to dlopen libjli at %s", getenv("INTERNAL_JLI_PATH"));
    fflush(stdout); fflush(stderr);
    void* libjli = dlopen(getenv("INTERNAL_JLI_PATH"), RTLD_GLOBAL);
    NSLog(@"[Bisect] dlopen returned %p", libjli);
    fflush(stdout); fflush(stderr);

    if (!libjli) {
        const char *error = dlerror();
        NSLog(@"[Init] JLI lib = NULL: %s", error);
        UIKit_returnToSplitView();
        showDialog(localize(@"Error", nil), @(error));
        return 1;
    }
    if (needsMirrorJITPrepare) {
        // Preload libjvm and rebind the vm_remap/vm_protect hooks BEFORE the
        // JVM boots so the JIT26 mirror prepare covers every RX request the
        // patched runtime makes — required on iOS 26.6+/27 for TXM devices
        // too (the runtime always uses mirror_w there).
        NSString *libjvmPath = [NSString stringWithFormat:@"%@/lib/server/libjvm.dylib", javaHome];
        if (![fm fileExistsAtPath:libjvmPath]) {
            UIKit_returnToSplitView();
            showDialog(localize(@"Error", nil),
                [NSString stringWithFormat:@"Java runtime is missing libjvm.dylib at:\n%@", libjvmPath]);
            return 1;
        }
        void *libjvm = dlopen(libjvmPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (!libjvm) {
            const char *error = dlerror();
            NSLog(@"[JavaLauncher] libjvm preload failed: %s", error ?: "unknown");
            UIKit_returnToSplitView();
            showDialog(localize(@"Error", nil),
                [NSString stringWithFormat:
                    @"The bundled Java runtime (libjvm.dylib) is damaged and cannot load.\n\n"
                     @"%@\n\n"
                     @"Reinstall the app or rebuild with “make jre” to re-download the JRE.",
                    error ? @(error) : @"unknown error"]);
            return 1;
        }
        NSLog(@"[JavaLauncher] libjvm preloaded at %p", libjvm);
        BOOL mirrorBrkOK = verify_libjvm_mirror_brk_patch();
        NSLog(@"[JavaLauncher] mirror brk verify: %d (libjvm=%@/lib/server/libjvm.dylib, txm=%d)",
            mirrorBrkOK, javaHome, DeviceHasTXM());
        JITReportLine(@"mirror_verify=%d java=%@", mirrorBrkOK, javaHome);
        if (!mirrorBrkOK) {
            // The bundled runtime missed the build-time BL->brk #0x6a patch
            // (see scripts/patch_libjvm_mirror_brk.py). Continuing would die
            // inside JNI_CreateJavaVM (CodeCache::initialize_heaps, 240 MB
            // mirror never prepared on iOS 27) with only a truncated hs_err.
            // Fail fast with a clear dialog instead of a hang/home-screen kill.
            UIKit_returnToSplitView();
            showDialog(localize(@"Error", nil),
                @"The bundled Java runtime is missing the iOS 27 JIT patch (mirror brk #0x6a).\n\n"
                 @"Rebuild with “make jre” (which runs scripts/patch_libjvm_mirror_brk.py + "
                 @"scripts/patch_libjvm_jit_alloc.py) and reinstall the app.");
            [PLLogOutputView handleExitCode:1];
            return 1;
        }
        rebind_jit_vm_hooks_after_libjvm_load();
    }

    // Setup Caciocavallo
    margv[++margc] = "-Djava.awt.headless=false";
    margv[++margc] = "-Dcacio.font.fontmanager=sun.awt.X11FontManager";
    margv[++margc] = "-Dcacio.font.fontscaler=sun.font.FreetypeFontScaler";
    margv[++margc] = [NSString stringWithFormat:@"-Dcacio.managed.screensize=%dx%d", width, height].UTF8String;
    margv[++margc] = "-Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel";
    if (isJava8) {
        // Setup Caciocavallo
        margv[++margc] = "-Dawt.toolkit=net.java.openjdk.cacio.ctc.CTCToolkit";
        margv[++margc] = "-Djava.awt.graphicsenv=net.java.openjdk.cacio.ctc.CTCGraphicsEnvironment";
    } else {
        // Required by Cosmetica to inject DNS
        margv[++margc] = "--add-opens=java.base/java.net=ALL-UNNAMED";

        // Setup Caciocavallo
        margv[++margc] = "-Dawt.toolkit=com.github.caciocavallosilano.cacio.ctc.CTCToolkit";
        margv[++margc] = "-Djava.awt.graphicsenv=com.github.caciocavallosilano.cacio.ctc.CTCGraphicsEnvironment";

        // Required by Caciocavallo17 to access internal API
        margv[++margc] = "--add-exports=java.desktop/java.awt=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/java.awt.peer=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.awt.image=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.java2d=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/java.awt.dnd.peer=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.awt=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.awt.event=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.awt.datatransfer=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.desktop/sun.font=ALL-UNNAMED";
        margv[++margc] = "--add-exports=java.base/sun.security.action=ALL-UNNAMED";
        margv[++margc] = "--add-opens=java.base/java.util=ALL-UNNAMED";
        margv[++margc] = "--add-opens=java.desktop/java.awt=ALL-UNNAMED";
        margv[++margc] = "--add-opens=java.desktop/sun.font=ALL-UNNAMED";
        margv[++margc] = "--add-opens=java.desktop/sun.java2d=ALL-UNNAMED";
        margv[++margc] = "--add-opens=java.base/java.lang.reflect=ALL-UNNAMED";

        // TODO: workaround, will be removed once the startup part works without PLaunchApp
        margv[++margc] = "--add-exports=cpw.mods.bootstraplauncher/cpw.mods.bootstraplauncher=ALL-UNNAMED";
    }

    // Add Caciocavallo bootclasspath
    NSString *cacio_classpath = [NSString stringWithFormat:@"-Xbootclasspath/%s", isJava8 ? "p" : "a"];
    NSString *cacio_libs_path = [NSString stringWithFormat:@"%@/libs_caciocavallo%s", NSBundle.mainBundle.bundlePath, isJava8 ? "" : "17"];
    NSArray *files = [fm contentsOfDirectoryAtPath:cacio_libs_path error:nil];
    for(NSString *file in files) {
        if ([file hasSuffix:@".jar"]) {
            cacio_classpath = [NSString stringWithFormat:@"%@:%@/%@", cacio_classpath, cacio_libs_path, file];
        }
    }
    margv[++margc] = cacio_classpath.UTF8String;

    if (!getEntitlementValue(@"com.apple.developer.kernel.extended-virtual-addressing")) {
        // In jailed environment, where extended virtual addressing entitlement isn't
        // present (for free dev account), allocating compressed space fails.
        // FIXME: does extended VA allow allocating compressed class space?
        margv[++margc] = "-XX:-UseCompressedClassPointers";
    }

    if ([launchTarget isKindOfClass:NSDictionary.class]) {
        for (NSString *arg in launchTarget[@"arguments"][@"jvm_processed"]) {
            margv[++margc] = arg.UTF8String;
        }
    }

    init_loadCustomJvmFlags(&margc, (const char **)margv);
    NSLog(@"[Init] Found JLI lib");

    NSString *lwjglDirPath;
    if (useExternalLwjgl) {
        lwjglDirPath = externalLwjglDir;
    } else if ([lwjglVersion isEqualToString:@"3.4.1"]) {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl41"];
    } else if ([lwjglVersion isEqualToString:@"3.3.6"]) {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl36"];
    } else {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl33"];
    }
    setenv("LWJGL_VERSION", lwjglVersion.UTF8String, 1);

    // Do not append lwjglJarPath explicitly: lwjglDirPath/* already expands to
    // every jar in that folder, so adding the same lwjgl.jar twice puts a
    // duplicate entry in java.class.path. Forge's SecureJarHandler builds a
    // union filesystem keyed by classpath entry and aborts the launch with
    // "Duplicate key .../libs/lwjgl33/lwjgl.jar". Vanilla tolerated it, Forge
    // did not.
    NSString *classpath = [NSString stringWithFormat:@"%@/*:%@/*", librariesPath, lwjglDirPath];
    if (launchJar) {
        classpath = [classpath stringByAppendingFormat:@":%@", launchTarget];
        margv[++margc] = [NSString stringWithFormat:@"-Dpojav.runJar=%@", launchTarget].UTF8String;
        // Forge/NeoForge installers: pass the install directory so the Java side
        // can invoke main with --installClient <gameDir> (see PojavLauncher.java).
        if ([jarArgs isKindOfClass:NSArray.class] && jarArgs.count >= 2 &&
            [jarArgs[0] isEqualToString:@"--installClient"]) {
            margv[++margc] = [NSString stringWithFormat:@"-Dpojav.installDir=%@", jarArgs[1]].UTF8String;
            // Marker file the InstallerProgressViewController writes when the user
            // presses Cancel; the Java side halts the JVM once it appears.
            margv[++margc] = [NSString stringWithFormat:@"-Dpojav.cancelFile=%s/installers/cancel-install", getenv("POJAV_HOME") ?: ""].UTF8String;
        }
    }
    margv[++margc] = "-cp";
    margv[++margc] = classpath.UTF8String;
    margv[++margc] = "net.kdt.pojavlaunch.PojavLauncher";

    margv[++margc] = (username ?: @"").UTF8String;
    margv[++margc] = (VersionDirectoryManager.shared.currentVersion ?: @"").UTF8String;
    //margv[++margc] = "ghidra.GhidraRun";

    pJLI_Launch = (JLI_Launch_func *)dlsym(libjli, "JLI_Launch");

    if (NULL == pJLI_Launch) {
        NSLog(@"[Init] JLI_Launch = NULL");
        return -2;
    }

    NSLog(@"[Init] Calling JLI_Launch");
    JITReportLine(@"jli=reached");

    // 26.x (SDL3 windowing / RenderPearl) refuses SDL_Init until
    // SDL_SetMainReady() runs; pojavInit (GLFW games only) never fires on the
    // SDL path, so prime the flag here for every launch. dlopen the SAME
    // natives dir the game will resolve via org.lwjgl.librarypath so dyld
    // reuses one SDL instance (a different copy would ignore the flag).
    aasdl_setMainReady([javaLibraryPath componentsSeparatedByString:@":"].firstObject.lastPathComponent);

    if (needsMirrorJITPrepare) {
        // Mirror setup needs prepare_memory_region on RX *and* RW after vm_remap.
        // StikDebug must stay attached through those extra brk calls. With
        // debug.debug_mirror_mapped_code_cache=0 (classic diagnosis path) the
        // script may be dead here — never send cmd 3 to a dead script: the
        // brk would crash (detached) or freeze the stale script thread.
        if (jitScriptAlive) {
            JIT26SetDetachAfterFirstBrGuarded(NO);
        } else {
            NSLog(@"[JavaLauncher] Mirror JIT prepare: script dead; skipping detach-policy command");
        }
        task_set_exception_ports(mach_task_self(), EXC_MASK_ALL & ~EXC_MASK_BREAKPOINT, 0,
            EXCEPTION_DEFAULT, THREAD_STATE_NONE);
        rebind_jit_vm_hooks_after_libjvm_load();
        start_jit_mirror_prepare_poll_thread();
        if (mirrorEnabled) {
            prewarm_jit_mirror_superpage();
        }
        NSLog(@"[JavaLauncher] Mirror JIT prepare: debugger kept attached, brk 0x6a handler active");
    }

    // Cr4shed known issue: exit after crash dump,
    // reset signal handler so that JVM can catch them
    signal(SIGSEGV, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGFPE, SIG_DFL);

    // Free split VC
    tmpRootVC = nil;

    // Watch the JVM startup: if it produces no output and never starts
    // rendering within 120s, surface a crash screen instead of leaving the
    // user staring at a frozen black screen. This catches the iOS 26.6+/27
    // hang where the patched JVM's first brk #0xf00d goes unserviced and the
    // JVM thread stalls inside JLI_Launch before any Java output.
    startJVMStartupWatchdog(jit26Handshake, jitNowMs());

    // Footprint sampler for Jetsam diagnosis (native + GPU memory invisible
    // to JVM heap stats). Logs every 2s until the process dies.
    // Fully gated by debug.mem_sample_log (Developer switch, default ON):
    // OFF = zero [MemSample]/[MobileGL-MemStats] lines, no timer at all.
    // A missing key (old installs) means ON.
    id memLogPref = getPrefObject(@"debug.mem_sample_log");
    BOOL memLogEnabled = memLogPref ? [memLogPref boolValue] : YES;
    WitchMemSamplerSetEnabled(memLogEnabled);
    WitchMemSamplerStart();
    // Tell the Java launcher to emit [JVM-Mem] lines (heap + direct buffer
    // pools) with the same debug switch; this is what identifies whether the
    // 30-minute growth is heap, direct ByteBuffers, or native/GPU memory.
    setenv("WITCH_MEM_PROBE", memLogEnabled ? "1" : "0", 1);

    // Desktop launchers run Minecraft with the game directory as the process
    // working directory. Mods such as LabyMod open relative paths
    // (labymod-neo/client-jars/<ver>/client-<ver>.jar) through plain
    // FileInputStream/JarFile, which the JVM resolves against the real process
    // CWD — NOT against the user.dir system property. iOS leaves the CWD at
    // "/", so LabyMod's "Client jar prepared" write (resolved via user.dir)
    // and the later open disagreed and it died with
    // "Failed to open remapped client jar ... (No such file or directory)".
    // chdir() once, before the JVM starts, so every relative path a mod uses
    // behaves exactly like on desktop.
    if (chdir(gameDir.fileSystemRepresentation) != 0) {
        NSLog(@"[JavaLauncher] chdir(%@) failed: %s", gameDir, strerror(errno));
    } else {
        NSLog(@"[JavaLauncher] Working directory -> %@", gameDir);
    }

    jint jliResult = pJLI_Launch(++margc, margv,
                   0, NULL, // sizeof(const_jargs) / sizeof(char *), const_jargs,
                   0, NULL, // sizeof(const_appclasspath) / sizeof(char *), const_appclasspath,
                   // These values are ignored in Java 17, so keep it anyways
                   "1.8.0-internal",
                   "1.8",

                   "java", "openjdk",
                   /* (const_jargs != NULL) ? JNI_TRUE : */ JNI_FALSE,
                   JNI_TRUE, JNI_FALSE, JNI_TRUE);
    // The JVM is gone once JLI_Launch returns. A later memory warning must not
    // dial the old JavaVM pointer in WitchMemoryPressure's System.gc() path.
    runtimeJavaVMPtr = NULL;
    return jliResult;
}

// ==================== JVM Startup Watchdog ====================
static uint64_t jitNowMs(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000 + (uint64_t)(ts.tv_nsec / 1000000);
}

// After JLI_Launch begins, a healthy JVM either prints output (any Java /
// launcher line), starts rendering (CAMetalLayer frame count advances), or
// exits. If none of those happened within the timeout the JVM is wedged —
// typical for the iOS 26.6+/27 patched-runtime brk hang — so surface the
// crash screen with a hint instead of an endless black screen.
static void startJVMStartupWatchdog(BOOL jit26Active, uint64_t launchMs) {
    if (!jit26Active) return; // Pre-iOS 26 classic path never hangs this way.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        uint64_t lastFrame = pojavSwapCount();
        for (int i = 0; i < 60; i++) { // 2s * 60 = 120s
            usleep(2 * 1000 * 1000);
            // Anything newer than launch = the JVM made progress.
            if (pojavLastLogWriteMs() > launchMs) return;
            // Frames advancing = game window is live and rendering.
            if (pojavSwapCount() != lastFrame) return;
        }
        NSLog(@"[JavaLauncher] WATCHDOG: JVM produced no output and no frames "
              @"for 120s after launch — showing crash screen (possible JIT26 brk hang)");
        dispatch_async(dispatch_get_main_queue(), ^{
            [PLLogOutputView handleExitCode:1];
        });
    });
}

// ==================== TouchController Mod Detection ====================
// Mirrors Tools.hasModLibrary (Java): true if the instance ships the mod via
// a jar in mods/ (Fabric/Quilt style) or via Forge-style libraries. Used to
// gate TOUCH_CONTROLLER_PROXY_SOCKET before the JVM snapshots the
// environment (System.getenv() in Java cannot see post-boot setenv()).
static BOOL instanceHasTouchControllerMod(NSString *gameDir) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *modDirs = @[
        [gameDir stringByAppendingPathComponent:@"mods"],
        [gameDir stringByAppendingPathComponent:@".minecraft/mods"]
    ];
    for (NSString *dirPath in modDirs) {
        NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:dirPath error:nil];
        for (NSString *entry in entries) {
            if ([entry rangeOfString:@"touchcontroller" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return YES;
            }
        }
    }
    NSString *librariesDir = [NSString stringWithFormat:@"%s/libraries", getenv("POJAV_HOME")];
    NSArray<NSString *> *libPaths = [fileManager subpathsOfDirectoryAtPath:librariesDir error:nil];
    for (NSString *relPath in libPaths) {
        if ([relPath rangeOfString:@"touchcontroller" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

// ==================== Distant Horizons Native Library Fix ====================
// On iOS, DH mod extracts libzstd-jni_dh-1.5.7-6.dylib to a temp directory,
// but the relocation process invalidates the code signature, causing crash.
// Fix: Pre-extract the library from DH jar, sign it with ad-hoc signature,
// and add its directory to java.library.path

// This function checks if the library exists and is signed; if not, it will
// be handled by the Java side (Tools.java) via extractDhNativeLibraries()
// We just check here and add the path if available.
static void checkAndAddDhNativeLibPath(NSString *versionId) {
    if (!versionId) return;
    
    NSString *extractDir = amethyst_hidden_path(@"dh_natives");
    NSString *targetLibPath = [extractDir stringByAppendingPathComponent:@"libzstd-jni_dh-1.5.7-6.dylib"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:targetLibPath]) {
        dhNativeLibPath = extractDir;
        NSLog(@"[DH Fix] Adding native library path: %@", dhNativeLibPath);
    } else {
        // Will be extracted by Java side before JVM launch
        dhNativeLibPath = extractDir;
        NSLog(@"[DH Fix] Will use native library path: %@ (extraction by Java)", dhNativeLibPath);
    }
}
