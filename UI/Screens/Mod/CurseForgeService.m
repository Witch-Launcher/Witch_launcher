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
#import "WitchCrypto.h"

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
        // pref may be encrypted enc_v1:... -> decrypt
        NSString *dec = [WitchCrypto decryptPrefValue:url];
        if (dec) url = dec;
        url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (url.length > 0) {
            if ([url hasSuffix:@"/"]) url = [url substringToIndex:url.length-1];
            return url;
        }
    }
    // Build-time fallback (Zalith pattern): WITCH_DEFAULT_BASE_URL injected via Config/WitchConfig.h (may be enc_v1:...)
    NSString *bundled = WITCH_DEFAULT_BASE_URL;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        if (dec) bundled = dec;
        if ([bundled hasSuffix:@"/"]) bundled = [bundled substringToIndex:bundled.length-1];
        return bundled;
    }
    return @"";
}
static NSString* WitchProxyToken(void) {
    id v = getPrefObject(@"witch.proxy_token");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        if (dec.length > 0) return dec;
        return v;
    }
    NSString *bundled = WITCH_DEFAULT_PROXY_TOKEN;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
}
static NSString* WitchProxyHMACSecret(void) {
    id v = getPrefObject(@"witch.proxy_hmac");
    if (!v) v = getPrefObject(@"witch.proxy_hmac_secret");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        if (dec.length > 0) return dec;
        return v;
    }
    NSString *bundled = WITCH_DEFAULT_HMAC_SECRET;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
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

// Map a CurseForge classId to the launcher's project_type string.
static NSString* CFProjectTypeForClassId(NSInteger classId) {
    if (classId == 6) return @"mod";
    if (classId == 4471) return @"modpack";
    if (classId == 6552) return @"shader";
    if (classId == 12) return @"resourcepack";
    if (classId == 17) return @"world";
    return @"unknown";
}

// A game version token is a dotted number like 1.20.1 (optionally suffixed).
static BOOL CFTokenIsMCVersion(NSString *token) {
    if (![token isKindOfClass:[NSString class]] || token.length == 0) return NO;
    if ([token rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) return NO;
    NSArray *parts = [[token componentsSeparatedByString:@"-"].firstObject componentsSeparatedByString:@"."];
    if (parts.count < 2 || parts.count > 3) return NO;
    NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
    for (NSString *p in parts) {
        if (p.length == 0) return NO;
        if ([p rangeOfCharacterFromSet:[digits invertedSet]].location != NSNotFound) return NO;
    }
    return YES;
}

// Normalize a CurseForge gameVersions token to a launcher loader id, or nil.
static NSString* CFLoaderForToken(NSString *token) {
    static NSSet *known = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        known = [NSSet setWithArray:@[@"forge", @"fabric", @"quilt", @"neoforge",
                                      @"liteloader", @"rift", @"canvas", @"vanilla"]];
    });
    NSString *lower = token.lowercaseString;
    return [known containsObject:lower] ? lower : nil;
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
        NSString *transport = token;
        // Encrypt token for transport if master key is available (B: at-rest + transport)
        if ([WitchCrypto isEnabled]) {
            NSString *enc = [WitchCrypto encryptForTransport:token];
            if (enc.length > 0) {
                transport = enc;
                [req setValue:@"1" forHTTPHeaderField:@"X-Witch-Enc"];
            }
        }
        [req setValue:[NSString stringWithFormat:@"Bearer %@", transport] forHTTPHeaderField:@"Authorization"];
    } else if ([WitchCrypto isEnabled]) {
        // Even without token, indicate enc capability for prioritized anonymous handling
        [req setValue:@"1" forHTTPHeaderField:@"X-Witch-Enc"];
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
                    @"project_type": CFProjectTypeForClassId(classId),
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

#pragma mark - Unified versions (Modrinth-compatible shape)

- (NSMutableURLRequest *)filesRequestForProject:(NSString *)projectId
                                          index:(NSInteger)index
                                       pageSize:(NSInteger)pageSize {
    BOOL useProxy = WitchShouldUseProxy();
    NSString *base = useProxy
        ? [NSString stringWithFormat:@"%@/v1/curseforge/mods/%@/files", WitchProxyBaseURL(), projectId]
        : [NSString stringWithFormat:@"%@/mods/%@/files", kCurseForgeBaseURL, projectId];
    NSURLComponents *components = [NSURLComponents componentsWithString:base];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"index" value:[@(index) stringValue]],
        [NSURLQueryItem queryItemWithName:@"pageSize" value:[@(pageSize) stringValue]],
    ];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:components.URL];
    if (useProxy) {
        NSString *pq = [NSString stringWithFormat:@"/v1/curseforge/mods/%@/files?%@", projectId, components.query ?: @""];
        [self addWitchAuthHeaders:req pathWithQuery:pq body:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    } else {
        [req setValue:[self effectiveAPIKey] forHTTPHeaderField:@"x-api-key"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    }
    return req;
}

- (void)fetchFilesPageForProject:(NSString *)projectId
                           index:(NSInteger)index
                        pageSize:(NSInteger)pageSize
                     accumulated:(NSMutableArray *)acc
                      completion:(void(^)(NSArray<NSDictionary *> *files, NSError *error))completion {
    NSMutableURLRequest *req = [self filesRequestForProject:projectId index:index pageSize:pageSize];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error ?: [NSError errorWithDomain:@"CurseForge" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No data received"}]);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *page = json[@"data"];
        if (![page isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion([acc copy], nil);
            });
            return;
        }
        [acc addObjectsFromArray:page];
        // Paginate until a short page or a sane cap (protects huge file lists).
        if ((NSInteger)page.count >= pageSize && acc.count < 2000) {
            [self fetchFilesPageForProject:projectId index:index + page.count pageSize:pageSize accumulated:acc completion:completion];
        } else {
            NSArray *all = [acc copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(all, nil);
            });
        }
    }] resume];
}

- (NSDictionary *)unifiedVersionFromCFFile:(NSDictionary *)file {
    NSString *displayName = @"";
    if ([file[@"displayName"] isKindOfClass:[NSString class]] && [file[@"displayName"] length] > 0) {
        displayName = file[@"displayName"];
    } else if ([file[@"fileName"] isKindOfClass:[NSString class]]) {
        displayName = file[@"fileName"];
    }
    // Split gameVersions into MC versions + loaders.
    NSMutableOrderedSet *mcVersions = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *loaders = [NSMutableOrderedSet orderedSet];
    NSArray *gameVersions = file[@"gameVersions"];
    if ([gameVersions isKindOfClass:[NSArray class]]) {
        for (id token in gameVersions) {
            if (![token isKindOfClass:[NSString class]]) continue;
            NSString *loader = CFLoaderForToken(token);
            if (loader) { [loaders addObject:loader]; continue; }
            if (CFTokenIsMCVersion(token)) [mcVersions addObject:token];
        }
    }
    if ([file[@"gameVersion"] isKindOfClass:[NSString class]] && CFTokenIsMCVersion(file[@"gameVersion"])) {
        [mcVersions addObject:file[@"gameVersion"]];
    }
    // Map CF file dependencies (relationType 3 = required, 2 = optional).
    NSMutableArray *deps = [NSMutableArray array];
    if ([file[@"dependencies"] isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dep in file[@"dependencies"]) {
            if (![dep isKindOfClass:[NSDictionary class]]) continue;
            NSNumber *modId = dep[@"modId"];
            if (![modId isKindOfClass:[NSNumber class]]) continue;
            NSString *rel = nil;
            if ([dep[@"relationType"] isEqual:@3]) rel = @"required";
            else if ([dep[@"relationType"] isEqual:@2]) rel = @"optional";
            if (!rel) continue;
            [deps addObject:@{@"project_id": [modId stringValue],
                              @"dependency_type": rel}];
        }
    }
    id fileId = file[@"id"];
    if (![fileId isKindOfClass:[NSNumber class]]) fileId = @0;
    id size = file[@"fileLength"];
    if (![size isKindOfClass:[NSNumber class]]) size = @0;
    return @{
        @"name": displayName,
        @"version_number": displayName,
        @"game_versions": [mcVersions array],
        @"loaders": [loaders array],
        @"url": ([file[@"downloadUrl"] isKindOfClass:[NSString class]] ? file[@"downloadUrl"] : @""),
        @"filename": ([file[@"fileName"] isKindOfClass:[NSString class]] ? file[@"fileName"] : @"file.jar"),
        @"size": size,
        @"fileDate": ([file[@"fileDate"] isKindOfClass:[NSString class]] ? file[@"fileDate"] : @""),
        @"dependencies": deps,
        @"_cfFileId": fileId,
        @"_source": @"curseforge",
    };
}

- (void)loadProjectVersions:(NSString *)projectId
                 completion:(void(^)(NSArray<NSDictionary *> *versions, NSError *error))completion
{
    if (![self isConfigured]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:401 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}]);
        return;
    }
    NSMutableArray *acc = [NSMutableArray array];
    [self fetchFilesPageForProject:projectId index:0 pageSize:200 accumulated:acc completion:^(NSArray<NSDictionary *> *files, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        // Newest first.
        NSArray *sorted = [files sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSString *da = [a[@"fileDate"] isKindOfClass:[NSString class]] ? a[@"fileDate"] : @"";
            NSString *db = [b[@"fileDate"] isKindOfClass:[NSString class]] ? b[@"fileDate"] : @"";
            return [db compare:da];
        }];
        NSMutableArray *versions = [NSMutableArray arrayWithCapacity:sorted.count];
        for (NSDictionary *file in sorted) {
            if (![file isKindOfClass:[NSDictionary class]]) continue;
            [versions addObject:[self unifiedVersionFromCFFile:file]];
        }
        if (completion) completion(versions, nil);
    }];
}

- (void)loadUnifiedProjectDetails:(NSString *)projectId
                       completion:(void(^)(NSDictionary *project, NSError *error))completion
{
    [self loadProjectDetails:projectId completion:^(NSDictionary *raw, NSError *error) {
        if (error || ![raw isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"CurseForge" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Project not found"}]);
            return;
        }
        NSString *icon = @"";
        if ([raw[@"logo"] isKindOfClass:[NSDictionary class]]) {
            id thumb = raw[@"logo"][@"thumbnailUrl"] ?: raw[@"logo"][@"url"];
            if ([thumb isKindOfClass:[NSString class]]) icon = thumb;
        }
        id pid = raw[@"id"];
        NSString *pidStr = [pid isKindOfClass:[NSNumber class]] ? [pid stringValue]
            : ([projectId isKindOfClass:[NSString class]] ? projectId : @"");
        if (completion) completion(@{
            @"title": ([raw[@"name"] isKindOfClass:[NSString class]] ? raw[@"name"] : @"Unknown"),
            @"icon_url": icon,
            @"project_id": pidStr,
            @"_source": @"curseforge",
        }, nil);
    }];
}

- (void)resolveDownloadURLForProject:(NSString *)projectId
                              fileId:(NSNumber *)fileId
                          completion:(void(^)(NSString * _Nullable url, NSError * _Nullable error))completion
{
    if (![self isConfigured]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:401 userInfo:@{NSLocalizedDescriptionKey: @"API key not configured"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/mods/%@/files/%@/download-url", projectId, fileId];
    NSMutableURLRequest *req = [self requestForPath:path];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            id url = json[@"data"];
            if ([url isKindOfClass:[NSString class]] && [url length] > 0) {
                if (completion) completion(url, nil);
            } else {
                if (completion) completion(nil, [NSError errorWithDomain:@"CurseForge" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve download URL"}]);
            }
        });
    }] resume];
}

- (NSURLSessionDownloadTask *)downloadFile:(NSString *)urlString
                                      name:(NSString *)name
                             progressBlock:(void(^)(float progress))progress
                                completion:(void(^)(NSString *path, NSError *error))completion
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CurseForgeService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return nil;
    }
    NSString *destPath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:destPath] error:&moveError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(destPath, moveError);
        });
    }];
    [task resume];
    if (progress) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (task.state == NSURLSessionTaskStateRunning) {
                [NSThread sleepForTimeInterval:0.5];
                float p = task.countOfBytesExpectedToReceive > 0 ? (float)task.countOfBytesReceived / task.countOfBytesExpectedToReceive : 0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(p);
                });
            }
        });
    }
    return task;
}

@end
