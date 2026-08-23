#import <UIKit/UIKit.h>

extern NSString * const AmethystBlurIntensityDidChangeNotification;

// TRUE REALTIME Gaussian frost: a UIVisualEffectView that live-blurs
// whatever is rendered behind it every frame (wallpaper, video, content).
// The intensity preference drives material thickness + readability tint,
// and works with or without a custom wallpaper (never black).
@interface AmethystBlurView : UIView

- (instancetype)initWithPrefKey:(NSString *)key;
- (void)applyCurrentIntensity;

+ (void)installInView:(UIView *)containerView;
+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key;

+ (BOOL)blurEnabled;
+ (CGFloat)currentIntensity;
+ (BOOL)blurEnabledForKey:(NSString *)key;

@end
