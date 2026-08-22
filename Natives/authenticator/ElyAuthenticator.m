#import "AFNetworking.h"
#import "BaseAuthenticator.h"
#import "../LauncherPreferences.h"
#import "../ios_uikit_bridge.h"
#import "../utils.h"

static NSString * const kElyAuthBaseURL = @"https://authserver.ely.by";
static NSString * const kElyOAuthAuthorizeURL = @"https://account.ely.by/oauth2/v1";
static NSString * const kElyOAuthTokenURL = @"https://account.ely.by/api/oauth2/v1/token";
static NSString * const kElyOAuthUserinfoURL = @"https://account.ely.by/api/account/v1/info";

static NSString * const kElyOAuthScope = @"offline_access minecraft_server_session account_info";

NSString *ELY_OAUTH_CLIENT_ID = @"";
NSString *ELY_OAUTH_CLIENT_SECRET = @"";
NSString *ELY_OAUTH_REDIRECT_URI = @"";

static NSString *dashedUUID(NSString *uuid) {
    if (uuid.length == 32) {
        return [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
            [uuid substringWithRange:NSMakeRange(0, 8)],
            [uuid substringWithRange:NSMakeRange(8, 4)],
            [uuid substringWithRange:NSMakeRange(12, 4)],
            [uuid substringWithRange:NSMakeRange(16, 4)],
            [uuid substringWithRange:NSMakeRange(20, 12)]];
    }
    return uuid;
}

@interface ElyAuthenticator ()
@property (nonatomic, copy) NSString *pendingRefreshToken;
@end

static NSString *elyErrorMessage(NSError *error) {
    NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
    if (errorData.length > 0) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil];
        NSString *message = dict[@"errorMessage"] ?: dict[@"error_description"] ?: dict[@"message"];
        if (message.length > 0) return message;
    }
    return error.localizedDescription;
}

@implementation ElyAuthenticator

#pragma mark Shared device client token

+ (NSString *)deviceClientToken {
    NSString *token = getPrefObject(@"internal.ely_client_token");
    if (token.length == 0) {
        token = [[NSUUID UUID] UUIDString].lowercaseString;
        setPrefObject(@"internal.ely_client_token", token);
    }
    return token;
}

+ (NSURL *)oauthAuthorizeURL {
    if (ELY_OAUTH_CLIENT_ID.length == 0 || ELY_OAUTH_REDIRECT_URI.length == 0) {
        return nil;
    }
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"+"];
    NSString *state = [[NSUUID UUID] UUIDString];
    NSString *query = [NSString stringWithFormat:@"client_id=%@&redirect_uri=%@&response_type=code&scope=%@&state=%@",
        [ELY_OAUTH_CLIENT_ID stringByAddingPercentEncodingWithAllowedCharacters:allowed],
        [ELY_OAUTH_REDIRECT_URI stringByAddingPercentEncodingWithAllowedCharacters:allowed],
        [kElyOAuthScope stringByAddingPercentEncodingWithAllowedCharacters:allowed],
        state];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", kElyOAuthAuthorizeURL, query]];
}

#pragma mark Init

- (id)initWithCredentials:(NSString *)login password:(NSString *)password totp:(NSString *)totp {
    self = [self initWithData:[NSMutableDictionary dictionary]];
    self.authData[@"input"] = login;
    self.authData[@"password"] = password;
    if (totp.length > 0) self.authData[@"totp"] = totp;
    return self;
}

- (id)initWithOAuthCode:(NSString *)code {
    self = [self initWithData:[NSMutableDictionary dictionary]];
    self.authData[@"input"] = code;
    self.authData[@"oauth"] = @YES;
    return self;
}

#pragma mark Login

- (void)loginWithCallback:(Callback)callback {
    if ([self.authData[@"oauth"] boolValue]) {
        [self exchangeOAuthCode:self.authData[@"input"] callback:callback];
    } else {
        [self authenticateWithCallback:callback];
    }
}

- (void)authenticateWithCallback:(Callback)callback {
    callback(localize(@"login.ely.progress.authenticate", nil), YES);

    NSString *password = self.authData[@"password"];
    if ([self.authData[@"totp"] length] > 0) {
        password = [NSString stringWithFormat:@"%@:%@", password, self.authData[@"totp"]];
    }

    NSDictionary *data = @{
        @"username": self.authData[@"input"],
        @"password": password ?: @"",
        @"clientToken": [ElyAuthenticator deviceClientToken],
        @"requestUser": @YES
    };

    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    [manager POST:[NSString stringWithFormat:@"%@/auth/authenticate", kElyAuthBaseURL] parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        self.authData[@"accountType"] = @"elyby";
        self.authData[@"accessToken"] = response[@"accessToken"];
        self.authData[@"clientToken"] = response[@"clientToken"] ?: [ElyAuthenticator deviceClientToken];
        self.authData[@"profileId"] = dashedUUID(response[@"selectedProfile"][@"id"]);
        self.authData[@"oldusername"] = self.authData[@"username"];
        self.authData[@"username"] = response[@"selectedProfile"][@"name"];
        self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + 86400);
        [self.authData removeObjectsForKeys:@[@"password", @"totp", @"input"]];
        callback(nil, [self saveChanges]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        NSDictionary *dict = errorData ? [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil] : nil;
        BOOL needsTotp = self.authData[@"totp"] == nil
            && [dict[@"error"] isEqualToString:@"ForbiddenOperationException"]
            && [[dict[@"errorMessage"] localizedLowercaseString] containsString:@"two factor"];
        if (needsTotp) {
            callback(@"TOTP_REQUIRED", NO);
        } else {
            callback(elyErrorMessage(error), NO);
        }
    }];
}

#pragma mark OAuth2

- (void)exchangeOAuthCode:(NSString *)code callback:(Callback)callback {
    callback(localize(@"login.ely.progress.oauthExchange", nil), YES);

    NSDictionary *data = @{
        @"client_id": ELY_OAUTH_CLIENT_ID,
        @"client_secret": ELY_OAUTH_CLIENT_SECRET,
        @"redirect_uri": ELY_OAUTH_REDIRECT_URI,
        @"grant_type": @"authorization_code",
        @"code": code
    };

    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    [manager POST:kElyOAuthTokenURL parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        self.pendingRefreshToken = response[@"refresh_token"];
        self.authData[@"accessToken"] = response[@"access_token"];
        long expiresIn = response[@"expires_in"] ? [response[@"expires_in"] longValue] : 86400;
        self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + expiresIn);
        [self fetchOAuthUserInfo:callback];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(elyErrorMessage(error), NO);
    }];
}

- (void)fetchOAuthUserInfo:(Callback)callback {
    callback(localize(@"login.ely.progress.userInfo", nil), YES);

    NSDictionary *headers = @{
        @"Authorization": [NSString stringWithFormat:@"Bearer %@", self.authData[@"accessToken"]]
    };
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    [manager GET:kElyOAuthUserinfoURL parameters:nil headers:headers progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        self.authData[@"accountType"] = @"elyby";
        self.authData[@"profileId"] = dashedUUID(response[@"uuid"]);
        self.authData[@"oldusername"] = self.authData[@"username"];
        self.authData[@"username"] = response[@"username"];
        [self.authData removeObjectForKey:@"input"];
        callback(nil, [self saveChanges]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(elyErrorMessage(error), NO);
    }];
}

- (void)refreshOAuthTokenWithCallback:(Callback)callback {
    NSString *refreshToken = self.pendingRefreshToken ?: [ElyAuthenticator storedRefreshTokenForProfile:self.authData[@"profileId"]];
    if (refreshToken.length == 0) {
        showDialog(localize(@"Error", nil), localize(@"login.ely.error.relogin", nil));
        callback(nil, YES);
        return;
    }

    callback(localize(@"login.ely.progress.refresh", nil), YES);

    NSDictionary *data = @{
        @"client_id": ELY_OAUTH_CLIENT_ID,
        @"client_secret": ELY_OAUTH_CLIENT_SECRET,
        @"grant_type": @"refresh_token",
        @"scope": kElyOAuthScope,
        @"refresh_token": refreshToken
    };

    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    [manager POST:kElyOAuthTokenURL parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        self.authData[@"accessToken"] = response[@"access_token"];
        if (response[@"refresh_token"]) self.pendingRefreshToken = response[@"refresh_token"];
        long expiresIn = response[@"expires_in"] ? [response[@"expires_in"] longValue] : 86400;
        self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + expiresIn);
        [self saveChanges];
        callback(nil, YES);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(elyErrorMessage(error), NO);
    }];
}

#pragma mark Yggdrasil refresh

- (void)refreshYggdrasilTokenWithCallback:(Callback)callback {
    callback(localize(@"login.ely.progress.validate", nil), YES);

    NSDictionary *validateData = @{ @"accessToken": self.authData[@"accessToken"] };
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    [manager POST:[NSString stringWithFormat:@"%@/auth/validate", kElyAuthBaseURL] parameters:validateData headers:nil progress:nil success:^(NSURLSessionDataTask *task, id response) {
        callback(nil, YES);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(localize(@"login.ely.progress.refresh", nil), YES);

        NSDictionary *refreshData = @{
            @"accessToken": self.authData[@"accessToken"],
            @"clientToken": self.authData[@"clientToken"] ?: [ElyAuthenticator deviceClientToken],
            @"requestUser": @YES
        };
        AFHTTPSessionManager *refreshManager = AFHTTPSessionManager.manager;
        refreshManager.requestSerializer = AFJSONRequestSerializer.serializer;
        [refreshManager POST:[NSString stringWithFormat:@"%@/auth/refresh", kElyAuthBaseURL] parameters:refreshData headers:nil progress:nil success:^(NSURLSessionDataTask *task2, NSDictionary *response) {
            self.authData[@"accessToken"] = response[@"accessToken"];
            if (response[@"selectedProfile"][@"name"]) {
                self.authData[@"oldusername"] = self.authData[@"username"];
                self.authData[@"username"] = response[@"selectedProfile"][@"name"];
                self.authData[@"profileId"] = dashedUUID(response[@"selectedProfile"][@"id"]);
            }
            self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + 86400);
            callback(nil, [self saveChanges]);
        } failure:^(NSURLSessionDataTask *task2, NSError *refreshError) {
            callback(elyErrorMessage(refreshError), NO);
        }];
    }];
}

- (void)refreshTokenWithCallback:(Callback)callback {
    if ([self.authData[@"oauth"] boolValue]) {
        [self refreshOAuthTokenWithCallback:callback];
    } else {
        [self refreshYggdrasilTokenWithCallback:callback];
    }
}

#pragma mark Persistence

- (BOOL)saveChanges {
    [self.authData removeObjectsForKeys:@[@"password", @"totp", @"input"]];
    if (self.pendingRefreshToken) {
        BOOL saved = [self storeElyRefreshToken:self.pendingRefreshToken];
        if (!saved) {
            showDialog(localize(@"Error", nil), @"Failed to save account tokens to keychain");
            return NO;
        }
        self.pendingRefreshToken = nil;
    }
    return [super saveChanges];
}

#pragma mark Keychain

+ (NSDictionary *)keychainQueryForKey:(NSString *)profile extraInfo:(NSDictionary *)extra {
    NSMutableDictionary *dict = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecAttrService: @"ElyToken",
        (id)kSecAttrAccount: profile,
    }.mutableCopy;
    if (extra) {
        [dict addEntriesFromDictionary:extra];
    }
    return dict;
}

+ (NSString *)storedRefreshTokenForProfile:(NSString *)profile {
    if (profile.length == 0) return nil;
    NSDictionary *dict = [ElyAuthenticator keychainQueryForKey:profile extraInfo:@{
        (id)kSecMatchLimit: (id)kSecMatchLimitOne,
        (id)kSecReturnData: (id)kCFBooleanTrue
    }];
    CFTypeRef resultData = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dict, &resultData);
    if (status != errSecSuccess) return nil;
    NSError *error = nil;
    NSDictionary *result = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[NSDictionary.class, NSString.class]] fromData:(__bridge NSData *)resultData error:&error];
    if (error) {
        NSDebugLog(@"[ElyAuthenticator] Failed to unarchive token data: %@", error);
        return nil;
    }
    return result[@"refreshToken"];
}

- (BOOL)storeElyRefreshToken:(NSString *)refreshToken {
    if (!refreshToken) return NO;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{
        @"refreshToken": refreshToken,
    } requiringSecureCoding:YES error:nil];
    NSDictionary *dict = [ElyAuthenticator keychainQueryForKey:self.authData[@"profileId"] extraInfo:@{
        (id)kSecAttrAccessible: (id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        (id)kSecValueData: data
    }];
    SecItemDelete((__bridge CFDictionaryRef)dict);
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)dict, NULL);
    return status == errSecSuccess;
}

+ (void)clearTokenDataOfProfile:(NSString *)profile {
    NSDictionary *dict = [ElyAuthenticator keychainQueryForKey:profile extraInfo:nil];
    SecItemDelete((__bridge CFDictionaryRef)dict);
}

+ (void)invalidateAccessToken:(NSString *)accessToken clientToken:(NSString *)clientToken {
    if (accessToken.length == 0) return;
    NSDictionary *data = @{
        @"accessToken": accessToken,
        @"clientToken": clientToken ?: [ElyAuthenticator deviceClientToken]
    };
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    [manager POST:[NSString stringWithFormat:@"%@/auth/invalidate", kElyAuthBaseURL] parameters:data headers:nil progress:nil success:nil failure:nil];
}

@end