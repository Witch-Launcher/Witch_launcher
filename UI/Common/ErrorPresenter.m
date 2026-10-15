#import "ErrorPresenter.h"
#import "utils.h"

@implementation ErrorPresenter

+ (void)showWithKind:(AppErrorKind)kind
               title:(NSString *)title
             message:(NSString *)message
        primaryTitle:(NSString *)primaryTitle
      secondaryTitle:(NSString *)secondaryTitle
           onPrimary:(void(^)(void))onPrimary
         onSecondary:(void(^)(void))onSecondary {
    NSString *t = title.length ? localize(title, nil) : title;
    // localize() passes dynamic content (names, paths, versions) through untouched,
    // so it is safe to run even on already-localized strings.
    NSString *m = message.length ? localize(message, nil) : message;
    NSString *p = primaryTitle.length ? localize(primaryTitle, nil) : primaryTitle;
    NSString *s = secondaryTitle.length ? localize(secondaryTitle, nil) : secondaryTitle;
    [AppErrorDialog presentWithKind:kind title:t message:m primaryTitle:p secondaryTitle:s onPrimary:onPrimary onSecondary:onSecondary];
}

+ (void)showError:(NSString *)title message:(NSString *)message {
    [self showWithKind:AppErrorKindError title:title ?: @"Error" message:message primaryTitle:@"OK" secondaryTitle:nil onPrimary:nil onSecondary:nil];
}

+ (void)showWarning:(NSString *)title message:(NSString *)message {
    [self showWithKind:AppErrorKindWarning title:title ?: @"Warning" message:message primaryTitle:@"OK" secondaryTitle:nil onPrimary:nil onSecondary:nil];
}

+ (void)showInfo:(NSString *)title message:(NSString *)message {
    [self showWithKind:AppErrorKindInfo title:title ?: @"Notice" message:message primaryTitle:@"OK" secondaryTitle:nil onPrimary:nil onSecondary:nil];
}

+ (void)showSuccess:(NSString *)title message:(NSString *)message {
    [self showWithKind:AppErrorKindSuccess title:title ?: @"Done" message:message primaryTitle:@"OK" secondaryTitle:nil onPrimary:nil onSecondary:nil];
}

+ (void)showMissingAccountWithAction:(void(^)(void))openAccounts {
    if (openAccounts) {
        [self showWithKind:AppErrorKindError
                     title:@"Account Required"
                   message:@"Please add and select an account first."
              primaryTitle:@"Accounts"
            secondaryTitle:@"Cancel"
                 onPrimary:openAccounts
               onSecondary:nil];
    } else {
        [self showError:@"Account Required" message:@"Please add and select an account first."];
    }
}

+ (void)showDemoAccount {
    [self showWarning:@"Minecraft Not Purchased"
              message:@"Your Microsoft account has not purchased Minecraft. Please purchase the game from minecraft.net to play."];
}

+ (void)showMissingVersion {
    [self showError:@"No Version" message:@"Please select a version from the sidebar first."];
}

+ (void)showValidation:(NSString *)field message:(NSString *)message {
    NSString *msg = message;
    if (!msg.length && field.length) {
        msg = [NSString stringWithFormat:@"Please enter %@.", field];
    }
    [self showError:@"Missing Information" message:msg ?: @"Please fill in the required field."];
}

+ (void)showNetworkError:(NSError *)error message:(NSString *)fallback {
    NSString *msg = error.localizedDescription.length ? error.localizedDescription : fallback;
    [self showError:@"Network Error" message:msg ?: @"Request failed. Check your connection and try again."];
}

+ (void)showFileError:(NSString *)action path:(NSString *)path error:(NSError *)error {
    NSString *detail = error.localizedDescription ?: @"Unknown error";
    NSString *msg = [NSString stringWithFormat:@"%@%@: %@",
                     action ?: @"File operation failed",
                     (path.length ? [NSString stringWithFormat:@" (%@)", path.lastPathComponent] : @""),
                     detail];
    [self showError:@"File Error" message:msg];
}

@end
