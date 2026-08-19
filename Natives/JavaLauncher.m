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
#include <unistd.h>

#include "utils.h"
#include "ZinkConfig.h"

#import "ios_uikit_bridge.h"
#import "JavaLauncher.h"
#import "LauncherPreferences.h"
#import "PLLogOutputView.h"
#import "PLProfiles.h"
#import "VersionDirectoryManager.h"
#import "TouchControllerManager.h"

static NSString *dhNativeLibPath = nil;

// Forward declaration for DH fix
static void checkAndAddDhNativeLibPath(NSString *versionId);

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

// Caps the requested heap so Java + JVM overhead + native GL/Metal buffers
// always fit under the real Jetsam kill allowance. Returns the capped value.
static int capAllocationToJetsamAllowance(int allocmem) {
    if (getEntitlementValue(@"com.apple.private.memorystatus")) {
        // updateJetsamControl() raised the task limit itself, no cap needed.
        return allocmem;
    }
    size_t availableMem = availableMemoryMB();
    if (availableMem > 0) {
        int byAllowance = (int)((double)availableMem * 0.6);
        if (byAllowance < allocmem) {
            NSLog(@"[JavaLauncher] RAM capped: %d MB -> %d MB (only %zu MB left before the Jetsam kill limit; add the memorystatus entitlement to raise it)",
                  allocmem, byAllowance, availableMem);
            return (int)MAX(384, byAllowance);
        }
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
    NSString *fcDir = [NSString stringWithFormat:@"%s/fontconfig", getenv("POJAV_HOME")];
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
    setenv("MVK_CONFIG_LOG_LEVEL", "2", 1);

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

    NSString *mgDirPath = [NSString stringWithFormat:@"%s/MG", getenv("POJAV_HOME")];
    setenv("MG_DIR_PATH", mgDirPath.UTF8String, 1);

    NSMutableDictionary *config = [NSMutableDictionary dictionary];

    // Set safe defaults for compatibility, then let user preferences override
    config[@"enableExtGL43"] = @1;
    config[@"enableExtDirectStateAccess"] = @1;
    config[@"maxGlslCacheSize"] = @128;
    config[@"customGLVersion"] = @0x030100;

    id enableAngle = getPrefObject(@"mobileglues.enable_angle");
    if (enableAngle) config[@"enableANGLE"] = [enableAngle boolValue] ? @1 : @0;

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
        NSString *verStr = [customGlVersion description];
        if ([verStr isEqualToString:@"3.0"]) config[@"customGLVersion"] = @0x030000;
        else if ([verStr isEqualToString:@"3.1"]) config[@"customGLVersion"] = @0x030100;
        else if ([verStr isEqualToString:@"3.2"]) config[@"customGLVersion"] = @0x030200;
        else if ([verStr isEqualToString:@"3.3"]) config[@"customGLVersion"] = @0x030300;
        else if ([verStr isEqualToString:@"4.0"]) config[@"customGLVersion"] = @0x040000;
        else if ([verStr isEqualToString:@"4.1"]) config[@"customGLVersion"] = @0x040100;
        else if ([verStr isEqualToString:@"4.2"]) config[@"customGLVersion"] = @0x040200;
        else if ([verStr isEqualToString:@"4.3"]) config[@"customGLVersion"] = @0x040300;
        else if ([verStr isEqualToString:@"4.4"]) config[@"customGLVersion"] = @0x040400;
        else if ([verStr isEqualToString:@"4.5"]) config[@"customGLVersion"] = @0x040500;
        else if ([verStr isEqualToString:@"4.6"]) config[@"customGLVersion"] = @0x040600;
    }

    id fsr1Setting = getPrefObject(@"mobileglues.fsr1_setting");
    if (fsr1Setting) config[@"fsr1Setting"] = @([fsr1Setting intValue]);

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

    init_loadDefaultEnv();
    init_loadCustomEnv();
    init_loadMobileGluesConfig();

    DeviceGetJITFlags(YES);
    BOOL requiresDebugJITMapping = DeviceNeedsDebugJITMapping();
    BOOL jit26AlwaysAttached = getPrefBool(@"debug.debug_always_attached_jit");
    NSLog(@"[JavaLauncher] JIT flags 0x%X -> requiresDebugJITMapping=%d", (unsigned)DeviceGetJITFlags(NO), requiresDebugJITMapping);
    if (requiresDebugJITMapping) {
        // Keep StikDebug attached through probe, JVM init, and mirror prepare.
        JIT26SetDetachAfterFirstBr(NO);
        JIT26SendJITScript([NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"UniversalJIT26Extension" ofType:@"js"]]);
        // Use the same brk #0xf00d path as patched libjvm (not legacy brk #0x69).
        void *probeMapping = JIT26PrepareRegion(NULL, getpagesize());
        NSLog(@"[JavaLauncher] JIT26 probe returned %p", probeMapping);
        if (!JIT26ProbeLooksValid(probeMapping)) {
            NSString *inBundleScriptPath = [NSBundle.mainBundle pathForResource:@"UniversalJIT26" ofType:@"js"];
            NSString *documentsScriptPath = [NSString stringWithFormat:@"%s/UniversalJIT26.js", getenv("POJAV_HOME")];
            if (inBundleScriptPath) {
                [[NSFileManager defaultManager] removeItemAtPath:documentsScriptPath error:nil];
                [NSFileManager.defaultManager copyItemAtPath:inBundleScriptPath toPath:documentsScriptPath error:nil];
            }
            NSString *lcAppInfoPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"LCAppInfo.plist"];
            NSMutableDictionary *lcAppInfo = [NSMutableDictionary dictionaryWithContentsOfFile:lcAppInfoPath];
            if (lcAppInfo && inBundleScriptPath) {
                lcAppInfo[@"jitLaunchScriptJs"] = [[NSData dataWithContentsOfFile:inBundleScriptPath] base64EncodedStringWithOptions:0];
                if ([lcAppInfo writeToFile:lcAppInfoPath atomically:YES]) {
                    showDialog(localize(@"Error", nil),
                        [NSString stringWithFormat:
                            @"StikDebug probe failed (got %p). Expected a real RX page, not a legacy error code. "
                             @"Witch refreshed UniversalJIT26.js — restart LiveContainer, re-enable JIT, then try again.",
                            probeMapping]);
                    [PLLogOutputView handleExitCode:1];
                    return 1;
                }
            }
            showDialog(localize(@"Error", nil),
                [NSString stringWithFormat:
                    @"StikDebug probe failed (got %p). Your assigned script may be outdated, or StikDebug is below 3.1.6. "
                     @"UniversalJIT26.js was refreshed in Witch Documents — re-assign it in StikDebug (long-press → Assign Script), "
                     @"re-enable JIT, then launch again.",
                    probeMapping]);
            [PLLogOutputView handleExitCode:1];
            return 1;
        }
        JIT26SetDetachAfterFirstBr(!jit26AlwaysAttached);
        init_jit_vm_remap_hook();
        // make sure we don't get stuck in EXC_BAD_ACCESS
        task_set_exception_ports(mach_task_self(), EXC_MASK_BAD_ACCESS, 0, EXCEPTION_DEFAULT, MACHINE_THREAD_STATE);
    }
    if (!requiresDebugJITMapping || jit26AlwaysAttached) {
        if (jit26AlwaysAttached) {
            // Only allow StikDebug to catch our breakpoints to prevent any stutters
            task_set_exception_ports(mach_task_self(), EXC_MASK_ALL & ~EXC_MASK_BREAKPOINT, 0,
                EXCEPTION_DEFAULT, THREAD_STATE_NONE);
        }
        // Activate Library Validation bypass for external runtime and dylibs (JNA, etc)
        init_bypassDyldLibValidation();
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
    NSLog(@"[JavaLauncher] RENDERER is set to %@\n", renderer);
    setenv("AMETHYST_RENDERER", renderer.UTF8String, 1);

    // The TouchController mod (0.3.1-alpha13+) only activates its iOS
    // platform when TOUCH_CONTROLLER_PROXY_SOCKET is set. It must be set
    // BEFORE the JVM starts: the JVM snapshots the environment at boot and
    // later setenv() calls are invisible to System.getenv(). The value is
    // not a real socket path (the transport is an in-process ring buffer),
    // so any non-empty value works; harmless when no mod is installed.
    setenv("TOUCH_CONTROLLER_PROXY_SOCKET", "inproc:touchcontroller", 1);
    NSLog(@"[JavaLauncher] TOUCH_CONTROLLER_PROXY_SOCKET set before JVM launch");

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
        UIKit_returnToSplitView();
        showDialog(localize(@"Error", nil),
            @"The selected Java runtime does not support JIT on this iOS version. "
             "Open Settings and choose a bundled Java 21 or 25 runtime.");
        return 1;
    }

    BOOL needsMirrorJITPrepare = requiresDebugJITMapping && RuntimeSupportsDebugJITMapping(javaHome);
    if (needsMirrorJITPrepare) {
        // Java 21/25 patched runtimes use mirror_w/x on every iOS 26.6+/27 device.
        // StikDebug must stay attached through vm_remap and follow-up prepare calls.
        JIT26SetDetachAfterFirstBr(NO);
        NSLog(@"[JavaLauncher] Mirror-capable runtime: debugger kept attached for JIT prepare");
    } else if (requiresDebugJITMapping && !jit26AlwaysAttached) {
        JIT26SetDetachAfterFirstBr(YES);
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
    if (getPrefBool(@"java.auto_ram")) {
        CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
        allocmem = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
        // Auto sizing is derived from physical RAM, not from the process's
        // Jetsam allowance, so it can over-allocate on sideloaded installs
        // (no memorystatus entitlement) where the kill limit is fixed and
        // low. Keep the allowance cap here to prevent launch-time Jetsam kills.
        allocmem = capAllocationToJetsamAllowance(allocmem);
    } else {
        // Manual allocation: honor the user's setting as-is. The JVM commits
        // heap lazily (ParallelGC), so -Xmx is a ceiling, not a preallocation.
        // Just warn when the requested heap exceeds the actual Jetsam kill
        // allowance so the user knows a memory-heavy session may be killed.
        allocmem = getPrefInt(@"java.allocated_memory");
        if (!getEntitlementValue(@"com.apple.private.memorystatus")) {
            size_t availableMem = availableMemoryMB();
            if (availableMem > 0 && (size_t)allocmem > availableMem) {
                NSLog(@"[JavaLauncher] Warning: requested %d MB heap exceeds the Jetsam kill allowance (~%zu MB); the game may be killed when its memory usage approaches the limit", allocmem, availableMem);
                showDialog(localize(@"Warning", nil),
                    [NSString stringWithFormat:@"You requested %d MB RAM, but the kill limit (Jetsam) of a Sideloaded install is only about %zu MB. Memory above this force-closes the game mid-play. Use Auto RAM or set a value below %zu MB.",
                        allocmem, availableMem, availableMem]);
            }
        }
    }
    NSLog(@"[JavaLauncher] Max RAM allocation is set to %d MB", allocmem);
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
    
    // Add DH native library path if available
    NSString *javaLibraryPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks"];
    NSString *lwjglVersion = [VersionDirectoryManager resolveEffectiveLwjglVersion];
    if ([lwjglVersion isEqualToString:@"3.4.1"]) {
        javaLibraryPath = [NSString stringWithFormat:@"%@:%@",
            [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"libs/lwjgl41_natives"],
            javaLibraryPath];
    } else if ([lwjglVersion isEqualToString:@"3.3.6"]) {
        javaLibraryPath = [NSString stringWithFormat:@"%@:%@",
            [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"libs/lwjgl36_natives"],
            javaLibraryPath];
    } else {
        javaLibraryPath = [NSString stringWithFormat:@"%@:%@",
            [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"libs/lwjgl33_natives"],
            javaLibraryPath];
    }
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
    
    margv[++margc] = [NSString stringWithFormat:@"-Duser.dir=%@", gameDir].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-Duser.home=%s", getenv("POJAV_HOME")].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-Duser.timezone=%@", NSTimeZone.localTimeZone.name].UTF8String;
    margv[++margc] = [NSString stringWithFormat:@"-DUIScreen.maximumFramesPerSecond=%d", (int)UIScreen.mainScreen.maximumFramesPerSecond].UTF8String;
    margv[++margc] = "-Dorg.lwjgl.glfw.checkThread0=false";
    margv[++margc] = "-Dorg.lwjgl.system.allocator=system";
    //margv[++margc] = "-Dorg.lwjgl.util.NoChecks=true";
    margv[++margc] = "-Dlog4j2.formatMsgNoLookups=true";
    // Voxy on iOS: cap geometry buffer at 256MB (iPhone 8 has 2GB RAM; Voxy
    // defaults to a 3.7GB SSBO allocation which fails with GL_OUT_OF_MEMORY)
    margv[++margc] = "-Dvoxy.geometryBufferSizeOverrideMB=256";

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
        const char *openglLibName = (strcmp(glLibName, RENDERER_NAME_MOLTENVK) == 0)
            ? RENDERER_NAME_MOBILEGLUES
            : glLibName;
        margv[++margc] = [NSString stringWithFormat:@"-Dorg.lwjgl.opengl.libname=%s", openglLibName].UTF8String;
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
    if(getPrefBool(@"general.cosmetica")) {
        margv[++margc] = [NSString stringWithFormat:@"-javaagent:%@/arc_dns_injector.jar=23.95.137.176", librariesPath].UTF8String;
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

    // On iOS 26+, use mirror mapped JIT for better code cache performance.
    // The patched runtimes interpret -XX:+MirrorMappedCodeCache as permission
    // to request the debugger-backed RX mapping. Only enable it after the
    // Universal JIT script has been selected for a device that cannot create
    // RX mappings (JIT_FLAG_FORCE_MIRRORED), regardless of TXM presence, since
    // iOS 26.6+/27 blocks direct executable mappings on every device.
    // Patched Java 21/25 always route code-cache writes through mirror_w on iOS 26+,
    // including iOS 27. Turning MirrorMappedCodeCache off does not disable mirror
    // usage — it only skips the debugger-backed RX prepare and SIGBUSes in
    // StubRoutines::call_stub during JVM init. Override with
    // debug.debug_mirror_mapped_code_cache: -1 = auto, 0 = off, 1 = on.
    BOOL mirrorEnabled;
    id mirrorOverrideObj = getPrefObject(@"debug.debug_mirror_mapped_code_cache");
    NSInteger mirrorOverride = mirrorOverrideObj ? [mirrorOverrideObj integerValue] : -1;
    if (mirrorOverride >= 0) {
        mirrorEnabled = mirrorOverride > 0;
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache override set to %s", mirrorEnabled ? "ON" : "OFF");
    } else if (@available(iOS 26.0, *)) {
        mirrorEnabled = needsMirrorJITPrepare;
    } else {
        mirrorEnabled = NO;
    }
    if (mirrorEnabled) {
        margv[++margc] = "-XX:+MirrorMappedCodeCache";
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache enabled on iOS %ld.%ld", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, (long)NSProcessInfo.processInfo.operatingSystemVersion.minorVersion);
    } else {
        NSLog(@"[JavaLauncher] MirrorMappedCodeCache disabled on iOS %ld.%ld (classic JIT26 path)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, (long)NSProcessInfo.processInfo.operatingSystemVersion.minorVersion);
    }

    // Disable Forge 1.16.x early progress window
    margv[++margc] = "-Dfml.earlyprogresswindow=false";

    // JNA on iOS must load libjnidispatch from jna.boot.library.path
    // (jna.nosys=true), so pre-copy the bundled 5.13.0 dylib into jna_tmp.
    // POJAV_HOME/jna_tmp is what PojavLauncher.main points jna.boot.library.path at.
    NSString *jnaTmpDir = [NSString stringWithFormat:@"%s/jna_tmp", getenv("POJAV_HOME")];
    [fm createDirectoryAtPath:jnaTmpDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *jnidispatchSrc = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/libjnidispatch.dylib"];
    NSString *jnidispatchDst = [jnaTmpDir stringByAppendingPathComponent:@"libjnidispatch.dylib"];
    if ([fm fileExistsAtPath:jnidispatchSrc] && ![fm fileExistsAtPath:jnidispatchDst]) {
        NSLog(@"[JavaLauncher] Copying libjnidispatch.dylib to %@", jnidispatchDst);
        [fm copyItemAtPath:jnidispatchSrc toPath:jnidispatchDst error:nil];
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
    if (requiresDebugJITMapping) {
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
        verify_libjvm_mirror_brk_patch();
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
    NSString *lwjglJarPath;
    if ([lwjglVersion isEqualToString:@"3.4.1"]) {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl41"];
        lwjglJarPath = [lwjglDirPath stringByAppendingPathComponent:@"lwjgl.jar"];
    } else if ([lwjglVersion isEqualToString:@"3.3.6"]) {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl36"];
        lwjglJarPath = [lwjglDirPath stringByAppendingPathComponent:@"lwjgl.jar"];
    } else {
        lwjglDirPath = [librariesPath stringByAppendingPathComponent:@"lwjgl33"];
        lwjglJarPath = [lwjglDirPath stringByAppendingPathComponent:@"lwjgl.jar"];
    }
    setenv("LWJGL_VERSION", lwjglVersion.UTF8String, 1);

    NSString *classpath = [NSString stringWithFormat:@"%@/*:%@/*:%@", librariesPath, lwjglDirPath, lwjglJarPath];
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

    // 26.x (SDL3 windowing / RenderPearl) refuses SDL_Init until
    // SDL_SetMainReady() runs; pojavInit (GLFW games only) never fires on the
    // SDL path, so prime the flag here for every launch. dlopen the SAME
    // natives dir the game will resolve via org.lwjgl.librarypath so dyld
    // reuses one SDL instance (a different copy would ignore the flag).
    aasdl_setMainReady([javaLibraryPath componentsSeparatedByString:@":"].firstObject.lastPathComponent);

    if (needsMirrorJITPrepare) {
        // Mirror setup needs prepare_memory_region on RX *and* RW after vm_remap.
        // StikDebug must stay attached through those extra brk calls.
        JIT26SetDetachAfterFirstBr(NO);
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

    return pJLI_Launch(++margc, margv,
                   0, NULL, // sizeof(const_jargs) / sizeof(char *), const_jargs,
                   0, NULL, // sizeof(const_appclasspath) / sizeof(char *), const_appclasspath,
                   // These values are ignored in Java 17, so keep it anyways
                   "1.8.0-internal",
                   "1.8",

                   "java", "openjdk",
                   /* (const_jargs != NULL) ? JNI_TRUE : */ JNI_FALSE,
                   JNI_TRUE, JNI_FALSE, JNI_TRUE);
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
    
    NSString *extractDir = [NSString stringWithFormat:@"%s/dh_natives", getenv("POJAV_HOME")];
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
