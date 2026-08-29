#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ProfileAvatarManager : NSObject

@property (class, readonly) ProfileAvatarManager *shared;

- (UIImage *)avatarImageForKey:(NSString *)key;
- (UIImage *)avatarImageForProfile:(NSDictionary *)profile;
- (void)updateAppIconForCurrentProfile;
- (NSString *)alternateIconNameForKey:(NSString *)key;

@end