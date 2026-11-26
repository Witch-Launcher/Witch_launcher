#import "SurfaceViewController+LaunchSplash.h"
#import "SurfaceViewController+Widget.h"
#import "LaunchSplashView.h"
#import "LauncherPreferences.h"
#import "WitchLogOverlay.h"
#import <QuartzCore/QuartzCore.h>

static NSTimer *launchSplashTimer;
static uint64_t launchSplashBaselineSwap;
static __weak LaunchSplashView *launchSplashView;

@implementation SurfaceViewController (LaunchSplash)

- (void)installOverlayLogGestureIfEnabled {
    if (!getPrefBool(@"general.overlay_log_in_game")) return;
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOverlayLogThreeFingerTap:)];
    tap.numberOfTouchesRequired = 3;
    // Keep the game's own touches flowing: a 3-finger tap is never claimed by
    // the game, so requiring it here cannot steal gameplay input.
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)handleOverlayLogThreeFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    if (!getPrefBool(@"general.overlay_log_in_game")) return;
    [[WitchLogOverlay sharedOverlay] toggleInView:self.view];
}

- (void)presentLaunchSplash {
    [self dismissLaunchSplash];
    if (!getPrefBool(@"appearance.launch_splash")) return;
    launchSplashBaselineSwap = pojavSwapCount();
    LaunchSplashView *splash = [[LaunchSplashView alloc] initWithFrame:self.view.bounds];
    splash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:splash];
    launchSplashView = splash;
    [splash startAnimating];

    __weak typeof(self) weakSelf = self;
    launchSplashTimer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        if (pojavSwapCount() <= launchSplashBaselineSwap) return;
        [timer invalidate];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf dismissLaunchSplash]; });
    }];
    [[NSRunLoop mainRunLoop] addTimer:launchSplashTimer forMode:NSRunLoopCommonModes];
}

- (void)dismissLaunchSplash {
    [launchSplashTimer invalidate];
    launchSplashTimer = nil;
    // With the in-game overlay log disabled, hide any log the user opened on
    // the splash so they are not left with a floating log they cannot close.
    if (!getPrefBool(@"general.overlay_log_in_game")) {
        [[WitchLogOverlay sharedOverlay] hideAnimated:YES];
    }
    LaunchSplashView *splash = launchSplashView;
    launchSplashView = nil;
    if (!splash) return;
    // The splash plays its own reversed choreography (cluster up, bar down,
    // scrim dissolves) and hands itself back when it is safe to remove.
    [splash playExitAnimationWithCompletion:^{
        [splash removeFromSuperview];
    }];
}

@end
