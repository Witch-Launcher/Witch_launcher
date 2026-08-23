#import <Foundation/Foundation.h>

extern NSString * const DownloadTasksDidChangeNotification;

typedef NS_ENUM(NSUInteger, DownloadType) {
    DownloadTypeMod,
    DownloadTypeShader,
    DownloadTypeResourcePack,
    DownloadTypeMap,
    DownloadTypeServer,
    DownloadTypeModpack
};

@interface DownloadTask : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *url;
@property (nonatomic) DownloadType type;
@property (nonatomic) NSString *targetPath;
@property (nonatomic) float progress;
@property (nonatomic) BOOL isFinished;
@property (nonatomic) NSError *error;
@property (nonatomic) BOOL cancelled;
@property (nonatomic, copy) void (^cancelBlock)(void);
@end

@interface DownloadManager : NSObject

@property (class, readonly) DownloadManager *shared;

- (void)downloadMod:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL success, NSError *error))completion;
- (void)downloadShader:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL success, NSError *error))completion;
- (void)downloadResourcePack:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL success, NSError *error))completion;
- (void)downloadMap:(NSString *)url name:(NSString *)name version:(NSString *)version completion:(void(^)(BOOL success, NSError *error))completion;
- (void)downloadToPath:(NSString *)url targetPath:(NSString *)targetPath completion:(void(^)(BOOL success, NSError *error))completion;

// Multi-download hub (top bar progress center). Fully parallel: callers may
// start any number of tasks and continue using the app.
- (NSArray<DownloadTask *> *)activeTasks;
- (DownloadTask *)beginTaskWithName:(NSString *)name type:(DownloadType)type;
- (void)updateProgress:(float)progress forTask:(DownloadTask *)task;
- (void)completeTask:(DownloadTask *)task error:(NSError *)error;
- (void)cancelTask:(DownloadTask *)task;
- (void)cancelAllTasks;

@end
