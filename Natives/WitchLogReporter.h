#import <Foundation/Foundation.h>
#import "CrashLogAnalyzer.h"

NS_ASSUME_NONNULL_BEGIN

@interface WitchLogReporter : NSObject

/// Collect all logs: latestlog, crash, hs_err + 20-line check for extra references
+ (NSDictionary*)collectLogPayloadWithAnalysis:(CrashLogAnalyzerResult*)analysis;

/// Send to server (requires witch.server_enabled). Calls completion on main queue.
+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                      exitCode:(int)code
                    completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

/// With user note (ghi chú) - will be checked for banned words before sending to Discord
+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                      exitCode:(int)code
                          note:(nullable NSString*)note
                    completion:(void(^)(BOOL success, NSString * _Nullable logId, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
