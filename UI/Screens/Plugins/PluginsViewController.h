#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PluginsViewController : UIViewController

+ (BOOL)handleIncomingURL:(NSURL *)url presenter:(nullable UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
