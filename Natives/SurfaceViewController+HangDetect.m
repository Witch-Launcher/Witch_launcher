#import "SurfaceViewController+HangDetect.h"
#import "SurfaceViewController+Widget.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ThemeManager.h"
#import "utils.h"

#import <QuartzCore/QuartzCore.h>

// Black-screen / hang watchdog. Launching the game arms this watcher; it
// polls the Metal swap counter (the same source as the FPS widget) and the
// tail of latestlog. If three minutes pass without a single presented frame
// while the log is frozen — or while it only cycles through the same
// automated lines — an achievement-style card offers to share the log.

static NSTimer *hangWatchdogTimer;
static CFTimeInterval hangWatchdogStartedAt;
static uint64_t hangWatchdogBaselineSwap;
static NSUInteger hangWatchdogLogSignature;
static NSInteger hangWatchdogStallTicks;
static BOOL hangWatchdogPanelShown;
static __weak UIView *hangPanelView;

static const NSTimeInterval kHangTimeout = 180.0;      // 3 minutes
static const NSTimeInterval kHangTickInterval = 5.0;
static const NSTimeInterval kHangLogStallWindow = 30.0;

static NSString *HangLatestLogPath(void) {
    const char *home = getenv("POJAV_HOME");
    if (!home) return nil;
    return [@(home) stringByAppendingPathComponent:@"latestlog.txt"];
}

// Signature of the last 4 KB of the log. A frozen file returns the same value
// every tick; a file that keeps appending identical automated lines keeps the
// same 4 KB window too, so both cases read as "stalled".
static NSUInteger HangLogTailSignature(void) {
    NSString *path = HangLatestLogPath();
    if (path.length == 0) return 0;
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return 0;
    unsigned long long size = [handle seekToEndOfFile];
    unsigned long long length = MIN(size, (unsigned long long)4096);
    if (length == 0) {
        [handle closeFile];
        return 0;
    }
    [handle seekToFileOffset:size - length];
    NSData *tail = [handle readDataOfLength:(NSUInteger)length];
    [handle closeFile];
    NSUInteger hash = 5381;
    const uint8_t *bytes = tail.bytes;
    for (NSUInteger i = 0; i < tail.length; i++) {
        hash = ((hash << 5) + hash) + bytes[i];
    }
    return hash;
}

@implementation SurfaceViewController (HangDetect)

- (void)startBlackScreenWatchdog {
    [self stopBlackScreenWatchdog];
    hangWatchdogStartedAt = CACurrentMediaTime();
    // The swap counter is process-wide; another world may already have drawn
    // frames in this app session. Only frames after this launch count.
    hangWatchdogBaselineSwap = pojavSwapCount();
    hangWatchdogLogSignature = HangLogTailSignature();
    hangWatchdogStallTicks = 0;
    hangWatchdogPanelShown = NO;

    __weak typeof(self) weakSelf = self;
    hangWatchdogTimer = [NSTimer timerWithTimeInterval:kHangTickInterval repeats:YES block:^(NSTimer *timer) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            [timer invalidate];
            return;
        }
        [strongSelf hangWatchdogTick:timer];
    }];
    [[NSRunLoop mainRunLoop] addTimer:hangWatchdogTimer forMode:NSRunLoopCommonModes];
}

- (void)stopBlackScreenWatchdog {
    [hangWatchdogTimer invalidate];
    hangWatchdogTimer = nil;
}

- (void)hangWatchdogTick:(NSTimer *)timer {
    if (hangWatchdogPanelShown) {
        [timer invalidate];
        return;
    }
    // Any presented drawable means the game is alive: the black screen is over.
    if (pojavSwapCount() > hangWatchdogBaselineSwap) {
        [self stopBlackScreenWatchdog];
        return;
    }

    NSUInteger signature = HangLogTailSignature();
    if (signature == hangWatchdogLogSignature) {
        hangWatchdogStallTicks += 1;
    } else {
        hangWatchdogLogSignature = signature;
        hangWatchdogStallTicks = 0;
    }

    NSTimeInterval elapsed = CACurrentMediaTime() - hangWatchdogStartedAt;
    BOOL logStalled = (hangWatchdogStallTicks * kHangTickInterval) >= kHangLogStallWindow;
    if (elapsed >= kHangTimeout && logStalled) {
        [self stopBlackScreenWatchdog];
        [self presentBlackScreenPanel];
    }
}

#pragma mark - Panel

- (void)presentBlackScreenPanel {
    if (hangWatchdogPanelShown) return;
    hangWatchdogPanelShown = YES;
    [HapticManager.shared play:HapticTypeWarning];

    ThemeManager *theme = ThemeManager.shared;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = theme.cardBackgroundColor;
    card.layer.cornerRadius = 18;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.35].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.28;
    card.layer.shadowRadius = 18;
    card.layer.shadowOffset = CGSizeMake(0, 8);
    [self.view addSubview:card];
    [AmethystBlurView installInView:card];
    hangPanelView = card;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = theme.accentColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    title.textColor = theme.primaryTextColor;
    title.numberOfLines = 1;
    title.text = localize(@"hang.title", nil);
    [card addSubview:title];

    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    message.textColor = theme.secondaryTextColor;
    message.numberOfLines = 0;
    message.text = localize(@"hang.message", nil);
    [card addSubview:message];

    UIButton *decline = [UIButton buttonWithType:UIButtonTypeSystem];
    decline.translatesAutoresizingMaskIntoConstraints = NO;
    decline.layer.cornerRadius = 12;
    decline.layer.borderWidth = 1.5;
    decline.layer.borderColor = theme.accentColor.CGColor;
    decline.backgroundColor = UIColor.clearColor;
    decline.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [decline setTitle:localize(@"hang.decline", nil) forState:UIControlStateNormal];
    [decline setTitleColor:theme.accentColor forState:UIControlStateNormal];
    [decline addTarget:self action:@selector(hangPanelDeclineTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:decline];

    UIButton *accept = [UIButton buttonWithType:UIButtonTypeSystem];
    accept.translatesAutoresizingMaskIntoConstraints = NO;
    accept.layer.cornerRadius = 12;
    accept.backgroundColor = theme.accentColor;
    accept.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [accept setTitle:localize(@"hang.accept", nil) forState:UIControlStateNormal];
    [accept setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
    [accept addTarget:self action:@selector(hangPanelAcceptTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:accept];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *width = [card.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-32];
    width.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [card.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        width,
        [card.widthAnchor constraintLessThanOrEqualToConstant:380],

        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [icon.widthAnchor constraintEqualToConstant:34],
        [icon.heightAnchor constraintEqualToConstant:34],

        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [message.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],

        [decline.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [decline.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:14],
        [decline.heightAnchor constraintEqualToConstant:44],
        [decline.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],

        [accept.leadingAnchor constraintEqualToAnchor:decline.trailingAnchor constant:10],
        [accept.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [accept.topAnchor constraintEqualToAnchor:decline.topAnchor],
        [accept.heightAnchor constraintEqualToAnchor:decline.heightAnchor],
        [accept.widthAnchor constraintEqualToAnchor:decline.widthAnchor],
    ]];

    [self.view layoutIfNeeded];
    card.alpha = 0;
    card.transform = CGAffineTransformMakeTranslation(0, -(CGRectGetMaxY(card.frame) + 40));
    icon.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.45 delay:0.12 usingSpringWithDamping:0.55 initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        icon.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hangPanelAcceptTapped {
    NSString *path = HangLatestLogPath();
    [self dismissBlackScreenPanel];
    if (path.length == 0) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                         applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)hangPanelDeclineTapped {
    [self dismissBlackScreenPanel];
}

- (void)dismissBlackScreenPanel {
    UIView *card = hangPanelView;
    if (!card) return;
    hangPanelView = nil;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        card.alpha = 0;
        card.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -120),
                                                 CGAffineTransformMakeScale(0.92, 0.92));
    } completion:^(BOOL finished) {
        [card removeFromSuperview];
    }];
}

@end
