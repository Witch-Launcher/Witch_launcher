#import "WitchRuntimeService.h"
#import "LauncherPreferences.h"
#import "LauncherPrefManageJREViewController.h"
#import "WitchJREPatcher.h"
#import "utils.h"
#import "UnzipKit.h"

static NSError *WitchRuntimeError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"WitchRuntime" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Runtime error"}];
}

static NSString *WitchRuntimeStatus(NSString *key, NSString *arg) {
    NSString *fmt = localize(key, nil);
    return arg.length > 0 ? [NSString stringWithFormat:fmt, arg] : fmt;
}

// Tải 1 URL với progress theo byte và trả file tạm khi xong.
// NSURLSession giữ delegate; session tự hủy sau khi hoàn tất.
@interface WitchURLDownloader : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, copy) void (^onProgress)(float fraction);
@property (nonatomic, copy) void (^onFinish)(NSString *filePath, NSError *error);
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation WitchURLDownloader

- (void)startWithURL:(NSURL *)url {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 60;
    self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    [[self.session downloadTaskWithURL:url] resume];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (self.onProgress && totalBytesExpectedToWrite > 0) {
        self.onProgress((float)((double)totalBytesWritten / (double)totalBytesExpectedToWrite));
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSInteger status = 200;
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        status = ((NSHTTPURLResponse *)downloadTask.response).statusCode;
    }
    [session finishTasksAndInvalidate];
    if (status >= 400) {
        if (self.onFinish) {
            self.onFinish(nil, WitchRuntimeError(3, [NSString stringWithFormat:@"HTTP %ld", (long)status]));
        }
        return;
    }
    NSString *ext = downloadTask.response.suggestedFilename.pathExtension;
    if (ext.length == 0) ext = downloadTask.originalRequest.URL.pathExtension;
    NSString *tmpName = [NSUUID UUID].UUIDString;
    if (ext.length > 0) tmpName = [tmpName stringByAppendingPathExtension:ext];
    NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpName];
    NSError *moveError = nil;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest] error:&moveError];
    if (self.onFinish) self.onFinish(moveError ? nil : dest, moveError);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) return;
    [session finishTasksAndInvalidate];
    if (self.onFinish) self.onFinish(nil, error);
}

@end

@interface WitchRuntimeService ()
@property (nonatomic, strong) NSDictionary *manifest;
@end

@implementation WitchRuntimeItem
- (BOOL)installed { return self.localVersion.length > 0; }
- (BOOL)updateAvailable {
    return self.installed && self.remoteVersion.length > 0 && ![self.remoteVersion isEqualToString:self.localVersion];
}
@end

@implementation WitchRuntimeService

+ (WitchRuntimeService *)shared {
    static WitchRuntimeService *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (NSString *)manifestURL {
    NSString *m = getPrefObject(@"witch.runtime_manifest");
    if ([m isKindOfClass:[NSString class]] && m.length > 8) return m;
    return @"https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/runtimes-latest/runtimes.json";
}

- (NSArray<WitchRuntimeItem *> *)builtinItems {
    NSMutableArray *arr = [NSMutableArray array];
    NSArray *defs = @[
        @{@"id": @"jre8", @"name": @"JDK 8", @"kind": @(0), @"important": @YES},
        @{@"id": @"jre17", @"name": @"JDK 17", @"kind": @(0), @"important": @NO},
        @{@"id": @"jre21", @"name": @"JDK 21", @"kind": @(0), @"important": @NO},
        @{@"id": @"jre25", @"name": @"JDK 25", @"kind": @(0), @"important": @YES},
        @{@"id": @"lwjgl333", @"name": @"LWJGL 3.3.3", @"kind": @(1), @"important": @YES},
        @{@"id": @"lwjgl336", @"name": @"LWJGL 3.3.6", @"kind": @(1), @"important": @NO},
        @{@"id": @"lwjgl341", @"name": @"LWJGL 3.4.1", @"kind": @(1), @"important": @YES},
    ];
    for (NSDictionary *d in defs) {
        WitchRuntimeItem *it = [[WitchRuntimeItem alloc] init];
        it.identifier = d[@"id"];
        it.displayName = d[@"name"];
        it.kind = [d[@"kind"] integerValue];
        it.important = [d[@"important"] boolValue];
        [arr addObject:it];
    }
    return arr;
}

- (NSString *)pojavHome {
    const char *h = getenv("POJAV_HOME");
    return h ? @(h) : NSTemporaryDirectory();
}

#pragma mark - Paths

- (NSString *)javaVersionKeyForItem:(WitchRuntimeItem *)item {
    return [item.identifier stringByReplacingOccurrencesOfString:@"jre" withString:@""];
}

// JavaLauncher dùng tên libs/lwjgl33|36|41 — giữ đúng quy ước đó cho bản tải thêm.
- (NSString *)lwjglDirectoryNameForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"lwjgl341"]) return @"lwjgl41";
    if ([identifier isEqualToString:@"lwjgl336"]) return @"lwjgl36";
    return @"lwjgl33";
}

- (NSString *)installDirectoryForItem:(WitchRuntimeItem *)item {
    if (item.kind == WitchRuntimeKindJDK) {
        return [[self pojavHome] stringByAppendingPathComponent:
                [NSString stringWithFormat:@"java_runtimes/java-%@-openjdk", [self javaVersionKeyForItem:item]]];
    }
    return [[self pojavHome] stringByAppendingPathComponent:
            [NSString stringWithFormat:@"lwjgl/%@", [self lwjglDirectoryNameForIdentifier:item.identifier]]];
}

- (NSString *)javaVersionFromReleaseLine:(NSString *)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange first = [line rangeOfString:@"\""];
    if (first.location == NSNotFound) return trimmed;
    NSRange rest = NSMakeRange(NSMaxRange(first), line.length - NSMaxRange(first));
    NSRange second = [line rangeOfString:@"\"" options:0 range:rest];
    if (second.location == NSNotFound) return trimmed;
    return [line substringWithRange:NSMakeRange(NSMaxRange(first), second.location - NSMaxRange(first))];
}

- (NSString *)localVersionForItem:(WitchRuntimeItem *)item {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (item.kind == WitchRuntimeKindJDK) {
        NSString *ver = [self javaVersionKeyForItem:item];
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        // User-selected folder (java.java_homes) first, then the default
        // install dir, then the bundled runtime.
        NSDictionary *homes = getPrefObject(@"java.java_homes");
        id external = [homes isKindOfClass:[NSDictionary class]] ? homes[ver] : nil;
        if ([external isKindOfClass:[NSString class]] && ![external isEqualToString:@"internal"]) {
            [candidates addObject:[NSString stringWithFormat:@"%@/java_runtimes/%@", [self pojavHome], external]];
        }
        [candidates addObject:[NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", [self pojavHome], ver]];
        [candidates addObject:[NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", NSBundle.mainBundle.bundlePath, ver]];
        for (NSString *dir in candidates) {
            NSString *release = [dir stringByAppendingPathComponent:@"release"];
            if (![fm fileExistsAtPath:release]) continue;
            NSString *content = [NSString stringWithContentsOfFile:release encoding:NSUTF8StringEncoding error:nil];
            // release: JAVA_VERSION="17.0.13" — expose just the version number
            // so it compares equal to the manifest version.
            for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
                if ([line containsString:@"JAVA_VERSION"]) {
                    return [self javaVersionFromReleaseLine:line];
                }
            }
            return @"installed";
        }
        return nil;
    } else {
        // LWJGL: version marker written after a full external install; the
        // bundled jnilibs in the app count as a fallback.
        NSString *marker = [NSString stringWithFormat:@"%@/lwjgl/%@/version.txt", [self pojavHome],
                            [self lwjglDirectoryNameForIdentifier:item.identifier]];
        if ([fm fileExistsAtPath:marker]) {
            return [[NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:nil]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        return @"bundled";
    }
}

#pragma mark - Refresh

- (void)refreshStatuses:(void(^)(NSArray<WitchRuntimeItem *> *, NSError *))completion {
    NSArray<WitchRuntimeItem *> *items = [self builtinItems];
    for (WitchRuntimeItem *it in items) {
        it.localVersion = [self localVersionForItem:it];
    }
    NSURL *url = [NSURL URLWithString:[self manifestURL]];
    if (!url) { completion(items, nil); return; }
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                self.manifest = json;
                for (WitchRuntimeItem *it in items) {
                    NSDictionary *e = json[it.identifier];
                    if ([e isKindOfClass:[NSDictionary class]]) {
                        it.remoteURL = e[@"url"];
                        it.remoteVersion = [e[@"version"] description];
                        it.remoteSize = [e[@"size"] longLongValue];
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(items, error); });
    }] resume];
}

#pragma mark - Install

- (void)downloadItem:(WitchRuntimeItem *)item progress:(void(^)(float, NSString *))progress completion:(void(^)(BOOL, NSError *))completion {
    // Completion luôn về main queue dù lỗi phát sinh từ delegate queue nào.
    void (^finish)(BOOL, NSError *) = ^(BOOL ok, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, error); });
    };
    if (!item.remoteURL.length) {
        // Manifest chưa có (repo JDK chưa publish): báo rõ để user không tưởng lỗi app
        finish(NO, WitchRuntimeError(404, localize(@"runtime.error_no_manifest", nil)));
        return;
    }
    void (^report)(float, NSString *) = ^(float fraction, NSString *status) {
        if (!progress) return;
        dispatch_async(dispatch_get_main_queue(), ^{ progress(fraction, status); });
    };
    if (item.kind == WitchRuntimeKindJDK) {
        [self installJDKItem:item report:report completion:finish];
    } else {
        [self installLWJGLItem:item report:report completion:finish];
    }
}

- (void)installJDKItem:(WitchRuntimeItem *)item report:(void(^)(float, NSString *))report completion:(void(^)(BOOL, NSError *))completion {
    NSString *target = [self installDirectoryForItem:item];
    report(0.02f, WitchRuntimeStatus(@"runtime.status_downloading", item.displayName));
    WitchURLDownloader *dl = [WitchURLDownloader new];
    dl.onProgress = ^(float f) {
        report(0.02f + 0.58f * f, WitchRuntimeStatus(@"runtime.status_downloading", item.displayName));
    };
    dl.onFinish = ^(NSString *file, NSError *error) {
        if (!file) { completion(NO, error); return; }
        report(0.62f, WitchRuntimeStatus(@"runtime.status_installing", item.displayName));
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *installError = nil;
            BOOL ok = [self installJDKArchive:file forItem:item target:target report:report error:&installError];
            [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
            if (ok) [self rescanRuntimes];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, installError); });
        });
    };
    [dl startWithURL:[NSURL URLWithString:item.remoteURL]];
}

- (BOOL)installJDKArchive:(NSString *)archive forItem:(WitchRuntimeItem *)item target:(NSString *)target
                   report:(void(^)(float, NSString *))report error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:target error:nil];
    [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:nil];

    NSError *extractError = nil;
    if (![self extractArchive:archive to:target report:report base:0.62f span:0.34f item:item error:&extractError]) {
        [fm removeItemAtPath:target error:nil];
        if (error) *error = extractError;
        return NO;
    }
    NSString *release = [target stringByAppendingPathComponent:@"release"];
    if (![fm fileExistsAtPath:release]) {
        [fm removeItemAtPath:target error:nil];
        if (error) *error = WitchRuntimeError(5, localize(@"runtime.error_release_missing", nil));
        return NO;
    }
    // Các archive trên JDK repo không đồng nhất: jre8 không có marker, jre17
    // có marker nhưng libjvm chưa patch brk hooks — cả hai đều khiến launcher
    // hiện dialog "runtime does not support JIT" hoặc treo trong JLI_Launch
    // trên iOS 26+. Patch ngay trên file trước khi runtime được load lần đầu
    // (sau khi load, __TEXT đã ký nên iOS 27 từ chối mọi ghi đè).
    report(0.97f, WitchRuntimeStatus(@"runtime.status_installing", item.displayName));
    if (!witch_jre_ensure_jit_ready(target.fileSystemRepresentation)) {
        NSLog(@"[WitchRuntimeService] JIT readiness check failed for %@ (libjvm missing/not mirror-capable)", target);
        [fm removeItemAtPath:target error:nil];
        if (error) *error = WitchRuntimeError(6, localize(@"runtime.error_jit_patch_failed", nil));
        return NO;
    }
    [self registerInstalledJDKForItem:item];
    report(0.99f, WitchRuntimeStatus(@"runtime.status_installing", item.displayName));
    return YES;
}

// Đăng ký vào java.java_homes để getSelectedJavaHome() tìm thấy ngay,
// nhưng không ghi đè lựa chọn đang hoạt động của user.
- (void)registerInstalledJDKForItem:(WitchRuntimeItem *)item {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *ver = [self javaVersionKeyForItem:item];
    NSString *folder = [NSString stringWithFormat:@"java-%@-openjdk", ver];
    NSMutableDictionary *homes = nil;
    NSDictionary *existing = getPrefObject(@"java.java_homes");
    homes = [existing isKindOfClass:[NSDictionary class]] ? [existing mutableCopy] : [NSMutableDictionary dictionary];

    id current = homes[ver];
    BOOL needsInstall = NO;
    if (![current isKindOfClass:[NSString class]] || [current length] == 0) {
        needsInstall = YES;
    } else if ([current isEqualToString:@"internal"]) {
        NSString *bundlePath = [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", NSBundle.mainBundle.bundlePath, ver];
        needsInstall = ![fm fileExistsAtPath:bundlePath];
    } else {
        NSString *path = [NSString stringWithFormat:@"%@/java_runtimes/%@", [self pojavHome], current];
        needsInstall = ![fm fileExistsAtPath:path];
    }
    if (needsInstall) {
        homes[ver] = folder;
        setPrefObject(@"java.java_homes", homes);
    }
}

- (void)installLWJGLItem:(WitchRuntimeItem *)item report:(void(^)(float, NSString *))report completion:(void(^)(BOOL, NSError *))completion {
    NSString *target = [self installDirectoryForItem:item];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:nil];

    report(0.02f, WitchRuntimeStatus(@"runtime.status_downloading", item.displayName));
    WitchURLDownloader *jarDl = [WitchURLDownloader new];
    jarDl.onProgress = ^(float f) {
        report(0.02f + 0.33f * f, WitchRuntimeStatus(@"runtime.status_downloading", item.displayName));
    };
    jarDl.onFinish = ^(NSString *jarFile, NSError *error) {
        if (!jarFile) { completion(NO, error); return; }
        // Launcher's classpath expects a single lwjgl.jar next to natives/.
        NSString *jarDest = [target stringByAppendingPathComponent:@"lwjgl.jar"];
        [fm removeItemAtPath:jarDest error:nil];
        NSError *moveError = nil;
        [fm moveItemAtPath:jarFile toPath:jarDest error:&moveError];
        if (moveError) { completion(NO, moveError); return; }

        NSDictionary *entry = self.manifest[[item.identifier stringByAppendingString:@"-natives"]];
        if (![entry isKindOfClass:[NSDictionary class]]) entry = nil;
        NSString *nativesURL = entry[@"url"];
        if (!nativesURL.length) {
            // Manifest chỉ có jar (hoặc đang dùng cache cũ): cài jar trước,
            // lần refresh sau sẽ bổ sung natives.
            [self finishLWJGLInstallForItem:item target:target report:report completion:completion];
            return;
        }
        report(0.36f, WitchRuntimeStatus(@"runtime.status_downloading",
                                         [NSString stringWithFormat:@"%@ natives", item.displayName]));
        WitchURLDownloader *nativesDl = [WitchURLDownloader new];
        nativesDl.onProgress = ^(float f) {
            report(0.36f + 0.32f * f, WitchRuntimeStatus(@"runtime.status_downloading",
                                                         [NSString stringWithFormat:@"%@ natives", item.displayName]));
        };
        nativesDl.onFinish = ^(NSString *nativesFile, NSError *error) {
            if (!nativesFile) { completion(NO, error); return; }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSString *nativesDir = [target stringByAppendingPathComponent:@"natives"];
                [fm removeItemAtPath:nativesDir error:nil];
                [fm createDirectoryAtPath:nativesDir withIntermediateDirectories:YES attributes:nil error:nil];
                NSError *extractError = nil;
                BOOL ok = [self extractArchive:nativesFile to:nativesDir report:report base:0.70f span:0.28f
                                          item:item error:&extractError];
                [[NSFileManager defaultManager] removeItemAtPath:nativesFile error:nil];
                if (!ok) {
                    [[NSFileManager defaultManager] removeItemAtPath:target error:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, extractError); });
                    return;
                }
                [self finishLWJGLInstallForItem:item target:target report:report completion:completion];
            });
        };
        [nativesDl startWithURL:[NSURL URLWithString:nativesURL]];
    };
    [jarDl startWithURL:[NSURL URLWithString:item.remoteURL]];
}

- (void)finishLWJGLInstallForItem:(WitchRuntimeItem *)item target:(NSString *)target
                           report:(void(^)(float, NSString *))report completion:(void(^)(BOOL, NSError *))completion {
    NSString *version = item.remoteVersion.length > 0 ? item.remoteVersion : @"unknown";
    NSString *marker = [target stringByAppendingPathComponent:@"version.txt"];
    [version writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    report(0.99f, WitchRuntimeStatus(@"runtime.status_installing", item.displayName));
    [self rescanRuntimes];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
}

#pragma mark - Extraction

// Downloads may land with no extension (temp names); sniff magic bytes so
// archives keep working even when the URL/server hides the format.
static NSString *WitchArchiveExtensionForFile(NSString *path) {
    NSString *ext = path.pathExtension.lowercaseString;
    if (ext.length > 0) return ext;
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) return ext;
    NSData *magic = [fh readDataOfLength:8];
    [fh closeFile];
    if (magic.length >= 6) {
        const uint8_t *b = magic.bytes;
        if (b[0] == 0xFD && b[1] == '7' && b[2] == 'z' && b[3] == 'X' && b[4] == 'Z' && b[5] == 0x00) return @"xz";
        if (b[0] == 'P' && b[1] == 'K') return @"zip";
    }
    return ext;
}

- (BOOL)extractArchive:(NSString *)archive to:(NSString *)target report:(void(^)(float, NSString *))report
                  base:(float)base span:(float)span item:(WitchRuntimeItem *)item error:(NSError **)error {
    NSString *ext = WitchArchiveExtensionForFile(archive);
    if ([ext isEqualToString:@"xz"] || [ext isEqualToString:@"txz"]) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:archive error:nil];
        unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:(int64_t)MAX(1ULL, size)];
        NSProgress *fileProgress = [NSProgress progressWithTotalUnitCount:1];
        NSString *msg = [LauncherPrefManageJREViewController extractTarXZ:archive to:target progress:progress
                                                              fileProgress:fileProgress fileCallback:^(NSString *name) {
            report(base + span * (float)progress.fractionCompleted,
                   WitchRuntimeStatus(@"runtime.status_extracting", name.lastPathComponent));
        }];
        if (msg) {
            if (error) *error = WitchRuntimeError(10, [NSString stringWithFormat:localize(@"runtime.error_extract", nil), msg]);
            return NO;
        }
        return YES;
    }
    if ([ext isEqualToString:@"zip"]) {
        report(base, WitchRuntimeStatus(@"runtime.status_extracting", archive.lastPathComponent));
        NSError *zipError = nil;
        UZKArchive *zip = [[UZKArchive alloc] initWithPath:archive error:&zipError];
        if (!zip || ![zip extractFilesTo:target overwrite:YES error:&zipError]) {
            if (error) *error = zipError ?: WitchRuntimeError(11, [NSString stringWithFormat:localize(@"runtime.error_extract", nil), @"zip"]);
            return NO;
        }
        report(base + span, WitchRuntimeStatus(@"runtime.status_extracting", archive.lastPathComponent));
        return YES;
    }
    if (error) *error = WitchRuntimeError(12, [NSString stringWithFormat:@"Unsupported archive: %@", archive.lastPathComponent]);
    return NO;
}

#pragma mark - Delete

- (BOOL)deleteItem:(WitchRuntimeItem *)item error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (item.kind == WitchRuntimeKindJDK) {
        // Only external (POJAV_HOME) is deletable; internal bundle copy is protected.
        NSString *dir = [self installDirectoryForItem:item];
        if ([fm fileExistsAtPath:dir]) {
            BOOL ok = [fm removeItemAtPath:dir error:error];
            [self rescanRuntimes];
            return ok;
        }
        if (error) *error = WitchRuntimeError(1, localize(@"runtime.error_builtin_jdk", nil));
        return NO;
    } else {
        NSString *dir = [self installDirectoryForItem:item];
        if ([fm fileExistsAtPath:dir]) {
            BOOL ok = [fm removeItemAtPath:dir error:error];
            [self rescanRuntimes];
            return ok;
        }
        if (error) *error = WitchRuntimeError(2, localize(@"runtime.error_builtin_lwjgl", nil));
        return NO;
    }
}

- (void)rescanRuntimes {
    // Cài luôn không restart: post notification để ManageJRE VC reload;
    // JavaLauncher reads paths lazily per-launch nên không cần restart app.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WitchRuntimesDidChange" object:nil];
    });
}

@end
