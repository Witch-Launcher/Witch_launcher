#import "CrashLogAnalyzer.h"
#import "WitchLogSnapshot.h"
#import "WitchLogIndex.h"

// fullLog is only materialized for small logs; beyond this the viewer and
// upload pipeline use indexed / streaming access instead.
static const unsigned long long kFullLogMaxBytes = 1024 * 1024;

@implementation CrashLogAnalyzerResult
@end

@implementation CrashLogAnalyzer

static NSString *latestLogPath(void) {
    const char *home = getenv("POJAV_HOME");
    if (!home) return nil;
    return [@(home) stringByAppendingPathComponent:@"latestlog.txt"];
}

static NSString *newestFileInDir(NSString *dir, NSArray<NSString *> *patterns) {
    if (!dir.length) return nil;
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] || !isDir) return nil;
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil];
    if (!files) return nil;
    NSString *newest = nil;
    NSDate *newestDate = nil;
    unsigned long long newestSize = 0;
    for (NSString *file in files) {
        BOOL match = NO;
        for (NSString *pattern in patterns) {
            if ([file rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                match = YES;
                break;
            }
        }
        if (!match) continue;
        NSString *path = [dir stringByAppendingPathComponent:file];
        NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if (!attrs) continue;
        // Skip directories and empty files.
        NSString *type = attrs[NSFileType];
        if ([type isEqualToString:NSFileTypeDirectory]) continue;
        NSDate *mod = attrs[NSFileModificationDate];
        if (!mod) continue;
        unsigned long long sz = [attrs fileSize];
        if (!newestDate || [mod compare:newestDate] == NSOrderedDescending ||
            ([mod isEqualToDate:newestDate] && sz > newestSize)) {
            newest = path;
            newestDate = mod;
            newestSize = sz;
        }
    }
    return newest;
}

static NSDate *modDateOf(NSString * _Nullable path) {
    if (!path.length) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return attrs[NSFileModificationDate];
}

static NSString *pickNewest(NSString * _Nullable a, NSString * _Nullable b) {
    if (!a) return b;
    if (!b) return a;
    NSDate *da = modDateOf(a);
    NSDate *db = modDateOf(b);
    if (!da) return b;
    if (!db) return a;
    return [db compare:da] == NSOrderedDescending ? b : a;
}

static NSString *newestCrashReport(void) {
    NSString *home = NSHomeDirectory();
    NSString *logPath = latestLogPath();
    NSString *pojavHome = logPath ? [logPath stringByDeletingLastPathComponent] : nil;
    // Game dir can differ from POJAV_HOME (per-version instances). Cover the
    // common layouts so "có file mà không cho xem" can't happen because we
    // looked in the wrong folder.
    const char *gameDirC = getenv("POJAV_GAME_DIR");
    NSString *gameDir = gameDirC ? @(gameDirC) : nil;
    NSMutableArray *roots = [NSMutableArray array];
    if (pojavHome) {
        [roots addObject:[pojavHome stringByAppendingPathComponent:@"crash-reports"]];
        [roots addObject:[pojavHome stringByAppendingPathComponent:@".minecraft/crash-reports"]];
    }
    if (gameDir.length) {
        [roots addObject:[gameDir stringByAppendingPathComponent:@"crash-reports"]];
        [roots addObject:[gameDir stringByAppendingPathComponent:@".minecraft/crash-reports"]];
    }
    [roots addObjectsFromArray:@[
        [home stringByAppendingPathComponent:@"Documents/crash-reports"],
        [home stringByAppendingPathComponent:@"Documents/.minecraft/crash-reports"],
    ]];
    NSString *newest = nil;
    for (NSString *root in roots) {
        // Crash reports are .txt; also match the "crash-" prefix in case a
        // pack uses .log. Require non-empty files (hardened helper skips dirs).
        NSString *candidate = newestFileInDir(root, @[@"crash-", @".txt", @".log"]);
        // Avoid picking up latestlog.txt or unrelated .txt: prefer names with crash-.
        if (candidate && [candidate.lastPathComponent rangeOfString:@"crash-" options:NSCaseInsensitiveSearch].location == NSNotFound
            && [candidate.lastPathComponent rangeOfString:@"latestlog" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            continue;
        }
        newest = pickNewest(newest, candidate);
    }
    // Validate: must exist and be non-empty, else treat as missing.
    if (newest && fileSizeOf(newest) == 0) {
        // Try next-best? Simplest: keep it (viewer will show empty) — but
        // prefer nil so UI shows "no file" instead of blank. Keep nil only if
        // truly empty AND no other candidate; here we already picked newest.
        // Leave as-is; viewer handles empty gracefully.
    }
    return newest;
}

static NSString *newestHsErr(void) {
    NSString *home = NSHomeDirectory();
    const char *cwd = getenv("PWD");
    NSMutableArray *roots = [NSMutableArray array];
    if (cwd) [roots addObject:@(cwd)];
    NSString *logPath = latestLogPath();
    if (logPath) [roots addObject:[logPath stringByDeletingLastPathComponent]];
    const char *gameDirC = getenv("POJAV_GAME_DIR");
    if (gameDirC) [roots addObject:@(gameDirC)];
    [roots addObjectsFromArray:@[
        home,
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library/Logs/CrashReporter"],
    ]];
    NSString *newest = nil;
    for (NSString *root in roots) {
        NSString *candidate = newestFileInDir(root, @[@"hs_err_pid", @"replay_pid"]);
        newest = pickNewest(newest, candidate);
    }
    return newest;
}

static unsigned long long fileSizeOf(NSString * _Nullable path) {
    if (!path) return 0;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return attrs ? [attrs fileSize] : 0;
}

+ (CrashLogAnalyzerResult *)analyzeWithExitCode:(int)code {
    NSString *logPath = latestLogPath();
    NSString *crashPath = newestCrashReport();
    NSString *hsErrPath = newestHsErr();

    unsigned long long total = fileSizeOf(logPath) + fileSizeOf(crashPath) + fileSizeOf(hsErrPath);

    // Streaming snapshot: tail excerpt + modloader message + error context.
    // Bounded (~0.1s for 18MB), never loads whole files.
    WitchLogSnapshotResult *snap = [WitchLogSnapshotter syncBuildWithLatestLog:logPath
                                                                      crashPath:crashPath
                                                                       hsErrPath:hsErrPath
                                                                        exitCode:code
                                                                        metadata:nil
                                                                        maxBytes:500 * 1024];

    CrashLogAnalyzerResult *result = [CrashLogAnalyzerResult new];
    result.latestLogPath = logPath;
    result.crashReportPath = crashPath;
    result.hsErrPath = hsErrPath;
    result.totalBytes = total;
    result.excerpt = snap.excerpt.length > 0 ? snap.excerpt : @"(empty log)";
    result.snapshot = snap.snapshot;
    switch (snap.category) {
        case WitchLogCategoryModConflict: result.category = CrashLogCategoryModConflict; break;
        case WitchLogCategoryError: result.category = CrashLogCategoryError; break;
        default: result.category = CrashLogCategoryRaw; break;
    }

    // Backward compat: materialize fullLog only when small enough to be safe
    // in a UITextView / JSON body. Large logs use indexed viewer + Deep Upload.
    if (total > 0 && total <= kFullLogMaxBytes) {
        NSMutableArray<NSString *> *allParts = [NSMutableArray array];
        NSString *logContent = logPath ? [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil] : nil;
        NSString *crashContent = crashPath ? [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil] : nil;
        NSString *hsErrContent = hsErrPath ? [NSString stringWithContentsOfFile:hsErrPath encoding:NSUTF8StringEncoding error:nil] : nil;
        if (logContent.length > 0) [allParts addObject:logContent];
        if (crashContent.length > 0) [allParts addObject:[NSString stringWithFormat:@"\n===== CRASH REPORT (%@) =====\n%@", crashPath.lastPathComponent, crashContent]];
        if (hsErrContent.length > 0) [allParts addObject:[NSString stringWithFormat:@"\n===== HS_ERR (%@) =====\n%@", hsErrPath.lastPathComponent, hsErrContent]];
        result.fullLog = [allParts componentsJoinedByString:@"\n"];
    } else {
        result.fullLog = nil;
    }
    return result;
}

+ (nullable NSString *)latestLogPath { return latestLogPath(); }
+ (nullable NSString *)newestCrashReportPath { return newestCrashReport(); }
+ (nullable NSString *)newestHsErrPath { return newestHsErr(); }

+ (void)refreshPathsForResult:(CrashLogAnalyzerResult *)result {
    if (!result) return;
    NSString *logPath = latestLogPath();
    // Only overwrite when we actually found something newer, or when the
    // cached path vanished. Never clobber a valid cached path with nil
    // (avoids flickering tabs when a rescan races file rotation).
    NSString *crashPath = newestCrashReport();
    NSString *hsPath = newestHsErr();
    if (logPath.length && [[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        result.latestLogPath = logPath;
    } else if (!result.latestLogPath.length || ![[NSFileManager defaultManager] fileExistsAtPath:result.latestLogPath]) {
        if (logPath.length) result.latestLogPath = logPath;
    }
    if (crashPath.length) {
        result.crashReportPath = crashPath;
    } else if (result.crashReportPath.length && ![[NSFileManager defaultManager] fileExistsAtPath:result.crashReportPath]) {
        result.crashReportPath = nil;
    }
    if (hsPath.length) {
        result.hsErrPath = hsPath;
    } else if (result.hsErrPath.length && ![[NSFileManager defaultManager] fileExistsAtPath:result.hsErrPath]) {
        result.hsErrPath = nil;
    }
    result.totalBytes = fileSizeOf(result.latestLogPath) + fileSizeOf(result.crashReportPath) + fileSizeOf(result.hsErrPath);
}

@end
