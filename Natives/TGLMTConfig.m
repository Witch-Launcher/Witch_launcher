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
    char buf[16];

    // Số frame bay (throughput TBDR A11): 1..8, mặc định 2.
    id frames = getPrefObject(@"tglmt.frames_in_flight");
    int fif = frames ? (int)[frames integerValue] : 2;
    if (fif < 1) fif = 1;
    if (fif > 8) fif = 8;
    snprintf(buf, sizeof(buf), "%d", fif);
    setenv("TGLMT_FRAMES_IN_FLIGHT", buf, 1);

    // Slot buffer xoay khi GPU đang bận: 1..8, mặc định 3. Cao = ít chờ
    // (bufWaitStall) nhưng tốn RAM pool; thấp = tiết kiệm RAM hơn.
    id pool = getPrefObject(@"tglmt.buf_pool_slots");
    int slots = pool ? (int)[pool integerValue] : 3;
    if (slots < 1) slots = 1;
    if (slots > 8) slots = 8;
    snprintf(buf, sizeof(buf), "%d", slots);
    setenv("TGLMT_BUF_POOL", buf, 1);

    // Chẩn đoán nặng (fprintf + readback mỗi draw). Tắt khi chơi thật —
    // bật làm FPS tụt mạnh (đo trên iPhone 8 Plus: 10-20 fps).
    BOOL diag = getPrefBool(@"tglmt.diag");
    setenv("TGLMT_DIAG", diag ? "1" : "0", 1);

    NSLog(@"[TGLMTConfig] Applied config: fif=%s pool=%s diag=%s note=%@",
        getenv("TGLMT_FRAMES_IN_FLIGHT"), getenv("TGLMT_BUF_POOL"),
        getenv("TGLMT_DIAG"), [self deviceSupportNote]);
    if (![self deviceSupportsTGLMT]) {
        NSLog(@"[TGLMTConfig] WARNING: %@", [self deviceSupportNote]);
    }
}

+ (NSString *)activeConfigSummary {
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
    id frames = getPrefObject(@"tglmt.frames_in_flight");
    id pool = getPrefObject(@"tglmt.buf_pool_slots");
    NSString *framesStr = frames ? [NSString stringWithFormat:@"%ld", (long)[frames integerValue]] : @"2";
    NSString *poolStr = pool ? [NSString stringWithFormat:@"%ld", (long)[pool integerValue]] : @"3";
    NSString *diagStr = getPrefBool(@"tglmt.diag") ? @"on" : @"off";
    return [NSString stringWithFormat:
        @"[TGLMT Config]\n"
        @"Renderer: %@\n"
        @"Backend: GL 4.6 Core -> Metal (libtglmt.dylib)\n"
        @"GPU: %@\n"
        @"Frames in Flight: %@\n"
        @"Buffer pool slots: %@\n"
        @"Diagnostics: %@",
        renderer, [self deviceSupportNote], framesStr, poolStr, diagStr];
}

@end
