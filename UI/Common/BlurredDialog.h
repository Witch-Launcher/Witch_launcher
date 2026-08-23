#import <UIKit/UIKit.h>

// A frosted-glass replacement for system UIAlertController info dialogs.
// The blur is REALTIME (samples everything rendered behind the window).
@interface BlurredDialog : NSObject

+ (void)presentInWindow:(UIWindow *)window
                  title:(NSString *)title
                message:(NSString *)message
                okTitle:(NSString *)okTitle;

@end
