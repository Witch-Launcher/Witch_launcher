#import "CustomControlsViewController.h"
#import "ErrorPresenter.h"
#import "LauncherPreferences.h"
#import "PerfRecorder.h"
#import "SettingsViewController.h"
#import "PLProfiles.h"
#import "SurfaceViewController.h"
#import "utils.h"
#import "AppSheet.h"
#import "WitchLogOverlay.h"

@implementation SurfaceViewController(Navigation)

static CGPoint lastCenterPoint;
- (void)initCategory_Navigation {
    UIPanGestureRecognizer *menuPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightEdge:)];
    menuPanGesture.delegate = self;

    UIView *menuSwipeLineView = [[UIView alloc] initWithFrame:CGRectMake(11.0, self.view.frame.size.height/2 - 100.0, 8.0, 200.0)];
    menuSwipeLineView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    menuSwipeLineView.backgroundColor = UIColor.whiteColor;
    menuSwipeLineView.layer.cornerRadius = 4;
    menuSwipeLineView.userInteractionEnabled = NO;

    UIView *menuSwipeView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width, 0, 30.0, self.view.frame.size.height)];
    menuSwipeView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    menuSwipeView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.1];
    [menuSwipeView addGestureRecognizer:menuPanGesture];
    [menuSwipeView addSubview:menuSwipeLineView];
    [self.rootView addSubview:menuSwipeView];
    self.menuSwipeView = menuSwipeView;

    self.menuArray = @[@"game.menu.force_close", @"game.menu.log_output", @"game.menu.custom_controls", @"Settings"];

    self.menuView = [[UITableView alloc] initWithFrame:CGRectMake(self.view.frame.size.width + 30.0, 0, 
        self.view.frame.size.width * 0.3 - 36.0 * 0.7, self.view.frame.size.height)];

    //menuView.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:240.0/255.0 alpha:1];
    self.menuView.dataSource = self;
    self.menuView.delegate = self;
    self.menuView.hidden = YES;
    self.menuView.layer.cornerRadius = 12;
    self.menuView.scrollEnabled = NO;
    self.menuView.separatorInset = UIEdgeInsetsZero;
    // Fixed metrics: default cells adopt the device's Dynamic Type body font,
    // which at accessibility sizes blew the rows up ~3x and wrapped each
    // menu word onto its own line.
    self.menuView.rowHeight = 52;
    [self.view addSubview:self.menuView];
}

- (void)setupCategory_Navigation {
    self.edgeGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightEdge:)];
    self.edgeGesture.edges = UIRectEdgeRight;
    self.edgeGesture.delegate = self;
    [self.touchView addGestureRecognizer:self.edgeGesture];
}

static CGPoint lastCenterPoint;
- (void)animateMenuScale:(CGFloat)scale duration:(CGFloat)duration {
    CGFloat centerX = self.rootView.bounds.size.width / 2;
    CGFloat centerY = self.rootView.bounds.size.height / 2;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        lastCenterPoint.x = centerX * scale;
        self.rootView.center = CGPointMake(lastCenterPoint.x, centerY);
        self.rootView.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
        self.menuView.transform = CGAffineTransformScale(CGAffineTransformIdentity, (1.1-scale)*2.5, (1.1-scale)*2.5);
        self.menuView.frame = CGRectMake(self.rootView.frame.size.width, self.rootView.frame.origin.y, self.menuView.frame.size.width, self.menuView.contentSize.height);
    } completion:^(BOOL finished) {
        self.menuView.hidden = scale == 1.0;
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
        [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (void)refreshMenuItems {
    NSMutableArray *items = [NSMutableArray arrayWithObject:@"game.menu.force_close"];
    // Performance recording is togglable from the in-game menu: offer "start"
    // when idle and "stop" while a session is active.
    if (PerfRecorder.shared.isRecording) {
        [items addObject:@"game.menu.perf_stop"];
    } else {
        [items addObject:@"game.menu.perf_start"];
    }
    [items addObjectsFromArray:@[@"game.menu.log_output", @"game.menu.custom_controls", @"Settings"]];
    self.menuArray = items;
    [self.menuView reloadData];
}

- (void)handleRightEdge:(UIPanGestureRecognizer *)sender {
    // Widget mode owns the right-edge interaction: its menu is opened by
    // tapping the widget, and the navigation strip is hidden. The recognizer
    // can still be re-enabled by loadCustomControls, which used to let the
    // game slide into the 0.7x menu state with no visible strip to drag it
    // back. Reject the gesture and recover if that state is already active.
    if (getPrefBool(@"general.widget_menu")) {
        if (!self.menuView.hidden || fabs(self.rootView.transform.a - 1.0) > 0.001) {
            [self animateMenuScale:1 duration:0.25];
        }
        return;
    }
    if (lastCenterPoint.y == 0) {
        lastCenterPoint.x = self.rootView.center.x;
        lastCenterPoint.y = 1;
    }

    CGFloat centerX = self.rootView.bounds.size.width / 2;
    CGFloat centerY = self.rootView.bounds.size.height / 2;

    CGPoint translation = [sender translationInView:sender.view];

    if (sender.state == UIGestureRecognizerStateBegan) {
        [self refreshMenuItems];
        self.menuView.hidden = NO;
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        self.rootView.center = CGPointMake(lastCenterPoint.x + translation.x/2, centerY + translation.y/10.0);
        CGFloat scale = MAX(0.7, self.rootView.center.x / centerX);
        self.rootView.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);

        self.menuView.frame = CGRectMake(self.rootView.frame.size.width, self.rootView.frame.origin.y, self.menuView.frame.size.width,  self.menuView.contentSize.height);
        // scale is in range of 0.7-1
        // 1.1 - scale produces in range of 0.4-0.1
        // result in transform scale range of 1-0.25
        self.menuView.transform = CGAffineTransformScale(CGAffineTransformIdentity, (1.1-scale)*2.5, (1.1-scale)*2.5);
    } else {
        CGPoint velocity = [sender velocityInView:sender.view];
        CGFloat scale = (velocity.x >= 0) ? 1 : 0.7;

        // calculate duration to produce smooth movement
        // FIXME: any better way?
        CGFloat duration = fabs(self.rootView.center.x - centerX * scale) / centerX + 0.1;
        duration = MIN(0.4, duration);
        //(110 - MIN(100, fabs(velocity.x))) / 100

        [self animateMenuScale:scale duration:duration];
    }
}

- (void)actionForceClose {
    [AppSheet showConfirmWithTitle:nil
                           message:localize(@"game.menu.confirm.force_close", nil)
                      confirmTitle:localize(@"OK", nil)
                       destructive:YES
                         onConfirm:^{
        [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.rootView.center = CGPointMake(self.rootView.bounds.size.width/-2, self.rootView.center.y);
            self.menuView.frame = CGRectMake(self.view.frame.size.width, 0, 0, 0);
        } completion:^(BOOL finished) {
            [[PerfRecorder shared] stopWithReason:PerfStopReasonForceClose];
            if (fatalExitGroup == nil) {
                exit(0);
            } else {
                dispatch_group_leave(fatalExitGroup);
            }
        }];
    }];
}

- (void)actionOpenCustomControls {
    [self animateMenuScale:1 duration:0.5];
    [self.ctrlView removeAllButtons];
    CustomControlsViewController *vc = [[CustomControlsViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.setDefaultCtrl = ^(NSString *name){
        if (PLProfiles.current.selectedProfile[@"defaultTouchCtrl"]) {
            // Save default to current profile. The profile dictionary is only
            // written to disk by -save, so without this call the new default
            // control map is lost on the next launcher start.
            PLProfiles.current.selectedProfile[@"defaultTouchCtrl"] = name;
            [PLProfiles.current save];
        } else {
            // Save default to preferences
            setPrefObject(@"control.default_ctrl", name);
        }
    };
    vc.getDefaultCtrl = ^{
        return [PLProfiles resolveKeyForCurrentProfile:@"defaultTouchCtrl"];
    };
    [self presentViewController:vc animated:NO completion:nil];
}

- (void)actionOpenPreferences {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    // Wrapped in a navigation controller so the Settings sheet keeps its
    // title bar with the Done (Xong) button in-game, like the launcher menu.
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)actionOpenNavigationMenu {
    [self animateMenuScale:0.7 duration:0.3];
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    if (!self.menuView.hidden) {
        return 0;
    }
    return UIRectEdgeBottom | UIRectEdgeRight;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return self.menuView.hidden &&
        getPrefBool(@"debug.debug_hide_home_indicator");
}

- (BOOL)prefersStatusBarHidden {
    return self.menuView.hidden;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    cell.backgroundColor = UIColor.systemFillColor;

    cell.textLabel.text = localize(self.menuArray[indexPath.row], nil);
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    cell.textLabel.adjustsFontForContentSizeCategory = NO;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [self didSelectMenuItem:indexPath.row];
}

- (void)didSelectMenuItem:(int)item {
    NSString *key = (item >= 0 && item < (int)self.menuArray.count) ? self.menuArray[item] : @"";
    if ([key isEqualToString:@"game.menu.force_close"]) {
        [self actionForceClose];
    } else if ([key isEqualToString:@"game.menu.perf_stop"]) {
        [self actionStopRecording];
    } else if ([key isEqualToString:@"game.menu.perf_start"]) {
        [self actionStartRecording];
    } else if ([key isEqualToString:@"game.menu.log_output"]) {
        if (getPrefBool(@"general.overlay_log_in_game")) {
            [[WitchLogOverlay sharedOverlay] toggleInView:self.view];
        } else {
            [self.logOutputView actionToggleLogOutput];
        }
    } else if ([key isEqualToString:@"game.menu.custom_controls"]) {
        [self actionOpenCustomControls];
    } else if ([key isEqualToString:@"Settings"]) {
        [self actionOpenPreferences];
    }
}

- (void)actionStartRecording {
    [[PerfRecorder shared] startManuallyWithMetadata:@{
        @"version": self.metadata[@"id"] ?: @"",
        @"instance": self.metadata[@"instanceName"] ?: @""
    }];
    [self animateMenuScale:1 duration:0.5];
    [ErrorPresenter showToast:localize(@"perf.toast.started", nil) success:YES];
}

- (void)actionStopRecording {
    [[PerfRecorder shared] stopWithReason:PerfStopReasonUser];
    [self animateMenuScale:1 duration:0.5];
    [ErrorPresenter showToast:localize(@"perf.toast.saved", nil) success:YES];
}

- (void)viewWillTransitionToSize_Navigation:(CGRect)frame {
    if (self.rootView.transform.a != 0) {
        CGFloat centerX = self.rootView.bounds.size.width / 2;
        CGFloat centerY = self.rootView.bounds.size.height / 2;
        self.rootView.center = lastCenterPoint = CGPointMake(centerX * self.rootView.transform.a, centerY);
    }

    self.menuView.frame = CGRectMake(self.rootView.frame.size.width, self.rootView.frame.origin.y,
        frame.size.width*0.3 - 30.0*0.7, self.menuView.contentSize.height);
}

- (void)setEdgeSwipeUIHidden:(BOOL)hidden {
    self.menuSwipeView.hidden = hidden;
}

@end
