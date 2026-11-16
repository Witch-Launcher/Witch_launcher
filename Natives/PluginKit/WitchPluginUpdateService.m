#import "WitchPluginUpdateService.h"
#import "WitchPluginManager.h"
#import "WitchPluginVersion.h"
#import "LauncherPreferences.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const WPCatalogDefaultRepository = @"Witch-Launcher/Witch_plugin_catalog";
static NSString * const WPCatalogDefaultFile = @"witch-plugins.json";
static NSString * const WPCatalogUserAgent = @"WitchLauncher/1.0";
static const unsigned long long WPCatalogMaxPackageBytes = 32ULL * 1024 * 1024;
static const NSTimeInterval WPCatalogRequestTimeout = 20.0;

static NSString *WPCatalogString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSError *WPCatalogError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"WitchPluginCatalog" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Plugin catalog error"}];
}

static BOOL WPCatalogValidSHA256(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length != 64) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    return [[value lowercaseString] rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSString *WPCatalogSHA256File(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    @try {
        while (1) {
            @autoreleasepool {
                NSData *chunk = [handle readDataOfLength:1024 * 1024];
                if (chunk.length == 0) break;
                CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
            }
        }
    } @catch (NSException *exception) {
        [handle closeFile];
        return nil;
    }
    [handle closeFile];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

#pragma mark - Entry

@interface WitchPluginCatalogEntry ()
@property (nonatomic, readwrite, copy) NSString *pluginID;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite, copy) NSString *version;
@property (nonatomic, readwrite, copy) NSString *summary;
@property (nonatomic, readwrite, copy) NSString *author;
@property (nonatomic, readwrite, copy) NSString *license;
@property (nonatomic, readwrite, copy) NSString *sourceURL;
@property (nonatomic, readwrite, copy) NSString *notes;
@property (nonatomic, readwrite, copy) NSString *channel;
@property (nonatomic, readwrite, copy) NSString *sha256;
@property (nonatomic, readwrite, copy) NSString *downloadURL;
@end

@implementation WitchPluginCatalogEntry

- (instancetype)initWithDictionary:(NSDictionary *)dictionary downloadURL:(NSString *)downloadURL {
    self = [super init];
    if (self) {
        _pluginID = [WPCatalogString(dictionary[@"id"]) copy];
        _name = [WPCatalogString(dictionary[@"name"]) copy];
        _version = [WPCatalogString(dictionary[@"version"]) copy];
        _summary = [WPCatalogString(dictionary[@"description"]) copy];
        _author = [WPCatalogString(dictionary[@"author"]) copy];
        _license = [WPCatalogString(dictionary[@"license"]) copy];
        _sourceURL = [WPCatalogString(dictionary[@"source"]) copy];
        _notes = [WPCatalogString(dictionary[@"notes"]) copy];
        _channel = [WPCatalogString(dictionary[@"channel"]) copy];
        _sha256 = [[WPCatalogString(dictionary[@"sha256"]) lowercaseString] copy];
        _downloadURL = [downloadURL copy];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.pluginID ?: @"",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"description": self.summary ?: @"",
        @"author": self.author ?: @"",
        @"license": self.license ?: @"",
        @"source": self.sourceURL ?: @"",
        @"notes": self.notes ?: @"",
        @"channel": self.channel ?: @"",
        @"sha256": self.sha256 ?: @""
    };
}

@end

#pragma mark - Service

@interface WitchPluginUpdateService ()
@property (nonatomic, readwrite, copy) NSArray<WitchPluginCatalogEntry *> *entries;
@property (nonatomic, readwrite, copy) NSString *repositoryDescription;
@property (nonatomic, readwrite, copy) NSString *lastErrorMessage;
@property (nonatomic, readwrite, nullable) NSDate *lastRefreshDate;
@property (nonatomic, readwrite) BOOL loading;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation WitchPluginUpdateService

+ (WitchPluginUpdateService *)shared {
    static WitchPluginUpdateService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = @[];
        _repositoryDescription = @"";
        _lastErrorMessage = @"";
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = WPCatalogRequestTimeout;
        configuration.timeoutIntervalForResource = 600;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (NSString *)repository {
    id override = getPrefObject(@"witch.plugins.repo");
    NSString *value = WPCatalogString(override);
    if (value.length > 3 && [value containsString:@"/"] && ![value hasPrefix:@"/"] && ![value containsString:@" "]) {
        return value;
    }
    return WPCatalogDefaultRepository;
}

- (NSString *)catalogFile {
    id override = getPrefObject(@"witch.plugins.catalog_file");
    NSString *value = WPCatalogString(override);
    if (value.length > 0 && ![value hasPrefix:@"/"] && ![value containsString:@".."]) {
        return value;
    }
    return WPCatalogDefaultFile;
}

#pragma mark - Networking

- (NSMutableURLRequest *)requestForURL:(NSString *)urlString accept:(NSString *)accept {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = WPCatalogRequestTimeout;
    request.HTTPMethod = @"GET";
    [request setValue:WPCatalogUserAgent forHTTPHeaderField:@"User-Agent"];
    if (accept.length > 0) [request setValue:accept forHTTPHeaderField:@"Accept"];
    return request;
}

// A repository is only usable when GitHub confirms it exists, is public and is
// not archived. Anything else is rejected before a single byte is downloaded.
- (void)validateRepositoryWithCompletion:(void (^)(NSString * _Nullable branch, NSError * _Nullable error))completion {
    NSString *repo = self.repository;
    NSMutableURLRequest *request = [self requestForURL:[NSString stringWithFormat:@"https://api.github.com/repos/%@", repo] accept:@"application/vnd.github+json"];
    if (!request) {
        completion(nil, WPCatalogError(1, @"Invalid catalog repository"));
        return;
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, networkError); });
            return;
        }
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        if (statusCode == 404) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(2, [NSString stringWithFormat:@"Catalog repository %@ was not found", repo])); });
            return;
        }
        if (statusCode >= 400) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(3, [NSString stringWithFormat:@"Catalog repository is not reachable (HTTP %ld)", (long)statusCode])); });
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(4, @"Invalid GitHub repository response")); });
            return;
        }
        NSString *fullName = WPCatalogString(json[@"full_name"]);
        if (fullName.length == 0 || [fullName.lowercaseString isEqualToString:repo.lowercaseString] == NO) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(5, @"The repository does not match the requested catalog")); });
            return;
        }
        if ([json[@"private"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(6, @"The catalog repository must be public")); });
            return;
        }
        if ([json[@"archived"] boolValue] || [json[@"disabled"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(7, @"The catalog repository is archived or disabled")); });
            return;
        }
        NSString *branch = WPCatalogString(json[@"default_branch"]);
        if (branch.length == 0) branch = @"main";
        NSString *description = WPCatalogString(json[@"description"]);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.repositoryDescription = description.length > 0 ? description : fullName;
            completion(branch, nil);
        });
    }];
    [task resume];
}

- (void)loadCatalogFromBranch:(NSString *)branch completion:(void (^)(NSArray<WitchPluginCatalogEntry *> * _Nullable entries, NSError * _Nullable error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://raw.githubusercontent.com/%@/%@/%@", self.repository, branch, self.catalogFile];
    NSMutableURLRequest *request = [self requestForURL:urlString accept:@"application/json"];
    if (!request) {
        completion(nil, WPCatalogError(8, @"Invalid catalog URL"));
        return;
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, networkError); });
            return;
        }
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        if (statusCode >= 400) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(9, [NSString stringWithFormat:@"Cannot read the plugin catalog (HTTP %ld)", (long)statusCode])); });
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(10, @"The plugin catalog is not valid JSON")); });
            return;
        }
        NSArray *raw = [json[@"plugins"] isKindOfClass:[NSArray class]] ? json[@"plugins"] : nil;
        if (!raw) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, WPCatalogError(11, @"The plugin catalog has no plugins list")); });
            return;
        }
        NSMutableArray<WitchPluginCatalogEntry *> *entries = [NSMutableArray array];
        for (id item in raw) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *dictionary = item;
            NSString *pluginID = WPCatalogString(dictionary[@"id"]);
            NSString *version = WPCatalogString(dictionary[@"version"]);
            NSString *package = WPCatalogString(dictionary[@"package"]);
            NSString *sha256 = WPCatalogString(dictionary[@"sha256"]).lowercaseString;
            if (pluginID.length == 0 || version.length == 0 || package.length == 0) continue;
            if (!WPCatalogValidSHA256(sha256)) continue;
            NSString *downloadURL = [self downloadURLForPackage:package branch:branch];
            if (downloadURL.length == 0) continue;
            WitchPluginCatalogEntry *entry = [[WitchPluginCatalogEntry alloc] initWithDictionary:dictionary downloadURL:downloadURL];
            if (entry.name.length == 0) entry.name = pluginID;
            [entries addObject:entry];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(entries, nil); });
    }];
    [task resume];
}

- (NSString *)downloadURLForPackage:(NSString *)package branch:(NSString *)branch {
    if ([package.lowercaseString hasPrefix:@"https://"]) return package;
    if ([package.lowercaseString hasPrefix:@"http://"]) return nil;
    NSString *clean = [package hasPrefix:@"/"] ? [package substringFromIndex:1] : package;
    if ([clean containsString:@".."]) return nil;
    return [NSString stringWithFormat:@"https://raw.githubusercontent.com/%@/%@/%@", self.repository, branch, clean];
}

#pragma mark - Catalog

- (void)refreshCatalogWithCompletion:(void (^)(BOOL ok, NSError * _Nullable error))completion {
    if (self.loading) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPCatalogError(12, @"The plugin catalog is already loading")); });
        return;
    }
    self.loading = YES;
    __weak typeof(self) weakSelf = self;
    [self validateRepositoryWithCompletion:^(NSString *branch, NSError *error) {
        WitchPluginUpdateService *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || branch.length == 0) {
            strongSelf.loading = NO;
            strongSelf.lastErrorMessage = error.localizedDescription ?: @"";
            if (completion) completion(NO, error);
            return;
        }
        [strongSelf loadCatalogFromBranch:branch completion:^(NSArray<WitchPluginCatalogEntry *> *entries, NSError *catalogError) {
            WitchPluginUpdateService *inner = weakSelf;
            if (!inner) return;
            inner.loading = NO;
            if (catalogError || entries == nil) {
                inner.lastErrorMessage = catalogError.localizedDescription ?: @"";
                if (completion) completion(NO, catalogError);
                return;
            }
            inner.entries = entries;
            inner.lastErrorMessage = @"";
            inner.lastRefreshDate = [NSDate date];
            if (completion) completion(YES, nil);
        }];
    }];
}

- (nullable WitchPluginCatalogEntry *)entryForPluginID:(NSString *)pluginID {
    if (pluginID.length == 0) return nil;
    for (WitchPluginCatalogEntry *entry in self.entries) {
        if ([entry.pluginID isEqualToString:pluginID]) return entry;
    }
    return nil;
}

- (BOOL)hasUpdateForPluginID:(NSString *)pluginID version:(NSString *)version {
    WitchPluginCatalogEntry *entry = [self entryForPluginID:pluginID];
    if (!entry) return NO;
    return [WitchPluginVersion isVersion:entry.version newerThan:version];
}

#pragma mark - Package

- (void)fetchAndVerifyEntry:(WitchPluginCatalogEntry *)entry
                completion:(void (^)(NSURL * _Nullable packageURL,
                                     NSDictionary * _Nullable info,
                                     WitchPluginRiskReport * _Nullable risk,
                                     NSError * _Nullable error))completion {
    if (!entry) {
        if (completion) completion(nil, nil, nil, WPCatalogError(13, @"Unknown plugin"));
        return;
    }
    NSURL *url = [NSURL URLWithString:entry.downloadURL];
    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        if (completion) completion(nil, nil, nil, WPCatalogError(14, @"The plugin package must be served over HTTPS"));
        return;
    }
    NSMutableURLRequest *request = [self requestForURL:entry.downloadURL accept:@"application/octet-stream"];
    if (!request) {
        if (completion) completion(nil, nil, nil, WPCatalogError(15, @"Invalid plugin package URL"));
        return;
    }
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *networkError) {
        if (networkError || !location) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, networkError ?: WPCatalogError(16, @"Cannot download the plugin package")); });
            return;
        }
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 200;
        if (statusCode >= 400) {
            [[NSFileManager defaultManager] removeItemAtPath:location.path error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, WPCatalogError(17, [NSString stringWithFormat:@"The plugin package is not available (HTTP %ld)", (long)statusCode])); });
            return;
        }
        unsigned long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:nil][NSFileSize] unsignedLongLongValue];
        if (size > WPCatalogMaxPackageBytes) {
            [[NSFileManager defaultManager] removeItemAtPath:location.path error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, WPCatalogError(18, @"The plugin package is too large")); });
            return;
        }
        NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plgw", NSUUID.UUID.UUIDString]];
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:temp] error:&moveError];
        if (moveError) {
            [[NSFileManager defaultManager] removeItemAtPath:location.path error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, moveError); });
            return;
        }
        // The catalog pins the package hash, so a swapped download is rejected
        // before anything is unpacked.
        NSString *hash = WPCatalogSHA256File(temp);
        if (!hash || ![hash isEqualToString:entry.sha256.lowercaseString]) {
            [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, WPCatalogError(19, @"The downloaded package does not match the catalog hash")); });
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *inspectError = nil;
            NSDictionary *info = [WitchPluginManager.shared inspectPackageAtURL:[NSURL fileURLWithPath:temp] error:&inspectError];
            if (!info) {
                [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, inspectError ?: WPCatalogError(20, @"Invalid plugin package")); });
                return;
            }
            NSDictionary *manifest = info[@"manifest"];
            NSDictionary *state = info[@"state"];
            NSString *packageID = WPCatalogString(manifest[@"id"]);
            NSString *artifactHash = WPCatalogString(state[@"artifactSha256"]);
            if (![packageID isEqualToString:entry.pluginID]) {
                [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, WPCatalogError(21, @"The package does not contain the expected plugin")); });
                return;
            }
            if (![artifactHash isEqualToString:entry.sha256.lowercaseString]) {
                [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, nil, WPCatalogError(22, @"The package hash does not match the catalog")); });
                return;
            }
            WitchPluginRiskReport *risk = [info[@"risk"] isKindOfClass:[WitchPluginRiskReport class]] ? info[@"risk"] : nil;
            [WitchPluginManager.shared verifyPackageInfo:info completion:^(BOOL verified, NSError *verifyError) {
                if (!verified) {
                    [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
                    completion(nil, nil, nil, verifyError ?: WPCatalogError(23, @"The registry did not verify this plugin build"));
                    return;
                }
                completion([NSURL fileURLWithPath:temp], info, risk, nil);
            }];
        });
    }];
    [task resume];
}

@end
