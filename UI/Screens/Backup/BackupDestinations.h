#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BackupRecord.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BackupDestination <NSObject>

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) BOOL configured;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) NSString *detailText;

- (void)setEnabled:(BOOL)enabled;
- (void)uploadFileAtPath:(NSString *)path
                  record:(BackupRecord *)record
              completion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion;
- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> * _Nullable items, NSError * _Nullable error))completion;
- (void)downloadFileNamed:(NSString *)name
                   toPath:(NSString *)path
               completion:(void (^)(NSError * _Nullable error))completion;
- (void)deleteFileNamed:(NSString *)name
             completion:(void (^)(NSError * _Nullable error))completion;

@end

@interface BackupFolderDestination : NSObject <BackupDestination>
- (BOOL)setFolderURL:(NSURL *)url error:(NSError **)error;
- (void)clearFolder;
- (nullable NSURL *)folderURL;
@end

@interface BackupWebDAVDestination : NSObject <BackupDestination>
@end

@interface BackupGoogleDriveDestination : NSObject <BackupDestination>
@end

@interface BackupOneDriveDestination : NSObject <BackupDestination>
@end

@interface BackupDropboxDestination : NSObject <BackupDestination>
@end

NS_ASSUME_NONNULL_END
