#import "TGLMTConfig.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "ZinkConfig.h"
#import "utils.h"

NSString *const TGLMTPrefSection = @"tglmt";

@implementation TGLMTConfig

+ (BOOL)isTGLMTRendererSelected {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    return [renderer isEqualToString:@ RENDERER_NAME_TGLMT];
}

+ (BOOL)deviceSupportsTGLMT {
    // Tái dùng bảng mapping thiết bị của ZinkConfig (A9..A19/M1..M5).
    // Ngưỡng đầy đủ: A11 (iPhone 10,x). Dưới A11: cảnh báo, không chặn.
    AppleGPUGeneration gen = [ZinkConfig deviceGPUGeneration];
    if (gen == AppleGPUGenerationUnknown) return YES; // simulator/máy lạ: cho chạy
    if (gen >= AppleGPUGenerationM1) return YES;
    return gen >= AppleGPUGenerationA11;
}

+ (NSString *)deviceSupportNote {
    AppleGPUGeneration gen = [ZinkConfig deviceGPUGeneration];
    NSString *name = [ZinkConfig deviceGPUGenerationName];
    if ([self deviceSupportsTGLMT]) {
        return [NSString stringWithFormat:@"%@ fully supported (vanilla boot path)", name];
    }
    return [NSString stringWithFormat:
        @"%@ below A11: TGLMT will still try (no mesh shaders, vanilla only), "
        @"expect reduced perf. Recommended: Zink/MobileGlues on this device.", name];
}

+ (void)applyEnvironmentFromPreferences {
    setenv("TGLMT_RENDERER", "1", 1);
    // Số frame bay (throughput TBDR A11): mặc định 3, chỉnh qua tglmt.frames_in_flight.
    id frames = getPrefObject(@"tglmt.frames_in_flight");
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", frames ? (int)[frames integerValue] : 3);
    setenv("TGLMT_FRAMES_IN_FLIGHT", buf, 1);

    NSLog(@"[TGLMTConfig] Applied config: frames=%s note=%@",
        getenv("TGLMT_FRAMES_IN_FLIGHT"), [self deviceSupportNote]);
    if (![self deviceSupportsTGLMT]) {
        NSLog(@"[TGLMTConfig] WARNING: %@", [self deviceSupportNote]);
    }
}

+ (NSString *)activeConfigSummary {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    id frames = getPrefObject(@"tglmt.frames_in_flight");
    NSString *framesStr = frames ? [NSString stringWithFormat:@"%ld", (long)[frames integerValue]] : @"3";
    return [NSString stringWithFormat:
        @"[TGLMT Config]\n"
        @"Renderer: %@\n"
        @"Backend: GL 4.6 Core -> Metal (libtglmt.dylib)\n"
        @"GPU: %@\n"
        @"Frames in Flight: %@",
        renderer, [self deviceSupportNote], framesStr];
}

@end
