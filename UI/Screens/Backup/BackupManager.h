#import <Foundation/Foundation.h>
#import "BackupRecord.h"
#import "BackupDestinations.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const BackupDidChangeNotification;

@interface BackupManager : NSObject

@property (class, readonly) BackupManager *shared;

@property (atomic, readonly) BOOL busy;
@property (nonatomic, readonly) NSArray<BackupRecord *> *records;
@property (nonatomic, readonly) NSArray<id<BackupDestination>> *destinations;
@property (nonatomic, readonly) NSArray<id<BackupDestination>> *enabledDestinations;

- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;
- (BOOL)isTriggerEnabled:(NSString *)trigger;
- (void)setTrigger:(NSString *)trigger enabled:(BOOL)enabled;
- (NSInteger)retentionCount;
- (void)setRetentionCount:(NSInteger)count;
- (NSString *)lastBackupDescription;
- (unsigned long long)totalLocalBytes;

- (BOOL)isRunningGame;
- (void)backupNowWithReason:(NSString *)reason
                 completion:(nullable void (^)(BackupRecord * _Nullable record, NSError * _Nullable error))completion;
- (void)backupIfNeededForTrigger:(NSString *)trigger
                      completion:(nullable void (^)(BackupRecord * _Nullable record, NSError * _Nullable error))completion;

- (void)restoreRecord:(BackupRecord *)record
             overwrite:(BOOL)overwrite
              progress:(nullable void (^)(double fraction, NSString *message))progress
            completion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)uploadRecord:(BackupRecord *)record
  toDestinationIdentifier:(NSString *)identifier
              completion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)deleteRecord:(BackupRecord *)record
          deleteRemote:(BOOL)deleteRemote
            completion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)reload;
- (void)pruneOldBackups;

@end

NS_ASSUME_NONNULL_END
