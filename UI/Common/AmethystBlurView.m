#import "AmethystBlurView.h"
#import "ThemeManager.h"
#import "UIView+LiquidGlass.h"

NSString * const AmethystBlurIntensityDidChangeNotification = @"AmethystBlurIntensityDidChangeNotification";

static NSString * const kDefaultBlurPrefKey = @"amethyst_settings_blur";

@interface AmethystBlurView ()
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic) BOOL glassEligible;
@property (nonatomic, strong) UIView *effectWrap;             // scales frost strength
@property (nonatomic, strong) UIVisualEffectView *effectView; // REALTIME system gaussian
@property (nonatomic, strong) UIView *tintView;               // readability tint
- (void)updateGlassCornerConfiguration;
@end

@implementation AmethystBlurView

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithPrefKey:kDefaultBlurPrefKey];
}

- (instancetype)initWithPrefKey:(NSString *)key {
    return [self initWithPrefKey:key glassEligible:NO];
}

- (instancetype)initWithPrefKey:(NSString *)key glassEligible:(BOOL)glassEligible {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _prefKey = key ?: kDefaultBlurPrefKey;
        _glassEligible = glassEligible;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO;

        // Live gaussian frost: UIVisualEffectView samples whatever is rendered
        // behind it every frame (wallpaper, video, scrolling content). The
        // wrap view scales the frost LINEARLY with the intensity slider —
        // system materials are discrete, so alpha-scaling the wrapper is the
        // only way to make 1% look like 1% instead of a heavy blur.
        _effectWrap = [[UIView alloc] init];
        _effectWrap.translatesAutoresizingMaskIntoConstraints = NO;
        _effectWrap.userInteractionEnabled = NO;
        [self addSubview:_effectWrap];

        _effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
        _effectView.translatesAutoresizingMaskIntoConstraints = NO;
        _effectView.userInteractionEnabled = NO;
        [_effectWrap addSubview:_effectView];

        _tintView = [[UIView alloc] init];
        _tintView.translatesAutoresizingMaskIntoConstraints = NO;
        _tintView.userInteractionEnabled = NO;
        [self addSubview:_tintView];

        [NSLayoutConstraint activateConstraints:@[
            [_effectWrap.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_effectWrap.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_effectWrap.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_effectWrap.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_effectView.topAnchor constraintEqualToAnchor:_effectWrap.topAnchor],
            [_effectView.bottomAnchor constraintEqualToAnchor:_effectWrap.bottomAnchor],
            [_effectView.leadingAnchor constraintEqualToAnchor:_effectWrap.leadingAnchor],
            [_effectView.trailingAnchor constraintEqualToAnchor:_effectWrap.trailingAnchor],
            [_tintView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_tintView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_tintView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_tintView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];

        [self applyCurrentIntensity];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyCurrentIntensity) name:ThemeDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyCurrentIntensity) name:AmethystBlurIntensityDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyCurrentIntensity) name:LiquidGlassDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (CGFloat)intensityForKey:(NSString *)key {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:key];
    return MAX(0.0f, MIN(v, 100.0f)) / 100.0f;
}
+ (CGFloat)currentIntensity { return [self intensityForKey:kDefaultBlurPrefKey]; }
+ (BOOL)blurEnabled { return [self currentIntensity] > 0.001f; }
+ (BOOL)blurEnabledForKey:(NSString *)key { return [self intensityForKey:key] > 0.001f; }
- (CGFloat)intensity { return [AmethystBlurView intensityForKey:_prefKey]; }

+ (UIBlurEffect *)materialForIntensity:(CGFloat)t {
    UIBlurEffectStyle style;
    if (t <= 1.0 / 3.0) {
        style = UIBlurEffectStyleSystemUltraThinMaterial;
    } else if (t <= 2.0 / 3.0) {
        style = UIBlurEffectStyleSystemThinMaterial;
    } else {
        style = UIBlurEffectStyleSystemMaterial;
    }
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:style];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL changed = NO;
    if (@available(iOS 13.0, *)) {
        changed = previousTraitCollection && [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
    } else {
        changed = !!previousTraitCollection;
    }
    if (changed) {
        [self applyCurrentIntensity];
    }
}

- (void)applyCurrentIntensity {
    CGFloat t = [self intensity];
    BOOL glass = self.glassEligible && [UIView lg_isEnabled];
    BOOL on = glass || t > 0.001f;

    _effectWrap.hidden = !on;

    if (on) {
        if (glass) {
            // UIGlassEffect must not be alpha-scaled: the system needs the
            // effect view at full opacity to sample and refract the backdrop.
            _effectWrap.alpha = 1.0;
            UIVisualEffect *effect = [UIView lg_makeEffectWithTint:nil];
            if (effect) {
                _effectView.effect = effect;
            }
            [self updateGlassCornerConfiguration];
        } else {
            // buckets; the full material at all times so the blur is a real
            // gaussian sampling of the backdrop, never a dimming overlay.
            _effectWrap.alpha = 1.0;
            UIBlurEffect *newEffect = [AmethystBlurView materialForIntensity:t];
            if (![_effectView.effect isEqual:newEffect]) {
                [_effectView setEffect:newEffect];
            }
        }
    }

    // Readability tint follows light/dark and scales down with intensity so
    // low slider values stay virtually invisible. Glass already supplies its
    // own material, so it needs much less extra tint than the blur fallback.
    // No extra tint: the blur must stay translucent and show what is behind,
    // never dim or darken it.
    _tintView.alpha = 0.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.glassEligible && [UIView lg_isEnabled]) {
        [self updateGlassCornerConfiguration];
    }
}

- (void)updateGlassCornerConfiguration {
    if (@available(iOS 26.0, *)) {
        UIView *host = self.superview;
        [UIView lg_configureGlassEffectView:_effectView
                                cornerRadius:host.layer.cornerRadius
                               maskedCorners:host.layer.maskedCorners];
    }
}

+ (void)installInView:(UIView *)containerView {
    [self installInView:containerView prefKey:nil glassEligible:NO];
}

+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key {
    [self installInView:containerView prefKey:key glassEligible:NO];
}

+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key glassEligible:(BOOL)glassEligible {
    if (!containerView) return;
    for (UIView *existing in containerView.subviews) {
        if ([existing isKindOfClass:AmethystBlurView.class]) return;
    }
    AmethystBlurView *blur = [[AmethystBlurView alloc] initWithPrefKey:key glassEligible:glassEligible];
    [containerView insertSubview:blur atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
}

@end
