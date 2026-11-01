#import "WitchPlugin.h"

@interface WitchPlugin ()
@property (nonatomic, readwrite) NSString *pluginID;
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *version;
@property (nonatomic, readwrite) NSString *summaryText;
@property (nonatomic, readwrite) NSString *detailsText;
@property (nonatomic, readwrite) NSString *author;
@property (nonatomic, readwrite) NSString *license;
@property (nonatomic, readwrite, nullable) NSString *sourceURL;
@property (nonatomic, readwrite, nullable) NSString *iconPath;
@property (nonatomic, readwrite, nullable) NSString *bannerPath;
@property (nonatomic, readwrite) NSString *installPath;
@property (nonatomic, readwrite) NSDictionary *manifest;
@property (nonatomic, readwrite) NSDictionary *state;
@property (nonatomic, readwrite) NSArray<NSString *> *permissions;
@property (nonatomic, readwrite) NSArray<NSDictionary *> *settingsSchema;
@property (nonatomic, readwrite) NSDictionary *entrypoints;
@property (nonatomic, readwrite) NSInteger apiVersion;
@property (nonatomic, readwrite) BOOL enabled;
@property (nonatomic, readwrite) BOOL trustedSignature;
@property (nonatomic, readwrite) BOOL developerSigned;
@property (nonatomic, readwrite) WitchPluginVerificationState verificationState;
@property (nonatomic, readwrite) NSString *verificationMessage;
@property (nonatomic, readwrite, nullable) NSString *signatureKeyID;
@property (nonatomic, readwrite, nullable) NSString *publicKeyBase64;
@property (nonatomic, readwrite, nullable) NSString *checksumsSha256;
@property (nonatomic, readwrite, nullable) NSString *artifactSha256;
@property (nonatomic, readwrite, nullable) NSString *verifiedAt;
@property (nonatomic, readwrite) NSInteger crashCount;
@end

static NSString *WPString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation WitchPlugin

- (instancetype)initWithInstallPath:(NSString *)installPath
                           manifest:(NSDictionary *)manifest
                              state:(NSDictionary *)state {
    self = [super init];
    if (self) {
        _installPath = [installPath copy];
        _manifest = [manifest copy];
        _pluginID = WPString(manifest[@"id"]);
        _name = WPString(manifest[@"name"]);
        _version = WPString(manifest[@"version"]);
        _summaryText = WPString(manifest[@"description"]);
        _detailsText = WPString(manifest[@"details"]);
        _author = WPString(manifest[@"author"]);
        _license = WPString(manifest[@"license"]);
        _sourceURL = [manifest[@"source"] isKindOfClass:[NSString class]] ? manifest[@"source"] : nil;
        _permissions = [manifest[@"permissions"] isKindOfClass:[NSArray class]] ? manifest[@"permissions"] : @[];
        _settingsSchema = [manifest[@"settings"] isKindOfClass:[NSArray class]] ? manifest[@"settings"] : @[];
        _entrypoints = [manifest[@"entrypoints"] isKindOfClass:[NSDictionary class]] ? manifest[@"entrypoints"] : @{};
        _apiVersion = [manifest[@"api"] respondsToSelector:@selector(integerValue)] ? [manifest[@"api"] integerValue] : 0;
        NSString *icon = WPString(manifest[@"icon"]);
        NSString *banner = WPString(manifest[@"banner"]);
        _iconPath = icon.length > 0 ? [installPath stringByAppendingPathComponent:icon] : nil;
        _bannerPath = banner.length > 0 ? [installPath stringByAppendingPathComponent:banner] : nil;
        [self updateState:state];
    }
    return self;
}

- (void)updateState:(NSDictionary *)state {
    _state = [state copy] ?: @{};
    _enabled = [_state[@"enabled"] boolValue];
    _trustedSignature = [_state[@"trusted"] boolValue];
    _developerSigned = [_state[@"developerSigned"] boolValue];
    _verificationState = (WitchPluginVerificationState)[_state[@"verificationState"] integerValue];
    _verificationMessage = WPString(_state[@"verificationMessage"]);
    if (_verificationMessage.length == 0) {
        _verificationMessage = _verificationState == WitchPluginVerificationStateVerified ? @"Verified by the Witch plugin registry" : @"Signature is valid but this build is not verified by the registry";
    }
    _signatureKeyID = [_state[@"keyId"] isKindOfClass:[NSString class]] ? _state[@"keyId"] : nil;
    _publicKeyBase64 = [_state[@"publicKey"] isKindOfClass:[NSString class]] ? _state[@"publicKey"] : nil;
    _checksumsSha256 = [_state[@"checksumsSha256"] isKindOfClass:[NSString class]] ? _state[@"checksumsSha256"] : nil;
    _artifactSha256 = [_state[@"artifactSha256"] isKindOfClass:[NSString class]] ? _state[@"artifactSha256"] : nil;
    _verifiedAt = [_state[@"verifiedAt"] isKindOfClass:[NSString class]] ? _state[@"verifiedAt"] : nil;
    _crashCount = [_state[@"crashCount"] integerValue];
}

- (NSDictionary *)settings {
    NSDictionary *settings = self.state[@"settings"];
    return [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
}

- (nullable UIImage *)iconImage {
    return self.iconPath.length > 0 ? [UIImage imageWithContentsOfFile:self.iconPath] : nil;
}

- (nullable UIImage *)bannerImage {
    return self.bannerPath.length > 0 ? [UIImage imageWithContentsOfFile:self.bannerPath] : nil;
}

@end
