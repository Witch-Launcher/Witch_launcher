#import "WitchLogOverlay.h"
#import "PLLogOutputView.h"
#import "WitchScrollingLogView.h"
#import "HapticManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

static const CGFloat kLogHeightRatio = 0.55;
static const CGFloat kLogHeightMin  = 230.0;
static const CGFloat kLogHeightMax  = 560.0;

@interface WitchLogOverlay ()
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) CAGradientLayer *scrimLayer;
@property (nonatomic, strong) WitchScrollingLogView *logView;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *captureButton;
// Set when the user explicitly pauses capture with the in-log button; an
// automatic resume must never override that choice.
@property (nonatomic, assign) BOOL userPausedCapture;
// Guards show/hide completions against fast repeated toggles.
@property (nonatomic, assign) NSUInteger animToken;
// Writable in this file; the public header exposes it read-only.
@property (nonatomic, assign, getter=isShowing) BOOL showing;
@end

@implementation WitchLogOverlay

+ (instancetype)sharedOverlay {
    static WitchLogOverlay *overlay;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        overlay = [[WitchLogOverlay alloc] initWithFrame:CGRectZero];
    });
    return overlay;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;

    _content = [[UIView alloc] init];
    _content.backgroundColor = UIColor.clearColor;
    _content.clipsToBounds = NO;
    [self addSubview:_content];

    _scrimLayer = [CAGradientLayer layer];
    _scrimLayer.colors = @[
        (id)[UIColor colorWithWhite:0 alpha:0.82].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.66].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.30].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
    ];
    _scrimLayer.locations = @[@0.0, @0.45, @0.78, @1.0];
    _scrimLayer.startPoint = CGPointMake(0.5, 0.0);
    _scrimLayer.endPoint = CGPointMake(0.5, 1.0);
    [_content.layer addSublayer:_scrimLayer];

    // The shared log text view brings the slow auto-roll plus the long-press
    // copy/share sheet; the overlay only needs its own capture controls.
    _logView = [[WitchScrollingLogView alloc] initWithFrame:CGRectZero];
    [_content addSubview:_logView];

    // Capture status pill (top-left) + manual pause/resume button (top-right).
    // Lets the user freeze the log in place to read it.
    _statusDot = [[UIView alloc] init];
    _statusDot.layer.cornerRadius = 3.5;
    _statusDot.backgroundColor = [UIColor systemGreenColor];
    [_content addSubview:_statusDot];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.65];
    [_content addSubview:_statusLabel];

    _captureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _captureButton.layer.cornerRadius = 13;
    _captureButton.layer.borderWidth = 1;
    _captureButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    _captureButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    _captureButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    _captureButton.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    [_captureButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.92] forState:UIControlStateNormal];
    [_captureButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    _captureButton.tintColor = [UIColor colorWithWhite:1 alpha:0.92];
    _captureButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    _captureButton.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 6);
    _captureButton.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, -2);
    [_captureButton addTarget:self action:@selector(captureButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:_captureButton];
    return self;
}

- (CGFloat)logHeight {
    CGFloat h = self.bounds.size.height * kLogHeightRatio;
    return MAX(kLogHeightMin, MIN(h, kLogHeightMax));
}

// Touches outside the visible log area fall through to whatever is below
// (the game / the splash) — the overlay is not a panel and must not eat
// input it does not visually own.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.showing) return NO;
    return CGRectContainsPoint(self.content.frame, point);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // While sliding in/out the content carries a transform; setting a frame
    // under a transform is undefined and caused the jumpy toggle.
    if (!CGAffineTransformIsIdentity(self.content.transform)) return;
    CGFloat logH = [self logHeight];
    CGFloat width = self.bounds.size.width;
    self.content.frame = CGRectMake(0, 0, width, logH);
    self.scrimLayer.frame = self.content.bounds;

    CGFloat rowTop = 12.0;
    self.statusDot.frame = CGRectMake(14.0, rowTop + 5.0, 7.0, 7.0);
    self.statusLabel.frame = CGRectMake(26.0, rowTop, 140.0, 17.0);
    self.captureButton.frame = CGRectMake(width - 14.0 - 104.0, rowTop - 2.0, 104.0, 26.0);
    self.logView.frame = CGRectMake(0, 34.0, width, logH - 34.0);
}

#pragma mark - Show / hide

- (void)showInView:(UIView *)host {
    if (!host) return;
    // "Bật log" also records — unless the user explicitly paused recording
    // with the in-log button earlier (never silently override that choice).
    if (![PLLogOutputView captureEnabled] && !self.userPausedCapture) {
        [PLLogOutputView setCaptureEnabled:YES];
    }
    if (self.superview) {
        [self.superview layoutIfNeeded];
        [self removeFromSuperview];
    }
    self.frame = host.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:self];
    [self refreshCaptureUI];
    [self.logView reloadFromLogBuffer];
    [self.logView startAutoScrollIfNeeded];

    // Establish the final geometry (identity transform) BEFORE parking the
    // content offscreen — otherwise layoutSubviews fights the transform and
    // the sheet visibly jumps.
    self.content.transform = CGAffineTransformIdentity;
    self.content.alpha = 1.0;
    [self layoutIfNeeded];

    self.animToken++;
    CGFloat offscreen = -([self logHeight] + 24.0);
    self.content.transform = CGAffineTransformMakeTranslation(0, offscreen);
    self.content.alpha = 0.0;

    [UIView animateWithDuration:0.5
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.5
                        options:(UIViewAnimationOptionCurveEaseOut |
                                 UIViewAnimationOptionAllowUserInteraction |
                                 UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.content.transform = CGAffineTransformIdentity;
        self.content.alpha = 1.0;
    } completion:nil];
    self.showing = YES;
}

- (void)hideAnimated:(BOOL)animated {
    // Hiding the log screen never stops capture: the game keeps logging and
    // the buffer keeps growing (capped), so re-opening shows a continuous
    // history. Recording is only stopped by the user's explicit "Tắt ghi"
    // button inside the log screen.
    self.animToken++;
    NSUInteger token = self.animToken;
    if (!self.superview) {
        self.showing = NO;
        return;
    }

    CGFloat offscreen = -([self logHeight] + 24.0);
    if (!animated) {
        self.content.transform = CGAffineTransformMakeTranslation(0, offscreen);
        self.content.alpha = 0.0;
        [self removeFromSuperview];
        self.showing = NO;
        return;
    }
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseInOut |
                                 UIViewAnimationOptionAllowUserInteraction |
                                 UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        self.content.transform = CGAffineTransformMakeTranslation(0, offscreen);
        self.content.alpha = 0.0;
    } completion:^(BOOL finished) {
        // A fast re-open may have superseded this hide.
        if (token != self.animToken) return;
        [self removeFromSuperview];
        self.content.transform = CGAffineTransformIdentity;
        self.content.alpha = 1.0;
    }];
    self.showing = NO;
}

- (void)toggleInView:(UIView *)host {
    if (self.showing && self.superview) {
        [self hideAnimated:YES];
    } else {
        [self showInView:host];
    }
}

#pragma mark - Capture toggle

- (void)captureButtonTapped {
    BOOL enabled = ![PLLogOutputView captureEnabled];
    [PLLogOutputView setCaptureEnabled:enabled];
    self.userPausedCapture = !enabled;
    [HapticManager.shared play:HapticTypeSelection];
    [self refreshCaptureUI];
    [self.logView reloadFromLogBuffer];
}

- (void)refreshCaptureUI {
    BOOL recording = [PLLogOutputView captureEnabled];
    self.statusDot.backgroundColor = recording ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];
    self.statusLabel.text = localize(recording ? @"witch.log_recording" : @"witch.log_paused", nil);
    [self.captureButton setImage:[UIImage systemImageNamed:recording ? @"pause.fill" : @"play.fill"] forState:UIControlStateNormal];
    [self.captureButton setTitle:localize(recording ? @"witch.log_stop" : @"witch.log_resume", nil) forState:UIControlStateNormal];
    self.captureButton.accessibilityLabel = localize(recording ? @"witch.log_stop" : @"witch.log_resume", nil);
}

@end
