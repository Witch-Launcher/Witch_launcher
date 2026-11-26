#import "SurfaceViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SurfaceViewController (LaunchSplash)
- (void)presentLaunchSplash;
- (void)dismissLaunchSplash;
- (void)installOverlayLogGestureIfEnabled;
@end

NS_ASSUME_NONNULL_END
