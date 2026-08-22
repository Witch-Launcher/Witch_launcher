#import "Foundation/Foundation.h"

typedef void(^Callback)(id status, BOOL success);

@interface BaseAuthenticator : NSObject

@property(class) BaseAuthenticator *current;

@property NSMutableDictionary *authData;

+ (id)loadSavedName:(NSString *)name;
+ (NSDictionary *)tokenDataOfProfile:(NSString *)profile;

- (id)initWithInput:(NSString *)string;
- (id)initWithData:(NSMutableDictionary *)data;
- (void)loginWithCallback:(Callback)callback;
- (void)refreshTokenWithCallback:(Callback)callback;
- (BOOL)saveChanges;

@end

@interface LocalAuthenticator : BaseAuthenticator
@end

@interface MicrosoftAuthenticator : BaseAuthenticator

+ (void)clearTokenDataOfProfile:(NSString *)profile;

@end

@interface ElyAuthenticator : BaseAuthenticator

- (id)initWithCredentials:(NSString *)login password:(NSString *)password totp:(NSString *)totp;
- (id)initWithOAuthCode:(NSString *)code;
+ (NSURL *)oauthAuthorizeURL;
+ (void)invalidateAccessToken:(NSString *)accessToken clientToken:(NSString *)clientToken;
+ (void)clearTokenDataOfProfile:(NSString *)profile;

@end
