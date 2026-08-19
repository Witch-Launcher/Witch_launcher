#import "ModrinthService.h"

static NSString *const kModrinthBaseURL = @"https://api.modrinth.com/v2";

@implementation ModrinthService

+ (instancetype)shared {
    static ModrinthService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)searchProjectsWithType:(NSString *)projectType
                         query:(NSString *)query
                        offset:(NSInteger)offset
                         limit:(NSInteger)limit
                  categoryFilter:(NSString *)categoryFilter
                   loaderFilter:(NSString *)loaderFilter
              gameVersionFilter:(NSString *)gameVersionFilter
                    completion:(void(^)(NSArray<NSDictionary *> *, NSError *))completion
{
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";
    
    // Build Modrinth facets: [["project_type:X"],["categories:Y"],["categories:Z"],["versions:V"]]
    NSMutableArray *facetGroups = [NSMutableArray array];
    [facetGroups addObject:[NSString stringWithFormat:@"[\"project_type:%@\"]", projectType]];
    if (categoryFilter.length > 0) {
        [facetGroups addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", categoryFilter]];
    }
    if (loaderFilter.length > 0) {
        [facetGroups addObject:[NSString stringWithFormat:@"[\"categories:%@\"]", loaderFilter]];
    }
    if (gameVersionFilter.length > 0) {
        [facetGroups addObject:[NSString stringWithFormat:@"[\"versions:%@\"]", gameVersionFilter]];
    }
    NSString *facets = [NSString stringWithFormat:@"[%@]", [facetGroups componentsJoinedByString:@","]];

    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@/search", kModrinthBaseURL]];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"query" value:encodedQuery],
        [NSURLQueryItem queryItemWithName:@"facets" value:facets],
        [NSURLQueryItem queryItemWithName:@"offset" value:[@(offset) stringValue]],
        [NSURLQueryItem queryItemWithName:@"limit" value:[@(limit) stringValue]],
        [NSURLQueryItem queryItemWithName:@"index" value:@"relevance"],
    ];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSArray *hits = json[@"hits"];
        NSMutableArray *results = [NSMutableArray array];
        for (NSDictionary *hit in hits) {
            [results addObject:@{
                @"project_id": hit[@"project_id"] ?: @"",
                @"title": hit[@"title"] ?: @"",
                @"description": hit[@"description"] ?: @"",
                @"icon_url": hit[@"icon_url"] ?: @"",
                @"author": hit[@"author"] ?: @"",
                @"downloads": hit[@"downloads"] ?: @0,
                @"follows": hit[@"follows"] ?: @0,
                @"project_type": hit[@"project_type"] ?: projectType,
                @"latest_version": hit[@"latest_version"] ?: @"",
                @"categories": hit[@"categories"] ?: @[],
                @"game_versions": hit[@"game_versions"] ?: @[],
                @"loaders": hit[@"loaders"] ?: @[],
            }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(results, nil);
        });
    }] resume];
}

- (void)loadProjectVersions:(NSString *)projectId
                 completion:(void(^)(NSArray<NSDictionary *> *, NSError *))completion
{
    NSString *urlStr = [NSString stringWithFormat:@"%@/project/%@/version", kModrinthBaseURL, projectId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSMutableArray *versions = [NSMutableArray array];
        for (NSDictionary *ver in json) {
            NSString *name = ver[@"name"] ?: @"";
            NSString *versionNumber = ver[@"version_number"] ?: @"";
            NSArray *gameVersions = ver[@"game_versions"] ?: @[];
            NSArray *loaders = ver[@"loaders"] ?: @[];
            NSDictionary *primaryFile = [ver[@"files"] firstObject] ?: @{};
            [versions addObject:@{
                @"name": name,
                @"version_number": versionNumber,
                @"game_versions": gameVersions,
                @"loaders": loaders,
                @"url": primaryFile[@"url"] ?: @"",
                @"filename": primaryFile[@"filename"] ?: @"",
                @"size": primaryFile[@"size"] ?: @0,
                @"dependencies": ver[@"dependencies"] ?: @[],
            }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(versions, nil);
        });
    }] resume];
}

- (void)loadProjectDetails:(NSString *)projectId
                completion:(void(^)(NSDictionary *, NSError *))completion
{
    NSString *urlStr = [NSString stringWithFormat:@"%@/project/%@", kModrinthBaseURL, projectId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(json, error);
        });
    }] resume];
}

- (NSURLSessionDownloadTask *)downloadFile:(NSString *)urlString
                                      name:(NSString *)name
                             progressBlock:(void(^)(float progress))progress
                                 completion:(void(^)(NSString *path, NSError *error))completion
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ModrinthService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return nil;
    }

    NSString *destPath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];

    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:destPath] error:&moveError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(destPath, moveError);
        });
    }];
    [task resume];

    if (progress) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (task.state == NSURLSessionTaskStateRunning) {
                [NSThread sleepForTimeInterval:0.5];
                float p = task.countOfBytesExpectedToReceive > 0 ? (float)task.countOfBytesReceived / task.countOfBytesExpectedToReceive : 0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(p);
                });
            }
        });
    }

    return task;
}

@end
