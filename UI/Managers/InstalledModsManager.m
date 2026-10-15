#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"

NSString * const InstalledModsDidChangeNotification = @"InstalledModsDidChangeNotification";

NSString * const InstalledItemCategoryMod = @"mod";
NSString * const InstalledItemCategoryShaderPack = @"shaderpack";
NSString * const InstalledItemCategoryResourcePack = @"resourcepack";

static NSString * const kModsManifestName = @"installed_mods.json";
static NSString * const kShaderManifestName = @"installed_shaderpacks.json";
static NSString * const kResourceManifestName = @"installed_resourcepacks.json";

@implementation InstalledModsManager

+ (InstalledModsManager *)shared {
    static InstalledModsManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

#pragma mark - Directories

- (NSString *)versionKeyForCurrentProfile {
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    NSString *ver = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion;
    if (ver.length == 0) ver = @"";
    return ver;
}

- (NSString *)modsDirForCurrentProfile {
    return [VersionDirectoryManager.shared modsPathForVersion:[self versionKeyForCurrentProfile]];
}

- (NSString *)resourcePacksDirForCurrentProfile {
    return [VersionDirectoryManager.shared resourcePacksPathForVersion:[self versionKeyForCurrentProfile]];
}

- (NSString *)shaderPacksDirForCurrentProfile {
    return [VersionDirectoryManager.shared shaderPacksPathForVersion:[self versionKeyForCurrentProfile]];
}

- (NSString *)dirForCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) {
        return [self resourcePacksDirForCurrentProfile];
    } else if ([category isEqualToString:InstalledItemCategoryShaderPack]) {
        return [self shaderPacksDirForCurrentProfile];
    }
    return [self modsDirForCurrentProfile];
}

- (NSString *)manifestNameForCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return kResourceManifestName;
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return kShaderManifestName;
    return kModsManifestName;
}

- (NSString *)manifestPathForCategory:(NSString *)category {
    NSString *dir = [self dirForCategory:category];
    return [dir stringByAppendingPathComponent:[self manifestNameForCategory:category]];
}

- (NSString *)normalizedCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return InstalledItemCategoryResourcePack;
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return InstalledItemCategoryShaderPack;
    return InstalledItemCategoryMod;
}

#pragma mark - Manifest IO

- (NSMutableDictionary *)loadManifestForCategory:(NSString *)category {
    NSString *path = [self manifestPathForCategory:category];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return [NSMutableDictionary dictionary];
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([parsed isKindOfClass:[NSMutableDictionary class]]) return parsed;
    if ([parsed isKindOfClass:[NSDictionary class]]) return [parsed mutableCopy];
    return [NSMutableDictionary dictionary];
}

- (void)saveManifest:(NSDictionary *)manifest forCategory:(NSString *)category {
    NSString *path = [self manifestPathForCategory:category];
    NSString *dir = path.stringByDeletingLastPathComponent;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:path atomically:YES];
}

- (void)postChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:InstalledModsDidChangeNotification object:nil];
}

#pragma mark - Reads

- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category {
    NSString *cat = [self normalizedCategory:category];
    NSMutableDictionary *m = [self loadManifestForCategory:cat];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:m.count];
    for (NSString *pid in m) {
        NSDictionary *entry = m[pid];
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSMutableDictionary *item = [entry mutableCopy];
        item[@"project_id"] = pid;
        if (!item[@"category"]) item[@"category"] = cat;
        [out addObject:item];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [[(a[@"title"] ?: a[@"filename"] ?: @"") lowercaseString]
                compare:[(b[@"title"] ?: b[@"filename"] ?: @"") lowercaseString]];
    }];
    return out;
}

- (NSDictionary *)infoForProjectId:(NSString *)projectId {
    return [self infoForProjectId:projectId category:InstalledItemCategoryMod];
}

- (NSDictionary *)infoForProjectId:(NSString *)projectId category:(NSString *)category {
    if (projectId.length == 0) return nil;
    NSString *cat = [self normalizedCategory:category];
    NSDictionary *entry = [self loadManifestForCategory:cat][projectId];
    if (![entry isKindOfClass:[NSDictionary class]]) return nil;
    NSMutableDictionary *item = [entry mutableCopy];
    item[@"project_id"] = projectId;
    if (!item[@"category"]) item[@"category"] = cat;
    return item;
}

- (NSDictionary *)infoForFilename:(NSString *)filename category:(NSString *)category {
    if (filename.length == 0) return nil;
    for (NSDictionary *item in [self allInstalledForCategory:category]) {
        if ([item[@"filename"] isEqualToString:filename]) return item;
    }
    return nil;
}

#pragma mark - Writes

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename {
    [self recordProjectId:projectId title:title versionNumber:versionNumber filename:filename
                 iconURL:nil source:nil category:InstalledItemCategoryMod mcVersion:nil loader:nil];
}

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category {
    [self recordProjectId:projectId title:title versionNumber:versionNumber filename:filename
                 iconURL:iconURL source:source category:category mcVersion:nil loader:nil];
}

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category
               mcVersion:(NSString *)mcVersion
                  loader:(NSString *)loader {
    if (projectId.length == 0 || filename.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = [self loadManifestForCategory:cat];
        NSMutableDictionary *existing = [m[projectId] isKindOfClass:[NSDictionary class]]
            ? [(NSDictionary *)m[projectId] mutableCopy] : [NSMutableDictionary dictionary];
        existing[@"title"] = title ?: existing[@"title"] ?: @"";
        existing[@"version_number"] = versionNumber ?: existing[@"version_number"] ?: @"";
        existing[@"filename"] = filename;
        if (iconURL) existing[@"icon_url"] = iconURL;
        else if (!existing[@"icon_url"]) existing[@"icon_url"] = @"";
        if (source.length > 0) existing[@"source"] = source;
        else if (!existing[@"source"]) existing[@"source"] = @"";
        existing[@"category"] = cat;
        if (mcVersion.length > 0) existing[@"mc_version"] = mcVersion;
        if (loader.length > 0) existing[@"loader"] = loader;
        existing[@"installed_at"] = @([[NSDate date] timeIntervalSince1970]);
        m[projectId] = existing;
        [self saveManifest:m forCategory:cat];
    }
    [self postChange];
}

- (void)removeProjectId:(NSString *)projectId category:(NSString *)category {
    if (projectId.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = [self loadManifestForCategory:cat];
        if (m[projectId]) {
            [m removeObjectForKey:projectId];
            [self saveManifest:m forCategory:cat];
        }
    }
    [self postChange];
}

- (void)removeRecordForFilename:(NSString *)filename category:(NSString *)category {
    if (filename.length == 0) return;
    NSDictionary *info = [self infoForFilename:filename category:category];
    if (info[@"project_id"]) {
        [self removeProjectId:info[@"project_id"] category:category];
    }
}

- (void)updateFilename:(NSString *)newFilename forProjectId:(NSString *)projectId category:(NSString *)category {
    if (projectId.length == 0 || newFilename.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = [self loadManifestForCategory:cat];
        NSMutableDictionary *entry = [m[projectId] isKindOfClass:[NSDictionary class]]
            ? [(NSDictionary *)m[projectId] mutableCopy] : nil;
        if (!entry) return;
        entry[@"filename"] = newFilename;
        m[projectId] = entry;
        [self saveManifest:m forCategory:cat];
    }
    [self postChange];
}

#pragma mark - Enable / disable

- (NSString *)onDiskNameForFilename:(NSString *)filename category:(NSString *)category enabled:(BOOL)enabled {
    // enabled=NO appends .off; enabled=YES strips it
    if (enabled) {
        if ([filename hasSuffix:@".off"]) return [filename substringToIndex:filename.length - 4];
        return filename;
    }
    if ([filename hasSuffix:@".off"]) return filename;
    return [filename stringByAppendingString:@".off"];
}

- (BOOL)isEnabledForFilename:(NSString *)filename category:(NSString *)category {
    if (filename.length == 0) return YES;
    NSString *dir = [self dirForCategory:category];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [filename hasSuffix:@".off"]
        ? [filename substringToIndex:filename.length - 4] : filename;
    NSString *onPath = [dir stringByAppendingPathComponent:base];
    NSString *offPath = [dir stringByAppendingPathComponent:[base stringByAppendingString:@".off"]];
    BOOL isOn = [fm fileExistsAtPath:onPath];
    BOOL isOff = [fm fileExistsAtPath:offPath];
    if (isOn && !isOff) return YES;
    if (isOff && !isOn) return NO;
    // Both or neither: treat as enabled if base file exists or manifest says so
    return YES;
}

- (BOOL)setEnabled:(BOOL)enabled forFilename:(NSString *)filename category:(NSString *)category {
    if (filename.length == 0) return NO;
    NSString *dir = [self dirForCategory:category];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [filename hasSuffix:@".off"]
        ? [filename substringToIndex:filename.length - 4] : filename;
    NSString *onPath = [dir stringByAppendingPathComponent:base];
    NSString *offPath = [dir stringByAppendingPathComponent:[base stringByAppendingString:@".off"]];
    NSError *err = nil;
    BOOL ok = YES;
    if (enabled) {
        if ([fm fileExistsAtPath:offPath] && ![fm fileExistsAtPath:onPath]) {
            ok = [fm moveItemAtPath:offPath toPath:onPath error:&err];
        }
    } else {
        if ([fm fileExistsAtPath:onPath] && ![fm fileExistsAtPath:offPath]) {
            ok = [fm moveItemAtPath:onPath toPath:offPath error:&err];
        }
    }
    if (!ok) NSLog(@"[InstalledMods] setEnabled=%d %@ failed: %@", enabled, filename, err);
    return ok;
}

@end
