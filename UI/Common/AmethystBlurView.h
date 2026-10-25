#import <UIKit/UIKit.h>

extern NSString * const AmethystBlurIntensityDidChangeNotification;

// TRUE REALTIME Gaussian frost: a UIVisualEffectView that live-blurs
// whatever is rendered behind it every frame (wallpaper, video, content).
// The intensity preference drives material thickness + readability tint,
// and works with or without a custom wallpaper (never black).
@interface AmethystBlurView : UIView

- (instancetype)initWithPrefKey:(NSString *)key;
// glassEligible marks navigation/chrome surfaces that may use Liquid Glass.
// Content-layer backgrounds keep the standard blur material even when the
// launcher-wide Liquid Glass preference is on (Apple HIG: don't put glass in
// the content layer).
- (instancetype)initWithPrefKey:(NSString *)key glassEligible:(BOOL)glassEligible;
- (void)applyCurrentIntensity;

+ (void)installInView:(UIView *)containerView;
+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key;
+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key glassEligible:(BOOL)glassEligible;

+ (BOOL)blurEnabled;
+ (CGFloat)currentIntensity;
+ (BOOL)blurEnabledForKey:(NSString *)key;

@end
