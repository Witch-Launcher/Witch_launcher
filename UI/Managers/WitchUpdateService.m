#import "WitchUpdateService.h"
#import "LauncherPreferences.h"
#import "config.h"
#import <objc/runtime.h>

@implementation WitchReleaseAsset
@end

@implementation WitchReleaseInfo
- (WitchReleaseAsset *)assetForVariant:(WitchAppVariant)variant isTrollStore:(BOOL)isTrollStore {
    // Prefer exact match: slimmed vs full, tipa vs ipa.
    // Full: Witch-<ver>-ios.ipa / Witch-<ver>-ios-trollstore.tipa (see Makefile METHOD_PACKAGE)
    // Slimmed: Witch-slimmed-<ver>-ios.ipa / Witch-slimmed-...tipa
    NSString *wantExt = isTrollStore ? @"tipa" : @"ipa";
    BOOL wantSlimmed = (variant == WitchAppVariantSlimmed);
    WitchReleaseAsset *fallback = nil;
    for (WitchReleaseAsset *a in self.assets) {
        NSString *lower = a.name.lowercaseString;
        if (![lower hasSuffix:wantExt]) continue;
        BOOL isSlimmed = [lower containsString:@"slimmed"];
        if (isSlimmed == wantSlimmed) return a;
        if (!fallback) fallback = a;
    }
    return fallback;
}
@end

@interface WitchUpdateService ()
- (void)markSeen:(WitchReleaseInfo *)info;
- (void)presentShareSheet:(NSURL *)fileURL fromVC:(UIViewController *)vc;
@end

@implementation WitchUpdateService {
    NSURLSession *_session;
}

+ (WitchUpdateService *)shared {
    static WitchUpdateService *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *c = [NSURLSessionConfiguration defaultSessionConfiguration];
        c.timeoutIntervalForRequest = 20;
        c.timeoutIntervalForResource = 600;
        _session = [NSURLSession sessionWithConfiguration:c];
    }
    return self;
}

- (NSString *)githubRepo {
    NSString *override = getPrefObject(@"witch.update_repo");
    if ([override isKindOfClass:[NSString class]] && override.length > 3 && [override containsString:@"/"]) {
        return override;
    }
    return @"Witch-Launcher/Witch_launcher";
}

- (WitchUpdateChannel)selectedChannel {
    NSInteger v = getPrefInt(@"launcher.update_channel");
    // default 0 = Auto. getPrefInt returns 0 when unset -> Auto, good.
    if (v < 0 || v > 2) return WitchUpdateChannelAuto;
    return (WitchUpdateChannel)v;
}

- (void)setSelectedChannel:(WitchUpdateChannel)channel {
    setPrefInt(@"launcher.update_channel", (NSInteger)channel);
}

- (NSString *)channelDisplayName:(WitchUpdateChannel)channel {
    switch (channel) {
        case WitchUpdateChannelBeta: return @"Beta (pre-release)";
        case WitchUpdateChannelStable: return @"Ổn định (release)";
        default: {
            return [self isBetaBuild] ? @"Tự động (Beta)" : @"Tự động (Ổn định)";
        }
    }
}

- (BOOL)isBetaBuild {
#if CONFIG_RELEASE
    return NO;
#else
    return YES;
#endif
}

- (NSString *)effectiveTag {
    WitchUpdateChannel c = [self selectedChannel];
    if (c == WitchUpdateChannelBeta) return @"pre-release";
    if (c == WitchUpdateChannelStable) return @"release";
    return [self isBetaBuild] ? @"pre-release" : @"release";
}

- (BOOL)isTrollStoreInstall {
    NSString *tsPath = [NSString stringWithFormat:@"%@/../_TrollStore", NSBundle.mainBundle.bundlePath];
    return [[NSFileManager defaultManager] fileExistsAtPath:tsPath];
}

- (NSString *)currentVersion {
    return NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
}

- (void)checkForUpdateForce:(BOOL)force completion:(void(^)(WitchReleaseInfo *, BOOL, NSError *))completion {
    NSString *tag = [self effectiveTag];
    NSString *urlStr = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/tags/%@", [self githubRepo], tag];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Witch-Launcher-iOS" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, NO, error); });
            return;
        }
        NSError *je = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (je || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, NO, je ?: [NSError errorWithDomain:@"WitchUpdate" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid GitHub response"}]); });
            return;
        }
        if (json[@"message"] && !json[@"tag_name"]) {
            // e.g. {"message":"Not Found"} when tag doesn't exist yet
            NSError *e = [NSError errorWithDomain:@"WitchUpdate" code:404 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Release '%@' chưa có: %@", tag, json[@"message"]]}];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, NO, e); });
            return;
        }
        WitchReleaseInfo *info = [[WitchReleaseInfo alloc] init];
        info.tagName = json[@"tag_name"] ?: tag;
        info.htmlURL = json[@"html_url"] ?: @"";
        info.body = json[@"body"] ?: @"";
        NSMutableArray *assets = [NSMutableArray array];
        for (NSDictionary *a in (NSArray *)json[@"assets"]) {
            if (![a isKindOfClass:[NSDictionary class]]) continue;
            WitchReleaseAsset *asset = [[WitchReleaseAsset alloc] init];
            asset.name = a[@"name"] ?: @"";
            asset.downloadURL = a[@"browser_download_url"] ?: @"";
            asset.size = [a[@"size"] longLongValue];
            if (asset.name.length && asset.downloadURL.length) [assets addObject:asset];
        }
        info.assets = assets;
        // Heuristic hasUpdate: body contains newer version OR assets exist and tag differs from suppressed.
        // GitHub rolling tags (pre-release/release) keep same tag name, so compare published/updated_at
        // against last seen value. Store per-tag updated_at.
        NSString *updatedAt = json[@"updated_at"] ?: json[@"published_at"] ?: @"";
        NSString *key = [NSString stringWithFormat:@"witch.update_last_seen_%@", tag];
        NSString *lastSeen = getPrefObject(key);
        BOOL hasUpdate = YES;
        if ([lastSeen isKindOfClass:[NSString class]] && [lastSeen isEqualToString:updatedAt] && !force) {
            hasUpdate = NO;
        }
        if (updatedAt.length > 0 && force) {
            // force check still refreshes marker only after user acts (see markSeen below via caller)
        }
        // stash updatedAt for caller
        objc_setAssociatedObject(info, @selector(checkForUpdateForce:completion:), updatedAt, OBJC_ASSOCIATION_COPY_NONATOMIC);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(info, hasUpdate, nil); });
    }] resume];
}

+ (NSString *)seenMarkerForInfo:(WitchReleaseInfo *)info {
    return objc_getAssociatedObject(info, @selector(checkForUpdateForce:completion:));
}

- (void)markSeen:(WitchReleaseInfo *)info {
    NSString *marker = [[self class] seenMarkerForInfo:info];
    if (!marker) return;
    NSString *key = [NSString stringWithFormat:@"witch.update_last_seen_%@", info.tagName.length ? info.tagName : [self effectiveTag]];
    // tagName for rolling releases is literally "pre-release"/"release"
    NSString *eff = [self effectiveTag];
    setPrefObject([NSString stringWithFormat:@"witch.update_last_seen_%@", eff], marker);
}

- (void)downloadAsset:(WitchReleaseAsset *)asset progress:(void(^)(float))progress completion:(void(^)(NSURL *, NSError *))completion {
    NSURL *url = [NSURL URLWithString:asset.downloadURL];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"WitchUpdate" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL tải không hợp lệ"}]);
        return;
    }
    NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:url completionHandler:^(NSURL *tmp, NSURLResponse *resp, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSString *ext = asset.name.pathExtension.length ? asset.name.pathExtension : @"ipa";
        NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Witch-update-%@.%@", [[NSUUID UUID] UUIDString], ext]];
        // Move to a stable path keeping original filename for share sheet clarity
        NSString *named = [NSTemporaryDirectory() stringByAppendingPathComponent:asset.name];
        [[NSFileManager defaultManager] removeItemAtPath:named error:nil];
        NSError *me = nil;
        NSURL *srcURL = tmp;
        // Prefer original filename
        [[NSFileManager defaultManager] moveItemAtURL:srcURL toURL:[NSURL fileURLWithPath:named] error:&me];
        NSURL *finalURL = me ? [NSURL fileURLWithPath:dest] : [NSURL fileURLWithPath:named];
        if (me) {
            [[NSFileManager defaultManager] moveItemAtURL:srcURL toURL:finalURL error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(finalURL, nil); });
    }];
    // Progress via KVO is overkill; poll countOfBytesReceived for UI that passes progress block.
    // Simple: report indeterminate 0.1 then 1.0 on completion; caller shows spinner.
    // For real progress, caller can observe task via DownloadManager hub instead.
    if (progress) progress(0.1f);
    [task resume];
}

- (void)installFileAtURL:(NSURL *)fileURL fromViewController:(UIViewController *)vc {
    if (!fileURL || !vc) return;
    NSString *path = fileURL.path;
    BOOL isTipa = [[path.pathExtension lowercaseString] isEqualToString:@"tipa"];
    NSString *schemeURL = nil;
    // TrollStore install APIs (best effort, version-dependent):
    // - trollstore://install?url=<file-url-encoded>
    // - apple-magnifier://install?url=<...>
    // File URL must be percent-encoded. TrollStore can install local files via UIDocumentInteractionController
    // "Open In TrollStore" as well, so Share Sheet is the reliable fallback.
    NSString *enc = [[NSURL fileURLWithPath:path].absoluteString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSArray<NSString *> *candidates = @[
        [NSString stringWithFormat:@"trollstore://install?url=%@", enc],
        [NSString stringWithFormat:@"apple-magnifier://install?url=%@", enc],
    ];
    UIApplication *app = UIApplication.sharedApplication;
    __block BOOL opened = NO;
    // Only try custom schemes on TrollStore installs or tipa files
    if ([self isTrollStoreInstall] || isTipa) {
        for (NSString *s in candidates) {
            NSURL *u = [NSURL URLWithString:s];
            if (u && [app canOpenURL:u]) {
                [app openURL:u options:@{} completionHandler:^(BOOL success) {
                    if (!success) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self presentShareSheet:fileURL fromVC:vc];
                        });
                    }
                }];
                opened = YES;
                break;
            }
        }
    }
    if (!opened) {
        [self presentShareSheet:fileURL fromVC:vc];
    }
}

- (void)presentShareSheet:(NSURL *)fileURL fromVC:(UIViewController *)vc {
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = vc.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width/2, vc.view.bounds.size.height/2, 1, 1);
    }
    [vc presentViewController:sheet animated:YES completion:nil];
}

- (void)autoCheckFromViewController:(UIViewController *)vc {
    if (!vc) return;
    // Respect "Để sau": don't nag more than once per 3 days unless force.
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastPrompt = [getPrefObject(@"witch.update_last_prompt") doubleValue];
    if (now - lastPrompt < 3*24*3600) return;
    [self checkForUpdateForce:NO completion:^(WitchReleaseInfo *info, BOOL hasUpdate, NSError *error) {
        if (error || !hasUpdate || !info) return;
        // Only prompt if there is at least one installable asset
        WitchReleaseAsset *any = [info assetForVariant:WitchAppVariantFull isTrollStore:[self isTrollStoreInstall]];
        if (!any) any = info.assets.firstObject;
        if (!any) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Có bản mới"
            message:[NSString stringWithFormat:@"Kênh %@ (%@) có bản mới.\nMở màn hình Cập nhật để chọn Full/Simple và cài đặt.", [self channelDisplayName:[self selectedChannel]], [self effectiveTag]]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
            setPrefObject(@"witch.update_last_prompt", @([[NSDate date] timeIntervalSince1970]));
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cập nhật" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            setPrefObject(@"witch.update_last_prompt", @([[NSDate date] timeIntervalSince1970]));
            [self markSeen:info];
            Class cls = NSClassFromString(@"LauncherUpdateViewController");
            if (cls) {
                UIViewController *uvc = [[cls alloc] init];
                uvc.title = @"Cập nhật";
                [vc.navigationController pushViewController:uvc animated:YES];
                if (!vc.navigationController) [vc presentViewController:[[UINavigationController alloc] initWithRootViewController:uvc] animated:YES completion:nil];
            }
        }]];
        [vc presentViewController:alert animated:YES completion:nil];
    }];
}

@end
