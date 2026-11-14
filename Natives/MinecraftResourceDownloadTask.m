#include <CommonCrypto/CommonDigest.h>

#import "authenticator/BaseAuthenticator.h"
#import "installer/modpack/ModpackAPI.h"
#import "AFNetworking.h"
#import "MinecraftResourceUtils.h"
#import "LauncherPreferences.h"
#import "MinecraftResourceDownloadTask.h"
#import "MinecraftResourceUtils.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface MinecraftResourceDownloadTask ()
@property AFURLSessionManager* manager;
// Witch patch: bounded download queue. The Minecraft installer queues
// thousands of files (every sound, every language file, every library) at
// once; resuming all of them immediately keeps thousands of sockets and
// task objects alive and makes the connection drops more likely. The queue
// keeps a small number of transfers in flight and starts the next one as
// soon as a slot frees up.
@property NSMutableArray<NSURLSessionDownloadTask*>* pendingDownloads;
@property NSUInteger activeDownloads;
@end

// Transfers that may run at the same time. The per-host limit of
// NSURLSession is 6, so this only caps the total number of open transfers.
static const NSUInteger kMaxParallelDownloads = 12;

// Witch patch: extra attempts for a download that failed with a transient
// network error. Installing Minecraft queues thousands of small files at
// once; a single dropped connection (NSURLErrorNetworkConnectionLost) used
// to abort the whole installation with an error dialog.
static const NSInteger kMaxDownloadRetries = 3;

// Network hiccups worth retrying: the connection was dropped, the host was
// unreachable, the DNS lookup failed or the request timed out. A wrong URL
// or a 404 is not retried.
static BOOL isRetryableDownloadError(NSError *error) {
    if (!error) {
        return NO;
    }
    switch (error.code) {
        case NSURLErrorTimedOut:
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorInternationalRoamingOff:
        case NSURLErrorCallIsActive:
        case NSURLErrorDataNotAllowed:
        case NSURLErrorResourceUnavailable:
            return YES;
        default:
            return NO;
    }
}

@implementation MinecraftResourceDownloadTask

- (instancetype)init {
    self = [super init];
    // TODO: implement background download
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    // Witch patch: idle timeout. 24 hours meant a connection that died
    // silently kept the task hanging until the whole system gave up; two
    // minutes without a single byte is a dead transfer and the retry takes
    // over from there.
    configuration.timeoutIntervalForRequest = 120;
    // Witch patch: wait for the network instead of failing immediately when
    // the device is offline or the connection is being re-established (a
    // mobile switch between wifi and cellular dropped the whole install).
    configuration.waitsForConnectivity = YES;
    //backgroundSessionConfigurationWithIdentifier:@"net.kdt.pojavlauncher.downloadtask"];
    self.manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    self.pendingDownloads = [NSMutableArray new];
    self.activeDownloads = 0;
    self.fileList = [NSMutableArray new];
    self.progressList = [NSMutableArray new];
    self.progress = [NSProgress new];
    self.progress.totalUnitCount = 1;
    self.textProgress = [NSProgress new];
    self.textProgress.kind = NSProgressKindFile;
    self.textProgress.fileOperationKind = NSProgressFileOperationKindDownloading;
    self.textProgress.totalUnitCount = -1;
    return self;
}

- (void)cancelAll {
    [self.progress cancel];
    [self.manager invalidateSessionCancelingTasks:YES resetSession:YES];
}

// Witch patch: start a transfer through the bounded queue. The slot is
// released when the transfer finishes (success or failure).
- (void)resumeDownloadTask:(NSURLSessionDownloadTask *)task {
    if (!task) {
        return;
    }
    @synchronized (self) {
        [self.pendingDownloads addObject:task];
        [self pumpPendingDownloads];
    }
}

- (void)pumpPendingDownloads {
    while (self.activeDownloads < kMaxParallelDownloads && self.pendingDownloads.count > 0) {
        NSURLSessionDownloadTask *task = self.pendingDownloads.firstObject;
        [self.pendingDownloads removeObjectAtIndex:0];
        self.activeDownloads++;
        [task resume];
    }
}

- (void)releaseDownloadSlot {
    @synchronized (self) {
        if (self.activeDownloads > 0) {
            self.activeDownloads--;
        }
        [self pumpPendingDownloads];
    }
}

// Add file to the queue
- (NSURLSessionDownloadTask *)createDownloadTask:(NSString *)url size:(NSUInteger)size sha:(NSString *)sha altName:(NSString *)altName toPath:(NSString *)path success:(void (^)())success {
    BOOL fileExists = [NSFileManager.defaultManager fileExistsAtPath:path];
    // logSuccess?
    if (fileExists && [self checkSHA:sha forFile:path altName:altName]) {
        if (success) success();
        return nil;
    } else if (![self checkAccessWithDialog:YES]) {
        return nil;
    }

    // Witch patch: the first attempt counts the file size in the progress
    // total; a retry re-uses the same slot.
    NSURLSessionDownloadTask *task = [self startDownloadAttempt:url size:size sha:sha altName:altName
                                                       toPath:path success:success attempt:0];
    NSUInteger effectiveSize = size > 0 ? size : 1;
    [self addDownloadTaskToProgress:task size:effectiveSize countInTotal:YES];
    [self.manager downloadProgressForTask:task].localizedDescription = altName ?: path.lastPathComponent;
    [self.fileList addObject:(altName ?: path.lastPathComponent)];

    return task;
}

// Witch patch: run one download attempt. A transient network failure is
// retried (with a short backoff) instead of aborting the installation.
- (NSURLSessionDownloadTask *)startDownloadAttempt:(NSString *)url size:(NSUInteger)size sha:(NSString *)sha
                                            altName:(NSString *)altName toPath:(NSString *)path
                                            success:(void (^)())success attempt:(NSInteger)attempt {
    NSString *name = altName ?: path.lastPathComponent;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    __block NSProgress *progress;
    __block NSURLSessionDownloadTask *task = [self.manager downloadTaskWithRequest:request progress:nil
    destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSLog(@"[MCDL] Downloading %@", name);
        progress = [self.manager downloadProgressForTask:task];
        if (size == 0 && progress.totalUnitCount == 0 && task) {
            NSUInteger actualSize = response.expectedContentLength > 0 ? response.expectedContentLength : 1;
            progress.totalUnitCount = actualSize;
        }
        [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        return [NSURL fileURLWithPath:path];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (self.progress.cancelled) {
            // Ignore any further errors
            [self releaseDownloadSlot];
            return;
        }
        if (error != nil) {
            if (isRetryableDownloadError(error) && attempt < kMaxDownloadRetries) {
                const NSTimeInterval delay = 1.0 + 2.0 * (double)attempt;
                NSLog(@"[MCDL] Retry %ld/%ld for %@ (%@)", (long)(attempt + 1), (long)kMaxDownloadRetries,
                      name, error.localizedDescription);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    NSURLSessionDownloadTask *retryTask = [self startDownloadAttempt:url size:size sha:sha
                                                                          altName:altName toPath:path
                                                                          success:success attempt:attempt + 1];
                    // The file size is already part of the progress total -
                    // the retry only adds the (still running) task.
                    NSUInteger effectiveSize = size > 0 ? size : 1;
                    [self addDownloadTaskToProgress:retryTask size:effectiveSize countInTotal:NO];
                    // The failed attempt gives its slot back before the
                    // retry takes a new one.
                    [self releaseDownloadSlot];
                    [self resumeDownloadTask:retryTask];
                });
                return;
            }
            [self releaseDownloadSlot];
            [self finishDownloadWithError:error file:name];
        } else if (![self checkSHA:sha forFile:path altName:altName]) {
            [self releaseDownloadSlot];
            [self finishDownloadWithErrorString:[NSString stringWithFormat:@"Failed to verify file %@: SHA1 mismatch", path.lastPathComponent]];
        } else {
            progress.totalUnitCount = progress.completedUnitCount;
            [self releaseDownloadSlot];
            if (success) success();
        }
    }];

    return task;
}

- (NSURLSessionDownloadTask *)createDownloadTask:(NSString *)url size:(NSUInteger)size sha:(NSString *)sha altName:(NSString *)altName toPath:(NSString *)path {
    return [self createDownloadTask:url size:size sha:sha altName:altName toPath:path success:nil];
}

- (void)addDownloadTaskToProgress:(NSURLSessionDownloadTask *)task size:(NSInteger)size countInTotal:(BOOL)countInTotal {
    NSProgress *progress = [self.manager downloadProgressForTask:task];
    NSUInteger fileSize = size > 0 ? (NSUInteger)size : 1;
    progress.kind = NSProgressKindFile;
    progress.totalUnitCount = fileSize;
    [self.progressList addObject:progress];
    [self.progress addChild:progress withPendingUnitCount:(countInTotal ? fileSize : 0)];
    if (countInTotal) {
        self.progress.totalUnitCount += fileSize;
    }
    self.textProgress.totalUnitCount = self.progress.totalUnitCount;
    // A retry adds its own (partial) progress on top of the failed attempt:
    // keep the reported completion inside the total.
    if (self.progress.completedUnitCount > self.progress.totalUnitCount) {
        self.progress.completedUnitCount = self.progress.totalUnitCount;
    }
}

- (void)resolveFullInheritsChain {
    NSMutableSet *seen = [NSMutableSet set];
    NSString *currentId = self.metadata[@"id"];
    while (self.metadata[@"inheritsFrom"]) {
        [seen addObject:currentId];
        NSString *parentId = self.metadata[@"inheritsFrom"];
        if ([seen containsObject:parentId]) break;
        currentId = parentId;
        NSString *parentPath = [NSString stringWithFormat:@"%1$s/versions/%2$@/%2$@.json", getenv("POJAV_GAME_DIR"), parentId];
        NSMutableDictionary *parentDict = parseJSONFromFile(parentPath);
        if (parentDict[@"NSErrorObject"]) break;
        [MinecraftResourceUtils processVersion:self.metadata inheritsFrom:parentDict];
        self.metadata = parentDict;
    }
}

- (void)ensureAncestorVersionsForJson:(NSMutableDictionary *)json completion:(void (^)())completion {
    if (!json[@"inheritsFrom"]) {
        completion();
        return;
    }

    NSString *parentId = json[@"inheritsFrom"];
    NSString *parentPath = [NSString stringWithFormat:@"%1$s/versions/%2$@/%2$@.json", getenv("POJAV_GAME_DIR"), parentId];

    // Check if parent already exists on disk
    NSMutableDictionary *parentJson = parseJSONFromFile(parentPath);
    if (parentJson && !parentJson[@"NSErrorObject"]) {
        // Parent exists; check further up the chain
        [self ensureAncestorVersionsForJson:parentJson completion:completion];
        return;
    }

    // Parent not on disk; look up in remote manifest
    NSDictionary *remoteVersion = (id)[MinecraftResourceUtils findVersion:parentId inList:remoteVersionList];
    if (remoteVersion) {
        NSString *url = remoteVersion[@"url"];
        NSString *sha = url.stringByDeletingLastPathComponent.lastPathComponent;
        NSUInteger size = [remoteVersion[@"size"] unsignedLongLongValue];

        __weak typeof(self) weakSelf = self;
        NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:sha altName:nil toPath:parentPath success:^{
            NSMutableDictionary *downloadedParent = parseJSONFromFile(parentPath);
            if (downloadedParent && !downloadedParent[@"NSErrorObject"]) {
                [weakSelf ensureAncestorVersionsForJson:downloadedParent completion:completion];
            } else {
                completion();
            }
        }];
        [self resumeDownloadTask:task];
    } else {
        // Parent not in remote manifest (e.g., mod loader profile like fabric-loader).
        // Read from disk if it exists, otherwise just proceed.
        NSMutableDictionary *existingParent = parseJSONFromFile(parentPath);
        if (existingParent && !existingParent[@"NSErrorObject"]) {
            [self ensureAncestorVersionsForJson:existingParent completion:completion];
        } else {
            NSLog(@"[MCDL] Warning: ancestor version %@ not found locally or remotely", parentId);
            completion();
        }
    }
}

- (void)downloadVersionMetadata:(NSDictionary *)version success:(void (^)())success {
    // Download base json
    NSString *versionStr = version[@"id"];
    if ([versionStr isEqualToString:@"latest-release"]) {
        versionStr = getPrefObject(@"internal.latest_version.release");
    } else if ([versionStr isEqualToString:@"latest-snapshot"]) {
        versionStr = getPrefObject(@"internal.latest_version.snapshot");
    }

    NSString *path = [NSString stringWithFormat:@"%1$s/versions/%2$@/%2$@.json", getenv("POJAV_GAME_DIR"), versionStr];
    // Find it again to resolve latest-*
    version = (id)[MinecraftResourceUtils findVersion:versionStr inList:remoteVersionList];

    void(^completionBlock)(void) = ^{
        self.metadata = parseJSONFromFile(path);
        if (self.metadata[@"NSErrorObject"]) {
            [self finishDownloadWithErrorString:[self.metadata[@"NSErrorObject"] localizedDescription]];
            return;
        }

        // Merge inheritsFrom chain for the in-memory copy (used by
        // library/asset downloads). Do NOT write to disk — Java's own
        // resolveInheritsChain will handle the JSON on disk.
        [self resolveFullInheritsChain];
        [MinecraftResourceUtils tweakVersionJson:self.metadata];

        success();
    };

    if (!version) {
        // This is likely local version, check if json exists and has inheritsFrom
        NSMutableDictionary *json = parseJSONFromFile(path);
        if (json[@"NSErrorObject"]) {
            [self finishDownloadWithErrorString:[json[@"NSErrorObject"] localizedDescription]];
            return;
        } else if (json[@"inheritsFrom"]) {
            // Ensure all ancestor versions in the inheritance chain exist on disk.
            // This handles cases like modpack -> fabric-loader -> base MC version.
            [self ensureAncestorVersionsForJson:json completion:completionBlock];
            return;
        } else {
            completionBlock();
            return;
        }
    }

    versionStr = version[@"id"];
    NSString *url = version[@"url"];
    NSString *sha = url.stringByDeletingLastPathComponent.lastPathComponent;
    NSUInteger size = [version[@"size"] unsignedLongLongValue];

    NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:sha altName:nil toPath:path success:completionBlock];
    [self resumeDownloadTask:task];
}

#pragma mark - Minecraft installation

- (void)downloadAssetMetadataWithSuccess:(void (^)())success {
    NSDictionary *assetIndex = self.metadata[@"assetIndex"];
    if (!assetIndex) {
        success();
        return;
    }
    NSString *name = [NSString stringWithFormat:@"assets/indexes/%@.json", assetIndex[@"id"]];
    NSString *path = [@(getenv("POJAV_GAME_DIR")) stringByAppendingPathComponent:name];
    NSString *url = assetIndex[@"url"];
    NSString *sha = url.stringByDeletingLastPathComponent.lastPathComponent;
    NSUInteger size = [assetIndex[@"size"] unsignedLongLongValue];
    NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:sha altName:name toPath:path success:^{
        self.metadata[@"assetIndexObj"] = parseJSONFromFile(path);
        success();
    }];
    [self resumeDownloadTask:task];
}

- (NSArray *)downloadClientLibraries {
    NSMutableArray *tasks = [NSMutableArray new];
    for (NSDictionary *library in self.metadata[@"libraries"]) {
        NSString *name = library[@"name"];
        if (![name isKindOfClass:[NSString class]] || name.length == 0) {
            NSLog(@"[MDCL] Skipped library with invalid name: %@", name);
            continue;
        }

        NSMutableDictionary *artifact = library[@"downloads"][@"artifact"];
        if (artifact == nil && [name containsString:@":"]) {
            NSLog(@"[MCDL] Unknown artifact object for %@, attempting to generate one", name);
            artifact = [[NSMutableDictionary alloc] init];
            NSString *prefix = library[@"url"] == nil ? @"https://libraries.minecraft.net/" : [library[@"url"] stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
            NSArray *libParts = [name componentsSeparatedByString:@":"];
            artifact[@"path"] = [NSString stringWithFormat:@"%1$@/%2$@/%3$@/%2$@-%3$@.jar", [libParts[0] stringByReplacingOccurrencesOfString:@"." withString:@"/"], libParts[1], libParts[2]];
            artifact[@"url"] = [NSString stringWithFormat:@"%@%@", prefix, artifact[@"path"]];
            artifact[@"sha1"] = library[@"checksums"][0];
        }

        NSString *path = [[NSString stringWithFormat:@"%s/libraries/%@", getenv("POJAV_GAME_DIR"), artifact[@"path"]] stringByStandardizingPath];
        NSString *sha = artifact[@"sha1"];
        NSUInteger size = [artifact[@"size"] unsignedLongLongValue];
        NSString *url = artifact[@"url"];
        if ([library[@"skip"] boolValue]) {
            NSLog(@"[MDCL] Skipped library %@", name);
            continue;
        }

        NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:sha altName:name toPath:path success:nil];
        if (task) {
            [tasks addObject:task];
        } else if (self.progress.cancelled) {
            return nil;
        }
    }
    return tasks;
}

- (NSArray *)downloadClientAssets {
    NSMutableArray *tasks = [NSMutableArray new];
    NSDictionary *assets = self.metadata[@"assetIndexObj"];
    if (!assets) {
        return @[];
    }
    for (NSString *name in assets[@"objects"]) {
        NSDictionary *object = assets[@"objects"][name];
        NSString *hash = object[@"hash"];
        NSString *pathname = [NSString stringWithFormat:@"%@/%@", [hash substringToIndex:2], hash];
        NSUInteger size = [object[@"size"] unsignedLongLongValue];

        NSString *path;
        if ([assets[@"map_to_resources"] boolValue]) {
            path = [NSString stringWithFormat:@"%s/resources/%@", getenv("POJAV_GAME_DIR"), name];
        } else {
            path = [NSString stringWithFormat:@"%s/assets/objects/%@", getenv("POJAV_GAME_DIR"), pathname];
        }

        /* Special case for 1.19+
         * Since 1.19-pre1, setting the window icon on macOS invokes ObjC.
         * However, if an IOException occurs, it won't try to set.
         * We skip downloading the icon file to workaround this. */
        if ([name hasSuffix:@"/minecraft.icns"]) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            continue;
        }

        NSString *url = [NSString stringWithFormat:@"https://resources.download.minecraft.net/%@", pathname];
        NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:hash altName:name toPath:path success:nil];
        if (task) {
            [tasks addObject:task];
        } else if (self.progress.cancelled) {
            return nil;
        }
    }
    return tasks;
}

- (void)downloadVersion:(NSDictionary *)version {
    [self prepareForDownload];
    [self downloadVersionMetadata:version success:^{
        [self downloadAssetMetadataWithSuccess:^{
            NSArray *libTasks = [self downloadClientLibraries];
            NSArray *assetTasks = [self downloadClientAssets];
            // Drop the 1 byte we set initially
            self.progress.totalUnitCount--;
            self.textProgress.totalUnitCount--;
            if (self.progress.totalUnitCount == 0) {
                self.progress.totalUnitCount = 1;
                self.progress.completedUnitCount = 1;
                self.textProgress.totalUnitCount = 1;
                self.textProgress.completedUnitCount = 1;
            }
            for (NSURLSessionDownloadTask *task in libTasks) {
                [self resumeDownloadTask:task];
            }
            for (NSURLSessionDownloadTask *task in assetTasks) {
                [self resumeDownloadTask:task];
            }
            [self.metadata removeObjectForKey:@"assetIndexObj"];
        }];
    }];
}

#pragma mark - Modpack installation

- (void)downloadModpackFromAPI:(ModpackAPI *)api detail:(NSDictionary *)modDetail atIndex:(NSUInteger)selectedVersion {
    [self prepareForDownload];

    NSString *url = modDetail[@"versionUrls"][selectedVersion];
    NSUInteger size = [modDetail[@"versionSizes"][selectedVersion] unsignedLongLongValue];
    NSString *sha = modDetail[@"versionHashes"][selectedVersion];
    NSString *name = [[modDetail[@"title"] lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    name = [name stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *packagePath = [NSTemporaryDirectory() stringByAppendingFormat:@"/%@.zip", name];

    NSURLSessionDownloadTask *task = [self createDownloadTask:url size:size sha:sha altName:nil toPath:packagePath success:^{
        NSString *path = [NSString stringWithFormat:@"%s/custom_gamedir/%@", getenv("POJAV_GAME_DIR"), name];
        [api downloader:self submitDownloadTasksFromPackage:packagePath toPath:path];
    }];
    [self resumeDownloadTask:task];
}

#pragma mark - Utilities

- (void)prepareForDownload {
    self.textProgress.totalUnitCount = -1;
    self.progress.totalUnitCount = 1;
    self.progress.completedUnitCount = 0;
    [self.fileList removeAllObjects];
    [self.progressList removeAllObjects];
}

- (void)finishDownloadWithErrorString:(NSString *)error {
    [self.progress cancel];
    [self.manager invalidateSessionCancelingTasks:YES resetSession:YES];
    showDialog(localize(@"Error", nil), error);
    self.handleError();
}

- (void)finishDownloadWithError:(NSError *)error file:(NSString *)file {
    NSString *errorStr = [NSString stringWithFormat:localize(@"launcher.mcl.error_download", NULL), file, error.localizedDescription];
    NSLog(@"[MCDL] Error: %@ %@", errorStr, NSThread.callStackSymbols);
    [self finishDownloadWithErrorString:errorStr];
}

// Check if the account has permission to download
- (BOOL)checkAccessWithDialog:(BOOL)show {
    return YES;
}

// Check SHA of the file
- (BOOL)checkSHAIgnorePref:(NSString *)sha forFile:(NSString *)path altName:(NSString *)altName logSuccess:(BOOL)logSuccess {
    if (sha.length == 0) {
        // When sha = skip, only check for file existence
        BOOL existence = [NSFileManager.defaultManager fileExistsAtPath:path];
        if (existence) {
            NSLog(@"[MCDL] Warning: couldn't find SHA for %@, have to assume it's good.", path);
        }
        return existence;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        NSLog(@"[MCDL] SHA1 checker: file doesn't exist: %@", altName ? altName : path.lastPathComponent);
        return NO;
    }

    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *localSHA = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [localSHA appendFormat:@"%02x", digest[i]];
    }

    BOOL check = [sha isEqualToString:localSHA];
    if (!check || (getPrefBool(@"general.debug_logging") && logSuccess)) {
        NSLog(@"[MCDL] SHA1 %@ for %@%@",
          (check ? @"passed" : @"failed"), 
          (altName ? altName : path.lastPathComponent),
          (check ? @"" : [NSString stringWithFormat:@" (expected: %@, got: %@)", sha, localSHA]));
    }
    return check;
}

- (BOOL)checkSHA:(NSString *)sha forFile:(NSString *)path altName:(NSString *)altName logSuccess:(BOOL)logSuccess {
    if (getPrefBool(@"general.check_sha")) {
        return [self checkSHAIgnorePref:sha forFile:path altName:altName logSuccess:logSuccess];
    } else {
        return [NSFileManager.defaultManager fileExistsAtPath:path];
    }
}

- (BOOL)checkSHA:(NSString *)sha forFile:(NSString *)path altName:(NSString *)altName {
    return [self checkSHA:sha forFile:path altName:altName logSuccess:altName==nil];
}

@end
