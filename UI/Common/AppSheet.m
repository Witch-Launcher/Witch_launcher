#import "AppSheet.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, AppSheetMode) {
    AppSheetModeOptions = 0,
    AppSheetModeConfirm,
    AppSheetModePrompt,
    AppSheetModePrompt2,
};

@interface AppSheetHostVC : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic) AppSheetMode mode;
@property (nonatomic, copy) NSString *sheetTitle;
@property (nonatomic, copy) NSString *sheetMessage;
@property (nonatomic) NSArray<NSDictionary *> *options;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic, copy) void(^onSelect)(NSInteger);
@property (nonatomic, copy) void(^onCancel)(void);
@property (nonatomic, copy) void(^onConfirmAction)(void);
@property (nonatomic, copy) void(^onPromptConfirm)(NSString *);
@property (nonatomic, copy) void(^onPrompt2Confirm)(NSString *, NSString *);
@property (nonatomic) NSString *confirmTitle;
@property (nonatomic) BOOL destructive;
@property (nonatomic) NSString *placeholder;
@property (nonatomic) NSString *placeholder2;
@property (nonatomic) NSString *initialText;
@property (nonatomic) UITextField *textField2;
@property (nonatomic) UIView *dimView;
@property (nonatomic) UIView *cardView;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UITextField *textField;
@property (nonatomic) BOOL didAnimateEntrance;
@end

@implementation AppSheetHostVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    ThemeManager *theme = ThemeManager.shared;

    _dimView = [[UIView alloc] init];
    _dimView.translatesAutoresizingMaskIntoConstraints = NO;
    _dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    _dimView.alpha = 0;
    [_dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissCancelled)]];
    [self.view addSubview:_dimView];

    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [theme.cardBackgroundColor colorWithAlphaComponent:0.96];
    _cardView.layer.cornerRadius = 22;
    _cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    _cardView.clipsToBounds = YES;
    _cardView.layer.borderWidth = 1;
    _cardView.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.30].CGColor;
    [self.view addSubview:_cardView];
    [AmethystBlurView installInView:_cardView];

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [theme.secondaryTextColor colorWithAlphaComponent:0.4];
    grabber.layer.cornerRadius = 2.5;
    [_cardView addSubview:grabber];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_cardView addGestureRecognizer:pan];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLabel.textColor = theme.primaryTextColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.text = _sheetTitle;
    titleLabel.hidden = (_sheetTitle.length == 0);
    [_cardView addSubview:titleLabel];

    UILabel *msgLabel = [[UILabel alloc] init];
    msgLabel.translatesAutoresizingMaskIntoConstraints = NO;
    msgLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    msgLabel.textColor = theme.secondaryTextColor;
    msgLabel.textAlignment = NSTextAlignmentCenter;
    msgLabel.numberOfLines = 0;
    msgLabel.text = _sheetMessage;
    msgLabel.hidden = (_sheetMessage.length == 0);
    [_cardView addSubview:msgLabel];

    NSMutableArray *c = [NSMutableArray arrayWithObjects:
        [_dimView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_dimView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_dimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_dimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [grabber.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:8],
        [grabber.centerXAnchor constraintEqualToAnchor:_cardView.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:40],
        [grabber.heightAnchor constraintEqualToConstant:5],
        [titleLabel.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:10],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-20],
        [msgLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [msgLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:20],
        [msgLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-20],
        nil];
    UIView *lastView = msgLabel;
    if (_sheetTitle.length == 0 && _sheetMessage.length == 0) {
        // Anchor content directly under the grabber.
        lastView = grabber;
    }

    if (_mode == AppSheetModeOptions) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.translatesAutoresizingMaskIntoConstraints = NO;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.rowHeight = 54;
        _tableView.showsVerticalScrollIndicator = NO;
        [_cardView addSubview:_tableView];
        CGFloat tableH = MIN(_options.count * 54, 340);
        UIView *cancelBtn = [self makeButtonWithTitle:@"Cancel" primary:NO destructive:NO action:@selector(dismissCancelled)];
        [_cardView addSubview:cancelBtn];
        cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutAnchor *contentTop = ([lastView isEqual:grabber] ? (NSLayoutAnchor *)grabber.bottomAnchor : ([lastView isEqual:msgLabel] && _sheetMessage.length > 0 ? (NSLayoutAnchor *)msgLabel.bottomAnchor : (NSLayoutAnchor *)titleLabel.bottomAnchor));
        [c addObjectsFromArray:@[
            [_tableView.topAnchor constraintEqualToAnchor:contentTop constant:8],
            [_tableView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:8],
            [_tableView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-8],
            [_tableView.heightAnchor constraintEqualToConstant:tableH],
            [cancelBtn.topAnchor constraintEqualToAnchor:_tableView.bottomAnchor constant:8],
            [cancelBtn.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
            [cancelBtn.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
            [cancelBtn.heightAnchor constraintEqualToConstant:46],
            [cancelBtn.bottomAnchor constraintEqualToAnchor:_cardView.safeAreaLayoutGuide.bottomAnchor constant:-12],
        ]];
    } else if (_mode == AppSheetModePrompt || _mode == AppSheetModePrompt2) {
        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [UIFont systemFontOfSize:16];
        _textField.textColor = theme.primaryTextColor;
        _textField.backgroundColor = [theme.separatorColor colorWithAlphaComponent:0.35];
        _textField.layer.cornerRadius = 12;
        _textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
        _textField.leftViewMode = UITextFieldViewModeAlways;
        _textField.placeholder = _placeholder;
        _textField.text = _initialText;
        _textField.returnKeyType = UIReturnKeyDone;
        _textField.delegate = self;
        [_cardView addSubview:_textField];
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:row];
        UIView *cancelBtn = [self makeButtonWithTitle:@"Cancel" primary:NO destructive:NO action:@selector(dismissCancelled)];
        UIView *okBtn = [self makeButtonWithTitle:(_confirmTitle.length ? _confirmTitle : @"OK") primary:YES destructive:NO action:@selector(promptConfirmed)];
        [row addSubview:cancelBtn];
        [row addSubview:okBtn];
        cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        okBtn.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutAnchor *fieldTop = ([lastView isEqual:grabber] ? (NSLayoutAnchor *)grabber.bottomAnchor : (NSLayoutAnchor *)msgLabel.bottomAnchor);
        NSMutableArray *pc = [NSMutableArray arrayWithObjects:
            [_textField.topAnchor constraintEqualToAnchor:fieldTop constant:10],
            [_textField.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
            [_textField.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
            [_textField.heightAnchor constraintEqualToConstant:46],
            nil];
        UIView *belowField = _textField;
        if (_mode == AppSheetModePrompt2) {
            _textField2 = [[UITextField alloc] init];
            _textField2.translatesAutoresizingMaskIntoConstraints = NO;
            _textField2.font = [UIFont systemFontOfSize:16];
            _textField2.textColor = theme.primaryTextColor;
            _textField2.backgroundColor = [theme.separatorColor colorWithAlphaComponent:0.35];
            _textField2.layer.cornerRadius = 12;
            _textField2.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
            _textField2.leftViewMode = UITextFieldViewModeAlways;
            _textField2.placeholder = _placeholder2;
            _textField2.returnKeyType = UIReturnKeyDone;
            _textField2.delegate = self;
            [_cardView addSubview:_textField2];
            [pc addObjectsFromArray:@[
                [_textField2.topAnchor constraintEqualToAnchor:_textField.bottomAnchor constant:8],
                [_textField2.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
                [_textField2.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
                [_textField2.heightAnchor constraintEqualToConstant:46],
            ]];
            belowField = _textField2;
        }
        [pc addObjectsFromArray:@[
            [row.topAnchor constraintEqualToAnchor:belowField.bottomAnchor constant:12],
            [row.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
            [row.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],
            [row.heightAnchor constraintEqualToConstant:46],
            [row.bottomAnchor constraintEqualToAnchor:_cardView.safeAreaLayoutGuide.bottomAnchor constant:-12],
            [cancelBtn.topAnchor constraintEqualToAnchor:row.topAnchor],
            [cancelBtn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [cancelBtn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [cancelBtn.trailingAnchor constraintEqualToAnchor:row.centerXAnchor constant:-6],
            [okBtn.topAnchor constraintEqualToAnchor:row.topAnchor],
            [okBtn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [okBtn.leadingAnchor constraintEqualToAnchor:row.centerXAnchor constant:6],
            [okBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        ]];
        [c addObjectsFromArray:pc];
    }
    [NSLayoutConstraint activateConstraints:c];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_didAnimateEntrance) return;
    _didAnimateEntrance = YES;
    // Slide-up entrance (runs after real layout so the offset is correct).
    [self.view layoutIfNeeded];
    CGFloat h = _cardView.frame.size.height;
    _cardView.transform = CGAffineTransformMakeTranslation(0, h + 40);
    [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self->_cardView.transform = CGAffineTransformIdentity;
        self->_dimView.alpha = 1;
    } completion:nil];
    if (_mode == AppSheetModePrompt || _mode == AppSheetModePrompt2) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_textField becomeFirstResponder];
        });
    }
}

- (UIView *)makeButtonWithTitle:(NSString *)title primary:(BOOL)primary destructive:(BOOL)destructive action:(SEL)action {
    ThemeManager *theme = ThemeManager.shared;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.layer.cornerRadius = 13;
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    if (primary) {
        btn.backgroundColor = destructive ? theme.errorColor : theme.accentColor;
        [btn setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [theme.separatorColor colorWithAlphaComponent:0.35];
        [btn setTitleColor:destructive ? theme.errorColor : theme.accentColor forState:UIControlStateNormal];
    }
    [btn setTitle:title forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:_cardView];
    if (pan.state == UIGestureRecognizerStateChanged && t.y > 0) {
        _cardView.transform = CGAffineTransformMakeTranslation(0, t.y);
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGPoint v = [pan velocityInView:_cardView];
        if (t.y > 120 || v.y > 900) [self dismissCancelled];
        else [UIView animateWithDuration:0.25 animations:^{ self->_cardView.transform = CGAffineTransformIdentity; }];
    }
}

- (void)dismissWithCompletion:(void(^)(void))completion {
    [UIView animateWithDuration:0.22 animations:^{
        self->_cardView.transform = CGAffineTransformMakeTranslation(0, self->_cardView.frame.size.height + 40);
        self->_dimView.alpha = 0;
    } completion:^(BOOL f) {
        UIWindow *window = objc_getAssociatedObject(self, "appSheetWindow");
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
        if (window) {
            window.hidden = YES;
            objc_setAssociatedObject(self, "appSheetWindow", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (completion) completion();
    }];
}

- (void)dismissCancelled {
    [HapticManager.shared play:HapticTypeLight];
    void (^cb)(void) = _onCancel;
    [self dismissWithCompletion:^{
        if (cb) cb();
    }];
}

- (void)confirmTapped {
    [HapticManager.shared play:HapticTypeMedium];
    void (^cb)(void) = _onConfirmAction;
    [self dismissWithCompletion:^{
        if (cb) cb();
    }];
}

- (void)promptConfirmed {
    [HapticManager.shared play:HapticTypeMedium];
    NSString *text = _textField.text ?: @"";
    NSString *text2 = _textField2.text ?: @"";
    void (^cb)(NSString *) = _onPromptConfirm;
    void (^cb2)(NSString *, NSString *) = _onPrompt2Confirm;
    BOOL isTwo = (_mode == AppSheetModePrompt2);
    [_textField resignFirstResponder];
    [_textField2 resignFirstResponder];
    [self dismissWithCompletion:^{
        if (isTwo) { if (cb2) cb2(text, text2); }
        else if (cb) cb(text);
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self promptConfirmed];
    return YES;
}

#pragma mark - Options table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"AppSheetOptionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    }
    NSDictionary *opt = _options[indexPath.row];
    cell.textLabel.text = opt[@"title"] ?: @"";
    cell.detailTextLabel.text = opt[@"subtitle"];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.textLabel.textColor = [opt[@"destructive"] boolValue] ? ThemeManager.shared.errorColor : ThemeManager.shared.primaryTextColor;
    NSString *icon = opt[@"icon"];
    if ([icon isKindOfClass:[NSString class]] && icon.length > 0) {
        cell.imageView.image = [UIImage systemImageNamed:icon];
        cell.imageView.tintColor = [opt[@"destructive"] boolValue] ? ThemeManager.shared.errorColor : ThemeManager.shared.accentColor;
    } else {
        cell.imageView.image = nil;
    }
    cell.accessoryType = ((NSInteger)indexPath.row == _selectedIndex) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = ThemeManager.shared.accentColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeSelection];
    void (^cb)(NSInteger) = _onSelect;
    NSInteger idx = indexPath.row;
    [self dismissWithCompletion:^{
        if (cb) cb(idx);
    }];
}

@end

@implementation AppSheet

+ (UIWindow *)presentHost:(AppSheetHostVC *)host {
    __block UIWindow *window = nil;
    __block UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) return nil;
    // Must run on main (callers may be on background queues).
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            window = [self presentHost:host];
        });
        return window;
    }
    window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert;
    window.backgroundColor = [UIColor clearColor];
    window.rootViewController = host;
    window.hidden = NO;
    objc_setAssociatedObject(host, "appSheetWindow", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return window;
}

+ (void)showOptionsWithTitle:(NSString *)title message:(NSString *)message options:(NSArray<NSDictionary *> *)options selectedIndex:(NSInteger)selectedIndex selection:(void(^)(NSInteger))selection {
    [self showOptionsWithTitle:title message:message options:options selectedIndex:selectedIndex selection:selection cancel:nil];
}

+ (void)showOptionsWithTitle:(NSString *)title message:(NSString *)message options:(NSArray<NSDictionary *> *)options selectedIndex:(NSInteger)selectedIndex selection:(void(^)(NSInteger))selection cancel:(void(^)(void))cancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [HapticManager.shared play:HapticTypeLight];
        AppSheetHostVC *host = [[AppSheetHostVC alloc] init];
        host.mode = AppSheetModeOptions;
        host.sheetTitle = title;
        host.sheetMessage = message;
        host.options = options ?: @[];
        host.selectedIndex = selectedIndex;
        host.onSelect = selection;
        host.onCancel = cancel;
        [self presentHost:host];
    });
}

+ (void)showConfirmWithTitle:(NSString *)title message:(NSString *)message confirmTitle:(NSString *)confirmTitle destructive:(BOOL)destructive onConfirm:(void(^)(void))onConfirm {
    dispatch_async(dispatch_get_main_queue(), ^{
        [HapticManager.shared play:HapticTypeWarning];
        AppSheetHostVC *host = [[AppSheetHostVC alloc] init];
        host.mode = AppSheetModeConfirm;
        host.sheetTitle = title;
        host.sheetMessage = message;
        host.confirmTitle = confirmTitle;
        host.destructive = destructive;
        host.onConfirmAction = onConfirm;
        [self presentHost:host];
    });
}

+ (void)showPromptWithTitle:(NSString *)title message:(NSString *)message placeholder:(NSString *)placeholder initialText:(NSString *)text onConfirm:(void(^)(NSString *))onConfirm {
    dispatch_async(dispatch_get_main_queue(), ^{
        AppSheetHostVC *host = [[AppSheetHostVC alloc] init];
        host.mode = AppSheetModePrompt;
        host.sheetTitle = title;
        host.sheetMessage = message;
        host.confirmTitle = @"OK";
        host.placeholder = placeholder;
        host.initialText = text;
        host.onPromptConfirm = onConfirm;
        [self presentHost:host];
    });
}

+ (void)showPrompt2WithTitle:(NSString *)title message:(NSString *)message placeholder1:(NSString *)placeholder1 placeholder2:(NSString *)placeholder2 onConfirm:(void(^)(NSString *, NSString *))onConfirm {
    dispatch_async(dispatch_get_main_queue(), ^{
        AppSheetHostVC *host = [[AppSheetHostVC alloc] init];
        host.mode = AppSheetModePrompt2;
        host.sheetTitle = title;
        host.sheetMessage = message;
        host.confirmTitle = @"OK";
        host.placeholder = placeholder1;
        host.placeholder2 = placeholder2;
        host.onPrompt2Confirm = onConfirm;
        [self presentHost:host];
    });
}

@end
