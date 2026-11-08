#import "LaunchSplashView.h"
#import "utils.h"
#import "ThemeManager.h"
#import "WitchScrollingLogView.h"
#import "PLLogOutputView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSArray<NSString *> *WitchSplashVideoExtensions(void) {
    return @[@"mp4", @"mov", @"m4v"];
}

static NSArray<NSString *> *WitchSplashImageExtensions(void) {
    return @[@"png", @"jpg", @"jpeg", @"heic"];
}

static NSString *WitchSplashPathInDirectory(NSString *directory, NSArray<NSString *> *extensions) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:directory error:nil];
    if (![names isKindOfClass:[NSArray class]]) return nil;
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) continue;
        NSString *ext = name.pathExtension.lowercaseString;
        if ([extensions containsObject:ext]) [matches addObject:name];
    }
    [matches sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString *first = matches.firstObject;
    return first ? [directory stringByAppendingPathComponent:first] : nil;
}

static NSString *WitchSplashPathForExtensions(NSArray<NSString *> *extensions) {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    // One tidy location: Documents/Splash (the ".Splash" hidden twin is also
    // accepted in case the folder was created invisible from the Files app),
    // then the bundled fallback.
    NSString *directory = [documents stringByAppendingPathComponent:@"Splash"];
    NSString *hiddenDirectory = [documents stringByAppendingPathComponent:@".Splash"];
    for (NSString *folder in @[directory, hiddenDirectory]) {
        NSString *found = WitchSplashPathInDirectory(folder, extensions);
        if (found) return found;
    }
    for (NSString *ext in extensions) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"splash" ofType:ext inDirectory:@"Splash"];
        if (path.length > 0) return path;
    }
    return nil;
}

static CGFloat WitchSplashBlurIntensity(void) {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"appearance.splash_blur"];
    return MAX(0.0f, MIN(v, 100.0f)) / 100.0f;
}

static UIBlurEffectStyle WitchSplashBlurStyle(CGFloat t) {
    if (t <= 1.0 / 3.0) return UIBlurEffectStyleSystemUltraThinMaterial;
    if (t <= 2.0 / 3.0) return UIBlurEffectStyleSystemThinMaterial;
    return UIBlurEffectStyleSystemMaterial;
}

static const CFTimeInterval kWordmarkRevealDuration = 0.5;

@interface LaunchSplashView ()
@property (nonatomic, strong, nullable) UIImageView *imageView;
@property (nonatomic, strong, nullable) AVPlayer *player;
@property (nonatomic, strong, nullable) AVPlayerItem *playerItem;
@property (nonatomic, strong, nullable) id<NSObject> playerObserver;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *scrim;

// Bottom cluster (matches the reference layout exactly): brand row is at the
// bottom in normal mode / top-left in log mode; below it the 2-line waiting
// message; the full-width indeterminate progress bar rides the very bottom
// edge.
@property (nonatomic, strong) UIView *brandRow;
@property (nonatomic, strong) UIImageView *markImageView;
@property (nonatomic, strong) UIImageView *wordmarkImageView;
@property (nonatomic, strong) CALayer *wordmarkMask;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *waitingLabel;
@property (nonatomic, strong) UIView *barTrack;
@property (nonatomic, strong) CALayer *barOne;
@property (nonatomic, strong) CALayer *barTwo;
@property (nonatomic, strong) CAGradientLayer *fadeLayer;

// Constraints, normal <-> log mode
@property (nonatomic, strong) NSLayoutConstraint *brandBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *brandTopConstraint;

// Log panel: square-cornered, hairline-bordered rect that spans the free
// space between the brand row (top-left) and the waiting line. Round ink
// buttons (pause / trash) hang outside the panel at the top-right corner.
@property (nonatomic, strong) UIView *logCard;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) WitchScrollingLogView *logTextView;

@property (nonatomic) BOOL mediaActive;
@property (nonatomic) BOOL logMode;
@property (nonatomic) BOOL entrancePlayed;
@property (nonatomic) BOOL wordmarkRevealed;
// Set when the user explicitly paused recording; the panel reopening must
// never override that choice, matching the in-game overlay rule.
@property (nonatomic) BOOL userPausedCapture;
@property (nonatomic) NSUInteger choreographyToken;
@end

@implementation LaunchSplashView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self applyThemeColorsToBackground];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self buildBackground];
    [self buildBottomCluster];
    [self buildLogPanel];
    [self installThreeFingerTap];
    return self;
}

- (void)dealloc {
    [self stopAnimating];
}

- (BOOL)isAccessibilityElement {
    return NO;
}

#pragma mark - Theme

// Everything on this screen follows the user's custom palette: background,
// ink (text + logo + border), and accent (progress fill). The custom splash
// media, when present, still draws above the base color.
- (void)applyThemeColorsToBackground {
    UIColor *bg = ThemeManager.shared.contentBackgroundColor ?: UIColor.blackColor;
    self.backgroundColor = bg;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    // Direct layers and the unconstrained image view would otherwise keep a
    // zero frame — the splash appeared black even with media loaded.
    self.imageView.frame = bounds;
    self.playerLayer.frame = bounds;
    self.fadeLayer.frame = bounds;
}

#pragma mark - Background (video / image / blur + base scrim)

- (void)buildBackground {
    NSString *video = WitchSplashPathForExtensions(WitchSplashVideoExtensions());
    if (video.length > 0) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:video]];
        AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:item];
        player.muted = YES;
        self.player = player;
        self.playerItem = item;
        self.playerObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                         object:item
                          queue:nil
                     usingBlock:^(NSNotification *note) {
            [item seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                [player play];
            }];
        }];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.layer insertSublayer:layer atIndex:0];
        self.playerLayer = layer;
        self.mediaActive = YES;
    } else {
        NSString *image = WitchSplashPathForExtensions(WitchSplashImageExtensions());
        if (image.length > 0) {
            UIImage *actual = [UIImage imageWithContentsOfFile:image];
            if (actual) {
                UIImageView *view = [[UIImageView alloc] initWithImage:actual];
                view.contentMode = UIViewContentModeScaleAspectFill;
                view.clipsToBounds = YES;
                self.imageView = view;
                [self addSubview:view];
                self.mediaActive = YES;
            }
        }
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.hidden = WitchSplashBlurIntensity() <= 0.0f;
    CGFloat blurT = WitchSplashBlurIntensity();
    if (blurT > 0.0f) {
        if (@available(iOS 13.0, *)) {
            blurView.effect = [UIBlurEffect effectWithStyle:WitchSplashBlurStyle(blurT)];
        } else {
            blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
    }
    [self addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    self.blurView = blurView;

    UIView *scrim = [[UIView alloc] init];
    scrim.translatesAutoresizingMaskIntoConstraints = NO;
    scrim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:self.mediaActive ? 0.40 : 0.0];
    [self addSubview:scrim];
    [NSLayoutConstraint activateConstraints:@[
        [scrim.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [scrim.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [scrim.topAnchor constraintEqualToAnchor:self.topAnchor],
        [scrim.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    self.scrim = scrim;

    // Soft gradient behind the bottom cluster: strong at the very bottom
    // edge, dissolving upwards — same treatment as the new log sheet.
    // Falls back to the user's background color so custom palettes never
    // break readability.
    UIColor *tone = [UIColor.blackColor colorWithAlphaComponent:0.92];
    CAGradientLayer *fade = [CAGradientLayer layer];
    fade.colors = @[
        (id)tone.CGColor,
        (id)[tone colorWithAlphaComponent:0.70].CGColor,
        (id)[tone colorWithAlphaComponent:0.32].CGColor,
        (id)[tone colorWithAlphaComponent:0.0].CGColor,
    ];
    fade.locations = @[@0.0, @0.42, @0.78, @1.0];
    [self.layer addSublayer:fade];
    self.fadeLayer = fade;
}

#pragma mark - Bottom cluster (brand -> waiting -> bar)

- (UIColor *)inkColor {
    return ThemeManager.shared.primaryTextColor
        ?: ThemeManager.shared.accentColor
        ?: UIColor.whiteColor;
}

- (void)buildBottomCluster {
    self.brandRow = [[UIView alloc] init];
    self.brandRow.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandRow.backgroundColor = UIColor.clearColor;
    self.brandRow.isAccessibilityElement = NO;
    [self addSubview:self.brandRow];

    // Released as template assets: the mark + wordmark take the user's ink
    // color; one brand variant only.
    UIImage *mark = [[UIImage imageNamed:@"brand-mark"]
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImage *wordmark = [[UIImage imageNamed:@"brand-wordmark"]
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.markImageView = [[UIImageView alloc] initWithImage:mark];
    self.markImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.markImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.markImageView.isAccessibilityElement = YES;
    self.markImageView.accessibilityLabel = @"Witch Launcher";
    [self.brandRow addSubview:self.markImageView];

    self.wordmarkImageView = [[UIImageView alloc] initWithImage:wordmark];
    self.wordmarkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.wordmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.brandRow addSubview:self.wordmarkImageView];

    CGFloat ratio = wordmark.size.width / MAX(1.0, wordmark.size.height);
    CGFloat markRatio = mark.size.width / MAX(1.0, mark.size.height);
    CGFloat wordH = 19.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.markImageView.centerYAnchor constraintEqualToAnchor:self.brandRow.centerYAnchor],
        [self.markImageView.leadingAnchor constraintEqualToAnchor:self.brandRow.leadingAnchor],
        [self.markImageView.heightAnchor constraintEqualToConstant:38.0],
        // Pin the width to the intrinsic aspect, otherwise the image view
        // keeps its intrinsic (huge) width and the glyph floats mid-row.
        [self.markImageView.widthAnchor constraintEqualToAnchor:self.markImageView.heightAnchor multiplier:markRatio],
        [self.wordmarkImageView.centerYAnchor constraintEqualToAnchor:self.brandRow.centerYAnchor],
        [self.wordmarkImageView.leadingAnchor constraintEqualToAnchor:self.markImageView.trailingAnchor constant:12.0],
        [self.wordmarkImageView.heightAnchor constraintEqualToConstant:wordH],
        [self.wordmarkImageView.widthAnchor constraintEqualToConstant:wordH * ratio],
    ]];

    // Launcher version, raised like a superscript at the wordmark's head.
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    self.versionLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold]];
    self.versionLabel.text = [NSString stringWithFormat:@"v%@", ver];
    [self.brandRow addSubview:self.versionLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.versionLabel.firstBaselineAnchor constraintEqualToAnchor:self.wordmarkImageView.topAnchor constant:2.0],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.wordmarkImageView.trailingAnchor constant:5.0],
    ]];
    NSLayoutConstraint *rowH = [self.brandRow.heightAnchor constraintEqualToConstant:38.0];
    rowH.active = YES;

    // Two-line waiting message, straight under the brand row.
    self.waitingLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold]];
    self.waitingLabel.text = localize(@"splash.starting_jvm", nil);
    self.waitingLabel.textAlignment = NSTextAlignmentLeft;
    self.waitingLabel.numberOfLines = 2;
    [self addSubview:self.waitingLabel];
    self.waitingLabel.preferredMaxLayoutWidth = 260.0;

    // Full-width indeterminate progress bar pinned to the very bottom edge
    // (square cut, no rounding). It always runs the classic two-bar
    // accent sweep — no percentage figure is shown.
    UIView *track = [[UIView alloc] init];
    track.translatesAutoresizingMaskIntoConstraints = NO;
    track.backgroundColor = [self.inkColor colorWithAlphaComponent:0.14];
    track.layer.cornerRadius = 0;
    track.layer.masksToBounds = YES;
    self.barTrack = track;
    for (NSInteger i = 0; i < 2; i++) {
        CAGradientLayer *bar = [CAGradientLayer layer];
        UIColor *opaque = ThemeManager.shared.accentColor;
        UIColor *tail = [opaque colorWithAlphaComponent:0.55];
        bar.colors = @[(__bridge id)tail.CGColor, (__bridge id)opaque.CGColor];
        bar.locations = @[@0.0, @1.0];
        bar.startPoint = CGPointMake(0.0, 0.5);
        bar.endPoint = CGPointMake(1.0, 0.5);
        bar.frame = CGRectMake(0, 0, 120.0, 6.0);
        bar.cornerRadius = 0;
        [track.layer addSublayer:bar];
        if (i == 0) self.barOne = bar; else self.barTwo = bar;
    }
    track.isAccessibilityElement = YES;
    track.accessibilityLabel = localize(@"splash.starting_jvm", nil);
    track.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    [self addSubview:track];

    UILayoutGuide *safe = self.safeAreaLayoutGuide;
    self.brandBottomConstraint = [self.brandRow.bottomAnchor constraintEqualToAnchor:self.waitingLabel.topAnchor constant:-10];
    self.brandTopConstraint = [self.brandRow.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12];
    self.brandTopConstraint.active = NO;
    [NSLayoutConstraint activateConstraints:@[
        // Flush to the left edge: the brand hangs right at the margin.
        [self.brandRow.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18.0],
        self.brandBottomConstraint,

        [self.waitingLabel.leadingAnchor constraintEqualToAnchor:self.brandRow.leadingAnchor constant:2.0],
        [self.waitingLabel.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-24.0],
        [self.waitingLabel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-24.0],

        [self.barTrack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.barTrack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.barTrack.heightAnchor constraintEqualToConstant:6.0],
        [self.barTrack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
    [self applyThemeColors];

    // Parked: nothing on screen yet. `startAnimating` choreographs it in.
    self.fadeLayer.opacity = 0.0;
    self.brandRow.alpha = 0.0;
    self.wordmarkMask = [CALayer layer];
    self.wordmarkMask.backgroundColor = UIColor.blackColor.CGColor;
    self.wordmarkMask.frame = CGRectMake(0, 0, 0, wordH * 2.0);
    self.wordmarkImageView.layer.mask = self.wordmarkMask;
    self.versionLabel.alpha = 0.0;
    self.waitingLabel.alpha = 0.0;
    self.waitingLabel.transform = CGAffineTransformMakeTranslation(0, 12);
    self.barTrack.alpha = 0.0;
    self.barTrack.transform = CGAffineTransformMakeTranslation(0, 12);
}

- (void)buildLogPanel {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.clearColor;
    card.layer.cornerRadius = 0;
    card.layer.borderWidth = 2;
    [self addSubview:card];
    self.logCard = card;

    // Round ink buttons hang outside the square panel at the top-right, as
    // in the reference sheet: filled circle, contrasting glyph.
    UIButton *capture = [UIButton buttonWithType:UIButtonTypeCustom];
    capture.translatesAutoresizingMaskIntoConstraints = NO;
    capture.layer.cornerRadius = 17;
    capture.contentEdgeInsets = UIEdgeInsetsZero;
    capture.imageView.contentMode = UIViewContentModeCenter;
    UIColor *ink = ThemeManager.shared.primaryTextColor ?: UIColor.whiteColor;
    capture.backgroundColor = ink;
    capture.tintColor = self.backgroundColor ?: [UIColor colorWithWhite:0.05 alpha:1.0];
    [capture setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    [capture addTarget:self action:@selector(captureButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:capture];
    self.captureButton = capture;

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeCustom];
    clear.translatesAutoresizingMaskIntoConstraints = NO;
    clear.layer.cornerRadius = 17;
    clear.contentEdgeInsets = UIEdgeInsetsZero;
    clear.imageView.contentMode = UIViewContentModeCenter;
    clear.backgroundColor = ink;
    clear.tintColor = self.backgroundColor ?: [UIColor colorWithWhite:0.05 alpha:1.0];
    [clear setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:clear];
    self.clearButton = clear;

    WitchScrollingLogView *log = [[WitchScrollingLogView alloc] initWithFrame:CGRectZero];
    log.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:log];
    self.logTextView = log;

    UILayoutGuide *safe = self.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12.0],
        [card.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12.0],
        [card.topAnchor constraintEqualToAnchor:self.brandRow.bottomAnchor constant:14.0],
        [card.bottomAnchor constraintEqualToAnchor:self.waitingLabel.topAnchor constant:-12.0],

        [clear.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-14.0],
        [clear.heightAnchor constraintEqualToConstant:34.0],
        [clear.widthAnchor constraintEqualToConstant:34.0],
        [capture.trailingAnchor constraintEqualToAnchor:clear.leadingAnchor constant:-8.0],
        [capture.centerYAnchor constraintEqualToAnchor:clear.centerYAnchor],
        [capture.heightAnchor constraintEqualToConstant:34.0],
        [capture.widthAnchor constraintEqualToConstant:34.0],
        [capture.topAnchor constraintEqualToAnchor:safe.topAnchor constant:6.0],
        [clear.centerYAnchor constraintEqualToAnchor:capture.centerYAnchor],

        [log.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [log.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [log.topAnchor constraintEqualToAnchor:card.topAnchor],
        [log.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    ]];

    card.alpha = 0.0;
    card.userInteractionEnabled = NO;
    card.transform = CGAffineTransformMakeTranslation(0, 16);
    log.hidden = YES;
    [self refreshCaptureUI];
}

- (void)applyThemeColors {
    UIColor *ink = self.inkColor;
    UIColor *accent = ThemeManager.shared.accentColor ?: ink;
    self.markImageView.tintColor = ink;
    self.wordmarkImageView.tintColor = ink;
    self.versionLabel.textColor = [ink colorWithAlphaComponent:0.55];
    self.waitingLabel.textColor = [ink colorWithAlphaComponent:0.95];
    self.barTrack.backgroundColor = [ink colorWithAlphaComponent:0.14];
    self.barOne.backgroundColor = accent.CGColor;
    self.barTwo.backgroundColor = accent.CGColor;
    self.logCard.layer.borderColor = (ThemeManager.shared.uiBorderColor ?: [ink colorWithAlphaComponent:0.85]).CGColor;
    self.logTextView.inkColor = [ink colorWithAlphaComponent:0.92];
    self.captureButton.backgroundColor = ink;
    self.captureButton.tintColor = self.backgroundColor ?: [UIColor colorWithWhite:0.05 alpha:1.0];
    self.clearButton.backgroundColor = ink;
    self.clearButton.tintColor = self.backgroundColor ?: [UIColor colorWithWhite:0.05 alpha:1.0];
}

- (UILabel *)makeLabelWithFont:(UIFont *)font {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textAlignment = NSTextAlignmentLeft;
    label.textColor = ThemeManager.shared.primaryTextColor ?: UIColor.whiteColor;
    label.numberOfLines = 1;
    label.isAccessibilityElement = YES;
    return label;
}

- (void)installThreeFingerTap {
    UITapGestureRecognizer *tap3 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleThreeFingerTap:)];
    tap3.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:tap3];
}

- (void)handleThreeFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    [self toggleLogMode];
}

#pragma mark - Choreography

- (void)startAnimating {
    if (self.entrancePlayed) {
        [self animateBarsIfPossible];
        return;
    }
    self.entrancePlayed = YES;
    NSUInteger token = ++self.choreographyToken;

    [UIView animateWithDuration:0.6 delay:0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState) animations:^{
        self.fadeLayer.opacity = 1.0;
    } completion:nil];

    [UIView animateWithDuration:0.55
                          delay:0.12
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.brandRow.alpha = 1.0;
        self.brandRow.transform = CGAffineTransformIdentity;
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.38 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (token != self.choreographyToken) return;
        [CATransaction begin];
        [CATransaction setAnimationDuration:kWordmarkRevealDuration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithControlPoints:0.3 :0.0 :0.2 :1.0]];
        self.wordmarkMask.frame = CGRectMake(0, 0, self.wordmarkImageView.bounds.size.width,
                                             MAX(1.0, self.wordmarkImageView.bounds.size.height + 6.0));
        [CATransaction commit];
        self.wordmarkRevealed = YES;
    });

    [UIView animateWithDuration:0.4
                          delay:0.55
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.versionLabel.alpha = 1.0;
        self.waitingLabel.alpha = 1.0;
        self.waitingLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.45
                          delay:0.78
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.barTrack.alpha = 1.0;
        self.barTrack.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (token != self.choreographyToken) return;
        [self animateBarsIfPossible];
    }];
}

- (void)playExitAnimationWithCompletion:(void (^)(void))completion {
    self.choreographyToken++;
    self.entrancePlayed = NO;
    [self stopAnimating];

    [UIView animateWithDuration:0.28 delay:0 options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState) animations:^{
        self.barTrack.alpha = 0.0;
        self.barTrack.transform = CGAffineTransformMakeTranslation(0, 12);
        self.waitingLabel.alpha = 0.0;
        self.waitingLabel.transform = CGAffineTransformMakeTranslation(0, 12);
    } completion:nil];

    [UIView animateWithDuration:0.36
                          delay:0.08
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.0
                        options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.brandRow.alpha = 0.0;
        self.brandRow.transform = CGAffineTransformMakeTranslation(0, -16);
        self.logCard.alpha = 0.0;
        self.logCard.transform = CGAffineTransformMakeTranslation(0, 12);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:0 options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState) animations:^{
            self.fadeLayer.opacity = 0.0;
        } completion:nil];
        if (completion) completion();
    }];
}

- (void)cancelChoreography {
    self.choreographyToken++;
}

- (void)animateBarsIfPossible {
    CGFloat trackWidth = self.barTrack.bounds.size.width;
    if (trackWidth < 60.0) trackWidth = 190.0;
    CGFloat barWidth = 120.0;
    CAMediaTimingFunction *easing = [CAMediaTimingFunction functionWithControlPoints:0.45 :0.0 :0.2 :1.0];
    NSArray *bars = @[self.barOne, self.barTwo];
    for (NSInteger i = 0; i < bars.count; i++) {
        CALayer *bar = bars[i];
        [bar removeAnimationForKey:@"position.x"];
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position.x"];
        anim.fromValue = @(-barWidth);
        anim.toValue = @(trackWidth + barWidth / 2);
        anim.duration = 1.15;
        anim.timingFunction = easing;
        anim.repeatCount = HUGE_VALF;
        anim.beginTime = CACurrentMediaTime() + (double)i * 0.575;
        [bar addAnimation:anim forKey:@"position.x"];
    }
}

- (void)stopAnimating {
    [self.barOne removeAnimationForKey:@"position.x"];
    [self.barTwo removeAnimationForKey:@"position.x"];
}

#pragma mark - Log panel

- (void)toggleLogMode {
    self.logMode = !self.logMode;
    BOOL on = self.logMode;
    if (on) {
        // Opening the log starts recording — unless the user explicitly
        // paused it earlier from the panel's own button.
        if (![PLLogOutputView captureEnabled] && !self.userPausedCapture) {
            [PLLogOutputView setCaptureEnabled:YES];
        }
    }
    [HapticManager.shared play:HapticTypeSelection];
    self.brandBottomConstraint.active = !on;
    self.brandTopConstraint.active = on;

    self.logCard.alpha = on ? 1.0 : 0.0;
    self.logCard.transform = on ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 16);
    self.logCard.userInteractionEnabled = on;
    // The bottom cluster (message + bar) stays in place in log mode too,
    // exactly like the reference layout.

    [UIView animateWithDuration:0.55
                          delay:0.0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.3
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        [self layoutIfNeeded];
        self.fadeLayer.opacity = on ? 0.0 : 1.0;
    } completion:nil];

    if (on) {
        self.logTextView.hidden = NO;
        [self.logTextView reloadFromLogBuffer];
        [self.logTextView startAutoScrollIfNeeded];
    } else {
        [self.logTextView stopAutoScroll];
        self.logTextView.hidden = YES;
    }
    [self refreshCaptureUI];
}

- (void)captureButtonTapped {
    BOOL enabled = ![PLLogOutputView captureEnabled];
    [PLLogOutputView setCaptureEnabled:enabled];
    self.userPausedCapture = !enabled;
    [HapticManager.shared play:HapticTypeSelection];
    [self refreshCaptureUI];
    [self.logTextView reloadFromLogBuffer];
}

- (void)clearButtonTapped {
    [PLLogOutputView clearLog];
    [self.logTextView clearDisplay];
    [HapticManager.shared play:HapticTypeMedium];
    [ErrorPresenter showToast:localize(@"witch.log_clear_done", nil) success:YES];
}

- (void)refreshCaptureUI {
    BOOL recording = [PLLogOutputView captureEnabled];
    UIImageSymbolConfiguration *iconCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIFontWeightBold];
    UIImage *icon = [UIImage systemImageNamed:recording ? @"pause.fill" : @"play.fill"
                                withConfiguration:iconCfg];
    [self.captureButton setImage:icon forState:UIControlStateNormal];
    self.captureButton.accessibilityLabel = localize(recording ? @"witch.log_stop" : @"witch.log_resume", nil);
}

#pragma mark - Player lifecycle

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview) {
        if (self.player) [self.player play];
        [self startAnimating];
    }
}

- (void)removeFromSuperview {
    [self.player pause];
    if (self.playerObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.playerObserver];
        self.playerObserver = nil;
    }
    self.playerItem = nil;
    self.player = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.wordmarkImageView.layer.mask = nil;
    [self.logTextView stopAutoScroll];
    [super removeFromSuperview];
}

@end

NS_ASSUME_NONNULL_END
