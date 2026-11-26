#import <Foundation/Foundation.h>
#import "WitchPluginRisk.h"

NS_ASSUME_NONNULL_BEGIN

// One plugin published by the GitHub catalog repository.
@interface WitchPluginCatalogEntry : NSObject

@property (nonatomic, readonly, copy) NSString *pluginID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, readonly, copy) NSString *summary;
@property (nonatomic, readonly, copy) NSString *author;
@property (nonatomic, readonly, copy) NSString *license;
@property (nonatomic, readonly, copy) NSString *sourceURL;
@property (nonatomic, readonly, copy) NSString *notes;
@property (nonatomic, readonly, copy) NSString *channel;
// SHA-256 of the published .plgw file. The launcher refuses a package whose
// hash does not match this value.
@property (nonatomic, readonly, copy) NSString *sha256;
@property (nonatomic, readonly, copy) NSString *downloadURL;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary downloadURL:(NSString *)downloadURL;

@end

// Reads the plugin catalog from a GitHub repository, resolves the packages and
// hands the verified package to the installer.
@interface WitchPluginUpdateService : NSObject

@property (class, readonly) WitchPluginUpdateService *shared;

// "owner/repo" of the catalog repository.
@property (nonatomic, readonly, copy) NSString *repository;
@property (nonatomic, readonly, copy) NSArray<WitchPluginCatalogEntry *> *entries;
@property (nonatomic, readonly, copy) NSString *repositoryDescription;
@property (nonatomic, readonly, copy) NSString *lastErrorMessage;
@property (nonatomic, readonly, nullable) NSDate *lastRefreshDate;
@property (nonatomic, readonly) BOOL loading;

- (void)refreshCatalogWithCompletion:(void (^)(BOOL ok, NSError * _Nullable error))completion;
- (nullable WitchPluginCatalogEntry *)entryForPluginID:(NSString *)pluginID;
- (BOOL)hasUpdateForPluginID:(NSString *)pluginID version:(NSString *)version;

// Downloads the package, pins it against the catalog hash, verifies the
// signature and the checksums, analyses the risk and asks the registry for a
// verdict. The completion only runs when everything passed.
- (void)fetchAndVerifyEntry:(WitchPluginCatalogEntry *)entry
                completion:(void (^)(NSURL * _Nullable packageURL,
                                     NSDictionary * _Nullable info,
                                     WitchPluginRiskReport * _Nullable risk,
                                     NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
