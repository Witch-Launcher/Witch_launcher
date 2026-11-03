#import "ModpackExporter.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "CurseForgeService.h"
#import "UnzipKit.h"
#import "utils.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const kModpackExporterErrorDomain = @"ModpackExporter";
static NSString * const kModrinthVersionFilesURL = @"https://api.modrinth.com/v2/version_files";

static NSError *MPExportError(NSString *message) {
    return [NSError errorWithDomain:kModpackExporterErrorDomain
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Export failed."}];
}

static BOOL MPIsConnectivityError(NSError *error) {
    if (![error.domain isEqualToString:NSURLErrorDomain]) return NO;
    switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorTimedOut:
            return YES;
        default:
            return NO;
    }
}

static NSString *MPHexString(const unsigned char *bytes, NSUInteger length) {
    static const char digits[] = "0123456789abcdef";
    NSMutableString *hex = [NSMutableString stringWithCapacity:length * 2];
    for (NSUInteger i = 0; i < length; i++) {
        [hex appendFormat:@"%c%c", digits[bytes[i] >> 4], digits[bytes[i] & 0x0F]];
    }
    return hex;
}

static NSDictionary *MPHashFile(NSString *path, NSError **error) {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    if (!stream) {
        if (error) *error = MPExportError([NSString stringWithFormat:@"Could not read %@", path.lastPathComponent]);
        return nil;
    }
    [stream open];
    if (stream.streamError) {
        if (error) *error = stream.streamError;
        return nil;
    }

    CC_SHA1_CTX sha1;
    CC_SHA512_CTX sha512;
    CC_SHA1_Init(&sha1);
    CC_SHA512_Init(&sha512);

    uint8_t buffer[128 * 1024];
    unsigned long long total = 0;
    while (YES) {
        NSInteger read = [stream read:buffer maxLength:sizeof(buffer)];
        if (read < 0) {
            if (error) *error = stream.streamError ?: MPExportError(@"Could not read file.");
            [stream close];
            return nil;
        }
        if (read == 0) break;
        CC_SHA1_Update(&sha1, buffer, (CC_LONG)read);
        CC_SHA512_Update(&sha512, buffer, (CC_LONG)read);
        total += (unsigned long long)read;
    }
    [stream close];

    unsigned char sha1Digest[CC_SHA1_DIGEST_LENGTH];
    unsigned char sha512Digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA1_Final(sha1Digest, &sha1);
    CC_SHA512_Final(sha512Digest, &sha512);

    return @{
        @"sha1": MPHexString(sha1Digest, CC_SHA1_DIGEST_LENGTH),
        @"sha512": MPHexString(sha512Digest, CC_SHA512_DIGEST_LENGTH),
        @"size": @(total),
    };
}

static BOOL MPIsHiddenName(NSString *name) {
    return name.length == 0 || [name hasPrefix:@"."];
}

static BOOL MPIsManifestName(NSString *name) {
    return [name isEqualToString:@"installed_mods.json"] ||
           [name isEqualToString:@"installed_shaderpacks.json"] ||
           [name isEqualToString:@"installed_resourcepacks.json"];
}

static NSArray<NSString *> *MPOverrideDirectories(void) {
    return @[
        @"config", @"defaultconfigs", @"kubejs", @"scripts", @"customnpcs",
        @"openloader", @"packmenu", @"global_packs", @"datapacks",
        @"patchouli_books", @"local", @"structures", @"schematics", @"fontfiles",
    ];
}

static void MPCollectOverrideFiles(NSString *root,
                                   NSString *relative,
                                   NSMutableArray<NSDictionary *> *out,
                                   NSFileManager *fm) {
    NSString *directory = relative.length > 0 ? [root stringByAppendingPathComponent:relative] : root;
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:directory error:nil];
    if (![names isKindOfClass:[NSArray class]]) return;

    for (NSString *name in names) {
        if (MPIsHiddenName(name)) continue;
        NSString *childRelative = relative.length > 0 ? [relative stringByAppendingPathComponent:name] : name;
        NSString *fullPath = [root stringByAppendingPathComponent:childRelative];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        NSString *type = attrs[NSFileType];
        if ([type isEqualToString:NSFileTypeDirectory]) {
            MPCollectOverrideFiles(root, childRelative, out, fm);
        } else if ([type isEqualToString:NSFileTypeRegular]) {
            [out addObject:@{@"source": fullPath, @"path": childRelative}];
        }
    }
}

static NSString *MPFilenameForbiddenCharacters(void) {
    return @"/\\:*?\"<>|";
}

static NSString *MPSanitizeExportComponent(NSString *input) {
    NSString *source = [input isKindOfClass:[NSString class]] ? input : @"";
    NSMutableCharacterSet *edges = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [edges addCharactersInString:@"."];
    source = [source stringByTrimmingCharactersInSet:edges];
    if (source.length == 0) return @"";

    NSMutableCharacterSet *forbidden = [NSMutableCharacterSet characterSetWithCharactersInString:MPFilenameForbiddenCharacters()];
    [forbidden formUnionWithCharacterSet:NSCharacterSet.controlCharacterSet];
    NSArray<NSString *> *parts = [source componentsSeparatedByCharactersInSet:forbidden];
    NSMutableArray<NSString *> *clean = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:edges];
        if (trimmed.length > 0) [clean addObject:trimmed];
    }
    return [clean componentsJoinedByString:@"-"];
}

static NSString *MPTruncateUTF8(NSString *string, NSUInteger maxBytes) {
    if (string.length == 0 || maxBytes == 0) return @"";
    if ([string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= maxBytes) return string;
    NSUInteger length = string.length;
    while (length > 0) {
        NSRange range = [string rangeOfComposedCharacterSequenceAtIndex:length - 1];
        length = range.location;
        NSString *candidate = [string substringToIndex:length];
        if ([candidate lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= maxBytes) return candidate;
    }
    return @"";
}

static NSString *MPSafeExportBaseName(NSString *name, NSString *version) {
    NSString *base = MPTruncateUTF8(MPSanitizeExportComponent(name), 140);
    if (base.length == 0) base = @"modpack";

    NSString *ver = MPTruncateUTF8(MPSanitizeExportComponent(version), 60);
    if (ver.length > 0) base = [base stringByAppendingFormat:@"-%@", ver];
    return base;
}

static NSString *MPNormalizeMcVersion(NSString *raw) {
    NSString *version = [VersionProfile cleanMinecraftVersion:raw];
    if (version.length == 0) return version;
    NSString *lower = version.lowercaseString;
    for (NSString *token in @[@"-fabric-loader-", @"-quilt-loader-", @"-neoforge-", @"-forge-", @"-optifine"]) {
        NSRange range = [lower rangeOfString:token];
        if (range.location != NSNotFound) {
            version = [version substringToIndex:range.location];
            break;
        }
    }
    return version;
}

static NSString *MPLoaderKeyForType(NSString *loaderType) {
    NSString *lower = loaderType.lowercaseString ?: @"";
    if ([lower containsString:@"fabric"]) return @"fabric-loader";
    if ([lower containsString:@"quilt"]) return @"quilt-loader";
    if ([lower containsString:@"neoforge"]) return @"neoforge";
    if ([lower containsString:@"forge"]) return @"forge";
    return nil;
}

static NSString *MPLoaderVersionFromIdentifier(NSString *raw, NSString *mcVersion, NSString *loaderType) {
    if (![raw isKindOfClass:[NSString class]] || raw.length == 0) return nil;
    NSString *s = raw;
    NSString *lower = s.lowercaseString;
    NSString *type = loaderType.lowercaseString ?: @"";

    if ([type containsString:@"fabric"] || [type containsString:@"quilt"]) {
        NSString *prefix = [NSString stringWithFormat:@"%@-loader-", [type containsString:@"quilt"] ? @"quilt" : @"fabric"];
        if (![lower hasPrefix:prefix]) return nil;
        s = [s substringFromIndex:prefix.length];
        if (mcVersion.length > 0) {
            NSString *suffix = [@"-" stringByAppendingString:mcVersion];
            if ([s hasSuffix:suffix]) s = [s substringToIndex:s.length - suffix.length];
        }
        return s.length > 0 ? s : nil;
    }

    if ([type containsString:@"forge"]) {
        BOOL hasForgeToken = [lower containsString:@"forge-"];
        if ([lower hasPrefix:@"neoforge-"]) {
            s = [s substringFromIndex:@"neoforge-".length];
        } else if ([lower hasPrefix:@"forge-"]) {
            s = [s substringFromIndex:@"forge-".length];
        }
        if (mcVersion.length > 0 && [s hasPrefix:[mcVersion stringByAppendingString:@"-"]]) {
            s = [s substringFromIndex:mcVersion.length + 1];
        }
        NSString *sLower = s.lowercaseString;
        if ([sLower hasPrefix:@"neoforge"] || [sLower hasPrefix:@"forge"]) {
            NSString *token = [sLower hasPrefix:@"neoforge"] ? @"neoforge" : @"forge";
            NSString *rest = [s substringFromIndex:token.length];
            if (mcVersion.length > 0 && [rest hasPrefix:[mcVersion stringByAppendingString:@"-"]]) {
                rest = [rest substringFromIndex:mcVersion.length + 1];
            } else if ([rest hasPrefix:@"-"]) {
                rest = [rest substringFromIndex:1];
            }
            s = rest;
            hasForgeToken = YES;
        }
        return (hasForgeToken && s.length > 0) ? s : nil;
    }
    return nil;
}

@interface ModpackExporter ()
@property (nonatomic, copy) NSDictionary *profile;
@property (nonatomic) ModpackExportFormat format;
@property (nonatomic, copy) NSString *packName;
@property (nonatomic, copy) NSString *packVersion;
@property (nonatomic, copy) NSString *packAuthor;
@property (nonatomic, copy, nullable) void (^progressBlock)(double, NSString *);
@property (nonatomic, copy) void (^completionBlock)(NSString *, NSError *);

@property (nonatomic, copy) NSString *versionKey;
@property (nonatomic, copy) NSString *versionDir;
@property (nonatomic, copy) NSString *mcVersion;
@property (nonatomic, copy) NSString *loaderType;
@property (nonatomic, copy) NSString *loaderVersion;

@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *entries;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *overrides;
@property (nonatomic, strong) NSMutableSet<NSString *> *overridePaths;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *modrinthMatches;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSMutableDictionary *> *> *curseForgeByProject;

@property (nonatomic) NSInteger curseForgeFailureCount;
@property (nonatomic) BOOL finished;
@end

@implementation ModpackExporter

+ (void)exportProfile:(NSDictionary *)profile
               format:(ModpackExportFormat)format
                 name:(NSString *)name
              version:(NSString *)version
               author:(NSString *)author
             progress:(void (^)(double, NSString *))progress
           completion:(void (^)(NSString *, NSError *))completion {
    ModpackExporter *exporter = [[ModpackExporter alloc] init];
    exporter.profile = [profile isKindOfClass:[NSDictionary class]] ? [profile copy] : @{};
    exporter.format = format;
    exporter.packName = name;
    exporter.packVersion = version;
    exporter.packAuthor = author;
    exporter.progressBlock = progress;
    exporter.completionBlock = completion;
    [exporter start];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        _overrides = [NSMutableArray array];
        _overridePaths = [NSMutableSet set];
        _modrinthMatches = [NSMutableDictionary dictionary];
        _curseForgeByProject = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Flow

- (void)start {
    NSString *versionKey = [[InstalledModsManager shared] versionKeyForProfile:self.profile];
    if (versionKey.length == 0 || [versionKey isEqualToString:@"latest-release"] || [versionKey isEqualToString:@"latest-snapshot"]) {
        [self finishWithPath:nil error:MPExportError(localize(@"modpack.export_no_version", nil))];
        return;
    }
    self.versionKey = versionKey;
    self.versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionKey];

    VersionProfile *profile = [VersionProfile profileWithVersionId:versionKey];
    NSString *rawMcVersion = [profile.mcVersion isKindOfClass:[NSString class]] ? profile.mcVersion : nil;
    self.mcVersion = MPNormalizeMcVersion(rawMcVersion);
    if (self.mcVersion.length == 0) {
        [self finishWithPath:nil error:MPExportError(localize(@"modpack.export_no_version", nil))];
        return;
    }
    [self resolveLoaderInfoWithProfile:profile];

    if (![[NSFileManager defaultManager] fileExistsAtPath:self.versionDir]) {
        [self finishWithPath:nil error:MPExportError(localize(@"modpack.export_missing_dir", nil))];
        return;
    }

    [self report:0.02 message:localize(@"modpack.export_prepare", nil)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *scanError = nil;
        if (![self scanAndHashFiles:&scanError]) {
            [self finishWithPath:nil error:scanError];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.format == ModpackExportFormatModrinth) {
                [self beginModrinthLookup];
            } else {
                [self beginCurseForgeLookup];
            }
        });
    });
}

- (void)resolveLoaderInfoWithProfile:(VersionProfile *)profile {
    self.loaderType = [profile.modLoader isKindOfClass:[NSString class]] ? profile.modLoader : @"";
    NSString *jsonPath = [self.versionDir stringByAppendingPathComponent:[self.versionKey stringByAppendingString:@".json"]];
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
    NSDictionary *json = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
    if (![json isKindOfClass:[NSDictionary class]]) json = nil;

    NSString *inherits = [json[@"inheritsFrom"] isKindOfClass:[NSString class]] ? json[@"inheritsFrom"] : nil;
    NSString *loaderVersion = MPLoaderVersionFromIdentifier(inherits, self.mcVersion, self.loaderType);
    if (loaderVersion.length == 0) {
        loaderVersion = MPLoaderVersionFromIdentifier(self.versionKey, self.mcVersion, self.loaderType);
    }
    if (loaderVersion.length == 0) {
        id stored = json[@"modLoaderVersion"];
        if ([stored isKindOfClass:[NSString class]]) loaderVersion = stored;
    }
    self.loaderVersion = loaderVersion ?: @"";
}

- (void)report:(double)fraction message:(NSString *)message {
    void (^block)(double, NSString *) = self.progressBlock;
    if (!block) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        block(MAX(0.0, MIN(1.0, fraction)), message ?: @"");
    });
}

- (void)finishWithPath:(NSString *)path error:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    void (^completion)(NSString *, NSError *) = self.completionBlock;
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(path, error);
    });
}

#pragma mark - Scanning

- (BOOL)scanAndHashFiles:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray<NSDictionary *> *contentDirs = @[
        @{@"dir": [[InstalledModsManager shared] modsDirForProfile:self.profile] ?: @"", @"prefix": @"mods", @"category": InstalledItemCategoryMod},
        @{@"dir": [[InstalledModsManager shared] resourcePacksDirForProfile:self.profile] ?: @"", @"prefix": @"resourcepacks", @"category": InstalledItemCategoryResourcePack},
        @{@"dir": [[InstalledModsManager shared] shaderPacksDirForProfile:self.profile] ?: @"", @"prefix": @"shaderpacks", @"category": InstalledItemCategoryShaderPack},
    ];

    NSMutableArray<NSMutableDictionary *> *candidates = [NSMutableArray array];
    for (NSDictionary *contentDir in contentDirs) {
        NSString *dir = contentDir[@"dir"];
        if (dir.length == 0) continue;
        NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:dir error:nil];
        if (![names isKindOfClass:[NSArray class]]) continue;

        for (NSString *name in names) {
            if (MPIsHiddenName(name) || MPIsManifestName(name)) continue;
            if ([name.lowercaseString hasSuffix:@".off"]) continue;
            NSString *fullPath = [dir stringByAppendingPathComponent:name];
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
            if (![attrs[NSFileType] isEqualToString:NSFileTypeRegular]) continue;

            NSString *relativePath = [contentDir[@"prefix"] stringByAppendingPathComponent:name];
            [candidates addObject:[@{
                @"sourcePath": fullPath,
                @"relativePath": relativePath,
                @"filename": name,
                @"category": contentDir[@"category"],
            } mutableCopy]];
        }
    }

    for (NSString *directoryName in MPOverrideDirectories()) {
        NSString *fullDir = [self.versionDir stringByAppendingPathComponent:directoryName];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullDir error:nil];
        if (![attrs[NSFileType] isEqualToString:NSFileTypeDirectory]) continue;
        NSMutableArray<NSDictionary *> *collected = [NSMutableArray array];
        MPCollectOverrideFiles(self.versionDir, directoryName, collected, fm);
        for (NSDictionary *item in collected) {
            NSString *path = item[@"path"];
            if (path.length == 0 || [self.overridePaths containsObject:path]) continue;
            [self.overridePaths addObject:path];
            [self.overrides addObject:item];
        }
    }

    self.entries = candidates;
    NSUInteger total = candidates.count + self.overrides.count;
    if (total == 0) {
        [self finishWithPath:nil error:MPExportError(localize(@"modpack.export_no_content", nil))];
        return NO;
    }

    [self report:0.05 message:[NSString stringWithFormat:localize(@"modpack.export_hash", nil), (unsigned long)candidates.count]];
    for (NSUInteger i = 0; i < candidates.count; i++) {
        NSMutableDictionary *entry = candidates[i];
        @autoreleasepool {
            NSError *hashError = nil;
            NSDictionary *hashes = MPHashFile(entry[@"sourcePath"], &hashError);
            if (!hashes) {
                if (error) *error = hashError ?: MPExportError(localize(@"modpack.export_failed", nil));
                return NO;
            }
            [entry addEntriesFromDictionary:hashes];
        }
        double fraction = candidates.count > 0 ? 0.05 + 0.20 * ((double)(i + 1) / (double)total) : 0.25;
        [self report:fraction message:[NSString stringWithFormat:localize(@"modpack.export_hash", nil), (unsigned long)candidates.count]];
    }
    return YES;
}

#pragma mark - Modrinth

- (void)beginModrinthLookup {
    if (self.entries.count == 0) {
        [self finishModrinthManifest];
        return;
    }

    NSMutableArray<NSString *> *hashes = [NSMutableArray arrayWithCapacity:self.entries.count];
    for (NSDictionary *entry in self.entries) {
        NSString *sha1 = entry[@"sha1"];
        if (sha1.length > 0) [hashes addObject:sha1];
    }

    NSMutableArray<NSArray<NSString *> *> *chunks = [NSMutableArray array];
    NSUInteger chunkSize = 100;
    for (NSUInteger i = 0; i < hashes.count; i += chunkSize) {
        NSUInteger length = MIN(chunkSize, hashes.count - i);
        [chunks addObject:[hashes subarrayWithRange:NSMakeRange(i, length)]];
    }

    self.modrinthMatches = [NSMutableDictionary dictionary];
    [self lookupModrinthChunks:chunks index:0];
}

- (void)lookupModrinthChunks:(NSArray<NSArray<NSString *> *> *)chunks index:(NSUInteger)index {
    if (index >= chunks.count) {
        [self finishModrinthManifest];
        return;
    }

    NSArray<NSString *> *hashes = chunks[index];
    double fraction = 0.30 + 0.25 * ((double)index / (double)MAX((NSUInteger)1, chunks.count));
    [self report:fraction message:localize(@"modpack.export_lookup", nil)];

    NSDictionary *body = @{@"hashes": hashes ?: @[], @"algorithm": @"sha1"};
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kModrinthVersionFilesURL]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            if (data.length > 0 && (statusCode == 0 || statusCode == 200)) {
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:[NSDictionary class]]) {
                    [self absorbModrinthResponse:json];
                }
            }
            if (error || (statusCode != 0 && statusCode != 200)) {
                [self finishModrinthManifest];
                return;
            }
            [self lookupModrinthChunks:chunks index:index + 1];
        });
    }] resume];
}

- (void)absorbModrinthResponse:(NSDictionary *)json {
    for (NSString *hash in json) {
        id version = json[hash];
        if (![version isKindOfClass:[NSDictionary class]]) continue;
        NSArray *files = version[@"files"];
        if (![files isKindOfClass:[NSArray class]]) continue;

        NSDictionary *matchedFile = nil;
        for (NSDictionary *file in files) {
            if (![file isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *hashes = file[@"hashes"];
            if ([hashes isKindOfClass:[NSDictionary class]] && [hashes[@"sha1"] isEqualToString:hash]) {
                matchedFile = file;
                break;
            }
        }
        if (!matchedFile) continue;

        NSString *url = matchedFile[@"url"];
        if (![url isKindOfClass:[NSString class]] || ![url.lowercaseString hasPrefix:@"https://"]) continue;
        self.modrinthMatches[hash] = @{@"url": url};
    }
}

- (void)finishModrinthManifest {
    NSMutableArray<NSDictionary *> *files = [NSMutableArray arrayWithCapacity:self.entries.count];
    for (NSDictionary *entry in self.entries) {
        NSDictionary *match = self.modrinthMatches[entry[@"sha1"]];
        if (match) {
            [files addObject:@{
                @"path": entry[@"relativePath"],
                @"hashes": @{@"sha1": entry[@"sha1"], @"sha512": entry[@"sha512"]},
                @"downloads": @[match[@"url"]],
                @"fileSize": entry[@"size"],
            }];
        } else {
            [self addEntryToOverrides:entry];
        }
    }

    [files sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"path"] compare:b[@"path"]];
    }];

    NSMutableDictionary *manifest = [NSMutableDictionary dictionary];
    manifest[@"formatVersion"] = @1;
    manifest[@"game"] = @"minecraft";
    manifest[@"versionId"] = [self effectivePackVersion];
    manifest[@"name"] = [self effectivePackName];
    manifest[@"summary"] = [NSString stringWithFormat:@"Exported from %@", [self effectivePackName]];
    manifest[@"files"] = files;
    manifest[@"dependencies"] = [self modrinthDependencies];

    [self writeArchiveWithManifest:manifest metadataName:@"modrinth.index.json" extension:@"mrpack"];
}

- (NSDictionary *)modrinthDependencies {
    NSMutableDictionary *deps = [NSMutableDictionary dictionary];
    if (self.mcVersion.length > 0) deps[@"minecraft"] = self.mcVersion;
    NSString *loaderKey = MPLoaderKeyForType(self.loaderType);
    if (loaderKey.length > 0 && self.loaderVersion.length > 0) {
        deps[loaderKey] = self.loaderVersion;
    }
    return deps;
}

#pragma mark - CurseForge

- (void)beginCurseForgeLookup {
    if (self.entries.count == 0 || ![CurseForgeService.shared isConfigured]) {
        [self finishCurseForgeManifest];
        return;
    }

    NSMutableDictionary<NSString *, NSMutableArray<NSMutableDictionary *> *> *byProject = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *projectOrder = [NSMutableArray array];
    NSDictionary<NSString *, NSDictionary *> *manifestIndex = [self curseForgeManifestIndex];

    for (NSMutableDictionary *entry in self.entries) {
        NSString *indexKey = [NSString stringWithFormat:@"%@|%@", entry[@"category"], entry[@"filename"]];
        NSDictionary *info = manifestIndex[indexKey];
        NSString *source = [info[@"source"] isKindOfClass:[NSString class]] ? [info[@"source"] lowercaseString] : @"";
        if (source.length > 0 && ![source isEqualToString:@"curseforge"] && ![source isEqualToString:@"cf"]) continue;
        id projectValue = info[@"project_id"];
        NSString *projectID = [projectValue isKindOfClass:[NSString class]] ? projectValue
                            : ([projectValue isKindOfClass:[NSNumber class]] ? [projectValue stringValue] : nil);
        if (projectID.length == 0) continue;

        BOOL numeric = YES;
        for (NSUInteger i = 0; i < projectID.length; i++) {
            unichar c = [projectID characterAtIndex:i];
            if (c < '0' || c > '9') { numeric = NO; break; }
        }
        if (!numeric) continue;

        entry[@"cfProjectID"] = projectID;
        if (!byProject[projectID]) {
            byProject[projectID] = [NSMutableArray array];
            [projectOrder addObject:projectID];
        }
        [byProject[projectID] addObject:entry];
    }

    self.curseForgeByProject = byProject;
    [self processCurseForgeProjectOrder:projectOrder index:0];
}

- (NSDictionary<NSString *, NSDictionary *> *)curseForgeManifestIndex {
    NSMutableDictionary<NSString *, NSDictionary *> *index = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary *> *profiles = [NSMutableArray arrayWithObject:self.profile ?: @{}];
    if (self.mcVersion.length > 0 && ![self.mcVersion isEqualToString:self.versionKey]) {
        [profiles addObject:@{@"lastVersionId": self.mcVersion}];
    }

    for (NSString *category in @[InstalledItemCategoryMod, InstalledItemCategoryResourcePack, InstalledItemCategoryShaderPack]) {
        for (NSDictionary *profile in profiles) {
            NSArray<NSDictionary *> *items = [[InstalledModsManager shared] allInstalledForCategory:category profile:profile];
            for (NSDictionary *item in items) {
                NSString *filename = [item[@"filename"] isKindOfClass:[NSString class]] ? item[@"filename"] : nil;
                if (filename.length == 0) continue;
                NSString *key = [NSString stringWithFormat:@"%@|%@", category, filename];
                if (!index[key]) index[key] = item;
            }
        }
    }
    return index;
}

- (void)processCurseForgeProjectOrder:(NSArray<NSString *> *)projectOrder index:(NSUInteger)index {
    if (index >= projectOrder.count) {
        [self finishCurseForgeManifest];
        return;
    }

    NSString *projectID = projectOrder[index];
    double fraction = 0.30 + 0.25 * ((double)index / (double)MAX((NSUInteger)1, projectOrder.count));
    [self report:fraction message:localize(@"modpack.export_lookup_cf", nil)];

    [CurseForgeService.shared loadProjectVersions:projectID completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error) {
            self.curseForgeFailureCount += 1;
            if (MPIsConnectivityError(error) || self.curseForgeFailureCount >= 3) {
                [self finishCurseForgeManifest];
                return;
            }
        } else {
            self.curseForgeFailureCount = 0;
        }
        if ([versions isKindOfClass:[NSArray class]] && versions.count > 0) {
            NSMutableDictionary<NSString *, NSDictionary *> *byFilename = [NSMutableDictionary dictionary];
            for (NSDictionary *version in versions) {
                NSString *filename = [version[@"filename"] isKindOfClass:[NSString class]] ? version[@"filename"] : nil;
                if (filename.length > 0 && !byFilename[filename]) byFilename[filename] = version;
            }
            for (NSMutableDictionary *entry in self.curseForgeByProject[projectID]) {
                NSString *filename = entry[@"filename"];
                NSNumber *entrySize = [entry[@"size"] isKindOfClass:[NSNumber class]] ? entry[@"size"] : nil;
                NSDictionary *version = nil;
                NSDictionary *sameName = nil;
                for (NSDictionary *candidate in versions) {
                    NSString *candidateName = [candidate[@"filename"] isKindOfClass:[NSString class]] ? candidate[@"filename"] : nil;
                    if (![candidateName isEqualToString:filename]) continue;
                    if (!sameName) sameName = candidate;
                    NSNumber *candidateSize = [candidate[@"size"] isKindOfClass:[NSNumber class]] ? candidate[@"size"] : nil;
                    if (entrySize.longLongValue > 0 && candidateSize.longLongValue == entrySize.longLongValue) {
                        version = candidate;
                        break;
                    }
                }
                if (!version) version = sameName;
                if (!version) {
                    for (NSString *candidateName in byFilename) {
                        if ([candidateName caseInsensitiveCompare:filename] == NSOrderedSame) {
                            version = byFilename[candidateName];
                            break;
                        }
                    }
                }
                NSNumber *fileID = [version[@"_cfFileId"] isKindOfClass:[NSNumber class]] ? version[@"_cfFileId"] : nil;
                if (fileID && fileID.longLongValue > 0) entry[@"cfFileID"] = fileID;
            }
        }
        [self processCurseForgeProjectOrder:projectOrder index:index + 1];
    }];
}

- (void)finishCurseForgeManifest {
    NSMutableArray<NSDictionary *> *files = [NSMutableArray arrayWithCapacity:self.entries.count];
    for (NSDictionary *entry in self.entries) {
        NSNumber *fileID = entry[@"cfFileID"];
        NSString *projectID = entry[@"cfProjectID"];
        if (fileID && projectID.length > 0) {
            [files addObject:@{
                @"projectID": @([projectID longLongValue]),
                @"fileID": fileID,
                @"required": @YES,
            }];
        } else {
            [self addEntryToOverrides:entry];
        }
    }

    NSMutableDictionary *minecraft = [NSMutableDictionary dictionary];
    minecraft[@"version"] = self.mcVersion ?: @"";
    NSMutableArray *modLoaders = [NSMutableArray array];
    NSString *loaderKey = MPLoaderKeyForType(self.loaderType);
    if (loaderKey.length > 0 && self.loaderVersion.length > 0) {
        NSString *prefix = [loaderKey isEqualToString:@"fabric-loader"] ? @"fabric"
                          : ([loaderKey isEqualToString:@"quilt-loader"] ? @"quilt" : loaderKey);
        [modLoaders addObject:@{
            @"id": [NSString stringWithFormat:@"%@-%@", prefix, self.loaderVersion],
            @"primary": @YES,
        }];
    }
    minecraft[@"modLoaders"] = modLoaders;

    NSMutableDictionary *manifest = [NSMutableDictionary dictionary];
    manifest[@"minecraft"] = minecraft;
    manifest[@"manifestType"] = @"minecraftModpack";
    manifest[@"manifestVersion"] = @1;
    manifest[@"name"] = [self effectivePackName];
    manifest[@"version"] = [self effectivePackVersion];
    NSString *author = [self.packAuthor stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    manifest[@"author"] = author.length > 0 ? author : @"Unknown";
    manifest[@"files"] = files;
    if (self.overrides.count > 0) manifest[@"overrides"] = @"overrides";

    [self writeArchiveWithManifest:manifest metadataName:@"manifest.json" extension:@"zip"];
}

#pragma mark - Archive

- (void)addEntryToOverrides:(NSDictionary *)entry {
    NSString *path = entry[@"relativePath"];
    if (path.length == 0 || [self.overridePaths containsObject:path]) return;
    [self.overridePaths addObject:path];
    [self.overrides addObject:@{@"source": entry[@"sourcePath"], @"path": path}];
}

- (NSString *)effectivePackName {
    NSString *name = [self.packName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length > 0) return name;
    NSString *profileName = [self.profile[@"name"] isKindOfClass:[NSString class]] ? self.profile[@"name"] : nil;
    return profileName.length > 0 ? profileName : @"Modpack";
}

- (NSString *)effectivePackVersion {
    NSString *version = [self.packVersion stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return version.length > 0 ? version : @"1.0.0";
}

- (void)writeArchiveWithManifest:(NSDictionary *)manifest metadataName:(NSString *)metadataName extension:(NSString *)extension {
    [self report:0.58 message:[NSString stringWithFormat:localize(@"modpack.export_writing", nil), (unsigned long)self.overrides.count]];

    NSError *jsonError = nil;
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest
                                                           options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                             error:&jsonError];
    if (!manifestData) {
        [self finishWithPath:nil error:jsonError ?: MPExportError(localize(@"modpack.export_failed", nil))];
        return;
    }

    NSArray<NSDictionary *> *overrides = [self.overrides copy];
    NSString *baseName = MPSafeExportBaseName([self effectivePackName], [self effectivePackVersion]);
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *exportDir = [docs stringByAppendingPathComponent:@"ExportedModpacks"];
    NSString *archivePath = [exportDir stringByAppendingPathComponent:[baseName stringByAppendingPathExtension:extension]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *fileError = nil;
        if (![fm createDirectoryAtPath:exportDir withIntermediateDirectories:YES attributes:nil error:&fileError]) {
            [self finishWithPath:nil error:fileError];
            return;
        }
        [[NSURL fileURLWithPath:exportDir isDirectory:YES] setResourceValue:@YES
                                                                   forKey:NSURLIsExcludedFromBackupKey
                                                                    error:nil];
        if ([fm fileExistsAtPath:archivePath]) {
            NSError *removeError = nil;
            if (![fm removeItemAtPath:archivePath error:&removeError]) {
                [self finishWithPath:nil error:removeError];
                return;
            }
        }

        NSError *archiveError = nil;
        UZKArchive *archive = [[UZKArchive alloc] initWithPath:archivePath error:&archiveError];
        if (!archive || archiveError) {
            [fm removeItemAtPath:archivePath error:nil];
            [self finishWithPath:nil error:archiveError ?: MPExportError(localize(@"modpack.export_failed", nil))];
            return;
        }

        NSError *writeError = nil;
        BOOL ok = [archive writeData:manifestData
                            filePath:metadataName
                            fileDate:[NSDate date]
                   compressionMethod:UZKCompressionMethodDefault
                            password:nil
                           overwrite:NO
                               error:&writeError];
        if (!ok) {
            [fm removeItemAtPath:archivePath error:nil];
            [self finishWithPath:nil error:writeError ?: MPExportError(localize(@"modpack.export_failed", nil))];
            return;
        }

        NSUInteger total = overrides.count;
        for (NSUInteger i = 0; i < total; i++) {
            NSDictionary *file = overrides[i];
            NSString *source = file[@"source"];
            NSString *path = [@"overrides" stringByAppendingPathComponent:file[@"path"]];
            NSError *entryError = nil;
            if (![self writeFile:source toArchive:archive atPath:path error:&entryError]) {
                [fm removeItemAtPath:archivePath error:nil];
                [self finishWithPath:nil error:entryError ?: MPExportError(localize(@"modpack.export_failed", nil))];
                return;
            }
            double fraction = total > 0 ? 0.60 + 0.35 * ((double)(i + 1) / (double)total) : 0.95;
            [self report:fraction message:[NSString stringWithFormat:localize(@"modpack.export_writing", nil), (unsigned long)total]];
        }

        [self report:1.0 message:localize(@"modpack.export_done", nil)];
        [self finishWithPath:archivePath error:nil];
    });
}

- (BOOL)writeFile:(NSString *)source toArchive:(UZKArchive *)archive atPath:(NSString *)path error:(NSError **)error {
    NSString *extension = source.pathExtension.lowercaseString;
    UZKCompressionMethod method = ([extension isEqualToString:@"jar"] || [extension isEqualToString:@"zip"])
        ? UZKCompressionMethodNone
        : UZKCompressionMethodDefault;

    return [archive writeIntoBuffer:path
                           fileDate:[NSDate date]
                  compressionMethod:method
                          overwrite:NO
                              error:error
                              block:^BOOL(BOOL (^writeData)(const void *, unsigned int), NSError *__autoreleasing *actionError) {
        NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:source];
        if (!stream) {
            if (actionError) *actionError = MPExportError([NSString stringWithFormat:@"Could not read %@", source.lastPathComponent]);
            return NO;
        }
        [stream open];
        if (stream.streamError) {
            if (actionError) *actionError = stream.streamError;
            [stream close];
            return NO;
        }

        uint8_t buffer[64 * 1024];
        BOOL ok = YES;
        while (YES) {
            NSInteger read = [stream read:buffer maxLength:sizeof(buffer)];
            if (read < 0) {
                if (actionError) *actionError = stream.streamError ?: MPExportError(@"Could not read file.");
                ok = NO;
                break;
            }
            if (read == 0) break;
            if (!writeData(buffer, (unsigned int)read)) {
                if (actionError) *actionError = MPExportError(@"Could not write file into the archive.");
                ok = NO;
                break;
            }
        }
        [stream close];
        return ok;
    }];
}

@end
