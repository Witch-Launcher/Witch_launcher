#import <Foundation/Foundation.h>
#import "WitchLogIndex.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WitchLogCategory) {
    WitchLogCategoryModConflict = 0,
    WitchLogCategoryError,
    WitchLogCategoryRaw,
};

/// Bounded crash snapshot built with streaming I/O (never loads whole files).
/// Completions are invoked on the main queue; sync variants must run off main.
@interface WitchLogSnapshotResult : NSObject
@property (nonatomic) WitchLogCategory category;
@property (nonatomic, copy) NSString *snapshot;   // capped at maxBytes (UTF-8)
@property (nonatomic, copy) NSString *excerpt;    // last 100 lines, joined
@property (nonatomic) NSUInteger totalLines;      // NSNotFound if unknown
@property (nonatomic) unsigned long long totalBytes;
@property (nonatomic, copy, nullable) NSString *modloaderMessage;
@end

@interface WitchLogSnapshotter : NSObject
+ (void)buildWithLatestLog:(nullable NSString *)latestPath
                 crashPath:(nullable NSString *)crashPath
                  hsErrPath:(nullable NSString *)hsErrPath
                   exitCode:(int)code
                   metadata:(nullable NSDictionary<NSString *, NSString *> *)metadata
                   maxBytes:(NSUInteger)maxBytes
                 completion:(void (^)(WitchLogSnapshotResult *result))completion;

/// Synchronous variant. MUST be called off the main thread.
+ (WitchLogSnapshotResult *)syncBuildWithLatestLog:(nullable NSString *)latestPath
                                         crashPath:(nullable NSString *)crashPath
                                          hsErrPath:(nullable NSString *)hsErrPath
                                           exitCode:(int)code
                                           metadata:(nullable NSDictionary<NSString *, NSString *> *)metadata
                                           maxBytes:(NSUInteger)maxBytes;

/// Bounded helpers for other subsystems (safe for multi-MB files).
/// Head read (stack traces start at the top of hs_err/crash files).
+ (NSString *)cappedHeadOfFile:(nullable NSString *)path maxBytes:(NSUInteger)maxBytes;
/// Tail lines without loading the whole file.
+ (NSArray<NSString *> *)tailLinesOfFile:(nullable NSString *)path maxLines:(NSUInteger)maxLines;
@end

NS_ASSUME_NONNULL_END
