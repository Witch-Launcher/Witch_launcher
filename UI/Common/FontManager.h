#import <UIKit/UIKit.h>

// User-selectable launcher font. A ttf/otf file is copied into
// POJAV_HOME/.amethyst/fonts, registered with CoreText, and applied by
// swizzling +[UIFont systemFontOfSize:] / systemFontOfSize:weight: so every
// existing "system font" call site picks it up. Monospace/named fonts
// (log views, Menlo, etc.) are intentionally left untouched.
@interface FontManager : NSObject

@property (class, readonly) FontManager *shared;

// Call once early (application:didFinishLaunchingWithOptions:) before UI is
// built: installs the swizzles and registers the saved custom font, if any.
+ (void)install;

- (BOOL)isEnabled;
- (NSString *)displayName; // custom font name, or localize(@"appearance.font_default")
- (BOOL)importFontAtURL:(NSURL *)url error:(NSError **)error;
- (void)useSystemFont;
- (void)refreshAllViews;

@end
