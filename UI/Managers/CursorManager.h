#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Quản lý các con trỏ chuột ảo.
/// Hỗ trợ pool chung (legacy) và pool riêng theo cursor type.
/// Mỗi con trỏ là một thư mục chứa ảnh (image.png hoặc image.gif)
/// và file hitbox.json lưu toạ độ hitbox (điểm "nóng" của con trỏ).
@interface CursorManager : NSObject

#pragma mark - Legacy shared pool (vẫn giữ để backward-compat)

+ (NSString *)cursorsDirectory;
+ (NSString *)defaultCursorName;
+ (BOOL)isDefaultCursor:(NSString *)name;
+ (NSArray<NSString *> *)cursorNames;
+ (NSString *)currentCursorName;
+ (void)setCurrentCursorName:(NSString *)name;
+ (UIImage *)imageForCursor:(NSString *)name;
+ (CGPoint)hitboxForCursor:(NSString *)name;
+ (void)setHitboxForCursor:(NSString *)name hitbox:(CGPoint)hitbox;
+ (BOOL)deleteCursor:(NSString *)name;
+ (nullable NSString *)importCursorFromURL:(NSURL *)url withName:(NSString *)name error:(NSError **)error;
+ (nullable NSString *)importCursorFromImage:(UIImage *)image withName:(NSString *)name error:(NSError **)error;
+ (CGRect)displayFrameForMouseFrame:(CGRect)mouseFrame;
+ (CGRect)mouseFrameForDisplayFrame:(CGRect)displayFrame;

#pragma mark - Per-type cursor pool

/// Thư mục cursors cho 1 type: Documents/cursor_types/{typeId}/
+ (NSString *)cursorsDirectoryForType:(NSString *)typeId;

/// Danh sách cursor names trong 1 type (luôn có "default" ở đầu).
+ (NSArray<NSString *> *)cursorNamesForType:(NSString *)typeId;

/// Cursor đang chọn cho 1 type (pref control.cursortype_{typeId}_cursor).
+ (NSString *)currentCursorForType:(NSString *)typeId;
+ (void)setCurrentCursor:(NSString *)cursorName forType:(NSString *)typeId;

/// Ảnh cursor trong 1 type (hỗ trợ PNG/GIF); default dùng MousePointer.
+ (UIImage *)imageForCursor:(NSString *)name inType:(NSString *)typeId;

/// Hitbox trong 1 type.
+ (CGPoint)hitboxForCursor:(NSString *)name inType:(NSString *)typeId;
+ (void)setHitboxForCursor:(NSString *)name hitbox:(CGPoint)hitbox inType:(NSString *)typeId;

/// Xoá cursor trong 1 type (không thể xoá "default").
+ (BOOL)deleteCursor:(NSString *)name inType:(NSString *)typeId;

/// Import cursor vào pool của 1 type.
+ (nullable NSString *)importCursorFromURL:(NSURL *)url withName:(NSString *)name forType:(NSString *)typeId error:(NSError **)error;
+ (nullable NSString *)importCursorFromImage:(UIImage *)image withName:(NSString *)name forType:(NSString *)typeId error:(NSError **)error;

#pragma mark - Composite image (cursor decoration)

/// Tạo ảnh composited: cursor shape mặc định làm nền + custom cursor overlay lên trên.
/// typeId xác định cursor shape nào dùng làm nền (arrow cho normal, hand cho link...).
+ (UIImage *)compositeImageForType:(NSString *)typeId;

/// Ảnh cursor shape mặc định cho từng type.
+ (nullable UIImage *)defaultShapeImageForType:(NSString *)typeId;

/// Calculate display frame for a specific cursor type (uses per-type cursor pool).
+ (CGRect)displayFrameForMouseFrame:(CGRect)mouseFrame typeId:(NSString *)typeId;

/// Convert display frame back to mouse frame for a specific cursor type.
+ (CGRect)mouseFrameForDisplayFrame:(CGRect)displayFrame typeId:(NSString *)typeId;

@end

NS_ASSUME_NONNULL_END
