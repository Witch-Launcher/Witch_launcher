#import "PLLogOutputView.h"
#import "PerfRecorder.h"
#import "SurfaceViewController.h"
#import "utils.h"
#import "CrashScreenViewController.h"
#import "AppSheet.h"

NSNotificationName const WitchLogLineDidAppendNotification = @"WitchLogLineDidAppendNotification";

@interface PLLogOutputView()<UITableViewDataSource, UITableViewDelegate>
@property(nonatomic) UITableView* logTableView;
@property(nonatomic) UINavigationBar* navigationBar;
@end

@implementation PLLogOutputView
static BOOL fatalErrorOccurred;
static NSMutableArray* logLines;
// weak: the live view is owned by SurfaceViewController. Keeping a strong
// static pointer here turned every finished game session into a permanent
// log-view leak even after the view was removed from the hierarchy.
static __weak PLLogOutputView* current;
// A long session with the log panel open otherwise appends one line per
// log chunk forever (verbose:gc + the 2s MemSampler alone are unbounded).
static const NSUInteger kMaxLogLines = 2000;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    // Do not make this view the navigation controller's root view: that
    // creates navController -> rootVC -> view(self) -> navController and
    // retains the whole log panel after the game exits. The controller owns
    // a plain container instead; the table and navigation bar live there.
    CGRect logFrame = frame;
    logFrame.origin.y = logFrame.size.height;

    UIView *container = [[UIView alloc] initWithFrame:logFrame];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // Keep the translucent backdrop the old root view had; the navigation
    // controller's default background is opaque and would hide the game.
    container.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    UIViewController *vc = [UIViewController new];
    vc.view = container;

    self.frame = logFrame;
    self.navController = [[UINavigationController alloc] initWithRootViewController:vc];
    self.navigationBar = self.navController.navigationBar;
    self.navController.view.hidden = YES;

    logLines = [NSMutableArray new];

    vc.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
            target:self action:@selector(actionToggleLogOutput)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
            target:self action:@selector(actionClearLogOutput)]
    ];
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    vc.title = [NSString stringWithFormat:@"%@ v%@", localize(@"game.menu.log_output", nil), ver];

    self.logTableView = [[UITableView alloc] initWithFrame:container.bounds];
    //self.logTableView.allowsSelection = NO;
    self.logTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.logTableView.backgroundColor = UIColor.clearColor;
    self.logTableView.contentInset = UIEdgeInsetsMake(self.navigationBar.frame.size.height, 0, 0, 0);
    self.logTableView.dataSource = self;
    self.logTableView.delegate = self;
    self.logTableView.layoutMargins = UIEdgeInsetsZero;
    self.logTableView.rowHeight = 20;
    self.logTableView.separatorInset = UIEdgeInsetsZero;
    self.logTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [container addSubview:self.logTableView];
    [container addSubview:self.navigationBar];

    // Register the live view BEFORE toggling capture: setCaptureEnabled: looks
    // up `current` to install the play/pause bar button, so calling it while
    // `current` is still nil silently dropped that button from the log panel.
    current = self;

    canAppendToLog = YES;
    [self actionStartStopLogOutput];

    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return logLines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.backgroundColor = UIColor.clearColor;
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:16];
        cell.textLabel.textColor = UIColor.whiteColor;
    }
    cell.textLabel.text = logLines[indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *line = cell.textLabel.text;
    if (line.length == 0 || [line isEqualToString:@"\n"]) {
        return;
    }

    [AppSheet showOptionsWithTitle:nil message:line options:@[
        @{@"title": localize(localize(@"Share", nil), nil), @"icon": @"square.and.arrow.up"},
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx != 0) return;
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[line] applicationActivities:nil];
        activityVC.popoverPresentationController.sourceView = _navigationBar;
        activityVC.popoverPresentationController.sourceRect = _navigationBar.bounds;
        [currentVC() presentViewController:activityVC animated:YES completion:nil];
    }];
}

- (void)actionClearLogOutput {
    [logLines removeAllObjects];
    [self.logTableView reloadData];
}

+ (void)clearLog {
    if (!logLines) return;
    [logLines removeAllObjects];
    if (current) {
        [current.logTableView reloadData];
    }
}

+ (void)trimLogToMaxLines:(NSUInteger)maxLines {
    if (!logLines || logLines.count == 0) {
        return;
    }
    if (maxLines == 0) {
        maxLines = 1;
    }
    if (logLines.count <= maxLines) {
        return;
    }
    [logLines removeObjectsInRange:NSMakeRange(0, logLines.count - maxLines)];
    [current.logTableView reloadData];
}

- (void)actionShareLatestlog {
    NSString *latestlogPath = [NSString stringWithFormat:@"file://%s/latestlog.txt", getenv("POJAV_HOME")];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[@"latestlog.txt",
        [NSURL URLWithString:latestlogPath]] applicationActivities:nil];
    activityVC.popoverPresentationController.sourceView = self.navigationBar;
        activityVC.popoverPresentationController.sourceRect = self.navigationBar.bounds;
    [currentVC() presentViewController:activityVC animated:YES completion:nil];
}

- (void)actionStartStopLogOutput {
    [PLLogOutputView setCaptureEnabled:!canAppendToLog];
}

+ (void)setCaptureEnabled:(BOOL)enabled {
    canAppendToLog = enabled;
    UINavigationItem *item = current.navigationBar.items.firstObject;
    if (item) {
        item.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
                enabled ? UIBarButtonSystemItemPause : UIBarButtonSystemItemPlay
             target:current action:@selector(actionStartStopLogOutput)];
    }
}

+ (BOOL)captureEnabled {
    return canAppendToLog;
}

- (void)actionToggleLogOutput {
    if (fatalErrorOccurred) {
        [UIApplication.sharedApplication performSelector:@selector(suspend)];
        dispatch_group_leave(fatalExitGroup);
        return;
    }

    UIView *navView = self.navController.view;
    // The navigation controller view is the visible container (not `self`),
    // because `self` must stay outside the navController -> rootVC -> view
    // retain cycle. Animate the container instead.
    UIViewAnimationOptions opt = navView.hidden ? UIViewAnimationOptionCurveEaseOut : UIViewAnimationOptionCurveEaseIn;
    [UIView transitionWithView:navView duration:0.4 options:opt animations:^(void){
        CGRect frame = navView.frame;
        frame.origin.y = navView.hidden ? 0 : self.frame.size.height;
        navView.hidden = NO;
        navView.frame = frame;
    } completion: ^(BOOL finished) {
        navView.hidden = navView.frame.origin.y != 0;
    }];
}

+ (void)_appendToLog:(NSString *)line {
    if (line.length == 0 || !logLines) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchLogLineDidAppendNotification object:nil userInfo:@{@"line": line}];
    PLLogOutputView *view = current;
    if (!view) {
        // No live log panel: keep the buffer trimmed and drop the line instead
        // of growing a static array for the rest of the process.
        if (logLines.count >= kMaxLogLines) {
            [logLines removeObjectsInRange:NSMakeRange(0, logLines.count - kMaxLogLines + 1)];
        }
        [logLines addObject:line];
        return;
    }

    // Trim in batches so a capped panel does not reload the table for every
    // single line once it reaches the limit.
    if (logLines.count >= kMaxLogLines) {
        NSUInteger drop = MAX((NSUInteger)1, kMaxLogLines / 10);
        [logLines removeObjectsInRange:NSMakeRange(0, MIN(drop, logLines.count))];
        [logLines addObject:line];
        UIView.animationsEnabled = NO;
        [view.logTableView reloadData];
        UIView.animationsEnabled = YES;
        [view.logTableView scrollToRowAtIndexPath:
            [NSIndexPath indexPathForRow:logLines.count - 1 inSection:0]
            atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:logLines.count inSection:0];
    [logLines addObject:line];
    UIView.animationsEnabled = NO;
    [view.logTableView beginUpdates];
    [view.logTableView
        insertRowsAtIndexPaths:@[indexPath]
        withRowAnimation:UITableViewRowAnimationNone];
    [view.logTableView endUpdates];
    UIView.animationsEnabled = YES;

    [view.logTableView 
        scrollToRowAtIndexPath:indexPath
        atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

+ (NSString *)fullLogText {
    if (!logLines.count) return @"";
    return [logLines componentsJoinedByString:@"\n"];
}

+ (void)appendToLog:(NSString *)string {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSArray *lines = [string componentsSeparatedByCharactersInSet:
            NSCharacterSet.newlineCharacterSet];
        for (NSString *line in lines) {
            [self _appendToLog:line];
        }
    });
}

+ (void)handleExitCode:(int)code {
    if (code != 0) {
        [[PerfRecorder shared] noteCrash];
    }
    dispatch_async(dispatch_get_main_queue(), ^(void){
        UIWindow *window = UIWindow.mainWindow;
        if (!window) {
            window = [UIApplication.sharedApplication windows].firstObject;
        }
        UIViewController *presenter = window.rootViewController;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
        CrashScreenViewController *crashVC = [[CrashScreenViewController alloc] initWithExitCode:code];
        crashVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:crashVC animated:YES completion:nil];
    });
}

@end
