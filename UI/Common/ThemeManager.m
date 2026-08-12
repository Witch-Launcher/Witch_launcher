#import "ThemeManager.h"
#import <CoreImage/CoreImage.h>

NSString * const ThemeDidChangeNotification = @"ThemeDidChangeNotification";

@interface ThemeManager ()
@property (nonatomic) UITraitCollection *currentTraitCollection;
@property (nonatomic) NSMutableDictionary *colorOverrides;
@end

@implementation ThemeManager

+ (ThemeManager *)shared {
    static ThemeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _interfaceStyle = UIUserInterfaceStyleUnspecified;
        _colorOverrides = [NSMutableDictionary dictionary];
        _backgroundBlurIntensity = 0;
        _uiOpacity = 1.0;
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            @"amethyst_ui_opacity": @1.0
        }];
        [self loadSavedPreferences];
    }
    return self;
}

- (void)loadSavedPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger style = [defaults integerForKey:@"amethyst_interface_style"];
    if (style > 0) {
        _interfaceStyle = style;
    }

    NSArray *colorKeys = @[@"amethyst_accent_color", @"amethyst_bg_color", @"amethyst_card_bg_color",
                           @"amethyst_sidebar_bg_color", @"amethyst_topbar_bg_color", @"amethyst_rightpanel_bg_color",
                           @"amethyst_text_color", @"amethyst_secondary_text_color"];
    for (NSString *key in colorKeys) {
        [self loadModeColorsForKey:key legacyHex:[defaults stringForKey:key]];
    }

    _backgroundBlurIntensity = [defaults floatForKey:@"amethyst_bg_blur"];
    _uiOpacity = [defaults floatForKey:@"amethyst_ui_opacity"];

    NSString *imgPath = [defaults stringForKey:@"amethyst_bg_image"];
    if (imgPath) {
        _backgroundImage = [UIImage imageWithContentsOfFile:imgPath];
        [self processBackgroundBlur];
    }

    NSString *videoPath = [defaults stringForKey:@"amethyst_bg_video"];
    if (videoPath) {
        _backgroundVideoURL = [NSURL fileURLWithPath:videoPath];
    }
}

- (void)loadModeColorsForKey:(NSString *)key legacyHex:(NSString *)legacyHex {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *darkKey = [self modePrefKeyFor:key dark:YES];
    NSString *lightKey = [self modePrefKeyFor:key dark:NO];
    NSString *darkHex = [defaults stringForKey:darkKey];
    NSString *lightHex = [defaults stringForKey:lightKey];

    if (legacyHex && !darkHex && !lightHex) {
        [defaults setObject:legacyHex forKey:darkKey];
        [defaults setObject:legacyHex forKey:lightKey];
        [defaults removeObjectForKey:key];
        _colorOverrides[darkKey] = [self colorFromHex:legacyHex];
        _colorOverrides[lightKey] = [self colorFromHex:legacyHex];
        return;
    }
    if (darkHex) _colorOverrides[darkKey] = [self colorFromHex:darkHex];
    if (lightHex) _colorOverrides[lightKey] = [self colorFromHex:lightHex];
}

- (NSString *)modePrefKeyFor:(NSString *)key dark:(BOOL)dark {
    return [key stringByAppendingFormat:@".%@", dark ? @"dark" : @"light"];
}

- (UIColor *)colorOverrideForKey:(NSString *)key {
    return [self colorOverrideForKey:key darkMode:self.isDarkMode];
}

- (UIColor *)colorOverrideForKey:(NSString *)key darkMode:(BOOL)dark {
    UIColor *color = _colorOverrides[[self modePrefKeyFor:key dark:dark]];
    if (!color) color = _colorOverrides[key];
    return color;
}

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    _backgroundImage = backgroundImage;
    _blurredBackgroundImage = nil;
    _backgroundVideoURL = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"amethyst_bg_video"];
    if (backgroundImage && _backgroundBlurIntensity > 0) {
        [self processBackgroundBlur];
    }
    [self broadcastThemeChange];
}

- (void)setBackgroundVideoURL:(NSURL *)backgroundVideoURL {
    _backgroundVideoURL = backgroundVideoURL;
    _backgroundImage = nil;
    _blurredBackgroundImage = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"amethyst_bg_image"];
    if (backgroundVideoURL) {
        [[NSUserDefaults standardUserDefaults] setObject:backgroundVideoURL.path forKey:@"amethyst_bg_video"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"amethyst_bg_video"];
    }
    [self broadcastThemeChange];
}

- (BOOL)hasCustomBackground {
    return _backgroundImage != nil || _backgroundVideoURL != nil;
}

- (UIColor *)contentBackgroundColor {
    return self.hasCustomBackground ? [UIColor clearColor] : self.backgroundColor;
}

- (void)setBackgroundBlurIntensity:(CGFloat)backgroundBlurIntensity {
    _backgroundBlurIntensity = backgroundBlurIntensity;
    [[NSUserDefaults standardUserDefaults] setFloat:backgroundBlurIntensity forKey:@"amethyst_bg_blur"];
    if (_backgroundImage) {
        [self processBackgroundBlur];
    }
    [self broadcastThemeChange];
}

- (void)setUiOpacity:(CGFloat)uiOpacity {
    _uiOpacity = uiOpacity;
    [[NSUserDefaults standardUserDefaults] setFloat:uiOpacity forKey:@"amethyst_ui_opacity"];
    [self broadcastThemeChange];
}

- (void)updateBackgroundBlur {
    if (_backgroundImage && _backgroundBlurIntensity > 0) {
        [self processBackgroundBlur];
    } else {
        _blurredBackgroundImage = nil;
    }
    [self broadcastThemeChange];
}

- (void)processBackgroundBlur {
    if (!_backgroundImage || _backgroundBlurIntensity <= 0) {
        _blurredBackgroundImage = nil;
        return;
    }
    CGImageRef cgImage = _backgroundImage.CGImage;
    if (!cgImage) {
        _blurredBackgroundImage = nil;
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
        CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [filter setValue:inputImage forKey:kCIInputImageKey];
        [filter setValue:@(self->_backgroundBlurIntensity) forKey:kCIInputRadiusKey];

        CIContext *context = [CIContext contextWithOptions:nil];
        CIImage *outputImage = [filter outputImage];
        CGImageRef cgImage = [context createCGImage:outputImage fromRect:[inputImage extent]];
        UIImage *blurred = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_blurredBackgroundImage = blurred;
            [self broadcastThemeChange];
        });
    });
}

- (UIColor *)colorFromHex:(NSString *)hex {
    hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length == 6) {
        unsigned int rgb = 0;
        [[NSScanner scannerWithString:hex] scanHexInt:&rgb];
        return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
    }
    return self.accentColor;
}

- (UIColor *)lighterColor:(UIColor *)color {
    CGFloat h, s, b, a;
    if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return [UIColor colorWithHue:h saturation:MAX(s - 0.1, 0) brightness:MIN(b + 0.15, 1.0) alpha:a];
    }
    return color;
}

- (BOOL)isDarkMode {
    if (_interfaceStyle == UIUserInterfaceStyleUnspecified) {
        return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return _interfaceStyle == UIUserInterfaceStyleDark;
}

- (UIColor *)accentColor {
    return [self colorOverrideForKey:@"amethyst_accent_color"]
        ?: [UIColor colorWithRed:0.067 green:0.235 blue:0.522 alpha:1.0];
}

- (UIColor *)accentHoverColor {
    return [self lighterColor:self.accentColor];
}

- (UIColor *)backgroundColor {
    UIColor *override = [self colorOverrideForKey:@"amethyst_bg_color"];
    UIColor *color = override;
    if (!color) color = [self isDarkMode] ? [UIColor colorWithRed:0.039 green:0.039 blue:0.047 alpha:1.0] : [UIColor colorWithRed:0.949 green:0.949 blue:0.957 alpha:1.0];
    return [color colorWithAlphaComponent:_uiOpacity];
}

- (UIColor *)cardBackgroundColor {
    UIColor *override = [self colorOverrideForKey:@"amethyst_card_bg_color"];
    UIColor *color = override;
    if (!color) color = [self isDarkMode] ? [UIColor colorWithRed:0.086 green:0.086 blue:0.094 alpha:1.0] : [UIColor whiteColor];
    return [color colorWithAlphaComponent:_uiOpacity];
}

- (UIColor *)sidebarBackgroundColor {
    UIColor *override = [self colorOverrideForKey:@"amethyst_sidebar_bg_color"];
    UIColor *color = override;
    if (!color) color = [self isDarkMode] ? [UIColor colorWithRed:0.051 green:0.051 blue:0.059 alpha:1.0] : [UIColor colorWithRed:0.969 green:0.969 blue:0.973 alpha:1.0];
    return [color colorWithAlphaComponent:_uiOpacity];
}

- (UIColor *)topBarBackgroundColor {
    UIColor *override = [self colorOverrideForKey:@"amethyst_topbar_bg_color"];
    UIColor *color = override;
    if (!color) color = [self isDarkMode] ? [UIColor colorWithRed:0.055 green:0.055 blue:0.063 alpha:1.0] : [UIColor colorWithRed:0.973 green:0.973 blue:0.976 alpha:1.0];
    return [color colorWithAlphaComponent:_uiOpacity];
}

- (UIColor *)rightPanelBackgroundColor {
    UIColor *override = [self colorOverrideForKey:@"amethyst_rightpanel_bg_color"];
    UIColor *color = override;
    if (!color) color = self.cardBackgroundColor;
    return [color colorWithAlphaComponent:_uiOpacity];
}

- (UIColor *)primaryTextColor {
    return [self colorOverrideForKey:@"amethyst_text_color"]
        ?: ([self isDarkMode] ? [UIColor whiteColor] : [UIColor blackColor]);
}

- (UIColor *)secondaryTextColor {
    return [self colorOverrideForKey:@"amethyst_secondary_text_color"]
        ?: ([self isDarkMode] ? [UIColor colorWithRed:0.596 green:0.596 blue:0.620 alpha:1.0] : [UIColor colorWithRed:0.557 green:0.557 blue:0.576 alpha:1.0]);
}

- (UIColor *)separatorColor {
    return [self isDarkMode] ? [UIColor colorWithRed:0.220 green:0.220 blue:0.227 alpha:1.0] : [UIColor colorWithRed:0.780 green:0.780 blue:0.800 alpha:1.0];
}

- (UIColor *)successColor {
    return [UIColor colorWithRed:0.384 green:1.0 blue:0.541 alpha:1.0];
}

- (UIColor *)warningColor {
    return [UIColor colorWithRed:1.0 green:0.937 blue:0.459 alpha:1.0];
}

- (UIColor *)errorColor {
    return [UIColor colorWithRed:1.0 green:0.388 blue:0.357 alpha:1.0];
}

- (UIColor *)buttonTextColor {
    return [UIColor whiteColor];
}

- (void)applyAccentColor:(UIColor *)color {
    [self applyAccentColor:color darkMode:self.isDarkMode];
}

- (void)applyAccentColor:(UIColor *)color darkMode:(BOOL)dark {
    NSString *modeKey = [self modePrefKeyFor:@"amethyst_accent_color" dark:dark];
    _colorOverrides[modeKey] = color;
    NSString *hex = [self hexStringFromColor:color];
    [[NSUserDefaults standardUserDefaults] setObject:hex forKey:modeKey];
    [self broadcastThemeChange];
}

- (void)applyColor:(UIColor *)color forKey:(NSString *)key {
    [self applyColor:color forKey:key darkMode:self.isDarkMode];
}

- (void)applyColor:(UIColor *)color forKey:(NSString *)key darkMode:(BOOL)dark {
    NSString *modeKey = [self modePrefKeyFor:key dark:dark];
    _colorOverrides[modeKey] = color;
    NSString *hex = [self hexStringFromColor:color];
    [[NSUserDefaults standardUserDefaults] setObject:hex forKey:modeKey];
    [self broadcastThemeChange];
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

- (void)applyInterfaceStyle:(UIUserInterfaceStyle)style {
    _interfaceStyle = style;
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:@"amethyst_interface_style"];
    [self broadcastThemeChange];
}

- (void)applyThemeToAllWindows {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        window.overrideUserInterfaceStyle = _interfaceStyle;
    }
    [self broadcastThemeChange];
}

- (void)broadcastThemeChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:ThemeDidChangeNotification object:nil];
}

- (void)resetAppearance {
    [_colorOverrides removeAllObjects];

    NSArray *colorKeys = @[@"amethyst_accent_color", @"amethyst_bg_color", @"amethyst_card_bg_color",
                           @"amethyst_sidebar_bg_color", @"amethyst_topbar_bg_color", @"amethyst_rightpanel_bg_color",
                           @"amethyst_text_color", @"amethyst_secondary_text_color"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in colorKeys) {
        [defaults removeObjectForKey:[self modePrefKeyFor:key dark:YES]];
        [defaults removeObjectForKey:[self modePrefKeyFor:key dark:NO]];
        [defaults removeObjectForKey:key];
    }
    [defaults removeObjectForKey:@"amethyst_bg_image"];
    [defaults removeObjectForKey:@"amethyst_bg_video"];
    [defaults removeObjectForKey:@"amethyst_bg_blur"];
    [defaults removeObjectForKey:@"amethyst_ui_opacity"];

    _backgroundImage = nil;
    _blurredBackgroundImage = nil;
    _backgroundVideoURL = nil;
    _backgroundBlurIntensity = 0;
    _uiOpacity = 1.0;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *imgPath = [paths.firstObject stringByAppendingPathComponent:@"amethyst_bg.png"];
    [[NSFileManager defaultManager] removeItemAtPath:imgPath error:nil];
    NSString *videoPath = [paths.firstObject stringByAppendingPathComponent:@"amethyst_bg.mp4"];
    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];

    [self broadcastThemeChange];
}

@end
