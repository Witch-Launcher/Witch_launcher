#import "WitchAIService.h"
#import "LauncherPreferences.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import "WitchCrypto.h"
#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#else
#define WITCH_DEFAULT_BASE_URL @""
#define WITCH_DEFAULT_HMAC_SECRET @""
#define WITCH_DEFAULT_PROXY_TOKEN @""
#define WITCH_DEFAULT_CURSEFORGE_API_KEY @""
#endif

static NSString* WitchProxyBaseURL(void) {
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
static NSString* WitchProxyToken(void) {
    id v = getPrefObject(@"witch.proxy_token");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        if (dec.length > 0) return dec;
        return v;
    }
    NSString *bundled = WITCH_DEFAULT_PROXY_TOKEN;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
}
static NSString* WitchProxyHMACSecret(void) {
    id v = getPrefObject(@"witch.proxy_hmac");
    if (!v) v = getPrefObject(@"witch.proxy_hmac_secret");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        if (dec.length > 0) return dec;
        return v;
    }
    NSString *bundled = WITCH_DEFAULT_HMAC_SECRET;
    if ([bundled isKindOfClass:[NSString class]] && bundled.length > 0) {
        NSString *dec = [WitchCrypto decryptIfNeeded:bundled];
        return dec ?: bundled;
    }
    return nil;
}
static NSString* WitchDeviceId(void) {
    NSString *did = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.device_id"];
    if (did.length > 0) return did;
    did = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:did forKey:@"witch.device_id"];
    return did;
}
static NSString* SHA256Hex(NSString *input) {
    if (!input) input = @"";
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}
static NSString* HMACSHA256Hex(NSString *secret, NSString *message) {
    const char *cKey = [secret cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x", cHMAC[i]];
    return hex;
}
static void AddWitchAuthHeaders(NSMutableURLRequest *req, NSString *pathWithQuery, NSString *bodyString) {
    NSString *token = WitchProxyToken();
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
    NSString *secret = WitchProxyHMACSecret();
    if (secret.length > 0) {
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]*1000];
        NSString *bodyHash = SHA256Hex(bodyString ?: @"");
        NSString *path = pathWithQuery ?: req.URL.path;
        NSString *message = [NSString stringWithFormat:@"%@.%@.%@.%@", timestamp, req.HTTPMethod ?: @"POST", path, bodyHash];
        NSString *sig = HMACSHA256Hex(secret, message);
        [req setValue:timestamp forHTTPHeaderField:@"X-Witch-Timestamp"];
        [req setValue:sig forHTTPHeaderField:@"X-Witch-Signature"];
        [req setValue:WitchDeviceId() forHTTPHeaderField:@"X-Witch-DeviceId"];
    } else if (token.length > 0) {
        [req setValue:WitchDeviceId() forHTTPHeaderField:@"X-Witch-DeviceId"];
    }
    // AppAttest (BuildKeys) — nếu có thì gửi kèm để Worker ưu tiên
    NSString *attest = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.assertion"];
    if (attest.length > 20) {
        [req setValue:attest forHTTPHeaderField:@"X-Witch-AppAttest"];
        NSString *keyId = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.keyId"];
        if (keyId.length > 0) [req setValue:keyId forHTTPHeaderField:@"X-Witch-AppAttest-KeyId"];
    }
}

@implementation WitchAIService

+ (BOOL)isEnabled {
    id v = getPrefObject(@"witch.ai_enabled");
    if (!v) return YES;
    return [v boolValue];
}

+ (BOOL)shouldUseOwnKey {
    NSString *source = getPrefObject(@"witch.ai_source");
    if ([source isEqualToString:@"own"]) return YES;
    return NO;
}
+ (NSString*)ownKey {
    id v = getPrefObject(@"witch.ai_own_key");
    if ([v isKindOfClass:[NSString class]] && [(NSString*)v length]>0) {
        NSString *dec = [WitchCrypto decryptPrefValue:v];
        return dec ?: v;
    }
    return nil;
}
+ (NSString*)ownBaseURL { id v = getPrefObject(@"witch.ai_own_base"); return [v isKindOfClass:[NSString class]] && [(NSString*)v length]>0 ? v : @"https://api.openai.com/v1"; }
+ (NSString*)ownModel { id v = getPrefObject(@"witch.ai_own_model"); return [v isKindOfClass:[NSString class]] && [(NSString*)v length]>0 ? v : @"gpt-4o-mini"; }

+ (NSString*)effectiveLang {
    NSString *pref = getPrefObject(@"witch.ai_language");
    if ([pref isEqualToString:@"vi"] || [pref isEqualToString:@"en"]) return pref;
    if ([pref isEqualToString:@"auto"] || !pref) {
        NSString *launcherLang = getPrefObject(@"launcher.language");
        if ([launcherLang isEqualToString:@"vi"] || [launcherLang isEqualToString:@"en"]) return launcherLang;
        return @"auto";
    }
    return @"auto";
}

+ (void)askWithPrompt:(NSString*)prompt lang:(NSString*)lang completion:(void(^)(NSString *, NSError*))completion {
    if (![self isEnabled]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:403 userInfo:@{NSLocalizedDescriptionKey: @"AI is disabled in Settings"}]);
        return;
    }
    NSString *effectiveLang = lang ?: [self effectiveLang];
    if ([effectiveLang isEqualToString:@"auto"]) effectiveLang = nil;

    if ([self shouldUseOwnKey] && [self ownKey].length > 0) {
        [self askViaOwnKey:prompt lang:effectiveLang completion:completion];
    } else {
        [self askViaServer:prompt lang:effectiveLang completion:completion];
    }
}

+ (void)askViaOwnKey:(NSString*)prompt lang:(NSString*)lang completion:(void(^)(NSString*, NSError*))completion {
    NSString *base = [self ownBaseURL];
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length-1];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/chat/completions", base]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [self ownKey]] forHTTPHeaderField:@"Authorization"];

    NSString *system = lang && [lang isEqualToString:@"vi"] ? @"Bạn là trợ lý Witch Launcher. Trả lời bằng tiếng Việt." : @"You are Witch Launcher assistant. Respond in English.";
    NSArray *messages = @[@{@"role":@"system", @"content": system}, @{@"role":@"user", @"content": prompt}];
    NSDictionary *body = @{@"model": [self ownModel], @"messages": messages, @"temperature": @0.3};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    req.HTTPBody = jsonData;

    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) { if (completion) completion(nil, error); return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *content = json[@"choices"][0][@"message"][@"content"];
            if (content.length > 0) { if (completion) completion(content, nil); }
            else { if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:500 userInfo:@{NSLocalizedDescriptionKey: @"No response"}]); }
        });
    }] resume];
}

+ (void)askViaServer:(NSString*)prompt lang:(NSString*)lang completion:(void(^)(NSString*, NSError*))completion {
    NSString *base = WitchProxyBaseURL();
    if (!base.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Witch server not configured. Go to Settings > Witch Server"}]);
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/ai/ask", base]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSMutableDictionary *body = [@{@"prompt": prompt, @"source": @"launcher"} mutableCopy];
    if (lang) body[@"lang"] = lang;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *bodyStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    req.HTTPBody = jsonData;
    AddWitchAuthHeaders(req, @"/v1/ai/ask", bodyStr);

    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) { if (completion) completion(nil, error); return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *ans = json[@"answer"];
            if (ans.length > 0) { if (completion) completion(ans, nil); }
            else {
                NSString *err = json[@"error"] ?: @"Unknown error";
                if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:500 userInfo:@{NSLocalizedDescriptionKey: err}]);
            }
        });
    }] resume];
}

+ (void)analyzeLogWithExcerpt:(NSString*)excerpt fullLog:(NSString*)fullLog meta:(NSDictionary*)meta completion:(void(^)(NSString*, NSError*))completion {
    if (![self isEnabled]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:403 userInfo:@{NSLocalizedDescriptionKey: @"AI is disabled"}]);
        return;
    }
    NSString *lang = [self effectiveLang];
    if ([lang isEqualToString:@"auto"]) lang = nil;

    if ([self shouldUseOwnKey] && [self ownKey].length > 0) {
        // For own key, we directly analyze with truncated log (no server tool)
        NSString *base = [self ownBaseURL];
        if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length-1];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/chat/completions", base]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", [self ownKey]] forHTTPHeaderField:@"Authorization"];
        NSString *system = lang && [lang isEqualToString:@"vi"] ? @"Bạn là chuyên gia phân tích log Minecraft. Phân tích và đưa ra gợi ý ngắn gọn bằng tiếng Việt." : @"You are a Minecraft log analyzer. Analyze and suggest fixes in English.";
        NSString *logContent = excerpt ?: fullLog ?: @"";
        if (logContent.length > 15000) logContent = [logContent substringToIndex:15000];
        NSString *userMsg = [NSString stringWithFormat:@"Meta: %@\nLog:\n%@", meta ?: @{}, logContent];
        NSArray *messages = @[@{@"role":@"system", @"content": system}, @{@"role":@"user", @"content": userMsg}];
        NSDictionary *body = @{@"model": [self ownModel], @"messages": messages, @"temperature": @0.3};
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        req.HTTPBody = jsonData;
        [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !data) { if (completion) completion(nil, error); return; }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *content = json[@"choices"][0][@"message"][@"content"];
                if (content.length > 0) { if (completion) completion(content, nil); }
                else { if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:500 userInfo:@{NSLocalizedDescriptionKey: @"No response"}]); }
            });
        }] resume];
    } else {
        NSString *base = WitchProxyBaseURL();
        if (!base.length) {
            if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Witch server not configured"}]);
            return;
        }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/v1/ai/analyze-log", base]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSMutableDictionary *body = [NSMutableDictionary dictionary];
        if (excerpt) body[@"excerpt"] = [excerpt substringToIndex:MIN(excerpt.length, 20000)];
        if (fullLog) body[@"fullLog"] = [fullLog substringToIndex:MIN(fullLog.length, 50000)];
        if (meta) body[@"meta"] = meta;
        body[@"source"] = @"launcher";
        if (lang) body[@"lang"] = lang;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        NSString *bodyStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        req.HTTPBody = jsonData;
        AddWitchAuthHeaders(req, @"/v1/ai/analyze-log", bodyStr);
        [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !data) { if (completion) completion(nil, error); return; }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *ans = json[@"answer"];
                if (ans.length > 0) { if (completion) completion(ans, nil); }
                else {
                    NSString *err = json[@"error"] ?: @"Unknown error";
                    if (completion) completion(nil, [NSError errorWithDomain:@"WitchAI" code:500 userInfo:@{NSLocalizedDescriptionKey: err}]);
                }
            });
        }] resume];
    }
}

@end
