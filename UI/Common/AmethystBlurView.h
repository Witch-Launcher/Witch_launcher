#import <UIKit/UIKit.h>

// Fired whenever the shared panel-blur intensity preference changes so every
// installed AmethystBlurView can update itself live.
extern NSString * const AmethystBlurIntensityDidChangeNotification;

// A REALTIME frosted backdrop for full panels/sheets. Unlike a snapshot, the
// system material continuously samples whatever renders behind the view
// (including playing video), so it always matches what is on screen.
//
// Intensity is driven by the shared "amethyst_settings_blur" preference
// (0-100%). 0 disables the frost entirely; higher values produce stronger
// materials. The view never intercepts touches.
@interface AmethystBlurView : UIVisualEffectView

- (void)applyCurrentIntensity;

// YES when the shared intensity preference is > 0.
+ (BOOL)blurEnabled;

+ (CGFloat)currentIntensity;

// Convenience: create + pin to all edges of `containerView`, inserted at
// index 0 (behind existing subviews).
+ (void)installInView:(UIView *)containerView;

@end
