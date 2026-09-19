#import "MobileGLConfig.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "utils.h"

NSString *const MobileGLPrefSection = @"mobilegl";

@implementation MobileGLConfig

+ (BOOL)isMobileGLRendererSelected {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    return [renderer isEqualToString:@ RENDERER_NAME_MOBILEGL];
}

+ (MobileGLBackendType)selectedBackendType {
    id backendType = getPrefObject(@"mobilegl.backend_type");
    if (backendType && [backendType isKindOfClass:[NSString class]]) {
        NSString *bt = (NSString *)backendType;
        if ([bt isEqualToString:@"DirectGLES"]) {
            return MobileGLBackendTypeDirectGLES;
        }
    }
    return MobileGLBackendTypeDirectVulkan;
}

+ (MobileGLAngleBackend)selectedAngleBackend {
    id angleBackend = getPrefObject(@"mobilegl.angle_backend");
    if (angleBackend && [angleBackend isKindOfClass:[NSString class]]) {
        NSString *ab = (NSString *)angleBackend;
        if ([ab isEqualToString:@"metal"]) {
            return MobileGLAngleBackendMetal;
        }
    }
    return MobileGLAngleBackendVulkan;
}

+ (void)applyEnvironmentFromPreferences {
    // Backend type (DirectVulkan or DirectGLES)
    MobileGLBackendType backendType = [self selectedBackendType];
    switch (backendType) {
        case MobileGLBackendTypeDirectGLES:
            setenv("MOBILEGL_BACKEND_TYPE", "DirectGLES", 1);
            break;
        default:
            setenv("MOBILEGL_BACKEND_TYPE", "DirectVulkan", 1);
            break;
    }

    // ANGLE backend (only relevant when DirectGLES is selected)
    MobileGLAngleBackend angleBackend = [self selectedAngleBackend];
    switch (angleBackend) {
        case MobileGLAngleBackendMetal:
            setenv("MOBILEGL_ANGLE_BACKEND", "metal", 1);
            break;
        default:
            setenv("MOBILEGL_ANGLE_BACKEND", "vulkan", 1);
            break;
    }

    id disableTimerQuery = getPrefObject(@"mobilegl.disable_timer_query");
    setenv("MOBILEGL_DISABLE_TIMERQUERY", [disableTimerQuery boolValue] ? "1" : "0", 1);

    id disableSubgroup = getPrefObject(@"mobilegl.disable_subgroup");
    setenv("MOBILEGL_MAGMA_DISABLE_SUBGROUP", [disableSubgroup boolValue] ? "1" : "0", 1);

    id advertiseFP64 = getPrefObject(@"mobilegl.advertise_fp64");
    setenv("MOBILEGL_ADVERTISE_FP64", [advertiseFP64 boolValue] ? "1" : "0", 1);

    id framesInFlight = getPrefObject(@"mobilegl.frames_in_flight");
    char framesStr[16];
    snprintf(framesStr, sizeof(framesStr), "%d", framesInFlight ? (int)[framesInFlight integerValue] : 3);
    setenv("MOBILEGL_MAGMA_FRAMESINFLIGHT", framesStr, 1);

    id vmaBlockSize = getPrefObject(@"mobilegl.vma_block_size");
    char vmaStr[16];
    snprintf(vmaStr, sizeof(vmaStr), "%d", vmaBlockSize ? (int)[vmaBlockSize integerValue] : 32);
    setenv("MOBILEGL_MAGMA_VMA_BLOCK_SIZE_MB", vmaStr, 1);

    id largeBufferAdopt = getPrefObject(@"mobilegl.large_buffer_adopt_size");
    char adoptStr[16];
    snprintf(adoptStr, sizeof(adoptStr), "%d", largeBufferAdopt ? (int)[largeBufferAdopt integerValue] : 4);
    setenv("MOBILEGL_LARGE_BUFFER_ADOPT_MB", adoptStr, 1);

    id coherentAsFlush = getPrefObject(@"mobilegl.coherent_as_flush");
    setenv("MOBILEGL_COHERENT_AS_FLUSH", [coherentAsFlush boolValue] ? "1" : "0", 1);

    id asyncShader = getPrefObject(@"mobilegl.async_shader_compile");
    switch (asyncShader ? [asyncShader integerValue] : MobileGLAsyncShaderCompileAuto) {
        case MobileGLAsyncShaderCompileOn:
            setenv("MOBILEGL_ASYNC_SHADER_COMPILE", "On", 1);
            break;
        case MobileGLAsyncShaderCompileOff:
            setenv("MOBILEGL_ASYNC_SHADER_COMPILE", "Off", 1);
            break;
        default:
            setenv("MOBILEGL_ASYNC_SHADER_COMPILE", "Auto", 1);
            break;
    }

    id shaderCache = getPrefObject(@"mobilegl.shader_cache");
    switch (shaderCache ? [shaderCache integerValue] : MobileGLShaderCacheAuto) {
        case MobileGLShaderCacheOn:
            setenv("MOBILEGL_SHADER_CACHE", "On", 1);
            break;
        case MobileGLShaderCacheOff:
            setenv("MOBILEGL_SHADER_CACHE", "Off", 1);
            break;
        default:
            setenv("MOBILEGL_SHADER_CACHE", "Auto", 1);
            break;
    }

    id r11g11b10f = getPrefObject(@"mobilegl.r11g11b10f_fallback");
    setenv("MOBILEGL_MAGMA_R11G11B10F_FALLBACK", [r11g11b10f boolValue] ? "1" : "0", 1);

    NSLog(@"[MobileGLConfig] Applied config: backend=%s angle=%s timerQ=%s subgroup=%s fp64=%s frames=%s vmaBlock=%sMB adoptThreshold=%sMB coherent=%s async=%s cache=%s r11g11b10f=%s",
        getenv("MOBILEGL_BACKEND_TYPE"),
        getenv("MOBILEGL_ANGLE_BACKEND"),
        getenv("MOBILEGL_DISABLE_TIMERQUERY"),
        getenv("MOBILEGL_MAGMA_DISABLE_SUBGROUP"),
        getenv("MOBILEGL_ADVERTISE_FP64"),
        getenv("MOBILEGL_MAGMA_FRAMESINFLIGHT"),
        getenv("MOBILEGL_MAGMA_VMA_BLOCK_SIZE_MB"),
        getenv("MOBILEGL_LARGE_BUFFER_ADOPT_MB"),
        getenv("MOBILEGL_COHERENT_AS_FLUSH"),
        getenv("MOBILEGL_ASYNC_SHADER_COMPILE"),
        getenv("MOBILEGL_SHADER_CACHE"),
        getenv("MOBILEGL_MAGMA_R11G11B10F_FALLBACK"));
}

+ (NSString *)activeConfigSummary {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];

    MobileGLBackendType backendType = [self selectedBackendType];
    NSString *backend = (backendType == MobileGLBackendTypeDirectGLES) ? @"DirectGLES" : @"DirectVulkan";

    MobileGLAngleBackend angleBackend = [self selectedAngleBackend];
    NSString *angleStr = (angleBackend == MobileGLAngleBackendMetal) ? @"MetalANGLE" : @"VulkanANGLE";

    id disableTimerQuery = getPrefObject(@"mobilegl.disable_timer_query");
    NSString *timerQ = disableTimerQuery ? ([disableTimerQuery boolValue] ? @"YES" : @"NO") : @"NO";

    id disableSubgroup = getPrefObject(@"mobilegl.disable_subgroup");
    NSString *subgroup = disableSubgroup ? ([disableSubgroup boolValue] ? @"YES" : @"NO") : @"NO";

    id advertiseFP64 = getPrefObject(@"mobilegl.advertise_fp64");
    NSString *fp64 = advertiseFP64 ? ([advertiseFP64 boolValue] ? @"YES" : @"NO") : @"NO";

    id framesInFlight = getPrefObject(@"mobilegl.frames_in_flight");
    NSString *frames = framesInFlight ? [NSString stringWithFormat:@"%ld", (long)[framesInFlight integerValue]] : @"3";

    id vmaBlockSize = getPrefObject(@"mobilegl.vma_block_size");
    NSString *vmaBlock = vmaBlockSize ? [NSString stringWithFormat:@"%ldMB", (long)[vmaBlockSize integerValue]] : @"32MB";

    id largeBufferAdopt = getPrefObject(@"mobilegl.large_buffer_adopt_size");
    NSString *adoptThreshold = largeBufferAdopt ? [NSString stringWithFormat:@"%ldMB", (long)[largeBufferAdopt integerValue]] : @"4MB";

    id coherentAsFlush = getPrefObject(@"mobilegl.coherent_as_flush");
    NSString *coherent = coherentAsFlush ? ([coherentAsFlush boolValue] ? @"YES" : @"NO") : @"NO";

    id asyncShader = getPrefObject(@"mobilegl.async_shader_compile");
    NSString *asyncStr;
    switch (asyncShader ? [asyncShader integerValue] : MobileGLAsyncShaderCompileAuto) {
        case MobileGLAsyncShaderCompileOn: asyncStr = @"On"; break;
        case MobileGLAsyncShaderCompileOff: asyncStr = @"Off"; break;
        default: asyncStr = @"Auto"; break;
    }

    id shaderCache = getPrefObject(@"mobilegl.shader_cache");
    NSString *cacheStr;
    switch (shaderCache ? [shaderCache integerValue] : MobileGLShaderCacheAuto) {
        case MobileGLShaderCacheOn: cacheStr = @"On"; break;
        case MobileGLShaderCacheOff: cacheStr = @"Off"; break;
        default: cacheStr = @"Auto"; break;
    }

    id r11g11b10f = getPrefObject(@"mobilegl.r11g11b10f_fallback");
    NSString *r11 = r11g11b10f ? ([r11g11b10f boolValue] ? @"YES" : @"NO") : @"NO";

    return [NSString stringWithFormat:
        @"[MobileGL Config]\n"
        @"Renderer: %@\n"
        @"Backend: %@\n"
        @"ANGLE Backend: %@\n"
        @"Timer Query: %@ / Subgroup: %@\n"
        @"FP64: %@ / Frames in Flight: %@\n"
        @"VMA Block: %@ / Buffer Adopt Threshold: %@\n"
        @"Coherent: %@ / Async: %@ / Cache: %@\n"
        @"R11G11B10F: %@",
        renderer, backend, angleStr,
        timerQ, subgroup,
        fp64, frames,
        vmaBlock, adoptThreshold,
        coherent, asyncStr, cacheStr,
        r11];
}

@end
