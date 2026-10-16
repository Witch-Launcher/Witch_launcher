#import "AmethystRootViewController.h"
#import "TopBarView.h"
#import "RightPanelViewController.h"
#import "ThemeManager.h"
#import "TransitionAnimator.h"
#import "MainCoordinator.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "AmethystBlurView.h"
#import "DownloadManager.h"
#import "HapticManager.h"
#import "PLProfiles.h"
#import "VersionDirectoryManager.h"
#import "authenticator/BaseAuthenticator.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@interface AmethystRootViewController () <RightPanelDelegate, TopBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) TopBarView *topBar;
@property (nonatomic) SidebarViewController *sidebarVC;
@property (nonatomic) RightPanelViewController *rightPanelVC;
@property (nonatomic) UIView *contentContainer;
@property (nonatomic) UIViewController *currentContentVC;
@property (nonatomic) UIView *sidebarBorder;
@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic) UIView *backgroundVideoView;
@property (nonatomic) AVPlayerLayer *backgroundVideoLayer;
@property (nonatomic) AVPlayer *backgroundVideoPlayer;
@property (nonatomic) BOOL didInitialLayout;
@property (nonatomic) CAShapeLayer *shellBorder;
@property (nonatomic) NSUInteger switchToken;
// Portrait-only floating launch button (right panel is hidden in portrait).
@property (nonatomic) UIButton *floatingLaunchBtn;
@property (nonatomic) BOOL floatingLaunchIsCancel;
// Portrait quick panel: versions + account, slides in from the right.
@property (nonatomic) UIButton *quickPanelBtn;
@property (nonatomic) UIView *quickDim;
@property (nonatomic) UIView *quickPanel;
@property (nonatomic) UITableView *quickTable;
@property (nonatomic) UIButton *quickAccountBtn;
@property (nonatomic) NSArray<NSString *> *quickVersions;
@property (nonatomic) BOOL quickPanelOpen;
@end

@implementation AmethystRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFloatingLaunch) name:DownloadTasksDidChangeNotification object:nil];
    [self updateColors];
    [self updateFloatingLaunch];
}

- (void)setupViews {
    _topBar = [[TopBarView alloc] initWithFrame:CGRectZero];
    _topBar.delegate = self;
    [self.view addSubview:_topBar];
    [AmethystBlurView installInView:_topBar prefKey:@"amethyst_topbar_blur"];

    _backgroundImageView = [[UIImageView alloc] init];
    _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    _backgroundImageView.clipsToBounds = YES;
    _backgroundImageView.hidden = YES;
    [self.view insertSubview:_backgroundImageView atIndex:0];

    _backgroundVideoView = [[UIView alloc] init];
    _backgroundVideoView.hidden = YES;
    [self.view insertSubview:_backgroundVideoView atIndex:0];
    _backgroundVideoLayer = [AVPlayerLayer layer];
    _backgroundVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _backgroundVideoLayer.backgroundColor = UIColor.clearColor.CGColor;
    [_backgroundVideoView.layer addSublayer:_backgroundVideoLayer];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundVideoDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundVideoDidEnd:) name:UIApplicationDidBecomeActiveNotification object:nil];

    _sidebarVC = [[SidebarViewController alloc] init];
    _sidebarVC.delegate = self;
    [self addChildViewController:_sidebarVC];
    [self.view addSubview:_sidebarVC.view];
    [_sidebarVC didMoveToParentViewController:self];
    [AmethystBlurView installInView:_sidebarVC.view prefKey:@"amethyst_sidebar_blur"];

    _sidebarBorder = [[UIView alloc] init];
    _sidebarBorder.hidden = YES; // superseded by floating borders
    [self.view addSubview:_sidebarBorder];

    _contentContainer = [[UIView alloc] init];
    _contentContainer.clipsToBounds = YES;
    [self.view addSubview:_contentContainer];

    _rightPanelVC = [[RightPanelViewController alloc] init];
    _rightPanelVC.delegate = self;
    [self addChildViewController:_rightPanelVC];
    [self.view addSubview:_rightPanelVC.view];
    [_rightPanelVC didMoveToParentViewController:self];
    [AmethystBlurView installInView:_rightPanelVC.view prefKey:@"amethyst_rightpanel_blur"];

    // Portrait floating launch: single circle overlay (panel hidden in portrait).
    _floatingLaunchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _floatingLaunchBtn.backgroundColor = ThemeManager.shared.accentColor;
    [_floatingLaunchBtn setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    _floatingLaunchBtn.tintColor = ThemeManager.shared.buttonTextColor;
    _floatingLaunchBtn.layer.cornerRadius = 32;
    _floatingLaunchBtn.clipsToBounds = NO;
    _floatingLaunchBtn.layer.shadowColor = UIColor.blackColor.CGColor;
    _floatingLaunchBtn.layer.shadowOpacity = 0.30;
    _floatingLaunchBtn.layer.shadowRadius = 12;
    _floatingLaunchBtn.layer.shadowOffset = CGSizeMake(0, 4);
    _floatingLaunchBtn.accessibilityLabel = @"Play";
    _floatingLaunchBtn.hidden = YES;
    [_floatingLaunchBtn addTarget:self action:@selector(floatingLaunchTapped) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(floatingLaunchLongPressed:)];
    [_floatingLaunchBtn addGestureRecognizer:lp];
    [self.view addSubview:_floatingLaunchBtn];

    // Portrait quick-panel trigger (versions + account).
    _quickPanelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _quickPanelBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    [_quickPanelBtn setImage:[UIImage systemImageNamed:@"list.bullet"] forState:UIControlStateNormal];
    _quickPanelBtn.tintColor = ThemeManager.shared.accentColor;
    _quickPanelBtn.layer.cornerRadius = 24;
    _quickPanelBtn.clipsToBounds = NO;
    _quickPanelBtn.layer.shadowColor = UIColor.blackColor.CGColor;
    _quickPanelBtn.layer.shadowOpacity = 0.30;
    _quickPanelBtn.layer.shadowRadius = 10;
    _quickPanelBtn.layer.shadowOffset = CGSizeMake(0, 3);
    _quickPanelBtn.layer.borderWidth = 1;
    _quickPanelBtn.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.35].CGColor;
    _quickPanelBtn.accessibilityLabel = @"Versions and account";
    _quickPanelBtn.hidden = YES;
    [_quickPanelBtn addTarget:self action:@selector(toggleQuickPanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_quickPanelBtn];

    // Quick panel: dim + card sliding from the right edge.
    _quickDim = [[UIView alloc] init];
    _quickDim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    _quickDim.alpha = 0;
    _quickDim.hidden = YES;
    [_quickDim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideQuickPanel)]];
    [self.view addSubview:_quickDim];

    _quickPanel = [[UIView alloc] init];
    _quickPanel.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _quickPanel.layer.cornerRadius = 18;
    _quickPanel.clipsToBounds = YES;
    _quickPanel.layer.borderWidth = 1;
    _quickPanel.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.30].CGColor;
    _quickPanel.hidden = YES;
    [self.view addSubview:_quickPanel];

    UILabel *quickTitle = [[UILabel alloc] init];
    quickTitle.translatesAutoresizingMaskIntoConstraints = NO;
    quickTitle.text = @"Versions & Account";
    quickTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    quickTitle.textColor = ThemeManager.shared.primaryTextColor;
    quickTitle.tag = 9001;
    [_quickPanel addSubview:quickTitle];

    UIButton *quickClose = [UIButton buttonWithType:UIButtonTypeSystem];
    quickClose.translatesAutoresizingMaskIntoConstraints = NO;
    [quickClose setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    quickClose.tintColor = ThemeManager.shared.secondaryTextColor;
    [quickClose addTarget:self action:@selector(hideQuickPanel) forControlEvents:UIControlEventTouchUpInside];
    [_quickPanel addSubview:quickClose];

    _quickAccountBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _quickAccountBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _quickAccountBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _quickAccountBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_quickAccountBtn addTarget:self action:@selector(quickAccountTapped) forControlEvents:UIControlEventTouchUpInside];
    [_quickPanel addSubview:_quickAccountBtn];

    _quickTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _quickTable.translatesAutoresizingMaskIntoConstraints = NO;
    _quickTable.delegate = self;
    _quickTable.dataSource = self;
    _quickTable.backgroundColor = [UIColor clearColor];
    _quickTable.rowHeight = 48;
    [_quickPanel addSubview:_quickTable];

    [NSLayoutConstraint activateConstraints:@[
        [quickTitle.topAnchor constraintEqualToAnchor:_quickPanel.topAnchor constant:14],
        [quickTitle.leadingAnchor constraintEqualToAnchor:_quickPanel.leadingAnchor constant:16],
        [quickClose.centerYAnchor constraintEqualToAnchor:quickTitle.centerYAnchor],
        [quickClose.trailingAnchor constraintEqualToAnchor:_quickPanel.trailingAnchor constant:-12],
        [quickClose.widthAnchor constraintEqualToConstant:28],
        [quickClose.heightAnchor constraintEqualToConstant:28],
        [_quickAccountBtn.topAnchor constraintEqualToAnchor:quickTitle.bottomAnchor constant:8],
        [_quickAccountBtn.leadingAnchor constraintEqualToAnchor:_quickPanel.leadingAnchor constant:16],
        [_quickAccountBtn.trailingAnchor constraintEqualToAnchor:_quickPanel.trailingAnchor constant:-16],
        [_quickAccountBtn.heightAnchor constraintEqualToConstant:44],
        [_quickTable.topAnchor constraintEqualToAnchor:_quickAccountBtn.bottomAnchor constant:8],
        [_quickTable.leadingAnchor constraintEqualToAnchor:_quickPanel.leadingAnchor constant:8],
        [_quickTable.trailingAnchor constraintEqualToAnchor:_quickPanel.trailingAnchor constant:-8],
        [_quickTable.bottomAnchor constraintEqualToAnchor:_quickPanel.bottomAnchor constant:-12],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(quickVersionsChanged) name:@"VersionDidChangeNotification" object:nil];

    // One continuous stroke around the whole shell — no seams at junctions.
    // CRITICAL: CAShapeLayer defaults to an OPAQUE BLACK fillColor. The
    // even-odd path below fills the entire ring where the top/left/right
    // bars live, so without clearing it the border layer paints a solid
    // black slab over all three bars ("đen xì").
    _shellBorder = [[CAShapeLayer alloc] init];
    _shellBorder.fillColor = UIColor.clearColor.CGColor;
    _shellBorder.fillRule = kCAFillRuleEvenOdd;
    _shellBorder.lineJoin = kCALineJoinRound;
    [self.view.layer addSublayer:_shellBorder];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat topBarHeight = 44.0;
    CGFloat sidebarWidth = 48.0;
    // Portrait: collapse the 180pt right panel (it squeezes content down to
    // ~150pt on phones) and show the floating circular launch button instead.
    // Landscape keeps the exact current layout.
    CGRect bounds = self.view.bounds;
    if (bounds.size.width == 0 || bounds.size.height == 0) return;
    BOOL isPortrait = bounds.size.width < bounds.size.height;
    CGFloat rightPanelWidth = isPortrait ? 0.0 : 180.0;
    _rightPanelVC.view.hidden = isPortrait;
    _floatingLaunchBtn.hidden = !isPortrait;
    _quickPanelBtn.hidden = !isPortrait;
    if (!isPortrait && _quickPanelOpen) {
        _quickPanelOpen = NO;
        _quickPanel.hidden = YES;
        _quickDim.hidden = YES;
    }
    // Seamless shell: bars attach edge-to-edge with safe-area-aware insets
    // (notch / Dynamic Island are handled via safeArea, no shrinking).
    // Gaps are user-tunable (Appearance > Shell edge margin / Panel spacing).
    NSUserDefaults *shellDefs = [NSUserDefaults standardUserDefaults];
    CGFloat fGap = MAX(0.0, MIN([shellDefs floatForKey:@"amethyst_shell_gap"], 12.0));
    CGFloat innerGap = MAX(0.0, MIN([shellDefs floatForKey:@"amethyst_shell_inner_gap"], 12.0));

    UIEdgeInsets safeArea = self.view.safeAreaInsets;

    CGFloat topBarY = safeArea.top;

    BOOL isLandscape = bounds.size.width > bounds.size.height;
    CGFloat leftInset = isLandscape ? safeArea.left : 0;
    CGFloat rightInset = isLandscape ? safeArea.right : 0;

    CGFloat frameX = leftInset + fGap;
    CGFloat frameW = bounds.size.width - leftInset - rightInset - fGap * 2;
    CGFloat contentTop = topBarY + 2 + topBarHeight; // flush under top bar
    CGFloat contentHeight = bounds.size.height - contentTop - safeArea.bottom - fGap;

    _topBar.frame = CGRectMake(frameX, topBarY + 2, frameW, topBarHeight);
    [self styleFloatingView:_topBar corners:kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner];

    _backgroundImageView.frame = bounds;
    _backgroundVideoView.frame = bounds;
    _backgroundVideoLayer.frame = _backgroundVideoView.bounds;

    _sidebarVC.view.frame = CGRectMake(frameX, contentTop, sidebarWidth, contentHeight);
    // Square top corners: the bar sits flush under the top bar — rounding the
    // T-junction leaves ugly notches. Only the bottom outer corner is rounded.
    [self styleFloatingView:_sidebarVC.view corners:kCALayerMinXMaxYCorner];
    _sidebarBorder.hidden = YES;

    _rightPanelVC.view.frame = CGRectMake(frameX + frameW - rightPanelWidth, contentTop, rightPanelWidth, contentHeight);
    [self styleFloatingView:_rightPanelVC.view corners:kCALayerMaxXMaxYCorner];

    _contentContainer.frame = CGRectMake(frameX + sidebarWidth + innerGap,
                                         contentTop,
                                         frameW - sidebarWidth - rightPanelWidth - innerGap * 2,
                                         contentHeight);

    if (self.currentContentVC) {
        self.currentContentVC.view.frame = _contentContainer.bounds;
    }

    // Portrait floating launch circle, bottom-right above the home indicator.
    if (isPortrait) {
        CGFloat btnSize = 64.0;
        CGFloat margin = 16.0;
        _floatingLaunchBtn.frame = CGRectMake(bounds.size.width - rightInset - margin - btnSize,
                                              bounds.size.height - safeArea.bottom - margin - btnSize,
                                              btnSize, btnSize);
        _quickPanelBtn.frame = CGRectMake(bounds.size.width - rightInset - margin - 48,
                                          bounds.size.height - safeArea.bottom - margin - btnSize - 12 - 48,
                                          48, 48);
        [self.view bringSubviewToFront:_quickDim];
        [self.view bringSubviewToFront:_quickPanel];
        [self.view bringSubviewToFront:_quickPanelBtn];
        [self.view bringSubviewToFront:_floatingLaunchBtn];
        [self layoutQuickPanel:_quickPanelOpen];
    }

    [self updateShellBorderPath];

    if (!self.didInitialLayout) {
        self.didInitialLayout = YES;
        [self.coordinator start];
    }
}

- (void)updateShellBorderPath {
    if (!_shellBorder) return;
    if (!ThemeManager.shared.uiBorderEnabled) {
        _shellBorder.hidden = YES;
        _shellBorder.path = NULL;
        return;
    }
    _shellBorder.hidden = NO;
    CGFloat w = MAX(0.0f, MIN([[NSUserDefaults standardUserDefaults] floatForKey:@"amethyst_bar_border_width"], 4.0f));
    _shellBorder.lineWidth = w;
    _shellBorder.strokeColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.45].CGColor;
    _shellBorder.frame = self.view.bounds;

    CGRect outer = CGRectMake(_topBar.frame.origin.x, _topBar.frame.origin.y,
                              _topBar.frame.size.width,
                              CGRectGetMaxY(_rightPanelVC.view.frame) - _topBar.frame.origin.y);
    UIBezierPath *outerPath = [UIBezierPath bezierPathWithRoundedRect:outer
                                                   byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomRight | UIRectCornerBottomLeft
                                                         cornerRadii:CGSizeMake(16, 16)];
    UIBezierPath *innerPath = [UIBezierPath bezierPathWithRoundedRect:_contentContainer.frame
                                                    byRoundingCorners:UIRectCornerAllCorners
                                                          cornerRadii:CGSizeMake(12, 12)];
    UIBezierPath *combined = [UIBezierPath bezierPath];
    [combined appendPath:outerPath];
    [combined appendPath:innerPath];

    // CALayer's path setter copies internally; the getter does NOT hand out
    // ownership, so there is nothing to release here (releasing caused an
    // over-release crash on first CA commit).
    _shellBorder.path = combined.CGPath;
}

- (void)styleFloatingView:(UIView *)v corners:(CACornerMask)corners {
    v.layer.cornerRadius = ThemeManager.shared.uiBorderCornerRadius;
    v.layer.maskedCorners = corners;
    // User-adjustable border thickness (Appearance > Bar Border Thickness).
    v.clipsToBounds = YES;
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.view setNeedsLayout];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return amethyst_orientation_mask();
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.backgroundColor;
    _sidebarBorder.backgroundColor = theme.separatorColor;
    [self styleFloatingView:_topBar corners:kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner];
    [self styleFloatingView:_sidebarVC.view corners:kCALayerMinXMaxYCorner];
    [self styleFloatingView:_rightPanelVC.view corners:kCALayerMaxXMaxYCorner];
    [self updateShellBorderPath];
    [self.view setNeedsLayout];
    [self updateFloatingLaunch];
    _quickPanel.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _quickPanelBtn.tintColor = ThemeManager.shared.accentColor;
    [_quickTable reloadData];
    if (theme.backgroundVideoURL) {
        [self setupBackgroundVideo:theme.backgroundVideoURL];
        _backgroundImageView.hidden = YES;
        _backgroundVideoView.hidden = NO;
    } else if (theme.backgroundImage) {
        [self stopBackgroundVideo];
        _backgroundImageView.image = theme.blurredBackgroundImage ?: theme.backgroundImage;
        _backgroundImageView.hidden = NO;
        _backgroundVideoView.hidden = YES;
    } else {
        [self stopBackgroundVideo];
        _backgroundImageView.hidden = YES;
        _backgroundVideoView.hidden = YES;
    }
}

- (void)setupBackgroundVideo:(NSURL *)videoURL {
    if (_backgroundVideoPlayer.currentItem && [_backgroundVideoPlayer.currentItem.asset isKindOfClass:[AVURLAsset class]]) {
        AVURLAsset *asset = (AVURLAsset *)_backgroundVideoPlayer.currentItem.asset;
        if ([asset.URL.path isEqualToString:videoURL.path]) {
            [_backgroundVideoPlayer play];
            return;
        }
    }
    _backgroundVideoPlayer = [AVPlayer playerWithURL:videoURL];
    _backgroundVideoPlayer.muted = YES;
    _backgroundVideoPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _backgroundVideoLayer.player = _backgroundVideoPlayer;
    [_backgroundVideoPlayer play];
}

- (void)stopBackgroundVideo {
    [_backgroundVideoPlayer pause];
    _backgroundVideoLayer.player = nil;
    _backgroundVideoPlayer = nil;
}

- (void)backgroundVideoDidEnd:(NSNotification *)notification {
    if (notification.name == AVPlayerItemDidPlayToEndTimeNotification) {
        AVPlayerItem *item = notification.object;
        if (item != _backgroundVideoPlayer.currentItem) return;
    }
    if (_backgroundVideoPlayer && _backgroundVideoPlayer.currentItem) {
        [_backgroundVideoPlayer seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            [_backgroundVideoPlayer play];
        }];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)switchContentTo:(UIViewController *)vc animated:(BOOL)animated {
    if (self.currentContentVC == vc) return;

    UIViewController *oldVC = self.currentContentVC;
    // Token guards rapid A->B->A switches: a stale animation completion must
    // never remove the view of the currently visible controller (blank tab).
    NSUInteger token = ++_switchToken;

    [self.contentContainer.layer removeAllAnimations];
    for (UIView *subview in self.contentContainer.subviews) {
        subview.transform = CGAffineTransformIdentity;
        subview.alpha = 1.0;
    }

    [self addChildViewController:vc];
    UIView *vcView = vc.view;
    vcView.transform = CGAffineTransformIdentity;
    vcView.alpha = 1.0;
    vcView.frame = self.contentContainer.bounds;
    vcView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentContainer addSubview:vcView];

    if (animated && oldVC && oldVC.view.superview == self.contentContainer) {
        vcView.alpha = 0;
        vcView.transform = CGAffineTransformMakeTranslation(30, 0);
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            vcView.alpha = 1;
            vcView.transform = CGAffineTransformIdentity;
            oldVC.view.alpha = 0;
            oldVC.view.transform = CGAffineTransformMakeTranslation(-30, 0);
        } completion:^(BOOL finished) {
            if (token != self->_switchToken || self->_currentContentVC == oldVC) {
                // Superseded (or old became current again): only detach old if
                // it is neither visible nor current.
                if (self->_currentContentVC != oldVC && oldVC.view.superview == self.contentContainer && oldVC != vc) {
                    [oldVC willMoveToParentViewController:nil];
                    [oldVC.view removeFromSuperview];
                    [oldVC removeFromParentViewController];
                }
                return;
            }
            [oldVC willMoveToParentViewController:nil];
            [oldVC.view removeFromSuperview];
            [oldVC removeFromParentViewController];
            [vc didMoveToParentViewController:self];
        }];
    } else {
        if (oldVC) {
            [oldVC willMoveToParentViewController:nil];
            [oldVC.view removeFromSuperview];
            [oldVC removeFromParentViewController];
        }
        [vc didMoveToParentViewController:self];
    }

    _currentContentVC = vc;
}

- (void)presentContentAsSheet:(UIViewController *)vc {
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (vc.popoverPresentationController) {
        vc.popoverPresentationController.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pushContent:(UIViewController *)vc animated:(BOOL)animated {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    nav.transitioningDelegate = self.coordinator;
    [self presentViewController:nav animated:animated completion:nil];
}

#pragma mark - SidebarDelegate

- (void)sidebarDidSelectTab:(SidebarTab)tab {
    [self.coordinator switchToTab:tab];
}

#pragma mark - TopBarDelegate

- (void)topBarDidTapFileManager {
    [self.coordinator showFileManager];
}

- (void)topBarDidTapSettings {
    [self.coordinator showSettings];
}

- (void)topBarDidTapDownloadHub {
    [self.coordinator showDownloadHub];
}

#pragma mark - RightPanelDelegate

- (void)rightPanelDidTapAccount {
    [self.coordinator showAccount];
}

- (void)rightPanelDidTapLaunch {
    [self.coordinator launchGame];
}

- (void)rightPanelDidTapDownloadHub {
    [self.coordinator showDownloadHub];
}

- (void)rightPanelDidTapFileManager {
    [self.coordinator showFileManager];
}

- (void)rightPanelDidTapSettings {
    [self.coordinator showSettings];
}

- (void)rightPanelDidAddVersion {
    [self.coordinator showAddVersion];
}

- (void)rightPanelDidRemoveVersion:(NSString *)versionName {
    [self.coordinator removeVersion:versionName];
}

- (void)rightPanelDidSelectVersion:(NSString *)versionName {
    [self.coordinator selectVersion:versionName];
}

- (void)rightPanelDidEditVersion:(NSString *)versionName {
    [self.coordinator editVersion:versionName];
}

#pragma mark - Portrait quick panel (versions + account)

- (CGFloat)quickPanelWidth {
    return MIN(300.0, self.view.bounds.size.width * 0.82);
}

- (void)layoutQuickPanel:(BOOL)visible {
    UIEdgeInsets safeArea = self.view.safeAreaInsets;
    CGFloat w = [self quickPanelWidth];
    CGFloat top = safeArea.top + 2 + 44.0;
    CGFloat h = self.view.bounds.size.height - top - safeArea.bottom - 5.0;
    _quickDim.frame = self.view.bounds;
    CGFloat x = visible ? (self.view.bounds.size.width - w - 5.0) : self.view.bounds.size.width;
    _quickPanel.frame = CGRectMake(x, top, w, MAX(h, 200));
}

- (void)toggleQuickPanel {
    if (_quickPanelOpen) [self hideQuickPanel];
    else [self showQuickPanel];
}

- (void)showQuickPanel {
    [[HapticManager shared] play:HapticTypeLight];
    [self quickVersionsChanged];
    NSString *name = BaseAuthenticator.current.authData[@"username"];
    [_quickAccountBtn setTitle:(name.length > 0 ? name : @"Add account") forState:UIControlStateNormal];
    [_quickAccountBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    _quickPanelOpen = YES;
    _quickDim.hidden = NO;
    _quickPanel.hidden = NO;
    [self.view bringSubviewToFront:_quickDim];
    [self.view bringSubviewToFront:_quickPanel];
    [self.view bringSubviewToFront:_quickPanelBtn];
    [self.view bringSubviewToFront:_floatingLaunchBtn];
    [self layoutQuickPanel:NO];
    _quickDim.alpha = 0;
    [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self layoutQuickPanel:YES];
        self->_quickDim.alpha = 1;
    } completion:nil];
}

- (void)hideQuickPanel {
    if (!_quickPanelOpen) return;
    [[HapticManager shared] play:HapticTypeLight];
    _quickPanelOpen = NO;
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        [self layoutQuickPanel:NO];
        self->_quickDim.alpha = 0;
    } completion:^(BOOL finished) {
        self->_quickPanel.hidden = YES;
        self->_quickDim.hidden = YES;
    }];
}

- (void)quickVersionsChanged {
    NSString *versionsDir = VersionDirectoryManager.shared.versionsRootPath;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:versionsDir error:nil] ?: @[];
    NSMutableArray *versions = [NSMutableArray array];
    for (NSString *item in contents) {
        NSString *fullPath = [versionsDir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [versions addObject:item];
        }
    }
    _quickVersions = [versions sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [_quickTable reloadData];
}

- (NSString *)displayNameForVersion:(NSString *)ver {
    for (NSString *key in PLProfiles.current.profiles) {
        NSDictionary *p = PLProfiles.current.profiles[key];
        if ([p[@"lastVersionId"] isEqualToString:ver] && [p[@"name"] isKindOfClass:[NSString class]]) {
            return p[@"name"];
        }
    }
    VersionProfile *profile = [VersionProfile profileWithVersionId:ver];
    NSString *mcVersion = profile.mcVersion ?: ver;
    if (![profile.modLoader isEqualToString:@"Vanilla"] && profile.modLoader.length > 0) {
        return [NSString stringWithFormat:@"%@-%@", mcVersion, profile.modLoader];
    }
    return mcVersion;
}

- (void)quickAccountTapped {
    [self hideQuickPanel];
    [self rightPanelDidTapAccount];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == _quickTable) return _quickVersions.count + 1;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _quickTable) return [[UITableViewCell alloc] init];
    static NSString *cellId = @"QuickVersionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    }
    if (indexPath.row < (NSInteger)_quickVersions.count) {
        NSString *ver = _quickVersions[indexPath.row];
        cell.textLabel.text = [self displayNameForVersion:ver];
        BOOL isCurrent = [ver isEqualToString:VersionDirectoryManager.shared.currentVersion];
        cell.accessoryType = isCurrent ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.textLabel.textColor = isCurrent ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;
    } else {
        cell.textLabel.text = @"Add version";
        cell.textLabel.textColor = ThemeManager.shared.accentColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _quickTable) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)_quickVersions.count) {
        [self.coordinator selectVersion:_quickVersions[indexPath.row]];
        [_quickTable reloadData];
    } else {
        [self hideQuickPanel];
        [self.coordinator showAddVersion];
    }
}

- (NSArray *)tableView:(UITableView *)tableView trailingSwipeActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _quickTable || indexPath.row >= (NSInteger)_quickVersions.count) return nil;
    NSString *ver = _quickVersions[indexPath.row];
    UIContextualAction *edit = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Setting" handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [self hideQuickPanel];
        [self.coordinator editVersion:ver];
        done(YES);
    }];
    edit.image = [UIImage systemImageNamed:@"gearshape.fill"];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [self.coordinator removeVersion:ver];
        done(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash"];
    return @[del, edit];
}

#pragma mark - Portrait floating launch

- (void)floatingLaunchTapped {
    if (_floatingLaunchIsCancel) {
        [[HapticManager shared] play:HapticTypeHeavy];
        [DownloadManager.shared cancelAllTasks];
        return;
    }
    [[HapticManager shared] play:HapticTypeMedium];
    [self rightPanelDidTapLaunch];
}

- (void)floatingLaunchLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [[HapticManager shared] play:HapticTypeLight];
        [self rightPanelDidTapAccount];
    }
}

- (void)updateFloatingLaunch {
    BOOL busy = [DownloadManager.shared activeTasks].count > 0;
    _floatingLaunchIsCancel = busy;
    ThemeManager *theme = ThemeManager.shared;
    if (busy) {
        [_floatingLaunchBtn setImage:[UIImage systemImageNamed:@"stop.fill"] forState:UIControlStateNormal];
        _floatingLaunchBtn.backgroundColor = theme.errorColor;
        _floatingLaunchBtn.accessibilityLabel = @"Cancel downloads (long-press for account)";
    } else {
        [_floatingLaunchBtn setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
        _floatingLaunchBtn.backgroundColor = theme.accentColor;
        _floatingLaunchBtn.accessibilityLabel = @"Play (long-press for account)";
    }
    _floatingLaunchBtn.tintColor = theme.buttonTextColor;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation UINavigationController (LockLandscape)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return amethyst_orientation_mask();
}
@end
