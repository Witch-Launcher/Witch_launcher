#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Worlds tab: saves/<world>/ read from level.dat (NBT) + icon.png,
// plus .zip imports. Tapping a world shows its datapacks.
@interface ProfileWorldsVC : UIViewController

@property (nonatomic) NSMutableDictionary *profile;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile;
- (void)reloadContent;

@end

NS_ASSUME_NONNULL_END
