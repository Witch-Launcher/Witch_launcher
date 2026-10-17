#import <UIKit/UIKit.h>
#import "ProfileAvatarManager.h"

@class ProfileListViewController;

@protocol ProfileListViewControllerDelegate <NSObject>
- (void)profileListDidUpdateProfile:(NSMutableDictionary *)updatedProfile;
@end

@interface ProfileListViewController : UIViewController

@property (nonatomic, weak) id<ProfileListViewControllerDelegate> delegate;
@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) BOOL isCurrentProfile;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile;

@end