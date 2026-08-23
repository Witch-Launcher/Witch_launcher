#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"

NSString * const InstalledModsDidChangeNotification = @"InstalledModsDidChangeNotification";

static NSString * const kManifestName = @"installed_mods.json";

@implementation InstalledModsManager

+ (InstalledModsManager *)shared {
    static InstalledModsManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSString *)modsDirForCurrentProfile {
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    NSString *ver = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion;
    if (ver.length == 0) ver = @"";
    return [VersionDirectoryManager.shared modsPathForVersion:ver];
}

- (NSString *)manifestPath {
    return [[self modsDirForCurrentProfile] stringByAppendingPathComponent:kManifestName];
}

- (NSMutableDictionary *)loadManifest {
    NSString *path = [self manifestPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return [NSMutableDictionary dictionary];
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([parsed isKindOfClass:[NSMutableDictionary class]]) return parsed;
    if ([parsed isKindOfClass:[NSDictionary class]]) return [parsed mutableCopy];
    return [NSMutableDictionary dictionary];
}

- (void)saveManifest:(NSDictionary *)manifest {
    NSString *dir = [self manifestPath].stringByDeletingLastPathComponent;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:[self manifestPath] atomically:YES];
}

- (NSDictionary *)infoForProjectId:(NSString *)projectId {
    if (projectId.length == 0) return nil;
    NSDictionary *m = [self loadManifest];
    NSDictionary *entry = m[projectId];
    return [entry isKindOfClass:[NSDictionary class]] ? entry : nil;
}

- (void)recordProjectId:(NSString *)projectId
                  title:(NSString *)title
          versionNumber:(NSString *)versionNumber
               filename:(NSString *)filename {
    if (projectId.length == 0 || filename.length == 0) return;
    NSMutableDictionary *m = [self loadManifest];
    m[projectId] = @{
        @"title": title ?: @"",
        @"version_number": versionNumber ?: @"",
        @"filename": filename,
        @"installed_at": @([[NSDate date] timeIntervalSince1970])
    }.mutableCopy;
    [self saveManifest:m];
    [[NSNotificationCenter defaultCenter] postNotificationName:InstalledModsDidChangeNotification object:nil];
}

@end
