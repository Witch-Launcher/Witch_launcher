#import "BackupStore.h"
#import "BackupConfig.h"
#import "VersionDirectoryManager.h"
#import "utils.h"
#import "UnzipKit.h"

static NSString *const kBackupManifestName = @"witch-backup.json";
static NSString *const kBackupErrorDomain = @"WitchBackupErrorDomain";

static NSError *BackupError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:kBackupErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Backup error"}];
}

static BOOL BackupExcludedRelativePath(NSString *relativePath) {
    if (relativePath.length == 0) return YES;
    NSArray<NSString *> *parts = [relativePath componentsSeparatedByString:@"/"];
    if (parts.count > 0 && [BackupScope isInternalRoot:parts.firstObject]) return YES;
    NSString *last = parts.lastObject;
    if ([last isEqualToString:@".DS_Store"] || [last isEqualToString:@"session.lock"]) return YES;
    if ([last.pathExtension.lowercaseString isEqualToString:@"lock"]) return YES;
    return NO;
}

static NSString *BackupISO8601Now(void) {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
    });
    return [formatter stringFromDate:[NSDate date]];
}

@interface BackupStore ()
@property (nonatomic, strong) NSMutableArray<BackupRecord *> *mutableRecords;
@property (nonatomic, strong) NSDateFormatter *fileDateFormatter;
@end

@implementation BackupStore

+ (BackupStore *)shared {
    static BackupStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[BackupStore alloc] init];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableRecords = [NSMutableArray array];
        _fileDateFormatter = [[NSDateFormatter alloc] init];
        _fileDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _fileDateFormatter.dateFormat = @"yyyyMMdd-HHmmss";
        [self reloadRecords];
    }
    return self;
}

#pragma mark - Index

- (NSArray<BackupRecord *> *)records {
    @synchronized (self) {
        return [self.mutableRecords sortedArrayUsingComparator:^NSComparisonResult(BackupRecord *a, BackupRecord *b) {
            return [b.createdAt compare:a.createdAt];
        }];
    }
}

- (void)reloadRecords {
    @synchronized (self) {
        [self.mutableRecords removeAllObjects];
        NSData *data = [NSData dataWithContentsOfFile:[BackupConfig indexPath]];
        if (data.length > 0) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *items = nil;
            if ([json isKindOfClass:[NSDictionary class]]) items = json[@"records"];
            else if ([json isKindOfClass:[NSArray class]]) items = json;
            if ([items isKindOfClass:[NSArray class]]) {
                for (NSDictionary *dict in items) {
                    if (![dict isKindOfClass:[NSDictionary class]]) continue;
                    BackupRecord *record = [[BackupRecord alloc] initWithDictionary:dict];
                    if (record.fileName.length == 0) continue;
                    [self.mutableRecords addObject:record];
                }
            }
        }
        [self pruneMissingArchives];
    }
}

- (void)pruneMissingArchives {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *keep = [NSMutableArray array];
    for (BackupRecord *record in self.mutableRecords) {
        BOOL hasLocal = record.localPath.length > 0 && [fm fileExistsAtPath:record.localPath];
        if (hasLocal || record.hasRemoteCopy) {
            if (!hasLocal) record.localPath = @"";
            [keep addObject:record];
        }
    }
    if (keep.count != self.mutableRecords.count) {
        self.mutableRecords = keep;
        [self saveRecords];
    }
}

- (void)saveRecords {
    @synchronized (self) {
        NSArray<BackupRecord *> *snapshot = [self.mutableRecords copy];
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:snapshot.count];
        for (BackupRecord *record in snapshot) {
            [items addObject:[record dictionaryRepresentation]];
        }
        NSDictionary *payload = @{@"format": @1, @"records": items};
        NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[BackupConfig indexPath] atomically:YES];
    }
}

- (void)addRecord:(BackupRecord *)record {
    if (!record) return;
    @synchronized (self) {
        [self.mutableRecords addObject:record];
    }
    [self saveRecords];
}

- (void)updateRecord:(BackupRecord *)record {
    if (!record) return;
    [self saveRecords];
}

- (void)removeRecord:(BackupRecord *)record deleteArchive:(BOOL)deleteArchive {
    if (!record) return;
    @synchronized (self) {
        [self.mutableRecords removeObjectIdenticalTo:record];
    }
    if (deleteArchive && record.localPath.length > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:record.localPath error:nil];
    }
    [self saveRecords];
}

- (void)removeAllRecords {
    NSArray<BackupRecord *> *snapshot = [self records];
    for (BackupRecord *record in snapshot) {
        if (record.localPath.length > 0) {
            [[NSFileManager defaultManager] removeItemAtPath:record.localPath error:nil];
        }
    }
    @synchronized (self) {
        [self.mutableRecords removeAllObjects];
    }
    [self saveRecords];
}

- (void)removeAllLocalArchives {
    NSArray<BackupRecord *> *snapshot = [self records];
    NSMutableArray<BackupRecord *> *keep = [NSMutableArray array];
    for (BackupRecord *record in snapshot) {
        if (record.localPath.length > 0) {
            [[NSFileManager defaultManager] removeItemAtPath:record.localPath error:nil];
            record.localPath = @"";
        }
        if (record.hasRemoteCopy) [keep addObject:record];
    }
    @synchronized (self) {
        self.mutableRecords = keep;
    }
    [self saveRecords];
}

- (unsigned long long)totalArchiveBytes {
    unsigned long long total = 0;
    for (BackupRecord *record in [self records]) {
        if (record.localPath.length > 0) total += record.size;
    }
    return total;
}

#pragma mark - Archive creation

- (nullable BackupRecord *)createArchiveForScope:(BackupScope *)scope
                                          reason:(NSString *)reason
                                        progress:(BackupProgressBlock)progress
                                           error:(NSError **)error {
    if (![scope isValid]) {
        if (error) *error = BackupError(1, localize(@"This version folder does not exist.", nil));
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSDictionary *> *files = [NSMutableArray array];
    unsigned long long totalBytes = 0;

    for (NSString *root in scope.roots) {
        if (![BackupScope isSafeRelativePath:root]) continue;
        NSString *fullRoot = [scope.versionPath stringByAppendingPathComponent:root];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:fullRoot isDirectory:&isDir]) continue;
        if (!isDir) {
            NSString *rel = root;
            if (BackupExcludedRelativePath(rel)) continue;
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullRoot error:nil];
            unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
            [files addObject:@{@"full": fullRoot, @"rel": rel, @"size": @(size), @"date": attrs[NSFileModificationDate] ?: [NSDate date]}];
            totalBytes += size;
            continue;
        }

        NSDirectoryEnumerator<NSString *> *enumerator = [fm enumeratorAtPath:fullRoot];
        for (NSString *relative in enumerator) {
            @autoreleasepool {
                NSDictionary *attrs = enumerator.fileAttributes;
                NSString *type = attrs[NSFileType];
                if ([type isEqualToString:NSFileTypeDirectory]) continue;
                if ([type isEqualToString:NSFileTypeSymbolicLink]) {
                    [enumerator skipDescendants];
                    continue;
                }
                NSString *rel = [root stringByAppendingPathComponent:relative];
                if (BackupExcludedRelativePath(rel)) continue;
                NSString *full = [fullRoot stringByAppendingPathComponent:relative];
                unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
                [files addObject:@{@"full": full, @"rel": rel, @"size": @(size), @"date": attrs[NSFileModificationDate] ?: [NSDate date]}];
                totalBytes += size;
            }
        }
    }

    if (files.count == 0) {
        if (error) *error = BackupError(2, localize(@"There are no selected files to back up.", nil));
        return nil;
    }

    NSString *identifier = NSUUID.UUID.UUIDString;
    NSString *stamp = [self.fileDateFormatter stringFromDate:[NSDate date]];
    NSString *fileName = [NSString stringWithFormat:@"Witch-%@-%@.zip", stamp, [identifier substringToIndex:8]];
    NSString *archivePath = [[BackupConfig archiveDirectoryPath] stringByAppendingPathComponent:fileName];
    [fm removeItemAtPath:archivePath error:nil];

    if (progress) progress(0.01, localize(@"Preparing backup...", nil));

    UZKArchive *archive = [[UZKArchive alloc] initWithPath:archivePath error:error];
    if (!archive) return nil;

    NSDictionary *manifest = @{
        @"format": @1,
        @"id": identifier,
        @"createdAt": BackupISO8601Now(),
        @"reason": reason ?: @"manual",
        @"version": scope.version ?: @"",
        @"instance": scope.instance ?: @"",
        @"roots": scope.roots ?: @[],
        @"fileCount": @(files.count),
        @"totalBytes": @(totalBytes),
        @"app": @"Witch iOS",
    };
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil];
    NSError *manifestError = nil;
    if (![archive writeData:manifestData filePath:kBackupManifestName fileDate:[NSDate date] error:&manifestError]) {
        if (error) *error = manifestError ?: BackupError(3, localize(@"Could not write the archive.", nil));
        [fm removeItemAtPath:archivePath error:nil];
        return nil;
    }

    __block unsigned long long processed = 0;
    NSUInteger index = 0;
    for (NSDictionary *item in files) {
        @autoreleasepool {
            NSString *full = item[@"full"];
            NSString *rel = item[@"rel"];
            NSDate *date = item[@"date"];
            NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:full];
            if (!handle) continue;

            __block NSError *writeError = nil;
            BOOL ok = [archive writeIntoBuffer:rel fileDate:date error:&writeError block:^BOOL(BOOL (^writeData)(const void *, unsigned int), NSError **actionError) {
                while (YES) {
                    @autoreleasepool {
                        NSData *chunk = [handle readDataOfLength:256 * 1024];
                        if (chunk.length == 0) break;
                        if (!writeData(chunk.bytes, (unsigned int)chunk.length)) {
                            if (actionError) *actionError = writeError ?: BackupError(3, localize(@"Could not write the archive.", nil));
                            return NO;
                        }
                        processed += chunk.length;
                    }
                }
                return YES;
            }];
            [handle closeFile];

            if (!ok) {
                if (error && !*error) {
                    *error = writeError ?: BackupError(3, localize(@"Could not write the archive.", nil));
                }
                [fm removeItemAtPath:archivePath error:nil];
                return nil;
            }

            index++;
            if (progress && totalBytes > 0) {
                double fraction = 0.02 + 0.93 * ((double)processed / (double)totalBytes);
                progress(MIN(fraction, 0.95), [NSString stringWithFormat:localize(@"Compressing %lu/%lu...", nil), (unsigned long)index, (unsigned long)files.count]);
            }
        }
    }

    NSDictionary *attrs = [fm attributesOfItemAtPath:archivePath error:nil];
    unsigned long long archiveSize = [attrs[NSFileSize] unsignedLongLongValue];

    BackupRecord *record = [[BackupRecord alloc] init];
    record.identifier = identifier;
    record.fileName = fileName;
    record.localPath = archivePath;
    record.createdAt = [NSDate date];
    record.size = archiveSize;
    record.fileCount = files.count;
    record.reason = reason ?: @"manual";
    record.version = scope.version ?: @"";
    record.instance = scope.instance ?: @"";
    record.roots = scope.roots ?: @[];
    record.uploads = [NSMutableDictionary dictionary];

    if (progress) progress(1.0, localize(@"Backup complete", nil));
    return record;
}

#pragma mark - Restore

- (BOOL)restoreRecord:(BackupRecord *)record
             overwrite:(BOOL)overwrite
              progress:(BackupProgressBlock)progress
                 error:(NSError **)error {
    if (!record || record.localPath.length == 0) {
        if (error) *error = BackupError(10, localize(@"Backup file not found.", nil));
        return NO;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:record.localPath]) {
        if (error) *error = BackupError(11, localize(@"Backup file is missing on this device.", nil));
        return NO;
    }

    NSString *temp = [[BackupConfig temporaryDirectoryPath] stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [fm createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:nil];
    if (progress) progress(0.02, localize(@"Opening backup...", nil));

    UZKArchive *archive = [[UZKArchive alloc] initWithPath:record.localPath error:error];
    if (!archive) {
        if (error && !*error) *error = BackupError(15, localize(@"Could not read the backup file.", nil));
        [fm removeItemAtPath:temp error:nil];
        return NO;
    }

    NSArray<NSString *> *names = [archive listFilenames:error];
    if (!names) {
        if (error && !*error) *error = BackupError(16, localize(@"Could not read the backup file.", nil));
        [fm removeItemAtPath:temp error:nil];
        return NO;
    }
    for (NSString *name in names) {
        if ([name hasPrefix:@"/"] || [name containsString:@".."] || [name containsString:@"\\"]) {
            if (error) *error = BackupError(12, localize(@"The backup contains an unsafe path.", nil));
            [fm removeItemAtPath:temp error:nil];
            return NO;
        }
    }

    if (progress) progress(0.10, localize(@"Extracting backup...", nil));
    if (![archive extractFilesTo:temp overwrite:YES error:error]) {
        if (error && !*error) *error = BackupError(17, localize(@"Could not extract the backup.", nil));
        [fm removeItemAtPath:temp error:nil];
        return NO;
    }

    NSString *version = record.version.length > 0 ? record.version : VersionDirectoryManager.shared.currentVersion;
    if (version.length == 0) {
        if (error) *error = BackupError(13, localize(@"No version selected for restore.", nil));
        [fm removeItemAtPath:temp error:nil];
        return NO;
    }
    NSString *versionPath = [VersionDirectoryManager.shared versionPathForVersion:version];
    if (![fm fileExistsAtPath:versionPath]) {
        if (error) *error = BackupError(14, localize(@"The target version folder does not exist.", nil));
        [fm removeItemAtPath:temp error:nil];
        return NO;
    }

    NSArray<NSString *> *roots = record.roots.count > 0 ? record.roots : [BackupScope defaultRoots];
    NSUInteger rootIndex = 0;
    NSUInteger restoredRoots = 0;
    for (NSString *root in roots) {
        if (![BackupScope isSafeRelativePath:root]) {
            if (error) *error = BackupError(12, localize(@"The backup contains an unsafe path.", nil));
            [fm removeItemAtPath:temp error:nil];
            return NO;
        }
        @autoreleasepool {
            NSString *source = [temp stringByAppendingPathComponent:root];
            if (![fm fileExistsAtPath:source]) continue;
            NSString *destination = [versionPath stringByAppendingPathComponent:root];
            [fm createDirectoryAtPath:[destination stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
            BOOL isDir = NO;
            if (!overwrite && [fm fileExistsAtPath:destination isDirectory:&isDir] && isDir) {
                if (![self mergeDirectoryAtPath:source intoDirectory:destination error:error]) {
                    [fm removeItemAtPath:temp error:nil];
                    return NO;
                }
            } else {
                [fm removeItemAtPath:destination error:nil];
                NSError *moveError = nil;
                if (![fm moveItemAtPath:source toPath:destination error:&moveError]) {
                    if (error) *error = moveError;
                    [fm removeItemAtPath:temp error:nil];
                    return NO;
                }
            }
            rootIndex++;
            restoredRoots++;
            if (progress) {
                double fraction = 0.15 + 0.8 * ((double)rootIndex / (double)MAX(roots.count, 1));
                progress(fraction, [NSString stringWithFormat:localize(@"Restoring %@...", nil), root]);
            }
        }
    }

    [fm removeItemAtPath:temp error:nil];
    if (restoredRoots == 0) {
        if (error) *error = BackupError(18, localize(@"The backup does not contain any selected files.", nil));
        return NO;
    }
    if (progress) progress(1.0, localize(@"Restore complete", nil));
    return YES;
}

- (BOOL)mergeDirectoryAtPath:(NSString *)source intoDirectory:(NSString *)destination error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *listError = nil;
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:source error:&listError];
    if (!entries) {
        if (error) *error = listError;
        return NO;
    }
    for (NSString *name in entries) {
        NSString *from = [source stringByAppendingPathComponent:name];
        NSString *to = [destination stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:from isDirectory:&isDir] && isDir) {
            if (![self mergeDirectoryAtPath:from intoDirectory:to error:error]) return NO;
        } else {
            [fm removeItemAtPath:to error:nil];
            NSError *copyError = nil;
            if (![fm copyItemAtPath:from toPath:to error:&copyError]) {
                if (error) *error = copyError;
                return NO;
            }
        }
    }
    return YES;
}

#pragma mark - Verify

- (BOOL)verifyRecord:(BackupRecord *)record error:(NSError **)error {
    if (record.localPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:record.localPath]) {
        if (error) *error = BackupError(20, localize(@"Backup file not found.", nil));
        return NO;
    }
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:record.localPath error:error];
    if (!archive) return NO;
    NSArray<NSString *> *names = [archive listFilenames:error];
    return names != nil && names.count > 0;
}

@end
