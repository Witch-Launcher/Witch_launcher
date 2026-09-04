#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WitchUploadState) {
    WitchUploadStatePending = 0,
    WitchUploadStatePreparing,
    WitchUploadStateUploading,
    WitchUploadStatePaused,
    WitchUploadStateCompleted,
    WitchUploadStateFailed,
};

/// Handle for an in-flight upload. Progress/completion always on main queue.
@interface WitchLogUploadJob : NSObject
@property (nonatomic, copy, readonly) NSString *jobID;
@property (nonatomic) WitchUploadState state;
@property (nonatomic) double progress; // 0..1
@property (nonatomic, copy, nullable) NSString *serverID; // logId / job_id
@property (nonatomic, strong, nullable) NSError *error;
- (void)cancel;
@end

/// File entry for multipart upload. Streaming from disk, never fully in RAM.
@interface WitchUploadFile : NSObject
@property (nonatomic, copy) NSString *name; // remote filename
@property (nonatomic, copy) NSString *path; // local file path
+ (instancetype)fileWithName:(NSString *)name path:(NSString *)path;
@end

/// Server contract for chunked upload (Phase-3 Witch server):
///   POST {base}/v1/logs/upload/init      {fileName,fileSize,sha256,chunkSize,compressed}
///     -> {uploadId, received:[...]}
///   GET  {base}/v1/logs/upload/{id}/status -> {received:[...], totalChunks}
///   POST {base}/v1/logs/upload/{id}/chunk?index=N  (octet-stream, X-Chunk-SHA256)
///     -> {received:[...]}
///   POST {base}/v1/logs/upload/{id}/complete {payload...} -> {logId / job_id}
/// If /init answers 404 (old server), the uploader transparently falls back
/// to single-shot multipart POST /v1/logs/report.
@interface WitchLogUploader : NSObject

/// authHandler fills Authorization / HMAC / device / attest headers.
/// bodyHint is the string the HMAC should cover (payload JSON for multipart,
/// per-request JSON for chunk protocol).
typedef void (^WitchAuthHandler)(NSMutableURLRequest *req, NSString * _Nullable bodyHint);

- (instancetype)initWithBaseURL:(NSString *)baseURL
                   authHandler:(WitchAuthHandler)authHandler;

/// Single-shot multipart upload. Body is assembled into a temp file by
/// streaming (bounded RAM) and sent with uploadTask fromFile. Works with the
/// current server. Files larger than maxFileBytes send their TAIL with
/// payload[@"truncated"]=@YES. Completion on main queue.
- (WitchLogUploadJob *)uploadPayload:(NSDictionary *)payload
                               files:(NSArray<WitchUploadFile *> *)files
                              toPath:(NSString *)apiPath
                        maxFileBytes:(unsigned long long)maxFileBytes
                            progress:(void (^)(double fraction))progress
                          completion:(void (^)(BOOL success, NSString * _Nullable serverID, NSError * _Nullable error))completion;

/// Chunked gzip upload with server-side resume. Falls back to single-shot
/// when the server has no chunk endpoints. Completion on main queue.
- (WitchLogUploadJob *)uploadFileChunked:(NSString *)filePath
                                fileName:(NSString *)name
                                 payload:(NSDictionary *)payload
                                progress:(void (^)(double fraction))progress
                              completion:(void (^)(BOOL success, NSString * _Nullable serverID, NSError * _Nullable error))completion;

@end

/// Streaming gzip file -> file (zlib, 64KB buffers, bounded RAM).
@interface WitchLogGzip : NSObject
+ (BOOL)gzipFileAtPath:(NSString *)src
                toPath:(NSString *)dst
                 error:(NSError **)outError;
@end

NS_ASSUME_NONNULL_END
