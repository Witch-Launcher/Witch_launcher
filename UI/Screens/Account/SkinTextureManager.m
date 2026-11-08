#import "SkinTextureManager.h"
#import "utils.h"

static NSString *const kLocalModelKeyPrefix = @"account.local_skin_model.";
static NSString *const kLocalProfileId = @"00000000-0000-0000-0000-000000000000";

// Older Microsoft accounts may not have xboxGamertag stored (it was added in a
// later login flow). A real, non-zero profile UUID is enough to identify a
// Microsoft account; local accounts always use the zero UUID. Demo accounts
// have the zero UUID plus an Xbox gamertag.
static BOOL SkinAccountIsMicrosoft(NSDictionary *account) {
    if ([account[@"accountType"] isEqualToString:@"elyby"]) return NO;
    // Local accounts always store the zero UUID, so a real profile UUID is the
    // most reliable premium marker — xboxGamertag is missing on accounts saved
    // by older login flows. Demo accounts have the zero UUID plus a gamertag.
    NSString *profileId = account[@"profileId"];
    if (![profileId isKindOfClass:NSString.class] || profileId.length == 0) return NO;
    if ([profileId isEqualToString:kLocalProfileId]) {
        return [account[@"xboxGamertag"] length] > 0;
    }
    return YES;
}

@implementation SkinTextureManager

+ (instancetype)shared {
    static SkinTextureManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SkinTextureManager alloc] init];
    });
    return instance;
}

#pragma mark - Local account default skin preference

+ (NSString *)localModelPrefKeyForUsername:(NSString *)username {
    return [kLocalModelKeyPrefix stringByAppendingString:username.lowercaseString ?: @""];
}

+ (BOOL)localPrefersSlimForUsername:(NSString *)username {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:[self localModelPrefKeyForUsername:username]];
    return [v isEqualToString:@"alex"];
}

+ (UIImage *)bundledDefaultSkinSlim:(BOOL)slim {
    NSString *name = slim ? @"alex" : @"steve";
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png" inDirectory:@"Skins"];
    if (path.length == 0) {
        path = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
    }
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

+ (UIImage *)bundledDefaultHeadSlim:(BOOL)slim size:(CGFloat)size {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 16; });
    NSString *key = [NSString stringWithFormat:@"%@-%.0f", slim ? @"alex" : @"steve", size];
    UIImage *cached = [cache objectForKey:key];
    if (cached) return cached;

    UIImage *skin = [self bundledDefaultSkinSlim:slim];
    if (!skin) return nil;
    CGImageRef face = CGImageCreateWithImageInRect(skin.CGImage, CGRectMake(8, 8, 8, 8));
    if (!face) return nil;
    CGFloat scale = MAX(1.0, size / 8.0);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    // UIKit contexts are top-left based while CGImage drawing is bottom-left
    // based; without this flip the face would render upside down.
    CGContextTranslateCTM(ctx, 0, size);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextDrawImage(ctx, CGRectMake(0, 0, size, size), face);
    UIImage *head = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(face);
    if (head) [cache setObject:head forKey:key];
    return head;
}

+ (UIImage *)localHeadForUsername:(NSString *)username size:(CGFloat)size {
    return [self bundledDefaultHeadSlim:[self localPrefersSlimForUsername:username] size:size];
}

+ (UIImage *)headImageFromSkinImage:(UIImage *)skin size:(CGFloat)size {
    CGImageRef skinCG = skin.CGImage;
    if (!skinCG) return nil;
    CGFloat scale = CGImageGetWidth(skinCG) / 64.0;
    if (scale <= 0) return nil;
    // Legacy 64x32 skins have no hat layer; their lower half is not a texture
    // atlas entry for the head, so only crop the base face.
    BOOL hasOverlay = CGImageGetHeight(skinCG) >= 64 * scale;
    size = MAX(1.0, size);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetInterpolationQuality(c, kCGInterpolationNone);
        // Base face (8,8) then the hat/overlay layer (40,8), matching the
        // vanilla skin layout. Transparent overlays leave the base visible.
        CGRect regions[2] = {
            CGRectMake(8 * scale, 8 * scale, 8 * scale, 8 * scale),
            CGRectMake(40 * scale, 8 * scale, 8 * scale, 8 * scale),
        };
        int regionCount = hasOverlay ? 2 : 1;
        for (int i = 0; i < regionCount; i++) {
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

#pragma mark - Cache

- (NSString *)cacheDirectory {
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]
        stringByAppendingPathComponent:@"SkinTextures"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)cachePathForAccount:(NSDictionary *)account {
    NSString *key = account[@"profileId"];
    if (![key isKindOfClass:[NSString class]] || key.length == 0) key = account[@"username"];
    if (![key isKindOfClass:[NSString class]] || key.length == 0) key = @"unknown";
    NSString *safe = [[key componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet] componentsJoinedByString:@"-"];
    return [[self cacheDirectory] stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"png"]];
}

- (UIImage *)cachedSkinForAccount:(NSDictionary *)account {
    NSString *path = [self cachePathForAccount:account];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

- (void)storeCachedSkin:(NSData *)data forAccount:(NSDictionary *)account {
    NSString *path = [self cachePathForAccount:account];
    [data writeToFile:path atomically:YES];
}

- (void)evictCachedSkinForAccount:(NSDictionary *)account {
    [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForAccount:account] error:nil];
}

#pragma mark - Resolution

- (void)skinImageForAccount:(NSDictionary *)account completion:(void (^)(UIImage *))completion {
    if (!completion) return;
    BOOL isEly = [account[@"accountType"] isEqualToString:@"elyby"];
    BOOL isPremium = SkinAccountIsMicrosoft(account);
    BOOL isDemo = isPremium && [account[@"profileId"] isEqualToString:kLocalProfileId];

    if (isDemo) {
        NSString *username = account[@"username"] ?: @"";
        BOOL slim = [SkinTextureManager localPrefersSlimForUsername:username];
        dispatch_async(dispatch_get_main_queue(), ^{ completion([SkinTextureManager bundledDefaultSkinSlim:slim]); });
        return;
    }
    if (!isEly && !isPremium) {
        NSString *username = account[@"username"] ?: @"";
        BOOL slim = [SkinTextureManager localPrefersSlimForUsername:username];
        dispatch_async(dispatch_get_main_queue(), ^{ completion([SkinTextureManager bundledDefaultSkinSlim:slim]); });
        return;
    }

    NSString *cachePath = [self cachePathForAccount:account];
    UIImage *cached = [self cachedSkinForAccount:account];
    if (cached) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(cached); });
        // Refresh in the background for next time.
        [self downloadSkinForAccount:account completion:^(UIImage *image) {}];
        return;
    }

    [self downloadSkinForAccount:account completion:^(UIImage *image) {
        if (image) {
            completion(image);
            return;
        }
        // Last resort: Steve (better than a broken/blank preview).
        completion([SkinTextureManager bundledDefaultSkinSlim:NO]);
    }];
}

- (void)headImageForAccount:(NSDictionary *)account
                       size:(CGFloat)size
                 completion:(void (^)(UIImage * _Nullable))completion {
    if (!completion) return;
    [self skinImageForAccount:account completion:^(UIImage *skin) {
        UIImage *head = skin ? [SkinTextureManager headImageFromSkinImage:skin size:size] : nil;
        completion(head);
    }];
}

- (void)downloadSkinForAccount:(NSDictionary *)account completion:(void (^)(UIImage *))completion {
    BOOL isEly = [account[@"accountType"] isEqualToString:@"elyby"];
    if (isEly) {
        NSString *username = account[@"username"];
        if (username.length == 0) { completion(nil); return; }
        NSString *escaped = [username stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
        [self fetchTextureURL:[NSString stringWithFormat:@"https://skinsystem.ely.by/skins/%@.png", escaped] completion:^(UIImage *image) {
            if (image) {
                NSData *png = UIImagePNGRepresentation(image);
                if (png) [self storeCachedSkin:png forAccount:account];
            }
            completion(image);
        }];
        return;
    }

    // Microsoft: sessionserver profile lookup -> base64 textures payload.
    NSString *profileId = account[@"profileId"] ?: @"";
    NSString *clean = [[profileId stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    if (clean.length == 0) { completion(nil); return; }
    NSString *lookup = [NSString stringWithFormat:@"https://sessionserver.mojang.com/session/minecraft/profile/%@", clean];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:lookup]
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSString *textureURL = nil;
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                for (NSDictionary *prop in json[@"properties"] ?: @[]) {
                    if (![prop[@"name"] isEqualToString:@"textures"]) continue;
                    NSString *value = prop[@"value"];
                    if (![value isKindOfClass:[NSString class]]) continue;
                    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:value options:0];
                    NSDictionary *textures = decoded ? [NSJSONSerialization JSONObjectWithData:decoded options:0 error:nil] : nil;
                    NSDictionary *skin = textures[@"textures"][@"SKIN"];
                    id url = skin[@"url"];
                    if ([url isKindOfClass:[NSString class]]) textureURL = url;
                }
            }
            if (!textureURL) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }
            [self fetchTextureURL:textureURL completion:^(UIImage *image) {
                if (image) {
                    NSData *png = UIImagePNGRepresentation(image);
                    if (png) [self storeCachedSkin:png forAccount:account];
                }
                completion(image);
            }];
        }];
    [task resume];
}

- (void)fetchTextureURL:(NSString *)urlString completion:(void (^)(UIImage *))completion {
    // Mojang returns http:// texture URLs; ATS blocks cleartext, so upgrade.
    if ([urlString hasPrefix:@"http://"]) {
        urlString = [@"https://" stringByAppendingString:[urlString substringFromIndex:7]];
    }
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:urlString]
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            UIImage *image = (!error && data) ? [UIImage imageWithData:data] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
        }];
    [task resume];
}

@end
