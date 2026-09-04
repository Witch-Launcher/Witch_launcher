#import "WitchLogReporter.h"
#import "LauncherPreferences.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import "WitchCrypto.h"
#import "WitchLogSnapshot.h"
#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#else
#define WITCH_DEFAULT_BASE_URL @""
#define WITCH_DEFAULT_HMAC_SECRET @""
#define WITCH_DEFAULT_PROXY_TOKEN @""
#define WITCH_DEFAULT_CURSEFORGE_API_KEY @""
#endif

// Raw log attachments cap: files stream from disk, so this bounds bandwidth
// and server/Discord-side size, not RAM. Oversized logs send their tail.
static const unsigned long long kMaxAttachBytes = 24ULL * 1024ULL * 1024ULL;

static NSString* WitchProxyBaseURL2(void) {
    NSString *url = getPrefObject(@"witch.proxy_base_url");
    if ([url isKindOfClass:[NSString class]]) {
        NSString *dec = [WitchCrypto decryptPrefValue:url];
        if (dec) url = dec;
        url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (url.length > 0) {
            if ([url hasSuffix:@"/"]) url = [url substringToIndex:url.length-1];
            return url;
        }
    }
    NSString *bundled = WITCH_DEFAULT_BASE_URL;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        if (dec) bundled = dec;
        if ([bundled hasSuffix:@"/"]) bundled = [bundled substringToIndex:bundled.length-1];
        return bundled;
    }
    return @"";
}
static NSString* WitchProxyToken2(void) {
    id v = getPrefObject(@"witch.proxy_token");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] >0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        return dec ?: v;
    }
    NSString *bundled = WITCH_DEFAULT_PROXY_TOKEN;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length>0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
}
static NSString* WitchProxyHMACSecret2(void) {
    id v = getPrefObject(@"witch.proxy_hmac");
    if (!v) v = getPrefObject(@"witch.proxy_hmac_secret");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length]>0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        return dec ?: v;
    }
    NSString *bundled = WITCH_DEFAULT_HMAC_SECRET;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length>0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
}
static NSString* WitchDeviceId2(void) {
    NSString *did = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.device_id"];
    if (did.length > 0) return did;
    did = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:did forKey:@"witch.device_id"];
    return did;
}
static NSString* SHA256HexOfString(NSString *input) {
    if (!input) input = @"";
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}
static NSString* HMACSHA256HexOfStrings(NSString *secret, NSString *message) {
    NSData *keyData = [secret dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    NSData *msgData = [message dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyData.bytes, keyData.length, msgData.bytes, msgData.length, cHMAC);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", cHMAC[i]];
    return hex;
}

/// Cut a (small) string at a line boundary under maxChars.
static NSString *TruncateAtLine(NSString *s, NSUInteger maxChars) {
    if (!s || s.length <= maxChars) return s ?: @"";
    NSRange r = [s rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, maxChars)];
    NSUInteger cut = (r.location != NSNotFound) ? r.location : maxChars;
    return [[s substringToIndex:cut] stringByAppendingString:@"\n..."];
}

@implementation WitchLogReporter

+ (WitchLogUploader *)sharedUploader {
    NSString *base = WitchProxyBaseURL2();
    if (!base.length) return nil;
    return [[WitchLogUploader alloc] initWithBaseURL:base authHandler:^(NSMutableURLRequest *req, NSString *bodyHint) {
        NSString *token = WitchProxyToken2();
        if (token.length > 0) {
            NSString *transport = token;
            if ([WitchCrypto isEnabled]) {
                NSString *enc = [WitchCrypto encryptForTransport:token];
                if (enc.length > 0) { transport = enc; [req setValue:@"1" forHTTPHeaderField:@"X-Witch-Enc"]; }
            }
            [req setValue:[NSString stringWithFormat:@"Bearer %@", transport] forHTTPHeaderField:@"Authorization"];
        } else if ([WitchCrypto isEnabled]) {
            [req setValue:@"1" forHTTPHeaderField:@"X-Witch-Enc"];
        }
        NSString *secret = WitchProxyHMACSecret2();
        // apiPath is unknown here; derive from URL for the HMAC message.
        NSString *path = req.URL.path.length ? req.URL.path : @"/v1/logs/report";
        if (secret.length > 0) {
            NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]*1000];
            NSString *bodyHash = SHA256HexOfString(bodyHint);
            NSString *message = [NSString stringWithFormat:@"%@.%@.%@.%@", timestamp, req.HTTPMethod ?: @"POST", path, bodyHash];
            NSString *sig = HMACSHA256HexOfStrings(secret, message);
            [req setValue:timestamp forHTTPHeaderField:@"X-Witch-Timestamp"];
            [req setValue:sig forHTTPHeaderField:@"X-Witch-Signature"];
            [req setValue:WitchDeviceId2() forHTTPHeaderField:@"X-Witch-DeviceId"];
        } else if (token.length > 0) {
            [req setValue:WitchDeviceId2() forHTTPHeaderField:@"X-Witch-DeviceId"];
        }
        NSString *attest = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.assertion"];
        if (attest.length > 20) {
            [req setValue:attest forHTTPHeaderField:@"X-Witch-AppAttest"];
            NSString *keyId = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.keyId"];
            if (keyId.length > 0) [req setValue:keyId forHTTPHeaderField:@"X-Witch-AppAttest-KeyId"];
        }
    }];
}

/// Read a whole small file as text (for crash/hs_err full embed). Returns nil
/// when the file is missing, empty, or larger than maxBytes (caller then uses
/// the capped preview instead). Never called on the main thread with big files
/// — call sites gate on fileSize first.
static NSString * _Nullable FullTextOfSmallFile(NSString * _Nullable path, unsigned long long maxBytes) {
    if (!path.length) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long sz = attrs ? [attrs fileSize] : 0;
    if (sz == 0 || sz > maxBytes) return nil;
    NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!s) {
        NSData *d = [NSData dataWithContentsOfFile:path];
        if (d) s = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
    }
    return s.length > 0 ? s : nil;
}

+ (NSDictionary*)collectLogPayloadWithAnalysis:(CrashLogAnalyzerResult*)analysis {
    // Bounded by construction: snapshot (~tens of KB) instead of fullLog.
    NSString *excerpt = analysis.excerpt ?: @"";
    NSString *snapshot = analysis.snapshot ?: analysis.fullLog ?: @"";
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    if (excerpt.length > 0) {
        NSString *t = TruncateAtLine(excerpt, 20000);
        payload[@"excerpt"] = t;
        payload[@"excerpt_truncated"] = @(t.length < excerpt.length);
    }
    if (snapshot.length > 0) {
        NSString *t = TruncateAtLine(snapshot, 100000);
        payload[@"snapshot"] = t;
        payload[@"snapshot_truncated"] = @(t.length < snapshot.length);
    }
    // Crash/hs_err: preview (capped head for Discord message) + FULL text when
    // small so the bot can forward complete files instead of "mỗi một khúc".
    // Server contract (back-compat): old servers read crashReport/hsErr as the
    // message preview; new servers prefer crashReportFull/hsErrFull (+ _isFull)
    // as file attachments with proper filenames.
    static const unsigned long long kFullEmbedMax = 512 * 1024;
    if (analysis.crashReportPath) {
        NSString *crash = [WitchLogSnapshotter cappedHeadOfFile:analysis.crashReportPath maxBytes:100 * 1024];
        if (crash.length > 0) payload[@"crashReport"] = TruncateAtLine(crash, 100000);
        payload[@"crashReportPath"] = analysis.crashReportPath;
        payload[@"crashReportName"] = analysis.crashReportPath.lastPathComponent ?: @"crash-report.txt";
        NSString *full = FullTextOfSmallFile(analysis.crashReportPath, kFullEmbedMax);
        if (full.length > 0) {
            payload[@"crashReportFull"] = full;
            payload[@"crashReportFull_isFull"] = @YES;
        } else if (crash.length > 0) {
            payload[@"crashReportFull_isFull"] = @NO;
            NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:analysis.crashReportPath error:nil];
            if (a) payload[@"crashReportSize"] = @([a fileSize]);
        }
    }
    if (analysis.hsErrPath) {
        NSString *hs = [WitchLogSnapshotter cappedHeadOfFile:analysis.hsErrPath maxBytes:100 * 1024];
        if (hs.length > 0) payload[@"hsErr"] = TruncateAtLine(hs, 100000);
        payload[@"hsErrPath"] = analysis.hsErrPath;
        payload[@"hsErrName"] = analysis.hsErrPath.lastPathComponent ?: @"hs_err.log";
        NSString *full = FullTextOfSmallFile(analysis.hsErrPath, kFullEmbedMax);
        if (full.length > 0) {
            payload[@"hsErrFull"] = full;
            payload[@"hsErrFull_isFull"] = @YES;
        } else if (hs.length > 0) {
            payload[@"hsErrFull_isFull"] = @NO;
            NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:analysis.hsErrPath error:nil];
            if (a) payload[@"hsErrSize"] = @([a fileSize]);
        }
    }
    if (analysis.latestLogPath) {
        payload[@"latestLogPath"] = analysis.latestLogPath;
        payload[@"latestLogName"] = @"latestlog.txt";
    }
    payload[@"totalBytes"] = @(analysis.totalBytes);
    NSString *catStr = @"raw";
    if (analysis.category == CrashLogCategoryModConflict) catStr = @"mod_conflict";
    else if (analysis.category == CrashLogCategoryError) catStr = @"error";
    payload[@"category"] = catStr;
    payload[@"deviceId"] = WitchDeviceId2();
    payload[@"appVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    // Explicit Discord message body so the bot always posts a real message
    // (not just file previews). Server may use `message` verbatim as content
    // with files attached; old servers ignore unknown keys.
    // Built fully in sendReport (needs exitCode/note) — placeholder here.
    return [payload copy];
}

/// Discord-friendly message text for the report. Always short (<1500 chars)
/// so it fits in one Discord message even with attachments.
+ (NSString *)discordMessageForAnalysis:(CrashLogAnalyzerResult *)analysis
                              exitCode:(int)code
                                  note:(nullable NSString *)note {
    NSString *catStr = @"raw";
    if (analysis.category == CrashLogCategoryModConflict) catStr = @"mod_conflict";
    else if (analysis.category == CrashLogCategoryError) catStr = @"error";
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    if (analysis.latestLogPath.length) [files addObject:@"latestlog.txt"];
    if (analysis.crashReportPath.length) [files addObject:analysis.crashReportPath.lastPathComponent ?: @"crash-report.txt"];
    if (analysis.hsErrPath.length) [files addObject:analysis.hsErrPath.lastPathComponent ?: @"hs_err.log"];
    NSString *appVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    NSString *mcVer = [self currentMcVersion];
    NSMutableString *m = [NSMutableString string];
    [m appendFormat:@"Witch crash report - exit %d - %@ - MC %@ - Witch v%@", code, catStr, mcVer, appVer];
    if (files.count) [m appendFormat:@"\nFiles: %@", [files componentsJoinedByString:@", "]];
    if (note.length) {
        NSString *n = note.length > 500 ? [[note substringToIndex:500] stringByAppendingString:@"..."] : note;
        [m appendFormat:@"\nNote: %@", n];
    }
    // Snapshot/excerpt travel as JSON + file attachments; the message itself
    // stays short so Discord never truncates it to "một khúc".
    return [m copy];
}

+ (NSString*)currentMcVersion {
    NSString *mcVer = getPrefObject(@"internal.mc_version") ?: @"unknown";
    @try {
        Class mgrClass = NSClassFromString(@"VersionDirectoryManager");
        if (mgrClass) {
            id mgr = [mgrClass performSelector:@selector(shared)];
            NSString *curVer = [mgr performSelector:@selector(currentVersion)];
            if ([curVer isKindOfClass:[NSString class]] && curVer.length > 0) mcVer = curVer;
        }
    } @catch(...) {}
    return mcVer;
}

/// File entries as PATHS (never NSData): latestlog, crash, hs_err, recent .ips.
+ (NSArray<WitchUploadFile *> *)attachmentFilesForAnalysis:(CrashLogAnalyzerResult *)analysis {
    NSMutableArray<WitchUploadFile *> *files = [NSMutableArray array];
    if (analysis.latestLogPath && [[NSFileManager defaultManager] fileExistsAtPath:analysis.latestLogPath]) {
        [files addObject:[WitchUploadFile fileWithName:@"latestlog.txt" path:analysis.latestLogPath]];
    }
    if (analysis.crashReportPath && [[NSFileManager defaultManager] fileExistsAtPath:analysis.crashReportPath]) {
        [files addObject:[WitchUploadFile fileWithName:analysis.crashReportPath.lastPathComponent ?: @"crash-report.txt"
                                                  path:analysis.crashReportPath]];
    }
    if (analysis.hsErrPath && [[NSFileManager defaultManager] fileExistsAtPath:analysis.hsErrPath]) {
        [files addObject:[WitchUploadFile fileWithName:analysis.hsErrPath.lastPathComponent ?: @"hs_err.log"
                                                  path:analysis.hsErrPath]];
    }
    // Newest Witch .ips within 24h (launcher crash to home).
    {
        const char *home = getenv("POJAV_HOME");
        NSArray *searchDirs = @[
            [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter"],
            home ? @(home) : @""
        ];
        for (NSString *dir in searchDirs) {
            if (dir.length == 0) continue;
            NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
            for (NSString *f in dirFiles) {
                if ([f.pathExtension isEqualToString:@"ips"] && [f containsString:@"Witch"]) {
                    NSString *full = [dir stringByAppendingPathComponent:f];
                    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
                    NSDate *mod = attr[NSFileModificationDate];
                    if (mod && [[NSDate date] timeIntervalSinceDate:mod] < 86400) {
                        [files addObject:[WitchUploadFile fileWithName:f path:full]];
                        break;
                    }
                }
            }
        }
    }
    return files;
}

+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis exitCode:(int)code completion:(void(^)(BOOL, NSString*, NSError*))completion {
    [self sendReportWithAnalysis:analysis exitCode:code note:nil progress:nil completion:completion];
}

+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis exitCode:(int)code note:(NSString*)note completion:(void(^)(BOOL, NSString*, NSError*))completion {
    [self sendReportWithAnalysis:analysis exitCode:code note:note progress:nil completion:completion];
}

+ (WitchLogUploadJob *)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                     exitCode:(int)code
                                     progress:(void(^)(double))progress
                                   completion:(void(^)(BOOL, NSString*, NSError*))completion {
    return [self sendReportWithAnalysis:analysis exitCode:code note:nil progress:progress completion:completion];
}

+ (WitchLogUploadJob *)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                      exitCode:(int)code
                                          note:(nullable NSString*)note
                                      progress:(void(^)(double))progress
                                    completion:(void(^)(BOOL, NSString*, NSError*))completion {
    WitchLogUploadJob *earlyJob = [WitchLogUploadJob new];
    WitchLogUploader *uploader = [self sharedUploader];
    if (!uploader) {
        NSError *e = [NSError errorWithDomain:@"WitchLog" code:401
                                     userInfo:@{NSLocalizedDescriptionKey: @"Witch server not configured"}];
        earlyJob.state = WitchUploadStateFailed;
        earlyJob.error = e;
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, e); });
        return earlyJob;
    }
    // Payload assembly here is bounded (snapshot + capped heads + small full
    // embeds ≤512KB each + directory scans — no whole-log reads), so calling
    // the uploader directly is safe on any thread. All heavy IO streams on
    // background queues inside.
    NSMutableDictionary *payload = [[self collectLogPayloadWithAnalysis:analysis] mutableCopy];
    payload[@"exitCode"] = @(code);
    if (note.length > 0) payload[@"note"] = [note substringToIndex:MIN(note.length, 2000)];
    payload[@"mcVersion"] = [self currentMcVersion];
    // Explicit Discord message: guarantees the bot posts a real message with
    // file list (not just truncated previews).
    payload[@"message"] = [self discordMessageForAnalysis:analysis exitCode:code note:note];
    NSArray<WitchUploadFile *> *files = [self attachmentFilesForAnalysis:analysis];
    return [uploader uploadPayload:payload files:files toPath:@"/v1/logs/report"
                      maxFileBytes:kMaxAttachBytes progress:progress ?: ^(double f){ (void)f; }
                        completion:completion ?: ^(BOOL ok, NSString *sid, NSError *e){ (void)ok; (void)sid; (void)e; }];
}

+ (WitchLogUploadJob *)sendDeepReportWithAnalysis:(CrashLogAnalyzerResult*)analysis
                                          exitCode:(int)code
                                              note:(nullable NSString*)note
                                          progress:(void(^)(double))progress
                                    completion:(void(^)(BOOL, NSString*, NSError*))completion {
    WitchLogUploader *uploader = [self sharedUploader];
    if (!uploader) {
        WitchLogUploadJob *earlyJob = [WitchLogUploadJob new];
        NSError *e = [NSError errorWithDomain:@"WitchLog" code:401
                                     userInfo:@{NSLocalizedDescriptionKey: @"Witch server not configured"}];
        earlyJob.state = WitchUploadStateFailed;
        earlyJob.error = e;
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, e); });
        return earlyJob;
    }
    if (!analysis.latestLogPath) {
        WitchLogUploadJob *noFileJob = [WitchLogUploadJob new];
        NSError *e = [NSError errorWithDomain:@"WitchLog" code:404
                                     userInfo:@{NSLocalizedDescriptionKey: @"No log file found"}];
        noFileJob.state = WitchUploadStateFailed;
        noFileJob.error = e;
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, e); });
        return noFileJob;
    }
    // Deep used to upload ONLY latestlog — crash/hs_err arrived as 100KB
    // snippets ("mỗi một khúc, không phải tin nhắn"). Now the payload carries
    // their FULL text when small (≤512KB, the 99% case) plus a real `message`,
    // and the old-server fallback attaches them as FILES too.
    NSMutableDictionary *payload = [[self collectLogPayloadWithAnalysis:analysis] mutableCopy];
    payload[@"exitCode"] = @(code);
    payload[@"mode"] = @"deep";
    if (note.length > 0) payload[@"note"] = [note substringToIndex:MIN(note.length, 2000)];
    payload[@"mcVersion"] = [self currentMcVersion];
    payload[@"message"] = [self discordMessageForAnalysis:analysis exitCode:code note:note];
    // Chunked `complete` JSON already contains crash/hs_err FULL text when small
    // (see collectLogPayload). Old-server fallback rebuilds file attachments
    // from crashReportPath/hsErrPath inside the uploader.
    return [uploader uploadFileChunked:analysis.latestLogPath
                              fileName:@"latestlog.txt"
                               payload:payload
                              progress:progress ?: ^(double f){ (void)f; }
                            completion:completion ?: ^(BOOL ok, NSString *sid, NSError *e){ (void)ok; (void)sid; (void)e; }];
}

@end
