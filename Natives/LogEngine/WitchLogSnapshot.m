#import "WitchLogSnapshot.h"

@implementation WitchLogSnapshotResult
@end

// Budgets keep every stage bounded regardless of log size.
static const NSUInteger kTailLines = 300;
static const NSUInteger kMaxTailBytes = 200 * 1024;
static const NSUInteger kMaxErrorBytes = 200 * 1024;
static const NSUInteger kMaxModloaderBytes = 8000;

static BOOL LineContainsAny(NSString *line, NSArray<NSString *> *patterns) {
    for (NSString *p in patterns) {
        if ([line rangeOfString:p options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static WitchLogFileInfo *InfoForPath(NSString * _Nullable path) {
    if (!path) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!attrs) return nil;
    WitchLogFileInfo *info = [WitchLogFileInfo new];
    info.path = path;
    info.fileSize = [attrs fileSize];
    info.modDate = attrs[NSFileModificationDate];
    info.lineCount = NSNotFound;
    WitchLogCheckpoint *zero = [WitchLogCheckpoint new];
    zero.line = 0; zero.byteOffset = 0;
    info.checkpoints = @[zero];
    return info;
}

@implementation WitchLogSnapshotter

+ (void)buildWithLatestLog:(NSString *)latestPath
                 crashPath:(NSString *)crashPath
                 hsErrPath:(NSString *)hsErrPath
                  exitCode:(int)code
                  metadata:(NSDictionary<NSString *, NSString *> *)metadata
                  maxBytes:(NSUInteger)maxBytes
                completion:(void (^)(WitchLogSnapshotResult *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        WitchLogSnapshotResult *r = [self syncBuildWithLatestLog:latestPath
                                                       crashPath:crashPath
                                                        hsErrPath:hsErrPath
                                                         exitCode:code
                                                         metadata:metadata
                                                         maxBytes:maxBytes];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(r); });
    });
}

+ (WitchLogSnapshotResult *)syncBuildWithLatestLog:(NSString *)latestPath
                                         crashPath:(NSString *)crashPath
                                          hsErrPath:(NSString *)hsErrPath
                                           exitCode:(int)code
                                           metadata:(NSDictionary<NSString *, NSString *> *)metadata
                                           maxBytes:(NSUInteger)maxBytes {
    if (maxBytes == 0) maxBytes = 500 * 1024;
    WitchLogSnapshotResult *result = [WitchLogSnapshotResult new];
    result.category = WitchLogCategoryRaw;

    WitchLogFileInfo *latestInfo = InfoForPath(latestPath);
    WitchLogReader *latestReader = latestInfo ? [[WitchLogReader alloc] initWithFileInfo:latestInfo] : nil;

    // ---- 1. Tail block (last 5000 lines, oldest-first). ----
    // Crash-relevant info (stack traces, modloader verdicts) is printed at
    // crash time, i.e. at the END of the log. Scanning the tail first is both
    // faster (bounded ~2MB) and more relevant than scanning from the head.
    NSArray<NSString *> *tailBlock = latestReader ? [latestReader syncReadTail:5000 startLine:nil] : @[];
    NSArray<NSString *> *tail100 = tailBlock.count > 100
        ? [tailBlock subarrayWithRange:NSMakeRange(tailBlock.count - 100, 100)] : tailBlock;
    result.excerpt = [tail100 componentsJoinedByString:@"\n"];

    // ---- 2+3. Single pass over tail block (+ small head scan if undecided). ----
    NSString *modloaderMessage = nil;
    NSMutableString *errorSection = [NSMutableString string];
    BOOL foundMod = NO;
    BOOL foundError = NO;
    if (tailBlock.count > 0) {
        modloaderMessage = [self scanLines:tailBlock
                              errorSection:errorSection
                                  foundMod:&foundMod
                                foundError:&foundError
                                 stopEarly:NO];
    }
    if (!foundMod && !foundError && !modloaderMessage && latestReader &&
        latestInfo.fileSize > 3 * 1024 * 1024) {
        // Large file, tail showed nothing: scan the first 1MB (early
        // modloader dependency failures abort before much is logged).
        NSMutableString *headErrors = [NSMutableString string];
        BOOL hMod = NO, hErr = NO;
        NSString *hMsg = [self scanHead:latestReader
                           errorSection:headErrors
                               foundMod:&hMod
                             foundError:&hErr];
        if (hMsg) modloaderMessage = hMsg;
        if (hMod) foundMod = YES;
        if (hErr && errorSection.length == 0) {
            [errorSection appendString:headErrors];
            foundError = YES;
        }
    }
    if (!modloaderMessage && crashPath) {
        WitchLogFileInfo *ci = InfoForPath(crashPath);
        if (ci) {
            WitchLogReader *cr = [[WitchLogReader alloc] initWithFileInfo:ci];
            NSArray<NSString *> *crashTail = [cr syncReadTail:2000 startLine:nil];
            NSMutableString *dummy = [NSMutableString string];
            BOOL cMod = NO, cErr = NO;
            NSString *cMsg = [self scanLines:crashTail errorSection:dummy
                                    foundMod:&cMod foundError:&cErr stopEarly:NO];
            if (cMsg) modloaderMessage = cMsg;
            if (cMod && !foundMod) {
                foundMod = YES;
                [errorSection appendString:@"[mod-conflict keywords detected in crash report]\n"];
            }
            if (cErr && !foundError && errorSection.length < 1024) {
                [errorSection appendString:dummy];
                foundError = YES;
            }
        }
    }
    if (!foundMod && modloaderMessage.length > 0) foundMod = YES;
    result.modloaderMessage = modloaderMessage;
    // hs_err quick check (small files, direct capped read).
    if (!foundMod && !foundError && hsErrPath) {
        NSString *hs = [self cappedHeadOfFile:hsErrPath maxBytes:64 * 1024];
        NSString *lower = hs.lowercaseString;
        if ([lower rangeOfString:@"problematic frame"].location != NSNotFound ||
            [lower rangeOfString:@"current thread"].location != NSNotFound ||
            [lower rangeOfString:@"siginfo"].location != NSNotFound) {
            foundError = YES;
            [errorSection appendFormat:@"[hs_err excerpt]\n%@\n",
             hs.length > 4000 ? [[hs substringToIndex:4000] stringByAppendingString:@"\n..."] : hs];
        }
    }
    if (foundMod) result.category = WitchLogCategoryModConflict;
    else if (foundError) result.category = WitchLogCategoryError;

    // ---- 4. Tail section (reuses the block read above, byte-capped) ----
    NSArray<NSString *> *tailSlice = tailBlock.count > kTailLines
        ? [tailBlock subarrayWithRange:NSMakeRange(tailBlock.count - kTailLines, kTailLines)] : tailBlock;
    NSMutableArray<NSString *> *cappedTail = [NSMutableArray array];
    NSUInteger tailBytes = 0;
    for (NSInteger i = (NSInteger)tailSlice.count - 1; i >= 0; i--) {
        NSUInteger lb = [tailSlice[i] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (tailBytes + lb > kMaxTailBytes) break;
        tailBytes += lb + 1;
        [cappedTail insertObject:tailSlice[i] atIndex:0];
    }

    // ---- 5. Assemble ----
    NSMutableString *snap = [NSMutableString string];
    [snap appendString:@"===== WITCH CRASH SNAPSHOT =====\n"];
    [snap appendFormat:@"exitCode: %d\n", code];
    if (metadata) {
        for (NSString *k in @[@"appVersion", @"mcVersion", @"device", @"ios", @"renderer", @"java"]) {
            NSString *v = metadata[k];
            if ([v isKindOfClass:[NSString class]] && v.length > 0) [snap appendFormat:@"%@: %@\n", k, v];
        }
    }
    if (latestInfo) [snap appendFormat:@"latestlog: %@ (%llu bytes)\n", latestPath.lastPathComponent, latestInfo.fileSize];
    if (crashPath) [snap appendFormat:@"crashReport: %@\n", crashPath.lastPathComponent];
    if (hsErrPath) [snap appendFormat:@"hsErr: %@\n", hsErrPath.lastPathComponent];
    if (modloaderMessage.length > 0) {
        [snap appendString:@"\n----- modloader message -----\n"];
        [snap appendString:modloaderMessage];
        [snap appendString:@"\n"];
    }
    if (errorSection.length > 0) {
        [snap appendString:@"\n----- errors (with context) -----\n"];
        [snap appendString:errorSection];
        [snap appendString:@"\n"];
    }
    [snap appendString:@"\n----- last log lines -----\n"];
    [snap appendString:[cappedTail componentsJoinedByString:@"\n"]];
    [snap appendString:@"\n===== END SNAPSHOT =====\n"];

    // Hard cap by bytes (cut at a line boundary).
    NSData *data = [snap dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length > maxBytes) {
        // Truncate the tail section first (most valuable content is at the top).
        NSUInteger over = data.length - maxBytes;
        if (over < cappedTail.count) {
            // crude but effective: drop whole oldest tail lines
            NSString *joined = [cappedTail componentsJoinedByString:@"\n"];
            NSData *tailData = [joined dataUsingEncoding:NSUTF8StringEncoding];
            if (tailData.length > over + 1024) {
                NSData *cut = [tailData subdataWithRange:NSMakeRange(over + 1024, tailData.length - over - 1024)];
                NSString *cutStr = [[NSString alloc] initWithData:cut encoding:NSUTF8StringEncoding];
                if (!cutStr) cutStr = @"";
                NSRange nl = [cutStr rangeOfString:@"\n"];
                if (nl.location != NSNotFound) cutStr = [cutStr substringFromIndex:nl.location + 1];
                NSMutableString *re = [NSMutableString string];
                [re appendString:@"===== WITCH CRASH SNAPSHOT =====\n"];
                [re appendFormat:@"exitCode: %d\n", code];
                if (modloaderMessage.length > 0) {
                    [re appendString:@"\n----- modloader message -----\n"];
                    [re appendString:modloaderMessage];
                    [re appendString:@"\n"];
                }
                if (errorSection.length > 0) {
                    [re appendString:@"\n----- errors (with context) -----\n"];
                    [re appendString:errorSection];
                    [re appendString:@"\n"];
                }
                [re appendString:@"\n----- last log lines (truncated head) -----\n[...]\n"];
                [re appendString:cutStr];
                [re appendString:@"\n===== END SNAPSHOT =====\n"];
                snap = re;
            }
        }
        data = [snap dataUsingEncoding:NSUTF8StringEncoding];
        if (data.length > maxBytes) {
            // Last resort: byte cut at UTF-8 boundary.
            NSUInteger cut = maxBytes - 64;
            while (cut > 0 && cut < data.length) {
                uint8_t b = ((const uint8_t *)data.bytes)[cut];
                if ((b & 0xC0) != 0x80) break;
                cut--;
            }
            snap = [[[NSString alloc] initWithBytes:data.bytes length:cut encoding:NSUTF8StringEncoding] mutableCopy] ?: [NSMutableString string];
            [snap appendString:@"\n[... snapshot truncated ...]\n"];
        }
    }

    result.snapshot = snap;
    result.totalBytes = latestInfo ? latestInfo.fileSize : 0;
    result.totalLines = NSNotFound; // indexed lazily by the viewer
    return result;
}

// MARK: - Scanners (bounded input, single pass)

/// Scan an in-memory line array (oldest-first): modloader user message,
/// mod-conflict flag, error hits with ±3 line context.
+ (nullable NSString *)scanLines:(NSArray<NSString *> *)lines
                    errorSection:(NSMutableString *)errorSection
                        foundMod:(BOOL *)outMod
                      foundError:(BOOL *)outError
                       stopEarly:(BOOL)stopEarly {
    NSArray *triggers = @[@"formattedexception", @"some of your mods are incompatible",
                          @"missing or unsupported mandatory dependencies",
                          @"một giải pháp tiềm năng", @"danh sách phụ thuộc chưa được đáp ứng"];
    NSArray *modPatterns = @[@"missing or unsupported mandatory dependencies", @"requires mod",
                             @"missing mod", @"conflicting mod", @"incompatible mod",
                             @"-- mods --", @"mods are missing", @"needs the following"];
    NSArray *errPatterns = @[@"exception", @"caused by", @"the game crashed whilst",
                             @"fatal error", @"failed to load", @"stacktrace"];
    NSRegularExpression *stackRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*at [\\w]"
                                                                                options:0 error:nil];
    NSRegularExpression *prefixRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[[^]]*\\] \\[[^]]*\\] [^:]*: "
                                                                                 options:0 error:nil];
    __block BOOL mlStarted = NO, mlFirst = YES, mlDone = NO;
    __block NSMutableArray<NSString *> *mlMsg = [NSMutableArray array];
    __block NSUInteger mlBytes = 0;
    __block BOOL foundMod = NO, foundErr = NO;
    __block NSMutableArray<NSString *> *window = [NSMutableArray array]; // last 3 lines
    __block NSUInteger errBytes = 0;
    __block NSInteger afterContext = 0;
    for (NSString *raw in lines) {
        @autoreleasepool {
            // --- modloader machine ---
            if (!mlDone) {
                if (!mlStarted) {
                    if (LineContainsAny(raw, triggers)) { mlStarted = YES; }
                }
                if (mlStarted) {
                    BOOL endBlock = NO;
                    if (!mlFirst) {
                        if ([stackRegex firstMatchInString:raw options:0 range:NSMakeRange(0, raw.length)]) endBlock = YES;
                        else if ([raw containsString:@"]]>"]) endBlock = YES;
                        else {
                            NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                            if ([trimmed hasPrefix:@"<log4j:"] && ![raw containsString:@"<![CDATA["]) endBlock = YES;
                            else if ([prefixRegex firstMatchInString:raw options:0 range:NSMakeRange(0, raw.length)]) endBlock = YES;
                        }
                    }
                    if (endBlock) { mlDone = YES; }
                    else {
                        mlFirst = NO;
                        NSString *line = raw;
                        if ([line containsString:@"<![CDATA["]) {
                            line = [line substringFromIndex:NSMaxRange([line rangeOfString:@"<![CDATA["])];
                        }
                        if ([line containsString:@"FormattedException: "]) {
                            line = [line substringFromIndex:NSMaxRange([line rangeOfString:@"FormattedException: "])];
                        }
                        NSTextCheckingResult *m = [prefixRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
                        if (m) line = [line substringFromIndex:NSMaxRange(m.range)];
                        if (line.length > 0) {
                            mlBytes += [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                            if (mlBytes > kMaxModloaderBytes) mlDone = YES;
                            else [mlMsg addObject:line];
                        }
                    }
                }
            }
            // --- mod patterns (skip once decided) ---
            if (!foundMod && mlMsg.count == 0) {
                if (LineContainsAny(raw, modPatterns)) foundMod = YES;
            }
            // --- error patterns with context ---
            if (!foundErr || afterContext > 0 || errBytes < kMaxErrorBytes) {
                if (LineContainsAny(raw, errPatterns)) {
                    foundErr = YES;
                    if (errBytes < kMaxErrorBytes) {
                        for (NSString *ctx in window) {
                            NSUInteger lb = [ctx lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                            if (errBytes + lb > kMaxErrorBytes) break;
                            [errorSection appendString:ctx];
                            [errorSection appendString:@"\n"];
                            errBytes += lb + 1;
                        }
                        NSUInteger lb = [raw lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                        if (errBytes + lb <= kMaxErrorBytes) {
                            [errorSection appendString:@"> "];
                            [errorSection appendString:raw];
                            [errorSection appendString:@"\n"];
                            errBytes += lb + 3;
                        }
                        [window removeAllObjects];
                        afterContext = 3;
                    }
                } else if (afterContext > 0 && errBytes < kMaxErrorBytes) {
                    NSUInteger lb = [raw lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                    if (errBytes + lb > kMaxErrorBytes) { afterContext = 0; }
                    else {
                        [errorSection appendString:raw];
                        [errorSection appendString:@"\n"];
                        errBytes += lb + 1;
                        afterContext--;
                    }
                }
            }
            [window addObject:raw];
            if (window.count > 3) [window removeObjectAtIndex:0];
            if (stopEarly && errBytes >= kMaxErrorBytes && foundErr && mlDone && afterContext == 0) {
                [errorSection appendString:@"[... more errors omitted ...]\n"];
                break;
            }
        }
    }
    if (mlMsg.count > 0) foundMod = YES;
    if (outMod) *outMod = foundMod;
    if (outError) *outError = foundErr;
    if (mlMsg.count == 0) return nil;
    NSString *out = [mlMsg componentsJoinedByString:@"\n"];
    if (out.length > 4000) out = [[out substringToIndex:4000] stringByAppendingString:@"\n..."];
    return out;
}

/// Scan the first 1MB of a large file (early dependency failures abort early).
+ (nullable NSString *)scanHead:(WitchLogReader *)reader
                   errorSection:(NSMutableString *)errorSection
                       foundMod:(BOOL *)outMod
                     foundError:(BOOL *)outError {
    NSMutableArray<NSString *> *head = [NSMutableArray array];
    [reader syncEnumerateLinesWithMaxBytes:1024 * 1024 batchSize:512
                                   handler:^(NSArray<NSString *> *batch, NSUInteger startLine, BOOL *stop) {
        [head addObjectsFromArray:batch];
        if (head.count >= 3000) *stop = YES;
    }];
    return [self scanLines:head errorSection:errorSection
                  foundMod:outMod foundError:outError stopEarly:YES];
}

+ (NSString *)cappedStringOfFile:(NSString *)path maxBytes:(NSUInteger)maxBytes {
    return [self cappedHeadOfFile:path maxBytes:maxBytes];
}

+ (NSString *)cappedHeadOfFile:(NSString *)path maxBytes:(NSUInteger)maxBytes {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) return @"";
    NSData *data = nil;
    @try {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        unsigned long long size = [attrs fileSize];
        if (size > maxBytes) {
            // Read the head (stack traces start at the top of hs_err).
            data = [fh readDataOfLength:maxBytes];
        } else {
            data = [fh readDataToEndOfFile];
        }
    } @finally {
        [fh closeFile];
    }
    if (!data) return @"";
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return s ?: @"";
}

+ (NSArray<NSString *> *)tailLinesOfFile:(NSString *)path maxLines:(NSUInteger)maxLines {
    if (!path || maxLines == 0) return @[];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!attrs) return @[];
    WitchLogFileInfo *info = [WitchLogFileInfo new];
    info.path = path;
    info.fileSize = [attrs fileSize];
    info.modDate = attrs[NSFileModificationDate];
    info.lineCount = NSNotFound;
    WitchLogCheckpoint *zero = [WitchLogCheckpoint new];
    zero.line = 0; zero.byteOffset = 0;
    info.checkpoints = @[zero];
    WitchLogReader *reader = [[WitchLogReader alloc] initWithFileInfo:info];
    return [reader syncReadTail:maxLines startLine:nil];
}

@end
