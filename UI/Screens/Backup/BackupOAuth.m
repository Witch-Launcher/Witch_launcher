#import "BackupOAuth.h"
#import "BackupConfig.h"
#import "BackupKeychain.h"
#import "utils.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

static NSString *const kOAuthErrorDomain = @"WitchBackupOAuthErrorDomain";

static NSError *OAuthError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:kOAuthErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"OAuth error"}];
}

static NSString *OAuthPercentEncode(NSString *value) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSString *OAuthFormBody(NSDictionary<NSString *, NSString *> *params) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in params) {
        [parts addObject:[NSString stringWithFormat:@"%@=%@", OAuthPercentEncode(key), OAuthPercentEncode(params[key] ?: @"")]];
    }
    return [parts componentsJoinedByString:@"&"];
}

static NSString *OAuthRandomString(NSUInteger length) {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (SecRandomCopyBytes(kSecRandomDefault, length, data.mutableBytes) != errSecSuccess) {
        arc4random_buf(data.mutableBytes, length);
    }
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [base64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

static NSString *OAuthCodeChallenge(NSString *verifier) {
    NSData *data = [verifier dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSData *hash = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    NSString *base64 = [hash base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [base64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

static NSString *OAuthQueryValue(NSURL *url, NSString *name) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if ([item.name isEqualToString:name]) return item.value;
    }
    return nil;
}

@interface BackupOAuth () <ASWebAuthenticationPresentationContextProviding>
@property (nonatomic, strong) ASWebAuthenticationSession *session;
@property (nonatomic, copy) void (^authorizationCompletion)(NSError * _Nullable error);
@property (nonatomic) BackupOAuthProvider authorizationProvider;
@property (nonatomic, copy) NSString *authorizationState;
@property (nonatomic, copy) NSString *authorizationVerifier;
@property (nonatomic, weak) UIViewController *presentingViewController;
@end

@implementation BackupOAuth

+ (instancetype)shared {
    static BackupOAuth *oauth;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        oauth = [[BackupOAuth alloc] init];
    });
    return oauth;
}

+ (NSString *)providerKeyForProvider:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return @"oauth.gdrive";
        case BackupOAuthProviderOneDrive: return @"oauth.onedrive";
        case BackupOAuthProviderDropbox: return @"oauth.dropbox";
    }
    return @"oauth.unknown";
}

+ (NSString *)displayNameForProvider:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return @"Google Drive";
        case BackupOAuthProviderOneDrive: return @"OneDrive";
        case BackupOAuthProviderDropbox: return @"Dropbox";
    }
    return @"Cloud";
}

+ (BOOL)isProviderConfigured:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return [BackupConfig googleConfigured];
        case BackupOAuthProviderOneDrive: return [BackupConfig azureConfigured];
        case BackupOAuthProviderDropbox: return [BackupConfig dropboxConfigured];
    }
    return NO;
}

- (BOOL)isAuthorizedForProvider:(BackupOAuthProvider)provider {
    NSDictionary *token = [BackupKeychain dictionaryForKey:[self.class providerKeyForProvider:provider]];
    if (token.count == 0) return NO;
    if ([token[@"refresh_token"] isKindOfClass:[NSString class]] && [token[@"refresh_token"] length] > 0) return YES;
    double expiresAt = [token[@"expires_at"] doubleValue];
    return expiresAt > [[NSDate date] timeIntervalSince1970] + 30;
}

#pragma mark - Authorization

- (void)authorizeProvider:(BackupOAuthProvider)provider
              presenting:(UIViewController *)presenting
              completion:(void (^)(NSError * _Nullable))completion {
    if (![self.class isProviderConfigured:provider]) {
        if (completion) completion(OAuthError(1, [NSString stringWithFormat:localize(@"%@ is not configured in this build.", nil), [self.class displayNameForProvider:provider]]));
        return;
    }
    if (self.session) {
        if (completion) completion(OAuthError(2, localize(@"Another sign-in is already in progress.", nil)));
        return;
    }

    self.authorizationProvider = provider;
    self.authorizationCompletion = completion;
    self.presentingViewController = presenting;
    self.authorizationState = OAuthRandomString(24);
    self.authorizationVerifier = OAuthRandomString(64);

    NSURL *authURL = [self authorizationURLForProvider:provider];
    if (!authURL) {
        [self finishAuthorizationWithError:OAuthError(3, localize(@"Could not build the sign-in URL.", nil))];
        return;
    }

    NSString *callbackScheme = [self callbackSchemeForProvider:provider];
    self.session = [[ASWebAuthenticationSession alloc] initWithURL:authURL
                                                callbackURLScheme:callbackScheme
                                                completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        if (error) {
            if ([error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] && error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
                [self finishAuthorizationWithError:OAuthError(4, localize(@"Sign-in cancelled.", nil))];
            } else {
                [self finishAuthorizationWithError:error];
            }
            return;
        }
        [self handleCallbackURL:callbackURL];
    }];
    self.session.presentationContextProvider = self;
    self.session.prefersEphemeralWebBrowserSession = NO;
    if (![self.session start]) {
        [self finishAuthorizationWithError:OAuthError(5, localize(@"Could not open the sign-in page.", nil))];
    }
}

- (NSString *)callbackSchemeForProvider:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return [BackupConfig googleCallbackScheme];
        case BackupOAuthProviderOneDrive: return [BackupConfig azureCallbackScheme];
        case BackupOAuthProviderDropbox: return [BackupConfig dropboxCallbackScheme];
    }
    return @"";
}

- (NSString *)redirectURIForProvider:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return [BackupConfig googleRedirectURI];
        case BackupOAuthProviderOneDrive: return [BackupConfig azureRedirectURI];
        case BackupOAuthProviderDropbox: return [BackupConfig dropboxRedirectURI];
    }
    return @"";
}

- (NSURL *)authorizationURLForProvider:(BackupOAuthProvider)provider {
    NSString *base = nil;
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    NSString *challenge = OAuthCodeChallenge(self.authorizationVerifier);
    params[@"state"] = self.authorizationState;
    params[@"redirect_uri"] = [self redirectURIForProvider:provider];
    params[@"response_type"] = @"code";
    params[@"code_challenge"] = challenge;
    params[@"code_challenge_method"] = @"S256";

    switch (provider) {
        case BackupOAuthProviderGoogleDrive:
            base = @"https://accounts.google.com/o/oauth2/v2/auth";
            params[@"client_id"] = [BackupConfig googleClientID];
            params[@"scope"] = @"https://www.googleapis.com/auth/drive.file";
            params[@"access_type"] = @"offline";
            params[@"prompt"] = @"consent";
            break;
        case BackupOAuthProviderOneDrive:
            base = @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize";
            params[@"client_id"] = [BackupConfig azureClientID];
            params[@"scope"] = @"offline_access Files.ReadWrite";
            params[@"response_mode"] = @"query";
            params[@"prompt"] = @"select_account";
            break;
        case BackupOAuthProviderDropbox:
            base = @"https://www.dropbox.com/oauth2/authorize";
            params[@"client_id"] = [BackupConfig dropboxAppKey];
            params[@"token_access_type"] = @"offline";
            break;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:base];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    for (NSString *key in params) {
        [items addObject:[NSURLQueryItem queryItemWithName:key value:params[key]]];
    }
    components.queryItems = items;
    return components.URL;
}

- (void)handleCallbackURL:(NSURL *)callbackURL {
    if (!callbackURL) {
        [self finishAuthorizationWithError:OAuthError(6, localize(@"Sign-in did not return a result.", nil))];
        return;
    }
    NSString *error = OAuthQueryValue(callbackURL, @"error");
    if (error.length > 0) {
        NSString *description = OAuthQueryValue(callbackURL, @"error_description") ?: error;
        [self finishAuthorizationWithError:OAuthError(7, description)];
        return;
    }
    NSString *state = OAuthQueryValue(callbackURL, @"state");
    if (![state isEqualToString:self.authorizationState]) {
        [self finishAuthorizationWithError:OAuthError(8, localize(@"Sign-in state did not match. Please try again.", nil))];
        return;
    }
    NSString *code = OAuthQueryValue(callbackURL, @"code");
    if (code.length == 0) {
        [self finishAuthorizationWithError:OAuthError(9, localize(@"Sign-in did not return an authorization code.", nil))];
        return;
    }

    BackupOAuthProvider provider = self.authorizationProvider;
    NSString *verifier = self.authorizationVerifier;
    [self exchangeCode:code verifier:verifier provider:provider completion:^(NSDictionary *token, NSError *error) {
        if (error) {
            [self finishAuthorizationWithError:error];
            return;
        }
        [self saveToken:token provider:provider];
        [self finishAuthorizationWithError:nil];
    }];
}

- (void)finishAuthorizationWithError:(NSError *)error {
    self.session = nil;
    self.presentingViewController = nil;
    self.authorizationVerifier = nil;
    self.authorizationState = nil;
    void (^completion)(NSError *) = self.authorizationCompletion;
    self.authorizationCompletion = nil;
    if (completion) completion(error);
}

#pragma mark - Token exchange

- (NSURL *)tokenURLForProvider:(BackupOAuthProvider)provider {
    switch (provider) {
        case BackupOAuthProviderGoogleDrive: return [NSURL URLWithString:@"https://oauth2.googleapis.com/token"];
        case BackupOAuthProviderOneDrive: return [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];
        case BackupOAuthProviderDropbox: return [NSURL URLWithString:@"https://api.dropboxapi.com/oauth2/token"];
    }
    return nil;
}

- (NSDictionary<NSString *, NSString *> *)codeExchangeParamsForProvider:(BackupOAuthProvider)provider
                                                                    code:(NSString *)code
                                                                verifier:(NSString *)verifier {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"code"] = code;
    params[@"grant_type"] = @"authorization_code";
    params[@"redirect_uri"] = [self redirectURIForProvider:provider];
    params[@"code_verifier"] = verifier;
    switch (provider) {
        case BackupOAuthProviderGoogleDrive:
            params[@"client_id"] = [BackupConfig googleClientID];
            break;
        case BackupOAuthProviderOneDrive:
            params[@"client_id"] = [BackupConfig azureClientID];
            params[@"scope"] = @"offline_access Files.ReadWrite";
            break;
        case BackupOAuthProviderDropbox:
            params[@"client_id"] = [BackupConfig dropboxAppKey];
            break;
    }
    return params;
}

- (void)exchangeCode:(NSString *)code
             verifier:(NSString *)verifier
             provider:(BackupOAuthProvider)provider
           completion:(void (^)(NSDictionary * _Nullable token, NSError * _Nullable error))completion {
    NSDictionary *params = [self codeExchangeParamsForProvider:provider code:code verifier:verifier];
    [self postTokenRequest:params provider:provider completion:completion];
}

- (void)postTokenRequest:(NSDictionary<NSString *, NSString *> *)params
                provider:(BackupOAuthProvider)provider
              completion:(void (^)(NSDictionary * _Nullable token, NSError * _Nullable error))completion {
    NSURL *url = [self tokenURLForProvider:provider];
    if (!url) {
        if (completion) completion(nil, OAuthError(10, @"Unsupported provider"));
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    request.HTTPBody = [OAuthFormBody(params) dataUsingEncoding:NSUTF8StringEncoding];
    request.timeoutInterval = 60;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (status < 200 || status >= 300 || ![json isKindOfClass:[NSDictionary class]]) {
                NSString *message = nil;
                if ([json isKindOfClass:[NSDictionary class]]) {
                    message = json[@"error_description"] ?: json[@"error"] ?: json[@"message"];
                }
                if (message.length == 0) message = [NSString stringWithFormat:@"HTTP %ld", (long)status];
                if (completion) completion(nil, OAuthError(11, message));
                return;
            }
            if (completion) completion(json, nil);
        });
    }];
    [task resume];
}

- (void)saveToken:(NSDictionary *)token provider:(BackupOAuthProvider)provider {
    NSMutableDictionary *stored = [NSMutableDictionary dictionary];
    NSString *access = token[@"access_token"];
    if ([access isKindOfClass:[NSString class]]) stored[@"access_token"] = access;
    NSString *refresh = token[@"refresh_token"];
    if ([refresh isKindOfClass:[NSString class]] && refresh.length > 0) {
        stored[@"refresh_token"] = refresh;
    } else {
        NSDictionary *old = [BackupKeychain dictionaryForKey:[self.class providerKeyForProvider:provider]];
        if ([old[@"refresh_token"] isKindOfClass:[NSString class]]) stored[@"refresh_token"] = old[@"refresh_token"];
    }
    if ([token[@"token_type"] isKindOfClass:[NSString class]]) stored[@"token_type"] = token[@"token_type"];
    if ([token[@"scope"] isKindOfClass:[NSString class]]) stored[@"scope"] = token[@"scope"];
    double expiresIn = [token[@"expires_in"] doubleValue];
    if (expiresIn <= 0) expiresIn = 3600;
    stored[@"expires_at"] = @([[NSDate date] timeIntervalSince1970] + expiresIn);
    [BackupKeychain setDictionary:stored forKey:[self.class providerKeyForProvider:provider]];
}

#pragma mark - Access / refresh

- (void)accessTokenForProvider:(BackupOAuthProvider)provider
                    completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSDictionary *token = [BackupKeychain dictionaryForKey:[self.class providerKeyForProvider:provider]];
    if (token.count == 0) {
        if (completion) completion(nil, OAuthError(20, [NSString stringWithFormat:localize(@"Connect %@ first.", nil), [self.class displayNameForProvider:provider]]));
        return;
    }
    NSString *access = token[@"access_token"];
    double expiresAt = [token[@"expires_at"] doubleValue];
    if ([access isKindOfClass:[NSString class]] && access.length > 0 && expiresAt > [[NSDate date] timeIntervalSince1970] + 30) {
        if (completion) completion(access, nil);
        return;
    }
    NSString *refresh = token[@"refresh_token"];
    if (![refresh isKindOfClass:[NSString class]] || refresh.length == 0) {
        if (completion) completion(nil, OAuthError(21, localize(@"The cloud session expired. Please reconnect the account.", nil)));
        return;
    }
    [self refreshToken:refresh provider:provider completion:completion];
}

- (void)refreshToken:(NSString *)refresh
            provider:(BackupOAuthProvider)provider
          completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"grant_type"] = @"refresh_token";
    params[@"refresh_token"] = refresh;
    switch (provider) {
        case BackupOAuthProviderGoogleDrive:
            params[@"client_id"] = [BackupConfig googleClientID];
            break;
        case BackupOAuthProviderOneDrive:
            params[@"client_id"] = [BackupConfig azureClientID];
            params[@"scope"] = @"offline_access Files.ReadWrite";
            break;
        case BackupOAuthProviderDropbox:
            params[@"client_id"] = [BackupConfig dropboxAppKey];
            break;
    }
    [self postTokenRequest:params provider:provider completion:^(NSDictionary *token, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        [self saveToken:token provider:provider];
        NSString *access = token[@"access_token"];
        if (completion) completion([access isKindOfClass:[NSString class]] ? access : nil, nil);
    }];
}

- (void)disconnectProvider:(BackupOAuthProvider)provider {
    [BackupKeychain removeKey:[self.class providerKeyForProvider:provider]];
}

#pragma mark - ASWebAuthenticationPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    UIWindow *window = self.presentingViewController.view.window ?: UIApplication.sharedApplication.windows.firstObject;
    return window ?: [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
}

@end
