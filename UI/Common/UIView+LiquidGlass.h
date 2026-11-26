#import <UIKit/UIKit.h>

extern NSString * const LiquidGlassDidChangeNotification;
extern NSString * const kLiquidGlassTag;

@interface UIView (LiquidGlass)

// iOS 26+ only. On older systems the preference is ignored and the normal
// opaque/blurred appearance is kept.
+ (BOOL)lg_isAvailable;
+ (BOOL)lg_isEnabled;
+ (UIVisualEffect *)lg_makeEffectWithTint:(UIColor *)tintColor;
+ (void)lg_configureGlassEffectView:(UIVisualEffectView *)effectView
                       cornerRadius:(CGFloat)radius
                      maskedCorners:(CACornerMask)maskedCorners API_AVAILABLE(ios(26.0));

// Applies a real UIGlassEffect background. The original background colour is
// remembered and restored when Liquid Glass is switched off.
- (UIVisualEffectView *)lg_addGlassEffect;
- (UIVisualEffectView *)lg_addGlassEffectWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius;
- (UIVisualEffectView *)lg_addGlassEffectWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius maskedCorners:(CACornerMask)maskedCorners;

// Registers the view as a Liquid Glass surface and applies/removes the effect
// according to the current preference. Safe to call before or after the
// toggle changes; the category observes the preference notifications.
- (void)lg_enableLiquidGlassWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius maskedCorners:(CACornerMask)maskedCorners;
- (void)lg_refreshLiquidGlass;
- (void)lg_setLiquidGlassBaseColor:(UIColor *)color;
- (void)lg_removeGlassEffect;
- (BOOL)lg_hasGlassEffect;
+ (void)lg_refreshAllInWindows;

@end
