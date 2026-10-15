#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Version-check statuses returned per item (parallel to items array):
//   checking / update / latest / incompatible / unknown (offline or error) / local (no project_id) / none
extern NSString * const ModUpdateStatusChecking;
extern NSString * const ModUpdateStatusUpdate;
extern NSString * const ModUpdateStatusLatest;
extern NSString * const ModUpdateStatusIncompatible;
extern NSString * const ModUpdateStatusUnknown;
extern NSString * const ModUpdateStatusLocal;
extern NSString * const ModUpdateStatusNone;

@interface ModUpdateChecker : NSObject

@property (class, readonly) ModUpdateChecker *shared;

// 24h cache: same (source, project_id, mcVersion, loader) is not re-fetched within a day
// unless forceRefresh=YES. Completion always on main queue with one result dict per item:
// @{ status, latest_version, latest_url, latest_filename, reason }
- (void)checkItems:(NSArray<NSDictionary *> *)items
         mcVersion:(NSString *)mcVersion
            loader:(NSString *)loader
      forceRefresh:(BOOL)force
        completion:(void(^)(NSArray<NSDictionary *> *results))completion;

- (void)invalidateAllCaches;

@end

NS_ASSUME_NONNULL_END
