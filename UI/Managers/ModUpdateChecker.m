#import "ModUpdateChecker.h"
#import "ModSourceService.h"

NSString * const ModUpdateStatusChecking = @"checking";
NSString * const ModUpdateStatusUpdate = @"update";
NSString * const ModUpdateStatusLatest = @"latest";
NSString * const ModUpdateStatusIncompatible = @"incompatible";
NSString * const ModUpdateStatusUnknown = @"unknown";
NSString * const ModUpdateStatusLocal = @"local";
NSString * const ModUpdateStatusNone = @"none";

static const NSTimeInterval kCheckCacheTTL = 24 * 60 * 60; // 1 day
static NSString * const kCachePrefix = @"witch.modcheck.v1.";

@implementation ModUpdateChecker

+ (ModUpdateChecker *)shared {
    static ModUpdateChecker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSString *)cacheKeyForItem:(NSDictionary *)item mcVersion:(NSString *)mc loader:(NSString *)loader {
    NSString *pid = item[@"project_id"] ?: @"";
    NSString *src = item[@"source"];
    if (![src isKindOfClass:[NSString class]] || src.length == 0) {
        src = [ModSourceService isCurseForgeMod:item] ? @"curseforge" : @"modrinth";
    }
    return [NSString stringWithFormat:@"%@%@.%@.%@.%@",
            kCachePrefix, src, pid, mc ?: @"any", loader ?: @"any"];
}

- (NSDictionary *)cachedResultForKey:(NSString *)key {
    NSDictionary *all = [[NSUserDefaults standardUserDefaults] dictionaryForKey:key];
    if (![all isKindOfClass:[NSDictionary class]]) return nil;
    NSNumber *at = all[@"checked_at"];
    if (![at isKindOfClass:[NSNumber class]]) return nil;
    NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - at.doubleValue;
    if (age < 0 || age > kCheckCacheTTL) return nil;
    return all[@"result"];
}

- (void)storeResult:(NSDictionary *)result forKey:(NSString *)key {
    NSDictionary *payload = @{
        @"checked_at": @([[NSDate date] timeIntervalSince1970]),
        @"result": result ?: @{}
    };
    [[NSUserDefaults standardUserDefaults] setObject:payload forKey:key];
}

- (void)invalidateAllCaches {
    // Best-effort: clear only our prefix keys
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    for (NSString *key in defs.dictionaryRepresentation.allKeys) {
        if ([key hasPrefix:kCachePrefix]) [defs removeObjectForKey:key];
    }
}

- (void)checkItems:(NSArray<NSDictionary *> *)items
         mcVersion:(NSString *)mcVersion
            loader:(NSString *)loader
      forceRefresh:(BOOL)force
        completion:(void(^)(NSArray<NSDictionary *> *))completion {
    if (!items) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });
        return;
    }
    NSString *mc = (mcVersion != nil) ? mcVersion : @"";
    NSString *rawLoader = (loader != nil) ? loader : @"";
    NSString *ld = [rawLoader lowercaseString];
    if ([ld isEqualToString:@"vanilla"]) ld = @"";

    NSMutableArray *results = [NSMutableArray arrayWithCapacity:items.count];
    for (NSUInteger i = 0; i < items.count; i++) {
        [results addObject:@{@"status": ModUpdateStatusChecking}];
    }
    NSMutableArray *toFetch = [NSMutableArray array];
    NSMutableArray *toFetchIdx = [NSMutableArray array];

    for (NSUInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        NSString *pid = item[@"project_id"];
        if (![pid isKindOfClass:[NSString class]] || pid.length == 0) {
            results[i] = @{@"status": ModUpdateStatusLocal};
            continue;
        }
        NSString *key = [self cacheKeyForItem:item mcVersion:mc loader:ld];
        if (!force) {
            NSDictionary *cached = [self cachedResultForKey:key];
            if (cached) {
                // Re-validate staleness of "update" vs current installed version:
                // if user updated since cache, recompute below instead of trusting.
                NSString *cachedLatest = cached[@"latest_version"];
                NSString *current = item[@"version_number"];
                if ([cachedLatest isKindOfClass:[NSString class]] && [current isKindOfClass:[NSString class]] &&
                    cachedLatest.length > 0 && current.length > 0 &&
                    [cached[@"status"] isEqualToString:ModUpdateStatusUpdate] &&
                    [cachedLatest isEqualToString:current]) {
                    // already updated since cache -> treat as latest
                    NSDictionary *fixed = @{@"status": ModUpdateStatusLatest, @"latest_version": cachedLatest};
                    results[i] = fixed;
                    [self storeResult:fixed forKey:key];
                } else {
                    results[i] = cached;
                }
                continue;
            }
        }
        [toFetch addObject:item];
        [toFetchIdx addObject:@(i)];
    }

    if (toFetch.count == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([results copy]); });
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger j = 0; j < toFetch.count; j++) {
        NSDictionary *item = toFetch[j];
        NSUInteger idx = [toFetchIdx[j] unsignedIntegerValue];
        NSString *key = [self cacheKeyForItem:item mcVersion:mc loader:ld];
        dispatch_group_enter(group);
        [ModSourceService loadVersionsForMod:item completion:^(NSArray *versions, NSError *error) {
            NSDictionary *res = nil;
            if (error || ![versions isKindOfClass:[NSArray class]] || versions.count == 0) {
                res = @{@"status": ModUpdateStatusUnknown};
            } else {
                res = [self resultForItem:item versions:versions mcVersion:mc loader:ld];
            }
            results[idx] = res;
            if (![res[@"status"] isEqualToString:ModUpdateStatusUnknown]) {
                [self storeResult:res forKey:key];
            }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion([results copy]);
    });
}

- (NSDictionary *)resultForItem:(NSDictionary *)item versions:(NSArray *)versions mcVersion:(NSString *)mc loader:(NSString *)ld {
    NSString *current = item[@"version_number"];
    if (![current isKindOfClass:[NSString class]]) current = @"";

    // versions are newest-first from both backends; find first compatible
    NSDictionary *best = nil;
    for (NSDictionary *v in versions) {
        if (![v isKindOfClass:[NSDictionary class]]) continue;
        NSArray *gvs = v[@"game_versions"];
        NSArray *lds = v[@"loaders"];
        BOOL mcOK = mc.length == 0 || ![gvs isKindOfClass:[NSArray class]] || gvs.count == 0 || [gvs containsObject:mc];
        // Some backends omit loaders for packs; treat missing as compatible
        BOOL ldOK = ld.length == 0 || ![lds isKindOfClass:[NSArray class]] || lds.count == 0 || [lds containsObject:ld];
        if (mcOK && ldOK) { best = v; break; }
    }
    if (!best) {
        // Report what the newest wants so UI can show "needs MC x"
        NSDictionary *newest = [versions.firstObject isKindOfClass:[NSDictionary class]] ? versions.firstObject : nil;
        NSArray *gvs = newest[@"game_versions"];
        NSArray *lds = newest[@"loaders"];
        NSString *reason = @"";
        if ([gvs isKindOfClass:[NSArray class]] && gvs.count > 0) {
            reason = [NSString stringWithFormat:@"Needs %@%@%@",
                      [gvs componentsJoinedByString:@", "],
                      ([lds isKindOfClass:[NSArray class]] && lds.count > 0) ? @" / " : @"",
                      ([lds isKindOfClass:[NSArray class]] ? [lds componentsJoinedByString:@", "] : @"")];
        }
        return @{
            @"status": ModUpdateStatusIncompatible,
            @"latest_version": newest[@"version_number"] ?: @"",
            @"reason": reason
        };
    }
    NSString *latest = [best[@"version_number"] isKindOfClass:[NSString class]] ? best[@"version_number"] : @"";
    if (current.length > 0 && latest.length > 0 && ![latest isEqualToString:current]) {
        return @{
            @"status": ModUpdateStatusUpdate,
            @"latest_version": latest,
            @"latest_url": ([best[@"url"] isKindOfClass:[NSString class]] ? best[@"url"] : @""),
            @"latest_filename": ([best[@"filename"] isKindOfClass:[NSString class]] ? best[@"filename"] : @""),
            @"latest_version_dict": best
        };
    }
    return @{@"status": ModUpdateStatusLatest, @"latest_version": latest};
}

@end
