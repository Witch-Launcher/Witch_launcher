#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Floating-overlay replacement for the old ProfileSettings popup.
// Full-page push with Back button; content lives on floating cards and the
// tab switcher is a floating pill above the bottom edge (no nested scrolls).
// Tabs: Overview | Mods | Shaders | Resources | Worlds.
// Icons are SF Symbols template only — no sticker, no emoji, no SVG dep.
@interface ProfileTabbedPageViewController : UIViewController

@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) BOOL isNewProfile;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew;

@end

NS_ASSUME_NONNULL_END
