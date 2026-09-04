#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CrashLogCategory) {
    CrashLogCategoryModConflict = 0,
    CrashLogCategoryError,
    CrashLogCategoryRaw
};

@interface CrashLogAnalyzerResult : NSObject
@property (nonatomic) CrashLogCategory category;
@property (nonatomic, copy) NSString *excerpt; // last 100 lines (always available)
/// Bounded AI payload (~tens of KB): metadata + modloader message + error
/// context + tail. This is what Quick Analysis sends — never the whole file.
@property (nonatomic, copy) NSString *snapshot;
/// Full concatenated log. ONLY populated when the total size is small
/// (<= 1MB). NIL for large logs — use Log Viewer (indexed) or Deep Upload.
@property (nonatomic, copy, nullable) NSString *fullLog;
@property (nonatomic, copy, nullable) NSString *latestLogPath;
@property (nonatomic, copy, nullable) NSString *crashReportPath;
@property (nonatomic, copy, nullable) NSString *hsErrPath;
@property (nonatomic) unsigned long long totalBytes;
@end

@interface CrashLogAnalyzer : NSObject

/// Streaming analysis: never loads whole files into RAM.
/// Safe to call on any thread, but prefer background (snapshot scan ~0.1s).
+ (CrashLogAnalyzerResult *)analyzeWithExitCode:(int)code;

/// Re-scan the filesystem for latestlog/crash/hs_err and update `result`
/// in place. Call this when the user switches tabs — crash reports are often
/// written a moment AFTER the crash screen appears, so a cached nil would
/// otherwise leave the Crash/hs_err tabs permanently disabled ("có file mà
/// không cho xem"). Safe on any thread; does only stat + dir listing.
+ (void)refreshPathsForResult:(CrashLogAnalyzerResult *)result;

/// Latest known paths without building a full result (for viewer fallback).
+ (nullable NSString *)latestLogPath;
+ (nullable NSString *)newestCrashReportPath;
+ (nullable NSString *)newestHsErrPath;

@end

NS_ASSUME_NONNULL_END
