#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Notification posted when the active cursor type changes (from game JNI call).
/// userInfo keys: @"typeId" (NSString), @"cursorName" (NSString)
extern NSString *const CursorTypeDidChangeNotification;

/// Cursor type identifier keys (stored in NSDictionary definitions)
extern NSString *const kCursorTypeId;
extern NSString *const kCursorTypeName;
extern NSString *const kCursorTypeDescription;
extern NSString *const kCursorTypeIcon;
extern NSString *const kCursorTypeGLFWConstant;
extern NSString *const kCursorTypeSDLConstant;

/// Manages cursor type definitions, enable/disable state, per-type cursor selection,
/// and handles cursor shape changes from the game (via GLFW/SDL3 JNI calls).
@interface CursorTypeManager : NSObject

+ (instancetype)shared;

/// All 12 cursor type definitions (array of NSDictionary).
+ (NSArray<NSDictionary *> *)allCursorTypes;

#pragma mark - Master toggle

/// Master toggle: ON = auto-switch cursor types per game request, OFF = always normal.
+ (BOOL)isMasterToggleEnabled;
+ (void)setMasterToggleEnabled:(BOOL)enabled;

#pragma mark - Per-type enable/disable

+ (BOOL)isEnabledForType:(NSString *)typeId;
+ (void)setEnabled:(BOOL)enabled forType:(NSString *)typeId;

#pragma mark - Per-type cursor assignment (delegates to CursorManager per-type pool)

+ (NSString *)cursorForType:(NSString *)typeId;
+ (void)setCursor:(NSString *)cursorName forType:(NSString *)typeId;

#pragma mark - Shape mapping

+ (nullable NSString *)typeIdForGLFWShape:(int)shape;
+ (nullable NSString *)typeIdForSDLShape:(int)shape;

#pragma mark - Cursor shape handling (called from JNI)

+ (void)handleCursorShapeChange:(int)shape isSDL3:(BOOL)isSDL3;

/// Manually set cursor to hidden (e.g., when game hides cursor via glfwSetCursor(window, NULL))
+ (void)setCursorHidden:(BOOL)hidden;

#pragma mark - Display

/// Get the composited image for a cursor type (custom overlay on default shape).
+ (UIImage *)imageForType:(NSString *)typeId;

/// Get the localized display name for a cursor type.
+ (NSString *)localizedNameForType:(NSString *)typeId;

/// Get the current active type ID (last one set by the game), or @"normal" if none.
+ (NSString *)currentActiveTypeId;

@end

NS_ASSUME_NONNULL_END
