#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppErrorDialog.h"

NS_ASSUME_NONNULL_BEGIN

// Global error / validation presenter for the whole launcher.
// Every missing-field / missing-account / missing-version / IO failure should go
// through here so dialogs look, sound and behave the same everywhere.
@interface ErrorPresenter : NSObject

+ (void)showError:(nullable NSString *)title message:(nullable NSString *)message;
+ (void)showWarning:(nullable NSString *)title message:(nullable NSString *)message;
+ (void)showInfo:(nullable NSString *)title message:(nullable NSString *)message;
+ (void)showSuccess:(nullable NSString *)title message:(nullable NSString *)message;

// Common launcher validations (with haptic + icon + optional action button)
+ (void)showMissingAccountWithAction:(nullable void(^)(void))openAccounts;
+ (void)showDemoAccount;
+ (void)showMissingVersion;
+ (void)showValidation:(nullable NSString *)field message:(nullable NSString *)message;
+ (void)showNetworkError:(nullable NSError *)error message:(nullable NSString *)fallback;
+ (void)showFileError:(nullable NSString *)action path:(nullable NSString *)path error:(nullable NSError *)error;
+ (void)showWithKind:(AppErrorKind)kind
               title:(nullable NSString *)title
             message:(nullable NSString *)message
        primaryTitle:(nullable NSString *)primaryTitle
      secondaryTitle:(nullable NSString *)secondaryTitle
           onPrimary:(nullable void(^)(void))onPrimary
         onSecondary:(nullable void(^)(void))onSecondary;

// Non-modal toast: small floating label that fades by itself.
// Never steals the key window, so it can never freeze the UI.
+ (void)showToast:(nullable NSString *)message;
+ (void)showToast:(nullable NSString *)message success:(BOOL)success;

@end

NS_ASSUME_NONNULL_END
