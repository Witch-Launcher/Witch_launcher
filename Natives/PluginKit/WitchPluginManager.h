#import <Foundation/Foundation.h>
#import "WitchPlugin.h"
#import "WitchPluginRisk.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const WitchPluginsDidChangeNotification;

// How a package is installed with respect to the launcher sandbox.
typedef NS_ENUM(NSInteger, WitchPluginSandboxPolicy) {
    // Sandbox the plugin when the risk analysis asks for it.
    WitchPluginSandboxPolicyAuto = 0,
    // Always run the plugin inside the sandbox.
    WitchPluginSandboxPolicyAlways = 1,
    // Never sandbox. Only used when the user explicitly accepts the risk.
    WitchPluginSandboxPolicyNever = 2
};

// What the launcher does with a package when it is installed.
@interface WitchPluginInstallOptions : NSObject

// Sandbox the plugin when the risk analysis asks for it.
@property (nonatomic) WitchPluginSandboxPolicy sandboxPolicy;
// Replace an already installed plugin of the same id.
@property (nonatomic) BOOL allowReplace;
// Trust in the publisher of the package.
@property (nonatomic) WitchPluginTrust trust;
// Why the publisher is trusted, shown on the plugin screen.
@property (nonatomic, copy, nullable) NSString *trustMessage;
// The package hash the catalog publishes, so the launcher can tell later
// whether the installed build is still the published one.
@property (nonatomic, copy, nullable) NSString *publishedSha256;

+ (instancetype)defaultOptions;

@end

@interface WitchPluginManager : NSObject

@property (class, readonly) WitchPluginManager *shared;

@property (nonatomic, readonly) BOOL safeMode;
@property (nonatomic, readonly) NSArray<WitchPlugin *> *plugins;
@property (nonatomic, readonly) NSString *pluginsDirectory;
@property (nonatomic, readonly) NSString *configurationPath;

- (void)reload;
- (nullable WitchPlugin *)pluginWithID:(NSString *)pluginID;
- (nullable NSDictionary *)inspectPackageAtURL:(NSURL *)url error:(NSError **)error;
- (BOOL)installPackageAtURL:(NSURL *)url error:(NSError **)error;
- (BOOL)installPackageAtURL:(NSURL *)url expectedInfo:(nullable NSDictionary *)info error:(NSError **)error;
- (BOOL)installPackageAtURL:(NSURL *)url
                expectedInfo:(nullable NSDictionary *)info
                     options:(nullable WitchPluginInstallOptions *)options
                       error:(NSError **)error;
- (BOOL)uninstallPluginID:(NSString *)pluginID error:(NSError **)error;
- (BOOL)setPluginID:(NSString *)pluginID enabled:(BOOL)enabled error:(NSError **)error;
- (BOOL)setPluginID:(NSString *)pluginID sandboxed:(BOOL)sandboxed error:(NSError **)error;
- (BOOL)sandboxEnabledForPluginID:(NSString *)pluginID;
- (nullable WitchPluginRiskReport *)riskReportForPluginID:(NSString *)pluginID;
- (BOOL)setSafeMode:(BOOL)safeMode error:(NSError **)error;
- (void)verifyPlugin:(WitchPlugin *)plugin completion:(nullable void (^)(BOOL verified, NSError * _Nullable error))completion;
- (void)verifyInstalledPlugins;
// Asks the registry about a package. The verdict is a trust signal, not a
// gate: a package the registry does not know can still be installed, it is
// simply marked as an unknown publisher.
- (void)checkPackageTrust:(NSDictionary *)info
               completion:(nullable void (^)(WitchPluginTrust trust, NSString * _Nullable reason, NSError * _Nullable error))completion;
// Turns an answer of the registry into a trust signal. A build the registry
// blocked is the only one that produces an error.
+ (WitchPluginTrust)trustForRegistryResponse:(nullable NSDictionary *)json
                                       reason:(NSString * _Nullable * _Nullable)reason
                                        error:(NSError * _Nullable * _Nullable)error;
- (BOOL)verifyIntegrityForPlugin:(WitchPlugin *)plugin error:(NSError **)error;
- (void)markPluginIDInvalid:(NSString *)pluginID message:(NSString *)message;
- (NSDictionary *)settingsForPluginID:(NSString *)pluginID;
- (BOOL)setSettingValue:(id)value forKey:(NSString *)key pluginID:(NSString *)pluginID error:(NSError **)error;
- (BOOL)setThemeColors:(NSDictionary *)colors pluginID:(NSString *)pluginID error:(NSError **)error;
- (BOOL)trustKeyForPluginID:(NSString *)pluginID error:(NSError **)error;
- (void)noteRuntimeFailureForPluginID:(NSString *)pluginID;
- (void)noteRuntimeSuccessForPluginID:(NSString *)pluginID;
- (NSString *)markerPathForPluginID:(NSString *)pluginID;
- (void)recoverFromCrashMarkers;

@end

NS_ASSUME_NONNULL_END
