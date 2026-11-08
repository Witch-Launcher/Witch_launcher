#import "BackupConfig.h"
#import "utils.h"

#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#endif

#ifndef WITCH_GOOGLE_DRIVE_CLIENT_ID
#define WITCH_GOOGLE_DRIVE_CLIENT_ID @""
#endif
#ifndef WITCH_MS_OAUTH_CLIENT_ID
#define WITCH_MS_OAUTH_CLIENT_ID @""
#endif
#ifndef WITCH_DROPBOX_APP_KEY
#define WITCH_DROPBOX_APP_KEY @""
#endif

@implementation BackupConfig

+ (NSString *)googleClientID {
    return WITCH_GOOGLE_DRIVE_CLIENT_ID ?: @"";
}

+ (NSString *)azureClientID {
    return WITCH_MS_OAUTH_CLIENT_ID ?: @"";
}

+ (NSString *)dropboxAppKey {
    return WITCH_DROPBOX_APP_KEY ?: @"";
}

+ (NSString *)googleRedirectURI {
    NSString *clientID = [self googleClientID];
    if (clientID.length == 0) return @"";
    NSString *identifier = [clientID stringByReplacingOccurrencesOfString:@".apps.googleusercontent.com" withString:@""];
    return [NSString stringWithFormat:@"com.googleusercontent.apps.%@:/oauth2redirect", identifier];
}

+ (NSString *)googleCallbackScheme {
    NSString *redirect = [self googleRedirectURI];
    NSRange range = [redirect rangeOfString:@":"];
    if (range.location == NSNotFound) return @"";
    return [redirect substringToIndex:range.location];
}

+ (NSString *)azureRedirectURI {
    return @"msauth.com.witch.zad626://auth";
}

+ (NSString *)azureCallbackScheme {
    return @"msauth.com.witch.zad626";
}

+ (NSString *)dropboxRedirectURI {
    NSString *appKey = [self dropboxAppKey];
    if (appKey.length == 0) return @"";
    return [NSString stringWithFormat:@"db-%@://oauth/redirect", appKey];
}

+ (NSString *)dropboxCallbackScheme {
    NSString *appKey = [self dropboxAppKey];
    return appKey.length > 0 ? [NSString stringWithFormat:@"db-%@", appKey] : @"";
}

+ (BOOL)googleConfigured {
    return [self googleClientID].length > 0;
}

+ (BOOL)azureConfigured {
    return [self azureClientID].length > 0;
}

+ (BOOL)dropboxConfigured {
    return [self dropboxAppKey].length > 0;
}

+ (NSString *)backupRootPath {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = amethyst_hidden_dir(@"backups");
        if (path.length == 0) {
            path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"witch-backups"];
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return path;
}

+ (NSString *)archiveDirectoryPath {
    NSString *path = [[self backupRootPath] stringByAppendingPathComponent:@"archives"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

+ (NSString *)indexPath {
    return [[self backupRootPath] stringByAppendingPathComponent:@"index.json"];
}

+ (NSString *)temporaryDirectoryPath {
    NSString *path = [[self backupRootPath] stringByAppendingPathComponent:@"tmp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

+ (NSString *)remoteFolderName {
    return @"Witch Backups";
}

+ (NSString *)humanSize:(unsigned long long)bytes {
    if (bytes < 1024ULL) return [NSString stringWithFormat:@"%llu B", bytes];
    double value = (double)bytes;
    NSArray<NSString *> *units = @[@"KB", @"MB", @"GB", @"TB"];
    NSUInteger unit = 0;
    value /= 1024.0;
    while (value >= 1024.0 && unit + 1 < units.count) {
        value /= 1024.0;
        unit++;
    }
    return [NSString stringWithFormat:@"%.1f %@", value, units[unit]];
}

@end
