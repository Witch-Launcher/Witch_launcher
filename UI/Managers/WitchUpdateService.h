#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, WitchUpdateChannel) {
    WitchUpdateChannelAuto = 0,   // beta build -> pre-release, release build -> release
    WitchUpdateChannelBeta = 1,   // always pre-release
    WitchUpdateChannelStable = 2, // always release
};

typedef NS_ENUM(NSInteger, WitchAppVariant) {
    WitchAppVariantFull = 0,
    WitchAppVariantSlimmed = 1,
};

@interface WitchReleaseAsset : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *downloadURL;
@property (nonatomic, assign) long long size;
@end

@interface WitchReleaseInfo : NSObject
@property (nonatomic, copy) NSString *tagName;
@property (nonatomic, copy) NSString *htmlURL;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, strong) NSArray<WitchReleaseAsset *> *assets;
- (WitchReleaseAsset *)assetForVariant:(WitchAppVariant)variant isTrollStore:(BOOL)isTrollStore;
@end

@interface WitchUpdateService : NSObject

@property (class, readonly) WitchUpdateService *shared;

- (NSString *)githubRepo; // e.g. Witch-Launcher/Witch_launcher, override via pref witch.update_repo
- (WitchUpdateChannel)selectedChannel;
- (void)setSelectedChannel:(WitchUpdateChannel)channel;
- (NSString *)channelDisplayName:(WitchUpdateChannel)channel;
- (NSString *)effectiveTag; // pre-release or release
- (BOOL)isTrollStoreInstall;
- (NSString *)currentVersion;
- (BOOL)isBetaBuild;

- (void)checkForUpdateForce:(BOOL)force
                 completion:(void(^)(WitchReleaseInfo *info, BOOL hasUpdate, NSError *error))completion;
- (void)downloadAsset:(WitchReleaseAsset *)asset
             progress:(void(^)(float progress))progress
           completion:(void(^)(NSURL *fileURL, NSError *error))completion;
- (void)installFileAtURL:(NSURL *)fileURL fromViewController:(UIViewController *)vc;

// Auto-check once per launch (respects witch.update_last_prompt + 3 days for "later")
- (void)autoCheckFromViewController:(UIViewController *)vc;

@end
