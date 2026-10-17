#import "ModIconReader.h"
#import "InstalledModsManager.h"
#import "UnzipKit.h"
#import <CommonCrypto/CommonDigest.h>

@interface ModIconReader ()
@property (nonatomic) NSCache *memCache;
@property (nonatomic) dispatch_queue_t ioQueue;
@end

@implementation ModIconReader

+ (ModIconReader *)shared {
    static ModIconReader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memCache = [[NSCache alloc] init];
        _memCache.countLimit = 120;
        _ioQueue = dispatch_queue_create("com.angelic.modiconreader", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

+ (NSString *)placeholderSystemImageForCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return @"paintpalette";
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return @"paintbrush.pointed";
    return @"puzzlepiece.extension";
}

#pragma mark - Disk cache

- (NSString *)diskCacheDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"ModIcons"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)cacheKeyForFilePath:(NSString *)path {
    // key = sha1(path + mtime + size) so edits invalidate
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSString *mtime = [NSString stringWithFormat:@"%@", attrs[NSFileModificationDate] ?: @""];
    NSString *size = [NSString stringWithFormat:@"%@", attrs[NSFileSize] ?: @""];
    NSString *raw = [NSString stringWithFormat:@"%@|%@|%@", path, mtime, size];
    const char *c = raw.UTF8String;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(c, (CC_LONG)strlen(c), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (NSString *)cacheKeyForURLString:(NSString *)url {
    const char *c = url.UTF8String ?: "";
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(c, (CC_LONG)strlen(c), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return [@"remote-" stringByAppendingString:hex];
}

#pragma mark - Metadata (sync, caller should be off-main)

+ (NSDictionary *)metadataForFileAtPath:(NSString *)filePath category:(NSString *)category {
    NSMutableDictionary *meta = [NSMutableDictionary dictionary];
    if (filePath.length == 0) return meta;
    NSError *uzError = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:filePath error:&uzError];
    if (uzError || !archive) return meta;

    if ([category isEqualToString:InstalledItemCategoryResourcePack] ||
        [category isEqualToString:InstalledItemCategoryShaderPack]) {
        NSData *mcmeta = [archive extractDataFromFile:@"pack.mcmeta" error:nil];
        if (mcmeta) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:mcmeta options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *pack = json[@"pack"];
                if ([pack isKindOfClass:[NSDictionary class]]) {
                    if ([pack[@"description"] isKindOfClass:[NSString class]]) meta[@"description"] = pack[@"description"];
                    else if ([pack[@"description"] isKindOfClass:[NSDictionary class]]) {
                        // newer pack format may nest text
                        id text = pack[@"description"][@"text"];
                        if ([text isKindOfClass:[NSString class]]) meta[@"description"] = text;
                    }
                    if (pack[@"pack_format"]) meta[@"pack_format"] = [NSString stringWithFormat:@"%@", pack[@"pack_format"]];
                }
            }
        }
        return meta;
    }

    // --- Mod jar ---
    NSData *fabricData = [archive extractDataFromFile:@"fabric.mod.json" error:nil];
    if (fabricData) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:fabricData options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]]) {
            if ([json[@"name"] isKindOfClass:[NSString class]]) meta[@"title"] = json[@"name"];
            if ([json[@"id"] isKindOfClass:[NSString class]]) meta[@"mod_id"] = json[@"id"];
            if ([json[@"version"] isKindOfClass:[NSString class]]) meta[@"version"] = json[@"version"];
            if ([json[@"description"] isKindOfClass:[NSString class]]) meta[@"description"] = json[@"description"];
            id authors = json[@"authors"];
            if ([authors isKindOfClass:[NSArray class]]) {
                NSMutableArray *names = [NSMutableArray array];
                for (id a in (NSArray *)authors) {
                    if ([a isKindOfClass:[NSString class]]) [names addObject:a];
                    else if ([a isKindOfClass:[NSDictionary class]] && [a[@"name"] isKindOfClass:[NSString class]]) [names addObject:a[@"name"]];
                }
                if (names.count) meta[@"authors"] = [names componentsJoinedByString:@", "];
            } else if ([authors isKindOfClass:[NSString class]]) {
                meta[@"authors"] = authors;
            }
            // icon can be string or { "": "...", "64x64": ... } — take first string
            id icon = json[@"icon"];
            if ([icon isKindOfClass:[NSString class]]) meta[@"icon_path"] = icon;
            else if ([icon isKindOfClass:[NSDictionary class]]) {
                for (id key in (NSDictionary *)icon) {
                    id v = ((NSDictionary *)icon)[key];
                    if ([v isKindOfClass:[NSString class]]) { meta[@"icon_path"] = v; break; }
                }
            }
        }
        // Return early-ish but still allow icon extraction below
        return meta;
    }

    // Forge mods.toml (TOML — best-effort regex for displayName/version)
    NSData *tomlData = [archive extractDataFromFile:@"META-INF/mods.toml" error:nil];
    if (!tomlData) tomlData = [archive extractDataFromFile:@"mods.toml" error:nil];
    if (tomlData) {
        NSString *text = [[NSString alloc] initWithData:tomlData encoding:NSUTF8StringEncoding];
        if (text) {
            NSRegularExpression *reName = [NSRegularExpression regularExpressionWithPattern:@"displayName\\s*=\\s*\"([^\"]+)\"" options:0 error:nil];
            NSTextCheckingResult *m1 = [reName firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
            if (m1 && m1.numberOfRanges > 1) meta[@"title"] = [text substringWithRange:[m1 rangeAtIndex:1]];
            NSRegularExpression *reVer = [NSRegularExpression regularExpressionWithPattern:@"\\nversion\\s*=\\s*\"([^\"]+)\"" options:0 error:nil];
            NSTextCheckingResult *m2 = [reVer firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
            if (m2 && m2.numberOfRanges > 1) meta[@"version"] = [text substringWithRange:[m2 rangeAtIndex:1]];
            NSRegularExpression *reDesc = [NSRegularExpression regularExpressionWithPattern:@"description\\s*=\\s*\"([^\"]+)\"" options:0 error:nil];
            NSTextCheckingResult *m3 = [reDesc firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
            if (m3 && m3.numberOfRanges > 1) meta[@"description"] = [text substringWithRange:[m3 rangeAtIndex:1]];
        }
        return meta;
    }

    NSData *mcmod = [archive extractDataFromFile:@"mcmod.info" error:nil];
    if (mcmod) {
        id json = [NSJSONSerialization JSONObjectWithData:mcmod options:0 error:nil];
        NSArray *arr = nil;
        if ([json isKindOfClass:[NSArray class]]) arr = json;
        else if ([json isKindOfClass:[NSDictionary class]] && [json[@"modList"] isKindOfClass:[NSArray class]]) arr = json[@"modList"];
        NSDictionary *first = [arr isKindOfClass:[NSArray class]] && arr.count > 0 && [arr[0] isKindOfClass:[NSDictionary class]] ? arr[0] : nil;
        if (first) {
            if ([first[@"name"] isKindOfClass:[NSString class]]) meta[@"title"] = first[@"name"];
            if ([first[@"version"] isKindOfClass:[NSString class]]) meta[@"version"] = first[@"version"];
            if ([first[@"description"] isKindOfClass:[NSString class]]) meta[@"description"] = first[@"description"];
            if ([first[@"authorList"] isKindOfClass:[NSArray class]]) meta[@"authors"] = [(NSArray *)first[@"authorList"] componentsJoinedByString:@", "];
            if ([first[@"logoFile"] isKindOfClass:[NSString class]]) meta[@"icon_path"] = first[@"logoFile"];
        }
    }
    return meta;
}

#pragma mark - Icon (async)

- (void)iconForFileAtPath:(NSString *)filePath
                 category:(NSString *)category
               completion:(void(^)(UIImage * _Nullable, NSDictionary *))completion {
    if (filePath.length == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, @{}); });
        return;
    }
    NSString *key = [self cacheKeyForFilePath:filePath];
    UIImage *mem = [self.memCache objectForKey:key];
    if (mem) {
        NSDictionary *meta = [ModIconReader metadataForFileAtPath:filePath category:category];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(mem, meta); });
        return;
    }
    NSString *diskPath = [[self diskCacheDir] stringByAppendingPathComponent:[key stringByAppendingPathExtension:@"png"]];
    NSData *diskData = [NSData dataWithContentsOfFile:diskPath];
    if (diskData) {
        UIImage *img = [UIImage imageWithData:diskData];
        if (img) [self.memCache setObject:img forKey:key];
        NSDictionary *meta = [ModIconReader metadataForFileAtPath:filePath category:category];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(img, meta); });
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        NSDictionary *meta = [ModIconReader metadataForFileAtPath:filePath category:category];
        UIImage *icon = [weakSelf extractIconFromArchive:filePath meta:meta category:category];
        if (icon) {
            [weakSelf.memCache setObject:icon forKey:key];
            NSData *png = UIImagePNGRepresentation(icon);
            if (png) [png writeToFile:diskPath atomically:YES];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(icon, meta);
        });
    });
}

- (UIImage *)extractIconFromArchive:(NSString *)filePath meta:(NSDictionary *)meta category:(NSString *)category {
    NSError *uzError = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:filePath error:&uzError];
    if (uzError || !archive) return nil;

    if ([category isEqualToString:InstalledItemCategoryResourcePack] ||
        [category isEqualToString:InstalledItemCategoryShaderPack]) {
        NSData *packPng = [archive extractDataFromFile:@"pack.png" error:nil];
        if (packPng) {
            UIImage *img = [UIImage imageWithData:packPng];
            if (img) return img;
        }
        return nil;
    }

    // 1) explicit icon path from fabric.mod.json / mcmod.info
    NSString *iconPath = meta[@"icon_path"];
    if ([iconPath isKindOfClass:[NSString class]] && iconPath.length > 0) {
        // strip leading slash
        NSString *p = [iconPath hasPrefix:@"/"] ? [iconPath substringFromIndex:1] : iconPath;
        NSData *d = [archive extractDataFromFile:p error:nil];
        if (d) {
            UIImage *img = [UIImage imageWithData:d];
            if (img) return img;
        }
    }
    // 2) common candidates
    NSString *modId = meta[@"mod_id"];
    NSMutableArray *candidates = [NSMutableArray arrayWithObjects:
        @"icon.png", @"logo.png", @"pack.png",
        @"assets/icon.png", @"assets/logo.png", nil];
    if ([modId isKindOfClass:[NSString class]] && modId.length > 0) {
        [candidates insertObject:[NSString stringWithFormat:@"assets/%@/icon.png", modId] atIndex:0];
        [candidates insertObject:[NSString stringWithFormat:@"assets/%@/logo.png", modId] atIndex:1];
    }
    for (NSString *c in candidates) {
        NSData *d = [archive extractDataFromFile:c error:nil];
        if (d) {
            UIImage *img = [UIImage imageWithData:d];
            if (img) return img;
        }
    }
    return nil;
}

#pragma mark - Remote icon with cache

- (void)remoteIconForURLString:(NSString *)urlString
                   completion:(void(^)(UIImage * _Nullable))completion {
    if (![urlString isKindOfClass:[NSString class]] || urlString.length == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSString *key = [self cacheKeyForURLString:urlString];
    UIImage *mem = [self.memCache objectForKey:key];
    if (mem) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(mem); });
        return;
    }
    NSString *diskPath = [[self diskCacheDir] stringByAppendingPathComponent:[key stringByAppendingPathExtension:@"png"]];
    NSData *diskData = [NSData dataWithContentsOfFile:diskPath];
    if (diskData) {
        UIImage *img = [UIImage imageWithData:diskData];
        if (img) [self.memCache setObject:img forKey:key];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(img); });
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        UIImage *img = nil;
        if ([data isKindOfClass:[NSData class]] && data.length > 0 && !err) {
            img = [UIImage imageWithData:data];
            if (img) {
                [weakSelf.memCache setObject:img forKey:key];
                [data writeToFile:diskPath atomically:YES];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(img);
        });
    }] resume];
}

@end
