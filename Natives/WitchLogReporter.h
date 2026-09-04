#import <Foundation/Foundation.h>
#import "CrashLogAnalyzer.h"
#import "WitchLogUpload.h"

NS_ASSUME_NONNULL_BEGIN

@interface WitchLogReporter : NSObject

/// Shared uploader configured with Witch base URL + auth headers.
/// Nil when no server is configured. All work happens off the main thread.
+ (nullable WitchLogUploader *)sharedUploader;

/// Bounded JSON payload (excerpt + snapshot, capped crash/hs_err tails).
/// Pure function of small strings — cheap, but call off main anyway.
+ (NSDictionary*)collectLogPayloadWithAnalysis:(CrashLogAnalyzerResult*)analysis;

/// Send report (snapshot + log files streamed from disk, bounded RAM).
/// Files are attached raw so Discord previews keep working.
/// Returns the upload job (cancel-able). Progress/completion on main queue.
+ (WitchLogUploadJob *)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                     exitCode:(int)code
                                     progress:(nullable void(^)(double fraction))progress
                                   completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

/// Legacy entry points (no progress). Kept for existing callers.
+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                      exitCode:(int)code
                    completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                      exitCode:(int)code
                          note:(nullable NSString*)note
                    completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

/// Full entry point with user note.
+ (WitchLogUploadJob *)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                     exitCode:(int)code
                                         note:(nullable NSString*)note
                                     progress:(nullable void(^)(double fraction))progress
                                   completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

/// Deep Analysis: gzip + chunked resumable upload of the full latestlog
/// (falls back to single-shot on old servers). Snapshot travels in the
/// payload so AI has immediate context. Returns the upload job.
+ (WitchLogUploadJob *)sendDeepReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                         exitCode:(int)code
                                             note:(nullable NSString*)note
                                         progress:(nullable void(^)(double fraction))progress
                                       completion:(void(^)(BOOL success, NSString * _Nullable serverID, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
