#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupConfig : NSObject

+ (NSString *)googleClientID;
+ (NSString *)azureClientID;
+ (NSString *)dropboxAppKey;

+ (NSString *)googleRedirectURI;
+ (NSString *)googleCallbackScheme;
+ (NSString *)azureRedirectURI;
+ (NSString *)azureCallbackScheme;
+ (NSString *)dropboxRedirectURI;
+ (NSString *)dropboxCallbackScheme;

+ (BOOL)googleConfigured;
+ (BOOL)azureConfigured;
+ (BOOL)dropboxConfigured;

+ (NSString *)backupRootPath;
+ (NSString *)archiveDirectoryPath;
+ (NSString *)indexPath;
+ (NSString *)temporaryDirectoryPath;
+ (NSString *)remoteFolderName;

+ (NSString *)humanSize:(unsigned long long)bytes;

@end

NS_ASSUME_NONNULL_END
