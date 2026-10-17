#import <UIKit/UIKit.h>

extern NSString * const ThemeDidChangeNotification;

@interface ThemeManager : NSObject

@property (class, readonly) ThemeManager *shared;

@property (nonatomic) UIColor *accentColor;
@property (nonatomic) UIColor *accentHoverColor;
@property (nonatomic) UIUserInterfaceStyle interfaceStyle;

@property (nonatomic) UIColor *backgroundColor;
@property (nonatomic) UIColor *cardBackgroundColor;
@property (nonatomic) UIColor *sidebarBackgroundColor;
@property (nonatomic) UIColor *topBarBackgroundColor;
@property (nonatomic) UIColor *rightPanelBackgroundColor;
@property (nonatomic, readonly) UIColor *primaryTextColor;
@property (nonatomic, readonly) UIColor *secondaryTextColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *successColor;
@property (nonatomic, readonly) UIColor *warningColor;
@property (nonatomic, readonly) UIColor *errorColor;
@property (nonatomic, readonly) UIColor *buttonTextColor;
// Luminance-based readable text color for an arbitrary background (same
// rule as buttonTextColor, but evaluated against the given color instead
// of the accent). Use for badges, pills and selected segments.
- (UIColor *)contrastTextColorForBackground:(UIColor *)background;
// Theme a segmented control: accent selection + readable titles in both
// modes (default mono accent is white in dark / black in light, so a
// hardcoded white selected title turns invisible). Preserves each state's
// font, only fixes colors.
- (void)styleSegmentedControl:(UISegmentedControl *)seg;

@property (nonatomic) UIImage *backgroundImage;
@property (nonatomic) UIImage *blurredBackgroundImage;
@property (nonatomic) NSURL *backgroundVideoURL;
@property (nonatomic, readonly) BOOL hasCustomBackground;
@property (nonatomic, readonly) UIColor *contentBackgroundColor;
@property (nonatomic) CGFloat backgroundBlurIntensity;
@property (nonatomic) CGFloat uiOpacity;
@property (nonatomic) BOOL uiBorderEnabled;
@property (nonatomic, readonly) UIColor *uiBorderColor;
@property (nonatomic) CGFloat uiBorderWidth;
@property (nonatomic) CGFloat uiBorderCornerRadius;

- (void)applyAccentColor:(UIColor *)color;
- (void)applyAccentColor:(UIColor *)color darkMode:(BOOL)dark;
- (void)applyColor:(UIColor *)color forKey:(NSString *)key;
- (void)applyColor:(UIColor *)color forKey:(NSString *)key darkMode:(BOOL)dark;
- (UIColor *)colorOverrideForKey:(NSString *)key;
- (UIColor *)colorOverrideForKey:(NSString *)key darkMode:(BOOL)dark;
- (void)applyInterfaceStyle:(UIUserInterfaceStyle)style;
- (void)applyThemeToAllWindows;
- (void)resetAppearance;
- (void)broadcastThemeChange;
- (void)updateBackgroundBlur;
- (void)applyBorderStyleToAllWindows;
- (BOOL)isDarkMode;

@end
