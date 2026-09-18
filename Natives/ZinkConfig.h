#pragma once

#import <Foundation/Foundation.h>

extern NSString *const ZinkPrefSection;

typedef NS_ENUM(NSInteger, ZinkOptimizationLevel) {
    ZinkOptimizationLevelAuto = -1,
    ZinkOptimizationLevelOff = 0,
    ZinkOptimizationLevelSafe = 1,
    ZinkOptimizationLevelLow = 2,
    ZinkOptimizationLevelMedium = 3,
    ZinkOptimizationLevelHigh = 4,
    ZinkOptimizationLevelUltra = 5
};

typedef NS_OPTIONS(NSUInteger, ZinkAPIFeatures) {
    ZinkAPIFeatureNone               = 0,
    ZinkAPIFeatureTransformFeedback  = 1 << 0,
    ZinkAPIFeatureComputeShader      = 1 << 1,
    ZinkAPIFeatureTessellationShader = 1 << 2,
    ZinkAPIFeatureGeometryShader     = 1 << 3,
    ZinkAPIFeatureMultiDrawIndirect  = 1 << 4,
    ZinkAPIFeatureDirectStateAccess  = 1 << 5,
    ZinkAPIFeatureTextureAnisotropic = 1 << 6,
    ZinkAPIFeatureMax = 1 << 7
};

typedef NS_ENUM(NSInteger, AppleGPUGeneration) {
    AppleGPUGenerationUnknown = 0,
    AppleGPUGenerationA9  = 9,
    AppleGPUGenerationA10 = 10,
    AppleGPUGenerationA11 = 11,
    AppleGPUGenerationA12 = 12,
    AppleGPUGenerationA13 = 13,
    AppleGPUGenerationA14 = 14,
    AppleGPUGenerationA15 = 15,
    AppleGPUGenerationA16 = 16,
    AppleGPUGenerationA17 = 17,
    AppleGPUGenerationA18 = 18,
    AppleGPUGenerationA19 = 19,
    AppleGPUGenerationM1  = 101,
    AppleGPUGenerationM2  = 102,
    AppleGPUGenerationM3  = 103,
    AppleGPUGenerationM4  = 104,
    AppleGPUGenerationM5  = 105
};

// Vulkan backend selection for Zink renderer
typedef NS_ENUM(NSInteger, ZinkVulkanBackend) {
    ZinkVulkanBackendAuto = 0,       // Auto-select based on GPU capability
    ZinkVulkanBackendMoltenVK = 1,   // Use MoltenVK (all chips A9+)
    ZinkVulkanBackendKosmicKrisp = 2 // Use KosmicKrisp Mesa driver (A13+ only)
};

@interface ZinkConfig : NSObject

+ (AppleGPUGeneration)deviceGPUGeneration;
+ (NSString *)deviceGPUGenerationName;
+ (ZinkOptimizationLevel)recommendedOptimizationLevel;
+ (ZinkAPIFeatures)supportedAPIFeaturesForGPUGeneration:(AppleGPUGeneration)gen;
+ (ZinkAPIFeatures)supportedAPIFeatures;
+ (BOOL)isZinkRenderSelected;

+ (NSString *)selectedMesaVersion;
+ (NSString *)zinkLibraryName;
+ (BOOL)isZinkUsingEGL;

// KosmicKrisp support detection (runtime MTLGPUFamily check)
+ (BOOL)deviceSupportsKosmicKrisp;
+ (BOOL)deviceSupportsKosmicKrispFull;  // A14+ = Vulkan 1.4
+ (BOOL)deviceSupportsKosmicKrispReduced; // A13 = Vulkan 1.2
+ (ZinkVulkanBackend)selectedVulkanBackend;
+ (NSString *)vulkanBackendName;

+ (void)applyZinkEnvironmentForOptimizationLevel:(ZinkOptimizationLevel)level;
+ (void)applyZinkEnvironmentFromPreferences;
+ (void)applyZinkAPIFeatureOverride:(ZinkAPIFeatures)enabledFeatures;

+ (NSString *)deviceRecommendationString;
+ (NSString *)apiSupportSummaryForGPUGeneration:(AppleGPUGeneration)gen;
+ (NSString *)activeConfigSummary;

@end
