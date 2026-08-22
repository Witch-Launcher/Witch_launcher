#import "AccountViewController.h"
#import "ThemeManager.h"
#import "CustomButton.h"
#import "authenticator/BaseAuthenticator.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "HapticManager.h"
#import "DownloadProgressOverlay.h"
#import <WebKit/WebKit.h>
#import "UIImageView+AFNetworking.h"
#import "AFNetworking.h"
#import "ElySkinHead.h"

@interface AccountViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic) NSDictionary *editingAccount;
@property (nonatomic) NSString *pendingSkinVariant;
@property (nonatomic) BOOL skinManagerWebViewActive;
@end

@interface MicrosoftAuthenticator (Keychain)
+ (NSDictionary *)tokenDataOfProfile:(NSString *)profile;
@end

@interface AccountCell : UITableViewCell
@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *typeLabel;
@property (nonatomic) UIButton *editBtn;
@property (nonatomic) UIButton *deleteBtn;
@end

@implementation AccountCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 10;
        self.clipsToBounds = YES;

        _avatarView = [[UIImageView alloc] init];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.layer.cornerRadius = 20;
        _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        [self.contentView addSubview:_nameLabel];

        _typeLabel = [[UILabel alloc] init];
        _typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _typeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _typeLabel.textColor = UIColor.whiteColor;
        _typeLabel.textAlignment = NSTextAlignmentCenter;
        _typeLabel.layer.cornerRadius = 4;
        _typeLabel.clipsToBounds = YES;
        [self.contentView addSubview:_typeLabel];

        _editBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _editBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_editBtn setTitle:@"Edit" forState:UIControlStateNormal];
        _editBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [_editBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
        _editBtn.hidden = YES;
        [self.contentView addSubview:_editBtn];

        _deleteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _deleteBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_deleteBtn setTitle:@"Delete" forState:UIControlStateNormal];
        _deleteBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [_deleteBtn setTitleColor:ThemeManager.shared.errorColor forState:UIControlStateNormal];
        [self.contentView addSubview:_deleteBtn];

        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:40],
            [_avatarView.heightAnchor constraintEqualToConstant:40],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],

            [_typeLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_typeLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_typeLabel.heightAnchor constraintEqualToConstant:18],
            [_typeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:60],

            [_deleteBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_deleteBtn.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_deleteBtn.widthAnchor constraintEqualToConstant:50],

            [_editBtn.trailingAnchor constraintEqualToAnchor:_deleteBtn.leadingAnchor constant:-4],
            [_editBtn.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_editBtn.widthAnchor constraintEqualToConstant:40],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
}

- (void)configureWithAccount:(NSDictionary *)account isSelected:(BOOL)isSelected {
    _nameLabel.text = account[@"username"] ?: @"Unknown";
    BOOL isEly = [account[@"accountType"] isEqualToString:@"elyby"];
    BOOL isPremium = [account[@"xboxGamertag"] length] > 0;
    BOOL isDemo = isPremium && [account[@"profileId"] isEqualToString:@"00000000-0000-0000-0000-000000000000"];

    if (isEly) {
        _typeLabel.text = @"Ely.by";
        _typeLabel.backgroundColor = [UIColor colorWithRed:0.55 green:0.35 blue:0.86 alpha:1];
    } else if (isDemo) {
        _typeLabel.text = @"Demo";
        _typeLabel.backgroundColor = [UIColor colorWithRed:0.95 green:0.60 blue:0.20 alpha:1];
    } else if (isPremium) {
        _typeLabel.text = @"Premium";
        _typeLabel.backgroundColor = [UIColor colorWithRed:0.20 green:0.60 blue:0.86 alpha:1];
    } else {
        _typeLabel.text = @"Local";
        _typeLabel.backgroundColor = ThemeManager.shared.secondaryTextColor;
    }

    _editBtn.hidden = !((isPremium && !isDemo) || isEly);

    UIImage *placeholder = [UIImage systemImageNamed:isDemo ? @"exclamationmark.triangle.fill" : (isPremium ? @"person.fill.checkmark" : @"person.circle.fill")];
    _avatarView.image = placeholder;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;

    NSString *profileId = account[@"profileId"];
    if (isEly && [account[@"username"] length] > 0) {
        NSString *username = account[@"username"];
        UIImage *cached = [ElySkinHead cachedHeadForUsername:username size:40];
        if (cached) {
            _avatarView.image = cached;
            _avatarView.tintColor = [UIColor clearColor];
        }
        __weak typeof(self) weakSelf = self;
        [ElySkinHead headForUsername:username size:40 completion:^(UIImage *head) {
            if (!head) return;
            weakSelf.avatarView.image = head;
            weakSelf.avatarView.tintColor = [UIColor clearColor];
        }];
    } else if (!isEly && isPremium && profileId.length > 0 && !isDemo) {
        NSString *skinURL = [NSString stringWithFormat:@"https://mc-heads.net/head/%@/40", profileId];
        __weak typeof(self) weakSelf = self;
        [_avatarView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:skinURL]]
                           placeholderImage:placeholder
                                    success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                        weakSelf.avatarView.image = image;
                                        weakSelf.avatarView.tintColor = [UIColor clearColor];
                                     } failure:nil];
    }

    if (isSelected) {
        self.layer.borderWidth = 2;
        self.layer.borderColor = ThemeManager.shared.accentColor.CGColor;
    } else {
        self.layer.borderWidth = 0;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _avatarView.image = nil;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    _nameLabel.text = nil;
    _typeLabel.text = nil;
    self.layer.borderWidth = 0;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

@interface AccountViewController () <UITableViewDelegate, UITableViewDataSource, WKNavigationDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *accountsArray;
@property (nonatomic) UISegmentedControl *addTypeControl;
@property (nonatomic) UITextField *usernameField;
@property (nonatomic) UITextField *passwordField;
@property (nonatomic) UIButton *addActionBtn;
@property (nonatomic) UIButton *oauthLinkBtn;
@property (nonatomic) UIView *addFormView;
@property (nonatomic) NSLayoutConstraint *passwordTopConstraint;
@property (nonatomic) NSLayoutConstraint *passwordHeightConstraint;
@property (nonatomic) NSLayoutConstraint *oauthTopConstraint;
@property (nonatomic) NSLayoutConstraint *oauthHeightConstraint;
@property (nonatomic) NSLayoutConstraint *formBottomConstraint;
@property (nonatomic) WKWebView *loginWebView;
@property (nonatomic) BOOL elyOAuthFlowActive;
@end

extern NSString *ELY_OAUTH_REDIRECT_URI;

@implementation AccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [self updateColors];
    [self loadAccounts];
}

- (void)setup {
    self.view.clipsToBounds = YES;

    // Tap to dismiss keyboard
    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapDismiss.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapDismiss];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"  Accounts";
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    [self.view addSubview:titleLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = 64;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 200, 0);
    [_tableView registerClass:[AccountCell class] forCellReuseIdentifier:@"AccountCell"];
    [self.view addSubview:_tableView];

    _addFormView = [[UIView alloc] init];
    _addFormView.translatesAutoresizingMaskIntoConstraints = NO;
    _addFormView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _addFormView.layer.cornerRadius = 12;
    _addFormView.layer.borderWidth = 1;
    _addFormView.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    [self.view addSubview:_addFormView];

    UILabel *addTitle = [[UILabel alloc] init];
    addTitle.translatesAutoresizingMaskIntoConstraints = NO;
    addTitle.text = @"Add Account";
    addTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    addTitle.textColor = ThemeManager.shared.primaryTextColor;
    [_addFormView addSubview:addTitle];

    _addTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Premium (Microsoft)", @"Local (Offline)", @"Ely.by"]];
    _addTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _addTypeControl.selectedSegmentIndex = 1;
    [_addTypeControl addTarget:self action:@selector(addTypeChanged) forControlEvents:UIControlEventValueChanged];
    [_addFormView addSubview:_addTypeControl];

    _usernameField = [[UITextField alloc] init];
    _usernameField.translatesAutoresizingMaskIntoConstraints = NO;
    _usernameField.placeholder = @"Username";
    _usernameField.text = @"Player";
    _usernameField.borderStyle = UITextBorderStyleRoundedRect;
    _usernameField.font = [UIFont systemFontOfSize:14];
    _usernameField.hidden = YES;
    _usernameField.returnKeyType = UIReturnKeyDone;
    [_usernameField addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventEditingDidEndOnExit];

    UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    kbToolbar.items = @[flexSpace, doneBtn];
    _usernameField.inputAccessoryView = kbToolbar;

    [_addFormView addSubview:_usernameField];

    _passwordField = [[UITextField alloc] init];
    _passwordField.translatesAutoresizingMaskIntoConstraints = NO;
    _passwordField.placeholder = @"Password";
    _passwordField.borderStyle = UITextBorderStyleRoundedRect;
    _passwordField.font = [UIFont systemFontOfSize:14];
    _passwordField.hidden = YES;
    _passwordField.secureTextEntry = YES;
    _passwordField.returnKeyType = UIReturnKeyDone;
    _passwordField.inputAccessoryView = kbToolbar;
    [_passwordField addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_addFormView addSubview:_passwordField];

    _addActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _addActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_addActionBtn setTitle:@"Login with Microsoft  →" forState:UIControlStateNormal];
    [_addActionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _addActionBtn.backgroundColor = ThemeManager.shared.accentColor;
    _addActionBtn.layer.cornerRadius = 8;
    _addActionBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_addActionBtn addTarget:self action:@selector(addAccountTapped) forControlEvents:UIControlEventTouchUpInside];
    _addActionBtn.hidden = YES;
    [_addFormView addSubview:_addActionBtn];

    _oauthLinkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _oauthLinkBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_oauthLinkBtn setTitle:@"Sign in with Browser (OAuth2)" forState:UIControlStateNormal];
    _oauthLinkBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [_oauthLinkBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    [_oauthLinkBtn addTarget:self action:@selector(addElyOAuthTapped) forControlEvents:UIControlEventTouchUpInside];
    _oauthLinkBtn.hidden = YES;
    [_addFormView addSubview:_oauthLinkBtn];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],

        [_tableView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_addFormView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_addFormView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        self.formBottomConstraint = [_addFormView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0],

        [addTitle.topAnchor constraintEqualToAnchor:_addFormView.topAnchor constant:12],
        [addTitle.centerXAnchor constraintEqualToAnchor:_addFormView.centerXAnchor],

        [_addTypeControl.topAnchor constraintEqualToAnchor:addTitle.bottomAnchor constant:10],
        [_addTypeControl.leadingAnchor constraintEqualToAnchor:_addFormView.leadingAnchor constant:12],
        [_addTypeControl.trailingAnchor constraintEqualToAnchor:_addFormView.trailingAnchor constant:-12],

        [_usernameField.topAnchor constraintEqualToAnchor:_addTypeControl.bottomAnchor constant:10],
        [_usernameField.leadingAnchor constraintEqualToAnchor:_addFormView.leadingAnchor constant:12],
        [_usernameField.trailingAnchor constraintEqualToAnchor:_addFormView.trailingAnchor constant:-12],
        [_usernameField.heightAnchor constraintEqualToConstant:36],

        self.passwordTopConstraint = [_passwordField.topAnchor constraintEqualToAnchor:_usernameField.bottomAnchor constant:0],
        [_passwordField.leadingAnchor constraintEqualToAnchor:_addFormView.leadingAnchor constant:12],
        [_passwordField.trailingAnchor constraintEqualToAnchor:_addFormView.trailingAnchor constant:-12],
        self.passwordHeightConstraint = [_passwordField.heightAnchor constraintEqualToConstant:0],

        [_addActionBtn.topAnchor constraintEqualToAnchor:_passwordField.bottomAnchor constant:10],
        [_addActionBtn.leadingAnchor constraintEqualToAnchor:_addFormView.leadingAnchor constant:12],
        [_addActionBtn.trailingAnchor constraintEqualToAnchor:_addFormView.trailingAnchor constant:-12],
        [_addActionBtn.heightAnchor constraintEqualToConstant:40],

        self.oauthTopConstraint = [_oauthLinkBtn.topAnchor constraintEqualToAnchor:_addActionBtn.bottomAnchor constant:0],
        [_oauthLinkBtn.centerXAnchor constraintEqualToAnchor:_addFormView.centerXAnchor],
        self.oauthHeightConstraint = [_oauthLinkBtn.heightAnchor constraintEqualToConstant:0],
        [_oauthLinkBtn.bottomAnchor constraintEqualToAnchor:_addFormView.bottomAnchor constant:-10],
    ]];

    [self addTypeChanged];
}

- (void)addTypeChanged {
    NSInteger selected = _addTypeControl.selectedSegmentIndex;
    BOOL isLocal = selected == 1;
    BOOL isEly = selected == 2;

    _usernameField.hidden = !(isLocal || isEly);
    _usernameField.placeholder = isEly ? @"Ely.by email or username" : @"Username";
    if (isLocal && _usernameField.text.length == 0) _usernameField.text = @"Player";
    if (!isLocal && [_usernameField.text isEqualToString:@"Player"]) _usernameField.text = @"";
    if (!isLocal && !isEly) _passwordField.text = @"";

    _passwordField.hidden = !isEly;
    self.passwordTopConstraint.constant = isEly ? 10 : 0;
    self.passwordHeightConstraint.constant = isEly ? 36 : 0;

    _oauthLinkBtn.hidden = !isEly;
    self.oauthTopConstraint.constant = isEly ? 6 : 0;
    self.oauthHeightConstraint.constant = isEly ? 30 : 0;

    _addActionBtn.hidden = NO;
    if (isLocal) {
        [_addActionBtn setTitle:@"Add Local Account" forState:UIControlStateNormal];
        _usernameField.placeholder = @"Username";
    } else if (isEly) {
        [_addActionBtn setTitle:@"Login with Ely.by  →" forState:UIControlStateNormal];
    } else {
        [_addActionBtn setTitle:@"Login with Microsoft  →" forState:UIControlStateNormal];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGFloat bottomInset = self.view.safeAreaInsets.bottom;
        self.formBottomConstraint.constant = -12 - bottomInset;
    });
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:kbFrame fromView:self.view.window];
    CGFloat overlap = self.view.frame.size.height - converted.origin.y;
    if (overlap <= 0) return;

    self.formBottomConstraint.constant = -12 - overlap;

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:curve << 16 animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    CGFloat bottomInset = self.view.safeAreaInsets.bottom;
    self.formBottomConstraint.constant = -12 - bottomInset;

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:curve << 16 animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _tableView.backgroundColor = theme.contentBackgroundColor;
    _addFormView.backgroundColor = theme.cardBackgroundColor;
    _addFormView.layer.borderColor = theme.separatorColor.CGColor;
}

- (void)loadAccounts {
    _accountsArray = [NSMutableArray array];
    NSString *gameDir = [NSString stringWithUTF8String:getenv("POJAV_HOME")];
    if (gameDir.length == 0) gameDir = NSTemporaryDirectory();
    NSString *accountDir = [gameDir stringByAppendingPathComponent:@"accounts"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:accountDir error:nil];
    for (NSString *file in files) {
        if ([file hasSuffix:@".json"]) {
            NSString *path = [accountDir stringByAppendingPathComponent:file];
            NSMutableDictionary *data = parseJSONFromFile(path);
            if (data && ![data isKindOfClass:[NSError class]]) {
                [_accountsArray addObject:data];
            }
        }
    }
    [_tableView reloadData];
}

- (void)selectAndSaveAccount:(BaseAuthenticator *)auth {
    BaseAuthenticator.current = auth;
    setPrefObject(@"internal.selected_account", auth.authData[@"username"] ?: @"");
    [self loadAccounts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (void)addMicrosoftAccount {
    self.elyOAuthFlowActive = NO;
    NSString *authURL = @"https://login.live.com/oauth20_authorize.srf?client_id=00000000402b5328&response_type=code&redirect_uri=https://login.live.com/oauth20_desktop.srf&scope=service::user.auth.xboxlive.com::MBI_SSL";
    [self presentLoginWebViewWithURL:[NSURL URLWithString:authURL] title:@"Microsoft Login"];
}

- (void)presentLoginWebViewWithURL:(NSURL *)url title:(NSString *)title {
    UIView *webContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    webContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webContainer.backgroundColor = UIColor.whiteColor;

    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, webContainer.bounds.size.width, 44)];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBar.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1];
    [webContainer addSubview:topBar];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(8, 0, 60, 44);
    [closeBtn setTitle:@"Cancel" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissWebView) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:closeBtn];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, topBar.bounds.size.width, 44)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [topBar addSubview:titleLabel];

    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 44, webContainer.bounds.size.width, webContainer.bounds.size.height - 44)];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.navigationDelegate = self;
    self.loginWebView = webView;
    [webContainer addSubview:webView];

    [self.view addSubview:webContainer];

    [webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)dismissWebView {
    [self.loginWebView.superview removeFromSuperview];
    self.loginWebView = nil;
    if (self.skinManagerWebViewActive) {
        self.skinManagerWebViewActive = NO;
        NSString *name = _editingAccount[@"username"];
        if (name.length > 0) {
            [ElySkinHead clearCacheForUsername:name];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *urlStr = url.absoluteString;

    NSString *redirectPrefix = self.elyOAuthFlowActive ? ELY_OAUTH_REDIRECT_URI : @"https://login.live.com/oauth20_desktop.srf";
    if ([urlStr hasPrefix:redirectPrefix]) {
        [self dismissWebView];
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
            NSArray *kv = [pair componentsSeparatedByString:@"="];
            if (kv.count != 2) continue;
            params[kv[0]] = [kv[1] stringByRemovingPercentEncoding];
        }

        if (self.elyOAuthFlowActive) {
            self.elyOAuthFlowActive = NO;
            if (params[@"code"]) {
                ElyAuthenticator *auth = [[ElyAuthenticator alloc] initWithOAuthCode:params[@"code"]];
                [auth loginWithCallback:^(id status, BOOL success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!success) {
                            NSString *errMsg = [status isKindOfClass:NSError.class] ? [(NSError *)status localizedDescription] : ([status isKindOfClass:NSString.class] ? status : @"Login failed");
                            showDialog(localize(@"Error", nil), errMsg);
                            return;
                        }
                        [self selectAndSaveAccount:auth];
                        showDialog(@"Success", [NSString stringWithFormat:@"Logged in as %@", auth.authData[@"username"] ?: @"Unknown"]);
                    });
                }];
            } else if (params[@"error_description"] || params[@"error"]) {
                showDialog(localize(@"Error", nil), params[@"error_description"] ?: params[@"error"]);
            }
        } else if (params[@"code"]) {
                MicrosoftAuthenticator *auth = [[MicrosoftAuthenticator alloc] initWithInput:params[@"code"]];
                [auth loginWithCallback:^(id status, BOOL success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!success) {
                            NSString *errMsg = [status isKindOfClass:NSError.class] ? [(NSError *)status localizedDescription] : ([status isKindOfClass:NSString.class] ? status : @"Login failed");
                            showDialog(localize(@"Error", nil), errMsg);
                            return;
                        }
                        if (status == nil || [status isEqualToString:@"Done"]) {
                            [self selectAndSaveAccount:auth];
                            showDialog(@"Success", [NSString stringWithFormat:@"Logged in as %@", auth.authData[@"username"] ?: @"Unknown"]);
                        } else if ([status isEqualToString:@"DEMO"]) {
                            [self selectAndSaveAccount:auth];
                            showDialog(@"Demo Account", @"Your Microsoft account has not purchased Minecraft. You will not be able to play the full game.");
                        }
                    });
                }];
        } else if (params[@"error"]) {
            showDialog(localize(@"Error", nil), params[@"error"]);
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)addLocalAccount {
    NSString *name = _usernameField.text;
    if (name.length == 0) name = @"Player";
    LocalAuthenticator *auth = [[LocalAuthenticator alloc] initWithInput:name];
    [auth loginWithCallback:^(NSString *status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self selectAndSaveAccount:auth];
                showDialog(@"Success", [NSString stringWithFormat:@"Local account '%@' added.", name]);
            }
        });
    }];
}

- (void)addAccountTapped {
    if (_addTypeControl.selectedSegmentIndex == 0) {
        [self addMicrosoftAccount];
    } else if (_addTypeControl.selectedSegmentIndex == 2) {
        [self addElyByAccount];
    } else {
        [self addLocalAccount];
    }
}

#pragma mark - Ely.by Login

- (void)addElyByAccount {
    NSString *login = _usernameField.text;
    NSString *password = _passwordField.text;
    if (login.length == 0 || password.length == 0) {
        showDialog(localize(@"Error", nil), @"Please enter your Ely.by email/username and password.");
        return;
    }
    [self elyLoginWithLogin:login password:password totp:nil];
}

- (void)elyLoginWithLogin:(NSString *)login password:(NSString *)password totp:(NSString *)totp {
    ElyAuthenticator *auth = [[ElyAuthenticator alloc] initWithCredentials:login password:password totp:totp];
    [auth loginWithCallback:^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([status isKindOfClass:NSString.class] && [status isEqualToString:@"TOTP_REQUIRED"]) {
                [self promptElyTOTPWithLogin:login password:password];
                return;
            }
            if (!success) {
                NSString *errMsg = [status isKindOfClass:NSError.class] ? [(NSError *)status localizedDescription] : ([status isKindOfClass:NSString.class] ? status : @"Login failed");
                showDialog(localize(@"Error", nil), errMsg);
                return;
            }
            if (status == nil || [status isEqualToString:@"Done"]) {
                [self selectAndSaveAccount:auth];
                showDialog(@"Success", [NSString stringWithFormat:@"Logged in as %@", auth.authData[@"username"] ?: @"Unknown"]);
            }
        });
    }];
}

- (void)promptElyTOTPWithLogin:(NSString *)login password:(NSString *)password {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Two-Factor Authentication"
                                                                   message:@"Your account is protected with two factor auth. Enter the 6-digit code from your authenticator app."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"123456";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Verify" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *code = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        [self elyLoginWithLogin:login password:password totp:code];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addElyOAuthTapped {
    NSURL *url = [ElyAuthenticator oauthAuthorizeURL];
    if (!url) {
        showDialog(@"OAuth2 Not Configured",
            @"Register an application at https://account.ely.by/dev/applications/new (type: Website), then fill in ELY_OAUTH_CLIENT_ID, ELY_OAUTH_CLIENT_SECRET and ELY_OAUTH_REDIRECT_URI in Natives/authenticator/ElyAuthenticator.m.");
        return;
    }
    self.elyOAuthFlowActive = YES;
    [self presentLoginWebViewWithURL:url title:@"Ely.by Login"];
}

- (void)deleteAccountAtIndex:(NSInteger)index {
    NSDictionary *account = _accountsArray[index];
    NSString *gameDir2 = [NSString stringWithUTF8String:getenv("POJAV_HOME")];
    if (gameDir2.length == 0) gameDir2 = NSTemporaryDirectory();
    NSString *path = [gameDir2 stringByAppendingPathComponent:[NSString stringWithFormat:@"accounts/%@.json", account[@"username"]]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    if ([account[@"username"] isEqualToString:getPrefObject(@"internal.selected_account")]) {
        BaseAuthenticator.current = nil;
        setPrefObject(@"internal.selected_account", @"");
    }

    NSString *xuid = account[@"xuid"];
    if (xuid) {
        [MicrosoftAuthenticator clearTokenDataOfProfile:xuid];
    }

    if ([account[@"accountType"] isEqualToString:@"elyby"]) {
        [ElyAuthenticator invalidateAccessToken:account[@"accessToken"] clientToken:account[@"clientToken"]];
        NSString *elyProfileId = account[@"profileId"];
        if (elyProfileId.length > 0) {
            [ElyAuthenticator clearTokenDataOfProfile:elyProfileId];
        }
    }

    [self loadAccounts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (void)editAccount:(NSDictionary *)account {
    BOOL isPremium = [account[@"xboxGamertag"] length] > 0;
    BOOL isEly = [account[@"accountType"] isEqualToString:@"elyby"];
    if (!isPremium && !isEly) return;
    _editingAccount = account;

    UIViewController *editVC = [[UIViewController alloc] init];
    editVC.title = [NSString stringWithFormat:@"Edit Account - %@", account[@"username"]];
    editVC.view.backgroundColor = ThemeManager.shared.backgroundColor;

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [editVC.view addSubview:scroll];

    UIImageView *skinPreview = [[UIImageView alloc] init];
    skinPreview.translatesAutoresizingMaskIntoConstraints = NO;
    skinPreview.contentMode = UIViewContentModeScaleAspectFit;
    skinPreview.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    skinPreview.layer.cornerRadius = 12;
    skinPreview.clipsToBounds = YES;
    skinPreview.image = [UIImage systemImageNamed:@"person.circle.fill"];
    skinPreview.tintColor = ThemeManager.shared.secondaryTextColor;
    [scroll addSubview:skinPreview];

    UIImageView *headView = [[UIImageView alloc] init];
    headView.translatesAutoresizingMaskIntoConstraints = NO;
    headView.contentMode = UIViewContentModeScaleAspectFit;
    headView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    headView.layer.cornerRadius = 8;
    headView.clipsToBounds = YES;
    headView.image = [UIImage systemImageNamed:@"person.fill"];
    headView.tintColor = ThemeManager.shared.secondaryTextColor;
    [scroll addSubview:headView];

    NSString *profileId = account[@"profileId"];
    if (isEly && [account[@"username"] length] > 0) {
        NSString *skinURL = [NSString stringWithFormat:@"https://skinsystem.ely.by/skins/%@.png", account[@"username"]];
        NSString *username = account[@"username"];
        __weak UIImageView *weakPreview = skinPreview;
        __weak UIImageView *weakHead = headView;
        UIImage *cachedHead = [ElySkinHead cachedHeadForUsername:username size:80];
        if (cachedHead) {
            headView.image = cachedHead;
            headView.tintColor = [UIColor clearColor];
        }
        [skinPreview setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:skinURL]]
                           placeholderImage:[UIImage systemImageNamed:@"person.circle.fill"]
                                    success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                        weakPreview.image = image;
                                    } failure:nil];
        [ElySkinHead headForUsername:username size:80 completion:^(UIImage *head) {
            if (!head) return;
            weakHead.image = head;
            weakHead.tintColor = [UIColor clearColor];
        }];
    } else if (profileId.length > 0 && ![profileId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        NSString *skinURL = [NSString stringWithFormat:@"https://mc-heads.net/body/%@/200", profileId];
        [skinPreview setImageWithURL:[NSURL URLWithString:skinURL]];
        NSString *headURL = [NSString stringWithFormat:@"https://mc-heads.net/avatar/%@/80", profileId];
        [headView setImageWithURL:[NSURL URLWithString:headURL]];
    }

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    nameLabel.text = account[@"username"] ?: @"";
    [scroll addSubview:nameLabel];

    UILabel *uuidLabel = [[UILabel alloc] init];
    uuidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    uuidLabel.font = [UIFont systemFontOfSize:12];
    uuidLabel.textColor = ThemeManager.shared.secondaryTextColor;
    uuidLabel.numberOfLines = 2;
    NSString *uuid = account[@"profileId"] ?: @"N/A";
    NSString *maskedUuid = (uuid.length > 4) ? [NSString stringWithFormat:@"%@***%@", [uuid substringToIndex:2], [uuid substringFromIndex:uuid.length - 2]] : uuid;
    uuidLabel.text = [NSString stringWithFormat:@"UUID: %@", maskedUuid];
    [scroll addSubview:uuidLabel];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [copyBtn setTitle:@"Copy" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(copyUUID) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:copyBtn];

    UIButton *changeSkinBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    changeSkinBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [changeSkinBtn setTitle:@"Change Skin" forState:UIControlStateNormal];
    [changeSkinBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    changeSkinBtn.backgroundColor = ThemeManager.shared.accentColor;
    changeSkinBtn.layer.cornerRadius = 8;
    changeSkinBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [changeSkinBtn addTarget:self action:@selector(changeSkinTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (isEly) {
        [changeSkinBtn setTitle:@"Manage Skin on ely.by  ↗" forState:UIControlStateNormal];
    }
    [scroll addSubview:changeSkinBtn];

    UIButton *changeCapeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    changeCapeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [changeCapeBtn setTitle:@"Change Cape" forState:UIControlStateNormal];
    [changeCapeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    changeCapeBtn.backgroundColor = ThemeManager.shared.accentColor;
    changeCapeBtn.layer.cornerRadius = 8;
    changeCapeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [changeCapeBtn addTarget:self action:@selector(changeCapeTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (isEly) {
        [changeCapeBtn setTitle:@"About Capes" forState:UIControlStateNormal];
    }
    [scroll addSubview:changeCapeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:editVC.view.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:editVC.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:editVC.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:editVC.view.bottomAnchor],

        [skinPreview.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:20],
        [skinPreview.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:20],
        [skinPreview.widthAnchor constraintEqualToConstant:140],
        [skinPreview.heightAnchor constraintEqualToConstant:200],

        [headView.topAnchor constraintEqualToAnchor:skinPreview.topAnchor],
        [headView.leadingAnchor constraintEqualToAnchor:skinPreview.trailingAnchor constant:16],
        [headView.widthAnchor constraintEqualToConstant:80],
        [headView.heightAnchor constraintEqualToConstant:80],

        [nameLabel.topAnchor constraintEqualToAnchor:headView.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:headView.leadingAnchor],

        [uuidLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [uuidLabel.leadingAnchor constraintEqualToAnchor:headView.leadingAnchor],
        [uuidLabel.trailingAnchor constraintEqualToAnchor:editVC.view.trailingAnchor constant:-20],

        [copyBtn.centerYAnchor constraintEqualToAnchor:uuidLabel.centerYAnchor],
        [copyBtn.leadingAnchor constraintEqualToAnchor:uuidLabel.trailingAnchor constant:-50],

        [changeSkinBtn.topAnchor constraintEqualToAnchor:skinPreview.bottomAnchor constant:20],
        [changeSkinBtn.leadingAnchor constraintEqualToAnchor:editVC.view.leadingAnchor constant:20],
        [changeSkinBtn.trailingAnchor constraintEqualToAnchor:editVC.view.trailingAnchor constant:-20],
        [changeSkinBtn.heightAnchor constraintEqualToConstant:44],

        [changeCapeBtn.topAnchor constraintEqualToAnchor:changeSkinBtn.bottomAnchor constant:10],
        [changeCapeBtn.leadingAnchor constraintEqualToAnchor:editVC.view.leadingAnchor constant:20],
        [changeCapeBtn.trailingAnchor constraintEqualToAnchor:editVC.view.trailingAnchor constant:-20],
        [changeCapeBtn.heightAnchor constraintEqualToConstant:44],
        [changeCapeBtn.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-30],
    ]];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)copyUUID {
    NSDictionary *account = [self selectedAccount];
    NSString *uuid = account[@"profileId"] ?: @"";
    [UIPasteboard generalPasteboard].string = uuid;
    showDialog(@"Copied", @"UUID copied to clipboard.");
}

- (NSDictionary *)selectedAccount {
    NSString *selected = getPrefObject(@"internal.selected_account");
    for (NSDictionary *acc in _accountsArray) {
        if ([acc[@"username"] isEqualToString:selected]) return acc;
    }
    return _accountsArray.firstObject;
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _accountsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AccountCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AccountCell" forIndexPath:indexPath];
    NSDictionary *account = _accountsArray[indexPath.row];
    NSString *selected = getPrefObject(@"internal.selected_account");
    BOOL isSelected = [account[@"username"] isEqualToString:selected];
    [cell configureWithAccount:account isSelected:isSelected];

    cell.deleteBtn.tag = indexPath.row;
    [cell.deleteBtn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.deleteBtn addTarget:self action:@selector(confirmDelete:) forControlEvents:UIControlEventTouchUpInside];

    cell.editBtn.tag = indexPath.row;
    [cell.editBtn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.editBtn addTarget:self action:@selector(editTapped:) forControlEvents:UIControlEventTouchUpInside];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *account = _accountsArray[indexPath.row];
    NSString *username = account[@"username"];
    BaseAuthenticator *auth = [BaseAuthenticator loadSavedName:username];

    BOOL isPremium = [account[@"xboxGamertag"] length] > 0;
    if (!isPremium) {
        [HapticManager.shared play:HapticTypeLight];
        AccountCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [UIView animateWithDuration:0.3 animations:^{
            cell.transform = CGAffineTransformMakeScale(1.05, 1.05);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 animations:^{
                cell.transform = CGAffineTransformIdentity;
            }];
        }];
        UIView *flash = [[UIView alloc] initWithFrame:cell.bounds];
        flash.backgroundColor = ThemeManager.shared.accentColor;
        flash.alpha = 0.3;
        flash.userInteractionEnabled = NO;
        [cell addSubview:flash];
        [UIView animateWithDuration:0.5 animations:^{
            flash.alpha = 0;
        } completion:^(BOOL finished) {
            [flash removeFromSuperview];
        }];
    }

    if (auth) {
        [self selectAndSaveAccount:auth];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteAccountAtIndex:indexPath.row];
    }
}

#pragma mark - Actions

- (void)confirmDelete:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSDictionary *account = _accountsArray[index];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete Account"
                                                                     message:[NSString stringWithFormat:@"Delete '%@'?", account[@"username"]]
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self deleteAccountAtIndex:index];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)editTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSDictionary *account = _accountsArray[index];
    [self editAccount:account];
}

#pragma mark - Change Skin / Cape

- (void)ensureFreshMSToken:(void (^)(NSString *accessToken))completion {
    NSString *username = _editingAccount[@"username"];
    NSString *xuid = _editingAccount[@"xuid"];
    if (username.length == 0 || xuid.length == 0) {
        completion(nil);
        return;
    }

    NSString *selectedName = getPrefObject(@"internal.selected_account");
    MicrosoftAuthenticator *auth = (MicrosoftAuthenticator *)[BaseAuthenticator loadSavedName:username];
    if (![auth isKindOfClass:MicrosoftAuthenticator.class]) {
        completion(nil);
        return;
    }

    [auth refreshTokenWithCallback:^(id status, BOOL success) {
        if (status != nil) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![selectedName isEqualToString:username] && selectedName.length > 0) {
                [BaseAuthenticator loadSavedName:selectedName];
            }
            NSDictionary *tokenData = [MicrosoftAuthenticator tokenDataOfProfile:xuid];
            completion(tokenData[@"accessToken"]);
        });
    }];
}

- (void)changeSkinTapped:(UIButton *)sender {
    BOOL isEly = [_editingAccount[@"accountType"] isEqualToString:@"elyby"];
    if (isEly) {
        self.skinManagerWebViewActive = YES;
        self.elyOAuthFlowActive = NO;
        [self presentLoginWebViewWithURL:[NSURL URLWithString:@"https://account.ely.by/"] title:@"ely.by Skin Manager"];
        return;
    }

    UIAlertController *variantAlert = [UIAlertController alertControllerWithTitle:@"Skin Model"
                                                                          message:@"Choose the model of your skin"
                                                                   preferredStyle:UIAlertControllerStyleActionSheet];
    [variantAlert addAction:[UIAlertAction actionWithTitle:@"Classic (Steve, 4px arms)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.pendingSkinVariant = @"classic";
        [self presentImagePickerForCape:NO];
    }]];
    [variantAlert addAction:[UIAlertAction actionWithTitle:@"Slim (Alex, 3px arms)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.pendingSkinVariant = @"slim";
        [self presentImagePickerForCape:NO];
    }]];
    [variantAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    variantAlert.popoverPresentationController.sourceView = sender;
    variantAlert.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:variantAlert animated:YES completion:nil];
}

- (void)changeCapeTapped:(UIButton *)sender {
    BOOL isEly = [_editingAccount[@"accountType"] isEqualToString:@"elyby"];
    if (isEly) {
        showDialog(@"Capes",
            @"Ely.by manages capes centrally: players cannot equip, upload or change capes themselves. Capes are granted automatically by the Ely.by system (events, donations and so on) and will show up on your character automatically.");
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Loading Capes"];
    [self ensureFreshMSToken:^(NSString *accessToken) {
        if (accessToken.length == 0) {
            [overlay dismiss];
            showDialog(@"Error", @"Failed to retrieve access token. Please re-login.");
            return;
        }

        NSDictionary *headers = @{
            @"Authorization": [NSString stringWithFormat:@"Bearer %@", accessToken]
        };
        AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
        [manager GET:@"https://api.minecraftservices.com/minecraft/profile" parameters:nil headers:headers progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [overlay dismiss];
                [self presentCapePickerWithProfile:response accessToken:accessToken sourceView:sender];
            });
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [overlay dismiss];
                showDialog(@"Error", error.localizedDescription ?: @"Failed to fetch profile.");
            });
        }];
    }];
}

- (void)presentCapePickerWithProfile:(NSDictionary *)profile accessToken:(NSString *)accessToken sourceView:(UIButton *)sourceView {
    NSArray *capes = profile[@"capes"] ?: @[];
    if (capes.count == 0) {
        showDialog(@"No Capes", @"This account does not own any capes. Capes can only be equipped if they were obtained through official Minecraft events or the Marketplace.");
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Change Cape"
                                                                   message:@"Select a cape to equip. Tapping the active cape unequips it."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *cape in capes) {
        NSString *capeId = cape[@"id"];
        BOOL isActive = [cape[@"state"] isEqualToString:@"ACTIVE"];
        NSString *title = cape[@"alias"] ?: capeId;
        if (isActive) title = [title stringByAppendingString:@"  ✓"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self equipCapeWithId:capeId isActive:isActive accessToken:accessToken];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = sourceView;
    sheet.popoverPresentationController.sourceRect = sourceView.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)equipCapeWithId:(NSString *)capeId isActive:(BOOL)isActive accessToken:(NSString *)accessToken {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.minecraftservices.com/minecraft/profile/capes/%@", capeId]]];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Changing Cape"];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (!error && httpResp.statusCode == 200) {
                [overlay finishWithMessage:isActive ? @"Cape removed!" : @"Cape equipped!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                });
            } else {
                [overlay dismiss];
                NSString *errMsg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: (error.localizedDescription ?: @"Unknown error");
                showDialog(@"Cape Change Failed", [NSString stringWithFormat:@"HTTP %ld: %@", (long)httpResp.statusCode, errMsg]);
            }
        });
    }];
    [task resume];
}

- (void)presentImagePickerForCape:(BOOL)forCape {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (!image) return;

    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    if (!((width == 64 && height == 64) || (width == 64 && height == 32))) {
        showDialog(@"Invalid Skin", @"The skin must be a standard 64x64 (modern) or 64x32 (legacy) PNG file.");
        return;
    }

    NSString *uuid = _editingAccount[@"profileId"];
    NSString *xuid = _editingAccount[@"xuid"];
    if (!uuid || !xuid) {
        showDialog(@"Error", @"Missing account profile information.");
        return;
    }
    NSString *plainUUID = [[uuid componentsSeparatedByString:@"-"] componentsJoinedByString:@""];
    NSString *variant = self.pendingSkinVariant ?: @"classic";
    self.pendingSkinVariant = nil;

    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        showDialog(@"Error", @"Failed to process image.");
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Uploading Skin"];
    [overlay updateProgress:0 message:@"Refreshing session..."];

    __weak typeof(self) weakSelf = self;
    NSString *capturedVariant = variant;
    [self ensureFreshMSToken:^(NSString *accessToken) {
        if (accessToken.length == 0) {
            [overlay dismiss];
            showDialog(@"Error", @"Failed to retrieve access token. Please re-login and try again.");
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.minecraftservices.com/minecraft/profile/skins"]];
        request.HTTPMethod = @"POST";
        [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

        NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

        NSMutableData *body = [NSMutableData data];
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"variant\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", capturedVariant] dataUsingEncoding:NSUTF8StringEncoding]];

        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"skin.png\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

        request.HTTPBody = body;
        [overlay updateProgress:0.5 message:@"Uploading..."];

        [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf) return;
                if (error) {
                    [overlay dismiss];
                    showDialog(@"Upload Failed", error.localizedDescription);
                    return;
                }
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                if (httpResp.statusCode == 200 || httpResp.statusCode == 204) {
                    [overlay finishWithMessage:@"Skin updated!"];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [overlay dismiss];
                        showDialog(@"Success", @"Your skin has been updated. It may take a few minutes to appear in-game.");
                    });
                } else {
                    [overlay dismiss];
                    NSString *errMsg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"Unknown error";
                    if (httpResp.statusCode == 401) {
                        errMsg = @"Session expired and could not be refreshed. Please re-login.";
                    }
                    showDialog(@"Upload Failed", [NSString stringWithFormat:@"HTTP %ld: %@", (long)httpResp.statusCode, errMsg]);
                }
            });
        }] resume];
    }];
}


- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
