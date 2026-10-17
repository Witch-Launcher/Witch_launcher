#import "WitchLogIndex.h"
#import <CommonCrypto/CommonDigest.h>

static const NSUInteger kReadChunkSize = 64 * 1024;
static const NSUInteger kMaxReadLines = 5000;
static const NSUInteger kMaxLineBytes = 16 * 1024;
static const unsigned long long kMaxBytesPerRead = 2 * 1024 * 1024;

NSString *WitchDecodeLogLine(const uint8_t *bytes, NSUInteger len) {
    if (len == 0) return @"";
    // Strip trailing \r (CRLF files).
    if (len > 0 && bytes[len - 1] == '\r') len--;
    if (len == 0) return @"";
    BOOL truncated = NO;
    if (len > kMaxLineBytes) { len = kMaxLineBytes; truncated = YES; }
    NSString *s = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithBytes:bytes length:len encoding:NSWindowsCP1252StringEncoding];
    if (!s) s = @"";
    if (truncated) s = [s stringByAppendingString:@"… [line truncated]"];
    return s;
}

@implementation WitchLogCheckpoint
@end

@implementation WitchLogFileInfo
- (WitchLogCheckpoint *)checkpointAtOrBeforeLine:(NSUInteger)targetLine {
    WitchLogCheckpoint *best = nil;
    for (WitchLogCheckpoint *cp in _checkpoints) {
        if (cp.line <= targetLine) best = cp;
        else break; // checkpoints are ascending
    }
    return best;
}
@end

// MARK: - Indexer

@interface WitchLogIndexer ()
@property (nonatomic, copy) NSString *path;
@property (nonatomic) NSUInteger checkpointEvery;
@property (nonatomic) BOOL cancelled;
@end

@implementation WitchLogIndexer

- (instancetype)initWithPath:(NSString *)path checkpointEvery:(NSUInteger)lines {
    self = [super init];
    if (self) {
        _path = [path copy];
        _checkpointEvery = lines > 0 ? lines : 4096;
    }
    return self;
}

- (void)cancel { _cancelled = YES; }

static NSString *SidecarPathFor(NSString *logPath) {
    return [logPath stringByAppendingString:@".witchidx"];
}

- (nullable WitchLogFileInfo *)cachedInfoForSize:(unsigned long long)size modDate:(NSDate *)mod {
    NSData *data = [NSData dataWithContentsOfFile:SidecarPathFor(_path)];
    if (!data) return nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    if ([dict[@"size"] unsignedLongLongValue] != size) return nil;
    // mtime comparison with 1s tolerance (filesystems round differently).
    double savedMtime = [dict[@"mtime"] doubleValue];
    double curMtime = mod ? mod.timeIntervalSince1970 : 0;
    if (fabs(savedMtime - curMtime) > 1.0) return nil;
    NSArray *raw = dict[@"checkpoints"];
    if (![raw isKindOfClass:[NSArray class]] || raw.count == 0) return nil;
    NSMutableArray *cps = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSArray *pair in raw) {
        if (![pair isKindOfClass:[NSArray class]] || pair.count != 2) return nil;
        WitchLogCheckpoint *cp = [WitchLogCheckpoint new];
        cp.line = [pair[0] unsignedIntegerValue];
        cp.byteOffset = [pair[1] unsignedLongLongValue];
        [cps addObject:cp];
    }
    WitchLogFileInfo *info = [WitchLogFileInfo new];
    info.path = _path;
    info.fileSize = size;
    info.modDate = mod;
    info.lineCount = [dict[@"lines"] unsignedIntegerValue];
    info.checkpoints = cps;
    return info;
}

- (void)saveInfo:(WitchLogFileInfo *)info {
    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:info.checkpoints.count];
    for (WitchLogCheckpoint *cp in info.checkpoints) {
        [raw addObject:@[@(cp.line), @(cp.byteOffset)]];
    }
    NSDictionary *dict = @{
        @"size": @(info.fileSize),
        @"mtime": @(info.modDate ? info.modDate.timeIntervalSince1970 : 0),
        @"lines": @(info.lineCount),
        @"every": @(self.checkpointEvery),
        @"checkpoints": raw,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (data) [data writeToFile:SidecarPathFor(_path) atomically:YES];
}

- (nullable WitchLogFileInfo *)syncBuildWithError:(NSError **)outError {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:_path error:outError];
    if (!attrs) return nil;
    unsigned long long size = [attrs fileSize];
    NSDate *mod = attrs[NSFileModificationDate];

    // Empty file: trivial index.
    WitchLogCheckpoint *zero = [WitchLogCheckpoint new];
    zero.line = 0; zero.byteOffset = 0;
    if (size == 0) {
        WitchLogFileInfo *info = [WitchLogFileInfo new];
        info.path = _path; info.fileSize = 0; info.modDate = mod;
        info.lineCount = 0; info.checkpoints = @[zero];
        return info;
    }

    WitchLogFileInfo *cached = [self cachedInfoForSize:size modDate:mod];
    if (cached) return cached;

    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:_path];
    if (!fh) {
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:404
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Cannot open log file"}];
        return nil;
    }
    NSMutableArray<WitchLogCheckpoint *> *cps = [NSMutableArray arrayWithObject:zero];
    NSUInteger lineCount = 0;
    NSUInteger nextCheckpointAt = self.checkpointEvery;
    unsigned long long offset = 0;
    @try {
        while (!self.cancelled) {
            NSData *chunk = [fh readDataOfLength:kReadChunkSize];
            if (chunk.length == 0) break;
            const uint8_t *bytes = chunk.bytes;
            for (NSUInteger i = 0; i < chunk.length; i++) {
                if (bytes[i] == '\n') {
                    lineCount++;
                    if (lineCount == nextCheckpointAt) {
                        WitchLogCheckpoint *cp = [WitchLogCheckpoint new];
                        cp.line = lineCount;
                        cp.byteOffset = offset + i + 1;
                        [cps addObject:cp];
                        nextCheckpointAt += self.checkpointEvery;
                    }
                }
            }
            offset += chunk.length;
        }
    } @finally {
        [fh closeFile];
    }
    if (self.cancelled) {
        if (outError) *outError = [NSError errorWithDomain:@"WitchLog" code:499
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Indexing cancelled"}];
        return nil;
    }
    // Count trailing line without \n.
    if (offset > 0) {
        NSFileHandle *tail = [NSFileHandle fileHandleForReadingAtPath:_path];
        @try {
            unsigned long long back = MIN(offset, 1ULL);
            [tail seekToFileOffset:offset - back];
            NSData *last = [tail readDataOfLength:1];
            if (last.length == 1 && ((const uint8_t *)last.bytes)[0] != '\n') lineCount++;
        } @finally {
            [tail closeFile];
        }
    }
    WitchLogFileInfo *info = [WitchLogFileInfo new];
    info.path = _path; info.fileSize = size; info.modDate = mod;
    info.lineCount = lineCount; info.checkpoints = cps;
    [self saveInfo:info];
    return info;
}

- (void)buildWithProgress:(void (^)(double))progress
               completion:(void (^)(WitchLogFileInfo *, NSError *))completion {
    // Fast path: valid sidecar -> answer immediately on main.
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:nil];
    if (attrs) {
        WitchLogFileInfo *cached = [self cachedInfoForSize:[attrs fileSize]
                                                   modDate:attrs[NSFileModificationDate]];
        if (cached) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progress) progress(1.0);
                completion(cached, nil);
            });
            return;
        }
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strong = weakSelf;
        if (!strong) return;
        // Chunked progress: re-scan here would double IO; instead report
        // coarse progress by file size buckets while syncBuild runs.
        // (syncBuild itself is a single pass; progress is best-effort.)
        if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(0.05); });
        NSError *err = nil;
        WitchLogFileInfo *info = [strong syncBuildWithError:&err];
        if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(1.0); });
        dispatch_async(dispatch_get_main_queue(), ^{ completion(info, err); });
    });
}

@end

// MARK: - Reader

@interface WitchLogReader ()
@property (nonatomic, strong) WitchLogFileInfo *info;
// Small sequential window cache so scrolling hits RAM, not disk.
@property (nonatomic) NSUInteger cacheBase;
@property (nonatomic, strong) NSArray<NSString *> *cacheLines;
@end

@implementation WitchLogReader

- (instancetype)initWithFileInfo:(WitchLogFileInfo *)info {
    self = [super init];
    if (self) {
        _fileInfo = info;
        _cacheBase = NSNotFound;
    }
    return self;
}

// Split raw bytes on 0x0A and decode per line (boundary-safe for UTF-8).
- (NSArray<NSString *> *)linesFromData:(NSData *)data
                             skipFirst:(NSUInteger)skip
                                 take:(NSUInteger)take
                         bytesConsumed:(unsigned long long *)outConsumed
                         hitByteLimit:(BOOL *)outLimited {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    const uint8_t *bytes = data.bytes;
    NSUInteger len = data.length;
    NSUInteger lineStart = 0;
    NSUInteger skipped = 0;
    unsigned long long consumed = 0;
    BOOL limited = NO;
    for (NSUInteger i = 0; i < len; i++) {
        if (bytes[i] != '\n') continue;
        if (skipped < skip) { skipped++; lineStart = i + 1; continue; }
        if (out.count >= take) break;
        if ((i + 1 - lineStart) + 0 > 0 && (consumed + (i + 1 - lineStart)) > kMaxBytesPerRead) {
            limited = YES; break;
        }
        [out addObject:WitchDecodeLogLine(bytes + lineStart, i - lineStart)];
        consumed += (i + 1 - lineStart);
        lineStart = i + 1;
    }
    if (outConsumed) *outConsumed = consumed;
    if (outLimited) *outLimited = limited;
    // Remainder (no trailing \n) is handled by the caller.
    return out;
}

- (NSArray<NSString *> *)syncReadLinesFrom:(NSUInteger)start
                                     count:(NSUInteger)count
                               actualStart:(NSUInteger *)outStart {
    if (outStart) *outStart = start;
    if (count == 0) return @[];
    count = MIN(count, kMaxReadLines);
    if (start >= self.fileInfo.lineCount) return @[];

    // Window cache hit?
    if (_cacheBase != NSNotFound && start >= _cacheBase &&
        start + count <= _cacheBase + _cacheLines.count) {
        NSRange r = NSMakeRange(start - _cacheBase, MIN(count, _cacheLines.count - (start - _cacheBase)));
        return [_cacheLines subarrayWithRange:r];
    }

    WitchLogCheckpoint *cp = [self.fileInfo checkpointAtOrBeforeLine:start];
    unsigned long long seekTo = cp ? cp.byteOffset : 0;
    NSUInteger cpLine = cp ? cp.line : 0;
    NSUInteger skip = start - cpLine;

    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:self.fileInfo.path];
    if (!fh) return @[];
    NSMutableArray<NSString *> *collected = [NSMutableArray array];
    // Over-read a bit to fill the window cache for sequential scrolls.
    NSUInteger want = count + 400;
    @try {
        [fh seekToFileOffset:seekTo];
        NSMutableData *carry = [NSMutableData data]; // partial line across chunks
        // carryLineIndex: absolute line number of carry's first byte
        NSUInteger pendingSkip = skip;
        unsigned long long budget = kMaxBytesPerRead + 256 * 1024;
        while (collected.count < want && budget > 0) {
            NSData *chunk = [fh readDataOfLength:(NSUInteger)MIN((unsigned long long)kReadChunkSize, budget)];
            if (chunk.length == 0) break;
            budget -= chunk.length;
            // Prepend carry.
            NSMutableData *buf = [NSMutableData dataWithData:carry];
            [buf appendData:chunk];
            [carry setLength:0];
            const uint8_t *bytes = buf.bytes;
            NSUInteger blen = buf.length;
            // Find last \n; everything after it is the new carry.
            NSUInteger lastNL = NSNotFound;
            for (NSUInteger i = blen; i > 0; i--) {
                if (bytes[i - 1] == '\n') { lastNL = i - 1; break; }
            }
            NSUInteger parseLen = (lastNL == NSNotFound) ? 0 : lastNL + 1;
            if (parseLen > 0) {
                NSUInteger lineStart = 0;
                for (NSUInteger i = 0; i < parseLen; i++) {
                    if (bytes[i] != '\n') continue;
                    if (pendingSkip > 0) { pendingSkip--; lineStart = i + 1; continue; }
                    if (collected.count >= want) break;
                    [collected addObject:WitchDecodeLogLine(bytes + lineStart, i - lineStart)];
                    lineStart = i + 1;
                }
            }
            NSUInteger carryFrom = (lastNL == NSNotFound) ? 0 : lastNL + 1;
            if (carryFrom < blen) [carry appendBytes:bytes + carryFrom length:blen - carryFrom];
            // Guard: a single gigantic line would grow carry forever.
            if (carry.length > kMaxLineBytes + kReadChunkSize) {
                if (pendingSkip > 0) { pendingSkip--; }
                else if (collected.count < want) {
                    [collected addObject:WitchDecodeLogLine(carry.bytes, carry.length)];
                }
                [carry setLength:0];
                // Resync: skip to next \n to realign.
                while (YES) {
                    NSData *s = [fh readDataOfLength:kReadChunkSize];
                    if (s.length == 0) break;
                    budget -= s.length;
                    const uint8_t *sb = s.bytes;
                    NSUInteger j = 0;
                    while (j < s.length && sb[j] != '\n') j++;
                    if (j < s.length) { [fh seekToFileOffset:[fh offsetInFile] - (s.length - j - 1)]; break; }
                }
            }
        }
        // EOF: flush carry as final line.
        if (collected.count < want && carry.length > 0 && pendingSkip == 0) {
            // Only if file doesn't end with \n (avoid phantom empty line).
            [collected addObject:WitchDecodeLogLine(carry.bytes, carry.length)];
        } else if (pendingSkip > 0 && carry.length > 0) {
            // skipped the final partial line
        }
    } @finally {
        [fh closeFile];
    }
    // Update window cache.
    if (collected.count > 0) {
        _cacheBase = start;
        _cacheLines = [collected copy];
    }
    if (collected.count > count) {
        return [collected subarrayWithRange:NSMakeRange(0, count)];
    }
    return collected;
}

- (void)readLinesFrom:(NSUInteger)start
                count:(NSUInteger)count
           completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strong = weakSelf;
        NSArray *lines = strong ? [strong syncReadLinesFrom:start count:count actualStart:nil] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(lines, start); });
    });
}

- (NSArray<NSString *> *)syncReadTail:(NSUInteger)maxLines startLine:(NSUInteger *)outStart {
    if (maxLines == 0) maxLines = 1;
    maxLines = MIN(maxLines, kMaxReadLines);
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:self.fileInfo.path];
    if (!fh) { if (outStart) *outStart = 0; return @[]; }
    NSMutableArray<NSData *> *blocks = [NSMutableArray array]; // file order
    NSUInteger newlineCount = 0;
    unsigned long long bufferStart = 0;
    @try {
        unsigned long long fileSize = [fh seekToEndOfFile];
        BOOL endsWithNL = NO;
        if (fileSize > 0) {
            [fh seekToFileOffset:fileSize - 1];
            NSData *one = [fh readDataOfLength:1];
            if (one.length == 1 && ((const uint8_t *)one.bytes)[0] == '\n') endsWithNL = YES;
        }
        NSUInteger need = maxLines + (endsWithNL ? 1 : 0);
        unsigned long long pos = fileSize;
        unsigned long long budget = 4 * 1024 * 1024; // 4MB cap for tail scan
        while (pos > 0 && newlineCount < need && budget > 0) {
            unsigned long long take = MIN((unsigned long long)kReadChunkSize, pos);
            take = MIN(take, budget);
            pos -= take;
            budget -= take;
            [fh seekToFileOffset:pos];
            NSData *block = [fh readDataOfLength:(NSUInteger)take];
            if (block.length == 0) break;
            [blocks insertObject:block atIndex:0];
            const uint8_t *b = block.bytes;
            for (NSUInteger i = 0; i < block.length; i++) {
                if (b[i] == '\n') newlineCount++;
            }
        }
        bufferStart = pos;
    } @finally {
        [fh closeFile];
    }
    NSUInteger totalLen = 0;
    for (NSData *d in blocks) totalLen += d.length;
    NSMutableData *all = [NSMutableData dataWithCapacity:totalLen];
    for (NSData *d in blocks) [all appendData:d];
    const uint8_t *bytes = all.bytes;
    // Line-start offsets, oldest-first, within the buffer.
    NSMutableArray<NSNumber *> *lineStarts = [NSMutableArray array];
    NSInteger end = (NSInteger)totalLen;
    if (end > 0 && bytes[end - 1] == '\n') end--; // ignore trailing empty segment
    // Walk backward collecting up to maxLines line starts.
    NSMutableArray<NSNumber *> *rev = [NSMutableArray array];
    [rev addObject:@(end)]; // sentinel = end of newest line
    for (NSInteger i = end - 1; i >= 0; i--) {
        if (bytes[i] == '\n') {
            [rev addObject:@(i + 1)];
            if (rev.count - 1 >= maxLines) break;
        }
    }
    // rev = [newestEnd, newestStart, ..., oldestStart?]. If the buffer does not
    // start at file offset 0, the oldest collected line may be cut -> drop it.
    NSUInteger have = rev.count - 1;
    if (have > 0 && bufferStart > 0 && have < maxLines) {
        // Byte budget exhausted mid-line: oldest collected line is partial.
        // (When have == maxLines the oldest start follows an observed '\n'.)
        [rev removeLastObject];
        have--;
    }
    for (NSInteger k = (NSInteger)have - 1; k >= 0; k--) {
        [lineStarts addObject:rev[k + 1]];
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:have];
    for (NSUInteger idx = 0; idx < lineStarts.count; idx++) {
        NSUInteger s = [lineStarts[idx] unsignedIntegerValue];
        NSUInteger e = (idx + 1 < lineStarts.count)
            ? [lineStarts[idx + 1] unsignedIntegerValue] - 1 // exclude '\n'
            : (NSUInteger)end;
        if (e > s && e <= totalLen && bytes[e - 1] == '\r') e--; // safety (Decode also strips)
        [lines addObject:WitchDecodeLogLine(bytes + s, e > s ? e - s : 0)];
    }
    NSUInteger startLine = 0;
    if (self.fileInfo.lineCount != NSNotFound) {
        startLine = (lines.count >= self.fileInfo.lineCount) ? 0 : self.fileInfo.lineCount - lines.count;
    }
    if (outStart) *outStart = startLine;
    return lines;
}

- (void)readTail:(NSUInteger)maxLines
      completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strong = weakSelf;
        NSUInteger s = 0;
        NSArray *lines = strong ? [strong syncReadTail:maxLines startLine:&s] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(lines, s); });
    });
}

- (void)syncEnumerateLinesWithMaxBytes:(unsigned long long)maxBytes
                            batchSize:(NSUInteger)batchSize
                              handler:(void (^)(NSArray<NSString *> *, NSUInteger, BOOL *))handler {
    if (batchSize == 0) batchSize = 512;
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:self.fileInfo.path];
    if (!fh) return;
    NSMutableArray<NSString *> *batch = [NSMutableArray arrayWithCapacity:batchSize];
    NSUInteger lineNo = 0;
    NSMutableData *carry = [NSMutableData data];
    BOOL stop = NO;
    unsigned long long consumed = 0;
    @try {
        while (!stop) {
            NSData *chunk = [fh readDataOfLength:kReadChunkSize];
            if (chunk.length == 0) break;
            if (consumed + chunk.length > maxBytes) {
                NSUInteger allowed = (NSUInteger)(maxBytes > consumed ? maxBytes - consumed : 0);
                chunk = [chunk subdataWithRange:NSMakeRange(0, allowed)];
            }
            consumed += chunk.length;
            NSMutableData *buf = [NSMutableData dataWithData:carry];
            [buf appendData:chunk];
            [carry setLength:0];
            const uint8_t *bytes = buf.bytes;
            NSUInteger blen = buf.length;
            NSUInteger lastNL = NSNotFound;
            for (NSUInteger i = blen; i > 0; i--) {
                if (bytes[i - 1] == '\n') { lastNL = i - 1; break; }
            }
            NSUInteger parseLen = (lastNL == NSNotFound) ? 0 : lastNL + 1;
            NSUInteger lineStart = 0;
            for (NSUInteger i = 0; i < parseLen && !stop; i++) {
                if (bytes[i] != '\n') continue;
                [batch addObject:WitchDecodeLogLine(bytes + lineStart, i - lineStart)];
                lineStart = i + 1;
                if (batch.count >= batchSize) {
                    handler([batch copy], lineNo, &stop);
                    lineNo += batch.count;
                    [batch removeAllObjects];
                }
            }
            NSUInteger carryFrom = (lastNL == NSNotFound) ? 0 : lastNL + 1;
            if (carryFrom < blen) [carry appendBytes:bytes + carryFrom length:blen - carryFrom];
            if (carry.length > kMaxLineBytes + kReadChunkSize) {
                [batch addObject:WitchDecodeLogLine(carry.bytes, carry.length)];
                [carry setLength:0];
                if (batch.count >= batchSize) {
                    handler([batch copy], lineNo, &stop);
                    lineNo += batch.count;
                    [batch removeAllObjects];
                }
            }
            if (consumed >= maxBytes) break;
        }
        if (!stop && carry.length > 0 && consumed < self.fileInfo.fileSize + 1) {
            // Final partial line (file without trailing newline).
            [batch addObject:WitchDecodeLogLine(carry.bytes, carry.length)];
        }
        if (!stop && batch.count > 0) {
            handler([batch copy], lineNo, &stop);
        }
    } @finally {
        [fh closeFile];
    }
}

- (nullable NSString *)syncSHA256Hex {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:self.fileInfo.path];
    if (!fh) return nil;
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    @try {
        while (YES) {
            @autoreleasepool {
                NSData *chunk = [fh readDataOfLength:1024 * 1024];
                if (chunk.length == 0) break;
                CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
            }
        }
    } @finally {
        [fh closeFile];
    }
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}

@end
