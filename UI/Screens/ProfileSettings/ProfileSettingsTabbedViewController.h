#import <UIKit/UIKit.h>

@class ProfileSettingsTabbedViewController;

@protocol ProfileSettingsTabbedDelegate <NSObject>
- (void)profileSettingsDidSave:(ProfileSettingsTabbedViewController *)controller;
- (void)profileSettingsDidCancel:(ProfileSettingsTabbedViewController *)controller;
@end

@interface ProfileSettingsTabbedViewController : UIViewController

@property (nonatomic, weak) id<ProfileSettingsTabbedDelegate> delegate;
@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) BOOL isNewProfile;

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew;

@end