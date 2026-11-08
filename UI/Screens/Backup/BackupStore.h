#import <Foundation/Foundation.h>
#import "BackupRecord.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^BackupProgressBlock)(double fraction, NSString *message);

@interface BackupStore : NSObject

@property (class, readonly) BackupStore *shared;

- (NSArray<BackupRecord *> *)records;
- (void)reloadRecords;
- (void)saveRecords;
- (void)addRecord:(BackupRecord *)record;
- (void)updateRecord:(BackupRecord *)record;
- (void)removeRecord:(BackupRecord *)record deleteArchive:(BOOL)deleteArchive;
- (void)removeAllRecords;
- (void)removeAllLocalArchives;

- (nullable BackupRecord *)createArchiveForScope:(BackupScope *)scope
                                          reason:(NSString *)reason
                                        progress:(nullable BackupProgressBlock)progress
                                           error:(NSError **)error;

- (BOOL)restoreRecord:(BackupRecord *)record
             overwrite:(BOOL)overwrite
              progress:(nullable BackupProgressBlock)progress
                 error:(NSError **)error;

- (BOOL)verifyRecord:(BackupRecord *)record error:(NSError **)error;
- (unsigned long long)totalArchiveBytes;

@end

NS_ASSUME_NONNULL_END
