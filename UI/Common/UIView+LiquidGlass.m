#import "UIView+LiquidGlass.h"
#import "ThemeManager.h"
#import "LauncherPreferences.h"
#import <objc/runtime.h>

NSString * const LiquidGlassDidChangeNotification = @"LiquidGlassDidChangeNotification";
NSString * const kLiquidGlassTag = @"__lg_glass_view";

static void * const kLiquidGlassConfigKey = (void *)&kLiquidGlassConfigKey;

@interface AmethystLiquidGlassConfig : NSObject
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CACornerMask maskedCorners;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic) BOOL baseColorCaptured;
@property (nonatomic, strong) UIVisualEffectView *effectView;
@end

@implementation AmethystLiquidGlassConfig
@end

static UIColor *LGAdaptiveTint(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.05];
    }];
}

static UICornerConfiguration *LGConfigurationForRadius(CGFloat radius, CACornerMask mask) API_AVAILABLE(ios(26.0));
static UICornerConfiguration *LGConfigurationForRadius(CGFloat radius, CACornerMask mask) {
    UICornerRadius *rounded = [UICornerRadius fixedRadius:MAX(0.0, radius)];
    UICornerRadius *square = [UICornerRadius fixedRadius:0.0];
    return [UICornerConfiguration configurationWithTopLeftRadius:(mask & kCALayerMinXMinYCorner ? rounded : square)
                                                topRightRadius:(mask & kCALayerMaxXMinYCorner ? rounded : square)
                                              bottomLeftRadius:(mask & kCALayerMinXMaxYCorner ? rounded : square)
                                             bottomRightRadius:(mask & kCALayerMaxXMaxYCorner ? rounded : square)];
}

@interface AmethystLiquidGlassCenter : NSObject
+ (instancetype)shared;
@end

@implementation AmethystLiquidGlassCenter

+ (instancetype)shared {
    static AmethystLiquidGlassCenter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(surfaceConfigurationChanged:) name:LiquidGlassDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(surfaceConfigurationChanged:) name:ThemeDidChangeNotification object:nil];
    });
    return instance;
}

- (void)surfaceConfigurationChanged:(NSNotification *)notification {
    [UIView lg_refreshAllInWindows];
}

@end

static void LGEnsureCenter(void) {
    (void)[AmethystLiquidGlassCenter shared];
}

@implementation UIView (LiquidGlass)

+ (BOOL)lg_isAvailable {
    if (@available(iOS 26.0, *)) {
        return NSClassFromString(@"UIGlassEffect") != nil;
    }
    return NO;
}

+ (BOOL)lg_isEnabled {
    if (![self lg_isAvailable]) return NO;
    LGEnsureCenter();
    return getPrefBool(@"general.liquid_glass");
}

+ (UIVisualEffect *)lg_makeEffectWithTint:(UIColor *)tintColor {
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        effect.interactive = NO;
        effect.tintColor = tintColor ?: LGAdaptiveTint();
        return effect;
    }
    return nil;
}

+ (void)lg_configureGlassEffectView:(UIVisualEffectView *)effectView
                       cornerRadius:(CGFloat)radius
                      maskedCorners:(CACornerMask)maskedCorners {
    effectView.layer.cornerRadius = MAX(0.0, radius);
    effectView.layer.maskedCorners = maskedCorners;
    if (@available(iOS 26.0, *)) {
        effectView.cornerConfiguration = LGConfigurationForRadius(radius, maskedCorners);
    }
}

- (UIVisualEffectView *)lg_addGlassEffect {
    return [self lg_addGlassEffectWithTint:nil cornerRadius:14.0];
}

- (UIVisualEffectView *)lg_addGlassEffectWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius {
    return [self lg_addGlassEffectWithTint:tintColor cornerRadius:radius maskedCorners:kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner];
}

- (UIVisualEffectView *)lg_addGlassEffectWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius maskedCorners:(CACornerMask)maskedCorners {
    if (![UIView lg_isAvailable]) return nil;
    LGEnsureCenter();
    AmethystLiquidGlassConfig *config = objc_getAssociatedObject(self, kLiquidGlassConfigKey);
    if (!config) {
        config = [[AmethystLiquidGlassConfig alloc] init];
        config.baseColor = self.backgroundColor;
        config.baseColorCaptured = YES;
        objc_setAssociatedObject(self, kLiquidGlassConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    config.tintColor = tintColor;
    config.cornerRadius = MAX(0.0, radius);
    config.maskedCorners = maskedCorners;
    [self lg_refreshLiquidGlass];
    return config.effectView;
}

- (void)lg_enableLiquidGlassWithTint:(UIColor *)tintColor cornerRadius:(CGFloat)radius maskedCorners:(CACornerMask)maskedCorners {
    [self lg_addGlassEffectWithTint:tintColor cornerRadius:radius maskedCorners:maskedCorners];
}

- (void)lg_refreshLiquidGlass {
    AmethystLiquidGlassConfig *config = objc_getAssociatedObject(self, kLiquidGlassConfigKey);
    if (!config) return;

    if (![UIView lg_isEnabled]) {
        [self lg_removeGlassEffect];
        return;
    }

    if (!config.effectView || config.effectView.superview != self) {
        [config.effectView removeFromSuperview];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
        effectView.translatesAutoresizingMaskIntoConstraints = NO;
        effectView.userInteractionEnabled = NO;
        effectView.clipsToBounds = YES;
        effectView.isAccessibilityElement = NO;
        effectView.accessibilityElementsHidden = YES;
        effectView.accessibilityIdentifier = kLiquidGlassTag;
        [self insertSubview:effectView atIndex:0];

        NSLayoutYAxisAnchor *topAnchor;
        NSLayoutYAxisAnchor *bottomAnchor;
        NSLayoutXAxisAnchor *leadingAnchor;
        NSLayoutXAxisAnchor *trailingAnchor;
        if ([self isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)self;
            topAnchor = scrollView.frameLayoutGuide.topAnchor;
            bottomAnchor = scrollView.frameLayoutGuide.bottomAnchor;
            leadingAnchor = scrollView.frameLayoutGuide.leadingAnchor;
            trailingAnchor = scrollView.frameLayoutGuide.trailingAnchor;
        } else {
            topAnchor = self.topAnchor;
            bottomAnchor = self.bottomAnchor;
            leadingAnchor = self.leadingAnchor;
            trailingAnchor = self.trailingAnchor;
        }

        [NSLayoutConstraint activateConstraints:@[
            [effectView.topAnchor constraintEqualToAnchor:topAnchor],
            [effectView.bottomAnchor constraintEqualToAnchor:bottomAnchor],
            [effectView.leadingAnchor constraintEqualToAnchor:leadingAnchor],
            [effectView.trailingAnchor constraintEqualToAnchor:trailingAnchor],
        ]];
        config.effectView = effectView;
    }

    UIVisualEffectView *effectView = config.effectView;
    effectView.effect = [UIView lg_makeEffectWithTint:config.tintColor];
    if (@available(iOS 26.0, *)) {
        [UIView lg_configureGlassEffectView:effectView cornerRadius:config.cornerRadius maskedCorners:config.maskedCorners];
    } else {
        effectView.layer.cornerRadius = config.cornerRadius;
        effectView.layer.maskedCorners = config.maskedCorners;
    }
    self.backgroundColor = [UIColor clearColor];
}

- (void)lg_setLiquidGlassBaseColor:(UIColor *)color {
    AmethystLiquidGlassConfig *config = objc_getAssociatedObject(self, kLiquidGlassConfigKey);
    if (!config) return;
    config.baseColor = color;
    config.baseColorCaptured = YES;
    if (![self lg_hasGlassEffect]) {
        self.backgroundColor = color;
    }
}

- (void)lg_removeGlassEffect {
    AmethystLiquidGlassConfig *config = objc_getAssociatedObject(self, kLiquidGlassConfigKey);
    if (!config) return;
    [config.effectView removeFromSuperview];
    config.effectView = nil;
    if (config.baseColorCaptured) {
        self.backgroundColor = config.baseColor;
    }
}

- (BOOL)lg_hasGlassEffect {
    AmethystLiquidGlassConfig *config = objc_getAssociatedObject(self, kLiquidGlassConfigKey);
    return config.effectView != nil && config.effectView.superview == self;
}

+ (void)lg_refreshAllInWindows {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self lg_refreshAllInWindows];
        });
        return;
    }

    void (^walk)(UIView *) = ^(UIView *view) {
        if (objc_getAssociatedObject(view, kLiquidGlassConfigKey)) {
            [view lg_refreshLiquidGlass];
        }
        for (UIView *subview in [view.subviews copy]) {
            walk(subview);
        }
    };

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            walk(window);
        }
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        walk(window);
    }
}

@end
