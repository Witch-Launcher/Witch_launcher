#import "BackupScheduler.h"
#import "BackupManager.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <BackgroundTasks/BackgroundTasks.h>

static NSString *const kBackupRefreshTask = @"com.witch.zad626.backup.refresh";
static NSString *const kBackupProcessingTask = @"com.witch.zad626.backup.processing";

@implementation BackupScheduler

+ (void)registerTasks {
    BGTaskScheduler *scheduler = [BGTaskScheduler sharedScheduler];
    [scheduler registerForTaskWithIdentifier:kBackupRefreshTask
                                   usingQueue:nil
                                launchHandler:^(BGTask *task) {
        [self handleTask:task];
    }];
    [scheduler registerForTaskWithIdentifier:kBackupProcessingTask
                                   usingQueue:nil
                                launchHandler:^(BGTask *task) {
        [self handleTask:task];
    }];
    [self scheduleNext];
}

+ (NSTimeInterval)interval {
    NSNumber *hours = getPrefObject(@"backup.auto_interval_hours");
    double value = hours.doubleValue > 0 ? hours.doubleValue : 24.0;
    return MAX(3600.0, value * 3600.0);
}

+ (void)scheduleNext {
    if (![BackupManager shared].isEnabled || ![[BackupManager shared] isTriggerEnabled:@"schedule"]) {
        [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:kBackupRefreshTask];
        [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:kBackupProcessingTask];
        return;
    }
    NSTimeInterval interval = [self interval];
    NSDate *lastRun = getPrefObject(@"backup.lastRun");
    NSDate *anchor = [lastRun isKindOfClass:[NSDate class]] ? lastRun : [NSDate date];
    NSDate *earliest = [anchor dateByAddingTimeInterval:interval];
    if ([earliest timeIntervalSinceNow] < 60) {
        earliest = [NSDate dateWithTimeIntervalSinceNow:60];
    }

    BGAppRefreshTaskRequest *refresh = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kBackupRefreshTask];
    refresh.earliestBeginDate = earliest;
    NSError *refreshError = nil;
    [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:kBackupRefreshTask];
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:refresh error:&refreshError]) {
        NSLog(@"[BackupScheduler] refresh request rejected: %@", refreshError.localizedDescription ?: @"unknown");
    }

    BGProcessingTaskRequest *processing = [[BGProcessingTaskRequest alloc] initWithIdentifier:kBackupProcessingTask];
    processing.requiresNetworkConnectivity = YES;
    processing.requiresExternalPower = NO;
    processing.earliestBeginDate = earliest;
    NSError *processingError = nil;
    [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:kBackupProcessingTask];
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:processing error:&processingError]) {
        NSLog(@"[BackupScheduler] processing request rejected: %@", processingError.localizedDescription ?: @"unknown");
    }
}

+ (void)handleTask:(BGTask *)task {
    __block BOOL finished = NO;
    __block void (^complete)(BOOL) = ^(BOOL success) {
        if (finished) return;
        finished = YES;
        [task setTaskCompletedWithSuccess:success];
        [self scheduleNext];
    };
    task.expirationHandler = ^{
        // Backups are atomic: a cancelled task leaves no partial archive in the
        // index. NSURLSession uploads are stopped when the app is suspended.
        complete(NO);
    };
    [[BackupManager shared] backupIfNeededForTrigger:@"schedule" completion:^(BackupRecord *record, NSError *error) {
        // A cloud upload failure does not invalidate the local backup, and
        // marking the BGTask failed would make iOS schedule it less often.
        complete(record != nil || error == nil);
    }];
}

@end
