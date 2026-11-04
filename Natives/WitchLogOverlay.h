#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Full-width, text-on-screen log overlay. No card, no chrome: monospaced
/// text floats on a soft black gradient that fades out at the bottom edge.
/// Slides down from the top with a spring. Long-press copies the whole log,
/// three-finger tap hides it. Designed for the launch splash; can be reused
/// in game via the `general.overlay_log_in_game` preference.
@interface WitchLogOverlay : UIView

+ (instancetype)sharedOverlay;

/// Adds the overlay to `host` (full bounds) and animates it in. Reuses the
/// shared instance; moves it if it is currently attached elsewhere.
- (void)showInView:(UIView *)host;
- (void)hideAnimated:(BOOL)animated;
/// Show in `host` when hidden, otherwise hide.
- (void)toggleInView:(UIView *)host;
@property (nonatomic, readonly, getter=isShowing) BOOL showing;

@end

NS_ASSUME_NONNULL_END
