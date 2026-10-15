#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Full-page replacement for the old ProfileSettings popup (FormSheet).
// Pushed fullscreen via AmethystRootViewController pushContent:animated: so it
// has a real Back button, then splits into inner tabs:
//   Overview (server profile + settings) | Mods | Shaders | Resources.
// Icons are SF Symbols template only (tintable) — no sticker, no emoji, no SVG dep.
@interface ProfileDetailPageViewController : UIViewController

@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) BOOL isNewProfile;
@property (nonatomic, copy, nullable) NSString *originalName;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew;

@end

NS_ASSUME_NONNULL_END
