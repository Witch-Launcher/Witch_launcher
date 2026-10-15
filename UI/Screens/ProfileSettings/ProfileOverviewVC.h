#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Overview tab: profile header card (avatar + rename-safe), server/profile
// storage info, and the classic settings form (General/Video/Controls/Java).
@interface ProfileOverviewVC : UIViewController

@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) BOOL isNewProfile;
@property (nonatomic, copy, nullable) NSString *originalName;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew;
- (void)refreshHeader;
- (BOOL)saveProfile; // NO when validation failed (error already shown)

@end

NS_ASSUME_NONNULL_END
