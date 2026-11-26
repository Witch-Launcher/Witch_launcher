#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupScheduler : NSObject

+ (void)registerTasks;
+ (void)scheduleNext;

@end

NS_ASSUME_NONNULL_END
