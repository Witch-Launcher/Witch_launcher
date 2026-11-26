#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Vẽ bộ con trỏ mặc định bằng vector (UIBezierPath) ở đúng kích thước pixel.
/// Toạ độ path dùng viewBox riêng của từng kiểu; renderer tự scale sang size.
@interface CursorShapeRenderer : NSObject

+ (BOOL)hasShapeForType:(NSString *)typeId;
+ (CGSize)viewBoxSizeForType:(NSString *)typeId;
+ (void)setDiagonalUsesNESW:(BOOL)useNESW;

/// Ảnh có size tính bằng point và scale là hệ số pixel.
/// Ví dụ size 27x37.8, scale 3 -> 81x113 px.
+ (nullable UIImage *)imageForType:(NSString *)typeId size:(CGSize)size scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
