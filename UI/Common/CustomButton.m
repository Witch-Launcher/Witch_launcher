#import "CustomButton.h"
#import "ThemeManager.h"

@implementation CustomButton

- (instancetype)initWithStyle:(CustomButtonStyle)style title:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _buttonStyle = style;
        _cornerRadius = 10.0;
        [self setTitle:title forState:UIControlStateNormal];
        [self setup];
        [self updateAppearance];
    }
    return self;
}

- (void)setup {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self addTarget:self action:@selector(didTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(didTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAppearance) name:ThemeDidChangeNotification object:nil];
}

- (void)updateAppearance {
    ThemeManager *theme = ThemeManager.shared;
    switch (self.buttonStyle) {
        case CustomButtonStylePrimary:
            self.backgroundColor = theme.accentColor;
            [self setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
            break;
        case CustomButtonStyleSecondary:
            self.backgroundColor = [UIColor clearColor];
            self.layer.borderWidth = 1.5;
            self.layer.borderColor = theme.accentColor.CGColor;
            [self setTitleColor:theme.accentColor forState:UIControlStateNormal];
            break;
        case CustomButtonStyleDestructive:
            self.backgroundColor = theme.errorColor;
            [self setTitleColor:[theme contrastTextColorForBackground:theme.errorColor] forState:UIControlStateNormal];
            break;
        case CustomButtonStyleGhost:
            self.backgroundColor = [UIColor clearColor];
            [self setTitleColor:theme.accentColor forState:UIControlStateNormal];
            break;
    }
    self.layer.cornerRadius = self.cornerRadius;
    self.clipsToBounds = YES;
}

- (void)didTouchDown {
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:nil];
}

- (void)didTouchUp {
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
