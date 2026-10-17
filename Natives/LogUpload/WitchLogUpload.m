#import "WitchLogUpload.h"
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

@implementation WitchUploadFile
+ (instancetype)fileWithName:(NSString *)name path:(NSString *)path {
    WitchUploadFile *f = [WitchUploadFile new];
    f.name = name;
    f.path = path;
    return f;
}
@end

@implementation WitchLogUploadJob {
    NSURLSessionTask *_task;
    BOOL _cancelled;
    WitchLogUploadJob *_fallbackJob;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _jobID = [[NSUUID UUID] UUIDString];
        _state = WitchUploadStatePending;
    }
    return self;
}
- (void)attachTask:(NSURLSessionTask *)task { _task = task; }
- (void)attachFallback:(WitchLogUploadJob *)job { _fallbackJob = job; }
- (void)cancel {
    if (_cancelled) return;
    // Never clobber a terminal state.
    if (self.state == WitchUploadStateCompleted || self.state == WitchUploadStateFailed) return;
    _cancelled = YES;
    [_fallbackJob cancel];
    self.state = WitchUploadStateFailed;
    self.error = [NSError errorWithDomain:@"WitchLog" code:499
                                 userInfo:@{NSLocalizedDescriptionKey: @"Upload cancelled"}];
    [_task cancel];
}
- (BOOL)isCancelled { return _cancelled; }
@end

// MARK: - gzip

@implementation WitchLogGzip
+ (BOOL)gzipFileAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)outError {
    NSFileHandle *in = [NSFileHandle fileHandleForReadingAtPath:src];
    if (!in) {
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:404
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Cannot open source file"}];
        return NO;
    }
    [[NSFileManager defaultManager] createFileAtPath:dst contents:nil attributes:nil];
    NSFileHandle *out = [NSFileHandle fileHandleForWritingAtPath:dst];
    if (!out) {
        [in closeFile];
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:500
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Cannot create gzip temp file"}];
        return NO;
    }
    BOOL ok = YES;
    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    // 15+16 => gzip wrapper.
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        [in closeFile]; [out closeFile];
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:500
                                                  userInfo:@{NSLocalizedDescriptionKey: @"deflateInit failed"}];
        return NO;
    }
    @try {
        uint8_t inBuf[64 * 1024];
        uint8_t outBuf[64 * 1024];
        BOOL eof = NO;
        while (!eof) {
            NSData *chunk = [in readDataOfLength:sizeof(inBuf)];
            if (chunk.length == 0) eof = YES;
            strm.next_in = (Bytef *)chunk.bytes;
            strm.avail_in = (uInt)chunk.length;
            int flush = eof ? Z_FINISH : Z_NO_FLUSH;
            do {
                strm.next_out = outBuf;
                strm.avail_out = sizeof(outBuf);
                int rc = deflate(&strm, flush);
                if (rc == Z_STREAM_ERROR) { ok = NO; eof = YES; break; }
                NSUInteger have = sizeof(outBuf) - strm.avail_out;
                if (have > 0) [out writeData:[NSData dataWithBytes:outBuf length:have]];
            } while (strm.avail_out == 0);
            if (!ok) break;
        }
    } @finally {
        deflateEnd(&strm);
        [in closeFile];
        [out closeFile];
    }
    if (!ok && outError) *outError = [NSError errorWithDomain:@"WitchLog" code:500
                                                     userInfo:@{NSLocalizedDescriptionKey: @"gzip failed"}];
    return ok;
}
@end

// MARK: - Uploader

@interface WitchLogUploader () <NSURLSessionTaskDelegate>
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) WitchAuthHandler authHandler;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, WitchLogUploadJob *> *jobsByTask;
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(double)> *progressByJob;
@end

@implementation WitchLogUploader

- (instancetype)initWithBaseURL:(NSString *)baseURL authHandler:(WitchAuthHandler)authHandler {
    self = [super init];
    if (self) {
        _baseURL = [baseURL copy];
        _authHandler = [authHandler copy];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 60;
        cfg.timeoutIntervalForResource = 30 * 60;
        NSOperationQueue *delegateQueue = [NSOperationQueue new];
        delegateQueue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:delegateQueue];
        _jobsByTask = [NSMutableDictionary dictionary];
        _progressByJob = [NSMutableDictionary dictionary];
    }
    return self;
}

// NSURLSessionTaskDelegate: upload progress (called off main).
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    if (totalBytesExpectedToSend <= 0) return;
    WitchLogUploadJob *job = nil;
    void (^progress)(double) = nil;
    @synchronized (self) {
        job = _jobsByTask[@(task.taskIdentifier)];
        progress = _progressByJob[job.jobID];
    }
    if (!job || !progress) return;
    double f = (double)totalBytesSent / (double)totalBytesExpectedToSend;
    job.progress = f;
    dispatch_async(dispatch_get_main_queue(), ^{ progress(f); });
}

#pragma mark - Multipart streaming

// Append at most maxBytes from srcPath to outHandle. If the file is larger,
// appends the TAIL (most relevant for logs) and sets *truncated=YES.
- (BOOL)appendFile:(NSString *)srcPath
          toHandle:(NSFileHandle *)outHandle
        maxBytes:(unsigned long long)maxBytes
       truncated:(BOOL *)outTruncated {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:srcPath error:nil];
    unsigned long long size = [attrs fileSize];
    unsigned long long startAt = 0;
    BOOL truncated = NO;
    if (size > maxBytes) { startAt = size - maxBytes; truncated = YES; }
    if (outTruncated) *outTruncated = truncated;
    NSFileHandle *in = [NSFileHandle fileHandleForReadingAtPath:srcPath];
    if (!in) return NO;
    @try {
        [in seekToFileOffset:startAt];
        // If we start mid-file, skip to the next line boundary so the server
        // never sees a half line at the top.
        if (startAt > 0) {
            NSData *probe = [in readDataOfLength:4096];
            const uint8_t *b = probe.bytes;
            NSUInteger i = 0;
            while (i < probe.length && b[i] != '\n') i++;
            if (i < probe.length) [in seekToFileOffset:startAt + i + 1];
            else [in seekToFileOffset:startAt + probe.length];
        }
        unsigned long long left = maxBytes;
        while (left > 0) {
            @autoreleasepool {
                NSUInteger want = (NSUInteger)MIN(left, 1024ULL * 1024ULL);
                NSData *chunk = [in readDataOfLength:want];
                if (chunk.length == 0) break;
                [outHandle writeData:chunk];
                left -= chunk.length;
            }
        }
    } @finally {
        [in closeFile];
    }
    return YES;
}

- (nullable NSString *)buildMultipartBodyWithPayload:(NSDictionary *)payload
                                               files:(NSArray<WitchUploadFile *> *)files
                                        maxFileBytes:(unsigned long long)maxBytes
                                            boundary:(NSString *)boundary
                                        payloadJSON:(NSData **)outJSON
                                          truncated:(BOOL *)outTruncated {
    NSError *err = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    if (!json) return nil;
    if (outJSON) *outJSON = json;
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"witch-upload-%@.bin", [[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createFileAtPath:tmp contents:nil attributes:nil];
    NSFileHandle *out = [NSFileHandle fileHandleForWritingAtPath:tmp];
    if (!out) return nil;
    BOOL anyTruncated = NO;
    @try {
        [out writeData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [out writeData:[@"Content-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [out writeData:json];
        [out writeData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        int idx = 0;
        for (WitchUploadFile *f in files) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:f.path]) continue;
            [out writeData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            NSString *safeName = f.name.length ? f.name : [NSString stringWithFormat:@"file%d.txt", idx];
            [out writeData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"files[%d]\"; filename=\"%@\"\r\nContent-Type: text/plain\r\n\r\n", idx, safeName] dataUsingEncoding:NSUTF8StringEncoding]];
            BOOL t = NO;
            [self appendFile:f.path toHandle:out maxBytes:maxBytes truncated:&t];
            anyTruncated = anyTruncated || t;
            [out writeData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            idx++;
        }
        [out writeData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    } @finally {
        [out closeFile];
    }
    if (outTruncated) *outTruncated = anyTruncated;
    return tmp;
}

- (WitchLogUploadJob *)uploadPayload:(NSDictionary *)payload
                               files:(NSArray<WitchUploadFile *> *)files
                              toPath:(NSString *)apiPath
                        maxFileBytes:(unsigned long long)maxFileBytes
                            progress:(void (^)(double))progress
                          completion:(void (^)(BOOL, NSString *, NSError *))completion {
    WitchLogUploadJob *job = [WitchLogUploadJob new];
    job.state = WitchUploadStatePreparing;
    __weak typeof(self) weakSelf = self;
    __weak WitchLogUploadJob *weakJob = job;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strong = weakSelf;
        WitchLogUploadJob *j = weakJob;
        if (!strong || !j || [j isCancelled]) return;
        NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
        NSData *payloadJSON = nil;
        BOOL truncated = NO;
        NSString *bodyPath = [strong buildMultipartBodyWithPayload:payload files:files
                                                      maxFileBytes:maxFileBytes
                                                          boundary:boundary
                                                       payloadJSON:&payloadJSON
                                                         truncated:&truncated];
        if (!bodyPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                j.state = WitchUploadStateFailed;
                j.error = [NSError errorWithDomain:@"WitchLog" code:400
                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload"}];
                completion(NO, nil, j.error);
            });
            return;
        }
        NSMutableDictionary *mutablePayload = [payload mutableCopy];
        if (truncated) mutablePayload[@"truncated"] = @YES;
        // NOTE: payload_json already written; truncated flag is best-effort info.
        // Re-stamp via header instead of rebuilding the body.
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", strong.baseURL, apiPath]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
   forHTTPHeaderField:@"Content-Type"];
        if (truncated) [req setValue:@"1" forHTTPHeaderField:@"X-Witch-Truncated"];
        NSString *bodyHint = [[NSString alloc] initWithData:payloadJSON encoding:NSUTF8StringEncoding];
        if (strong.authHandler) strong.authHandler(req, bodyHint);
        if ([j isCancelled]) {
            [[NSFileManager defaultManager] removeItemAtPath:bodyPath error:nil];
            return;
        }
        j.state = WitchUploadStateUploading;
        NSURLSessionUploadTask *task = [strong.session uploadTaskWithRequest:req
                                                                   fromFile:[NSURL fileURLWithPath:bodyPath]
                                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [[NSFileManager defaultManager] removeItemAtPath:bodyPath error:nil];
            typeof(self) s2 = weakSelf;
            WitchLogUploadJob *j2 = weakJob;
            if (s2) @synchronized (s2) {
                // task lookup cleanup by matching job
                for (NSNumber *k in s2.jobsByTask.allKeys) {
                    if (s2.jobsByTask[k] == j2) { [s2.jobsByTask removeObjectForKey:k]; break; }
                }
                if (j2) [s2.progressByJob removeObjectForKey:j2.jobID];
                // One session per uploader; tear it down so nothing leaks.
                [s2.session finishTasksAndInvalidate];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!j2 || [j2 isCancelled]) return;
                if (error) {
                    j2.state = WitchUploadStateFailed;
                    j2.error = error;
                    completion(NO, nil, error);
                    return;
                }
                NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
                NSDictionary *jsonResp = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                if (status >= 200 && status < 300) {
                    j2.state = WitchUploadStateCompleted;
                    j2.progress = 1.0;
                    NSString *sid = [jsonResp[@"logId"] description] ?: [jsonResp[@"job_id"] description];
                    j2.serverID = ([sid isKindOfClass:[NSString class]] && sid.length > 0) ? sid : nil;
                    if (progress) progress(1.0);
                    completion(YES, j2.serverID, nil);
                } else {
                    // Surface nested Worker detail too ({"error":...,"data":[...]})
                    // so Discord webhook failures show the real cause.
                    NSString *msg = nil;
                    if ([jsonResp isKindOfClass:[NSDictionary class]]) {
                        id e = jsonResp[@"error"];
                        if ([e isKindOfClass:[NSString class]] && [(NSString*)e length] > 0) msg = e;
                        id d = jsonResp[@"data"];
                        NSArray *arr = nil;
                        if ([d isKindOfClass:[NSArray class]]) arr = d;
                        else if ([d isKindOfClass:[NSDictionary class]]) arr = @[d];
                        NSString *detail = nil;
                        for (id item in arr) {
                            NSString *found = nil;
                            @try {
                                if ([item isKindOfClass:[NSDictionary class]]) {
                                    id inner = item[@"error"];
                                    if ([inner isKindOfClass:[NSDictionary class]] && [inner[@"message"] isKindOfClass:[NSString class]]) found = inner[@"message"];
                                    else if ([inner isKindOfClass:[NSString class]]) found = inner;
                                    else if ([item[@"message"] isKindOfClass:[NSString class]]) found = item[@"message"];
                                } else if ([item isKindOfClass:[NSString class]]) found = item;
                            } @catch (...) {}
                            if (found.length > 0) { detail = found; break; }
                        }
                        if (detail.length > 0 && (!msg.length || [msg rangeOfString:detail options:NSCaseInsensitiveSearch].location == NSNotFound)) {
                            msg = msg.length ? [NSString stringWithFormat:@"%@: %@", msg, detail] : detail;
                        }
                        if (!msg.length && [jsonResp[@"message"] isKindOfClass:[NSString class]]) msg = jsonResp[@"message"];
                    }
                    if (!msg.length) msg = [NSString stringWithFormat:@"Server %ld", (long)status];
                    if (msg.length > 2000) msg = [[msg substringToIndex:2000] stringByAppendingString:@"..."];
                    NSError *e = [NSError errorWithDomain:@"WitchLog" code:status
                                                 userInfo:@{NSLocalizedDescriptionKey: msg}];
                    j2.state = WitchUploadStateFailed;
                    j2.error = e;
                    completion(NO, nil, e);
                }
            });
        }];
        [j attachTask:task];
        @synchronized (strong) {
            strong.jobsByTask[@(task.taskIdentifier)] = j;
            if (progress) strong.progressByJob[j.jobID] = [progress copy];
        }
        [task resume];
    });
    return job;
}

#pragma mark - Chunked upload with resume + single-shot fallback

- (nullable NSDictionary *)syncJSONRequest:(NSMutableURLRequest *)req
                              jsonBody:(nullable NSDictionary *)body
                                 error:(NSError **)outError {
    NSData *bodyData = nil;
    if (body) {
        bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:outError];
        if (!bodyData) return nil;
        req.HTTPBody = bodyData;
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    if (self.authHandler) {
        NSString *hint = bodyData ? [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] : nil;
        self.authHandler(req, hint);
    }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *respData = nil;
    __block NSURLResponse *resp = nil;
    __block NSError *reqErr = nil;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        respData = d; resp = r; reqErr = e;
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (reqErr) { if (outError) *outError = reqErr; return nil; }
    NSInteger status = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
    if (status == 404) {
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:404
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Chunk endpoint not found"}];
        return nil;
    }
    if (status < 200 || status >= 300) {
        NSString *msg = nil;
        if (respData.length > 0) {
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
            if ([j isKindOfClass:[NSDictionary class]]) {
                id e = j[@"error"];
                if ([e isKindOfClass:[NSString class]] && [(NSString*)e length] > 0) msg = e;
                if ([j[@"message"] isKindOfClass:[NSString class]] && [(NSString*)j[@"message"] length] > 0) {
                    msg = msg.length ? [NSString stringWithFormat:@"%@: %@", msg, j[@"message"]] : j[@"message"];
                }
            } else {
                NSString *raw = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
                raw = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (raw.length > 0) msg = raw.length > 500 ? [[raw substringToIndex:500] stringByAppendingString:@"..."] : raw;
            }
        }
        if (!msg.length) msg = [NSString stringWithFormat:@"Server %ld", (long)status];
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:status
                                                  userInfo:@{NSLocalizedDescriptionKey: msg}];
        return nil;
    }
    if (!respData) return @{};
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:respData options:0 error:outError];
    return [json isKindOfClass:[NSDictionary class]] ? json : @{};
}

static NSString *ResumeKeyForSHA(NSString *sha) {
    return [@"witch.upload.resume." stringByAppendingString:sha];
}

- (WitchLogUploadJob *)uploadFileChunked:(NSString *)filePath
                                fileName:(NSString *)name
                                 payload:(NSDictionary *)payload
                                progress:(void (^)(double))progress
                              completion:(void (^)(BOOL, NSString *, NSError *))completion {
    WitchLogUploadJob *job = [WitchLogUploadJob new];
    job.state = WitchUploadStatePreparing;
    __weak typeof(self) weakSelf = self;
    __weak WitchLogUploadJob *weakJob = job;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strong = weakSelf;
        WitchLogUploadJob *j = weakJob;
        if (!strong || !j || [j isCancelled]) return;
        void (^fail)(NSError *) = ^(NSError *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([j isCancelled]) return;
                j.state = WitchUploadStateFailed;
                j.error = e;
                completion(NO, nil, e);
            });
        };
        void (^report)(double) = ^(double f) {
            j.progress = f;
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(f); });
        };
        report(0.02);

        // 1. gzip to temp (streaming, bounded RAM).
        NSString *gzPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                            [NSString stringWithFormat:@"witch-log-%@.gz", [[NSUUID UUID] UUIDString]]];
        NSError *gzErr = nil;
        if (![WitchLogGzip gzipFileAtPath:filePath toPath:gzPath error:&gzErr]) {
            [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
            fail(gzErr);
            return;
        }
        unsigned long long gzSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:gzPath error:nil] fileSize];
        // 2. streaming SHA-256 of the gzipped payload (resume key).
        NSString *sha = [strong syncSHA256OfFile:gzPath job:j];
        if (!sha) {
            [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
            fail([NSError errorWithDomain:@"WitchLog" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Hash failed"}]);
            return;
        }
        const unsigned long long chunkSize = 4 * 1024 * 1024;
        NSUInteger totalChunks = (NSUInteger)((gzSize + chunkSize - 1) / chunkSize);
        if (totalChunks == 0) totalChunks = 1;
        report(0.08);

        // 3. init (404 => old server => single-shot fallback).
        NSURL *initURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/logs/upload/init", strong.baseURL]];
        NSMutableURLRequest *initReq = [NSMutableURLRequest requestWithURL:initURL];
        initReq.HTTPMethod = @"POST";
        NSError *initErr = nil;
        NSDictionary *initResp = [strong syncJSONRequest:initReq jsonBody:@{
            @"fileName": name ?: @"latestlog.txt.gz",
            @"fileSize": @(gzSize),
            @"sha256": sha,
            @"chunkSize": @(chunkSize),
            @"compressed": @"gzip",
        } error:&initErr];
        if (!initResp) {
            // Fallback path: single-shot multipart with the gzipped file PLUS
            // crash/hs_err companions as real FILES (not truncated snippets).
            // Deep previously sent only latestlog here — companions arrived as
            // 100KB previews ("mỗi một khúc"), now they ride as attachments.
            if ([initErr code] == 404) {
                WitchUploadFile *f = [WitchUploadFile fileWithName:[(name ?: @"latestlog.txt") stringByAppendingString:@".gz"]
                                                              path:gzPath];
                NSMutableArray<WitchUploadFile *> *allFiles = [NSMutableArray arrayWithObject:f];
                // payload carries the companion PATHS (see WitchLogReporter).
                NSString *crashPath = [payload isKindOfClass:[NSDictionary class]] ? payload[@"crashReportPath"] : nil;
                NSString *hsPath = [payload isKindOfClass:[NSDictionary class]] ? payload[@"hsErrPath"] : nil;
                NSString *crashName = ([payload isKindOfClass:[NSDictionary class]] && [payload[@"crashReportName"] isKindOfClass:[NSString class]])
                    ? payload[@"crashReportName"] : (crashPath.lastPathComponent ?: @"crash-report.txt");
                NSString *hsName = ([payload isKindOfClass:[NSDictionary class]] && [payload[@"hsErrName"] isKindOfClass:[NSString class]])
                    ? payload[@"hsErrName"] : (hsPath.lastPathComponent ?: @"hs_err.log");
                if ([crashPath isKindOfClass:[NSString class]] && crashPath.length > 0 &&
                    [[NSFileManager defaultManager] fileExistsAtPath:crashPath]) {
                    [allFiles addObject:[WitchUploadFile fileWithName:crashName path:crashPath]];
                }
                if ([hsPath isKindOfClass:[NSString class]] && hsPath.length > 0 &&
                    [[NSFileManager defaultManager] fileExistsAtPath:hsPath]) {
                    [allFiles addObject:[WitchUploadFile fileWithName:hsName path:hsPath]];
                }
                // Chain: reuse single-shot machinery; cleanup gz afterwards.
                WitchLogUploadJob *inner = [strong uploadPayload:payload files:allFiles toPath:@"/v1/logs/report"
                                                   maxFileBytes:64ULL*1024ULL*1024ULL progress:^(double pf) {
                    report(0.08 + pf * 0.92);
                } completion:^(BOOL ok, NSString *sid, NSError *e) {
                    [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([j isCancelled]) return;
                        j.progress = ok ? 1.0 : j.progress;
                        j.state = ok ? WitchUploadStateCompleted : WitchUploadStateFailed;
                        j.serverID = sid;
                        j.error = e;
                        completion(ok, sid, e);
                    });
                }];
                [j attachFallback:inner];
                if ([j isCancelled]) { [inner cancel]; return; }
                j.state = WitchUploadStateUploading;
                return;
            }
            [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
            fail(initErr);
            return;
        }
        NSString *uploadID = [initResp[@"uploadId"] isKindOfClass:[NSString class]] ? initResp[@"uploadId"] : nil;
        if (!uploadID) {
            [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
            fail([NSError errorWithDomain:@"WitchLog" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Bad init response"}]);
            return;
        }
        NSMutableSet *received = [NSMutableSet set];
        // Merge server-known received + locally persisted received (resume).
        for (id n in (initResp[@"received"] ?: @[])) [received addObject:n];
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:ResumeKeyForSHA(sha)];
        if ([saved[@"uploadID"] isEqualToString:uploadID]) {
            for (id n in (saved[@"received"] ?: @[])) [received addObject:n];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:@{@"uploadID": uploadID, @"received": @[]} forKey:ResumeKeyForSHA(sha)];
        }
        j.state = WitchUploadStateUploading;

        // 4. upload missing chunks sequentially (simple + resume-friendly).
        NSFileHandle *gz = [NSFileHandle fileHandleForReadingAtPath:gzPath];
        BOOL chunkFailed = NO;
        for (NSUInteger i = 0; i < totalChunks; i++) {
            if ([j isCancelled]) break;
            if ([received containsObject:@(i)]) { report(0.08 + 0.84 * (double)(i + 1) / (double)totalChunks); continue; }
            @autoreleasepool {
                [gz seekToFileOffset:i * chunkSize];
                NSData *data = [gz readDataOfLength:(NSUInteger)MIN(chunkSize, gzSize - i * chunkSize)];
                // per-chunk sha for integrity
                unsigned char h[CC_SHA256_DIGEST_LENGTH];
                CC_SHA256(data.bytes, (CC_LONG)data.length, h);
                NSMutableString *chex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
                for (int k = 0; k < CC_SHA256_DIGEST_LENGTH; k++) [chex appendFormat:@"%02x", h[k]];
                NSURL *cu = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/logs/upload/%@/chunk?index=%lu",
                                                  strong.baseURL, uploadID, (unsigned long)i]];
                NSMutableURLRequest *cr = [NSMutableURLRequest requestWithURL:cu];
                cr.HTTPMethod = @"POST";
                cr.HTTPBody = data;
                [cr setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
                [cr setValue:chex forHTTPHeaderField:@"X-Chunk-SHA256"];
                if (strong.authHandler) strong.authHandler(cr, chex);
                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                __block NSError *cerr = nil;
                __block NSInteger cstatus = 0;
                __block NSDictionary *cjson = nil;
                [[[NSURLSession sharedSession] dataTaskWithRequest:cr completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
                    cerr = e;
                    cstatus = [r isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)r statusCode] : 0;
                    if (d) cjson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                    dispatch_semaphore_signal(sem);
                }] resume];
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                if (cerr || cstatus < 200 || cstatus >= 300) {
                    chunkFailed = YES;
                    fail(cerr ?: [NSError errorWithDomain:@"WitchLog" code:cstatus ?: 500
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                           [NSString stringWithFormat:@"Chunk %lu failed (%ld)", (unsigned long)i, (long)cstatus]}]);
                    break;
                }
                [received addObject:@(i)];
                if ([cjson[@"received"] isKindOfClass:[NSArray class]]) {
                    for (id n in cjson[@"received"]) [received addObject:n];
                }
                [[NSUserDefaults standardUserDefaults] setObject:@{@"uploadID": uploadID, @"received": received.allObjects}
                                                          forKey:ResumeKeyForSHA(sha)];
                report(0.08 + 0.84 * (double)(i + 1) / (double)totalChunks);
            }
        }
        [gz closeFile];
        if (chunkFailed || [j isCancelled]) {
            [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
            return;
        }
        // 5. complete -> server assembles, verifies hash, queues AI job.
        NSURL *doneURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/logs/upload/%@/complete", strong.baseURL, uploadID]];
        NSMutableURLRequest *doneReq = [NSMutableURLRequest requestWithURL:doneURL];
        doneReq.HTTPMethod = @"POST";
        NSMutableDictionary *doneBody = [payload mutableCopy] ?: [NSMutableDictionary dictionary];
        doneBody[@"fileName"] = name ?: @"latestlog.txt.gz";
        doneBody[@"sha256"] = sha;
        NSError *doneErr = nil;
        NSDictionary *doneResp = [strong syncJSONRequest:doneReq jsonBody:doneBody error:&doneErr];
        [[NSFileManager defaultManager] removeItemAtPath:gzPath error:nil];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:ResumeKeyForSHA(sha)];
        if (!doneResp) { fail(doneErr); return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([j isCancelled]) return;
            j.state = WitchUploadStateCompleted;
            j.progress = 1.0;
            NSString *sid = nil;
            id v = doneResp[@"logId"] ?: doneResp[@"job_id"];
            if ([v isKindOfClass:[NSString class]]) sid = v;
            else if (v) sid = [v description];
            j.serverID = sid;
            if (progress) progress(1.0);
            completion(YES, sid, nil);
        });
    });
    return job;
}

- (nullable NSString *)syncSHA256OfFile:(NSString *)path job:(WitchLogUploadJob *)job {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) return nil;
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    @try {
        while (![job isCancelled]) {
            @autoreleasepool {
                NSData *chunk = [fh readDataOfLength:1024 * 1024];
                if (chunk.length == 0) break;
                CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
            }
        }
    } @finally {
        [fh closeFile];
    }
    if ([job isCancelled]) return nil;
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}

@end
