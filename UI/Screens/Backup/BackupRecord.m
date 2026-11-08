#import "BackupRecord.h"
#import "BackupConfig.h"
#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

@implementation BackupRecord

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
        _createdAt = [NSDate date];
        _roots = @[];
        _uploads = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self || ![dictionary isKindOfClass:[NSDictionary class]]) return self;

    if ([dictionary[@"id"] isKindOfClass:[NSString class]]) _identifier = dictionary[@"id"];
    if ([dictionary[@"fileName"] isKindOfClass:[NSString class]]) _fileName = dictionary[@"fileName"];
    if ([dictionary[@"localPath"] isKindOfClass:[NSString class]]) _localPath = dictionary[@"localPath"];
    if ([dictionary[@"reason"] isKindOfClass:[NSString class]]) _reason = dictionary[@"reason"];
    if ([dictionary[@"version"] isKindOfClass:[NSString class]]) _version = dictionary[@"version"];
    if ([dictionary[@"instance"] isKindOfClass:[NSString class]]) _instance = dictionary[@"instance"];
    if ([dictionary[@"roots"] isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *roots = [NSMutableArray array];
        for (id root in dictionary[@"roots"]) {
            if ([root isKindOfClass:[NSString class]] && [BackupScope isSafeRelativePath:root]) {
                [roots addObject:root];
            }
        }
        _roots = roots;
    }
    if ([dictionary[@"size"] respondsToSelector:@selector(unsignedLongLongValue)]) _size = [dictionary[@"size"] unsignedLongLongValue];
    if ([dictionary[@"fileCount"] respondsToSelector:@selector(unsignedIntegerValue)]) _fileCount = [dictionary[@"fileCount"] unsignedIntegerValue];

    id created = dictionary[@"createdAt"];
    if ([created isKindOfClass:[NSNumber class]]) {
        _createdAt = [NSDate dateWithTimeIntervalSince1970:[created doubleValue]];
    } else if ([created isKindOfClass:[NSString class]]) {
        static NSISO8601DateFormatter *formatter;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
        });
        _createdAt = [formatter dateFromString:created] ?: [NSDate date];
    }

    if ([dictionary[@"uploads"] isKindOfClass:[NSDictionary class]]) {
        _uploads = [dictionary[@"uploads"] mutableCopy];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
    });
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.identifier ?: NSUUID.UUID.UUIDString;
    dict[@"fileName"] = self.fileName ?: @"";
    dict[@"localPath"] = self.localPath ?: @"";
    dict[@"createdAt"] = [formatter stringFromDate:self.createdAt ?: [NSDate date]];
    dict[@"size"] = @(self.size);
    dict[@"fileCount"] = @(self.fileCount);
    dict[@"reason"] = self.reason ?: @"manual";
    dict[@"version"] = self.version ?: @"";
    dict[@"instance"] = self.instance ?: @"";
    dict[@"roots"] = self.roots ?: @[];
    dict[@"uploads"] = self.uploads ?: @{};
    return dict;
}

- (NSString *)reasonTitle {
    NSString *reason = self.reason ?: @"manual";
    if ([reason isEqualToString:@"launch"]) return localize(@"Before launch", nil);
    if ([reason isEqualToString:@"exit"]) return localize(@"After game exit", nil);
    if ([reason isEqualToString:@"open"]) return localize(@"App opened", nil);
    if ([reason isEqualToString:@"schedule"]) return localize(@"Scheduled", nil);
    return localize(@"Manual", nil);
}

- (NSInteger)successfulUploadCount {
    NSInteger count = 0;
    for (NSDictionary *state in self.uploads.allValues) {
        if ([state[@"status"] isEqualToString:@"done"]) count++;
    }
    return count;
}

- (BOOL)hasRemoteCopy {
    if (self.successfulUploadCount > 0) return YES;
    return NO;
}

- (NSString *)destinationSummary {
    if (self.uploads.count == 0) return localize(@"This device only", nil);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSDictionary<NSString *, NSString *> *labels = @{
        @"folder": localize(@"Cloud folder", nil),
        @"webdav": @"WebDAV",
        @"gdrive": @"Google Drive",
        @"onedrive": @"OneDrive",
        @"dropbox": @"Dropbox",
    };
    for (NSString *key in self.uploads) {
        NSDictionary *state = self.uploads[key];
        if ([state[@"status"] isEqualToString:@"done"]) {
            [names addObject:labels[key] ?: key];
        }
    }
    if (names.count == 0) return localize(@"Upload failed", nil);
    return [names componentsJoinedByString:@", "];
}

@end

@implementation BackupScope

+ (NSArray<NSString *> *)defaultRoots {
    return @[
        @"saves",
        @"config",
        @"mods",
        @"resourcepacks",
        @"shaderpacks",
        @"options.txt",
        @"servers.dat",
        @"servers.dat_old",
        @"usercache.json",
    ];
}

+ (NSArray<NSString *> *)selectableRootsAtVersionPath:(NSString *)versionPath {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:versionPath error:nil] ?: @[];
    for (NSString *name in [entries sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        if ([name hasPrefix:@"."]) continue;
        if ([self isInternalRoot:name]) continue;
        NSString *full = [versionPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:full isDirectory:&isDir]) {
            [result addObject:name];
        }
    }
    return result;
}

+ (BOOL)isSafeRelativePath:(NSString *)path {
    if (path.length == 0) return NO;
    if ([path hasPrefix:@"/"] || [path containsString:@"\\"]) return NO;
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if (part.length == 0 || [part isEqualToString:@"."] || [part isEqualToString:@".."]) return NO;
    }
    return YES;
}

+ (BOOL)isInternalRoot:(NSString *)path {
    static NSSet<NSString *> *internal;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        internal = [NSSet setWithArray:@[
            @"logs", @"crash-reports", @"debug", @"natives", @"libraries", @"assets",
            @"versions", @".git", @"__MACOSX", @"backups", @".amethyst",
        ]];
    });
    if (path.length == 0) return NO;
    NSString *first = [[path componentsSeparatedByString:@"/"] firstObject];
    return [internal containsObject:first];
}

+ (instancetype)scopeForVersion:(NSString *)version roots:(NSArray<NSString *> *)roots {
    BackupScope *scope = [[BackupScope alloc] init];
    scope.version = version ?: VersionDirectoryManager.shared.currentVersion ?: @"";
    scope.instance = VersionDirectoryManager.shared.currentInstance ?: @"";
    scope.versionPath = scope.version.length > 0 ? [VersionDirectoryManager.shared versionPathForVersion:scope.version] : @"";

    NSArray *candidates = roots;
    if (candidates.count == 0) {
        id saved = getPrefObject(@"backup.scope_paths");
        candidates = [saved isKindOfClass:[NSArray class]] ? saved : [self defaultRoots];
    }
    NSMutableArray<NSString *> *safeRoots = [NSMutableArray array];
    for (id root in candidates) {
        if (![root isKindOfClass:[NSString class]]) continue;
        if (![self isSafeRelativePath:root] || [self isInternalRoot:root]) continue;
        [safeRoots addObject:root];
    }
    scope.roots = safeRoots.count > 0 ? safeRoots : [self defaultRoots];
    return scope;
}

- (BOOL)isValid {
    if (self.versionPath.length == 0 || self.roots.count == 0) return NO;
    for (NSString *root in self.roots) {
        if (![BackupScope isSafeRelativePath:root] || [BackupScope isInternalRoot:root]) return NO;
    }
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:self.versionPath isDirectory:&isDir] && isDir;
}

@end
