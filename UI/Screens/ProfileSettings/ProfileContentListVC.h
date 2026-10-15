#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// One list screen reused for Mods / Shaders / Resource packs.
// Floating-card rows, token-guarded icons, profile-scoped storage.
@interface ProfileContentListVC : UIViewController

@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic, copy) NSString *category; // InstalledItemCategory*

- (instancetype)initWithProfile:(NSMutableDictionary *)profile category:(NSString *)category;
- (void)reloadContent;

@end

NS_ASSUME_NONNULL_END
