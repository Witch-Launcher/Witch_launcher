#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WitchPluginRuntime : NSObject

@property (class, readonly) WitchPluginRuntime *shared;

- (void)loadEnabledPlugins;
- (nullable UIViewController *)createCustomRootViewController;

@end

NS_ASSUME_NONNULL_END
