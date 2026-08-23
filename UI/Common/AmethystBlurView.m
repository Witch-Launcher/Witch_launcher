#import "AmethystBlurView.h"
#import "ThemeManager.h"

NSString * const AmethystBlurIntensityDidChangeNotification = @"AmethystBlurIntensityDidChangeNotification";

static NSString * const kDefaultBlurPrefKey = @"amethyst_settings_blur";

@interface AmethystBlurView ()
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, strong) UIView *effectWrap;             // scales frost strength
@property (nonatomic, strong) UIVisualEffectView *effectView; // REALTIME system gaussian
@property (nonatomic, strong) UIView *tintView;               // readability tint
@end

@implementation AmethystBlurView

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithPrefKey:kDefaultBlurPrefKey];
}

- (instancetype)initWithPrefKey:(NSString *)key {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _prefKey = key ?: kDefaultBlurPrefKey;
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
    // One adaptive material; perceived strength is driven by the wrap alpha.
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
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
    BOOL on = t > 0.001f;

    // Linear scaling: 1% → wrapper alpha 0.01 (barely-there frost),
    // 100% → full material. Discrete material buckets would make any
    // nonzero value look like ~90% blur, which is exactly the bug.
    _effectWrap.hidden = !on;
    _effectWrap.alpha = t;

    if (on) {
        UIBlurEffect *newEffect = [AmethystBlurView materialForIntensity:t];
        if (![_effectView.effect isEqual:newEffect]) {
            [_effectView setEffect:newEffect];
        }
    }

    // Readability tint follows light/dark and scales down with intensity so
    // low slider values stay virtually invisible.
    BOOL dark = ThemeManager.shared.isDarkMode;
    UIColor *base = dark ? [UIColor colorWithWhite:0 alpha:1] : [UIColor colorWithWhite:1 alpha:1];
    _tintView.backgroundColor = base;
    _tintView.alpha = on ? (0.12 * t) : 0.0;
}

+ (void)installInView:(UIView *)containerView {
    [self installInView:containerView prefKey:nil];
}

+ (void)installInView:(UIView *)containerView prefKey:(NSString *)key {
    if (!containerView) return;
    for (UIView *existing in containerView.subviews) {
        if ([existing isKindOfClass:AmethystBlurView.class]) return;
    }
    AmethystBlurView *blur = [[AmethystBlurView alloc] initWithPrefKey:key];
    [containerView insertSubview:blur atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
}

@end
