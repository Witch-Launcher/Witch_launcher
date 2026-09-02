#import "CurseForgeService.h"
#import "LauncherPreferences.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#else
#define WITCH_DEFAULT_BASE_URL @""
#define WITCH_DEFAULT_HMAC_SECRET @""
#define WITCH_DEFAULT_PROXY_TOKEN @""
#define WITCH_DEFAULT_CURSEFORGE_API_KEY @""
#endif
#import "WitchAppAttest.h"

static NSString * const kCurseForgeBaseURL = @"https://api.curseforge.com/v1";
static NSInteger const kMinecraftGameId = 432;

NSString * const kCurseForgeAPIKeyPrefKey = @"curseforge.api_key";

@interface CurseForgeService ()
@property (nonatomic, copy) NSString *apiKey;
@end

// Witch server helpers
static BOOL WitchServerEnabled(void) {
    id val = getPrefObject(@"witch.server_enabled");
    if (!val) return YES; // default enabled
    return [val boolValue];
}
static NSString* WitchProxyBaseURL(void) {
    NSString *url = getPrefObject(@"witch.proxy_base_url");
    if ([url isKindOfClass:[NSString class]]) {
        url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (url.length > 0) {
            if ([url hasSuffix:@"/"]) url = [url substringToIndex:url.length-1];
            return url;
        }
    }
    // Build-time fallback (Zalith pattern): WITCH_DEFAULT_BASE_URL injected via Config/WitchConfig.h
    // For public GitHub builds it is @"" → user must enter in Settings → Network
    NSString *bundled = WITCH_DEFAULT_BASE_URL;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        if ([bundled hasSuffix:@"/"]) bundled = [bundled substringToIndex:bundled.length-1];
        return bundled;
    }
    return @"";
}
static NSString* WitchProxyToken(void) {
    id v = getPrefObject(@"witch.proxy_token");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) return v;
    NSString *bundled = WITCH_DEFAULT_PROXY_TOKEN;
    return ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) ? bundled : nil;
}
static NSString* WitchProxyHMACSecret(void) {
    id v = getPrefObject(@"witch.proxy_hmac");
    if (!v) v = getPrefObject(@"witch.proxy_hmac_secret");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) return v;
    NSString *bundled = WITCH_DEFAULT_HMAC_SECRET;
    return ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) ? bundled : nil;
}
static NSString* WitchCurseForgeSource(void) {
    NSString *v = getPrefObject(@"witch.curseforge_source");
    if ([v isKindOfClass:[NSString class]] && v.length > 0) return v;
    return @"server";
}
static BOOL WitchShouldUseProxy(void) {
    if (!WitchServerEnabled()) return NO;
    if (![WitchCurseForgeSource() isEqualToString:@"server"]) return NO;
    NSString *base = WitchProxyBaseURL();
    return base.length > 0;
}
static NSString* WitchDeviceId(void) {
    NSString *did = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.device_id"];
    if (did.length > 0) return did;
    did = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:did forKey:@"witch.device_id"];
    return did;
}
static NSString* SHA256Hex(NSString *input) {
    if (!input) input = @"";
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}
static NSString* HMACSHA256Hex(NSString *secret, NSString *message) {
    const char *cKey = [secret cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", cHMAC[i]];
    return hex;
}

@implementation CurseForgeService

+ (instancetype)shared {
    static CurseForgeService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Try loading saved API key
        NSString *savedKey = getPrefObject(kCurseForgeAPIKeyPrefKey);
        if (savedKey.length > 0) {
            _apiKey = savedKey;
        }
    }
    return self;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = [apiKey copy];
    setPrefObject(kCurseForgeAPIKeyPrefKey, apiKey);
}

- (BOOL)isConfigured {
    if (WitchShouldUseProxy()) {
        return WitchProxyBaseURL().length > 0;
    }
    // Own key mode
    NSString *ownKey = getPrefObject(@"witch.curseforge_own_key");
    if ([ownKey isKindOfClass:[NSString class]] && ownKey.length > 0) return YES;
    return _apiKey.length > 0;
}

- (BOOL)isAIEnabled {
    id v = getPrefObject(@"witch.ai_enabled");
    if (!v) return YES;
    return [v boolValue];
}

#pragma mark - Loader mapping

/// Map loader name to CurseForge modLoaderType enum
/// 1 = Forge, 4 = Fabric, 5 = Quilt, 6 = NeoForge
- (NSInteger)modLoaderTypeForName:(NSString *)name {
    if ([name.lowercaseString isEqualToString:@"forge"]) return 1;
    if ([name.lowercaseString isEqualToString:@"fabric"]) return 4;
    if ([name.lowercaseString isEqualToString:@"quilt"]) return 5;
    if ([name.lowercaseString isEqualToString:@"neoforge"]) return 6;
    return 0; // Any
}

#pragma mark - Helpers

- (NSString*)effectiveAPIKey {
    NSString *ownKey = getPrefObject(@"witch.curseforge_own_key");
    if ([ownKey isKindOfClass:[NSString class]] && ownKey.length > 0) return ownKey;
    return _apiKey;
}

- (NSURL*)baseURLForDirect {
    return [NSURL URLWithString:kCurseForgeBaseURL];
}

- (NSURL*)baseURLForProxy {
    NSString *base = WitchProxyBaseURL();
    // proxy exposes /v1/curseforge/*
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/curseforge", base]];
}

- (void)addWitchAuthHeaders:(NSMutableURLRequest*)req pathWithQuery:(NSString*)pathWithQuery body:(NSString*)bodyString {
    NSString *token = WitchProxyToken();
    if (token.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    }
    NSString *secret = WitchProxyHMACSecret();
    if (secret.length > 0) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]*1000];
        NSString *bodyHash = SHA256Hex(bodyString ?: @"");
        NSString *path = pathWithQuery ?: req.URL.path;
        if (req.URL.query.length > 0) path = [NSString stringWithFormat:@"%@?%@", req.URL.path, req.URL.query];
        // For proxy, path is /v1/curseforge/...
        NSString *message = [NSString stringWithFormat:@"%@.%@.%@.%@", timestamp, req.HTTPMethod ?: @"GET", path, bodyHash];
        NSString *sig = HMACSHA256Hex(secret, message);
        [req setValue:timestamp forHTTPHeaderField:@"X-Witch-Timestamp"];
        [req setValue:sig forHTTPHeaderField:@"X-Witch-Signature"];
        [req setValue:WitchDeviceId() forHTTPHeaderField:@"X-Witch-DeviceId"];
    } else if (token.length > 0) {
        [req setValue:WitchDeviceId() forHTTPHeaderField:@"X-Witch-DeviceId"];
    }
    // AppAttest (Zalith pattern): nếu đã attest thì gửi kèm, Worker sẽ ưu tiên rate limit
    NSString *attest = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.assertion"];
    if (attest.length > 20) {
        [req setValue:attest forHTTPHeaderField:@"X-Witch-AppAttest"];
        NSString *keyId = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.keyId"];
        if (keyId.length > 0) [req setValue:keyId forHTTPHeaderField:@"X-Witch-AppAttest-KeyId"];
    }
}

#pragma mark - API Requests

- (NSMutableURLRequest *)requestForPath:(NSString *)path {
    BOOL useProxy = WitchShouldUseProxy();
    NSURL *base = useProxy ? [self baseURLForProxy] : [self baseURLForDirect];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", base.absoluteString, path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    if (useProxy) {
        [self addWitchAuthHeaders:req pathWithQuery:path body:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    } else {
        NSString *key = [self effectiveAPIKey];
        [req setValue:key forHTTPHeaderField:@"x-api-key"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    }
    return req;
}

- (void)searchProjectsWithClassId:(NSInteger)classId
                            query:(NSString *)query
                           offset:(NSInteger)offset
                            limit:(NSInteger)limit
                     loaderFilter:(NSString *)loaderFilter
                gameVersionFilter:(NSString *)gameVersionFilter
                       completion:(void(^)(NSArray<NSDictionary *> *results, NSError *error))completion
{
    if (![self isConfigured]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:401 userInfo:@{NSLocalizedDescriptionKey: @"CurseForge API key not configured. Go to Settings to add your key."}]);
        return;
    }

    BOOL useProxy = WitchShouldUseProxy();
    NSString *searchBase = useProxy ? [NSString stringWithFormat:@"%@/v1/curseforge/mods/search", WitchProxyBaseURL()] : [NSString stringWithFormat:@"%@/mods/search", kCurseForgeBaseURL];
    NSURLComponents *components = [NSURLComponents componentsWithString:searchBase];
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray arrayWithArray:@[
        [NSURLQueryItem queryItemWithName:@"gameId" value:[@(kMinecraftGameId) stringValue]],
        [NSURLQueryItem queryItemWithName:@"classId" value:[@(classId) stringValue]],
        [NSURLQueryItem queryItemWithName:@"searchFilter" value:query ?: @""],
        [NSURLQueryItem queryItemWithName:@"index" value:[@(offset) stringValue]],
        [NSURLQueryItem queryItemWithName:@"pageSize" value:[@(limit) stringValue]],
        [NSURLQueryItem queryItemWithName:@"sortField" value:@"2"], // Popularity
        [NSURLQueryItem queryItemWithName:@"sortOrder" value:@"desc"],
    ]];

    if (loaderFilter.length > 0) {
        NSInteger loaderType = [self modLoaderTypeForName:loaderFilter];
        if (loaderType > 0) {
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"modLoaderType" value:[@(loaderType) stringValue]]];
        }
    }
    if (gameVersionFilter.length > 0) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"gameVersion" value:gameVersionFilter]];
    }

    components.queryItems = queryItems;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:components.URL];
    if (useProxy) {
        [self addWitchAuthHeaders:req pathWithQuery:[NSString stringWithFormat:@"/v1/curseforge/mods/search?%@", components.query ?: @""] body:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    } else {
        NSString *key = [self effectiveAPIKey];
        [req setValue:key forHTTPHeaderField:@"x-api-key"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    }

    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(nil, error ?: [NSError errorWithDomain:@"CurseForge" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No data received"}]);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *rawData = json[@"data"];
            if (![rawData isKindOfClass:[NSArray class]]) {
                if (completion) completion(@[], nil);
                return;
            }
            // Map CurseForge response to a format compatible with our UI
            NSMutableArray *results = [NSMutableArray array];
            for (NSDictionary *mod in rawData) {
                NSString *iconUrl = @"";
                if ([mod[@"logo"] isKindOfClass:[NSDictionary class]]) {
                    iconUrl = mod[@"logo"][@"thumbnailUrl"] ?: @"";
                }
                NSString *author = @"";
                NSArray *authors = mod[@"authors"];
                if ([authors isKindOfClass:[NSArray class]] && authors.count > 0) {
                    author = authors[0][@"name"] ?: @"";
                }
                // Map loaders
                NSMutableArray *loaders = [NSMutableArray array];
                NSArray *latestFilesIndexes = mod[@"latestFilesIndexes"];
                if ([latestFilesIndexes isKindOfClass:[NSArray class]]) {
                    NSMutableSet *loaderSet = [NSMutableSet set];
                    for (NSDictionary *fi in latestFilesIndexes) {
                        NSNumber *modLoader = fi[@"modLoader"];
                        if ([modLoader isKindOfClass:[NSNumber class]]) {
                            switch (modLoader.intValue) {
                                case 1: [loaderSet addObject:@"forge"]; break;
                                case 4: [loaderSet addObject:@"fabric"]; break;
                                case 5: [loaderSet addObject:@"quilt"]; break;
                                case 6: [loaderSet addObject:@"neoforge"]; break;
                            }
                        }
                    }
                    [loaders addObjectsFromArray:loaderSet.allObjects];
                }

                [results addObject:@{
                    @"slug": mod[@"slug"] ?: @"",
                    @"title": mod[@"name"] ?: @"Unknown",
                    @"description": mod[@"summary"] ?: @"",
                    @"project_type": classId == 6 ? @"mod" : classId == 4471 ? @"modpack" : classId == 6552 ? @"shader" : @"unknown",
                    @"icon_url": iconUrl,
                    @"downloads": mod[@"downloadCount"] ?: @0,
                    @"follows": mod[@"thumbsUpCount"] ?: @0,
                    @"author": author,
                    @"loaders": loaders,
                    @"project_id": [mod[@"id"] stringValue] ?: @"",
                    @"_source": @"curseforge",
                }];
            }
            if (completion) completion(results, nil);
        });
    }] resume];
}

- (void)loadProjectFiles:(NSString *)projectId
              completion:(void(^)(NSArray<NSDictionary *> *files, NSError *error))completion
{
    if (![self isConfigured]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:401 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/mods/%@/files", projectId];
    NSMutableURLRequest *req = [self requestForPath:path];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *files = json[@"data"];
            if (completion) completion([files isKindOfClass:[NSArray class]] ? files : @[], nil);
        });
    }] resume];
}

- (void)loadProjectDetails:(NSString *)projectId
                completion:(void(^)(NSDictionary *project, NSError *error))completion
{
    if (![self isConfigured]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:401 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/mods/%@", projectId];
    NSMutableURLRequest *req = [self requestForPath:path];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(json[@"data"], nil);
        });
    }] resume];
}

@end
