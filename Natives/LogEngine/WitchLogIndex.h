#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Sparse line index: every N lines stores (line -> byteOffset).
/// Lets the viewer seek directly instead of reading the whole file.
/// All heavy work runs on a background serial queue; completions hop to main.
@interface WitchLogCheckpoint : NSObject
@property (nonatomic) NSUInteger line; // 0-based line number starting at this offset
@property (nonatomic) unsigned long long byteOffset;
@end

@interface WitchLogFileInfo : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic) unsigned long long fileSize;
@property (nonatomic, strong, nullable) NSDate *modDate;
@property (nonatomic) NSUInteger lineCount; // NSNotFound until indexed
@property (nonatomic, copy) NSArray<WitchLogCheckpoint *> *checkpoints;
/// Nearest checkpoint with checkpoint.line <= targetLine (nil if none).
- (nullable WitchLogCheckpoint *)checkpointAtOrBeforeLine:(NSUInteger)targetLine;
@end

@interface WitchLogIndexer : NSObject
/// Lines between checkpoints. 4096 is a good default.
- (instancetype)initWithPath:(NSString *)path checkpointEvery:(NSUInteger)lines;
- (void)cancel;
@property (nonatomic, readonly) BOOL cancelled;
/// Build index (or load valid .witchidx sidecar). Progress/completion on main queue.
- (void)buildWithProgress:(void (^)(double fraction))progress
               completion:(void (^)(WitchLogFileInfo * _Nullable info, NSError * _Nullable error))completion;
/// Synchronous variant. MUST be called off the main thread.
- (nullable WitchLogFileInfo *)syncBuildWithError:(NSError **)outError;
@end

@interface WitchLogReader : NSObject
- (instancetype)initWithFileInfo:(WitchLogFileInfo *)info;
@property (nonatomic, strong, readonly) WitchLogFileInfo *fileInfo;

/// Random access read of lines [start, start+count). Completion on main queue.
/// count is capped internally (5000) and overlong lines truncated.
- (void)readLinesFrom:(NSUInteger)start
                count:(NSUInteger)count
           completion:(void (^)(NSArray<NSString *> *lines, NSUInteger actualStart))completion;

/// Last N lines of the file without loading the whole file. Completion on main queue.
- (void)readTail:(NSUInteger)maxLines
      completion:(void (^)(NSArray<NSString *> *lines, NSUInteger startLine))completion;

/// Synchronous variants. MUST be called off the main thread.
- (NSArray<NSString *> *)syncReadLinesFrom:(NSUInteger)start
                                     count:(NSUInteger)count
                               actualStart:(nullable NSUInteger *)outStart;
- (NSArray<NSString *> *)syncReadTail:(NSUInteger)maxLines
                            startLine:(nullable NSUInteger *)outStart;

/// Stream all lines in batches on the caller's (background) thread.
/// Stops early when *stop=YES or maxBytes of file content is consumed.
- (void)syncEnumerateLinesWithMaxBytes:(unsigned long long)maxBytes
                            batchSize:(NSUInteger)batchSize
                              handler:(void (^)(NSArray<NSString *> *batch, NSUInteger startLine, BOOL *stop))handler;

/// Streaming SHA-256 of the raw file, bounded RAM. MUST be called off main thread.
- (nullable NSString *)syncSHA256Hex;
@end

/// Decode one raw log line (split on 0x0A beforehand, so UTF-8 boundaries are safe).
/// Falls back to CP1252 when bytes are not valid UTF-8; truncates overlong lines.
FOUNDATION_EXPORT NSString *WitchDecodeLogLine(const uint8_t *bytes, NSUInteger len);

NS_ASSUME_NONNULL_END
