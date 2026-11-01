#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WitchPluginVerificationState) {
    WitchPluginVerificationStateUnverified = 0,
    WitchPluginVerificationStateVerified = 1,
    WitchPluginVerificationStateRevoked = 2,
    WitchPluginVerificationStateInvalid = 3
};

@interface WitchPlugin : NSObject

@property (nonatomic, readonly) NSString *pluginID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *version;
@property (nonatomic, readonly) NSString *summaryText;
@property (nonatomic, readonly) NSString *detailsText;
@property (nonatomic, readonly) NSString *author;
@property (nonatomic, readonly) NSString *license;
@property (nonatomic, readonly, nullable) NSString *sourceURL;
@property (nonatomic, readonly, nullable) NSString *iconPath;
@property (nonatomic, readonly, nullable) NSString *bannerPath;
@property (nonatomic, readonly) NSString *installPath;
@property (nonatomic, readonly) NSDictionary *manifest;
@property (nonatomic, readonly) NSDictionary *state;
@property (nonatomic, readonly) NSArray<NSString *> *permissions;
@property (nonatomic, readonly) NSArray<NSDictionary *> *settingsSchema;
@property (nonatomic, readonly) NSDictionary *entrypoints;
@property (nonatomic, readonly) NSInteger apiVersion;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL trustedSignature;
@property (nonatomic, readonly) BOOL developerSigned;
@property (nonatomic, readonly) WitchPluginVerificationState verificationState;
@property (nonatomic, readonly) NSString *verificationMessage;
@property (nonatomic, readonly, nullable) NSString *signatureKeyID;
@property (nonatomic, readonly, nullable) NSString *publicKeyBase64;
@property (nonatomic, readonly, nullable) NSString *checksumsSha256;
@property (nonatomic, readonly, nullable) NSString *artifactSha256;
@property (nonatomic, readonly, nullable) NSString *verifiedAt;
@property (nonatomic, readonly) NSInteger crashCount;

- (instancetype)initWithInstallPath:(NSString *)installPath
                           manifest:(NSDictionary *)manifest
                              state:(NSDictionary *)state;
- (void)updateState:(NSDictionary *)state;
- (NSDictionary *)settings;
- (nullable UIImage *)iconImage;
- (nullable UIImage *)bannerImage;

@end

NS_ASSUME_NONNULL_END
