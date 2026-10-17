#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Launcher-styled bottom sheets replacing UIAlertController action sheets,
// alerts, confirms and text prompts. Frosted card, spring slide-up,
// SF-symbol icons (tintable), haptics, safe-area aware, drag-to-dismiss.
// Shown in a dedicated non-key window above everything (same pattern as
// AppErrorDialog), so sheets work from any stack without touching key status.
@interface AppSheet : NSObject

// Option list. Each option: @{@"title":NSString,
//                             @"subtitle":NSString (optional),
//                             @"icon":NSString SF symbol name (optional),
//                             @"destructive":NSNumber BOOL (optional)}.
// selectedIndex: NSNotFound for none (shows checkmark when >= 0).
+ (void)showOptionsWithTitle:(nullable NSString *)title
                     message:(nullable NSString *)message
                     options:(NSArray<NSDictionary *> *)options
               selectedIndex:(NSInteger)selectedIndex
                   selection:(nullable void(^)(NSInteger index))selection;

+ (void)showOptionsWithTitle:(nullable NSString *)title
                     message:(nullable NSString *)message
                     options:(NSArray<NSDictionary *> *)options
               selectedIndex:(NSInteger)selectedIndex
                   selection:(nullable void(^)(NSInteger index))selection
                      cancel:(nullable void(^)(void))cancel;

// Confirm dialog with Confirm/Cancel buttons.
+ (void)showConfirmWithTitle:(nullable NSString *)title
                     message:(nullable NSString *)message
                confirmTitle:(nullable NSString *)confirmTitle
                 destructive:(BOOL)destructive
                   onConfirm:(nullable void(^)(void))onConfirm;

// Text prompt with one field.
+ (void)showPromptWithTitle:(nullable NSString *)title
                    message:(nullable NSString *)message
                placeholder:(nullable NSString *)placeholder
                initialText:(nullable NSString *)text
                  onConfirm:(nullable void(^)(NSString *text))onConfirm;

// Text prompt with two fields (e.g. name + address).
+ (void)showPrompt2WithTitle:(nullable NSString *)title
                     message:(nullable NSString *)message
            placeholder1:(nullable NSString *)placeholder1
            placeholder2:(nullable NSString *)placeholder2
                   onConfirm:(nullable void(^)(NSString *text1, NSString *text2))onConfirm;

@end

NS_ASSUME_NONNULL_END
