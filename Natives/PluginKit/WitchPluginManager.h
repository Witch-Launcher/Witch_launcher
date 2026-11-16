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
             sandboxPolicy:(WitchPluginSandboxPolicy)sandboxPolicy
               allowReplace:(BOOL)allowReplace
                       error:(NSError **)error;
- (BOOL)uninstallPluginID:(NSString *)pluginID error:(NSError **)error;
- (BOOL)setPluginID:(NSString *)pluginID enabled:(BOOL)enabled error:(NSError **)error;
- (BOOL)setPluginID:(NSString *)pluginID sandboxed:(BOOL)sandboxed error:(NSError **)error;
- (BOOL)sandboxEnabledForPluginID:(NSString *)pluginID;
- (nullable WitchPluginRiskReport *)riskReportForPluginID:(NSString *)pluginID;
- (BOOL)setSafeMode:(BOOL)safeMode error:(NSError **)error;
- (void)verifyPlugin:(WitchPlugin *)plugin completion:(nullable void (^)(BOOL verified, NSError * _Nullable error))completion;
- (void)verifyInstalledPlugins;
- (void)verifyPackageInfo:(NSDictionary *)info completion:(nullable void (^)(BOOL verified, NSError * _Nullable error))completion;
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
