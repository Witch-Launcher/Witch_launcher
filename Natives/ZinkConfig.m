#import "ZinkConfig.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "utils.h"

#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

NSString *const ZinkPrefSection = @"zink";
static AppleGPUGeneration _cachedGPUGeneration = AppleGPUGenerationUnknown;

@implementation ZinkConfig

#pragma mark - Device Detection

+ (AppleGPUGeneration)deviceGPUGeneration {
    if (_cachedGPUGeneration != AppleGPUGenerationUnknown) {
        return _cachedGPUGeneration;
    }

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithUTF8String:systemInfo.machine];

    NSDictionary *deviceMap = @{
        @"iPhone8,1": @(AppleGPUGenerationA9),
        @"iPhone8,2": @(AppleGPUGenerationA9),
        @"iPhone8,4": @(AppleGPUGenerationA9),
        @"iPhone9,1": @(AppleGPUGenerationA10),
        @"iPhone9,2": @(AppleGPUGenerationA10),
        @"iPhone9,3": @(AppleGPUGenerationA10),
        @"iPhone9,4": @(AppleGPUGenerationA10),
        @"iPhone10,1": @(AppleGPUGenerationA11),
        @"iPhone10,2": @(AppleGPUGenerationA11),
        @"iPhone10,3": @(AppleGPUGenerationA11),
        @"iPhone10,4": @(AppleGPUGenerationA11),
        @"iPhone10,5": @(AppleGPUGenerationA11),
        @"iPhone10,6": @(AppleGPUGenerationA11),
        @"iPhone11,2": @(AppleGPUGenerationA12),
        @"iPhone11,4": @(AppleGPUGenerationA12),
        @"iPhone11,6": @(AppleGPUGenerationA12),
        @"iPhone11,8": @(AppleGPUGenerationA12),
        @"iPhone12,1": @(AppleGPUGenerationA13),
        @"iPhone12,3": @(AppleGPUGenerationA13),
        @"iPhone12,5": @(AppleGPUGenerationA13),
        @"iPhone12,8": @(AppleGPUGenerationA13),
        @"iPhone13,1": @(AppleGPUGenerationA14),
        @"iPhone13,2": @(AppleGPUGenerationA14),
        @"iPhone13,3": @(AppleGPUGenerationA14),
        @"iPhone13,4": @(AppleGPUGenerationA14),
        @"iPhone14,2": @(AppleGPUGenerationA15),
        @"iPhone14,3": @(AppleGPUGenerationA15),
        @"iPhone14,4": @(AppleGPUGenerationA15),
        @"iPhone14,5": @(AppleGPUGenerationA15),
        @"iPhone14,6": @(AppleGPUGenerationA15),
        @"iPhone14,7": @(AppleGPUGenerationA15),
        @"iPhone14,8": @(AppleGPUGenerationA15),
        @"iPhone15,2": @(AppleGPUGenerationA16),
        @"iPhone15,3": @(AppleGPUGenerationA16),
        @"iPhone15,4": @(AppleGPUGenerationA16),
        @"iPhone15,5": @(AppleGPUGenerationA16),
        @"iPhone16,1": @(AppleGPUGenerationA17),
        @"iPhone16,2": @(AppleGPUGenerationA17),
        @"iPhone17,1": @(AppleGPUGenerationA18),
        @"iPhone17,2": @(AppleGPUGenerationA18),
        @"iPhone17,3": @(AppleGPUGenerationA18),
        @"iPhone17,4": @(AppleGPUGenerationA18),
        @"iPhone18,1": @(AppleGPUGenerationA19),
        @"iPhone18,2": @(AppleGPUGenerationA19),
        @"iPhone18,3": @(AppleGPUGenerationA19),
        @"iPhone18,4": @(AppleGPUGenerationA19),

        @"iPad6,11": @(AppleGPUGenerationA9),
        @"iPad6,12": @(AppleGPUGenerationA9),
        @"iPad7,5": @(AppleGPUGenerationA10),
        @"iPad7,6": @(AppleGPUGenerationA10),
        @"iPad8,1": @(AppleGPUGenerationA12),
        @"iPad8,2": @(AppleGPUGenerationA12),
        @"iPad8,3": @(AppleGPUGenerationA12),
        @"iPad8,4": @(AppleGPUGenerationA12),
        @"iPad8,5": @(AppleGPUGenerationA12),
        @"iPad8,6": @(AppleGPUGenerationA12),
        @"iPad8,7": @(AppleGPUGenerationA12),
        @"iPad8,8": @(AppleGPUGenerationA12),
        @"iPad11,1": @(AppleGPUGenerationA12),
        @"iPad11,2": @(AppleGPUGenerationA12),
        @"iPad11,3": @(AppleGPUGenerationA12),
        @"iPad11,4": @(AppleGPUGenerationA12),
        @"iPad11,6": @(AppleGPUGenerationA12),
        @"iPad11,7": @(AppleGPUGenerationA12),
        @"iPad13,1": @(AppleGPUGenerationM1),
        @"iPad13,2": @(AppleGPUGenerationM1),
        @"iPad13,4": @(AppleGPUGenerationM1),
        @"iPad13,5": @(AppleGPUGenerationM1),
        @"iPad13,6": @(AppleGPUGenerationM1),
        @"iPad13,7": @(AppleGPUGenerationM1),
        @"iPad13,8": @(AppleGPUGenerationM1),
        @"iPad13,9": @(AppleGPUGenerationM1),
        @"iPad13,10": @(AppleGPUGenerationM1),
        @"iPad13,11": @(AppleGPUGenerationM1),
        @"iPad13,16": @(AppleGPUGenerationM1),
        @"iPad13,17": @(AppleGPUGenerationM1),
        @"iPad13,18": @(AppleGPUGenerationM1),
        @"iPad13,19": @(AppleGPUGenerationM1),
        @"iPad14,1": @(AppleGPUGenerationA14),
        @"iPad14,2": @(AppleGPUGenerationA14),
        @"iPad14,3": @(AppleGPUGenerationM2),
        @"iPad14,4": @(AppleGPUGenerationM2),
        @"iPad14,5": @(AppleGPUGenerationA15),
        @"iPad14,6": @(AppleGPUGenerationA15),
        @"iPad16,1": @(AppleGPUGenerationM4),
        @"iPad16,2": @(AppleGPUGenerationM4),
        @"iPad16,3": @(AppleGPUGenerationM4),
        @"iPad16,4": @(AppleGPUGenerationM4),
        @"iPad16,5": @(AppleGPUGenerationM5),
        @"iPad16,6": @(AppleGPUGenerationM5),
    };

    NSNumber *genNum = deviceMap[machine];
    if (genNum) {
        _cachedGPUGeneration = (AppleGPUGeneration)[genNum integerValue];
    } else {
        NSString *model = UIDevice.currentDevice.model;
        if ([model containsString:@"iPad"]) {
            if ([machine containsString:@"iPad8"] || [machine containsString:@"iPad13"]) {
                _cachedGPUGeneration = AppleGPUGenerationM1;
            } else if ([machine containsString:@"iPad14"]) {
                if ([[machine substringFromIndex:7] intValue] >= 3) {
                    _cachedGPUGeneration = AppleGPUGenerationM2;
                } else {
                    _cachedGPUGeneration = AppleGPUGenerationA14;
                }
            } else if ([machine containsString:@"iPad16"]) {
                if ([[machine substringFromIndex:7] intValue] >= 5) {
                    _cachedGPUGeneration = AppleGPUGenerationM5;
                } else {
                    _cachedGPUGeneration = AppleGPUGenerationM4;
                }
            } else {
                _cachedGPUGeneration = AppleGPUGenerationA12;
            }
        } else {
            _cachedGPUGeneration = AppleGPUGenerationA14;
        }
    }
    return _cachedGPUGeneration;
}

+ (NSString *)deviceGPUGenerationName {
    switch ([self deviceGPUGeneration]) {
        case AppleGPUGenerationA9:  return @"A9";
        case AppleGPUGenerationA10: return @"A10";
        case AppleGPUGenerationA11: return @"A11";
        case AppleGPUGenerationA12: return @"A12";
        case AppleGPUGenerationA13: return @"A13";
        case AppleGPUGenerationA14: return @"A14";
        case AppleGPUGenerationA15: return @"A15";
        case AppleGPUGenerationA16: return @"A16";
        case AppleGPUGenerationA17: return @"A17 Pro";
        case AppleGPUGenerationA18: return @"A18";
        case AppleGPUGenerationA19: return @"A19 Pro";
        case AppleGPUGenerationM1:  return @"M1";  return @"M1";
        case AppleGPUGenerationM2:  return @"M2";
        case AppleGPUGenerationM3:  return @"M3";
        case AppleGPUGenerationM4:  return @"M4";
        case AppleGPUGenerationM5:  return @"M5";
        default: return @"Unknown";
    }
}

#pragma mark - API Support

+ (ZinkAPIFeatures)supportedAPIFeaturesForGPUGeneration:(AppleGPUGeneration)gen {
    ZinkAPIFeatures features = ZinkAPIFeatureNone;

    features |= ZinkAPIFeatureTextureAnisotropic;

    switch (gen) {
        case AppleGPUGenerationA9:
        case AppleGPUGenerationA10:
            features |= ZinkAPIFeatureTessellationShader;
            features |= ZinkAPIFeatureGeometryShader;
            break;

        case AppleGPUGenerationA11:
            features |= ZinkAPIFeatureTessellationShader;
            features |= ZinkAPIFeatureGeometryShader;
            features |= ZinkAPIFeatureComputeShader;
            features |= ZinkAPIFeatureMultiDrawIndirect;
            break;

        case AppleGPUGenerationA12:
        case AppleGPUGenerationA13:
            features |= ZinkAPIFeatureTessellationShader;
            features |= ZinkAPIFeatureGeometryShader;
            features |= ZinkAPIFeatureComputeShader;
            features |= ZinkAPIFeatureMultiDrawIndirect;
            features |= ZinkAPIFeatureDirectStateAccess;
            break;

        case AppleGPUGenerationA14:
        case AppleGPUGenerationA15:
        case AppleGPUGenerationA16:
            features |= ZinkAPIFeatureTessellationShader;
            features |= ZinkAPIFeatureGeometryShader;
            features |= ZinkAPIFeatureComputeShader;
            features |= ZinkAPIFeatureMultiDrawIndirect;
            features |= ZinkAPIFeatureDirectStateAccess;
            break;

        case AppleGPUGenerationA17:
        case AppleGPUGenerationA18:
        case AppleGPUGenerationA19:
        case AppleGPUGenerationM1:
        case AppleGPUGenerationM2:
        case AppleGPUGenerationM3:
        case AppleGPUGenerationM4:
        case AppleGPUGenerationM5:
            features |= ZinkAPIFeatureTessellationShader;
            features |= ZinkAPIFeatureGeometryShader;
            features |= ZinkAPIFeatureComputeShader;
            features |= ZinkAPIFeatureMultiDrawIndirect;
            features |= ZinkAPIFeatureDirectStateAccess;
            break;

        default:
            features |= ZinkAPIFeatureDirectStateAccess;
            break;
    }

    return features;
}

+ (ZinkAPIFeatures)supportedAPIFeatures {
    return [self supportedAPIFeaturesForGPUGeneration:[self deviceGPUGeneration]];
}

#pragma mark - Optimization Level

+ (ZinkOptimizationLevel)recommendedOptimizationLevel {
    AppleGPUGeneration gen = [self deviceGPUGeneration];
    switch (gen) {
        case AppleGPUGenerationA9:
        case AppleGPUGenerationA10:
            return ZinkOptimizationLevelLow;
        case AppleGPUGenerationA11:
            return ZinkOptimizationLevelMedium;
        case AppleGPUGenerationA12:
        case AppleGPUGenerationA13:
            return ZinkOptimizationLevelMedium;
        case AppleGPUGenerationA14:
            return ZinkOptimizationLevelHigh;
        case AppleGPUGenerationA15:
        case AppleGPUGenerationA16:
        case AppleGPUGenerationA17:
        case AppleGPUGenerationA18:
        case AppleGPUGenerationA19:
        case AppleGPUGenerationM1:
        case AppleGPUGenerationM2:
        case AppleGPUGenerationM3:
        case AppleGPUGenerationM4:
        case AppleGPUGenerationM5:
            return ZinkOptimizationLevelUltra;
        default:
            return ZinkOptimizationLevelMedium;
    }
}

+ (BOOL)isZinkRenderSelected {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    return [renderer hasPrefix:@"libOSMesa"];
}

+ (NSString *)selectedMesaVersion {
    id ver = getPrefObject(@"zink.mesa_version");
    if (ver && [ver isKindOfClass:[NSString class]]) {
        NSString *v = (NSString *)ver;
        if ([v isEqualToString:@"25.0.7"] || [v isEqualToString:@"26.2.2"]) {
            NSLog(@"[ZinkConfig] selectedMesaVersion: preference = %@", v);
            return v;
        }
    }
    NSLog(@"[ZinkConfig] selectedMesaVersion: default = 26.2.2");
    return @"26.2.2";
}

+ (NSString *)zinkLibraryName {
    NSString *ver = [self selectedMesaVersion];
    if ([ver isEqualToString:@"25.0.7"]) {
        NSLog(@"[ZinkConfig] zinkLibraryName: libOSMesa.8.dylib (OSMesa backend)");
        return @"libOSMesa.8.dylib";
    }
    NSLog(@"[ZinkConfig] zinkLibraryName: libEGL_Mesa26.dylib (EGL backend)");
    return @"libEGL_Mesa26.dylib";
}

+ (BOOL)isZinkUsingEGL {
    NSString *ver = [self selectedMesaVersion];
    BOOL result = [ver isEqualToString:@"26.2.2"];
    NSLog(@"[ZinkConfig] isZinkUsingEGL: %@ → %@", ver, result ? @"YES (EGL)" : @"NO (OSMesa)");
    return result;
}

#pragma mark - KosmicKrisp Support Detection

+ (BOOL)deviceSupportsKosmicKrisp {
    static int cached = -1; // -1=unknown, 0=no, 1=yes
    if (cached >= 0) return cached == 1;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"[ZinkConfig] KosmicKrisp: No Metal device found");
        cached = 0;
        return NO;
    }

    // KosmicKrisp minimum: A13/Apple6 (image atomics + Vulkan Memory Model + Arg Buffers Tier 2)
    BOOL supported = NO;
    if ([device respondsToSelector:@selector(supportsFamily:)]) {
        supported = [device supportsFamily:MTLGPUFamilyApple6];
    }

    NSLog(@"[ZinkConfig] KosmicKrisp support: %@ (device=%@)",
          supported ? @"YES" : @"NO", device.name);
    cached = supported ? 1 : 0;
    return supported;
}

+ (BOOL)deviceSupportsKosmicKrispFull {
    static int cached = -1;
    if (cached >= 0) return cached == 1;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) { cached = 0; return NO; }

    // Full KosmicKrisp (Vulkan 1.4): A14+/Apple7+ (Metal 4)
    BOOL supported = NO;
    if ([device respondsToSelector:@selector(supportsFamily:)]) {
        supported = [device supportsFamily:MTLGPUFamilyApple7];
    }

    NSLog(@"[ZinkConfig] KosmicKrisp Full (VK 1.4): %@ (device=%@)",
          supported ? @"YES" : @"NO", device.name);
    cached = supported ? 1 : 0;
    return supported;
}

+ (BOOL)deviceSupportsKosmicKrispReduced {
    // A13 only (Apple6): KosmicKrisp with reduced Vulkan 1.2
    return [self deviceSupportsKosmicKrisp] && ![self deviceSupportsKosmicKrispFull];
}

+ (ZinkVulkanBackend)selectedVulkanBackend {
    id raw = getPrefObject(@"zink.vulkan_backend");
    if (raw && [raw isKindOfClass:[NSNumber class]]) {
        NSInteger val = [raw integerValue];
        if (val >= ZinkVulkanBackendAuto && val <= ZinkVulkanBackendKosmicKrisp) {
            return (ZinkVulkanBackend)val;
        }
    }
    return ZinkVulkanBackendAuto;
}

+ (NSString *)vulkanBackendName {
    switch ([self selectedVulkanBackend]) {
        case ZinkVulkanBackendMoltenVK:    return @"MoltenVK";
        case ZinkVulkanBackendKosmicKrisp: return @"KosmicKrisp";
        case ZinkVulkanBackendAuto:
        default: {
            if ([self deviceSupportsKosmicKrisp]) return @"KosmicKrisp (auto)";
            return @"MoltenVK (auto)";
        }
    }
}

#pragma mark - Environment Setup

+ (void)applyZinkEnvironmentForOptimizationLevel:(ZinkOptimizationLevel)level {
    if (level == ZinkOptimizationLevelAuto) {
        level = [self recommendedOptimizationLevel];
    }

    // GL 4.1 / GLSL 410 is used for Minecraft 1.21.4+'s core shader pipeline
    // which relies on GL_ARB_separate_shader_objects (glCreateShaderProgramv)
    // introduced in GL 4.1. Minecraft 1.17–1.21 also works at 4.1 without issue.
    // GL_ARB_shader_draw_parameters is force-enabled via MESA_EXTENSION_OVERRIDE
    // since Mesa 21.0.0 Zink does not expose it by default on Metal/MoltenVK.
    // If compatibility issues arise, users can set zink.gl_override to 3.3 or 4.0.
    NSString *extOverrides = @"";
    BOOL enableGLThread = YES;
    int glslCacheSize = 32;

    ZinkAPIFeatures supported = [self supportedAPIFeatures];

    switch (level) {
        case ZinkOptimizationLevelOff:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~ZinkAPIFeatureTransformFeedback];
            glslCacheSize = 128;
            enableGLThread = YES;
            break;

        case ZinkOptimizationLevelSafe:
            extOverrides = [self extensionDisableStringForLevel:ZinkAPIFeatureNone];
            glslCacheSize = 16;
            enableGLThread = NO;
            break;

        case ZinkOptimizationLevelLow:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~(ZinkAPIFeatureTransformFeedback |
                                          ZinkAPIFeatureComputeShader |
                                          ZinkAPIFeatureDirectStateAccess)];
            glslCacheSize = 32;
            break;

        case ZinkOptimizationLevelMedium:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~(ZinkAPIFeatureTransformFeedback |
                                          ZinkAPIFeatureComputeShader)];
            glslCacheSize = 64;
            break;

        case ZinkOptimizationLevelHigh:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~ZinkAPIFeatureTransformFeedback];
            glslCacheSize = 128;
            break;

        case ZinkOptimizationLevelUltra:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~ZinkAPIFeatureTransformFeedback];
            glslCacheSize = 256;
            break;

        default:
            extOverrides = [self extensionDisableStringForLevel:
                            supported & ~ZinkAPIFeatureTransformFeedback];
            break;
    }

    setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);
    setenv("MESA_GLSL_VERSION_OVERRIDE", "410", 1);

    if (extOverrides.length > 0) {
        setenv("MESA_EXTENSION_OVERRIDE", extOverrides.UTF8String, 1);
    } else {
        unsetenv("MESA_EXTENSION_OVERRIDE");
    }

    if (enableGLThread) {
        setenv("mesa_glthread", "true", 1);
    } else {
        setenv("mesa_glthread", "false", 1);
    }

    char cacheSizeStr[16];
    snprintf(cacheSizeStr, sizeof(cacheSizeStr), "%d", glslCacheSize);
    setenv("MESA_GLSL_CACHE_MAX_SIZE", cacheSizeStr, 1);
}

+ (void)applyZinkAPIFeatureOverride:(ZinkAPIFeatures)enabledFeatures {
    setenv("MESA_EXTENSION_OVERRIDE",
        [self extensionDisableStringForLevel:enabledFeatures].UTF8String, 1);
}

+ (NSString *)activeConfigSummary {
    AppleGPUGeneration gen = [self deviceGPUGeneration];
    NSString *genName = [self deviceGPUGenerationName];

    id rawLevel = getPrefObject(@"zink.optimization_level");
    ZinkOptimizationLevel level = ZinkOptimizationLevelAuto;
    if (rawLevel) {
        level = (ZinkOptimizationLevel)[rawLevel integerValue];
        if (level < ZinkOptimizationLevelOff || level > ZinkOptimizationLevelUltra) {
            level = ZinkOptimizationLevelAuto;
        }
    }

    NSString *levelName;
    switch (level) {
        case ZinkOptimizationLevelAuto: levelName = @"Auto"; break;
        case ZinkOptimizationLevelOff:  levelName = @"Off (0)"; break;
        case ZinkOptimizationLevelSafe: levelName = @"Safe (1)"; break;
        case ZinkOptimizationLevelLow:  levelName = @"Low (2)"; break;
        case ZinkOptimizationLevelMedium: levelName = @"Medium (3)"; break;
        case ZinkOptimizationLevelHigh: levelName = @"High (4)"; break;
        case ZinkOptimizationLevelUltra: levelName = @"Ultra (5)"; break;
        default: levelName = @"Unknown"; break;
    }

    ZinkOptimizationLevel resolvedLevel = level;
    if (resolvedLevel == ZinkOptimizationLevelAuto) {
        resolvedLevel = [self recommendedOptimizationLevel];
    }

    NSString *resolvedLevelName;
    switch (resolvedLevel) {
        case ZinkOptimizationLevelOff:  resolvedLevelName = @"Off (0)"; break;
        case ZinkOptimizationLevelSafe: resolvedLevelName = @"Safe (1)"; break;
        case ZinkOptimizationLevelLow:  resolvedLevelName = @"Low (2)"; break;
        case ZinkOptimizationLevelMedium: resolvedLevelName = @"Medium (3)"; break;
        case ZinkOptimizationLevelHigh: resolvedLevelName = @"High (4)"; break;
        case ZinkOptimizationLevelUltra: resolvedLevelName = @"Ultra (5)"; break;
        default: resolvedLevelName = @"Unknown"; break;
    }

    id glOverride = getPrefObject(@"zink.gl_override");
    NSString *glVer = (glOverride && [glOverride isKindOfClass:[NSString class]] && [glOverride length] > 0 && ![(NSString *)glOverride isEqualToString:@"0"])
        ? (NSString *)glOverride : @"4.1 (from level)";

    id glThread = getPrefObject(@"zink.enable_gl_thread");
    NSString *glThreadStr = glThread ? ([glThread boolValue] ? @"YES" : @"NO") : @"YES";

    id cacheSize = getPrefObject(@"zink.glsl_cache_size");
    NSString *cacheStr = cacheSize ? [NSString stringWithFormat:@"%ld MB", (long)[cacheSize integerValue]] : @"32 MB";

    id apiFeatures = getPrefObject(@"zink.api_features");
    NSString *apiStr;
    if (apiFeatures) {
        NSInteger apiVal = [apiFeatures integerValue];
        switch (apiVal) {
            case 0: apiStr = @"Minimal"; break;
            case 1: apiStr = @"Basic"; break;
            case 2: apiStr = @"Standard"; break;
            case 3: apiStr = @"Full"; break;
            default: apiStr = @"Full (default)"; break;
        }
    } else {
        apiStr = @"Full (default)";
    }

    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];

    return [NSString stringWithFormat:
        @"[Zink Config]\n"
        @"Renderer: %@\n"
        @"Mesa: %@ (%@)\n"
        @"GPU: %@ (recommended: %@)\n"
        @"Setting / Resolved: %@ / %@\n"
        @"GL: %@ / GL Thread: %@\n"
        @"Cache: %@ / API: %@",
        renderer, [self selectedMesaVersion], [self isZinkUsingEGL] ? @"EGL" : @"OSMesa",
        genName, [self deviceRecommendationString],
        levelName, resolvedLevelName,
        glVer, glThreadStr,
        cacheStr, apiStr];
}

+ (void)applyZinkEnvironmentFromPreferences {
    // Set Mesa version for Zink backend selection
    NSString *mesaVersion = [self selectedMesaVersion];
    setenv("ZINK_MESA_VERSION", mesaVersion.UTF8String, 1);
    if ([self isZinkUsingEGL]) {
        setenv("ZINK_USE_EGL", "1", 1);
        NSLog(@"[ZinkConfig] Using Mesa %@ (EGL backend)", mesaVersion);
    } else {
        unsetenv("ZINK_USE_EGL");
        NSLog(@"[ZinkConfig] Using Mesa %@ (OSMesa backend)", mesaVersion);
    }

    id rawLevel = getPrefObject(@"zink.optimization_level");
    ZinkOptimizationLevel level = ZinkOptimizationLevelAuto;
    if (rawLevel) {
        level = (ZinkOptimizationLevel)[rawLevel integerValue];
        if (level < ZinkOptimizationLevelOff || level > ZinkOptimizationLevelUltra) {
            level = ZinkOptimizationLevelAuto;
        }
    }

    ZinkOptimizationLevel resolvedLevel = level;
    if (resolvedLevel == ZinkOptimizationLevelAuto) {
        resolvedLevel = [self recommendedOptimizationLevel];
    }

    [self applyZinkEnvironmentForOptimizationLevel:level];

    // Store active config for in-game display (available via System.getenv in Java)
    NSString *summary = [self activeConfigSummary];
    setenv("ZINK_ACTIVE_CONFIG", summary.UTF8String, 1);
    NSLog(@"[ZinkConfig] %@", summary);

    id customGlVersion = getPrefObject(@"zink.gl_override");
    if (customGlVersion && [customGlVersion isKindOfClass:[NSString class]]) {
        NSString *verStr = (NSString *)customGlVersion;
        if ([verStr isEqualToString:@"3.3"]) {
            setenv("MESA_GL_VERSION_OVERRIDE", "3.3", 1);
            setenv("MESA_GLSL_VERSION_OVERRIDE", "330", 1);
        } else if ([verStr isEqualToString:@"4.0"]) {
            setenv("MESA_GL_VERSION_OVERRIDE", "4.0", 1);
            setenv("MESA_GLSL_VERSION_OVERRIDE", "400", 1);
        } else if ([verStr isEqualToString:@"4.1"]) {
            setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);
            setenv("MESA_GLSL_VERSION_OVERRIDE", "410", 1);
        } else if ([verStr isEqualToString:@"4.3"]) {
            setenv("MESA_GL_VERSION_OVERRIDE", "4.3", 1);
            setenv("MESA_GLSL_VERSION_OVERRIDE", "430", 1);
        } else if ([verStr isEqualToString:@"4.6"]) {
            setenv("MESA_GL_VERSION_OVERRIDE", "4.6", 1);
            setenv("MESA_GLSL_VERSION_OVERRIDE", "460", 1);
        }

        // GL 4.3+ (user requested compute-capable profile). The optimization
        // level may have disabled GL_ARB_compute_shader (e.g. Medium on A11)
        // to reduce memory pressure, which silently breaks any GL 4.3+
        // compute consumer such as Voxy: its Capabilities probe reads
        // glDispatchComputeIndirect == NULL and reports itself unsupported.
        // Force-enable compute and indirect-draw-count extensions so a
        // 4.3/4.6 override behaves as advertised and Voxy can run.
        if ([verStr isEqualToString:@"4.3"] || [verStr isEqualToString:@"4.6"]) {
            const char *origOverride = getenv("MESA_EXTENSION_OVERRIDE");
            NSString *extOverride = origOverride ? [NSString stringWithUTF8String:origOverride] : @"";
            NSArray *tokens = [extOverride componentsSeparatedByString:@" "];
            NSMutableArray *cleanTokens = [NSMutableArray array];
            for (NSString *token in tokens) {
                if (token.length > 0 && ![token isEqualToString:@"-GL_ARB_compute_shader"]) {
                    [cleanTokens addObject:token];
                }
            }
            [cleanTokens addObject:@"+GL_ARB_compute_shader"];
            [cleanTokens addObject:@"+GL_ARB_indirect_parameters"];
            setenv("MESA_EXTENSION_OVERRIDE",
                   [[cleanTokens componentsJoinedByString:@" "] UTF8String], 1);
            NSLog(@"[ZinkConfig] GL 4.3+ override: compute + indirect-parameters force-enabled, MESA_EXTENSION_OVERRIDE=%@",
                  [cleanTokens componentsJoinedByString:@" "]);
        }
    }

    id enableGLThread = getPrefObject(@"zink.enable_gl_thread");
    if (enableGLThread) {
        setenv("mesa_glthread", [enableGLThread boolValue] ? "true" : "false", 1);
    } else {
        // Disable glthread on A11 and older to reduce memory pressure
        AppleGPUGeneration gen = [self deviceGPUGeneration];
        if (gen <= AppleGPUGenerationA11) {
            setenv("mesa_glthread", "false", 1);
        }
    }

    // On A11 and older: disable MoltenVK command buffer prefilling to reduce GPU memory pressure
    AppleGPUGeneration gen = [self deviceGPUGeneration];
    if (gen <= AppleGPUGenerationA11) {
        setenv("MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS", "0", 1);
    }

    // Set shader cache to a writable path (Documents/.mesa_shader_cache)
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (docPaths.count > 0) {
        NSString *cacheDir = [docPaths[0] stringByAppendingPathComponent:@".mesa_shader_cache"];
        NSError *err = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&err];
        if (!err) {
            setenv("MESA_SHADER_CACHE_DIR", cacheDir.UTF8String, 1);
            setenv("MESA_GLSL_CACHE_DIR", cacheDir.UTF8String, 1);
        }
    }

    id cacheSize = getPrefObject(@"zink.glsl_cache_size");
    if (cacheSize && [cacheSize integerValue] > 0) {
        char buf[16];
        snprintf(buf, sizeof(buf), "%ld", (long)[cacheSize integerValue]);
        setenv("MESA_GLSL_CACHE_MAX_SIZE", buf, 1);
        setenv("MESA_SHADER_CACHE_MAX_SIZE", buf, 1);
    }

    id customAPIOverride = getPrefObject(@"zink.api_features");
    if (customAPIOverride) {
        NSInteger apiVal = [customAPIOverride integerValue];
        ZinkAPIFeatures baseFeatures = [self supportedAPIFeatures];
        ZinkAPIFeatures enabledFeatures;

        switch (apiVal) {
            case 0: // Minimal
                enabledFeatures = ZinkAPIFeatureTextureAnisotropic;
                break;
            case 1: // Basic
                enabledFeatures = ZinkAPIFeatureTextureAnisotropic |
                                  ZinkAPIFeatureTessellationShader |
                                  ZinkAPIFeatureGeometryShader;
                break;
            case 2: // Standard
                enabledFeatures = baseFeatures & ~ZinkAPIFeatureTransformFeedback;
                if (resolvedLevel <= ZinkOptimizationLevelLow) {
                    enabledFeatures &= ~ZinkAPIFeatureComputeShader;
                }
                if (resolvedLevel <= ZinkOptimizationLevelSafe) {
                    enabledFeatures &= ~(ZinkAPIFeatureDirectStateAccess | ZinkAPIFeatureMultiDrawIndirect);
                }
                break;
            case 3: // Full
            default:
                enabledFeatures = baseFeatures & ~ZinkAPIFeatureTransformFeedback;
                break;
        }
        [self applyZinkAPIFeatureOverride:enabledFeatures];
    }
}

+ (NSString *)extensionDisableStringForLevel:(ZinkAPIFeatures)enabledFeatures {
    NSMutableArray *disableExts = [NSMutableArray array];

    // Force-enable GL_ARB_shader_draw_parameters (required by Minecraft 1.17+
    // rendering pipeline). Zink/Mesa 21.0.0 does not expose this extension by
    // default even when the underlying Vulkan/Metal supports it.
    [disableExts addObject:@"+GL_ARB_shader_draw_parameters"];

    if (!(enabledFeatures & ZinkAPIFeatureTransformFeedback)) {
        [disableExts addObject:@"-GL_ARB_transform_feedback"];
        [disableExts addObject:@"-GL_ARB_transform_feedback2"];
        [disableExts addObject:@"-GL_ARB_transform_feedback3"];
        [disableExts addObject:@"-GL_NV_transform_feedback"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureComputeShader)) {
        [disableExts addObject:@"-GL_ARB_compute_shader"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureTessellationShader)) {
        [disableExts addObject:@"-GL_ARB_tessellation_shader"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureGeometryShader)) {
        [disableExts addObject:@"-GL_ARB_geometry_shader4"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureMultiDrawIndirect)) {
        [disableExts addObject:@"-GL_ARB_multi_draw_indirect"];
        [disableExts addObject:@"-GL_ARB_draw_indirect"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureDirectStateAccess)) {
        [disableExts addObject:@"-GL_ARB_direct_state_access"];
    }

    if (!(enabledFeatures & ZinkAPIFeatureTextureAnisotropic)) {
        [disableExts addObject:@"-GL_EXT_texture_filter_anisotropic"];
    }

    return [disableExts componentsJoinedByString:@" "];
}

#pragma mark - Info Strings

+ (NSString *)deviceRecommendationString {
    AppleGPUGeneration gen = [self deviceGPUGeneration];
    ZinkOptimizationLevel rec = [self recommendedOptimizationLevel];

    NSString *genName = [self deviceGPUGenerationName];
    NSString *levelName;
    switch (rec) {
        case ZinkOptimizationLevelSafe:   levelName = @"Safe (1)"; break;
        case ZinkOptimizationLevelLow:    levelName = @"Low (2)"; break;
        case ZinkOptimizationLevelMedium: levelName = @"Medium (3)"; break;
        case ZinkOptimizationLevelHigh:   levelName = @"High (4)"; break;
        case ZinkOptimizationLevelUltra:  levelName = @"Ultra (5)"; break;
        default: levelName = @"Auto"; break;
    }

    return [NSString stringWithFormat:@"%@ GPU → Recommended: %@", genName, levelName];
}

+ (NSString *)apiSupportSummaryForGPUGeneration:(AppleGPUGeneration)gen {
    ZinkAPIFeatures features = [self supportedAPIFeaturesForGPUGeneration:gen];
    NSMutableString *summary = [NSMutableString string];

    [summary appendFormat:@"%@ GPU:\n", [self deviceGPUGenerationName]];
    [summary appendFormat:@"✓ Transform Feedback: %@\n",
        (features & ZinkAPIFeatureTransformFeedback) ? @"OFF (forced)" : @"OFF (unsupported)"];
    [summary appendFormat:@"✓ Compute Shader: %@\n",
        (features & ZinkAPIFeatureComputeShader) ? @"ON" : @"OFF"];
    [summary appendFormat:@"✓ Tessellation: %@\n",
        (features & ZinkAPIFeatureTessellationShader) ? @"ON" : @"OFF"];
    [summary appendFormat:@"✓ Multi Draw Indirect: %@\n",
        (features & ZinkAPIFeatureMultiDrawIndirect) ? @"ON" : @"OFF"];
    [summary appendFormat:@"✓ Direct State Access: %@\n",
        (features & ZinkAPIFeatureDirectStateAccess) ? @"ON" : @"OFF"];

    return summary;
}

@end
