#import "AmethystBlurView.h"
#import "ThemeManager.h"

NSString * const AmethystBlurIntensityDidChangeNotification = @"AmethystBlurIntensityDidChangeNotification";

static NSString * const kBlurPrefKey = @"amethyst_settings_blur";

@interface AmethystBlurView ()
// Scrubbing a paused UIViewPropertyAnimator from nil -> blurEffect is the
// standard technique for a continuously variable REALTIME system blur.
@property (nonatomic, strong) UIViewPropertyAnimator *animator;
@property (nonatomic, copy) NSString *styleKey;
@end

@implementation AmethystBlurView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO; // never steal touches from the panel
        [self rebuildAnimator];
        [self applyCurrentIntensity];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applyCurrentIntensity)
                                                     name:ThemeDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applyCurrentIntensity)
                                                     name:AmethystBlurIntensityDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_animator stopAnimation:YES];
}

+ (CGFloat)currentIntensity {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:kBlurPrefKey];
    return MAX(0.0f, MIN(v, 100.0f)) / 100.0f;
}

+ (BOOL)blurEnabled {
    return [self currentIntensity] > 0.001f;
}

- (UIBlurEffect *)makeEffect {
    BOOL dark = ThemeManager.shared.isDarkMode;
    // Ultra-thin reads better at low intensities, full material at high.
    if ([AmethystBlurView currentIntensity] <= 0.5) {
        return [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight];
}

- (void)rebuildAnimator {
    if (_animator) {
        [_animator stopAnimation:YES];
        _animator = nil;
    }
    self.effect = nil;
    __weak typeof(self) wSelf = self;
    UIBlurEffect *target = [self makeEffect];
    _animator = [[UIViewPropertyAnimator alloc] initWithDuration:1.0
                                                           curve:UIViewAnimationCurveLinear
                                                      animations:^{
        wSelf.effect = target;
    }];
    [_animator pauseAnimation];
}

- (void)applyCurrentIntensity {
    CGFloat t = [AmethystBlurView currentIntensity];

    // Rebuild when the theme (material style) changed since last build.
    BOOL dark = ThemeManager.shared.isDarkMode;
    NSString *key = [NSString stringWithFormat:@"%@-%@", dark ? @"dark" : @"light", t <= 0.5 ? @"thin" : @"full"];
    if (![key isEqualToString:_styleKey]) {
        _styleKey = key;
        [self rebuildAnimator];
    }

    _animator.fractionComplete = t; // 0 => nil effect (clear), 1 => full frost
}

+ (void)installInView:(UIView *)containerView {
    if (!containerView) return;
    AmethystBlurView *blur = [[AmethystBlurView alloc] initWithFrame:containerView.bounds];
    [containerView insertSubview:blur atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
}

@end
