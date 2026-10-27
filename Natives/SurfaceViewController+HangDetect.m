#import "SurfaceViewController+HangDetect.h"
#import "SurfaceViewController+Widget.h"
#import "AmethystNoticePanel.h"
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

    NSString *logPath = HangLatestLogPath();
    AmethystNoticeAction *decline = [AmethystNoticeAction secondaryWithTitle:localize(@"hang.decline", nil) handler:nil];
    AmethystNoticeAction *accept = [AmethystNoticeAction primaryWithTitle:localize(@"hang.accept", nil) handler:^{
        if (logPath.length == 0) return;
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:logPath]]
                                                                                     applicationActivities:nil];
        activity.popoverPresentationController.sourceView = self.view;
        activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [self presentViewController:activity animated:YES completion:nil];
    }];
    AmethystNoticePanel *notice = [AmethystNoticePanel
        noticeWithTitle:localize(@"hang.title", nil)
                message:localize(@"hang.message", nil)
                actions:@[ decline, accept ]];
    [AmethystNoticePanel presentInView:self.view notice:notice];
}

@end
