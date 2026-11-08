#import "BackupManager.h"
#import "BackupStore.h"
#import "BackupConfig.h"
#import "BackupOAuth.h"
#import "LauncherPreferences.h"
#import "VersionDirectoryManager.h"
#import "utils.h"

NSString *const BackupDidChangeNotification = @"BackupDidChangeNotification";

@interface BackupManager ()
@property (nonatomic, strong) BackupStore *store;
@property (nonatomic, strong) NSArray<id<BackupDestination>> *allDestinations;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (atomic) BOOL busy;
@end

@implementation BackupManager

+ (BackupManager *)shared {
    static BackupManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BackupManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _store = [BackupStore shared];
        _workQueue = dispatch_queue_create("com.witch.zad626.backup", DISPATCH_QUEUE_SERIAL);
        _allDestinations = @[
            [[BackupFolderDestination alloc] init],
            [[BackupWebDAVDestination alloc] init],
            [[BackupGoogleDriveDestination alloc] init],
            [[BackupOneDriveDestination alloc] init],
            [[BackupDropboxDestination alloc] init],
        ];
        _busy = NO;
    }
    return self;
}

- (NSArray<BackupRecord *> *)records {
    return [self.store records];
}

- (NSArray<id<BackupDestination>> *)destinations {
    return self.allDestinations;
}

- (NSArray<id<BackupDestination>> *)enabledDestinations {
    NSMutableArray *result = [NSMutableArray array];
    for (id<BackupDestination> destination in self.allDestinations) {
        if (destination.enabled && destination.configured) [result addObject:destination];
    }
    return result;
}

- (void)reload {
    [self.store reloadRecords];
    [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
}

#pragma mark - Preferences

- (BOOL)boolPref:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = getPrefObject(key);
    if (value == nil) return defaultValue;
    return [value boolValue];
}

- (BOOL)isEnabled {
    return [self boolPref:@"backup.enabled" defaultValue:NO];
}

- (void)setEnabled:(BOOL)enabled {
    setPrefBool(@"backup.enabled", enabled);
    Class scheduler = NSClassFromString(@"BackupScheduler");
    if ([scheduler respondsToSelector:@selector(scheduleNext)]) {
        [(id)scheduler performSelector:@selector(scheduleNext)];
    }
}

- (NSString *)triggerPreferenceKey:(NSString *)trigger {
    return [NSString stringWithFormat:@"backup.auto_%@", trigger ?: @"manual"];
}

- (BOOL)isTriggerEnabled:(NSString *)trigger {
    if ([trigger isEqualToString:@"open"]) return [self boolPref:[self triggerPreferenceKey:trigger] defaultValue:NO];
    return [self boolPref:[self triggerPreferenceKey:trigger] defaultValue:YES];
}

- (void)setTrigger:(NSString *)trigger enabled:(BOOL)enabled {
    if (trigger.length == 0) return;
    setPrefBool([self triggerPreferenceKey:trigger], enabled);
    if ([trigger isEqualToString:@"schedule"]) {
        Class scheduler = NSClassFromString(@"BackupScheduler");
        if ([scheduler respondsToSelector:@selector(scheduleNext)]) {
            [(id)scheduler performSelector:@selector(scheduleNext)];
        }
    }
}

- (NSInteger)retentionCount {
    NSNumber *value = getPrefObject(@"backup.retention");
    if ([value respondsToSelector:@selector(integerValue)] && value.integerValue > 0) return value.integerValue;
    return 10;
}

- (void)setRetentionCount:(NSInteger)count {
    setPrefObject(@"backup.retention", @(MAX(1, count)));
}

- (NSString *)lastBackupDescription {
    NSDate *date = getPrefObject(@"backup.lastRun");
    if (![date isKindOfClass:[NSDate class]]) return localize(@"Never", nil);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

- (unsigned long long)totalLocalBytes {
    return [self.store totalArchiveBytes];
}

- (BOOL)isRunningGame {
    Class cls = NSClassFromString(@"SurfaceViewController");
    if (![cls respondsToSelector:@selector(isRunning)]) return NO;
    BOOL (*function)(id, SEL) = (void *)[cls methodForSelector:@selector(isRunning)];
    return function(cls, @selector(isRunning));
}

#pragma mark - Backup

- (void)backupNowWithReason:(NSString *)reason
                 completion:(void (^)(BackupRecord *, NSError *))completion {
    if (self.busy) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchBackup" code:1 userInfo:@{NSLocalizedDescriptionKey: localize(@"A backup is already running.", nil)}]);
        return;
    }
    if (self.isRunningGame) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchBackup" code:2 userInfo:@{NSLocalizedDescriptionKey: localize(@"Close Minecraft before backing up or restoring.", nil)}]);
        return;
    }

    BackupScope *scope = [BackupScope scopeForVersion:VersionDirectoryManager.shared.currentVersion roots:nil];
    if (![scope isValid]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchBackup" code:3 userInfo:@{NSLocalizedDescriptionKey: localize(@"No installed version is selected.", nil)}]);
        return;
    }

    self.busy = YES;
    NSString *reasonValue = reason.length > 0 ? reason : @"manual";
    dispatch_async(self.workQueue, ^{
        NSError *error = nil;
        BackupRecord *record = [self.store createArchiveForScope:scope reason:reasonValue progress:^(double fraction, NSString *message) {
            (void)fraction;
            (void)message;
        } error:&error];

        if (!record) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                if (completion) completion(nil, error);
            });
            return;
        }

        [self.store addRecord:record];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self uploadRecord:record toDestinations:self.enabledDestinations completion:^(NSError *uploadError) {
                self.busy = NO;
                setPrefObject(@"backup.lastRun", [NSDate date]);
                [self pruneOldBackups];
                [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
                Class scheduler = NSClassFromString(@"BackupScheduler");
                if ([scheduler respondsToSelector:@selector(scheduleNext)]) {
                    [(id)scheduler performSelector:@selector(scheduleNext)];
                }
                if (completion) completion(record, uploadError);
            }];
        });
    });
}

- (void)uploadRecord:(BackupRecord *)record
      toDestinations:(NSArray<id<BackupDestination>> *)destinations
          completion:(void (^)(NSError *))completion {
    if (destinations.count == 0) {
        if (completion) completion(nil);
        return;
    }
    [self uploadRecord:record destinations:destinations index:0 firstError:nil completion:completion];
}

- (void)uploadRecord:(BackupRecord *)record
        destinations:(NSArray<id<BackupDestination>> *)destinations
               index:(NSUInteger)index
          firstError:(NSError *)firstError
          completion:(void (^)(NSError *))completion {
    if (index >= destinations.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.store updateRecord:record];
            if (completion) completion(firstError);
        });
        return;
    }
    id<BackupDestination> destination = destinations[index];
    record.uploads[destination.identifier] = [@{@"status": @"uploading"} mutableCopy];
    [destination uploadFileAtPath:record.localPath record:record completion:^(NSDictionary *result, NSError *error) {
        NSMutableDictionary *state = [NSMutableDictionary dictionary];
        state[@"status"] = error ? @"failed" : @"done";
        if (result) state[@"remote"] = result;
        if (error) state[@"error"] = error.localizedDescription ?: @"Upload failed";
        record.uploads[destination.identifier] = state;
        [self.store updateRecord:record];
        NSError *nextError = firstError ?: error;
        [self uploadRecord:record destinations:destinations index:index + 1 firstError:nextError completion:completion];
    }];
}

- (void)backupIfNeededForTrigger:(NSString *)trigger
                      completion:(void (^)(BackupRecord *, NSError *))completion {
    NSString *value = trigger.length > 0 ? trigger : @"manual";
    if (![value isEqualToString:@"manual"] && ![self isEnabled]) {
        if (completion) completion(nil, nil);
        return;
    }
    if (![value isEqualToString:@"manual"] && ![self isTriggerEnabled:value]) {
        if (completion) completion(nil, nil);
        return;
    }
    if (self.busy) {
        if (completion) completion(nil, nil);
        return;
    }
    if (self.isRunningGame) {
        if (completion) completion(nil, nil);
        return;
    }

    NSDate *lastRun = getPrefObject(@"backup.lastRun");
    if ([lastRun isKindOfClass:[NSDate class]]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:lastRun];
        if (([value isEqualToString:@"launch"] || [value isEqualToString:@"open"]) && elapsed < 300) {
            if (completion) completion(nil, nil);
            return;
        }
        if ([value isEqualToString:@"schedule"]) {
            NSNumber *hours = getPrefObject(@"backup.auto_interval_hours");
            double interval = hours.doubleValue > 0 ? hours.doubleValue : 24.0;
            if (elapsed < interval * 3600.0) {
                if (completion) completion(nil, nil);
                return;
            }
        }
    }
    [self backupNowWithReason:value completion:completion];
}

#pragma mark - Restore

- (void)restoreRecord:(BackupRecord *)record
             overwrite:(BOOL)overwrite
              progress:(void (^)(double, NSString *))progress
            completion:(void (^)(NSError *))completion {
    if (self.busy) {
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:4 userInfo:@{NSLocalizedDescriptionKey: localize(@"A backup or restore is already running.", nil)}]);
        return;
    }
    if (self.isRunningGame) {
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:5 userInfo:@{NSLocalizedDescriptionKey: localize(@"Close Minecraft before restoring a backup.", nil)}]);
        return;
    }

    self.busy = YES;
    [self ensureLocalArchiveForRecord:record completion:^(NSError *downloadError) {
        if (downloadError) {
            self.busy = NO;
            if (completion) completion(downloadError);
            return;
        }
        dispatch_async(self.workQueue, ^{
            NSError *error = nil;
            BOOL ok = [self.store restoreRecord:record overwrite:overwrite progress:^(double fraction, NSString *message) {
                if (progress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progress(fraction, message);
                    });
                }
            } error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
                if (completion) completion(ok ? nil : error);
            });
        });
    }];
}

- (void)ensureLocalArchiveForRecord:(BackupRecord *)record completion:(void (^)(NSError *))completion {
    if (record.localPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:record.localPath]) {
        if (completion) completion(nil);
        return;
    }
    NSMutableArray<NSString *> *remoteKeys = [NSMutableArray array];
    for (NSString *key in record.uploads) {
        if ([record.uploads[key][@"status"] isEqualToString:@"done"]) [remoteKeys addObject:key];
    }
    if (remoteKeys.count == 0) {
        if (record.localPath.length > 0) {
            record.localPath = @"";
            [self.store updateRecord:record];
        }
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:6 userInfo:@{NSLocalizedDescriptionKey: localize(@"Backup file is not available on this device or in the cloud.", nil)}]);
        return;
    }
    NSString *path = record.localPath;
    if (path.length == 0) {
        path = [[BackupConfig archiveDirectoryPath] stringByAppendingPathComponent:record.fileName];
        record.localPath = path;
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [self downloadRecord:record identifiers:remoteKeys index:0 toPath:path firstError:nil completion:^(NSError *error) {
        if (error) {
            record.localPath = @"";
            [self.store updateRecord:record];
        }
        if (completion) completion(error);
    }];
}

- (void)downloadRecord:(BackupRecord *)record
            identifiers:(NSArray<NSString *> *)identifiers
                  index:(NSUInteger)index
                 toPath:(NSString *)path
             firstError:(NSError *)firstError
             completion:(void (^)(NSError *))completion {
    if (index >= identifiers.count) {
        if (completion) completion(firstError ?: [NSError errorWithDomain:@"WitchBackup" code:7 userInfo:@{NSLocalizedDescriptionKey: localize(@"Cloud destination is no longer available.", nil)}]);
        return;
    }
    NSString *identifier = identifiers[index];
    id<BackupDestination> destination = nil;
    for (id<BackupDestination> item in self.allDestinations) {
        if ([item.identifier isEqualToString:identifier]) { destination = item; break; }
    }
    if (!destination) {
        [self downloadRecord:record identifiers:identifiers index:index + 1 toPath:path firstError:firstError completion:completion];
        return;
    }
    [destination downloadFileNamed:record.fileName toPath:path completion:^(NSError *error) {
        if (!error) {
            [self.store updateRecord:record];
            if (completion) completion(nil);
            return;
        }
        [self downloadRecord:record identifiers:identifiers index:index + 1 toPath:path firstError:firstError ?: error completion:completion];
    }];
}

- (void)uploadRecord:(BackupRecord *)record
  toDestinationIdentifier:(NSString *)identifier
              completion:(void (^)(NSError *))completion {
    if (self.busy) {
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:8 userInfo:@{NSLocalizedDescriptionKey: localize(@"Another backup task is running.", nil)}]);
        return;
    }
    id<BackupDestination> destination = nil;
    for (id<BackupDestination> item in self.allDestinations) {
        if ([item.identifier isEqualToString:identifier]) { destination = item; break; }
    }
    if (!destination || !destination.configured) {
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:9 userInfo:@{NSLocalizedDescriptionKey: localize(@"This destination is not configured.", nil)}]);
        return;
    }
    self.busy = YES;
    [destination uploadFileAtPath:record.localPath record:record completion:^(NSDictionary *result, NSError *error) {
        NSMutableDictionary *state = [NSMutableDictionary dictionary];
        state[@"status"] = error ? @"failed" : @"done";
        if (result) state[@"remote"] = result;
        if (error) state[@"error"] = error.localizedDescription ?: @"Upload failed";
        record.uploads[destination.identifier] = state;
        [self.store updateRecord:record];
        self.busy = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
        if (completion) completion(error);
    }];
}

#pragma mark - Delete / prune

- (void)deleteRecord:(BackupRecord *)record
          deleteRemote:(BOOL)deleteRemote
            completion:(void (^)(NSError *))completion {
    if (!record) {
        if (completion) completion(nil);
        return;
    }
    if (self.busy) {
        if (completion) completion([NSError errorWithDomain:@"WitchBackup" code:10 userInfo:@{NSLocalizedDescriptionKey: localize(@"Another backup task is running.", nil)}]);
        return;
    }
    if (!deleteRemote) {
        if (record.hasRemoteCopy) {
            if (record.localPath.length > 0) {
                [[NSFileManager defaultManager] removeItemAtPath:record.localPath error:nil];
                record.localPath = @"";
                [self.store updateRecord:record];
            }
        } else {
            [self.store removeRecord:record deleteArchive:YES];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
        if (completion) completion(nil);
        return;
    }

    NSMutableArray<id<BackupDestination>> *remote = [NSMutableArray array];
    for (NSString *key in record.uploads) {
        if (![record.uploads[key][@"status"] isEqualToString:@"done"]) continue;
        for (id<BackupDestination> destination in self.allDestinations) {
            if ([destination.identifier isEqualToString:key]) { [remote addObject:destination]; break; }
        }
    }
    self.busy = YES;
    [self deleteRemoteRecord:record destinations:remote index:0 firstError:nil completion:^(NSError *error) {
        self.busy = NO;
        if (completion) completion(error);
    }];
}

- (void)deleteRemoteRecord:(BackupRecord *)record
               destinations:(NSArray<id<BackupDestination>> *)destinations
                      index:(NSUInteger)index
                 firstError:(NSError *)firstError
                 completion:(void (^)(NSError *))completion {
    if (index >= destinations.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (firstError) {
                if (completion) completion(firstError);
                return;
            }
            [self.store removeRecord:record deleteArchive:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:BackupDidChangeNotification object:self];
            if (completion) completion(nil);
        });
        return;
    }
    id<BackupDestination> destination = destinations[index];
    [destination deleteFileNamed:record.fileName completion:^(NSError *error) {
        [self deleteRemoteRecord:record destinations:destinations index:index + 1 firstError:firstError ?: error completion:completion];
    }];
}

- (void)pruneOldBackups {
    if (self.busy) return;
    NSInteger keep = [self retentionCount];
    NSArray<BackupRecord *> *records = [self.store records];
    for (NSInteger i = keep; i < (NSInteger)records.count; i++) {
        BackupRecord *record = records[i];
        if (record.localPath.length > 0) {
            [[NSFileManager defaultManager] removeItemAtPath:record.localPath error:nil];
            record.localPath = @"";
        }
        if (record.hasRemoteCopy) {
            [self.store updateRecord:record];
        } else {
            [self.store removeRecord:record deleteArchive:YES];
        }
    }
}

@end
