#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "AFNetworking.h"

NSString * const DownloadTasksDidChangeNotification = @"DownloadTasksDidChangeNotification";

@implementation DownloadTask
@end

@interface DownloadManager ()
@property (nonatomic) NSMutableArray<DownloadTask *> *activeTasks;
@end

@implementation DownloadManager

+ (DownloadManager *)shared {
    static DownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTasks = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Multi-download hub

- (void)notifyChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:DownloadTasksDidChangeNotification object:nil];
}

- (NSArray<DownloadTask *> *)activeTasks {
    return [_activeTasks copy];
}

- (DownloadTask *)beginTaskWithName:(NSString *)name type:(DownloadType)type {
    DownloadTask *t = [[DownloadTask alloc] init];
    t.name = name ?: @"Download";
    t.type = type;
    t.progress = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_activeTasks addObject:t];
        [self notifyChange];
    });
    return t;
}

- (void)updateProgress:(float)progress forTask:(DownloadTask *)task {
    if (!task || task.cancelled) return;
    float clamped = MAX(0.0f, MIN(progress, 1.0f));
    // Throttle: only notify on meaningful steps to avoid notification storms.
    static const float kStep = 0.02f;
    static NSMutableDictionary<NSString *, NSNumber *> *lastSteps = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lastSteps = [NSMutableDictionary dictionary]; });
    NSString *key = NSStringFromClass(task.class);
    key = [key stringByAppendingFormat:@"/%@", task.name];
    NSNumber *last = lastSteps[key];
    if (clamped < 1.0f && last && fabs(clamped - last.floatValue) < kStep) {
        task.progress = clamped;
        return;
    }
    lastSteps[key] = @(clamped);
    dispatch_async(dispatch_get_main_queue(), ^{
        task.progress = clamped;
        [self notifyChange];
    });
}

- (void)completeTask:(DownloadTask *)task error:(NSError *)error {
    if (!task) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        task.isFinished = YES;
        task.error = error;
        [self->_activeTasks removeObject:task];
        [self notifyChange];
    });
}

- (void)cancelTask:(DownloadTask *)task {
    if (!task || task.cancelled) return;
    task.cancelled = YES;
    if (task.cancelBlock) task.cancelBlock();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_activeTasks removeObject:task];
        [self notifyChange];
    });
}

- (void)cancelAllTasks {
    for (DownloadTask *t in [self.activeTasks copy]) {
        [self cancelTask:t];
    }
}

#pragma mark - Convenience flows

- (void)downloadMod:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:version];
    NSString *targetPath = [modsDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".jar"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadShader:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *shaderDir = [VersionDirectoryManager.shared shaderPacksPathForVersion:version];
    NSString *targetPath = [shaderDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".zip"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"zip"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadResourcePack:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *rpDir = [VersionDirectoryManager.shared resourcePacksPathForVersion:version];
    NSString *targetPath = [rpDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".zip"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"zip"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadMap:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL, NSError *))completion {
    NSString *savesDir = [VersionDirectoryManager.shared savesPathForVersion:version];
    NSString *targetPath = [savesDir stringByAppendingPathComponent:name];
    if (![targetPath hasSuffix:@".zip"]) {
        targetPath = [targetPath stringByAppendingPathExtension:@"zip"];
    }
    [self downloadToPath:url targetPath:targetPath completion:completion];
}

- (void)downloadToPath:(NSString *)urlString targetPath:(NSString *)targetPath completion:(void(^)(BOOL, NSError *))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DownloadManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return;
    }

    NSString *dir = targetPath.stringByDeletingLastPathComponent;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *task = [[AFHTTPSessionManager manager] downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath_, NSURLResponse *response) {
        NSString *suggested = response.suggestedFilename ?: targetPath.lastPathComponent;
        NSString *finalPath = [targetPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:suggested];
        return [NSURL fileURLWithPath:finalPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
        } else {
            if (completion) completion(YES, nil);
        }
    }];
    [task resume];
}

@end
