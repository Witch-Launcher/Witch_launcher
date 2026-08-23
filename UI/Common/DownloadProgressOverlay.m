#import "DownloadProgressOverlay.h"

#import "AmethystBlurView.h"
#import "ThemeManager.h"

@interface DownloadProgressOverlay ()
@property (nonatomic) UIView *containerView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIButton *cancelBtn;
@property (nonatomic) BOOL isFinished;
@property (nonatomic) BOOL isDismissing;
@end

@implementation DownloadProgressOverlay

+ (instancetype)showInView:(UIView *)view title:(NSString *)title {
    return [self showBlurredInView:view title:title blurred:NO];
}

// `blurred` adds a realtime frost behind the card — used by the Launch flow
// so the game-download progress stays readable over any wallpaper.
+ (instancetype)showBlurredInView:(UIView *)view title:(NSString *)title blurred:(BOOL)blurred {
    DownloadProgressOverlay *overlay = [[self alloc] initWithFrame:view.bounds];
    overlay.titleLabel.text = title;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (blurred) {
        [AmethystBlurView installInView:overlay];
    }
    [view addSubview:overlay];
    overlay.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{
        overlay.alpha = 1;
    }];
    return overlay;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];

        _containerView = [[UIView alloc] init];
        _containerView.translatesAutoresizingMaskIntoConstraints = NO;
        _containerView.layer.cornerRadius = 14;
        _containerView.clipsToBounds = YES;
        [self addSubview:_containerView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 0;
        _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
        [_containerView addSubview:_titleLabel];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 1;
        _statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _statusLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [_containerView addSubview:_statusLabel];

        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.translatesAutoresizingMaskIntoConstraints = NO;
        _progressView.progressTintColor = ThemeManager.shared.accentColor;
        _progressView.trackTintColor = ThemeManager.shared.separatorColor;
        [_containerView addSubview:_progressView];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _percentLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.textColor = ThemeManager.shared.accentColor;
        [_containerView addSubview:_percentLabel];

        _speedLabel = [[UILabel alloc] init];
        _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _speedLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _speedLabel.textAlignment = NSTextAlignmentLeft;
        _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [_containerView addSubview:_speedLabel];

        _etaLabel = [[UILabel alloc] init];
        _etaLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _etaLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _etaLabel.textAlignment = NSTextAlignmentRight;
        _etaLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [_containerView addSubview:_etaLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_containerView.widthAnchor constraintEqualToConstant:280],
            [_containerView.heightAnchor constraintGreaterThanOrEqualToConstant:140],

            [_titleLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:20],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:20],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-20],

            [_statusLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:20],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-20],

            [_progressView.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:12],
            [_progressView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:20],
            [_progressView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-20],
            [_progressView.heightAnchor constraintEqualToConstant:4],

            [_percentLabel.topAnchor constraintEqualToAnchor:_progressView.bottomAnchor constant:8],
            [_percentLabel.centerXAnchor constraintEqualToAnchor:_containerView.centerXAnchor],
            [_percentLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_containerView.leadingAnchor constant:20],
            [_percentLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_containerView.trailingAnchor constant:-20],

            [_speedLabel.topAnchor constraintEqualToAnchor:_percentLabel.bottomAnchor constant:6],
            [_speedLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:20],
            [_speedLabel.trailingAnchor constraintEqualToAnchor:_containerView.centerXAnchor constant:-4],
            [_speedLabel.lastBaselineAnchor constraintEqualToAnchor:_etaLabel.lastBaselineAnchor],

            [_etaLabel.topAnchor constraintEqualToAnchor:_percentLabel.bottomAnchor constant:6],
            [_etaLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-20],
            [_etaLabel.leadingAnchor constraintEqualToAnchor:_containerView.centerXAnchor constant:4],
            [_etaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_containerView.bottomAnchor constant:-16],
        ]];

        _cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        _cancelBtn.hidden = YES;
        [_cancelBtn setTitle:@"Cancel" forState:UIControlStateNormal];
        _cancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [_cancelBtn setTitleColor:ThemeManager.shared.errorColor forState:UIControlStateNormal];
        _cancelBtn.layer.cornerRadius = 6;
        _cancelBtn.layer.borderWidth = 1;
        _cancelBtn.layer.borderColor = ThemeManager.shared.errorColor.CGColor;
        _cancelBtn.contentEdgeInsets = UIEdgeInsetsMake(4, 12, 4, 12);
        [_cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [_containerView addSubview:_cancelBtn];

        [NSLayoutConstraint activateConstraints:@[
            [_cancelBtn.topAnchor constraintEqualToAnchor:_etaLabel.bottomAnchor constant:10],
            [_cancelBtn.centerXAnchor constraintEqualToAnchor:_containerView.centerXAnchor],
            [_cancelBtn.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-12],
            [_cancelBtn.heightAnchor constraintEqualToConstant:28],
        ]];

        _speedLabel.text = nil;
        _etaLabel.text = nil;
        _percentLabel.text = nil;

        [self updateTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    _containerView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _statusLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _progressView.progressTintColor = ThemeManager.shared.accentColor;
    _percentLabel.textColor = ThemeManager.shared.accentColor;
    _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _etaLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [_cancelBtn setTitleColor:ThemeManager.shared.errorColor forState:UIControlStateNormal];
    _cancelBtn.layer.borderColor = ThemeManager.shared.errorColor.CGColor;
}

- (void)updateProgress:(float)progress message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = progress;
        if (message) self.statusLabel.text = message;
        self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", progress * 100];
    });
}

- (void)updateWithFraction:(float)fraction description:(NSString *)description additionalDescription:(NSString *)additional speed:(NSString *)speed eta:(NSString *)eta {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = fraction;
        self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", fraction * 100];
        if (description) self.statusLabel.text = description;
        self.speedLabel.text = speed;
        self.etaLabel.text = eta;
    });
}

- (void)finishWithMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isFinished = YES;
        self.progressView.progress = 1.0;
        self.percentLabel.text = @"100%";
        self.speedLabel.text = nil;
        self.etaLabel.text = nil;
        if (message) self.statusLabel.text = message;
        self.progressView.progressTintColor = ThemeManager.shared.successColor;
    });
}

- (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isDismissing) return;
        self.isDismissing = YES;
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    });
}

- (void)cancelTapped {
    if (self.isFinished || self.isDismissing) return;
    self.cancelBtn.enabled = NO;
    void (^block)(void) = self.cancelBlock;
    self.cancelBlock = nil;
    if (block) {
        block();
    } else {
        [self dismiss];
    }
}

- (void)setCancelBlock:(void (^)(void))cancelBlock {
    _cancelBlock = [cancelBlock copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cancelBtn.hidden = cancelBlock == nil;
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
