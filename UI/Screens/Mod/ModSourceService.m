#import "ModSourceService.h"
#import "ModrinthService.h"
#import "CurseForgeService.h"

@implementation ModSourceService

+ (BOOL)isCurseForgeMod:(NSDictionary *)mod {
    return [[mod objectForKey:@"_source"] isEqualToString:@"curseforge"];
}

+ (NSString *)sourceOfMod:(NSDictionary *)mod {
    return [self isCurseForgeMod:mod] ? @"curseforge" : @"modrinth";
}

+ (void)loadVersionsForMod:(NSDictionary *)mod
                completion:(void(^)(NSArray<NSDictionary *> * _Nullable,
                                    NSError * _Nullable))completion {
    NSString *projectId = mod[@"project_id"];
    if (![projectId isKindOfClass:[NSString class]] || projectId.length == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ModSourceService" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"Mod project ID not found."}]);
        return;
    }
    if ([self isCurseForgeMod:mod]) {
        [CurseForgeService.shared loadProjectVersions:projectId completion:completion];
    } else {
        [ModrinthService.shared loadProjectVersions:projectId completion:completion];
    }
}

+ (void)loadDetailsForProjectId:(NSString *)projectId
                         source:(NSString *)source
                     completion:(void(^)(NSDictionary * _Nullable,
                                        NSError * _Nullable))completion {
    if ([source isEqualToString:@"curseforge"]) {
        [CurseForgeService.shared loadUnifiedProjectDetails:projectId completion:completion];
    } else {
        // Map raw Modrinth details to the unified shape.
        [ModrinthService.shared loadProjectDetails:projectId completion:^(NSDictionary *raw, NSError *error) {
            if (error || ![raw isKindOfClass:[NSDictionary class]]) {
                if (completion) completion(nil, error);
                return;
            }
            if (completion) completion(@{
                @"title": ([raw[@"title"] isKindOfClass:[NSString class]] ? raw[@"title"] : @"Unknown"),
                @"icon_url": ([raw[@"icon_url"] isKindOfClass:[NSString class]] ? raw[@"icon_url"] : @""),
                @"project_id": projectId,
                @"_source": @"modrinth",
            }, nil);
        }];
    }
}

+ (NSURLSessionDownloadTask *)downloadVersion:(NSDictionary *)version
                                        ofMod:(NSDictionary *)mod
                                     progress:(void(^)(float))progress
                                   completion:(void(^)(NSString *, NSError *))completion {
    return [self downloadVersion:version ofMod:mod progressBytes:(progress ? ^(float p, long long r, long long t) {
        progress(p);
    } : nil) completion:completion];
}

+ (NSURLSessionDownloadTask *)downloadVersion:(NSDictionary *)version
                                        ofMod:(NSDictionary *)mod
                                progressBytes:(void(^)(float, long long, long long))progressBytes
                                   completion:(void(^)(NSString *, NSError *))completion {
    NSString *url = [version[@"url"] isKindOfClass:[NSString class]] ? version[@"url"] : @"";
    NSString *filename = [version[@"filename"] isKindOfClass:[NSString class]] && [version[@"filename"] length] > 0
        ? version[@"filename"] : @"file.jar";
    if (url.length > 0) {
        return [self downloadFromURL:url name:filename progressBytes:progressBytes completion:completion];
    }
    // CurseForge files without a direct link: resolve the CDN URL first.
    if ([self isCurseForgeMod:mod]) {
        NSString *projectId = mod[@"project_id"];
        NSNumber *fileId = version[@"_cfFileId"];
        if ([projectId isKindOfClass:[NSString class]] && [fileId isKindOfClass:[NSNumber class]]) {
            __block NSURLSessionDownloadTask *inner = nil;
            // Return a lightweight placeholder task handle; the real task is
            // created after URL resolution. Callers only use it for cancel.
            [CurseForgeService.shared resolveDownloadURLForProject:projectId fileId:fileId completion:^(NSString *resolved, NSError *error) {
                NSString *downloadURL = resolved;
                if (downloadURL.length == 0) {
                    // CurseForge hides downloadUrl for files whose authors did
                    // not opt into third-party distribution. The public CDN
                    // layout still serves them.
                    downloadURL = [CurseForgeService cdnURLForFileId:fileId fileName:filename];
                }
                if (downloadURL.length > 0) {
                    inner = [self downloadFromURL:downloadURL name:filename progressBytes:progressBytes completion:completion];
                } else if (completion) {
                    completion(nil, error ?: [NSError errorWithDomain:@"ModSourceService" code:-2
                        userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve download URL"}]);
                }
            }];
            (void)inner;
            return nil;
        }
    }
    if (completion) completion(nil, [NSError errorWithDomain:@"ModSourceService" code:-1
        userInfo:@{NSLocalizedDescriptionKey: @"This version has no download URL"}]);
    return nil;
}

#pragma mark - Plain downloader

+ (NSURLSessionDownloadTask *)downloadFromURL:(NSString *)urlString
                                         name:(NSString *)name
                                     progress:(void(^)(float))progress
                                   completion:(void(^)(NSString *, NSError *))completion {
    return [self downloadFromURL:urlString name:name progressBytes:(progress ? ^(float p, long long r, long long t) {
        progress(p);
    } : nil) completion:completion];
}

+ (NSURLSessionDownloadTask *)downloadFromURL:(NSString *)urlString
                                         name:(NSString *)name
                                progressBytes:(void(^)(float, long long, long long))progressBytes
                                   completion:(void(^)(NSString *, NSError *))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ModSourceService" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return nil;
    }
    // Unique per-download folder: parallel downloads may share a filename.
    NSString *destDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"amethyst-dl-%@", NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *safeName = name.length > 0 ? name.lastPathComponent : @"file.jar";
    if (safeName.length == 0) safeName = @"file.jar";
    NSString *destPath = [destDir stringByAppendingPathComponent:safeName];
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location
                                                    toURL:[NSURL fileURLWithPath:destPath]
                                                    error:&moveError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(destPath, moveError);
            });
        }];
    [task resume];
    if (progressBytes) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (task.state == NSURLSessionTaskStateRunning) {
                [NSThread sleepForTimeInterval:0.5];
                int64_t received = task.countOfBytesReceived;
                int64_t expected = task.countOfBytesExpectedToReceive;
                float p = expected > 0 ? (float)received / expected : 0;
                dispatch_async(dispatch_get_main_queue(), ^{ progressBytes(p, received, expected); });
            }
        });
    }
    return task;
}

@end
