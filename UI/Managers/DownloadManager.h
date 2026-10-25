#import <Foundation/Foundation.h>

extern NSString * const DownloadTasksDidChangeNotification;

typedef NS_ENUM(NSUInteger, DownloadType) {
    DownloadTypeMod,
    DownloadTypeShader,
    DownloadTypeResourcePack,
    DownloadTypeMap,
    DownloadTypeServer,
    DownloadTypeModpack,
    DownloadTypeLaunch
};

@interface DownloadTask : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *url;
@property (nonatomic) DownloadType type;
@property (nonatomic) NSString *targetPath;
@property (nonatomic) float progress;
@property (nonatomic) long long receivedBytes;
@property (nonatomic) long long totalBytes;
@property (nonatomic) double bytesPerSecond;
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

// Unpacks a world .zip into <savesDir>/<world folder> so Minecraft can see it
// (a zip sitting in saves/ is invisible to the game). Handles both layouts:
// level.dat at the archive root, and everything wrapped in one top folder.
// Returns NO with an error when no level.dat exists anywhere in the archive.
+ (BOOL)installWorldArchiveAtPath:(NSString *)archivePath
                         savesDir:(NSString *)savesDir
                     fallbackName:(NSString *)fallbackName
                            error:(NSError **)error;

// Multi-download hub (top bar progress center). Fully parallel: callers may
// start any number of tasks and continue using the app.
- (NSArray<DownloadTask *> *)activeTasks;
// Active first, then recently finished ones (newest first) so the download
// list can keep showing checkmarks after a file completes.
- (NSArray<DownloadTask *> *)allTasks;
- (DownloadTask *)beginTaskWithName:(NSString *)name type:(DownloadType)type;
- (void)updateProgress:(float)progress forTask:(DownloadTask *)task;
- (void)updateProgressBytes:(float)progress received:(long long)received total:(long long)total forTask:(DownloadTask *)task;
- (void)completeTask:(DownloadTask *)task error:(NSError *)error;
- (void)cancelTask:(DownloadTask *)task;
- (void)cancelAllTasks;
- (void)clearFinishedTasks;

@end
