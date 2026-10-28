#import "AmethystNoticePanel.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ThemeManager.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static __weak UIView *noticeCardView;

@implementation AmethystNoticeAction

+ (instancetype)primaryWithTitle:(NSString *)title handler:(void (^)(void))handler {
    AmethystNoticeAction *action = [self new];
    action->_title = title;
    action->_isPrimary = YES;
    action->_handler = handler;
    return action;
}

+ (instancetype)secondaryWithTitle:(NSString *)title handler:(void (^)(void))handler {
    AmethystNoticeAction *action = [self new];
    action->_title = title;
    action->_isPrimary = NO;
    action->_handler = handler;
    return action;
}

@end

@implementation AmethystNoticePanel

+ (instancetype)noticeWithTitle:(NSString *)title
                        message:(NSString *)message
                        actions:(NSArray<AmethystNoticeAction *> *)actions {
    AmethystNoticePanel *notice = [self new];
    notice.title = title;
    notice.message = message;
    notice.actions = actions;
    return notice;
}

+ (BOOL)isPresented {
    return noticeCardView != nil;
}

+ (void)presentInView:(UIView *)host notice:(AmethystNoticePanel *)notice {
    if (!host || !notice) return;
    // Replace whatever card is already up so notices never stack.
    [self dismiss];
    [HapticManager.shared play:HapticTypeWarning];

    ThemeManager *theme = ThemeManager.shared;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = theme.cardBackgroundColor;
    card.layer.cornerRadius = 18;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.35].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.28;
    card.layer.shadowRadius = 18;
    card.layer.shadowOffset = CGSizeMake(0, 8);
    [host addSubview:card];
    [AmethystBlurView installInView:card];
    noticeCardView = card;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:notice.iconSystemName ?: @"exclamationmark.triangle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = theme.accentColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    title.textColor = theme.primaryTextColor;
    title.numberOfLines = 1;
    title.text = notice.title;
    [card addSubview:title];

    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    message.textColor = theme.secondaryTextColor;
    message.numberOfLines = 0;
    message.text = notice.message;
    [card addSubview:message];

    // Buttons stack vertically at full width so long localized labels never
    // truncate.
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSMutableArray<AmethystNoticeAction *> *actions = [notice.actions mutableCopy];
    if (actions.count > 2) {
        actions = [actions subarrayWithRange:NSMakeRange(0, 2)].mutableCopy;
    }
    for (AmethystNoticeAction *action in actions) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.layer.cornerRadius = 12;
        button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        if (action.isPrimary) {
            button.backgroundColor = theme.accentColor;
            [button setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
        } else {
            button.layer.borderWidth = 1.5;
            button.layer.borderColor = theme.accentColor.CGColor;
            button.backgroundColor = UIColor.clearColor;
            [button setTitleColor:theme.accentColor forState:UIControlStateNormal];
        }
        if (action.title.length > 0) {
            [button setTitle:action.title forState:UIControlStateNormal];
        }
        // Tap = dismiss the card first, then run the handler.
        [button addTarget:self action:@selector(noticeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(button, "amethystNoticeAction", action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [card addSubview:button];
        [buttons addObject:button];
    }

    UILayoutGuide *safe = host.safeAreaLayoutGuide;
    // Preferred width 380, never wider than the screen edges, floor 260 so
    // the card stays readable even if the host has not been laid out yet.
    NSLayoutConstraint *wantWidth = [card.widthAnchor constraintEqualToConstant:380];
    wantWidth.priority = 999;
    NSLayoutConstraint *floorWidth = [card.widthAnchor constraintGreaterThanOrEqualToConstant:260];
    floorWidth.priority = 998;
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
        [card.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:host.leadingAnchor constant:16],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:host.trailingAnchor constant:-16],
        [card.widthAnchor constraintLessThanOrEqualToConstant:380],
        wantWidth,
        floorWidth,

        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [icon.widthAnchor constraintEqualToConstant:34],
        [icon.heightAnchor constraintEqualToConstant:34],

        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [message.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
    ]];
    if (buttons.count == 0) {
        [NSLayoutConstraint activateConstraints:@[
            [message.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        ]];
    } else {
        NSMutableArray<NSLayoutConstraint *> *layout = [NSMutableArray array];
        UIButton *previous = nil;
        for (UIButton *button in buttons) {
            [layout addObject:[button.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16]];
            [layout addObject:[button.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]];
            [layout addObject:[button.heightAnchor constraintEqualToConstant:44]];
            [layout addObject:[button.topAnchor constraintEqualToAnchor:(previous ?: message).bottomAnchor
                                                               constant:(previous ? 10 : 14)]];
            previous = button;
        }
        [layout addObject:[previous.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]];
        [NSLayoutConstraint activateConstraints:layout];
    }

    [host layoutIfNeeded];
    card.alpha = 0;
    card.transform = CGAffineTransformMakeTranslation(0, -(CGRectGetMaxY(card.frame) + 40));
    icon.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.45 delay:0.12 usingSpringWithDamping:0.55 initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        icon.transform = CGAffineTransformIdentity;
    } completion:nil];
}

+ (void)noticeButtonTapped:(UIButton *)sender {
    [self dismiss];
    AmethystNoticeAction *action = objc_getAssociatedObject(sender, "amethystNoticeAction");
    if (action.handler) action.handler();
}

+ (void)dismiss {
    UIView *card = noticeCardView;
    if (!card) return;
    noticeCardView = nil;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        card.alpha = 0;
        card.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -120),
                                                 CGAffineTransformMakeScale(0.92, 0.92));
    } completion:^(BOOL finished) {
        [card removeFromSuperview];
    }];
}

@end
