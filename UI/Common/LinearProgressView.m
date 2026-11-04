#import "LinearProgressView.h"
#import "ThemeManager.h"

@interface LinearProgressView ()
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) NSLayoutConstraint *fillLeadingConstraint;
@property (nonatomic) CGFloat fillWidth;
@end

@implementation LinearProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 4;
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor clearColor];

        _trackView = [[UIView alloc] init];
        _trackView.translatesAutoresizingMaskIntoConstraints = NO;
        _trackView.layer.cornerRadius = 4;
        _trackView.layer.masksToBounds = YES;
        _trackView.backgroundColor = ThemeManager.shared.separatorColor;
        [self addSubview:_trackView];

        _fillView = [[UIView alloc] init];
        _fillView.translatesAutoresizingMaskIntoConstraints = NO;
        _fillView.layer.cornerRadius = 4;
        _fillView.layer.masksToBounds = YES;
        _fillView.backgroundColor = ThemeManager.shared.accentColor;
        [self addSubview:_fillView];

        [NSLayoutConstraint activateConstraints:@[
            [_trackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_trackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_trackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_trackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        _fillWidth = 96.0f;
        self.fillLeadingConstraint = [_fillView.leadingAnchor constraintEqualToAnchor:_trackView.leadingAnchor];
        [NSLayoutConstraint activateConstraints:@[
            self.fillLeadingConstraint,
            [_fillView.widthAnchor constraintEqualToConstant:_fillWidth],
            [_fillView.topAnchor constraintEqualToAnchor:_trackView.topAnchor],
            [_fillView.bottomAnchor constraintEqualToAnchor:_trackView.bottomAnchor],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateColors {
    _trackView.backgroundColor = ThemeManager.shared.separatorColor;
    _fillView.backgroundColor = ThemeManager.shared.accentColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_fillWidth > self.trackView.bounds.size.width) {
        _fillWidth = self.trackView.bounds.size.width * 0.6f;
        self.fillLeadingConstraint.constant = 0;
        [self layoutIfNeeded];
    }
}

- (void)startAnimating {
    if (_animating) return;
    _animating = YES;
    self.fillLeadingConstraint.constant = 0;
    [self layoutIfNeeded];
    self.fillLeadingConstraint.constant = self.trackView.bounds.size.width - _fillWidth;
    [UIView animateWithDuration:1.6
                          delay:0
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         [self layoutIfNeeded];
                     } completion:nil];
}

- (void)stopAnimating {
    _animating = NO;
    [_fillView.layer removeAllAnimations];
    self.fillLeadingConstraint.constant = 0;
    [self layoutIfNeeded];
}

@end
