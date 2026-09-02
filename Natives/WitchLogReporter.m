#import "WitchLogReporter.h"
#import "LauncherPreferences.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#else
#define WITCH_DEFAULT_BASE_URL @""
#define WITCH_DEFAULT_HMAC_SECRET @""
#define WITCH_DEFAULT_PROXY_TOKEN @""
#define WITCH_DEFAULT_CURSEFORGE_API_KEY @""
#endif

static NSString* WitchProxyBaseURL2(void) {
    NSString *url = getPrefObject(@"witch.proxy_base_url");
    if ([url isKindOfClass:[NSString class]]) {
        url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (url.length > 0) {
            if ([url hasSuffix:@"/"]) url = [url substringToIndex:url.length-1];
            return url;
        }
    }
    NSString *bundled = WITCH_DEFAULT_BASE_URL;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        if ([bundled hasSuffix:@"/"]) bundled = [bundled substringToIndex:bundled.length-1];
        return bundled;
    }
    return @"";
}
static NSString* WitchProxyToken2(void) {
    id v = getPrefObject(@"witch.proxy_token");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] >0) return v;
    NSString *bundled = WITCH_DEFAULT_PROXY_TOKEN;
    return ([bundled isKindOfClass:[NSString class]] && bundled.length>0) ? bundled : nil;
}
static NSString* WitchProxyHMACSecret2(void) {
    id v = getPrefObject(@"witch.proxy_hmac");
    if (!v) v = getPrefObject(@"witch.proxy_hmac_secret");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length]>0) return v;
    NSString *bundled = WITCH_DEFAULT_HMAC_SECRET;
    return ([bundled isKindOfClass:[NSString class]] && bundled.length>0) ? bundled : nil;
}
static NSString* WitchDeviceId2(void) {
    NSString *did = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.device_id"];
    if (did.length > 0) return did;
    did = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:did forKey:@"witch.device_id"];
    return did;
}
static NSString* SHA256Hex2(NSString *input) {
    if (!input) input = @"";
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}
static NSString* HMACSHA256Hex2(NSString *secret, NSString *message) {
    const char *cKey = [secret cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", cHMAC[i]];
    return hex;
}

@implementation WitchLogReporter

+ (NSDictionary*)collectLogPayloadWithAnalysis:(CrashLogAnalyzerResult*)analysis {
    NSString *fullLog = analysis.fullLog ?: @"";
    NSString *excerpt = analysis.excerpt ?: @"";
    // Check last 20 lines of latestlog for references to other logs
    NSArray *lines = [fullLog componentsSeparatedByString:@"\n"];
    NSInteger start = lines.count > 20 ? lines.count - 20 : 0;
    NSArray *last20 = [lines subarrayWithRange:NSMakeRange(start, lines.count - start)];
    NSMutableArray *detectedExtra = [NSMutableArray array];
    for (NSString *line in last20) {
        NSString *lower = line.lowercaseString;
        if ([lower containsString:@"hs_err_pid"] || [lower containsString:@"replay_pid"]) {
            // Already captured by hsErrPath, but note
            if (analysis.hsErrPath) [detectedExtra addObject:analysis.hsErrPath];
        }
        if ([lower containsString:@"crash-"] && [lower containsString:@".txt"]) {
            // Extract path-like substring
            // naive: search for "/" then ".txt"
            NSRange r = [line rangeOfString:@"/"];
            if (r.location != NSNotFound) {
                // keep whole line as hint
                [detectedExtra addObject:line];
            }
            if (analysis.crashReportPath) [detectedExtra addObject:analysis.crashReportPath];
        }
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    if (excerpt.length > 0) payload[@"excerpt"] = [excerpt substringToIndex:MIN(excerpt.length, 20000)];
    if (fullLog.length > 0) payload[@"fullLog"] = [fullLog substringToIndex:MIN(fullLog.length, 50000)];
    // Read crash report content if exists and not already in payload
    if (analysis.crashReportPath) {
        NSString *crash = [NSString stringWithContentsOfFile:analysis.crashReportPath encoding:NSUTF8StringEncoding error:nil];
        if (crash.length > 0) payload[@"crashReport"] = [crash substringToIndex:MIN(crash.length, 100000)];
        payload[@"crashReportPath"] = analysis.crashReportPath;
    }
    if (analysis.hsErrPath) {
        NSString *hs = [NSString stringWithContentsOfFile:analysis.hsErrPath encoding:NSUTF8StringEncoding error:nil];
        if (hs.length > 0) payload[@"hsErr"] = [hs substringToIndex:MIN(hs.length, 100000)];
        payload[@"hsErrPath"] = analysis.hsErrPath;
    }
    if (detectedExtra.count > 0) payload[@"detectedExtra"] = [detectedExtra copy];
    payload[@"category"] = @(analysis.category).stringValue ?: @"0";
    // Map category enum to string
    NSString *catStr = @"raw";
    if (analysis.category == CrashLogCategoryModConflict) catStr = @"mod_conflict";
    else if (analysis.category == CrashLogCategoryError) catStr = @"error";
    payload[@"category"] = catStr;
    payload[@"deviceId"] = WitchDeviceId2();
    payload[@"appVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    // mcVersion and exitCode will be added by caller
    return [payload copy];
}

+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis exitCode:(int)code completion:(void(^)(BOOL, NSString*, NSError*))completion {
    [self sendReportWithAnalysis:analysis exitCode:code note:nil completion:completion];
}

+ (void)sendReportWithAnalysis:(CrashLogAnalyzerResult*)analysis exitCode:(int)code note:(NSString*)note completion:(void(^)(BOOL, NSString*, NSError*))completion {
    NSDictionary *payloadBase = [self collectLogPayloadWithAnalysis:analysis];
    NSMutableDictionary *payload = [payloadBase mutableCopy];
    payload[@"exitCode"] = @(code);
    if (note.length > 0) payload[@"note"] = [note substringToIndex:MIN(note.length, 2000)];
    // Add mcVersion
    NSString *mcVer = getPrefObject(@"internal.mc_version") ?: getPrefObject(@"general.game_directory") ?: @"unknown";
    // Try VersionDirectoryManager if available
    @try {
        Class mgrClass = NSClassFromString(@"VersionDirectoryManager");
        if (mgrClass) {
            id mgr = [mgrClass performSelector:@selector(shared)];
            NSString *curVer = [mgr performSelector:@selector(currentVersion)];
            if ([curVer isKindOfClass:[NSString class]] && curVer.length > 0) mcVer = curVer;
        }
    } @catch(...) {}
    payload[@"mcVersion"] = mcVer;

    // Thu thập file để gửi kèm (latestlog, crash-report, hs_err, .ips) dạng multipart nếu có
    NSMutableArray *filesToSend = [NSMutableArray array];
    // latestlog file
    if (analysis.latestLogPath) {
        NSData *data = [NSData dataWithContentsOfFile:analysis.latestLogPath];
        if (data.length > 0) [filesToSend addObject:@{@"name": @"latestlog.txt", @"data": data, @"path": analysis.latestLogPath}];
    }
    if (analysis.crashReportPath) {
        NSData *data = [NSData dataWithContentsOfFile:analysis.crashReportPath];
        if (data.length > 0) [filesToSend addObject:@{@"name": [analysis.crashReportPath lastPathComponent] ?: @"crash-report.txt", @"data": data, @"path": analysis.crashReportPath}];
    }
    if (analysis.hsErrPath) {
        NSData *data = [NSData dataWithContentsOfFile:analysis.hsErrPath];
        if (data.length > 0) [filesToSend addObject:@{@"name": [analysis.hsErrPath lastPathComponent] ?: @"hs_err.log", @"data": data, @"path": analysis.hsErrPath}];
    }
    // Tìm .ips mới nhất trong 24h (khi launcher crash ra home)
    {
        NSArray *searchDirs = @[
            [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter"],
            @(getenv("POJAV_HOME") ?: "")
        ];
        for (NSString *dir in searchDirs) {
            if (dir.length==0) continue;
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
            for (NSString *f in files) {
                if ([f.pathExtension isEqualToString:@"ips"] && [f containsString:@"Witch"]) {
                    NSString *full = [dir stringByAppendingPathComponent:f];
                    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
                    NSDate *mod = attr[NSFileModificationDate];
                    if (mod && [[NSDate date] timeIntervalSinceDate:mod] < 86400) {
                        NSData *data = [NSData dataWithContentsOfFile:full];
                        if (data.length>0 && data.length < 5*1024*1024) [filesToSend addObject:@{@"name": f, @"data": data, @"path": full}];
                        break;
                    }
                }
            }
        }
    }
    // Thêm các file được nhắc trong log (detectedExtra) nếu là đường dẫn file thật
    for (NSString *extra in payload[@"detectedExtra"] ?: @[]) {
        if ([extra hasPrefix:@"/"] && [[NSFileManager defaultManager] fileExistsAtPath:extra]) {
            NSData *data = [NSData dataWithContentsOfFile:extra];
            if (data.length>0 && data.length < 5*1024*1024) [filesToSend addObject:@{@"name": [extra lastPathComponent], @"data": data, @"path": extra}];
        }
    }

    NSString *base = WitchProxyBaseURL2();
    if (!base.length) {
        if (completion) completion(NO, nil, [NSError errorWithDomain:@"WitchLog" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Witch server not configured"}]);
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/logs/report", base]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    // Nếu có file >20k hoặc có .ips/crash thì dùng multipart để Discord nhận file đính kèm, ngược lại vẫn JSON cho nhẹ
    BOOL useMultipart = filesToSend.count > 0;
    NSData *bodyData = nil;
    NSString *bodyStr = nil;
    if (useMultipart) {
        NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
        [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
        NSMutableData *body = [NSMutableData data];
        // payload_json
        NSData *jsonDataTmp = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
        if (!jsonDataTmp) {
            if (completion) completion(NO, nil, [NSError errorWithDomain:@"WitchLog" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload"}]);
            return;
        }
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:jsonDataTmp];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        // files
        for (int i=0;i<filesToSend.count;i++) {
            NSDictionary *f = filesToSend[i];
            NSString *name = f[@"name"] ?: [NSString stringWithFormat:@"file%d.txt", i];
            NSData *data = f[@"data"];
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"files[%d]\"; filename=\"%@\"\r\nContent-Type: text/plain\r\n\r\n", i, name] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:data];
            [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        bodyData = body;
        bodyStr = [[NSString alloc] initWithData:jsonDataTmp encoding:NSUTF8StringEncoding]; // dùng json để ký HMAC
    } else {
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
        if (!jsonData) {
            if (completion) completion(NO, nil, [NSError errorWithDomain:@"WitchLog" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload"}]);
            return;
        }
        if (jsonData.length > 600 * 1024) {
            NSMutableDictionary *small = [payload mutableCopy];
            NSString *fl = small[@"fullLog"];
            if ([fl isKindOfClass:[NSString class]] && fl.length > 20000) small[@"fullLog"] = [fl substringToIndex:20000];
            jsonData = [NSJSONSerialization dataWithJSONObject:small options:0 error:nil];
            payload = small;
        }
        bodyData = jsonData;
        bodyStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    req.HTTPBody = bodyData;
    // Auth headers
    NSString *token = WitchProxyToken2();
    if (token.length > 0) [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    NSString *secret = WitchProxyHMACSecret2();
    if (secret.length > 0) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]*1000];
        NSString *bodyHash = SHA256Hex2(bodyStr);
        NSString *path = @"/v1/logs/report";
        NSString *message = [NSString stringWithFormat:@"%@.%@.%@.%@", timestamp, @"POST", path, bodyHash];
        NSString *sig = HMACSHA256Hex2(secret, message);
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

    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { if (completion) completion(NO, nil, error); return; }
            NSInteger status = [(NSHTTPURLResponse*)response statusCode];
            NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (status >= 200 && status < 300) {
                NSString *logId = [json[@"logId"] description] ?: nil;
                if (completion) completion(YES, logId, nil);
            } else {
                NSString *msg = json[@"error"] ?: [NSString stringWithFormat:@"Server %ld", (long)status];
                if (completion) completion(NO, nil, [NSError errorWithDomain:@"WitchLog" code:status userInfo:@{NSLocalizedDescriptionKey: msg}]);
            }
        });
    }] resume];
}

@end
