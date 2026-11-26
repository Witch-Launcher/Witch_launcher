#import <UIKit/UIKit.h>

extern NSString * const ThemeDidChangeNotification;
// Posted instead of ThemeDidChangeNotification while the user drags the
// shell border sliders: only the root shell listens, so redrawing the
// outline stays cheap. A coalesced full theme broadcast follows shortly
// after the interaction settles.
extern NSString * const ShellBorderDidChangeNotification;

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
// Theme a UISearchBar: transparent bar + translucent themed field, so the
// iOS 26 glass chrome never paints an opaque white row over the theme.
- (void)styleSearchBar:(UISearchBar *)bar;

@property (nonatomic) UIImage *backgroundImage;
@property (nonatomic) UIImage *blurredBackgroundImage;
@property (nonatomic) NSURL *backgroundVideoURL;
@property (nonatomic, readonly) BOOL hasCustomBackground;
@property (nonatomic, readonly) UIColor *contentBackgroundColor;
@property (nonatomic) CGFloat backgroundBlurIntensity;
@property (nonatomic) CGFloat uiOpacity;
// Global visual scale for the launcher shell, browser-zoom style. 1.0 = 100%.
// Also applies to sheets, pickers and pages presented by the shell and to
// AppSheet windows; the Minecraft surface and keyboards stay at 100%.
@property (nonatomic) CGFloat uiScale;
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
- (void)applyUIScaleToAllWindows;
// Idempotent browser-zoom application for one root view; returns YES when
// the view changed (used by the shell's layout pass to survive rotation).
- (BOOL)applyUIScaleToRootView:(UIView *)rootView inWindow:(UIWindow *)window;
// Build the themed UINavigationBarAppearance and apply it to the appearance
// proxy plus every live bar in every window, so Done/Save bars follow the
// user's colors instead of the default system look.
- (void)applyNavigationBarTheme;
- (void)resetAppearance;
- (void)broadcastThemeChange;
- (void)notifyShellBorderChange;
- (void)updateBackgroundBlur;
- (void)applyBorderStyleToAllWindows;
- (BOOL)isDarkMode;

@end
