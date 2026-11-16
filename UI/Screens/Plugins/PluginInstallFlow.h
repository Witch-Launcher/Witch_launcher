#import <UIKit/UIKit.h>
#import "WitchPluginRisk.h"

NS_ASSUME_NONNULL_BEGIN

@class WitchPluginCatalogEntry;

// Shared install pipeline: verify the package, show what the plugin is going
// to do and install it. A plugin without findings is installed right away, a
// plugin that needs attention or is dangerous is shown first and the user
// decides.
@interface PluginInstallFlow : NSObject

@property (class, readonly) PluginInstallFlow *shared;

- (void)installCatalogEntry:(WitchPluginCatalogEntry *)entry
        fromViewController:(UIViewController *)viewController;
- (void)presentInstallForPackageURL:(NSURL *)packageURL
                                info:(NSDictionary *)info
                                risk:(nullable WitchPluginRiskReport *)risk
                             isUpdate:(BOOL)isUpdate
                   fromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
