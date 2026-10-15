#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AppErrorKind) {
    AppErrorKindError = 0,
    AppErrorKindWarning,
    AppErrorKindInfo,
    AppErrorKindSuccess
};

// Frosted-glass global dialog. SF Symbols template icons only (tintable via
// ThemeManager) — no sticker images, no emoji glyphs, no SVG dependency.
@interface AppErrorDialog : NSObject

+ (void)presentWithKind:(AppErrorKind)kind
                 title:(nullable NSString *)title
               message:(nullable NSString *)message;

+ (void)presentWithKind:(AppErrorKind)kind
                 title:(nullable NSString *)title
               message:(nullable NSString *)message
          primaryTitle:(nullable NSString *)primaryTitle
        secondaryTitle:(nullable NSString *)secondaryTitle
             onPrimary:(nullable void(^)(void))onPrimary
           onSecondary:(nullable void(^)(void))onSecondary;

// Back-compat shim: old showDialog(title, message) routes here.
+ (void)presentLegacyTitle:(nullable NSString *)title message:(nullable NSString *)message;

+ (AppErrorKind)kindForLegacyTitle:(nullable NSString *)title;

@end

NS_ASSUME_NONNULL_END
