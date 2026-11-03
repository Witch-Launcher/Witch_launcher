#import "SurfaceViewController+LaunchSplash.h"
#import "SurfaceViewController+Widget.h"
#import "LaunchSplashView.h"
#import "LauncherPreferences.h"
#import <QuartzCore/QuartzCore.h>

static NSTimer *launchSplashTimer;
static uint64_t launchSplashBaselineSwap;
static __weak LaunchSplashView *launchSplashView;

@implementation SurfaceViewController (LaunchSplash)

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
    LaunchSplashView *splash = launchSplashView;
    launchSplashView = nil;
    if (!splash) return;
    [splash stopAnimating];
    [UIView animateWithDuration:0.3 animations:^{
        splash.alpha = 0.0;
    } completion:^(BOOL finished) {
        [splash removeFromSuperview];
    }];
}

@end
