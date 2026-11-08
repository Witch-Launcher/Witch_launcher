#import "WitchPluginManager.h"
#import "WitchPluginTheme.h"
#import "WitchCrypto.h"
#import "LauncherPreferences.h"
#import "UnzipKit.h"
#import "utils.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#endif

#ifndef WITCH_DEFAULT_BASE_URL
#define WITCH_DEFAULT_BASE_URL @""
#endif
#ifndef WITCH_PLUGIN_OFFICIAL_KEY_ID
#define WITCH_PLUGIN_OFFICIAL_KEY_ID @""
#endif
#ifndef WITCH_PLUGIN_OFFICIAL_PUBLIC_KEY
#define WITCH_PLUGIN_OFFICIAL_PUBLIC_KEY @""
#endif

NSString * const WitchPluginsDidChangeNotification = @"WitchPluginsDidChangeNotification";

static NSString * const WPErrorDomain = @"WitchPlugin";
static NSString * const WPManifestName = @"witch-plugin.json";
static NSString * const WPChecksumsName = @"checksums.json";
static NSString * const WPSignatureName = @"witch-plugin.sig";
static NSString * const WPStateName = @"state.json";
static NSString * const WPConfigurationName = @"plugins.json";
static NSString * const WPFeaturePrefix = @"feature.";
static const NSInteger WitchPluginAPIVersion = 1;
static const unsigned long long WP_MAX_PACKAGE_BYTES = 32ULL * 1024 * 1024;
static const unsigned long long WP_MAX_EXTRACTED_BYTES = 128ULL * 1024 * 1024;
static const NSUInteger WP_MAX_PACKAGE_FILES = 2048;
static const NSUInteger WP_MAX_STATE_BYTES = 1024 * 1024;
static const NSUInteger WP_MAX_CONFIGURATION_BYTES = 4 * 1024 * 1024;

static NSError *WPError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:WPErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Plugin error"}];
}

static BOOL WPFileExists(NSString *path) {
    return path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static NSString *WPString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static BOOL WPOpenSourceLicense(NSString *license) {
    static NSSet *allowed = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowed = [NSSet setWithArray:@[
            @"MIT", @"Apache-2.0", @"BSD-2-Clause", @"BSD-3-Clause", @"ISC",
            @"MPL-2.0", @"GPL-2.0-only", @"GPL-2.0-or-later", @"GPL-3.0-only",
            @"GPL-3.0-or-later", @"LGPL-2.1-only", @"LGPL-2.1-or-later",
            @"LGPL-3.0-only", @"LGPL-3.0-or-later", @"AGPL-3.0-only",
            @"AGPL-3.0-or-later", @"EPL-2.0", @"CC0-1.0", @"Unlicense", @"Zlib"
        ]];
    });
    return [allowed containsObject:license];
}

static NSString *WPSHA256Data(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static NSString *WPSHA256File(NSString *path, NSError **error) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) {
        if (error) *error = WPError(20, [NSString stringWithFormat:@"Cannot read %@", path.lastPathComponent]);
        return nil;
    }
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
        if (error) *error = WPError(20, [NSString stringWithFormat:@"Cannot read %@", path.lastPathComponent]);
        return nil;
    }
    [handle closeFile];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static BOOL WPValidRelativePath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
    while ([path hasSuffix:@"/"]) path = [path substringToIndex:path.length - 1];
    if (path.length == 0 || [path hasPrefix:@"/"] || [path containsString:@"\\"]) return NO;
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if (part.length == 0 || [part isEqualToString:@"."] || [part isEqualToString:@".."]) return NO;
    }
    return YES;
}

static BOOL WPValidSHA256(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length != 64) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    return [[value lowercaseString] rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSString *WPConfigurationPath(void) {
    const char *home = getenv("POJAV_HOME");
    if (!home) return nil;
    return [@(home) stringByAppendingPathComponent:WPConfigurationName];
}

static BOOL WPJSONSerializable(NSString *key, id value) {
    return key.length > 0 && value && [NSJSONSerialization isValidJSONObject:@{key: value}];
}

static NSString *WPDefaultState(void) {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    return [formatter stringFromDate:[NSDate date]];
}

static NSString *WPSafeModePath(void) {
    return amethyst_hidden_path(@"SAFE_MODE");
}

static NSString *WPLegacySafeModePath(void) {
    const char *home = getenv("POJAV_HOME");
    if (!home) return nil;
    return [@(home) stringByAppendingPathComponent:@"SAFE_MODE"];
}

static NSString *WPBaseURL(void) {
    id stored = getPrefObject(@"witch.proxy_base_url");
    if ([stored isKindOfClass:[NSString class]] && [stored length] > 0) {
        NSString *plain = [WitchCrypto decryptIfNeeded:stored] ?: stored;
        plain = [plain stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (plain.length > 0) {
            while ([plain hasSuffix:@"/"]) plain = [plain substringToIndex:plain.length - 1];
            return plain;
        }
    }
    NSString *bundled = WITCH_DEFAULT_BASE_URL;
    if (bundled.length > 0) {
        bundled = [WitchCrypto decryptIfNeeded:bundled] ?: bundled;
        while ([bundled hasSuffix:@"/"]) bundled = [bundled substringToIndex:bundled.length - 1];
        return bundled;
    }
    return @"";
}

static NSString *WPOfficialKeyID(void) {
    return WITCH_PLUGIN_OFFICIAL_KEY_ID;
}

static NSString *WPOfficialPublicKey(void) {
    return WITCH_PLUGIN_OFFICIAL_PUBLIC_KEY;
}

static NSDictionary *WPTrustedKeys(void) {
    id value = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"witch.plugins.trusted_keys"];
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static BOOL WPTrustedKey(NSString *keyID, NSString *publicKey) {
    if (keyID.length == 0 || publicKey.length == 0) return NO;
    if (WPOfficialKeyID().length > 0 && [keyID isEqualToString:WPOfficialKeyID()] && [publicKey isEqualToString:WPOfficialPublicKey()]) return YES;
    NSString *pinned = WPTrustedKeys()[keyID];
    return [pinned isKindOfClass:[NSString class]] && [pinned isEqualToString:publicKey];
}

static void WPPinKey(NSString *keyID, NSString *publicKey) {
    if (keyID.length == 0 || publicKey.length == 0) return;
    NSMutableDictionary *trusted = [WPTrustedKeys() mutableCopy];
    trusted[keyID] = publicKey;
    [[NSUserDefaults standardUserDefaults] setObject:trusted forKey:@"witch.plugins.trusted_keys"];
}

static NSData *WPBase64Data(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    return [[NSData alloc] initWithBase64EncodedString:value options:0];
}

static SecKeyRef WPCreatePublicKey(NSData *raw, NSError **error) {
    if (raw.length != 65 || ((const uint8_t *)raw.bytes)[0] != 0x04) {
        if (error) *error = WPError(21, @"Plugin public key must be a 65-byte P-256 point");
        return NULL;
    }
    NSDictionary *attrs = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
        (__bridge id)kSecAttrKeySizeInBits: @256
    };
    CFErrorRef cfError = NULL;
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)raw, (__bridge CFDictionaryRef)attrs, &cfError);
    if (!key && error) {
        *error = cfError ? CFBridgingRelease(cfError) : WPError(22, @"Cannot create plugin public key");
    } else if (cfError) {
        CFRelease(cfError);
    }
    return key;
}

static BOOL WPVerifySignature(NSData *message, NSData *signature, NSData *publicKey, NSError **error) {
    SecKeyRef key = WPCreatePublicKey(publicKey, error);
    if (!key) return NO;
    CFErrorRef cfError = NULL;
    BOOL ok = SecKeyVerifySignature(key, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)message, (__bridge CFDataRef)signature, &cfError);
    CFRelease(key);
    if (!ok && error) {
        *error = cfError ? CFBridgingRelease(cfError) : WPError(23, @"Plugin signature does not match checksums.json");
    } else if (cfError) {
        CFRelease(cfError);
    }
    return ok;
}

@interface WitchPluginManager ()
@property (nonatomic, readwrite) BOOL safeMode;
@property (nonatomic, readwrite) NSArray<WitchPlugin *> *plugins;
@property (nonatomic, readwrite) NSString *pluginsDirectory;
@property (nonatomic, readwrite) NSString *configurationPath;
@property (nonatomic) NSMutableDictionary *configuration;
@property (nonatomic) BOOL configurationInvalid;
@end

@implementation WitchPluginManager

+ (WitchPluginManager *)shared {
    static WitchPluginManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance reload];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _plugins = @[];
        _pluginsDirectory = amethyst_hidden_dir(@"plugins");
        _configurationPath = WPConfigurationPath();
        _configuration = [NSMutableDictionary dictionary];
        _safeMode = WPFileExists(WPSafeModePath()) || WPFileExists(WPLegacySafeModePath());
    }
    return self;
}

- (void)reloadConfiguration {
    self.configurationPath = WPConfigurationPath();
    self.configuration = [NSMutableDictionary dictionary];
    self.configurationInvalid = NO;
    if (self.configurationPath.length == 0) return;
    NSData *data = [NSData dataWithContentsOfFile:self.configurationPath];
    if (!data) return;
    if (data.length > WP_MAX_CONFIGURATION_BYTES) {
        self.configurationInvalid = YES;
        NSLog(@"[Plugins] Configuration is too large: %@", self.configurationPath);
        return;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
        self.configurationInvalid = YES;
        NSLog(@"[Plugins] Cannot parse configuration: %@", self.configurationPath);
        return;
    }
    NSMutableDictionary *root = [json mutableCopy];
    id plugins = root[@"plugins"];
    if (plugins != nil && ![plugins isKindOfClass:[NSDictionary class]]) {
        self.configurationInvalid = YES;
        NSLog(@"[Plugins] Configuration plugins must be an object: %@", self.configurationPath);
        return;
    }
    self.configuration = root;
}

- (nullable NSDictionary *)configurationEntryForPluginID:(NSString *)pluginID {
    if (self.configurationInvalid || pluginID.length == 0) return nil;
    NSDictionary *plugins = self.configuration[@"plugins"];
    if (![plugins isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *entry = plugins[pluginID];
    return [entry isKindOfClass:[NSDictionary class]] ? entry : nil;
}

- (NSMutableDictionary *)mutablePluginsForConfiguration {
    NSMutableDictionary *root = self.configuration ? [self.configuration mutableCopy] : [NSMutableDictionary dictionary];
    id plugins = root[@"plugins"];
    NSMutableDictionary *entries = [plugins isKindOfClass:[NSDictionary class]] ? [plugins mutableCopy] : [NSMutableDictionary dictionary];
    root[@"version"] = @1;
    root[@"plugins"] = entries;
    self.configuration = root;
    return entries;
}

- (BOOL)writeConfiguration:(NSError **)error {
    if (self.configurationPath.length == 0) {
        if (error) *error = WPError(90, @"Plugin configuration path is unavailable");
        return NO;
    }
    if (self.configurationInvalid) {
        if (error) *error = WPError(91, @"Plugin configuration contains invalid JSON");
        return NO;
    }
    NSMutableDictionary *root = self.configuration ? [self.configuration mutableCopy] : [NSMutableDictionary dictionary];
    root[@"version"] = @1;
    if (![root[@"plugins"] isKindOfClass:[NSDictionary class]]) root[@"plugins"] = @{};
    self.configuration = root;
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    if (data.length > WP_MAX_CONFIGURATION_BYTES) {
        if (error) *error = WPError(90, @"Plugin configuration is too large");
        return NO;
    }
    return [data writeToFile:self.configurationPath options:NSDataWritingAtomic error:error];
}

- (NSDictionary *)settingsWithoutFeatureKeys:(NSDictionary *)settings {
    NSMutableDictionary *regular = [NSMutableDictionary dictionary];
    for (NSString *key in settings) {
        if (![key isKindOfClass:[NSString class]] || [key hasPrefix:WPFeaturePrefix]) continue;
        regular[key] = settings[key];
    }
    return regular;
}

- (void)writeInitialConfigurationIfNeeded {
    if (self.configurationPath.length == 0 || self.configurationInvalid) return;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.configurationPath]) return;
    NSMutableDictionary *entries = [self mutablePluginsForConfiguration];
    for (WitchPlugin *plugin in self.plugins) {
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        entry[@"enabled"] = @(plugin.enabled);
        entry[@"version"] = plugin.version ?: @"";
        entry[@"settings"] = [self settingsWithoutFeatureKeys:plugin.settings];
        entry[@"features"] = @{};
        entries[plugin.pluginID] = entry;
    }
    if ([self writeConfiguration:nil]) {
        NSLog(@"[Plugins] Created configuration: %@", self.configurationPath);
    }
}

- (void)addConfigurationForPluginID:(NSString *)pluginID version:(NSString *)version {
    if (self.configurationPath.length == 0 || self.configurationInvalid || pluginID.length == 0) return;
    NSMutableDictionary *entries = [self mutablePluginsForConfiguration];
    NSMutableDictionary *entry = [entries[pluginID] isKindOfClass:[NSDictionary class]] ? [entries[pluginID] mutableCopy] : [NSMutableDictionary dictionary];
    entry[@"enabled"] = @YES;
    entry[@"version"] = version ?: @"";
    if (![entry[@"settings"] isKindOfClass:[NSDictionary class]]) entry[@"settings"] = @{};
    if (![entry[@"features"] isKindOfClass:[NSDictionary class]]) entry[@"features"] = @{};
    entries[pluginID] = entry;
    [self writeConfiguration:nil];
}

- (void)updateConfigurationForPluginID:(NSString *)pluginID enabled:(BOOL)enabled {
    if (self.configurationPath.length == 0 || self.configurationInvalid || pluginID.length == 0) return;
    NSMutableDictionary *entries = [self mutablePluginsForConfiguration];
    NSMutableDictionary *entry = [entries[pluginID] isKindOfClass:[NSDictionary class]] ? [entries[pluginID] mutableCopy] : [NSMutableDictionary dictionary];
    entry[@"enabled"] = @(enabled);
    entries[pluginID] = entry;
    [self writeConfiguration:nil];
}

- (void)updateConfigurationForPluginID:(NSString *)pluginID settingKey:(NSString *)key value:(id)value {
    if (self.configurationPath.length == 0 || self.configurationInvalid || pluginID.length == 0 || key.length == 0 || !value) return;
    NSMutableDictionary *entries = [self mutablePluginsForConfiguration];
    NSMutableDictionary *entry = [entries[pluginID] isKindOfClass:[NSDictionary class]] ? [entries[pluginID] mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary *settings = [entry[@"settings"] isKindOfClass:[NSDictionary class]] ? [entry[@"settings"] mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary *features = [entry[@"features"] isKindOfClass:[NSDictionary class]] ? [entry[@"features"] mutableCopy] : [NSMutableDictionary dictionary];
    if ([key hasPrefix:WPFeaturePrefix]) {
        NSString *feature = [key substringFromIndex:WPFeaturePrefix.length];
        if (feature.length > 0) features[feature] = value;
    } else {
        settings[key] = value;
    }
    entry[@"settings"] = settings;
    entry[@"features"] = features;
    entries[pluginID] = entry;
    [self writeConfiguration:nil];
}

- (void)removeConfigurationForPluginID:(NSString *)pluginID {
    if (self.configurationPath.length == 0 || self.configurationInvalid || pluginID.length == 0) return;
    NSMutableDictionary *entries = [self mutablePluginsForConfiguration];
    [entries removeObjectForKey:pluginID];
    [self writeConfiguration:nil];
}

- (void)reload {
    [self reloadConfiguration];
    NSString *root = amethyst_hidden_dir(@"plugins");
    self.pluginsDirectory = root;
    self.safeMode = WPFileExists(WPSafeModePath()) || WPFileExists(WPLegacySafeModePath());
    NSMutableArray *found = [NSMutableArray array];
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:nil];
    for (NSString *entry in entries) {
        if ([entry hasPrefix:@"."]) continue;
        NSString *directory = [root stringByAppendingPathComponent:entry];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) continue;
        NSString *manifestPath = [directory stringByAppendingPathComponent:WPManifestName];
        NSData *data = [NSData dataWithContentsOfFile:manifestPath];
        if (!data) continue;
        NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![manifest isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *state = [self stateForPluginID:WPString(manifest[@"id"]) directory:directory];
        WitchPlugin *plugin = [[WitchPlugin alloc] initWithInstallPath:directory manifest:manifest state:state];
        if (plugin.pluginID.length > 0) [found addObject:plugin];
    }
    [found sortUsingComparator:^NSComparisonResult(WitchPlugin *a, WitchPlugin *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    self.plugins = found;
    [self writeInitialConfigurationIfNeeded];
}

- (nullable WitchPlugin *)pluginWithID:(NSString *)pluginID {
    for (WitchPlugin *plugin in self.plugins) {
        if ([plugin.pluginID isEqualToString:pluginID]) return plugin;
    }
    return nil;
}

- (NSString *)statePathForPluginID:(NSString *)pluginID directory:(NSString *)directory {
    return [directory stringByAppendingPathComponent:WPStateName];
}

- (NSDictionary *)defaultStateForPlugin:(NSString *)pluginID {
    return @{
        @"enabled": @YES,
        @"trusted": @NO,
        @"developerSigned": @YES,
        @"verificationState": @(WitchPluginVerificationStateUnverified),
        @"verificationMessage": @"Signature is valid but this build is not verified by the registry",
        @"installedAt": WPDefaultState(),
        @"crashCount": @0,
        @"settings": @{}
    };
}

- (NSDictionary *)stateForPluginID:(NSString *)pluginID directory:(NSString *)directory {
    NSString *path = [self statePathForPluginID:pluginID directory:directory];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *state = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSMutableDictionary *merged = [[self defaultStateForPlugin:pluginID] mutableCopy];
    if ([state isKindOfClass:[NSDictionary class]]) [merged addEntriesFromDictionary:state];
    NSDictionary *configuration = [self configurationEntryForPluginID:pluginID];
    if (configuration) {
        if ([configuration[@"enabled"] isKindOfClass:[NSNumber class]]) {
            merged[@"enabled"] = @([configuration[@"enabled"] boolValue]);
        }
        NSMutableDictionary *settings = [merged[@"settings"] isKindOfClass:[NSDictionary class]] ? [merged[@"settings"] mutableCopy] : [NSMutableDictionary dictionary];
        NSDictionary *configuredSettings = configuration[@"settings"];
        if ([configuredSettings isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in configuredSettings) {
                id value = configuredSettings[key];
                if (WPJSONSerializable(key, value)) settings[key] = value;
            }
        }
        NSDictionary *features = configuration[@"features"];
        if ([features isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in features) {
                id value = features[key];
                if (![key isKindOfClass:[NSString class]] || key.length == 0) continue;
                NSString *settingKey = [WPFeaturePrefix stringByAppendingString:key];
                if (WPJSONSerializable(settingKey, value)) settings[settingKey] = value;
            }
        }
        merged[@"settings"] = settings;
    }
    return merged;
}

- (BOOL)writeState:(NSDictionary *)state pluginID:(NSString *)pluginID directory:(NSString *)directory error:(NSError **)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    if (data.length > WP_MAX_STATE_BYTES) {
        if (error) *error = WPError(87, @"Plugin state is too large");
        return NO;
    }
    NSString *path = [self statePathForPluginID:pluginID directory:directory];
    if (![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    return YES;
}

- (BOOL)validateManifest:(NSDictionary *)manifest error:(NSError **)error {
    NSString *pluginID = WPString(manifest[@"id"]);
    NSString *name = WPString(manifest[@"name"]);
    NSString *version = WPString(manifest[@"version"]);
    NSString *license = WPString(manifest[@"license"]);
    NSString *source = WPString(manifest[@"source"]);
    NSNumber *api = [manifest[@"api"] isKindOfClass:[NSNumber class]] ? manifest[@"api"] : nil;
    if (![[NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[a-z0-9][a-z0-9._-]{1,63}$"] evaluateWithObject:(pluginID ?: @"")]) {
        if (error) *error = WPError(30, @"Manifest id must be lowercase letters, numbers, dot, underscore or dash");
        return NO;
    }
    if (name.length == 0) {
        if (error) *error = WPError(31, @"Manifest name is required");
        return NO;
    }
    if (![[NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[0-9]+(\\.[0-9]+){0,3}([-+][0-9A-Za-z.-]+)?$"] evaluateWithObject:(version ?: @"")]) {
        if (error) *error = WPError(32, @"Manifest version must look like 1.0.0");
        return NO;
    }
    if (!WPOpenSourceLicense(license)) {
        if (error) *error = WPError(33, @"Manifest license must be an OSI/SPDX open-source license");
        return NO;
    }
    NSURL *sourceURL = [NSURL URLWithString:source];
    if (!sourceURL || !([sourceURL.scheme.lowercaseString isEqualToString:@"https"] || [sourceURL.scheme.lowercaseString isEqualToString:@"http"])) {
        if (error) *error = WPError(34, @"Manifest source must be an http(s) source-code URL");
        return NO;
    }
    NSInteger apiVersion = api.integerValue;
    if (apiVersion < 1 || apiVersion > WitchPluginAPIVersion) {
        if (error) *error = WPError(35, [NSString stringWithFormat:@"Plugin API %ld is not supported (max %ld)", (long)apiVersion, (long)WitchPluginAPIVersion]);
        return NO;
    }
    NSDictionary *entrypoints = manifest[@"entrypoints"];
    if (entrypoints && ![entrypoints isKindOfClass:[NSDictionary class]]) {
        if (error) *error = WPError(36, @"Manifest entrypoints must be an object");
        return NO;
    }
    for (NSString *key in entrypoints) {
        NSString *value = entrypoints[key];
        if (![value isKindOfClass:[NSString class]] || !WPValidRelativePath(value)) {
            if (error) *error = WPError(37, [NSString stringWithFormat:@"Invalid entrypoint: %@", key]);
            return NO;
        }
    }
    for (NSString *key in @[@"icon", @"banner"]) {
        id value = manifest[key];
        if (value != nil && (![value isKindOfClass:[NSString class]] || !WPValidRelativePath(value))) {
            if (error) *error = WPError(38, [NSString stringWithFormat:@"Invalid %@ path", key]);
            return NO;
        }
    }
    id ui = manifest[@"ui"];
    NSString *themePath = [ui isKindOfClass:[NSString class]] ? ui : ([ui isKindOfClass:[NSDictionary class]] ? ui[@"theme"] : nil);
    if (ui != nil && !([ui isKindOfClass:[NSString class]] || [ui isKindOfClass:[NSDictionary class]])) {
        if (error) *error = WPError(38, @"Manifest ui must be a path or an object");
        return NO;
    }
    if (themePath != nil && (![themePath isKindOfClass:[NSString class]] || !WPValidRelativePath(themePath))) {
        if (error) *error = WPError(38, @"Invalid theme path");
        return NO;
    }
    id settings = manifest[@"settings"];
    if (settings != nil && ![settings isKindOfClass:[NSArray class]]) {
        if (error) *error = WPError(39, @"Manifest settings must be an array");
        return NO;
    }
    NSMutableSet *settingKeys = [NSMutableSet set];
    for (id item in settings) {
        if (![item isKindOfClass:[NSDictionary class]] || WPString(item[@"key"]).length == 0 || WPString(item[@"type"]).length == 0) {
            if (error) *error = WPError(39, @"Manifest settings entries need key and type");
            return NO;
        }
        NSString *key = WPString(item[@"key"]);
        if ([settingKeys containsObject:key]) {
            if (error) *error = WPError(39, [NSString stringWithFormat:@"Duplicate setting key: %@", key]);
            return NO;
        }
        [settingKeys addObject:key];
    }
    return YES;
}

- (nullable NSDictionary *)inspectPackageAtURL:(NSURL *)url error:(NSError **)error {
    NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"witch-plugin-inspect-%@", NSUUID.UUID.UUIDString]];
    NSDictionary *result = [self inspectPackageAtURL:url extractTo:temp error:error];
    [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
    return result;
}

- (nullable NSDictionary *)inspectPackageAtURL:(NSURL *)url extractTo:(NSString *)destination error:(NSError **)error {
    if (!url.isFileURL) {
        if (error) *error = WPError(40, @"Plugin package must be a local .plgw file");
        return nil;
    }
    NSString *path = url.path;
    if (![path.pathExtension.lowercaseString isEqualToString:@"plgw"]) {
        if (error) *error = WPError(41, @"Plugin package extension must be .plgw");
        return nil;
    }
    if (!WPFileExists(path)) {
        if (error) *error = WPError(42, @"Plugin package not found");
        return nil;
    }
    NSDictionary *packageAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if ([packageAttributes[NSFileSize] unsignedLongLongValue] > WP_MAX_PACKAGE_BYTES) {
        if (error) *error = WPError(42, @"Plugin package is too large");
        return nil;
    }
    NSError *archiveError = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithURL:url error:&archiveError];
    if (!archive) {
        if (error) *error = archiveError ?: WPError(43, @"Cannot open plugin package");
        return nil;
    }
    NSArray<NSString *> *names = [archive listFilenames:&archiveError];
    if (names.count == 0) {
        if (error) *error = archiveError ?: WPError(44, @"Plugin package is empty");
        return nil;
    }
    if (names.count > WP_MAX_PACKAGE_FILES) {
        if (error) *error = WPError(44, @"Plugin package contains too many files");
        return nil;
    }
    unsigned long long extractedBytes = 0;
    NSArray<UZKFileInfo *> *fileInfo = [archive listFileInfo:&archiveError];
    if (fileInfo.count != names.count) {
        if (error) *error = archiveError ?: WPError(44, @"Cannot read plugin package metadata");
        return nil;
    }
    for (UZKFileInfo *info in fileInfo) {
        if (info.uncompressedSize > WP_MAX_EXTRACTED_BYTES - extractedBytes) {
            if (error) *error = WPError(44, @"Plugin package expands to too much data");
            return nil;
        }
        extractedBytes += info.uncompressedSize;
    }
    for (NSString *name in names) {
        if (!WPValidRelativePath(name)) {
            if (error) *error = WPError(45, [NSString stringWithFormat:@"Unsafe path in package: %@", name]);
            return nil;
        }
    }
    [[NSFileManager defaultManager] removeItemAtPath:destination error:nil];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    if (![archive extractFilesTo:destination overwrite:YES error:&archiveError]) {
        if (error) *error = archiveError ?: WPError(46, @"Cannot extract plugin package");
        return nil;
    }
    NSData *manifestData = [NSData dataWithContentsOfFile:[destination stringByAppendingPathComponent:WPManifestName]];
    NSDictionary *manifest = manifestData ? [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil] : nil;
    if (![manifest isKindOfClass:[NSDictionary class]]) {
        if (error) *error = WPError(47, @"witch-plugin.json is missing or invalid");
        return nil;
    }
    if (![self validateManifest:manifest error:error]) return nil;
    NSMutableArray *referenced = [NSMutableArray array];
    for (NSString *value in [manifest[@"entrypoints"] allValues]) [referenced addObject:value];
    for (NSString *key in @[@"icon", @"banner"]) if (manifest[key]) [referenced addObject:manifest[key]];
    id ui = manifest[@"ui"];
    if ([ui isKindOfClass:[NSString class]]) [referenced addObject:ui];
    if ([ui isKindOfClass:[NSDictionary class]] && ui[@"theme"]) [referenced addObject:ui[@"theme"]];
    for (NSString *relative in referenced) {
        NSString *full = [destination stringByAppendingPathComponent:relative];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDirectory] || isDirectory) {
            if (error) *error = WPError(59, [NSString stringWithFormat:@"Manifest file is missing: %@", relative]);
            return nil;
        }
    }

    NSData *checksumsData = [NSData dataWithContentsOfFile:[destination stringByAppendingPathComponent:WPChecksumsName]];
    NSDictionary *checksums = checksumsData ? [NSJSONSerialization JSONObjectWithData:checksumsData options:0 error:nil] : nil;
    if (![checksums isKindOfClass:[NSDictionary class]] || checksums.count == 0) {
        if (error) *error = WPError(48, @"checksums.json is missing or invalid");
        return nil;
    }
    if (![checksums[WPManifestName] isKindOfClass:[NSString class]]) {
        if (error) *error = WPError(49, @"checksums.json must cover witch-plugin.json");
        return nil;
    }
    for (NSString *key in checksums) {
        if (!WPValidRelativePath(key) || !WPValidSHA256(checksums[key])) {
            if (error) *error = WPError(50, [NSString stringWithFormat:@"Invalid checksum entry: %@", key]);
            return nil;
        }
    }

    NSData *signatureData = [NSData dataWithContentsOfFile:[destination stringByAppendingPathComponent:WPSignatureName]];
    NSDictionary *signature = signatureData ? [NSJSONSerialization JSONObjectWithData:signatureData options:0 error:nil] : nil;
    if (![signature isKindOfClass:[NSDictionary class]]) {
        if (error) *error = WPError(51, @"witch-plugin.sig is missing or invalid");
        return nil;
    }
    if (![WPString(signature[@"algorithm"]).uppercaseString isEqualToString:@"ES256"]) {
        if (error) *error = WPError(52, @"Plugin signature algorithm must be ES256");
        return nil;
    }
    NSString *keyID = WPString(signature[@"keyId"]);
    NSData *publicKey = WPBase64Data(signature[@"publicKey"]);
    NSData *signatureBytes = WPBase64Data(signature[@"signature"]);
    if (keyID.length == 0 || !publicKey || !signatureBytes) {
        if (error) *error = WPError(53, @"Plugin signature metadata is incomplete");
        return nil;
    }
    NSError *signatureError = nil;
    if (!WPVerifySignature(checksumsData, signatureBytes, publicKey, &signatureError)) {
        if (error) *error = signatureError ?: WPError(54, @"Plugin signature verification failed");
        return nil;
    }

    NSMutableSet *allowed = [NSMutableSet setWithArray:checksums.allKeys];
    [allowed addObject:WPChecksumsName];
    [allowed addObject:WPSignatureName];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:destination];
    unsigned long long actualBytes = 0;
    for (NSString *relative in enumerator) {
        NSString *full = [destination stringByAppendingPathComponent:relative];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
        NSString *type = attributes[NSFileType];
        if ([type isEqualToString:NSFileTypeSymbolicLink]) {
            if (error) *error = WPError(58, [NSString stringWithFormat:@"Symbolic links are not allowed: %@", relative]);
            return nil;
        }
        BOOL isDirectory = [type isEqualToString:NSFileTypeDirectory];
        if (!isDirectory && ![type isEqualToString:NSFileTypeRegular]) {
            if (error) *error = WPError(58, [NSString stringWithFormat:@"Unsupported file type: %@", relative]);
            return nil;
        }
        if (isDirectory) continue;
        actualBytes += [attributes[NSFileSize] unsignedLongLongValue];
        if (actualBytes > WP_MAX_EXTRACTED_BYTES) {
            if (error) *error = WPError(58, @"Plugin package expands to too much data");
            return nil;
        }
        if (![allowed containsObject:relative]) {
            if (error) *error = WPError(55, [NSString stringWithFormat:@"File is not covered by checksums.json: %@", relative]);
            return nil;
        }
    }
    for (NSString *relative in checksums) {
        NSString *full = [destination stringByAppendingPathComponent:relative];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDirectory] || isDirectory) {
            if (error) *error = WPError(56, [NSString stringWithFormat:@"Missing file: %@", relative]);
            return nil;
        }
        NSError *hashError = nil;
        NSString *hash = WPSHA256File(full, &hashError);
        if (!hash || ![hash isEqualToString:[checksums[relative] lowercaseString]]) {
            if (error) *error = hashError ?: WPError(57, [NSString stringWithFormat:@"Checksum mismatch: %@", relative]);
            return nil;
        }
    }

    NSString *artifactHash = WPSHA256File(path, error);
    if (!artifactHash) return nil;
    BOOL trusted = WPTrustedKey(keyID, WPString(signature[@"publicKey"]));
    NSDictionary *state = @{
        @"trusted": @(trusted),
        @"developerSigned": @(!trusted),
        @"keyId": keyID,
        @"publicKey": WPString(signature[@"publicKey"]),
        @"checksumsSha256": WPSHA256Data(checksumsData),
        @"artifactSha256": artifactHash
    };
    return @{@"manifest": manifest, @"signature": signature, @"state": state};
}

- (BOOL)verifyIntegrityForPlugin:(WitchPlugin *)plugin error:(NSError **)error {
    if (!plugin || plugin.installPath.length == 0) {
        if (error) *error = WPError(80, @"Plugin is not installed");
        return NO;
    }
    NSString *root = plugin.installPath;
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:root isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = WPError(80, @"Plugin files are missing");
        return NO;
    }
    NSData *checksumsData = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:WPChecksumsName]];
    NSDictionary *checksums = checksumsData ? [NSJSONSerialization JSONObjectWithData:checksumsData options:0 error:nil] : nil;
    if (![checksums isKindOfClass:[NSDictionary class]] || checksums.count == 0) {
        if (error) *error = WPError(81, @"Plugin checksums are missing or invalid");
        return NO;
    }
    if (![checksums[WPManifestName] isKindOfClass:[NSString class]]) {
        if (error) *error = WPError(81, @"Plugin checksums do not cover the manifest");
        return NO;
    }
    for (NSString *key in checksums) {
        if (!WPValidRelativePath(key) || !WPValidSHA256(checksums[key])) {
            if (error) *error = WPError(81, @"Plugin checksums are invalid");
            return NO;
        }
    }
    NSData *signatureData = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:WPSignatureName]];
    NSDictionary *signature = signatureData ? [NSJSONSerialization JSONObjectWithData:signatureData options:0 error:nil] : nil;
    if (![signature isKindOfClass:[NSDictionary class]]) {
        if (error) *error = WPError(82, @"Plugin signature is missing or invalid");
        return NO;
    }
    NSString *keyID = WPString(signature[@"keyId"]);
    NSString *publicKeyString = WPString(signature[@"publicKey"]);
    NSData *publicKey = WPBase64Data(signature[@"publicKey"]);
    NSData *signatureBytes = WPBase64Data(signature[@"signature"]);
    if (![WPString(signature[@"algorithm"]).uppercaseString isEqualToString:@"ES256"] || keyID.length == 0 || !publicKey || !signatureBytes) {
        if (error) *error = WPError(82, @"Plugin signature metadata is incomplete");
        return NO;
    }
    if (plugin.publicKeyBase64.length == 0 || ![publicKeyString isEqualToString:plugin.publicKeyBase64]) {
        if (error) *error = WPError(83, @"Plugin signing key changed after installation");
        return NO;
    }
    if (plugin.signatureKeyID.length > 0 && ![keyID isEqualToString:plugin.signatureKeyID]) {
        if (error) *error = WPError(83, @"Plugin signing key changed after installation");
        return NO;
    }
    NSError *signatureError = nil;
    if (!WPVerifySignature(checksumsData, signatureBytes, publicKey, &signatureError)) {
        if (error) *error = signatureError ?: WPError(84, @"Plugin signature verification failed");
        return NO;
    }
    if (plugin.checksumsSha256.length > 0 && ![WPSHA256Data(checksumsData) isEqualToString:plugin.checksumsSha256]) {
        if (error) *error = WPError(84, @"Plugin checksums changed after installation");
        return NO;
    }
    NSMutableSet *allowed = [NSMutableSet setWithArray:checksums.allKeys];
    [allowed addObject:WPChecksumsName];
    [allowed addObject:WPSignatureName];
    [allowed addObject:WPStateName];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:root];
    unsigned long long actualBytes = 0;
    for (NSString *relative in enumerator) {
        NSString *full = [root stringByAppendingPathComponent:relative];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
        NSString *type = attributes[NSFileType];
        if ([type isEqualToString:NSFileTypeSymbolicLink]) {
            if (error) *error = WPError(85, @"Plugin contains a symbolic link");
            return NO;
        }
        if ([type isEqualToString:NSFileTypeDirectory]) continue;
        if (![type isEqualToString:NSFileTypeRegular] || ![allowed containsObject:relative]) {
            if (error) *error = WPError(85, @"Plugin contains an unexpected file");
            return NO;
        }
        actualBytes += [attributes[NSFileSize] unsignedLongLongValue];
        if (actualBytes > WP_MAX_EXTRACTED_BYTES) {
            if (error) *error = WPError(85, @"Plugin files are too large");
            return NO;
        }
    }
    for (NSString *relative in checksums) {
        NSString *full = [root stringByAppendingPathComponent:relative];
        BOOL fileIsDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&fileIsDirectory] || fileIsDirectory) {
            if (error) *error = WPError(86, [NSString stringWithFormat:@"Plugin file is missing: %@", relative]);
            return NO;
        }
        NSError *hashError = nil;
        NSString *hash = WPSHA256File(full, &hashError);
        if (!hash || ![hash isEqualToString:[checksums[relative] lowercaseString]]) {
            if (error) *error = hashError ?: WPError(86, [NSString stringWithFormat:@"Plugin file was modified: %@", relative]);
            return NO;
        }
    }
    return YES;
}

- (void)markPluginIDInvalid:(NSString *)pluginID message:(NSString *)message {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) return;
    NSMutableDictionary *state = [plugin.state mutableCopy];
    state[@"verificationState"] = @(WitchPluginVerificationStateInvalid);
    state[@"verificationMessage"] = message.length > 0 ? message : @"Plugin files failed integrity verification";
    state[@"enabled"] = @NO;
    [self writeState:state pluginID:pluginID directory:plugin.installPath error:nil];
    [self updateConfigurationForPluginID:pluginID enabled:NO];
    [self reload];
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
}

- (BOOL)installPackageAtURL:(NSURL *)url error:(NSError **)error {
    return [self installPackageAtURL:url expectedInfo:nil error:error];
}

- (BOOL)installPackageAtURL:(NSURL *)url expectedInfo:(NSDictionary *)expectedInfo error:(NSError **)error {
    NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"witch-plugin-install-%@", NSUUID.UUID.UUIDString]];
    NSDictionary *info = [self inspectPackageAtURL:url extractTo:temp error:error];
    if (!info) {
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        return NO;
    }
    if (expectedInfo) {
        NSDictionary *expectedManifest = [expectedInfo[@"manifest"] isKindOfClass:[NSDictionary class]] ? expectedInfo[@"manifest"] : @{};
        NSDictionary *expectedState = [expectedInfo[@"state"] isKindOfClass:[NSDictionary class]] ? expectedInfo[@"state"] : @{};
        NSDictionary *actualManifest = info[@"manifest"];
        NSDictionary *actualState = info[@"state"];
        BOOL matches = [WPString(expectedManifest[@"id"]) isEqualToString:WPString(actualManifest[@"id"])] &&
                       [WPString(expectedManifest[@"version"]) isEqualToString:WPString(actualManifest[@"version"])] &&
                       [WPString(expectedState[@"artifactSha256"]) isEqualToString:WPString(actualState[@"artifactSha256"])] &&
                       [WPString(expectedState[@"checksumsSha256"]) isEqualToString:WPString(actualState[@"checksumsSha256"])];
        if (!matches) {
            if (error) *error = WPError(92, @"Plugin package changed after verification");
            [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
            return NO;
        }
    }
    NSDictionary *manifest = info[@"manifest"];
    NSString *pluginID = WPString(manifest[@"id"]);
    NSString *destination = [amethyst_hidden_dir(@"plugins") stringByAppendingPathComponent:pluginID];
    if (WPFileExists(destination)) {
        if (error) *error = WPError(60, [NSString stringWithFormat:@"Plugin %@ is already installed", pluginID]);
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        return NO;
    }
    if (![[NSFileManager defaultManager] moveItemAtPath:temp toPath:destination error:error]) {
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        return NO;
    }

    NSMutableDictionary *state = [[self defaultStateForPlugin:pluginID] mutableCopy];
    NSDictionary *signatureState = info[@"state"];
    for (NSString *key in signatureState) state[key] = signatureState[key];
    state[@"enabled"] = @YES;
    NSDictionary *signature = info[@"signature"];
    NSString *keyID = WPString(signature[@"keyId"]);
    NSString *publicKey = WPString(signature[@"publicKey"]);
    if (state[@"trusted"] && [state[@"trusted"] boolValue]) WPPinKey(keyID, publicKey);
    [self writeState:state pluginID:pluginID directory:destination error:nil];
    [self addConfigurationForPluginID:pluginID version:WPString(manifest[@"version"])];
    [self reload];
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (BOOL)uninstallPluginID:(NSString *)pluginID error:(NSError **)error {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) {
        if (error) *error = WPError(61, @"Plugin is not installed");
        return NO;
    }
    if (![[NSFileManager defaultManager] removeItemAtPath:plugin.installPath error:error]) return NO;
    [[NSFileManager defaultManager] removeItemAtPath:[self markerPathForPluginID:pluginID] error:nil];
    [self removeConfigurationForPluginID:pluginID];
    [self reload];
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (BOOL)setPluginID:(NSString *)pluginID enabled:(BOOL)enabled error:(NSError **)error {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) {
        if (error) *error = WPError(62, @"Plugin is not installed");
        return NO;
    }
    if (enabled && self.safeMode) {
        if (error) *error = WPError(63, @"Safe mode is active. Turn it off before enabling plugins.");
        return NO;
    }
    if (enabled && (plugin.verificationState == WitchPluginVerificationStateRevoked || plugin.verificationState == WitchPluginVerificationStateInvalid)) {
        if (error) *error = WPError(63, @"This plugin build is blocked by the registry and cannot be enabled.");
        return NO;
    }
    if (enabled) {
        NSError *integrityError = nil;
        if (![self verifyIntegrityForPlugin:plugin error:&integrityError]) {
            [self markPluginIDInvalid:pluginID message:integrityError.localizedDescription];
            if (error) *error = integrityError;
            return NO;
        }
    }
    NSMutableDictionary *state = [plugin.state mutableCopy];
    state[@"enabled"] = @(enabled);
    if (![self writeState:state pluginID:pluginID directory:plugin.installPath error:error]) return NO;
    [self updateConfigurationForPluginID:pluginID enabled:enabled];
    [plugin updateState:state];
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (BOOL)setSafeMode:(BOOL)safeMode error:(NSError **)error {
    if (safeMode) {
        NSString *path = WPSafeModePath();
        if (!path) {
            if (error) *error = WPError(64, @"Launcher home is unavailable");
            return NO;
        }
        if (![@"safe-mode\n" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
    } else {
        NSString *path = WPSafeModePath();
        if (path.length > 0) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        NSString *legacy = WPLegacySafeModePath();
        if (legacy.length > 0) [[NSFileManager defaultManager] removeItemAtPath:legacy error:nil];
    }
    self.safeMode = safeMode;
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (nullable NSURL *)verificationURLForPluginID:(NSString *)pluginID
                                         version:(NSString *)version
                                 checksumsSha256:(NSString *)checksumsSha256
                                  artifactSha256:(NSString *)artifactSha256
                                           keyID:(NSString *)keyID
                                           error:(NSError **)error {
    NSString *base = WPBaseURL();
    if (base.length == 0) {
        if (error) *error = WPError(70, @"Verification server is not configured");
        return nil;
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:[base stringByAppendingString:@"/v1/plugins/verify"]];
    NSMutableArray *items = [NSMutableArray array];
    void (^add)(NSString *, NSString *) = ^(NSString *name, NSString *value) {
        if (value.length == 0) return;
        [items addObject:[NSURLQueryItem queryItemWithName:name value:value]];
    };
    add(@"id", pluginID);
    add(@"version", version);
    add(@"checksumsSha256", checksumsSha256);
    add(@"artifactSha256", artifactSha256);
    add(@"keyId", keyID);
    components.queryItems = items;
    if (!components.URL) {
        if (error) *error = WPError(75, @"Invalid verification server URL");
        return nil;
    }
    return components.URL;
}

- (void)verifyPlugin:(WitchPlugin *)plugin completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSError *urlError = nil;
    NSURL *verificationURL = [self verificationURLForPluginID:plugin.pluginID
                                                      version:plugin.version
                                              checksumsSha256:plugin.checksumsSha256
                                               artifactSha256:plugin.artifactSha256
                                                        keyID:plugin.signatureKeyID
                                                        error:&urlError];
    if (!verificationURL) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, urlError); });
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:verificationURL];
    request.timeoutInterval = 15;
    request.HTTPMethod = @"GET";
    [request setValue:@"WitchLauncher/1.0" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, networkError); });
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, @"Invalid verification response")); });
            return;
        }
        if (![json[@"ok"] boolValue]) {
            NSString *serverError = WPString(json[@"error"]);
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, serverError.length > 0 ? serverError : @"Registry verification failed")); });
            return;
        }
        BOOL verified = [json[@"verified"] boolValue];
        NSString *status = WPString(json[@"status"]);
        NSString *reason = WPString(json[@"reason"]);
        if ([status isEqualToString:@"unavailable"]) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, reason.length > 0 ? reason : @"Registry verification is unavailable")); });
            return;
        }
        NSError *integrityError = nil;
        if (![self verifyIntegrityForPlugin:plugin error:&integrityError]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self markPluginIDInvalid:plugin.pluginID message:integrityError.localizedDescription];
                if (completion) completion(NO, integrityError);
            });
            return;
        }
        NSMutableDictionary *state = [plugin.state mutableCopy];
        if (verified) {
            state[@"verificationState"] = @(WitchPluginVerificationStateVerified);
            state[@"verificationMessage"] = @"Verified by the Witch plugin registry";
            state[@"verifiedAt"] = WPString(json[@"verifiedAt"]);
            state[@"license"] = WPString([json[@"plugin"] isKindOfClass:[NSDictionary class]] ? json[@"plugin"][@"license"] : nil);
        } else if ([status isEqualToString:@"revoked"]) {
            state[@"verificationState"] = @(WitchPluginVerificationStateRevoked);
            state[@"verificationMessage"] = reason.length > 0 ? reason : @"This plugin was revoked by the registry";
            state[@"enabled"] = @NO;
        } else if ([status isEqualToString:@"rejected"] || [status isEqualToString:@"invalid"]) {
            state[@"verificationState"] = @(WitchPluginVerificationStateInvalid);
            state[@"verificationMessage"] = reason.length > 0 ? reason : @"This plugin failed registry verification";
            state[@"enabled"] = @NO;
        } else {
            state[@"verificationState"] = @(WitchPluginVerificationStateUnverified);
            state[@"verificationMessage"] = reason.length > 0 ? reason : @"Not verified by the Witch plugin registry";
        }
        NSError *saveError = nil;
        [self writeState:state pluginID:plugin.pluginID directory:plugin.installPath error:&saveError];
        if (state[@"enabled"] && ![state[@"enabled"] boolValue]) {
            [self updateConfigurationForPluginID:plugin.pluginID enabled:NO];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [plugin updateState:state];
            [WitchPluginTheme reload];
            [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
            if (completion) completion(verified, saveError);
        });
    }];
    [task resume];
}

- (void)verifyInstalledPlugins {
    NSArray<WitchPlugin *> *plugins = self.plugins.copy;
    for (WitchPlugin *plugin in plugins) {
        if (plugin.checksumsSha256.length == 0 || plugin.artifactSha256.length == 0) continue;
        [self verifyPlugin:plugin completion:nil];
    }
}

- (void)verifyPackageInfo:(NSDictionary *)info completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSDictionary *manifest = [info[@"manifest"] isKindOfClass:[NSDictionary class]] ? info[@"manifest"] : @{};
    NSDictionary *state = [info[@"state"] isKindOfClass:[NSDictionary class]] ? info[@"state"] : @{};
    NSError *urlError = nil;
    NSURL *verificationURL = [self verificationURLForPluginID:WPString(manifest[@"id"])
                                                      version:WPString(manifest[@"version"])
                                              checksumsSha256:WPString(state[@"checksumsSha256"])
                                               artifactSha256:WPString(state[@"artifactSha256"])
                                                        keyID:WPString(state[@"keyId"])
                                                        error:&urlError];
    if (!verificationURL) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, urlError); });
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:verificationURL];
    request.timeoutInterval = 15;
    request.HTTPMethod = @"GET";
    [request setValue:@"WitchLauncher/1.0" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, networkError); });
            return;
        }
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        if (statusCode >= 400) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, [NSString stringWithFormat:@"Registry verification failed (HTTP %ld)", (long)statusCode])); });
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, @"Invalid verification response")); });
            return;
        }
        if (![json[@"ok"] boolValue]) {
            NSString *serverError = WPString(json[@"error"]);
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, serverError.length > 0 ? serverError : @"Registry verification failed")); });
            return;
        }
        BOOL verified = [json[@"verified"] boolValue];
        NSString *status = WPString(json[@"status"]);
        NSString *reason = WPString(json[@"reason"]);
        if ([status isEqualToString:@"unavailable"]) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(71, reason.length > 0 ? reason : @"Registry verification is unavailable")); });
            return;
        }
        if (verified) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
            return;
        }
        NSString *message = reason.length > 0 ? reason : @"This plugin is not verified by the Witch registry";
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, WPError(78, message)); });
    }];
    [task resume];
}

- (NSDictionary *)settingsForPluginID:(NSString *)pluginID {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    return plugin ? plugin.settings : @{};
}

- (BOOL)setSettingValue:(id)value forKey:(NSString *)key pluginID:(NSString *)pluginID error:(NSError **)error {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) {
        if (error) *error = WPError(72, @"Plugin is not installed");
        return NO;
    }
    if (key.length == 0 || !value || ![NSJSONSerialization isValidJSONObject:@{key: value}]) {
        if (error) *error = WPError(73, @"Plugin setting value is not serializable");
        return NO;
    }
    NSMutableDictionary *state = [plugin.state mutableCopy];
    NSMutableDictionary *settings = [plugin.settings mutableCopy];
    settings[key] = value;
    state[@"settings"] = settings;
    if (![self writeState:state pluginID:pluginID directory:plugin.installPath error:error]) return NO;
    [self updateConfigurationForPluginID:pluginID settingKey:key value:value];
    [plugin updateState:state];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (BOOL)setThemeColors:(NSDictionary *)colors pluginID:(NSString *)pluginID error:(NSError **)error {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) {
        if (error) *error = WPError(74, @"Plugin is not installed");
        return NO;
    }
    NSMutableDictionary *state = [plugin.state mutableCopy];
    NSMutableDictionary *themeColors = [state[@"themeColors"] isKindOfClass:[NSDictionary class]] ? [state[@"themeColors"] mutableCopy] : [NSMutableDictionary dictionary];
    for (NSString *key in colors) {
        if (![key isKindOfClass:[NSString class]] || ![colors[key] isKindOfClass:[NSString class]]) continue;
        themeColors[key] = colors[key];
    }
    state[@"themeColors"] = themeColors;
    if (![self writeState:state pluginID:pluginID directory:plugin.installPath error:error]) return NO;
    [plugin updateState:state];
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (BOOL)trustKeyForPluginID:(NSString *)pluginID error:(NSError **)error {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) {
        if (error) *error = WPError(76, @"Plugin is not installed");
        return NO;
    }
    if (plugin.signatureKeyID.length == 0 || plugin.publicKeyBase64.length == 0) {
        if (error) *error = WPError(77, @"Plugin has no signing key");
        return NO;
    }
    WPPinKey(plugin.signatureKeyID, plugin.publicKeyBase64);
    NSMutableDictionary *state = [plugin.state mutableCopy];
    state[@"trusted"] = @YES;
    state[@"developerSigned"] = @NO;
    if (![self writeState:state pluginID:pluginID directory:plugin.installPath error:error]) return NO;
    [plugin updateState:state];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

- (NSString *)markerPathForPluginID:(NSString *)pluginID {
    NSString *runtime = amethyst_hidden_dir(@"plugins/runtime");
    return [runtime stringByAppendingPathComponent:[pluginID stringByAppendingPathExtension:@"loading"]];
}

- (void)noteRuntimeFailureForPluginID:(NSString *)pluginID {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) return;
    NSMutableDictionary *state = [plugin.state mutableCopy];
    NSInteger crashes = [state[@"crashCount"] integerValue] + 1;
    state[@"crashCount"] = @(crashes);
    state[@"enabled"] = @NO;
    state[@"verificationMessage"] = @"Disabled after a runtime failure";
    [self writeState:state pluginID:pluginID directory:plugin.installPath error:nil];
    [self updateConfigurationForPluginID:pluginID enabled:NO];
    [[NSFileManager defaultManager] removeItemAtPath:[self markerPathForPluginID:pluginID] error:nil];
    if (crashes >= 2) [self setSafeMode:YES error:nil];
    [self reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
}

- (void)noteRuntimeSuccessForPluginID:(NSString *)pluginID {
    WitchPlugin *plugin = [self pluginWithID:pluginID];
    if (!plugin) return;
    NSMutableDictionary *state = [plugin.state mutableCopy];
    if ([state[@"crashCount"] integerValue] != 0) {
        state[@"crashCount"] = @0;
        [self writeState:state pluginID:pluginID directory:plugin.installPath error:nil];
        [plugin updateState:state];
    }
    [[NSFileManager defaultManager] removeItemAtPath:[self markerPathForPluginID:pluginID] error:nil];
}

- (void)recoverFromCrashMarkers {
    NSString *runtime = amethyst_hidden_dir(@"plugins/runtime");
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:runtime error:nil];
    for (NSString *entry in entries) {
        if (![entry.pathExtension isEqualToString:@"loading"]) continue;
        NSString *pluginID = [entry stringByDeletingPathExtension];
        WitchPlugin *plugin = [self pluginWithID:pluginID];
        if (plugin) {
            NSMutableDictionary *state = [plugin.state mutableCopy];
            NSInteger crashes = [state[@"crashCount"] integerValue] + 1;
            state[@"crashCount"] = @(crashes);
            state[@"enabled"] = @NO;
            state[@"verificationMessage"] = @"Disabled after the launcher terminated while this plugin was loading";
            [self writeState:state pluginID:pluginID directory:plugin.installPath error:nil];
            [self updateConfigurationForPluginID:pluginID enabled:NO];
            if (crashes >= 2) [self setSafeMode:YES error:nil];
        }
        [[NSFileManager defaultManager] removeItemAtPath:[runtime stringByAppendingPathComponent:entry] error:nil];
    }
    if (entries.count > 0) [self reload];
}

@end
