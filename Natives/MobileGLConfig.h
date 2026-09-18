#pragma once

#import <Foundation/Foundation.h>

extern NSString *const MobileGLPrefSection;

typedef NS_ENUM(NSInteger, MobileGLAsyncShaderCompile) {
    MobileGLAsyncShaderCompileAuto = 0,
    MobileGLAsyncShaderCompileOn = 1,
    MobileGLAsyncShaderCompileOff = 2
};

typedef NS_ENUM(NSInteger, MobileGLShaderCache) {
    MobileGLShaderCacheAuto = 0,
    MobileGLShaderCacheOn = 1,
    MobileGLShaderCacheOff = 2
};

typedef NS_ENUM(NSInteger, MobileGLBackendType) {
    MobileGLBackendTypeDirectVulkan = 0,
    MobileGLBackendTypeDirectGLES = 1
};

typedef NS_ENUM(NSInteger, MobileGLAngleBackend) {
    MobileGLAngleBackendVulkan = 0,
    MobileGLAngleBackendMetal = 1
};

@interface MobileGLConfig : NSObject

+ (BOOL)isMobileGLRendererSelected;
+ (MobileGLBackendType)selectedBackendType;
+ (MobileGLAngleBackend)selectedAngleBackend;
+ (void)applyEnvironmentFromPreferences;
+ (NSString *)activeConfigSummary;

@end
