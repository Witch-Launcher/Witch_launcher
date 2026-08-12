#import "AmethystRootViewController.h"
#import "TopBarView.h"
#import "RightPanelViewController.h"
#import "ThemeManager.h"
#import "TransitionAnimator.h"
#import "MainCoordinator.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import <AVFoundation/AVFoundation.h>

@interface AmethystRootViewController () <RightPanelDelegate, TopBarDelegate>
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
@end

@implementation AmethystRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
}

- (void)setupViews {
    _topBar = [[TopBarView alloc] initWithFrame:CGRectZero];
    _topBar.delegate = self;
    [self.view addSubview:_topBar];

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

    _sidebarBorder = [[UIView alloc] init];
    [self.view addSubview:_sidebarBorder];

    _contentContainer = [[UIView alloc] init];
    _contentContainer.clipsToBounds = YES;
    [self.view addSubview:_contentContainer];

    _rightPanelVC = [[RightPanelViewController alloc] init];
    _rightPanelVC.delegate = self;
    [self addChildViewController:_rightPanelVC];
    [self.view addSubview:_rightPanelVC.view];
    [_rightPanelVC didMoveToParentViewController:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat topBarHeight = 44.0;
    CGFloat sidebarWidth = 48.0;
    CGFloat rightPanelWidth = 180.0;

    CGRect bounds = self.view.bounds;
    if (bounds.size.width == 0 || bounds.size.height == 0) return;

    UIEdgeInsets safeArea = self.view.safeAreaInsets;

    CGFloat topBarY = safeArea.top;

    BOOL isLandscape = bounds.size.width > bounds.size.height;
    CGFloat leftInset = isLandscape ? safeArea.left : 0;
    CGFloat rightInset = isLandscape ? safeArea.right : 0;

    CGFloat contentTop = topBarY + topBarHeight;
    CGFloat contentHeight = bounds.size.height - contentTop - safeArea.bottom;
    CGFloat contentWidth = bounds.size.width - leftInset - sidebarWidth - 1 - rightPanelWidth - rightInset;

    _topBar.frame = CGRectMake(leftInset, topBarY, bounds.size.width - leftInset - rightInset, topBarHeight);

    _backgroundImageView.frame = bounds;
    _backgroundVideoView.frame = bounds;
    _backgroundVideoLayer.frame = _backgroundVideoView.bounds;

    CGFloat sidebarX = leftInset;
    _sidebarVC.view.frame = CGRectMake(sidebarX, contentTop, sidebarWidth, contentHeight);
    _sidebarBorder.frame = CGRectMake(sidebarX + sidebarWidth, contentTop, 1, contentHeight);

    CGFloat rightX = bounds.size.width - rightPanelWidth - rightInset;
    _rightPanelVC.view.frame = CGRectMake(rightX, contentTop, rightPanelWidth, contentHeight);

    _contentContainer.frame = CGRectMake(sidebarX + sidebarWidth + 1, contentTop, contentWidth, contentHeight);

    if (self.currentContentVC) {
        self.currentContentVC.view.frame = _contentContainer.bounds;
    }

    if (!self.didInitialLayout) {
        self.didInitialLayout = YES;
        [self.coordinator start];
    }
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation UINavigationController (LockLandscape)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return amethyst_orientation_mask();
}
@end
