#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupRecord : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *localPath;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic) unsigned long long size;
@property (nonatomic) NSUInteger fileCount;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *instance;
@property (nonatomic, copy) NSArray<NSString *> *roots;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *uploads;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

- (NSString *)reasonTitle;
- (NSString *)destinationSummary;
- (NSInteger)successfulUploadCount;
- (BOOL)hasRemoteCopy;

@end

@interface BackupScope : NSObject

@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *instance;
@property (nonatomic, copy) NSString *versionPath;
@property (nonatomic, copy) NSArray<NSString *> *roots;

+ (NSArray<NSString *> *)defaultRoots;
+ (NSArray<NSString *> *)selectableRootsAtVersionPath:(NSString *)versionPath;
+ (instancetype)scopeForVersion:(NSString *)version roots:(nullable NSArray<NSString *> *)roots;
+ (BOOL)isSafeRelativePath:(NSString *)path;
+ (BOOL)isInternalRoot:(NSString *)path;
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
