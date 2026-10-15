#import "AppErrorDialog.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import <objc/runtime.h>

@interface UIView (AppErrorDialogTap)
- (void)appErrorDialog_primaryTapped;
- (void)appErrorDialog_secondaryTapped;
@end

@implementation AppErrorDialog

+ (AppErrorKind)kindForLegacyTitle:(NSString *)title {
    NSString *t = title.lowercaseString ?: @"";
    if ([t containsString:@"success"] || [t containsString:@"done"] || [t containsString:@"thành công"]) {
        return AppErrorKindSuccess;
    }
    if ([t containsString:@"warn"] || [t containsString:@"cảnh báo"] || [t containsString:@"not purchased"] ||
        [t containsString:@"partial"] || [t containsString:@"incompatible"] || [t containsString:@"outdated"]) {
        return AppErrorKindWarning;
    }
    if ([t containsString:@"error"] || [t containsString:@"fail"] || [t containsString:@"missing"] ||
        [t containsString:@"required"] || [t containsString:@"no "] || [t containsString:@"network"] ||
        [t containsString:@"lỗi"] || [t containsString:@"thiếu"]) {
        return AppErrorKindError;
    }
    return AppErrorKindInfo;
}

+ (void)presentLegacyTitle:(NSString *)title message:(NSString *)message {
    [self presentWithKind:[self kindForLegacyTitle:title] title:title message:message];
}

+ (void)presentWithKind:(AppErrorKind)kind title:(NSString *)title message:(NSString *)message {
    [self presentWithKind:kind title:title message:message primaryTitle:nil secondaryTitle:nil onPrimary:nil onSecondary:nil];
}

+ (NSString *)iconNameForKind:(AppErrorKind)kind {
    switch (kind) {
        case AppErrorKindError: return @"xmark.octagon.fill";
        case AppErrorKindWarning: return @"exclamationmark.triangle.fill";
        case AppErrorKindSuccess: return @"checkmark.circle.fill";
        case AppErrorKindInfo:
        default: return @"info.circle.fill";
    }
}

+ (UIColor *)colorForKind:(AppErrorKind)kind theme:(ThemeManager *)theme {
    switch (kind) {
        case AppErrorKindError: return theme.errorColor;
        case AppErrorKindWarning: return theme.warningColor;
        case AppErrorKindSuccess: return theme.successColor;
        case AppErrorKindInfo:
        default: return theme.accentColor;
    }
}

+ (void)presentWithKind:(AppErrorKind)kind
                 title:(NSString *)title
               message:(NSString *)message
          primaryTitle:(NSString *)primaryTitle
        secondaryTitle:(NSString *)secondaryTitle
             onPrimary:(void(^)(void))onPrimary
           onSecondary:(void(^)(void))onSecondary {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Dedicated window above everything (alerts, pickers, sheets):
        // windowLevel Alert+1 always wins regardless of the present stack.
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) return;
        UIWindow *prevKey = nil;
        for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) { prevKey = w; break; }
        }
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = [UIColor clearColor];
        UIViewController *host = [[UIViewController alloc] init];
        host.view.backgroundColor = [UIColor clearColor];
        window.rootViewController = host;
        [window makeKeyAndVisible];
        // Retain while visible; released on dismiss.
        objc_setAssociatedObject(host, "errorDialogWindow", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (prevKey) objc_setAssociatedObject(host, "errorDialogPrevKey", prevKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *root = host.view;

        ThemeManager *theme = ThemeManager.shared;
        UIColor *accent = [self colorForKind:kind theme:theme];

        // Haptic per kind (Error/Warning/Success were wired but never played before)
        if (kind == AppErrorKindError) [HapticManager.shared play:HapticTypeError];
        else if (kind == AppErrorKindWarning) [HapticManager.shared play:HapticTypeWarning];
        else if (kind == AppErrorKindSuccess) [HapticManager.shared play:HapticTypeSuccess];
        else [HapticManager.shared play:HapticTypeLight];

        UIView *overlay = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [root addSubview:overlay];
        // Pin to host edges so rotation is handled.
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [overlay.topAnchor constraintEqualToAnchor:root.topAnchor],
            [overlay.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
            [overlay.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
            [overlay.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        ]];

        UIView *dim = [[UIView alloc] init];
        dim.translatesAutoresizingMaskIntoConstraints = NO;
        dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30];
        [overlay addSubview:dim];
        [AmethystBlurView installInView:overlay];

        UIView *card = [[UIView alloc] init];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = [theme.cardBackgroundColor colorWithAlphaComponent:0.92];
        card.layer.cornerRadius = 16;
        card.layer.borderWidth = 1;
        card.layer.borderColor = [accent colorWithAlphaComponent:0.45].CGColor;
        card.clipsToBounds = YES;
        [overlay addSubview:card];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        UIImage *icon = [UIImage systemImageNamed:[self iconNameForKind:kind]];
        iconView.image = icon;
        iconView.tintColor = accent;
        iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightSemibold];
        [card addSubview:iconView];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        titleLabel.textColor = theme.primaryTextColor;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.text = title.length ? title : @"Notice";
        titleLabel.numberOfLines = 0;
        [card addSubview:titleLabel];

        UILabel *msgLabel = [[UILabel alloc] init];
        msgLabel.translatesAutoresizingMaskIntoConstraints = NO;
        msgLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        msgLabel.textColor = theme.secondaryTextColor;
        msgLabel.textAlignment = NSTextAlignmentCenter;
        msgLabel.text = message ?: @"";
        msgLabel.numberOfLines = 0;
        [card addSubview:msgLabel];

        UIButton *primaryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        primaryBtn.translatesAutoresizingMaskIntoConstraints = NO;
        primaryBtn.backgroundColor = accent;
        primaryBtn.layer.cornerRadius = 10;
        [primaryBtn setTitle:(primaryTitle.length ? primaryTitle : @"OK") forState:UIControlStateNormal];
        [primaryBtn setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
        primaryBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [card addSubview:primaryBtn];

        UIButton *secondaryBtn = nil;
        if (secondaryTitle.length > 0) {
            secondaryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            secondaryBtn.translatesAutoresizingMaskIntoConstraints = NO;
            secondaryBtn.backgroundColor = [UIColor clearColor];
            secondaryBtn.layer.cornerRadius = 10;
            secondaryBtn.layer.borderWidth = 1;
            secondaryBtn.layer.borderColor = accent.CGColor;
            [secondaryBtn setTitle:secondaryTitle forState:UIControlStateNormal];
            [secondaryBtn setTitleColor:accent forState:UIControlStateNormal];
            secondaryBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            [card addSubview:secondaryBtn];
        }

        NSMutableArray *constraints = [NSMutableArray arrayWithObjects:
            [dim.topAnchor constraintEqualToAnchor:overlay.topAnchor],
            [dim.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],
            [dim.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
            [dim.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
            [card.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
            [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
            [card.widthAnchor constraintLessThanOrEqualToConstant:330],
            [card.widthAnchor constraintLessThanOrEqualToAnchor:overlay.widthAnchor constant:-48],
            [iconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
            [iconView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
            [iconView.widthAnchor constraintEqualToConstant:34],
            [iconView.heightAnchor constraintEqualToConstant:34],
            [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:10],
            [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
            [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
            [msgLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
            [msgLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
            [msgLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
            [primaryBtn.topAnchor constraintGreaterThanOrEqualToAnchor:msgLabel.bottomAnchor constant:14],
            [primaryBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [primaryBtn.heightAnchor constraintEqualToConstant:42],
            [primaryBtn.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
            nil];
        if (secondaryBtn) {
            [constraints addObjectsFromArray:@[
                [primaryBtn.trailingAnchor constraintEqualToAnchor:card.centerXAnchor constant:-6],
                [secondaryBtn.topAnchor constraintEqualToAnchor:primaryBtn.topAnchor],
                [secondaryBtn.leadingAnchor constraintEqualToAnchor:card.centerXAnchor constant:6],
                [secondaryBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
                [secondaryBtn.heightAnchor constraintEqualToAnchor:primaryBtn.heightAnchor],
                [secondaryBtn.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
            ]];
        } else {
            [constraints addObject:[primaryBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]];
        }
        [NSLayoutConstraint activateConstraints:constraints];

        // Hide message label spacing when empty
        if (!message.length) {
            msgLabel.hidden = YES;
        }

        overlay.alpha = 0;
        card.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            overlay.alpha = 1;
            card.transform = CGAffineTransformIdentity;
        } completion:nil];

        void (^dismiss)(void) = ^{
            [UIView animateWithDuration:0.16 animations:^{
                overlay.alpha = 0;
            } completion:^(BOOL finished) {
                [overlay removeFromSuperview];
            }];
        };
        // Retain blocks via associated objects on overlay
        if (onPrimary) objc_setAssociatedObject(overlay, "onPrimary", [onPrimary copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        if (onSecondary) objc_setAssociatedObject(overlay, "onSecondary", [onSecondary copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [primaryBtn addTarget:overlay action:@selector(appErrorDialog_primaryTapped) forControlEvents:UIControlEventTouchUpInside];
        [secondaryBtn addTarget:overlay action:@selector(appErrorDialog_secondaryTapped) forControlEvents:UIControlEventTouchUpInside];
        (void)dismiss;
    });
}

@end

@implementation UIView (AppErrorDialogTap)

- (void)appErrorDialog_teardownWindow {
    // overlay -> host.view -> host: walk up to the host view controller.
    UIView *v = self;
    while (v.superview) v = v.superview;
    UIResponder *r = v.nextResponder;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = r.nextResponder;
    UIViewController *host = (UIViewController *)r;
    UIWindow *window = objc_getAssociatedObject(host, "errorDialogWindow");
    UIWindow *prevKey = objc_getAssociatedObject(host, "errorDialogPrevKey");
    [self removeFromSuperview];
    if (window) {
        window.hidden = YES;
        objc_setAssociatedObject(host, "errorDialogWindow", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (prevKey) [prevKey makeKeyAndVisible];
}

- (void)appErrorDialog_primaryTapped {
    void (^cb)(void) = objc_getAssociatedObject(self, "onPrimary");
    [UIView animateWithDuration:0.16 animations:^{ self.alpha = 0; } completion:^(BOOL f) {
        [self appErrorDialog_teardownWindow];
        if (cb) cb();
    }];
}

- (void)appErrorDialog_secondaryTapped {
    void (^cb)(void) = objc_getAssociatedObject(self, "onSecondary");
    [UIView animateWithDuration:0.16 animations:^{ self.alpha = 0; } completion:^(BOOL f) {
        [self appErrorDialog_teardownWindow];
        if (cb) cb();
    }];
}

@end
