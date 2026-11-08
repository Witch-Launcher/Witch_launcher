#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Launch splash: brand cluster (logo mark + wordmark + version sup) anchored
/// bottom-left over a soft inward-fading black scrim, a "please wait" line and
/// an indeterminate accent bar, all with a staggered entrance/exit
/// choreography. A three-finger tap opens the built-in log panel: the brand
/// row flies to the top-left corner and a rounded log sheet fills the freed
/// space (recording auto-starts, and silencing the panel never stops it).
@interface LaunchSplashView : UIView

/// Starts the staggered entrance choreography (scrim in -> mark -> wordmark
/// + version -> waiting line -> progress bar -> hint).
- (void)startAnimating;

/// Plays the reversed exit choreography and hands the view back through
/// `completion` when it is safe to remove.
- (void)playExitAnimationWithCompletion:(void (^)(void))completion;

/// Legacy no-op kept for compatibility with existing call sites.
- (void)stopAnimating;

/// Suspends the entrance choreography if it is still running (used when the
/// splash is dismissed before the sequence finished).
- (void)cancelChoreography;

@end

NS_ASSUME_NONNULL_END
