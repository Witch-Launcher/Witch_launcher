#import "LaunchSplashView.h"
#import "utils.h"

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
@property (nonatomic, copy, nullable) id<NSObject> playerObserver;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *scrim;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *barTrack;
@property (nonatomic, strong) UIView *barFill;
@property (nonatomic, strong) NSLayoutConstraint *barFillLeading;
@property (nonatomic) CGFloat barFillWidth;
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
    CGFloat maxWidth = MIN(440, self.bounds.size.width - 48);
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
    self.titleLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold] alpha:1.0];
    self.titleLabel.text = localize(@"splash.starting_title", nil);

    self.messageLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular] alpha:0.72];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.preferredMaxLayoutWidth = 440;
    self.messageLabel.text = localize(@"splash.starting_message", nil);

    UIView *track = [[UIView alloc] init];
    track.translatesAutoresizingMaskIntoConstraints = NO;
    track.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.16];
    track.layer.cornerRadius = 3;
    track.layer.masksToBounds = YES;
    track.isAccessibilityElement = YES;
    track.accessibilityLabel = localize(@"splash.starting_message", nil);
    self.barTrack = track;

    UIView *fill = [[UIView alloc] init];
    fill.translatesAutoresizingMaskIntoConstraints = NO;
    fill.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.95];
    fill.layer.cornerRadius = 3;
    fill.layer.masksToBounds = YES;
    [track addSubview:fill];
    self.barFill = fill;

    self.barFillWidth = 96;
    self.barFillLeading = [fill.leadingAnchor constraintEqualToAnchor:track.leadingAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [track.widthAnchor constraintEqualToConstant:260],
        [track.heightAnchor constraintEqualToConstant:6],
        self.barFillLeading,
        [fill.widthAnchor constraintEqualToConstant:self.barFillWidth],
        [fill.topAnchor constraintEqualToAnchor:track.topAnchor],
        [fill.bottomAnchor constraintEqualToAnchor:track.bottomAnchor],
    ]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.messageLabel, track]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 18;
    [stack setCustomSpacing:36 afterView:self.messageLabel];
    [self addSubview:stack];
    self.contentStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-24],
    ]];

    UILabel *hint = [self makeLabelWithFont:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] alpha:0.45];
    hint.text = localize(@"splash.starting_hint", nil);
    hint.numberOfLines = 1;
    hint.adjustsFontSizeToFitWidth = YES;
    hint.minimumScaleFactor = 0.7;
    hint.hidden = self.mediaActive;
    [self addSubview:hint];
    self.hintLabel = hint;
    NSLayoutConstraint *safeBottom = [self.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:self.hintLabel.bottomAnchor constant:16];
    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.hintLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            safeBottom,
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.hintLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [self.hintLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-24],
        ]];
    }
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
    self.barFillLeading.constant = 0;
    [self layoutIfNeeded];
    self.barFillLeading.constant = 164.0;
    [UIView animateWithDuration:1.6 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)stopAnimating {
    [self.barFill.layer removeAllAnimations];
    [self layoutIfNeeded];
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
