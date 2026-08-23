#import "BlurredDialog.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"

@implementation BlurredDialog

+ (void)presentInWindow:(UIWindow *)window
                  title:(NSString *)title
                message:(NSString *)message
                okTitle:(NSString *)okTitle {
    if (!window) return;
    UIView *root = window.rootViewController.view;
    if (!root) return;

    ThemeManager *theme = ThemeManager.shared;

    UIView *overlay = [[UIView alloc] initWithFrame:root.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root addSubview:overlay];

    // Dim + realtime frost over the whole window
    UIView *dim = [[UIView alloc] init];
    dim.translatesAutoresizingMaskIntoConstraints = NO;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30];
    [overlay addSubview:dim];
    [AmethystBlurView installInView:overlay];

    // Card
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [theme.cardBackgroundColor colorWithAlphaComponent:0.82];
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.45].CGColor;
    card.clipsToBounds = YES;
    [overlay addSubview:card];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    titleLabel.textColor = theme.primaryTextColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = title ?: @"";
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

    UIButton *okBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    okBtn.translatesAutoresizingMaskIntoConstraints = NO;
    okBtn.backgroundColor = theme.accentColor;
    okBtn.layer.cornerRadius = 10;
    [okBtn setTitle:(okTitle.length ? okTitle : @"OK") forState:UIControlStateNormal];
    [okBtn setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
    okBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [card addSubview:okBtn];

    [NSLayoutConstraint activateConstraints:@[
        [dim.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [dim.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],
        [dim.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [dim.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],

        [card.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToConstant:320],
        [card.widthAnchor constraintLessThanOrEqualToAnchor:overlay.widthAnchor constant:-48],

        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [msgLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [msgLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [msgLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [okBtn.topAnchor constraintGreaterThanOrEqualToAnchor:msgLabel.bottomAnchor constant:14],
        [okBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [okBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [okBtn.heightAnchor constraintEqualToConstant:40],
        [okBtn.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    // Appear animation
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
    [okBtn addTarget:overlay action:@selector(removeFromSuperview) forControlEvents:UIControlEventTouchUpInside];
    (void)dismiss;
}

@end
