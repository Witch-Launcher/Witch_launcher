#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BackupOAuthProvider) {
    BackupOAuthProviderGoogleDrive,
    BackupOAuthProviderOneDrive,
    BackupOAuthProviderDropbox,
};

@interface BackupOAuth : NSObject

+ (instancetype)shared;

+ (NSString *)providerKeyForProvider:(BackupOAuthProvider)provider;
+ (NSString *)displayNameForProvider:(BackupOAuthProvider)provider;
+ (BOOL)isProviderConfigured:(BackupOAuthProvider)provider;

- (BOOL)isAuthorizedForProvider:(BackupOAuthProvider)provider;
- (void)authorizeProvider:(BackupOAuthProvider)provider
              presenting:(UIViewController *)presenting
              completion:(void (^)(NSError * _Nullable error))completion;
- (void)accessTokenForProvider:(BackupOAuthProvider)provider
                    completion:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion;
- (void)disconnectProvider:(BackupOAuthProvider)provider;

@end

NS_ASSUME_NONNULL_END
