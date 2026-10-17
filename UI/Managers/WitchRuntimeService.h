#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WitchRuntimeKind) {
    WitchRuntimeKindJDK = 0,
    WitchRuntimeKindLWJGL = 1,
};

@interface WitchRuntimeItem : NSObject
@property (nonatomic, copy) NSString *identifier; // jre8, jre17, jre21, jre25, lwjgl333, lwjgl336, lwjgl341
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) WitchRuntimeKind kind;
@property (nonatomic, assign) BOOL important; // hiện chữ "quan trọng"
@property (nonatomic, copy) NSString *remoteURL;    // từ runtimes.json
@property (nonatomic, copy) NSString *remoteVersion;
@property (nonatomic, copy) NSString *localVersion; // nil = chưa cài
@property (nonatomic, assign) long long remoteSize;
@property (nonatomic, readonly) BOOL installed;
@property (nonatomic, readonly) BOOL updateAvailable;
@end

@interface WitchRuntimeService : NSObject
@property (class, readonly) WitchRuntimeService *shared;
- (NSString *)manifestURL; // pref witch.runtime_manifest hoặc default JDK-Java_iOS
- (NSArray<WitchRuntimeItem *> *)builtinItems; // 4 JDK + 3 LWJGL, đánh dấu quan trọng theo yêu cầu
- (void)refreshStatuses:(void(^)(NSArray<WitchRuntimeItem *> *items, NSError *error))completion;
- (void)downloadItem:(WitchRuntimeItem *)item progress:(void(^)(float))progress completion:(void(^)(BOOL ok, NSError *error))completion;
- (BOOL)deleteItem:(WitchRuntimeItem *)item error:(NSError **)error;
- (void)rescanRuntimes; // cài luôn không restart: quét lại java_runtimes
@end
