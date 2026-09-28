#pragma once

#import <Foundation/Foundation.h>

extern NSString *const TGLMTPrefSection;

// TGLMT: OpenGL 4.6 Core -> Metal directly (libtglmt.dylib).
// Vanilla boot path, tối thiểu A11. Không MoltenVK, không ANGLE.
@interface TGLMTConfig : NSObject

+ (BOOL)isTGLMTRendererSelected;
// A11+ được hỗ trợ đầy đủ (depth 32F, blit, divisor, UBO). A9/A10 vẫn cho
// chạy nhưng log cảnh báo (mesh Apple7+ vắng mặt là đúng, vanilla không cần).
+ (BOOL)deviceSupportsTGLMT;
+ (NSString *)deviceSupportNote;
+ (void)applyEnvironmentFromPreferences;
+ (NSString *)activeConfigSummary;

@end
