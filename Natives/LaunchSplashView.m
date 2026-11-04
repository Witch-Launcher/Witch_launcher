#import "LaunchSplashView.h"
#import "utils.h"
#import "ThemeManager.h"
#import "WitchLogOverlay.h"
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
    NSString *directory = [documents stringByAppendingPathComponent:@"Splash"];
    NSString *found = WitchSplashPathInDirectory(directory, extensions);
    if (found) return found;
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

@interface LaunchSplashView ()
@property (nonatomic, strong, nullable) UIImageView *imageView;
@property (nonatomic, strong, nullable) AVPlayer *player;
@property (nonatomic, strong, nullable) AVPlayerItem *playerItem;
@property (nonatomic, strong, nullable) id<NSObject> playerObserver;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *scrim;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIVisualEffectView *panel;
@property (nonatomic, strong) UIView *barTrack;
@property (nonatomic, strong) CALayer *barOne;
@property (nonatomic, strong) CALayer *barTwo;
@property (nonatomic) BOOL mediaActive;
@end

@implementation LaunchSplashView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.blackColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self buildBackground];
    [self buildContent];
    return self;
}

- (void)dealloc {
    [self stopAnimating];
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat maxWidth = MIN(280, self.bounds.size.width - 96);
    if (maxWidth < 0) maxWidth = 0;
    if (self.messageLabel.preferredMaxLayoutWidth != maxWidth) {
        self.messageLabel.preferredMaxLayoutWidth = maxWidth;
        [self.messageLabel invalidateIntrinsicContentSize];
    }
    self.imageView.frame = self.bounds;
    self.playerLayer.frame = self.bounds;
}

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
}

- (void)buildContent {
    self.titleLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] alpha:0.98];
    self.titleLabel.text = localize(@"splash.starting_title", nil);

    self.messageLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular] alpha:0.72];
    self.messageLabel.numberOfLines = 2;
    self.messageLabel.preferredMaxLayoutWidth = 236;
    self.messageLabel.text = localize(@"splash.starting_message", nil);

    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 190, 3)];
    track.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *accent = ThemeManager.shared.accentColor ?: UIColor.whiteColor;
    track.backgroundColor = [accent colorWithAlphaComponent:0.22];
    track.layer.cornerRadius = 1.5;
    track.layer.masksToBounds = YES;
    track.isAccessibilityElement = YES;
    track.accessibilityLabel = localize(@"splash.starting_message", nil);
    track.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    self.barTrack = track;

    CGFloat barWidth = 76;
    NSArray *colors = @[accent, accent];
    for (NSInteger i = 0; i < 2; i++) {
        CALayer *bar = [CALayer layer];
        bar.frame = CGRectMake(0, 0, barWidth, 3);
        bar.cornerRadius = 1.5;
        bar.backgroundColor = [colors[i] colorWithAlphaComponent:0.95].CGColor;
        [track.layer addSublayer:bar];
        if (i == 0) self.barOne = bar; else self.barTwo = bar;
    }

    [NSLayoutConstraint activateConstraints:@[
        [track.widthAnchor constraintEqualToConstant:190],
        [track.heightAnchor constraintEqualToConstant:3],
    ]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.messageLabel, track]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 6;
    [stack setCustomSpacing:12 afterView:self.messageLabel];
    stack.isAccessibilityElement = NO;

    // Compact floating card pinned to the bottom: leaves the whole top area
    // free for the log overlay (three-finger tap).
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 18;
    panel.layer.masksToBounds = YES;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [panel.contentView addSubview:stack];
    [self addSubview:panel];
    self.panel = panel;
    self.contentStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-13],
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-14],
        [panel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [panel.widthAnchor constraintEqualToConstant:264],
    ]];

    UILabel *hint = [self makeLabelWithFont:[UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium] alpha:0.62];
    hint.text = localize(@"splash.three_finger_log_hint", nil);
    hint.numberOfLines = 1;
    hint.adjustsFontSizeToFitWidth = YES;
    hint.minimumScaleFactor = 0.72;
    [self addSubview:hint];
    self.hintLabel = hint;
    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [panel.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-46],
            [hint.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [hint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [hint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [self.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:hint.bottomAnchor constant:16],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [panel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-58],
            [hint.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [hint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [hint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [hint.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18],
        ]];
    }

    UITapGestureRecognizer *tap3 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleThreeFingerTap:)];
    tap3.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:tap3];
}

- (void)handleThreeFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    UIView *host = self.superview ?: self;
    [[WitchLogOverlay sharedOverlay] toggleInView:host];
}

- (UILabel *)makeLabelWithFont:(UIFont *)font alpha:(CGFloat)alpha {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [[UIColor whiteColor] colorWithAlphaComponent:alpha];
    label.numberOfLines = 1;
    label.isAccessibilityElement = YES;
    return label;
}

- (void)startAnimating {
    CGFloat trackWidth = 190.0;
    CGFloat barWidth = 76.0;
    CAMediaTimingFunction *easing = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];
    NSArray *bars = @[self.barOne, self.barTwo];
    for (NSInteger i = 0; i < bars.count; i++) {
        CALayer *bar = bars[i];
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position.x"];
        anim.fromValue = @(-barWidth / 2);
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

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview && self.player) [self.player play];
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
    [super removeFromSuperview];
}

@end

NS_ASSUME_NONNULL_END
