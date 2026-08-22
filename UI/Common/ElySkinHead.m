#import "ElySkinHead.h"

static NSString *ElySkinCacheDirectory(void) {
    NSString *home = [NSString stringWithUTF8String:getenv("POJAV_HOME")];
    if (home.length == 0) home = NSTemporaryDirectory();
    NSString *dir = [home stringByAppendingPathComponent:@"cache/ely_heads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *ElySkinCachedPath(NSString *username) {
    NSString *safeName = [[username lowercaseString] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [[ElySkinCacheDirectory() stringByAppendingPathComponent:safeName] stringByAppendingPathExtension:@"png"];
}

static UIImage *ElyRenderHeadFromSkinData(NSData *skinData, CGFloat size);

@interface ElySkinRedirectDelegate : NSObject <NSURLSessionDataDelegate>
@end

@implementation ElySkinRedirectDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSMutableURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *))completionHandler {
    if (![request.URL.scheme.lowercaseString isEqualToString:@"http"]) {
        completionHandler(request);
        return;
    }
    NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
    components.scheme = @"https";
    NSMutableURLRequest *upgradedRequest = [[NSMutableURLRequest alloc] initWithURL:components.URL];
    upgradedRequest.HTTPMethod = request.HTTPMethod;
    upgradedRequest.allHTTPHeaderFields = request.allHTTPHeaderFields;
    upgradedRequest.HTTPBody = request.HTTPBody;
    upgradedRequest.timeoutInterval = request.timeoutInterval;
    completionHandler(upgradedRequest);
}

@end

static NSURLSession *ElySkinSession(void) {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                                delegate:[ElySkinRedirectDelegate new]
                                           delegateQueue:nil];
    });
    return session;
}

@implementation ElySkinHead

+ (void)headForUsername:(NSString *)username
                   size:(CGFloat)size
             completion:(void (^)(UIImage *head))completion {
    if (username.length == 0 || completion == nil) return;

    NSString *cachePath = ElySkinCachedPath(username);
    NSData *cachedData = [NSData dataWithContentsOfFile:cachePath];
    BOOL shouldRefresh = YES;

    if (cachedData.length > 0) {
        UIImage *head = ElyRenderHeadFromSkinData(cachedData, size);
        if (head) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(head); });
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:cachePath error:nil];
            NSDate *modified = attrs[NSFileModificationDate];
            NSTimeInterval age = modified ? -[modified timeIntervalSinceNow] : DBL_MAX;
            if (age < 300) shouldRefresh = NO;
        }
    }

    if (!shouldRefresh) return;

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://skinsystem.ely.by/skins/%@.png", username]];
    [[ElySkinSession() dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (!data || error || httpResp.statusCode != 200) return;
        if ([data isEqualToData:cachedData]) return;
        [data writeToFile:cachePath atomically:YES];
        UIImage *head = ElyRenderHeadFromSkinData(data, size);
        if (!head) return;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(head); });
    }] resume];
}

+ (UIImage *)cachedHeadForUsername:(NSString *)username size:(CGFloat)size {
    if (username.length == 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:ElySkinCachedPath(username)];
    if (!data) return nil;
    return ElyRenderHeadFromSkinData(data, size);
}

+ (void)clearCacheForUsername:(NSString *)username {
    if (username.length == 0) return;
    [[NSFileManager defaultManager] removeItemAtPath:ElySkinCachedPath(username) error:nil];
}

@end

static UIImage *ElyRenderHeadFromSkinData(NSData *skinData, CGFloat size) {
    UIImage *skin = [UIImage imageWithData:skinData];
    CGImageRef skinCG = skin.CGImage;
    if (!skinCG) return nil;

    CGFloat scale = CGImageGetWidth(skinCG) / 64.0;
    if (scale <= 0) return nil;

    UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
    format.scale = MAX(UIScreen.mainScreen.scale, 2.0);
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGRect regions[2] = {
            CGRectMake(8 * scale, 8 * scale, 8 * scale, 8 * scale),
            CGRectMake(40 * scale, 8 * scale, 8 * scale, 8 * scale),
        };
        for (int i = 0; i < 2; i++) {
            CGImageRef part = CGImageCreateWithImageInRect(skinCG, regions[i]);
            if (!part) continue;
            CGContextSaveGState(c);
            CGContextTranslateCTM(c, 0, size);
            CGContextScaleCTM(c, 1, -1);
            CGContextDrawImage(c, CGRectMake(0, 0, size, size), part);
            CGContextRestoreGState(c);
            CGImageRelease(part);
        }
    }];
}