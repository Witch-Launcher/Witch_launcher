#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "AFNetworking.h"
#import "UnzipKit.h"
#import "utils.h"

NSString * const DownloadTasksDidChangeNotification = @"DownloadTasksDidChangeNotification";

@interface DownloadTask ()
@property (nonatomic) long long lastSampleBytes;
@property (nonatomic) NSTimeInterval lastSampleTime;
@property (nonatomic) float lastNotifiedProgress;
@property (nonatomic) BOOL hasNotifiedProgress;
@end

@implementation DownloadTask
@end

@interface DownloadManager ()
@property (nonatomic) NSMutableArray<DownloadTask *> *activeTasks;
@property (nonatomic) NSMutableArray<DownloadTask *> *finishedTasks;
@end

static const NSUInteger kMaxFinishedTasks = 60;

@implementation DownloadManager

+ (DownloadManager *)shared {
    static DownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTasks = [NSMutableArray array];
        _finishedTasks = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Multi-download hub

- (void)notifyChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:DownloadTasksDidChangeNotification object:nil];
}

- (NSArray<DownloadTask *> *)activeTasks {
    return [_activeTasks copy];
}

- (NSArray<DownloadTask *> *)allTasks {
    NSMutableArray *all = [NSMutableArray arrayWithArray:_activeTasks];
    [all addObjectsFromArray:_finishedTasks];
    return [all copy];
}

- (DownloadTask *)beginTaskWithName:(NSString *)name type:(DownloadType)type {
    DownloadTask *t = [[DownloadTask alloc] init];
    t.name = name ?: @"Download";
    t.type = type;
    t.progress = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_activeTasks addObject:t];
        [self notifyChange];
    });
    return t;
}

- (void)updateProgress:(float)progress forTask:(DownloadTask *)task {
    if (!task || task.cancelled) return;
    float clamped = MAX(0.0f, MIN(progress, 1.0f));
    // Throttle: only notify on meaningful steps to avoid notification storms.
    static const float kStep = 0.02f;
    if (clamped < 1.0f && task.hasNotifiedProgress && fabs(clamped - task.lastNotifiedProgress) < kStep) {
        task.progress = clamped;
        return;
    }
    task.hasNotifiedProgress = YES;
    task.lastNotifiedProgress = clamped;
    dispatch_async(dispatch_get_main_queue(), ^{
        task.progress = clamped;
        [self notifyChange];
    });
}

- (void)updateProgressBytes:(float)progress received:(long long)received total:(long long)total forTask:(DownloadTask *)task {
    if (!task || task.cancelled) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (task.lastSampleTime <= 0) {
        task.lastSampleTime = now;
        task.lastSampleBytes = received;
    } else if (now - task.lastSampleTime >= 0.4) {
        double dt = now - task.lastSampleTime;
        long long delta = received - task.lastSampleBytes;
        if (dt > 0 && delta > 0) {
            double rate = (double)delta / dt;
            task.bytesPerSecond = task.bytesPerSecond > 0 ? task.bytesPerSecond * 0.6 + rate * 0.4 : rate;
        }
        task.lastSampleTime = now;
        task.lastSampleBytes = received;
    }
    task.receivedBytes = received;
    task.totalBytes = total;
    [self updateProgress:progress forTask:task];
}

- (void)completeTask:(DownloadTask *)task error:(NSError *)error {
    if (!task) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        task.isFinished = YES;
        task.error = error;
        [self->_activeTasks removeObject:task];
        [self moveToFinished:task];
        [self notifyChange];
    });
}

- (void)cancelTask:(DownloadTask *)task {
    if (!task || task.cancelled) return;
    task.cancelled = YES;
    if (task.cancelBlock) task.cancelBlock();
    dispatch_async(dispatch_get_main_queue(), ^{
        task.isFinished = YES;
        [self->_activeTasks removeObject:task];
        [self moveToFinished:task];
        [self notifyChange];
    });
}

- (void)cancelAllTasks {
    for (DownloadTask *t in [self.activeTasks copy]) {
        [self cancelTask:t];
    }
}

- (void)clearFinishedTasks {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_finishedTasks removeAllObjects];
        [self notifyChange];
    });
}

- (void)moveToFinished:(DownloadTask *)task {
    [_finishedTasks removeObject:task];
    [_finishedTasks insertObject:task atIndex:0];
    if (_finishedTasks.count > kMaxFinishedTasks) {
        [_finishedTasks removeObjectsInRange:NSMakeRange(kMaxFinishedTasks, _finishedTasks.count - kMaxFinishedTasks)];
    }
}

#pragma mark - Convenience flows

- (void)downloadMod:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:version];
    NSString *targetPath = [modsDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".jar"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadShader:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *shaderDir = [VersionDirectoryManager.shared shaderPacksPathForVersion:version];
    NSString *targetPath = [shaderDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".zip"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"zip"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadResourcePack:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *rpDir = [VersionDirectoryManager.shared resourcePacksPathForVersion:version];
    NSString *targetPath = [rpDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".zip"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"zip"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadMap:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *savesDir = [VersionDirectoryManager.shared savesPathForVersion:version];
    NSString *fileName = name.length > 0 ? name : @"world";
    if (![fileName hasSuffix:@".zip"]) fileName = [fileName stringByAppendingPathExtension:@"zip"];
    // Fixed destination: unlike downloadToPath we must know exactly where the
    // zip landed so we can unpack and remove it afterwards.
    NSString *zipPath = [savesDir stringByAppendingPathComponent:fileName];

    NSURL *downloadURL = [NSURL URLWithString:url ?: @""];
    if (!downloadURL) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DownloadManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:savesDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:zipPath error:nil];

    NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
    NSURLSessionDownloadTask *task = [[AFHTTPSessionManager manager] downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath_, NSURLResponse *response) {
        return [NSURL fileURLWithPath:zipPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        // Unpack off the main thread: large worlds would freeze the UI.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *unpackError = nil;
            NSString *fallback = [fileName stringByDeletingPathExtension];
            BOOL ok = [DownloadManager installWorldArchiveAtPath:zipPath savesDir:savesDir fallbackName:fallback error:&unpackError];
            if (!ok) {
                NSLog(@"[DownloadManager] world unpack failed for %@: %@", zipPath, unpackError);
                // Keep the zip so the user still has the download; surface why.
                NSError *report = unpackError ?: [NSError errorWithDomain:@"DownloadManager" code:-3
                                                                    userInfo:@{NSLocalizedDescriptionKey: localize(@"map.unpack_failed", nil)}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO, report); });
                return;
            }
            [fm removeItemAtPath:zipPath error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(YES, nil); });
        });
    }];
    [task resume];
}

- (void)downloadToPath:(NSString *)urlString targetPath:(NSString *)targetPath completion:(void(^)(BOOL, NSError *))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DownloadManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return;
    }

    NSString *dir = targetPath.stringByDeletingLastPathComponent;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    // Download beside the destination first, then swap it in. A failed or
    // partial transfer must not destroy the file that is already installed.
    NSString *partPath = [targetPath stringByAppendingFormat:@".%@.part", NSUUID.UUID.UUIDString];

    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *task = [[AFHTTPSessionManager manager] downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath_, NSURLResponse *response) {
        // Use the caller's destination verbatim. CDN/proxy URLs sometimes end
        // in an opaque path, so trusting suggestedFilename can drop extensions
        // (e.g. modpack jars) or write to the wrong folder.
        return [NSURL fileURLWithPath:partPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error) {
            [fm removeItemAtPath:partPath error:nil];
            if (completion) completion(NO, error);
            return;
        }
        NSError *moveError = nil;
        BOOL moved = NO;
        if ([fm fileExistsAtPath:targetPath]) {
            // Atomic swap on the same volume: the installed file stays in
            // place if anything goes wrong.
            moved = [fm replaceItemAtURL:[NSURL fileURLWithPath:targetPath]
                           withItemAtURL:[NSURL fileURLWithPath:partPath]
                          backupItemName:nil
                                 options:0
                        resultingItemURL:nil
                                   error:&moveError];
        } else {
            moved = [fm moveItemAtPath:partPath toPath:targetPath error:&moveError];
        }
        if (!moved && [fm fileExistsAtPath:targetPath]) {
            // Some filesystems reject replaceItemAtURL; fall back to a
            // backup-and-swap so a failure still leaves the old file intact.
            NSString *backupPath = [targetPath stringByAppendingFormat:@".%@.old", NSUUID.UUID.UUIDString];
            if ([fm moveItemAtPath:targetPath toPath:backupPath error:nil]) {
                NSError *swapError = nil;
                if ([fm moveItemAtPath:partPath toPath:targetPath error:&swapError]) {
                    moved = YES;
                    moveError = nil;
                    [fm removeItemAtPath:backupPath error:nil];
                } else {
                    [fm moveItemAtPath:backupPath toPath:targetPath error:nil];
                    moveError = swapError;
                }
            }
        }
        if (!moved) [fm removeItemAtPath:partPath error:nil];
        if (completion) completion(moved, moveError);
    }];
    [task resume];
}

#pragma mark - World unpack

+ (NSString *)uniqueWorldDirInSaves:(NSString *)savesDir preferredName:(NSString *)preferred {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *name = preferred.length > 0 ? preferred : @"World";
    NSString *candidate = [savesDir stringByAppendingPathComponent:name];
    NSInteger n = 2;
    while ([fm fileExistsAtPath:candidate] && n <= 99) {
        candidate = [savesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%ld)", name, (long)n]];
        n++;
    }
    return candidate;
}

+ (BOOL)installWorldArchiveAtPath:(NSString *)archivePath
                         savesDir:(NSString *)savesDir
                     fallbackName:(NSString *)fallbackName
                            error:(NSError **)error {
    if (archivePath.length == 0 || savesDir.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"DownloadManager" code:-2
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"map.unpack_failed", nil)}];
        return NO;
    }
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:archivePath error:error];
    if (!archive) return NO;
    NSArray<NSString *> *names = [archive listFilenames:error];
    if (![names isKindOfClass:[NSArray class]]) return NO;

    // Find the shallowest level.dat (root or inside a wrapper folder).
    NSString *levelEntry = nil;
    NSInteger levelDepth = NSIntegerMax;
    for (NSString *n in names) {
        if ([n hasSuffix:@"/"]) continue;
        if ([[n.lastPathComponent lowercaseString] isEqualToString:@"level.dat"]) {
            NSInteger depth = [n componentsSeparatedByString:@"/"].count;
            if (depth < levelDepth) {
                levelDepth = depth;
                levelEntry = n;
            }
        }
    }
    if (!levelEntry) {
        if (error) *error = [NSError errorWithDomain:@"DownloadManager" code:-2
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"map.unpack_no_level", nil)}];
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:savesDir withIntermediateDirectories:YES attributes:nil error:nil];

    if (levelDepth == 1) {
        // level.dat at the archive root: the whole zip *is* the world.
        NSString *name = [fallbackName stringByDeletingPathExtension];
        name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
        NSString *dest = [self uniqueWorldDirInSaves:savesDir preferredName:name];
        [fm createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:nil];
        if (![archive extractFilesTo:dest overwrite:YES error:error]) {
            [fm removeItemAtPath:dest error:nil];
            return NO;
        }
        return YES;
    }

    // Wrapped in a top-level folder: keep the folder's own name. When that
    // name is taken, unpack to a temp dir and move the folder under a
    // uniquified name.
    NSString *topDir = [levelEntry componentsSeparatedByString:@"/"].firstObject;
    NSString *topDest = [savesDir stringByAppendingPathComponent:topDir];
    if (![fm fileExistsAtPath:topDest]) {
        return [archive extractFilesTo:savesDir overwrite:YES error:error];
    }
    NSString *unique = [self uniqueWorldDirInSaves:savesDir preferredName:topDir];
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"amethyst-world-%@", NSUUID.UUID.UUIDString]];
    [fm createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
    if (![archive extractFilesTo:tmpDir overwrite:YES error:error]) {
        [fm removeItemAtPath:tmpDir error:nil];
        return NO;
    }
    NSError *moveError = nil;
    if (![fm moveItemAtPath:[tmpDir stringByAppendingPathComponent:topDir] toPath:unique error:&moveError]) {
        if (error) *error = moveError;
        [fm removeItemAtPath:tmpDir error:nil];
        return NO;
    }
    [fm removeItemAtPath:tmpDir error:nil];
    return YES;
}

@end
