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

- (NSString *)versionKeyForProfile:(NSDictionary *)profile {
    id lastVersion = profile[@"lastVersionId"];
    if ([lastVersion isKindOfClass:[NSString class]] && [(NSString *)lastVersion length] > 0) {
        return lastVersion;
    }
    return [self versionKeyForCurrentProfile];
}

- (NSString *)dirForCategory:(NSString *)category versionKey:(NSString *)ver {
    NSString *v = ([ver isKindOfClass:[NSString class]] && ver.length > 0) ? ver : @"";
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) {
        return [VersionDirectoryManager.shared resourcePacksPathForVersion:v];
    } else if ([category isEqualToString:InstalledItemCategoryShaderPack]) {
        return [VersionDirectoryManager.shared shaderPacksPathForVersion:v];
    }
    return [VersionDirectoryManager.shared modsPathForVersion:v];
}

- (NSString *)modsDirForProfile:(NSDictionary *)profile {
    return [VersionDirectoryManager.shared modsPathForVersion:[self versionKeyForProfile:profile]];
}

- (NSString *)resourcePacksDirForProfile:(NSDictionary *)profile {
    return [VersionDirectoryManager.shared resourcePacksPathForVersion:[self versionKeyForProfile:profile]];
}

- (NSString *)shaderPacksDirForProfile:(NSDictionary *)profile {
    return [VersionDirectoryManager.shared shaderPacksPathForVersion:[self versionKeyForProfile:profile]];
}

- (NSString *)savesDirForCurrentProfile {
    return [VersionDirectoryManager.shared savesPathForVersion:[self versionKeyForCurrentProfile]];
}

- (NSString *)savesDirForProfile:(NSDictionary *)profile {
    return [VersionDirectoryManager.shared savesPathForVersion:[self versionKeyForProfile:profile]];
}

- (NSString *)serversDirForProfile:(NSDictionary *)profile {
    return [VersionDirectoryManager.shared serversPathForVersion:[self versionKeyForProfile:profile]];
}

- (NSString *)dirForCategory:(NSString *)category profile:(NSDictionary *)profile {
    return [self dirForCategory:category versionKey:[self versionKeyForProfile:profile]];
}

- (NSString *)dirForCategory:(NSString *)category {
    return [self dirForCategory:category versionKey:[self versionKeyForCurrentProfile]];
}

- (NSString *)manifestNameForCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return kResourceManifestName;
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return kShaderManifestName;
    return kModsManifestName;
}

- (NSString *)manifestPathForCategory:(NSString *)category versionKey:(NSString *)ver {
    NSString *dir = [self dirForCategory:category versionKey:ver];
    return [dir stringByAppendingPathComponent:[self manifestNameForCategory:category]];
}

- (NSString *)manifestPathForCategory:(NSString *)category profile:(NSDictionary *)profile {
    return [self manifestPathForCategory:category versionKey:[self versionKeyForProfile:profile]];
}

- (NSString *)manifestPathForCategory:(NSString *)category {
    return [self manifestPathForCategory:category versionKey:[self versionKeyForCurrentProfile]];
}

- (NSString *)normalizedCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return InstalledItemCategoryResourcePack;
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return InstalledItemCategoryShaderPack;
    return InstalledItemCategoryMod;
}

#pragma mark - Project-type routing

- (NSString *)categoryForProjectType:(NSString *)projectType {
    if ([projectType isEqualToString:@"shader"]) return InstalledItemCategoryShaderPack;
    if ([projectType isEqualToString:@"resourcepack"]) return InstalledItemCategoryResourcePack;
    return InstalledItemCategoryMod;
}

- (NSString *)extensionForProjectType:(NSString *)projectType {
    if ([projectType isEqualToString:@"shader"] || [projectType isEqualToString:@"resourcepack"]) return @"zip";
    return @"jar";
}

- (NSString *)dirForProjectType:(NSString *)projectType version:(NSString *)version {
    NSString *v = ([version isKindOfClass:[NSString class]] && version.length > 0) ? version : @"";
    if ([projectType isEqualToString:@"shader"]) return [VersionDirectoryManager.shared shaderPacksPathForVersion:v];
    if ([projectType isEqualToString:@"resourcepack"]) return [VersionDirectoryManager.shared resourcePacksPathForVersion:v];
    return [VersionDirectoryManager.shared modsPathForVersion:v];
}

#pragma mark - Manifest IO

- (NSMutableDictionary *)loadManifestAtPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return [NSMutableDictionary dictionary];
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([parsed isKindOfClass:[NSMutableDictionary class]]) return parsed;
    if ([parsed isKindOfClass:[NSDictionary class]]) return [parsed mutableCopy];
    return [NSMutableDictionary dictionary];
}

- (void)saveManifest:(NSDictionary *)manifest atPath:(NSString *)path {
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:path atomically:YES];
}

- (NSMutableDictionary *)loadManifestForCategory:(NSString *)category {
    return [self loadManifestAtPath:[self manifestPathForCategory:category]];
}

- (NSMutableDictionary *)loadManifestForCategory:(NSString *)category profile:(NSDictionary *)profile {
    return [self loadManifestAtPath:[self manifestPathForCategory:category profile:profile]];
}

- (void)saveManifest:(NSDictionary *)manifest forCategory:(NSString *)category {
    [self saveManifest:manifest atPath:[self manifestPathForCategory:category]];
}

- (void)saveManifest:(NSDictionary *)manifest forCategory:(NSString *)category profile:(NSDictionary *)profile {
    [self saveManifest:manifest atPath:[self manifestPathForCategory:category profile:profile]];
}

- (void)postChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:InstalledModsDidChangeNotification object:nil];
}

#pragma mark - Reads

- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category {
    return [self allInstalledForCategory:category profile:nil];
}

- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category profile:(NSDictionary *)profile {
    NSString *cat = [self normalizedCategory:category];
    NSMutableDictionary *m = profile ? [self loadManifestForCategory:cat profile:profile]
                                     : [self loadManifestForCategory:cat];
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
    [self recordProjectId:projectId title:title versionNumber:versionNumber filename:filename
                 iconURL:iconURL source:source category:category mcVersion:mcVersion loader:loader profile:nil];
}

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category
               mcVersion:(NSString *)mcVersion
                  loader:(NSString *)loader
                 profile:(NSDictionary *)profile {
    [self recordProjectId:projectId title:title versionNumber:versionNumber filename:filename
                 iconURL:iconURL source:source category:category mcVersion:mcVersion loader:loader
              projectType:nil profile:profile];
}

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category
               mcVersion:(NSString *)mcVersion
                  loader:(NSString *)loader
             projectType:(NSString *)projectType
                 profile:(NSDictionary *)profile {
    if (projectId.length == 0 || filename.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = profile ? [self loadManifestForCategory:cat profile:profile]
                                         : [self loadManifestForCategory:cat];
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
        if (projectType.length > 0) existing[@"project_type"] = projectType;
        else if (!existing[@"project_type"]) existing[@"project_type"] = @"mod";
        existing[@"installed_at"] = @([[NSDate date] timeIntervalSince1970]);
        m[projectId] = existing;
        if (profile) [self saveManifest:m forCategory:cat profile:profile];
        else [self saveManifest:m forCategory:cat];
    }
    [self postChange];
}

- (void)removeProjectId:(NSString *)projectId category:(NSString *)category {
    [self removeProjectId:projectId category:category profile:nil];
}

- (void)removeProjectId:(NSString *)projectId category:(NSString *)category profile:(NSDictionary *)profile {
    if (projectId.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = profile ? [self loadManifestForCategory:cat profile:profile]
                                         : [self loadManifestForCategory:cat];
        if (m[projectId]) {
            [m removeObjectForKey:projectId];
            if (profile) [self saveManifest:m forCategory:cat profile:profile];
            else [self saveManifest:m forCategory:cat];
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
    [self updateFilename:newFilename forProjectId:projectId category:category profile:nil];
}

- (void)updateFilename:(NSString *)newFilename forProjectId:(NSString *)projectId category:(NSString *)category profile:(NSDictionary *)profile {
    if (projectId.length == 0 || newFilename.length == 0) return;
    @synchronized (self) {
        NSString *cat = [self normalizedCategory:category];
        NSMutableDictionary *m = profile ? [self loadManifestForCategory:cat profile:profile]
                                         : [self loadManifestForCategory:cat];
        NSMutableDictionary *entry = [m[projectId] isKindOfClass:[NSDictionary class]]
            ? [(NSDictionary *)m[projectId] mutableCopy] : nil;
        if (!entry) return;
        entry[@"filename"] = newFilename;
        m[projectId] = entry;
        if (profile) [self saveManifest:m forCategory:cat profile:profile];
        else [self saveManifest:m forCategory:cat];
    }
    [self postChange];
}

#pragma mark - Enable / disable

- (NSString *)baseNameForFilename:(NSString *)filename {
    if ([filename isKindOfClass:[NSString class]] && [filename hasSuffix:@".off"]) {
        return [filename substringToIndex:filename.length - 4];
    }
    return filename;
}

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
    return [self isEnabledForFilename:filename category:category profile:nil];
}

- (BOOL)isEnabledForFilename:(NSString *)filename category:(NSString *)category profile:(NSDictionary *)profile {
    if (filename.length == 0) return YES;
    NSString *dir = profile ? [self dirForCategory:category profile:profile] : [self dirForCategory:category];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [self baseNameForFilename:filename];
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
    return [self setEnabled:enabled forFilename:filename category:category profile:nil];
}

- (BOOL)setEnabled:(BOOL)enabled forFilename:(NSString *)filename category:(NSString *)category profile:(NSDictionary *)profile {
    if (filename.length == 0) return NO;
    NSString *dir = profile ? [self dirForCategory:category profile:profile] : [self dirForCategory:category];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [self baseNameForFilename:filename];
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
    else [self postChange];
    return ok;
}

@end
