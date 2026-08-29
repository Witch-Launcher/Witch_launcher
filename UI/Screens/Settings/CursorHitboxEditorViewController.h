#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Màn hình chọn toạ độ hitbox (điểm "nóng") cho một con trỏ chuột.
/// Hỗ trợ cả legacy shared pool và per-type cursor pool.
@interface CursorHitboxEditorViewController : UIViewController

@property (nonatomic, strong) NSString *cursorName;
@property (nonatomic, copy, nullable) NSString *typeId; // nil = legacy shared pool

@end

NS_ASSUME_NONNULL_END
