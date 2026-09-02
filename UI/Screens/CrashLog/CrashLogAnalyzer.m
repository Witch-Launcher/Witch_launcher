#import "CrashLogAnalyzer.h"

@implementation CrashLogAnalyzerResult
@end

@implementation CrashLogAnalyzer

static NSString *latestLogPath(void) {
    const char *home = getenv("POJAV_HOME");
    if (!home) return nil;
    return [@(home) stringByAppendingPathComponent:@"latestlog.txt"];
}

static NSString *newestFileInDir(NSString *dir, NSArray<NSString *> *patterns) {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil];
    NSString *newest = nil;
    NSDate *newestDate = nil;
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
        if (!newestDate || [attrs.fileModificationDate compare:newestDate] == NSOrderedDescending) {
            newest = path;
            newestDate = attrs.fileModificationDate;
        }
    }
    return newest;
}

static NSString *newestCrashReport(void) {
    NSString *home = NSHomeDirectory();
    NSString *pojavHome = latestLogPath() ? [latestLogPath() stringByDeletingLastPathComponent] : nil;
    NSMutableArray *roots = [NSMutableArray array];
    if (pojavHome) {
        [roots addObject:[pojavHome stringByAppendingPathComponent:@"crash-reports"]];
    }
    [roots addObjectsFromArray:@[
        [home stringByAppendingPathComponent:@"Documents/crash-reports"],
        [home stringByAppendingPathComponent:@"Documents/.minecraft/crash-reports"],
    ]];
    NSString *newest = nil;
    for (NSString *root in roots) {
        NSString *candidate = newestFileInDir(root, @[@".txt", @"crash-"]);
        if (candidate && (!newest ||
            [[NSFileManager.defaultManager attributesOfItemAtPath:candidate error:nil].fileModificationDate
                compare:[NSFileManager.defaultManager attributesOfItemAtPath:newest error:nil].fileModificationDate] == NSOrderedDescending)) {
            newest = candidate;
        }
    }
    return newest;
}

static NSString *newestHsErr(void) {
    NSString *home = NSHomeDirectory();
    const char *cwd = getenv("PWD");
    NSMutableArray *roots = [NSMutableArray array];
    if (cwd) [roots addObject:@(cwd)];
    if (latestLogPath()) [roots addObject:[latestLogPath() stringByDeletingLastPathComponent]];
    [roots addObjectsFromArray:@[
        home,
        [home stringByAppendingPathComponent:@"Documents"],
    ]];
    NSString *newest = nil;
    for (NSString *root in roots) {
        NSString *candidate = newestFileInDir(root, @[@"hs_err_pid", @"replay_pid"]);
        if (candidate && (!newest ||
            [[NSFileManager.defaultManager attributesOfItemAtPath:candidate error:nil].fileModificationDate
                compare:[NSFileManager.defaultManager attributesOfItemAtPath:newest error:nil].fileModificationDate] == NSOrderedDescending)) {
            newest = candidate;
        }
    }
    return newest;
}

+ (CrashLogAnalyzerResult *)analyzeWithExitCode:(int)code {
    NSString *logPath = latestLogPath();
    NSString *crashPath = newestCrashReport();
    NSString *hsErrPath = newestHsErr();

    NSString *logContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    NSString *crashContent = crashPath ? [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil] : nil;
    NSString *hsErrContent = hsErrPath ? [NSString stringWithContentsOfFile:hsErrPath encoding:NSUTF8StringEncoding error:nil] : nil;

    CrashLogAnalyzerResult *result = [CrashLogAnalyzerResult new];
    result.latestLogPath = logPath;
    result.crashReportPath = crashPath;
    result.hsErrPath = hsErrPath;
    // Full log gộp cả 3 nguồn để AI và full view có đủ thông tin
    NSMutableArray<NSString *> *allParts = [NSMutableArray array];
    if (logContent.length > 0) [allParts addObject:logContent];
    if (crashContent.length > 0) [allParts addObject:[NSString stringWithFormat:@"\n===== CRASH REPORT (%@) =====\n%@", crashPath.lastPathComponent, crashContent]];
    if (hsErrContent.length > 0) [allParts addObject:[NSString stringWithFormat:@"\n===== HS_ERR (%@) =====\n%@", hsErrPath.lastPathComponent, hsErrContent]];
    result.fullLog = [allParts componentsJoinedByString:@"\n"];

    // Luôn tính 100 dòng cuối cho người đọc (trên máy, không phải AI)
    NSArray<NSString *> *allLines = [result.fullLog componentsSeparatedByString:@"\n"];
    NSUInteger start = allLines.count > 100 ? allLines.count - 100 : 0;
    NSString *last100 = [[allLines subarrayWithRange:NSMakeRange(start, allLines.count - start)] componentsJoinedByString:@"\n"];

    // Dùng hits để xác định category, nhưng excerpt mặc định vẫn là 100 dòng cuối (theo yêu cầu fix)
    NSMutableArray<NSArray<NSString *> *> *blockSources = [NSMutableArray array];
    if (logContent) [blockSources addObject:[logContent componentsSeparatedByString:@"\n"]];
    if (crashContent) [blockSources addObject:[crashContent componentsSeparatedByString:@"\n"]];

    NSString *modloaderMessage = [self extractModloaderMessageFromBlocks:blockSources];
    if (modloaderMessage.length > 0) {
        result.category = CrashLogCategoryModConflict;
        result.excerpt = last100;
        return result;
    }

    NSArray<NSArray<NSNumber *> *> *modHits = [self findHits:@[
        @"missing or unsupported mandatory dependencies",
        @"requires mod",
        @"missing mod",
        @"conflicting mod",
        @"incompatible mod",
        @"mod file",
        @"-- mods --",
        @"mods are missing",
        @"needs the following",
    ] inBlocks:blockSources];

    if ([self hitCount:modHits] > 0) {
        result.category = CrashLogCategoryModConflict;
        result.excerpt = last100;
        return result;
    }

    NSArray<NSArray<NSNumber *> *> *errorHits = [self findHits:@[
        @"exception",
        @"caused by",
        @"the game crashed whilst",
        @"fatal error",
        @"error:",
        @"failed to load",
        @"stacktrace",
        @"at java.",
        @"at org.",
        @"at net.",
        @"at dev.",
        @"at com.",
    ] inBlocks:blockSources];

    if ([self hitCount:errorHits] > 0) {
        result.category = CrashLogCategoryError;
        result.excerpt = last100;
        return result;
    }

    if (hsErrContent) {
        NSArray<NSArray<NSString *> *> *hsErrBlocks = @[[hsErrContent componentsSeparatedByString:@"\n"]];
        NSArray<NSArray<NSNumber *> *> *hsErrHits = [self findHits:@[
            @"# sig", @"# exception", @"# error", @"problematic frame", @"current thread",
            @"siginfo", @"register to memory mapping", @"safepoint synchronization"
        ] inBlocks:hsErrBlocks];
        if ([self hitCount:hsErrHits] > 0) {
            result.category = CrashLogCategoryError;
            result.excerpt = last100;
            return result;
        }
    }

    result.category = CrashLogCategoryRaw;
    result.excerpt = last100;
    return result;
}

+ (NSArray<NSArray<NSNumber *> *> *)findHits:(NSArray<NSString *> *)patterns inBlocks:(NSArray<NSArray<NSString *> *> *)blocks {
    NSMutableArray *result = [NSMutableArray array];
    for (NSArray *block in blocks) {
        NSMutableArray *indexes = [NSMutableArray array];
        for (NSInteger i = 0; i < block.count; i++) {
            NSString *line = block[i];
            for (NSString *pattern in patterns) {
                if ([line rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [indexes addObject:@(i)];
                    break;
                }
            }
        }
        [result addObject:indexes];
    }
    return result;
}

+ (NSUInteger)hitCount:(NSArray<NSArray<NSNumber *> *> *)hits {
    NSUInteger count = 0;
    for (NSArray *blockHits in hits) {
        count += blockHits.count;
    }
    return count;
}

+ (NSString *)extractModloaderMessageFromBlocks:(NSArray<NSArray<NSString *> *> *)blocks {
    NSRegularExpression *stackRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*at [\\w]"
                                                                               options:0
                                                                                 error:nil];
    NSRegularExpression *logPrefixRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[[^]]*\\] \\[[^]]*\\] [^:]*: "
                                                                                   options:0
                                                                                     error:nil];
    for (NSArray<NSString *> *block in blocks) {
        BOOL started = NO;
        BOOL isFirstLine = YES;
        NSMutableArray<NSString *> *messageLines = [NSMutableArray array];

        for (NSString *rawLine in block) {
            NSString *line = rawLine;
            NSString *lowerLine = line.lowercaseString;
            if (!started) {
                if ([lowerLine containsString:@"formattedexception"] ||
                    [lowerLine containsString:@"some of your mods are incompatible"] ||
                    [lowerLine containsString:@"missing or unsupported mandatory dependencies"] ||
                    [lowerLine containsString:@"một giải pháp tiềm năng"] ||
                    [lowerLine containsString:@"danh sách phụ thuộc chưa được đáp ứng"]) {
                    started = YES;
                } else {
                    continue;
                }
            }

            // Stack trace lines ("    at net.fabricmc...") mark the end of
            // the modloader's user-facing message.
            if (!isFirstLine && [stackRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)]) {
                break;
            }
            // A new log4j XML entry / CDATA terminator closes the message block.
            if ([line containsString:@"]]>"]) break;
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([trimmed hasPrefix:@"<log4j:"] && ![line containsString:@"<![CDATA["]) {
                break;
            }
            // A new timestamped log entry closes the message block, but the
            // first line itself may carry a "[time] [level/thread]" prefix.
            if (!isFirstLine && [logPrefixRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)]) {
                break;
            }
            isFirstLine = NO;

            // Strip the log4j XML CDATA wrapper, if the message starts inside one.
            if ([line containsString:@"<![CDATA["]) {
                line = [line substringFromIndex:NSMaxRange([line rangeOfString:@"<![CDATA["])];
            }
            // Strip the exception class prefix: "net.fabricmc.loader.impl.FormattedException: ".
            if ([line containsString:@"FormattedException: "]) {
                line = [line substringFromIndex:NSMaxRange([line rangeOfString:@"FormattedException: "])];
            }
            // Strip a leading "[12:34:56] [Main/INFO] ..." timestamp prefix.
            NSTextCheckingResult *prefixMatch = [logPrefixRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (prefixMatch) {
                line = [line substringFromIndex:NSMaxRange(prefixMatch.range)];
            }

            if (line.length > 0) {
                [messageLines addObject:line];
            }
        }

        if (started && messageLines.count > 0) {
            NSString *message = [messageLines componentsJoinedByString:@"\n"];
            if (message.length > 4000) {
                message = [message substringToIndex:4000];
                message = [message stringByAppendingString:@"\n..."];
            }
            return message;
        }
    }
    return nil;
}

+ (NSString *)buildExcerptFromHits:(NSArray<NSArray<NSNumber *> *> *)hits blocks:(NSArray<NSArray<NSString *> *> *)blocks {
    NSMutableArray *collected = [NSMutableArray array];
    for (NSUInteger blockIndex = 0; blockIndex < blocks.count; blockIndex++) {
        NSArray *block = blocks[blockIndex];
        NSArray *blockHits = hits[blockIndex];
        if (blockHits.count == 0) continue;

        NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
        for (NSNumber *hit in blockHits) {
            NSInteger idx = hit.integerValue;
            NSInteger start = MAX(0, idx - 2);
            NSInteger end = MIN((NSInteger)block.count - 1, idx + 15);
            [indexes addIndexesInRange:NSMakeRange(start, end - start + 1)];
        }
        if (collected.count > 0) [collected addObject:@"..."];
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [collected addObject:block[idx]];
        }];
    }
    NSString *excerpt = [collected componentsJoinedByString:@"\n"];
    if (excerpt.length > 6000) {
        excerpt = [excerpt substringToIndex:6000];
        excerpt = [excerpt stringByAppendingString:@"\n..."];
    }
    return excerpt;
}

@end
