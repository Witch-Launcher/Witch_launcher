#import "ErrorPresenter.h"
#import "HapticManager.h"
#import "utils.h"

@implementation ErrorPresenter

+ (void)showToast:(NSString *)message {
    [self showToast:message success:YES];
}

+ (void)showToast:(NSString *)message success:(BOOL)success {
    if (!message.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) return;
        UIWindow *host = nil;
        for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) { host = w; break; }
        }
        if (!host) host = scene.windows.firstObject;
        if (!host) return;
        [HapticManager.shared play:success ? HapticTypeSuccess : HapticTypeWarning];

        UILabel *toast = [[UILabel alloc] init];
        toast.text = message;
        toast.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        toast.textColor = UIColor.whiteColor;
        toast.textAlignment = NSTextAlignmentCenter;
        toast.numberOfLines = 2;
        toast.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
        toast.layer.cornerRadius = 14;
        toast.clipsToBounds = YES;
        toast.alpha = 0;
        toast.translatesAutoresizingMaskIntoConstraints = NO;
        [host.rootViewController.view addSubview:toast];
        [NSLayoutConstraint activateConstraints:@[
            [toast.centerXAnchor constraintEqualToAnchor:host.rootViewController.view.centerXAnchor],
            [toast.bottomAnchor constraintEqualToAnchor:host.rootViewController.view.safeAreaLayoutGuide.bottomAnchor constant:-90],
            [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:host.rootViewController.view.leadingAnchor constant:40],
            [toast.trailingAnchor constraintLessThanOrEqualToAnchor:host.rootViewController.view.trailingAnchor constant:-40],
        ]];
        [UIView animateWithDuration:0.25 animations:^{ toast.alpha = 1; } completion:^(BOOL f) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; } completion:^(BOOL f2) {
                    [toast removeFromSuperview];
                }];
            });
        }];
    });
}

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
