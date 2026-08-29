#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Detail page cho 1 cursor type: toggle enable/disable, upload cursor, chọn cursor từ pool, edit hitbox.
@interface CursorTypeDetailViewController : UIViewController

@property (nonatomic, copy) NSString *typeId;

@end

NS_ASSUME_NONNULL_END
