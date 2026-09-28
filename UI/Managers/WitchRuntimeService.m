#import "WitchRuntimeService.h"
#import "LauncherPreferences.h"

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

- (NSString *)localVersionForItem:(WitchRuntimeItem *)item {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (item.kind == WitchRuntimeKindJDK) {
        // java_runtimes/java-<ver>-openjdk/release (+ external POJAV_HOME copy)
        NSString *ver = [[item.identifier stringByReplacingOccurrencesOfString:@"jre" withString:@""] copy];
        NSArray *candidates = @[
            [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk/release", NSBundle.mainBundle.bundlePath, ver],
            [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk/release", [self pojavHome], ver],
        ];
        for (NSString *p in candidates) {
            if ([fm fileExistsAtPath:p]) {
                NSString *content = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
                // release file: JAVA_VERSION="1.8.0_472" etc. Use first matching line.
                for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
                    if ([line containsString:@"JAVA_VERSION"]) return [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                }
                return @"installed";
            }
        }
        return nil;
    } else {
        // LWJGL: check internal bundle + external override marker
        // Internal always exists for full builds; external marker allows update/delete.
        NSString *marker = [NSString stringWithFormat:@"%@/lwjgl/%@/version.txt", [self pojavHome], item.identifier];
        if ([fm fileExistsAtPath:marker]) {
            return [[NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        // Fallback: bundled counts as installed (non-deletable legacy)
        return @"bundled";
    }
}

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

- (void)downloadItem:(WitchRuntimeItem *)item progress:(void(^)(float))progress completion:(void(^)(BOOL, NSError *))completion {
    if (!item.remoteURL.length) {
        // Manifest chưa có (repo JDK chưa publish): báo rõ để user không tưởng lỗi app
        NSError *e = [NSError errorWithDomain:@"WitchRuntime" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Chưa có manifest runtimes.json trên JDK-Java_iOS (runtimes-latest). Hãy publish repo JDK trước, hoặc import tay file .tar.xz trong Manage Runtime."}];
        completion(NO, e);
        return;
    }
    NSURL *url = [NSURL URLWithString:item.remoteURL];
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *tmp, NSURLResponse *resp, NSError *error) {
        if (error) { dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, error); }); return; }
        // Copy into POJAV_HOME staging; extraction (tar.xz) reuses existing import flow.
        // For now: keep file in Documents for user to import (phase 2 will auto-extract).
        NSString *dest = [[self pojavHome] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-download/%@", @"runtimes", tmp.lastPathComponent ?: item.identifier]];
        [[NSFileManager defaultManager] createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        NSError *me = nil;
        [[NSFileManager defaultManager] moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&me];
        if (me) { dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, me); }); return; }
        // Write version marker so updateAvailable clears without restart
        if (item.remoteVersion) {
            NSString *marker = [[self pojavHome] stringByAppendingPathComponent:[NSString stringWithFormat:@"lwjgl/%@/version.txt", item.identifier]];
            if (item.kind == WitchRuntimeKindJDK) {
                // JDK marker lives next to runtime dir; rescan will pick real release file after extract.
                // Store pending version so UI shows downloaded state.
                setPrefObject([NSString stringWithFormat:@"witch.runtime_pending_%@", item.identifier], item.remoteVersion);
            } else {
                [[NSFileManager defaultManager] createDirectoryAtPath:[marker stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                [item.remoteVersion writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
        }
        [self rescanRuntimes];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
    }];
    if (progress) progress(0.1f);
    [task resume];
}

- (BOOL)deleteItem:(WitchRuntimeItem *)item error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (item.kind == WitchRuntimeKindJDK) {
        // Only external (POJAV_HOME) is deletable; internal bundle copy is protected.
        NSString *ver = [item.identifier stringByReplacingOccurrencesOfString:@"jre" withString:@""];
        NSString *ext = [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", [self pojavHome], ver];
        if ([fm fileExistsAtPath:ext]) {
            BOOL ok = [fm removeItemAtPath:ext error:error];
            [self rescanRuntimes];
            return ok;
        }
        if (error) *error = [NSError errorWithDomain:@"WitchRuntime" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Bản built-in trong app không xóa được (chỉ xóa được bản tải thêm ở POJAV_HOME)."}];
        return NO;
    } else {
        NSString *dir = [[self pojavHome] stringByAppendingPathComponent:[NSString stringWithFormat:@"lwjgl/%@", item.identifier]];
        if ([fm fileExistsAtPath:dir]) {
            BOOL ok = [fm removeItemAtPath:dir error:error];
            [self rescanRuntimes];
            return ok;
        }
        if (error) *error = [NSError errorWithDomain:@"WitchRuntime" code:2 userInfo:@{NSLocalizedDescriptionKey: @"LWJGL built-in trong app chưa hỗ trợ xóa (chờ chuyển sang POJAV_HOME)."}];
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
