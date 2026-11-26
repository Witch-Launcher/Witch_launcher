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
#import "AFNetworking.h"
#import "ElySkinHead.h"
#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "Skin3DView.h"
#import "SkinTextureManager.h"

extern NSString *ELY_OAUTH_REDIRECT_URI;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Account kind helpers

static BOOL AccountIsEly(NSDictionary *account) {
    return [account[@"accountType"] isEqualToString:@"elyby"];
}

static BOOL AccountIsDemo(NSDictionary *account) {
    return [account[@"xboxGamertag"] length] > 0 && [account[@"profileId"] isEqualToString:@"00000000-0000-0000-0000-000000000000"];
}

static BOOL AccountIsPremium(NSDictionary *account) {
    if (AccountIsEly(account)) return NO;
    // Local accounts always store the zero UUID, so a real profile UUID is the
    // most reliable premium marker — xboxGamertag is missing on accounts saved
    // by older login flows. Demo accounts have the zero UUID plus a gamertag.
    NSString *profileId = account[@"profileId"];
    if (![profileId isKindOfClass:NSString.class] || profileId.length == 0) return NO;
    if ([profileId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return [account[@"xboxGamertag"] length] > 0;
    }
    return YES;
}

static BOOL AccountIsLocal(NSDictionary *account) {
    return !AccountIsEly(account) && !AccountIsPremium(account);
}

static NSString *AccountKindText(NSDictionary *account) {
    if (AccountIsEly(account)) return localize(@"account.type.ely", nil);
    if (AccountIsDemo(account)) return localize(@"account.type.demo", nil);
    if (AccountIsPremium(account)) return localize(@"account.type.premium", nil);
    return localize(@"account.type.local", nil);
}

static UIColor *AccountKindColor(NSDictionary *account) {
    if (AccountIsEly(account)) return [UIColor colorWithRed:0.55 green:0.35 blue:0.86 alpha:1];
    if (AccountIsDemo(account)) return [UIColor colorWithRed:0.95 green:0.60 blue:0.20 alpha:1];
    if (AccountIsPremium(account)) return [UIColor colorWithRed:0.20 green:0.60 blue:0.86 alpha:1];
    return ThemeManager.shared.secondaryTextColor;
}

static NSString *AccountShortID(NSDictionary *account) {
    NSString *uuid = account[@"profileId"];
    if (![uuid isKindOfClass:[NSString class]] || uuid.length < 5) return @"";
    NSString *clean = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (clean.length <= 8) return clean;
    return [[clean substringToIndex:4] stringByAppendingFormat:@"…%@", [clean substringFromIndex:clean.length - 4]];
}

#pragma mark - Account cell

@interface AccountCell : UITableViewCell
@property (nonatomic) UIView *cardView;
@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *typeLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UIButton *selectButton;
@property (nonatomic) BOOL isSelectedAccount;
@end

@implementation AccountCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        // Inset card instead of a bare flat row: the list instantly reads as
        // modern iOS, and the selection state (accent border + tint) is much
        // clearer than a flat highlight.
        _cardView = [[UIView alloc] init];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        _cardView.layer.cornerRadius = 16;
        _cardView.layer.borderWidth = 1;
        _cardView.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
        [self.contentView addSubview:_cardView];

        _avatarView = [[UIImageView alloc] init];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.layer.cornerRadius = 14;
        _avatarView.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
        // A ring tinted by the account kind is a cheap but effective way to
        // tell Microsoft / Ely / local / demo apart before reading the badge.
        _avatarView.layer.borderWidth = 1.5;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        _nameLabel.numberOfLines = 1;
        [_cardView addSubview:_nameLabel];

        _typeLabel = [[UILabel alloc] init];
        _typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _typeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        _typeLabel.textAlignment = NSTextAlignmentCenter;
        _typeLabel.layer.cornerRadius = 9;
        _typeLabel.clipsToBounds = YES;
        [_cardView addSubview:_typeLabel];

        _detailLabel = [[UILabel alloc] init];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
        _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _detailLabel.numberOfLines = 1;
        [_cardView addSubview:_detailLabel];

        _selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _selectButton.translatesAutoresizingMaskIntoConstraints = NO;
        _selectButton.tintColor = ThemeManager.shared.secondaryTextColor;
        [_selectButton setImage:[UIImage systemImageNamed:@"circle"] forState:UIControlStateNormal];
        _selectButton.accessibilityLabel = localize(@"account.select", nil);
        [_cardView addSubview:_selectButton];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

            [_avatarView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
            [_avatarView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:44],
            [_avatarView.heightAnchor constraintEqualToConstant:44],

            [_selectButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-10],
            [_selectButton.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_selectButton.widthAnchor constraintEqualToConstant:34],
            [_selectButton.heightAnchor constraintEqualToConstant:34],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:11],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_selectButton.leadingAnchor constant:-8],

            [_typeLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_typeLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_typeLabel.heightAnchor constraintEqualToConstant:18],
            [_typeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:48],

            [_detailLabel.leadingAnchor constraintEqualToAnchor:_typeLabel.trailingAnchor constant:8],
            [_detailLabel.centerYAnchor constraintEqualToAnchor:_typeLabel.centerYAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_selectButton.leadingAnchor constant:-8],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    ThemeManager *theme = ThemeManager.shared;
    self.nameLabel.textColor = theme.primaryTextColor;
    self.detailLabel.textColor = theme.secondaryTextColor;
    if (self.isSelectedAccount) {
        self.cardView.backgroundColor = [theme.accentColor colorWithAlphaComponent:0.10];
        self.cardView.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.55].CGColor;
    } else {
        self.cardView.backgroundColor = theme.cardBackgroundColor;
        self.cardView.layer.borderColor = theme.separatorColor.CGColor;
    }
}

- (void)configureWithAccount:(NSDictionary *)account isSelected:(BOOL)isSelected {
    ThemeManager *theme = ThemeManager.shared;
    UIColor *kindColor = AccountKindColor(account);
    self.isSelectedAccount = isSelected;

    _nameLabel.text = account[@"username"] ?: localize(@"Unknown", nil);
    _typeLabel.text = [NSString stringWithFormat:@" %@ ", AccountKindText(account)];
    _typeLabel.backgroundColor = [kindColor colorWithAlphaComponent:0.16];
    _typeLabel.textColor = kindColor;
    _detailLabel.text = AccountShortID(account);

    if (isSelected) {
        _cardView.backgroundColor = [theme.accentColor colorWithAlphaComponent:0.10];
        _cardView.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.55].CGColor;
        _cardView.layer.borderWidth = 1.5;
        [_selectButton setImage:[UIImage systemImageNamed:@"checkmark.circle.fill"] forState:UIControlStateNormal];
        _selectButton.tintColor = theme.accentColor;
    } else {
        _cardView.backgroundColor = theme.cardBackgroundColor;
        _cardView.layer.borderColor = theme.separatorColor.CGColor;
        _cardView.layer.borderWidth = 1;
        [_selectButton setImage:[UIImage systemImageNamed:@"circle"] forState:UIControlStateNormal];
        _selectButton.tintColor = theme.secondaryTextColor;
    }

    NSString *username = account[@"username"] ?: @"";
    BOOL isEly = AccountIsEly(account);
    BOOL isPremium = AccountIsPremium(account);
    BOOL isDemo = AccountIsDemo(account);

    UIImage *placeholder = [UIImage systemImageNamed:isDemo ? @"exclamationmark.triangle.fill" : (isPremium ? @"person.fill.checkmark" : @"person.crop.circle")];
    _avatarView.image = placeholder;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    _avatarView.layer.borderColor = [kindColor colorWithAlphaComponent:0.45].CGColor;

    if (AccountIsLocal(account)) {
        _avatarView.image = [SkinTextureManager localHeadForUsername:username size:48];
        _avatarView.tintColor = [UIColor clearColor];
        return;
    }

    if (isEly && username.length > 0) {
        UIImage *cached = [ElySkinHead cachedHeadForUsername:username size:48];
        if (cached) {
            _avatarView.image = cached;
            _avatarView.tintColor = [UIColor clearColor];
        }
        __weak typeof(self) weakSelf = self;
        [ElySkinHead headForUsername:username size:48 completion:^(UIImage *head) {
            if (!head || !weakSelf) return;
            weakSelf.avatarView.image = head;
            weakSelf.avatarView.tintColor = [UIColor clearColor];
        }];
    } else if (isPremium && !isDemo) {
        // Use the same cached skin resolver as the 3D preview so the list and
        // the main-menu panel always show the real custom head.
        __weak typeof(self) weakSelf = self;
        [[SkinTextureManager shared] headImageForAccount:account size:48 completion:^(UIImage *head) {
            if (!head || !weakSelf) return;
            weakSelf.avatarView.image = head;
            weakSelf.avatarView.tintColor = [UIColor clearColor];
        }];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _avatarView.image = nil;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    _nameLabel.text = nil;
    _typeLabel.text = nil;
    _detailLabel.text = nil;
    ThemeManager *theme = ThemeManager.shared;
    _cardView.backgroundColor = theme.cardBackgroundColor;
    _cardView.layer.borderColor = theme.separatorColor.CGColor;
    _cardView.layer.borderWidth = 1;
    _typeLabel.textColor = UIColor.whiteColor;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

#pragma mark - Account detail sheet

@interface AccountDetailViewController : UIViewController
@property (nonatomic, strong) NSDictionary *account;
@end

@interface AccountDetailViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIView *contentView;
@property (nonatomic) UIStackView *rootStack;
@property (nonatomic) UIView *stageContainer;
@property (nonatomic) Skin3DView *skin3D;
@property (nonatomic) UIButton *closeButton;
@property (nonatomic) UIButton *autoRotateButton;
@property (nonatomic) UILabel *typeBadge;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UIButton *renameButton;
@property (nonatomic) UIView *uuidChip;
@property (nonatomic) UILabel *uuidLabel;
@property (nonatomic) UIButton *uuidCopyButton;
@property (nonatomic) UIButton *selectAccountButton;
@property (nonatomic) UIView *localSkinRow;
@property (nonatomic) UIButton *steveButton;
@property (nonatomic) UIButton *alexButton;
@property (nonatomic) UIButton *skinButton;
@property (nonatomic) UIButton *capeButton;
@property (nonatomic) UIButton *openElyButton;
@property (nonatomic) UIButton *deleteGridButton;
@property (nonatomic) UIView *bottomBar;
@property (nonatomic) NSLayoutConstraint *stageWidthConstraint;
@property (nonatomic) NSLayoutConstraint *stageHeightConstraint;
@property (nonatomic) BOOL wideLayout;
@property (nonatomic) BOOL layoutConfigured;
@property (nonatomic, nullable) NSString *pendingSkinVariant;
@property (nonatomic) BOOL skinManagerWebViewActive;
@property (nonatomic, nullable) WKWebView *loginWebView;
@end

@interface AccountViewController (AccountDetailDelegate)
@property (nonatomic) BOOL elyOAuthFlowActive;
- (void)presentLoginWebViewWithURL:(NSURL *)url title:(NSString *)title;
- (void)presentCapePickerWithProfile:(NSDictionary *)profile accessToken:(NSString *)accessToken sourceView:(UIView *)sourceView;
- (void)ensureFreshMSTokenForAccount:(NSDictionary *)account completion:(void (^)(NSString * _Nullable accessToken))completion;
- (void)deleteAccountByUsername:(NSString *)username;
- (void)selectAccount:(NSDictionary *)account showToast:(BOOL)showToast;
@end

@implementation AccountDetailViewController

#pragma mark - View lifecycle & layout

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    _closeButton.tintColor = ThemeManager.shared.primaryTextColor;
    _closeButton.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.14];
    _closeButton.layer.cornerRadius = 18;
    _closeButton.accessibilityLabel = localize(@"Close", nil);
    [_closeButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    // No rubber-band: pulling down must not drag the page/panel around; it
    // only scrolls when the content is actually taller than the screen.
    _scrollView.alwaysBounceVertical = NO;
    _scrollView.bounces = NO;
    [_scrollView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];

    [self buildStage];
    UIView *info = [self buildInfoContainer];
    info.translatesAutoresizingMaskIntoConstraints = NO;

    _rootStack = [[UIStackView alloc] initWithArrangedSubviews:@[_stageContainer, info]];
    _rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    _rootStack.axis = UILayoutConstraintAxisVertical;
    _rootStack.alignment = UIStackViewAlignmentFill;
    _rootStack.spacing = 16.0;
    [_contentView addSubview:_rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [_closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [_closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [_closeButton.widthAnchor constraintEqualToConstant:36],
        [_closeButton.heightAnchor constraintEqualToConstant:36],

        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:2],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],
        [_contentView.heightAnchor constraintGreaterThanOrEqualToAnchor:_scrollView.frameLayoutGuide.heightAnchor],

        [_rootStack.topAnchor constraintEqualToAnchor:_contentView.topAnchor],
        [_rootStack.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor],
        [_rootStack.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor],
        [_rootStack.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-16],

        [_stageContainer.heightAnchor constraintGreaterThanOrEqualToConstant:340],
    ]];

    [self.view bringSubviewToFront:_closeButton];
    [self updateColors];
    [self populateAccount];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)buildStage {
    _stageContainer = [[UIView alloc] init];
    _stageContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _stageContainer.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _stageContainer.layer.cornerRadius = 18;
    _stageContainer.layer.borderWidth = 1;
    _stageContainer.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _stageContainer.clipsToBounds = YES;

    CAGradientLayer *tint = [CAGradientLayer layer];
    tint.name = @"stageTint";
    tint.colors = @[(id)[ThemeManager.shared.accentColor colorWithAlphaComponent:0.20].CGColor,
                    (id)[ThemeManager.shared.accentColor colorWithAlphaComponent:0.02].CGColor];
    tint.startPoint = CGPointMake(0.5, 0.0);
    tint.endPoint = CGPointMake(0.5, 1.0);
    [_stageContainer.layer insertSublayer:tint atIndex:0];

    _skin3D = [[Skin3DView alloc] init];
    _skin3D.translatesAutoresizingMaskIntoConstraints = NO;
    [_stageContainer addSubview:_skin3D];

    _typeBadge = [[UILabel alloc] init];
    _typeBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _typeBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    _typeBadge.textColor = UIColor.whiteColor;
    _typeBadge.textAlignment = NSTextAlignmentCenter;
    _typeBadge.layer.cornerRadius = 8;
    _typeBadge.clipsToBounds = YES;
    [_stageContainer addSubview:_typeBadge];

    UILabel *dragHint = [[UILabel alloc] init];
    dragHint.translatesAutoresizingMaskIntoConstraints = NO;
    dragHint.text = localize(@"account.drag_hint", nil);
    dragHint.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
    dragHint.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    dragHint.textAlignment = NSTextAlignmentCenter;
    dragHint.numberOfLines = 1;
    dragHint.adjustsFontSizeToFitWidth = YES;
    dragHint.minimumScaleFactor = 0.7;
    [_stageContainer addSubview:dragHint];

    [NSLayoutConstraint activateConstraints:@[
        [_skin3D.leadingAnchor constraintEqualToAnchor:_stageContainer.leadingAnchor],
        [_skin3D.trailingAnchor constraintEqualToAnchor:_stageContainer.trailingAnchor],
        [_skin3D.topAnchor constraintEqualToAnchor:_stageContainer.topAnchor],
        [_skin3D.bottomAnchor constraintEqualToAnchor:_stageContainer.bottomAnchor],

        [_typeBadge.topAnchor constraintEqualToAnchor:_stageContainer.topAnchor constant:14],
        [_typeBadge.leadingAnchor constraintEqualToAnchor:_stageContainer.leadingAnchor constant:14],
        [_typeBadge.heightAnchor constraintEqualToConstant:22],
        [_typeBadge.widthAnchor constraintGreaterThanOrEqualToConstant:62],

        [dragHint.bottomAnchor constraintEqualToAnchor:_stageContainer.bottomAnchor constant:-10],
        [dragHint.centerXAnchor constraintEqualToAnchor:_stageContainer.centerXAnchor],
        [dragHint.leadingAnchor constraintGreaterThanOrEqualToAnchor:_stageContainer.leadingAnchor constant:12],
        [dragHint.trailingAnchor constraintLessThanOrEqualToAnchor:_stageContainer.trailingAnchor constant:-12],
    ]];
}

- (UIButton *)actionCircleWithIcon:(NSString *)icon tint:(UIColor *)tint action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    button.tintColor = tint;
    button.backgroundColor = [tint colorWithAlphaComponent:0.16];
    button.layer.cornerRadius = 29;
    [button.widthAnchor constraintEqualToConstant:58].active = YES;
    [button.heightAnchor constraintEqualToConstant:58].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIStackView *)actionItemWithButton:(UIButton *)button title:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    label.textColor = ThemeManager.shared.secondaryTextColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    label.userInteractionEnabled = NO;
    UIStackView *item = [[UIStackView alloc] initWithArrangedSubviews:@[button, label]];
    item.axis = UILayoutConstraintAxisVertical;
    item.alignment = UIStackViewAlignmentCenter;
    item.spacing = 5;
    [item.widthAnchor constraintEqualToConstant:74].active = YES;
    return item;
}

- (UIButton *)faceSwatchSlim:(BOOL)slim tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setImage:[SkinTextureManager bundledDefaultHeadSlim:slim size:44] forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFill;
    button.layer.cornerRadius = 12;
    button.clipsToBounds = YES;
    button.tag = tag;
    button.layer.borderWidth = 1;
    button.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    [button addTarget:self action:@selector(modelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:44].active = YES;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;
    return button;
}

- (UIView *)buildInfoContainer {
    UIView *info = [[UIView alloc] init];
    info.backgroundColor = UIColor.clearColor;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBold];
    nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    nameLabel.numberOfLines = 1;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.6;
    _nameLabel = nameLabel;

    _renameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _renameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_renameButton setImage:[UIImage systemImageNamed:@"pencil"] forState:UIControlStateNormal];
    _renameButton.tintColor = ThemeManager.shared.accentColor;
    _renameButton.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _renameButton.layer.cornerRadius = 17;
    _renameButton.layer.borderWidth = 1;
    _renameButton.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _renameButton.accessibilityLabel = localize(@"Edit", nil);
    [_renameButton addTarget:self action:@selector(editNameTapped) forControlEvents:UIControlEventTouchUpInside];
    [_renameButton.widthAnchor constraintEqualToConstant:34].active = YES;
    [_renameButton.heightAnchor constraintEqualToConstant:34].active = YES;

    UIView *nameRow = [[UIView alloc] init];
    [nameRow addSubview:nameLabel];
    [nameRow addSubview:_renameButton];
    [NSLayoutConstraint activateConstraints:@[
        [nameLabel.leadingAnchor constraintEqualToAnchor:nameRow.leadingAnchor],
        [nameLabel.centerYAnchor constraintEqualToAnchor:nameRow.centerYAnchor],
        [nameLabel.trailingAnchor constraintEqualToAnchor:_renameButton.leadingAnchor constant:-10],
        [_renameButton.trailingAnchor constraintEqualToAnchor:nameRow.trailingAnchor],
        [_renameButton.centerYAnchor constraintEqualToAnchor:nameRow.centerYAnchor],
        [nameRow.heightAnchor constraintGreaterThanOrEqualToConstant:40],
    ]];

    _uuidChip = [[UIView alloc] init];
    _uuidChip.translatesAutoresizingMaskIntoConstraints = NO;
    _uuidChip.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    _uuidChip.layer.cornerRadius = 11;
    _uuidChip.layer.borderWidth = 1;
    _uuidChip.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;

    _uuidLabel = [[UILabel alloc] init];
    _uuidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _uuidLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    _uuidLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _uuidLabel.numberOfLines = 1;
    _uuidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_uuidChip addSubview:_uuidLabel];

    _uuidCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _uuidCopyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_uuidCopyButton setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    _uuidCopyButton.tintColor = ThemeManager.shared.accentColor;
    _uuidCopyButton.accessibilityLabel = localize(@"account.screen.copy_uuid", nil);
    [_uuidCopyButton addTarget:self action:@selector(copyUUIDTapped) forControlEvents:UIControlEventTouchUpInside];
    [_uuidChip addSubview:_uuidCopyButton];

    [NSLayoutConstraint activateConstraints:@[
        [_uuidChip.heightAnchor constraintEqualToConstant:38],
        [_uuidLabel.leadingAnchor constraintEqualToAnchor:_uuidChip.leadingAnchor constant:12],
        [_uuidLabel.centerYAnchor constraintEqualToAnchor:_uuidChip.centerYAnchor],
        [_uuidLabel.trailingAnchor constraintEqualToAnchor:_uuidCopyButton.leadingAnchor constant:-4],
        [_uuidCopyButton.trailingAnchor constraintEqualToAnchor:_uuidChip.trailingAnchor constant:-4],
        [_uuidCopyButton.centerYAnchor constraintEqualToAnchor:_uuidChip.centerYAnchor],
        [_uuidCopyButton.widthAnchor constraintEqualToConstant:30],
        [_uuidCopyButton.heightAnchor constraintEqualToConstant:30],
    ]];

    _selectAccountButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _selectAccountButton.translatesAutoresizingMaskIntoConstraints = NO;
    _selectAccountButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _selectAccountButton.layer.cornerRadius = 14;
    _selectAccountButton.layer.borderWidth = 1;
    [_selectAccountButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [_selectAccountButton addTarget:self action:@selector(selectAccountTapped) forControlEvents:UIControlEventTouchUpInside];

    _skinButton = [self actionCircleWithIcon:@"paintbrush.pointed.fill" tint:ThemeManager.shared.accentColor action:@selector(changeSkinTapped)];
    _capeButton = [self actionCircleWithIcon:@"sparkles" tint:[UIColor systemPurpleColor] action:@selector(changeCapeTapped)];
    _openElyButton = [self actionCircleWithIcon:@"globe" tint:[UIColor systemIndigoColor] action:@selector(openElyTapped)];
    _deleteGridButton = [self actionCircleWithIcon:@"trash" tint:ThemeManager.shared.errorColor action:@selector(deleteTapped)];

    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self actionItemWithButton:_skinButton title:localize(@"skin.change", nil)],
        [self actionItemWithButton:_capeButton title:localize(@"cape.change", nil)],
        [self actionItemWithButton:_openElyButton title:localize(@"account.action.ely_short", nil)],
        [self actionItemWithButton:_deleteGridButton title:localize(@"Delete", nil)],
    ]];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.alignment = UIStackViewAlignmentCenter;
    actions.distribution = UIStackViewDistributionEqualSpacing;
    actions.spacing = 12;

    // Bottom bar: default-skin picker (local accounts) + auto-rotate pill.
    _localSkinRow = [[UIView alloc] init];
    _localSkinRow.translatesAutoresizingMaskIntoConstraints = NO;
    [_localSkinRow.heightAnchor constraintEqualToConstant:44].active = YES;

    UILabel *localLabel = [[UILabel alloc] init];
    localLabel.translatesAutoresizingMaskIntoConstraints = NO;
    localLabel.text = localize(@"account.local_model_title", nil);
    localLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    localLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [_localSkinRow addSubview:localLabel];

    _steveButton = [self faceSwatchSlim:NO tag:0];
    _alexButton = [self faceSwatchSlim:YES tag:1];
    [_localSkinRow addSubview:_steveButton];
    [_localSkinRow addSubview:_alexButton];

    [NSLayoutConstraint activateConstraints:@[
        [localLabel.leadingAnchor constraintEqualToAnchor:_localSkinRow.leadingAnchor],
        [localLabel.centerYAnchor constraintEqualToAnchor:_localSkinRow.centerYAnchor],
        [localLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_steveButton.leadingAnchor constant:-10],

        [_alexButton.trailingAnchor constraintEqualToAnchor:_localSkinRow.trailingAnchor],
        [_alexButton.centerYAnchor constraintEqualToAnchor:_localSkinRow.centerYAnchor],
        [_steveButton.trailingAnchor constraintEqualToAnchor:_alexButton.leadingAnchor constant:-8],
        [_steveButton.centerYAnchor constraintEqualToAnchor:_localSkinRow.centerYAnchor],
    ]];
    _localSkinRow.hidden = YES;

    _autoRotateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _autoRotateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_autoRotateButton setTitle:localize(@"account.auto_rotate", nil) forState:UIControlStateNormal];
    _autoRotateButton.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    _autoRotateButton.layer.cornerRadius = 16;
    _autoRotateButton.layer.borderWidth = 1;
    _autoRotateButton.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [_autoRotateButton.heightAnchor constraintEqualToConstant:32].active = YES;
    _autoRotateButton.accessibilityLabel = localize(@"account.auto_rotate", nil);
    [_autoRotateButton addTarget:self action:@selector(autoRotateTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *bottomSpacer = [[UIView alloc] init];
    [bottomSpacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];

    _bottomBar = [[UIStackView alloc] initWithArrangedSubviews:@[_localSkinRow, bottomSpacer, _autoRotateButton]];
    ((UIStackView *)_bottomBar).axis = UILayoutConstraintAxisHorizontal;
    ((UIStackView *)_bottomBar).alignment = UIStackViewAlignmentCenter;
    ((UIStackView *)_bottomBar).spacing = 12;

    UIView *spacer = [[UIView alloc] init];
    [spacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        nameRow, _uuidChip, _selectAccountButton, actions, _bottomBar, spacer,
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14;
    [stack setCustomSpacing:10 afterView:nameRow];
    [stack setCustomSpacing:18 afterView:_selectAccountButton];
    [info addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:info.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:info.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:info.trailingAnchor constant:-20],
        // Exact bottom: a plain UIView with only a <= bottom under a vertical
        // stack collapses to zero height and its children stop being tappable.
        [stack.bottomAnchor constraintEqualToAnchor:info.bottomAnchor],
    ]];
    return info;
}

- (void)updateLayoutForWidth:(CGFloat)width {
    BOOL wide = width >= 640.0;
    if (_layoutConfigured && wide == _wideLayout) return;
    _layoutConfigured = YES;
    _wideLayout = wide;

    _stageWidthConstraint.active = NO;
    _stageHeightConstraint.active = NO;
    _stageWidthConstraint = nil;
    _stageHeightConstraint = nil;

    _rootStack.axis = wide ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    _rootStack.spacing = wide ? 22.0 : 16.0;
    if (wide) {
        _stageWidthConstraint = [_stageContainer.widthAnchor constraintEqualToAnchor:_rootStack.widthAnchor multiplier:0.46];
        _stageWidthConstraint.active = YES;
    } else {
        _stageHeightConstraint = [_stageContainer.heightAnchor constraintEqualToConstant:340];
        _stageHeightConstraint.active = YES;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateLayoutForWidth:self.view.bounds.size.width];
    for (CALayer *layer in _stageContainer.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]] && [layer.name isEqualToString:@"stageTint"]) {
            layer.frame = _stageContainer.bounds;
        }
    }
}

#pragma mark - Populate & skin

- (Skin3DModel)preferredModel {
    if (AccountIsLocal(_account) || AccountIsDemo(_account)) {
        NSString *username = _account[@"username"] ?: @"";
        return [SkinTextureManager localPrefersSlimForUsername:username] ? Skin3DModelSlim : Skin3DModelClassic;
    }
    return Skin3DModelClassic;
}

- (void)refreshSkinPreview {
    __weak typeof(self) weakSelf = self;
    [[SkinTextureManager shared] skinImageForAccount:self.account completion:^(UIImage *image) {
        if (!weakSelf) return;
        [weakSelf.skin3D setSkinImage:image model:[weakSelf preferredModel]];
    }];
}

- (void)populateAccount {
    NSDictionary *account = _account;
    BOOL isEly = AccountIsEly(account);
    BOOL isPremium = AccountIsPremium(account);
    BOOL isDemo = AccountIsDemo(account);
    BOOL isLocal = AccountIsLocal(account);

    _typeBadge.text = [NSString stringWithFormat:@"  %@  ", AccountKindText(account)];
    _typeBadge.backgroundColor = AccountKindColor(account);

    _nameLabel.text = account[@"username"] ?: @"";

    NSString *uuid = account[@"profileId"] ?: @"N/A";
    NSString *maskedUuid = (uuid.length > 4) ? [NSString stringWithFormat:@"%@***%@", [uuid substringToIndex:2], [uuid substringFromIndex:uuid.length - 2]] : uuid;
    _uuidLabel.text = [NSString stringWithFormat:@"UUID  %@", maskedUuid];

    // Local accounts: Steve/Alex picker for the default skin render.
    BOOL useDefaultSkin = isLocal || isDemo;
    _localSkinRow.hidden = !useDefaultSkin;
    if (useDefaultSkin) {
        NSString *username = account[@"username"] ?: @"";
        [self updateModelSelectionSlim:[SkinTextureManager localPrefersSlimForUsername:username]];
    }

    // Per-type action visibility. Renaming works for local accounts too (the
    // pencil next to the name, file renamed with the display name). Local and
    // demo accounts cannot upload a skin, so they get no skin button — their
    // default Steve/Alex skin is chosen in the bottom bar.
    _skinButton.hidden = isLocal || isDemo;
    _capeButton.hidden = isEly || isLocal || isDemo;
    _renameButton.hidden = isDemo;
    _openElyButton.hidden = !isEly;
    _selectAccountButton.hidden = isDemo;

    [self updateSelectButton];
    [self refreshSkinPreview];
}

- (void)updateModelSelectionSlim:(BOOL)slim {
    ThemeManager *theme = ThemeManager.shared;
    _steveButton.layer.borderColor = (slim ? theme.separatorColor : theme.accentColor).CGColor;
    _steveButton.layer.borderWidth = slim ? 1.0 : 2.5;
    _alexButton.layer.borderColor = (slim ? theme.accentColor : theme.separatorColor).CGColor;
    _alexButton.layer.borderWidth = slim ? 2.5 : 1.0;
    _steveButton.alpha = slim ? 0.75 : 1.0;
    _alexButton.alpha = slim ? 1.0 : 0.75;
}

- (void)modelButtonTapped:(UIButton *)sender {
    BOOL slim = (sender.tag == 1);
    NSString *username = _account[@"username"] ?: @"";
    [[NSUserDefaults standardUserDefaults] setObject:(slim ? @"alex" : @"steve")
                                              forKey:[NSString stringWithFormat:@"account.local_skin_model.%@", username.lowercaseString]];
    [self updateModelSelectionSlim:slim];
    [self refreshSkinPreview];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (BOOL)isCurrentlySelectedAccount {
    NSString *selected = getPrefObject(@"internal.selected_account");
    return [selected isEqualToString:_account[@"username"]];
}

- (void)updateSelectButton {
    BOOL selected = [self isCurrentlySelectedAccount];
    ThemeManager *theme = ThemeManager.shared;
    if (selected) {
        [_selectAccountButton setTitle:[NSString stringWithFormat:@"✓  %@", localize(@"account.in_use", nil)] forState:UIControlStateNormal];
        _selectAccountButton.backgroundColor = [theme.accentColor colorWithAlphaComponent:0.15];
        [_selectAccountButton setTitleColor:theme.accentColor forState:UIControlStateNormal];
        _selectAccountButton.layer.borderColor = [theme.accentColor colorWithAlphaComponent:0.4].CGColor;
        _selectAccountButton.userInteractionEnabled = NO;
    } else {
        [_selectAccountButton setTitle:localize(@"account.set_active", nil) forState:UIControlStateNormal];
        _selectAccountButton.backgroundColor = theme.accentColor;
        [_selectAccountButton setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
        _selectAccountButton.layer.borderColor = UIColor.clearColor.CGColor;
        _selectAccountButton.userInteractionEnabled = YES;
    }
}

- (void)selectAccountTapped {
    AccountViewController *parent = (AccountViewController *)self.presentingViewController;
    [parent selectAccount:_account showToast:YES];
    [_selectAccountButton.superview setNeedsLayout];
    [self updateSelectButton];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (void)autoRotateTapped {
    _skin3D.autoRotate = !_skin3D.autoRotate;
    [HapticManager.shared play:HapticTypeSelection];
    [self updateAutoRotateStyle];
}

- (void)updateAutoRotateStyle {
    ThemeManager *theme = ThemeManager.shared;
    BOOL on = _skin3D.autoRotate;
    _autoRotateButton.backgroundColor = on ? [theme.accentColor colorWithAlphaComponent:0.18] : theme.cardBackgroundColor;
    [_autoRotateButton setTitleColor:(on ? theme.accentColor : theme.secondaryTextColor) forState:UIControlStateNormal];
    _autoRotateButton.layer.borderColor = (on ? [theme.accentColor colorWithAlphaComponent:0.5] : theme.separatorColor).CGColor;
}

- (void)openElyTapped {
    NSURL *url = [NSURL URLWithString:@"https://ely.by/"];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _scrollView.backgroundColor = theme.contentBackgroundColor;
    _contentView.backgroundColor = theme.contentBackgroundColor;
    _stageContainer.backgroundColor = theme.cardBackgroundColor;
    _stageContainer.layer.borderColor = theme.separatorColor.CGColor;
    _nameLabel.textColor = theme.primaryTextColor;
    _uuidLabel.textColor = theme.secondaryTextColor;
    _uuidChip.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    _uuidChip.layer.borderColor = theme.separatorColor.CGColor;
    _uuidCopyButton.tintColor = theme.accentColor;
    _renameButton.tintColor = theme.accentColor;
    _renameButton.backgroundColor = theme.cardBackgroundColor;
    _renameButton.layer.borderColor = theme.separatorColor.CGColor;
    [self updateAutoRotateStyle];
    _typeBadge.backgroundColor = AccountKindColor(_account);
    for (CALayer *sublayer in _stageContainer.layer.sublayers) {
        if ([sublayer isKindOfClass:[CAGradientLayer class]] && [sublayer.name isEqualToString:@"stageTint"]) {
            ((CAGradientLayer *)sublayer).colors = @[(id)[theme.accentColor colorWithAlphaComponent:0.20].CGColor,
                                                     (id)[theme.accentColor colorWithAlphaComponent:0.02].CGColor];
        }
    }
    _deleteGridButton.tintColor = theme.errorColor;
    _deleteGridButton.backgroundColor = [theme.errorColor colorWithAlphaComponent:0.16];
    [self updateSelectButton];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:kbFrame fromView:self.view.window];
    CGFloat overlap = self.view.frame.size.height - converted.origin.y;
    if (overlap <= 0) return;
    _scrollView.contentInset = UIEdgeInsetsMake(0, 0, overlap, 0);
    _scrollView.scrollIndicatorInsets = _scrollView.contentInset;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyUUIDTapped {
    NSString *uuid = _account[@"profileId"] ?: @"";
    [UIPasteboard generalPasteboard].string = uuid;
    [HapticManager.shared play:HapticTypeSuccess];
    [ErrorPresenter showToast:localize(@"account.screen.uuid_copied", nil) success:YES];
}

- (void)changeSkinTapped {
    if (AccountIsLocal(_account) || AccountIsDemo(_account)) {
        NSString *username = _account[@"username"] ?: @"";
        [AppSheet showOptionsWithTitle:localize(@"account.local_model_title", nil) message:nil options:@[
            @{@"title": @"Steve", @"icon": @"person"},
            @{@"title": @"Alex", @"icon": @"person.fill"},
        ] selectedIndex:([SkinTextureManager localPrefersSlimForUsername:username] ? 1 : 0) selection:^(NSInteger idx) {
            NSString *value = (idx == 1) ? @"alex" : @"steve";
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:[NSString stringWithFormat:@"account.local_skin_model.%@", username.lowercaseString]];
            [self updateModelSelectionSlim:(idx == 1)];
            [self refreshSkinPreview];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
        }];
        return;
    }
    BOOL isEly = [_account[@"accountType"] isEqualToString:@"elyby"];
    if (isEly) {
        self.skinManagerWebViewActive = YES;
        AccountViewController *parent = (AccountViewController *)self.presentingViewController;
        parent.elyOAuthFlowActive = NO;
        [parent presentLoginWebViewWithURL:[NSURL URLWithString:@"https://account.ely.by/"] title:@"ely.by Skin Manager"];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [AppSheet showOptionsWithTitle:localize(@"skin.model_title", nil) message:localize(@"skin.choose_model_hint", nil) options:@[
        @{@"title": localize(@"skin.model_classic", nil), @"icon": @"person"},
        @{@"title": localize(@"skin.model_slim", nil), @"icon": @"person.fill"},
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        self.pendingSkinVariant = (idx == 0) ? @"classic" : @"slim";
        [self presentImagePickerForCape:NO];
    }];
}

- (void)changeCapeTapped {
    BOOL isEly = [_account[@"accountType"] isEqualToString:@"elyby"];
    if (isEly) {
        showDialog(@"Capes",
            @"Ely.by manages capes centrally: players cannot equip, upload or change capes themselves. Capes are granted automatically by the Ely.by system (events, donations and so on) and will show up on your character automatically.");
        return;
    }

    AccountViewController *parent = (AccountViewController *)self.presentingViewController;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:localize(@"progress.loading_capes", nil)];
    [parent ensureFreshMSTokenForAccount:self.account completion:^(NSString *accessToken) {
        if (accessToken.length == 0) {
            [overlay dismiss];
            showDialog(@"Error", @"Failed to retrieve access token. Please re-login.");
            return;
        }
        NSDictionary *headers = @{ @"Authorization": [NSString stringWithFormat:@"Bearer %@", accessToken] };
        AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
        [manager GET:@"https://api.minecraftservices.com/minecraft/profile" parameters:nil headers:headers progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [overlay dismiss];
                [parent presentCapePickerWithProfile:response accessToken:accessToken sourceView:self.capeButton];
                [self dismissViewControllerAnimated:YES completion:nil];
            });
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [overlay dismiss];
                showDialog(@"Error", error.localizedDescription ?: @"Failed to fetch profile.");
            });
        }];
    }];
}

- (void)editNameTapped {
    NSString *oldName = _account[@"username"] ?: @"";
    [AppSheet showPromptWithTitle:localize(@"Edit", nil) message:localize(@"account.screen.profile", nil) placeholder:localize(@"account.username.placeholder", nil) initialText:oldName onConfirm:^(NSString *text) {
        NSString *name = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) {
            showDialog(@"Error", @"Name cannot be empty.");
            return;
        }
        if ([name isEqualToString:oldName]) return;
        NSString *oldPath = amethyst_hidden_path([NSString stringWithFormat:@"accounts/%@.json", oldName]);
        NSString *newPath = amethyst_hidden_path([NSString stringWithFormat:@"accounts/%@.json", name]);
        if ([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            showDialog(@"Error", @"An account with that name already exists.");
            return;
        }
        NSMutableDictionary *data = parseJSONFromFile(oldPath);
        if (!data || data[@"NSErrorObject"]) {
            showDialog(@"Error", @"Could not read the account file.");
            return;
        }
        data[@"username"] = name;
        NSError *saveError = saveJSONToFile(data, newPath);
        if (saveError) {
            showDialog(@"Error", saveError.localizedDescription ?: @"Could not save the account.");
            return;
        }
        [[NSFileManager defaultManager] removeItemAtPath:oldPath error:nil];
        if ([getPrefObject(@"internal.selected_account") isEqualToString:oldName]) {
            setPrefObject(@"internal.selected_account", name);
            [BaseAuthenticator loadSavedName:name];
        }
        _account = data;
        [self populateAccount];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
        showDialog(localize(@"Success", nil), localize(@"account.name_updated", nil));
    }];
}

- (void)deleteTapped {
    [AppSheet showConfirmWithTitle:localize(@"account.delete_title", nil)
                           message:[NSString stringWithFormat:@"Delete '%@'?", _account[@"username"]]
                     confirmTitle:localize(@"Delete", nil)
                      destructive:YES
                        onConfirm:^{
                            AccountViewController *parent = (AccountViewController *)self.presentingViewController;
                            [self dismissViewControllerAnimated:YES completion:nil];
                            [parent deleteAccountByUsername:_account[@"username"]];
                        }];
}

- (void)presentImagePickerForCape:(BOOL)forCape {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
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
    NSString *uuid = _account[@"profileId"];
    NSString *xuid = _account[@"xuid"];
    if (AccountIsLocal(_account)) {
        // Local accounts have no online profile to upload to.
        showDialog(@"Offline Account", @"Skins can only be uploaded for online (Microsoft / Ely.by) accounts. Local accounts use the Steve or Alex default skin.");
        return;
    }
    if (!uuid || !xuid) {
        showDialog(@"Error", @"Missing account profile information.");
        return;
    }
    NSString *variant = self.pendingSkinVariant ?: @"classic";
    self.pendingSkinVariant = nil;
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        showDialog(@"Error", @"Failed to process image.");
        return;
    }
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:localize(@"progress.uploading_skin", nil)];
    [overlay updateProgress:0 message:localize(@"progress.msg.refreshing", nil)];
    __weak typeof(self) weakSelf = self;
    NSString *capturedVariant = variant;
    AccountViewController *parent = (AccountViewController *)self.presentingViewController;
    [parent ensureFreshMSTokenForAccount:self.account completion:^(NSString *accessToken) {
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
        [overlay updateProgress:0.5 message:localize(@"progress.msg.uploading", nil)];
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
                    [overlay finishWithMessage:localize(@"skin.updated", nil)];
                    // Evict the stale cached texture so the new skin shows up.
                    [[SkinTextureManager shared] evictCachedSkinForAccount:weakSelf.account];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [overlay dismiss];
                        showDialog(localize(@"Success", nil), localize(@"account.screen.skin_uploaded_desc", nil));
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
                        [weakSelf refreshSkinPreview];
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#pragma mark - AccountViewController

@interface AccountViewController () <UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, WKNavigationDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *accountsArray;
@property (nonatomic) UIView *headerView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *subtitleLabel;
@property (nonatomic) UIButton *addButton;
@property (nonatomic) UIButton *closeButton;
@property (nonatomic) UIView *emptyStateView;
@property (nonatomic) UIView *addFormView;
@property (nonatomic) UIScrollView *formScrollView;
@property (nonatomic) UIView *formContentView;
@property (nonatomic) NSLayoutConstraint *formHeightConstraint;
@property (nonatomic) BOOL keyboardVisible;
@property (nonatomic) CGFloat keyboardOverlap;
@property (nonatomic) UISegmentedControl *addTypeControl;
@property (nonatomic) UITextField *usernameField;
@property (nonatomic) UITextField *passwordField;
@property (nonatomic) UIButton *addActionBtn;
@property (nonatomic) UIButton *oauthLinkBtn;
@property (nonatomic) UIButton *closeFormButton;
@property (nonatomic) NSLayoutConstraint *passwordTopConstraint;
@property (nonatomic) NSLayoutConstraint *passwordHeightConstraint;
@property (nonatomic) NSLayoutConstraint *oauthTopConstraint;
@property (nonatomic) NSLayoutConstraint *oauthHeightConstraint;
@property (nonatomic) NSLayoutConstraint *formBottomConstraint;
@property (nonatomic, nullable) WKWebView *loginWebView;
@property (nonatomic) BOOL elyOAuthFlowActive;
@property (nonatomic) BOOL showingAddForm;
@end

@implementation AccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];

    [self setupHeader];
    [self setupTableView];
    [self setupEmptyState];
    // The FAB is created with the header, so hoist it above the list views
    // (but below the add-account form).
    [self.view bringSubviewToFront:_addButton];
    [self setupAddForm];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountListChanged) name:@"AccountDidChangeNotification" object:nil];

    [self updateColors];
    [self loadAccounts];
}

- (void)setupHeader {
    _headerView = [[UIView alloc] init];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_headerView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = localize(@"account.title", nil);
    _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    [_headerView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.text = localize(@"account.screen.subtitle", nil);
    _subtitleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    _subtitleLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [_headerView addSubview:_subtitleLabel];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    _closeButton.tintColor = ThemeManager.shared.primaryTextColor;
    _closeButton.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.14];
    _closeButton.layer.cornerRadius = 17;
    _closeButton.accessibilityLabel = localize(@"Close", nil);
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_headerView addSubview:_closeButton];

    // Floating action button, bottom-right: saves the whole toolbar row.
    _addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    _addButton.tintColor = ThemeManager.shared.buttonTextColor;
    _addButton.backgroundColor = ThemeManager.shared.accentColor;
    _addButton.layer.cornerRadius = 26;
    _addButton.layer.shadowColor = UIColor.blackColor.CGColor;
    _addButton.layer.shadowOpacity = 0.28;
    _addButton.layer.shadowRadius = 12;
    _addButton.layer.shadowOffset = CGSizeMake(0, 5);
    _addButton.accessibilityLabel = localize(@"account.screen.add_account", nil);
    [_addButton addTarget:self action:@selector(addButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_addButton];

    [NSLayoutConstraint activateConstraints:@[
        [_headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_headerView.heightAnchor constraintEqualToConstant:72],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:20],
        [_titleLabel.topAnchor constraintEqualToAnchor:_headerView.topAnchor constant:10],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:21],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_closeButton.leadingAnchor constant:-12],

        [_closeButton.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-20],
        [_closeButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_closeButton.widthAnchor constraintEqualToConstant:34],
        [_closeButton.heightAnchor constraintEqualToConstant:34],

        [_addButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-22],
        [_addButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-22],
        [_addButton.widthAnchor constraintEqualToConstant:52],
        [_addButton.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = 80;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(6, 0, 96, 0);
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerClass:[AccountCell class] forCellReuseIdentifier:@"AccountCell"];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] init];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *iconCfg = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIFontWeightMedium];
    icon.image = [UIImage systemImageNamed:@"person.crop.circle" withConfiguration:iconCfg];
    icon.tintColor = ThemeManager.shared.accentColor;
    icon.contentMode = UIViewContentModeCenter;
    icon.backgroundColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.10];
    icon.layer.cornerRadius = 28;
    icon.layer.borderWidth = 1.5;
    icon.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.25].CGColor;
    [_emptyStateView addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = localize(@"account.empty_title", nil);
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textColor = ThemeManager.shared.primaryTextColor;
    title.textAlignment = NSTextAlignmentCenter;
    [_emptyStateView addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = localize(@"account.empty_subtitle", nil);
    subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subtitle.textColor = ThemeManager.shared.secondaryTextColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 2;
    [_emptyStateView addSubview:subtitle];

    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addButton setTitle:localize(@"account.screen.add_account", nil) forState:UIControlStateNormal];
    addButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    addButton.tintColor = ThemeManager.shared.buttonTextColor;
    addButton.backgroundColor = ThemeManager.shared.accentColor;
    addButton.layer.cornerRadius = 23;
    addButton.layer.shadowColor = ThemeManager.shared.accentColor.CGColor;
    addButton.layer.shadowOpacity = 0.4;
    addButton.layer.shadowRadius = 10;
    addButton.layer.shadowOffset = CGSizeMake(0, 4);
    [addButton addTarget:self action:@selector(addButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_emptyStateView addSubview:addButton];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, title, subtitle, addButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16;
    [stack setCustomSpacing:8 afterView:icon];
    [stack setCustomSpacing:3 afterView:title];
    [_emptyStateView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
        [_emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_emptyStateView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:_emptyStateView.centerYAnchor constant:-24],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:_emptyStateView.leadingAnchor constant:32],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:_emptyStateView.trailingAnchor constant:-32],

        [icon.widthAnchor constraintEqualToConstant:72],
        [icon.heightAnchor constraintEqualToConstant:72],
        [addButton.heightAnchor constraintEqualToConstant:46],
        [addButton.widthAnchor constraintEqualToConstant:210],
    ]];
}

- (UIView *)fieldIconWrapWithSymbol:(NSString *)symbol {
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 38, 38)];
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(9, 9, 20, 20)];
    icon.image = [UIImage systemImageNamed:symbol];
    icon.tintColor = ThemeManager.shared.secondaryTextColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [wrap addSubview:icon];
    return wrap;
}

- (void)setupAddForm {
    _addFormView = [[UIView alloc] init];
    _addFormView.translatesAutoresizingMaskIntoConstraints = NO;
    _addFormView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _addFormView.layer.cornerRadius = 22;
    _addFormView.layer.borderWidth = 1;
    _addFormView.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _addFormView.layer.shadowColor = UIColor.blackColor.CGColor;
    _addFormView.layer.shadowOpacity = 0.30;
    _addFormView.layer.shadowRadius = 26;
    _addFormView.layer.shadowOffset = CGSizeMake(0, 8);
    _addFormView.clipsToBounds = YES;
    _addFormView.alpha = 0;
    _addFormView.userInteractionEnabled = NO;
    [self.view addSubview:_addFormView];

    // The form content scrolls inside the card so the keyboard can never
    // cover the fields or the submit button.
    _formScrollView = [[UIScrollView alloc] init];
    _formScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _formScrollView.showsVerticalScrollIndicator = NO;
    _formScrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_addFormView addSubview:_formScrollView];

    _formContentView = [[UIView alloc] init];
    _formContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_formScrollView addSubview:_formContentView];

    UILabel *addTitle = [[UILabel alloc] init];
    addTitle.translatesAutoresizingMaskIntoConstraints = NO;
    addTitle.text = localize(@"account.add", nil);
    addTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    addTitle.textColor = ThemeManager.shared.primaryTextColor;
    [_formContentView addSubview:addTitle];

    _closeFormButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeFormButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeFormButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    _closeFormButton.tintColor = ThemeManager.shared.secondaryTextColor;
    _closeFormButton.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.12];
    _closeFormButton.layer.cornerRadius = 16;
    _closeFormButton.accessibilityLabel = localize(@"Close", nil);
    [_closeFormButton addTarget:self action:@selector(closeFormTapped) forControlEvents:UIControlEventTouchUpInside];
    [_formContentView addSubview:_closeFormButton];

    _addTypeControl = [[UISegmentedControl alloc] initWithItems:@[localize(@"Premium (Microsoft)", nil), localize(@"Local (Offline)", nil), @"Ely.by"]];
    _addTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _addTypeControl.selectedSegmentIndex = 1;
    [ThemeManager.shared styleSegmentedControl:_addTypeControl];
    [_addTypeControl addTarget:self action:@selector(addTypeChanged) forControlEvents:UIControlEventValueChanged];
    [_formContentView addSubview:_addTypeControl];

    _usernameField = [[UITextField alloc] init];
    _usernameField.translatesAutoresizingMaskIntoConstraints = NO;
    _usernameField.placeholder = localize(@"account.username.placeholder", nil);
    _usernameField.text = @"Player";
    _usernameField.borderStyle = UITextBorderStyleNone;
    _usernameField.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    _usernameField.layer.cornerRadius = 12;
    _usernameField.font = [UIFont systemFontOfSize:14];
    _usernameField.hidden = YES;
    _usernameField.returnKeyType = UIReturnKeyDone;
    _usernameField.leftView = [self fieldIconWrapWithSymbol:@"person"];
    _usernameField.leftViewMode = UITextFieldViewModeAlways;
    _usernameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [_usernameField addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_formContentView addSubview:_usernameField];

    UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    kbToolbar.items = @[flexSpace, doneBtn];
    _usernameField.inputAccessoryView = kbToolbar;

    _passwordField = [[UITextField alloc] init];
    _passwordField.translatesAutoresizingMaskIntoConstraints = NO;
    _passwordField.placeholder = localize(@"account.password.placeholder", nil);
    _passwordField.borderStyle = UITextBorderStyleNone;
    _passwordField.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    _passwordField.layer.cornerRadius = 12;
    _passwordField.font = [UIFont systemFontOfSize:14];
    _passwordField.hidden = YES;
    _passwordField.secureTextEntry = YES;
    _passwordField.returnKeyType = UIReturnKeyDone;
    _passwordField.leftView = [self fieldIconWrapWithSymbol:@"lock"];
    _passwordField.leftViewMode = UITextFieldViewModeAlways;
    _passwordField.inputAccessoryView = kbToolbar;
    [_passwordField addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_formContentView addSubview:_passwordField];

    _addActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _addActionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_addActionBtn setTitle:localize(@"account.login_ms", nil) forState:UIControlStateNormal];
    [_addActionBtn setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
    _addActionBtn.backgroundColor = ThemeManager.shared.accentColor;
    _addActionBtn.layer.cornerRadius = 14;
    _addActionBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_addActionBtn addTarget:self action:@selector(addAccountTapped) forControlEvents:UIControlEventTouchUpInside];
    _addActionBtn.hidden = YES;
    [_formContentView addSubview:_addActionBtn];

    _oauthLinkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _oauthLinkBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_oauthLinkBtn setTitle:localize(@"Sign in with Browser (OAuth2)", nil) forState:UIControlStateNormal];
    _oauthLinkBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [_oauthLinkBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    [_oauthLinkBtn addTarget:self action:@selector(addElyOAuthTapped) forControlEvents:UIControlEventTouchUpInside];
    _oauthLinkBtn.hidden = YES;
    [_formContentView addSubview:_oauthLinkBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_addFormView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_addFormView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        self.formBottomConstraint = [_addFormView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16],

        [_formScrollView.topAnchor constraintEqualToAnchor:_addFormView.topAnchor],
        [_formScrollView.leadingAnchor constraintEqualToAnchor:_addFormView.leadingAnchor],
        [_formScrollView.trailingAnchor constraintEqualToAnchor:_addFormView.trailingAnchor],
        [_formScrollView.bottomAnchor constraintEqualToAnchor:_addFormView.bottomAnchor],

        [_formContentView.topAnchor constraintEqualToAnchor:_formScrollView.contentLayoutGuide.topAnchor],
        [_formContentView.leadingAnchor constraintEqualToAnchor:_formScrollView.contentLayoutGuide.leadingAnchor],
        [_formContentView.trailingAnchor constraintEqualToAnchor:_formScrollView.contentLayoutGuide.trailingAnchor],
        [_formContentView.bottomAnchor constraintEqualToAnchor:_formScrollView.contentLayoutGuide.bottomAnchor],
        [_formContentView.widthAnchor constraintEqualToAnchor:_formScrollView.frameLayoutGuide.widthAnchor],

        [addTitle.topAnchor constraintEqualToAnchor:_formContentView.topAnchor constant:18],
        [addTitle.leadingAnchor constraintEqualToAnchor:_formContentView.leadingAnchor constant:18],

        [_closeFormButton.centerYAnchor constraintEqualToAnchor:addTitle.centerYAnchor],
        [_closeFormButton.trailingAnchor constraintEqualToAnchor:_formContentView.trailingAnchor constant:-14],
        [_closeFormButton.widthAnchor constraintEqualToConstant:32],
        [_closeFormButton.heightAnchor constraintEqualToConstant:32],

        [_addTypeControl.topAnchor constraintEqualToAnchor:addTitle.bottomAnchor constant:14],
        [_addTypeControl.leadingAnchor constraintEqualToAnchor:_formContentView.leadingAnchor constant:16],
        [_addTypeControl.trailingAnchor constraintEqualToAnchor:_formContentView.trailingAnchor constant:-16],

        [_usernameField.topAnchor constraintEqualToAnchor:_addTypeControl.bottomAnchor constant:12],
        [_usernameField.leadingAnchor constraintEqualToAnchor:_formContentView.leadingAnchor constant:16],
        [_usernameField.trailingAnchor constraintEqualToAnchor:_formContentView.trailingAnchor constant:-16],
        [_usernameField.heightAnchor constraintEqualToConstant:44],

        self.passwordTopConstraint = [_passwordField.topAnchor constraintEqualToAnchor:_usernameField.bottomAnchor constant:0],
        [_passwordField.leadingAnchor constraintEqualToAnchor:_formContentView.leadingAnchor constant:16],
        [_passwordField.trailingAnchor constraintEqualToAnchor:_formContentView.trailingAnchor constant:-16],
        self.passwordHeightConstraint = [_passwordField.heightAnchor constraintEqualToConstant:0],

        [_addActionBtn.topAnchor constraintEqualToAnchor:_passwordField.bottomAnchor constant:12],
        [_addActionBtn.leadingAnchor constraintEqualToAnchor:_formContentView.leadingAnchor constant:16],
        [_addActionBtn.trailingAnchor constraintEqualToAnchor:_formContentView.trailingAnchor constant:-16],
        [_addActionBtn.heightAnchor constraintEqualToConstant:48],

        self.oauthTopConstraint = [_oauthLinkBtn.topAnchor constraintEqualToAnchor:_addActionBtn.bottomAnchor constant:0],
        [_oauthLinkBtn.centerXAnchor constraintEqualToAnchor:_formContentView.centerXAnchor],
        self.oauthHeightConstraint = [_oauthLinkBtn.heightAnchor constraintEqualToConstant:0],
        [_oauthLinkBtn.bottomAnchor constraintEqualToAnchor:_formContentView.bottomAnchor constant:-16],
    ]];

    _formHeightConstraint = [_addFormView.heightAnchor constraintEqualToConstant:380];
    _formHeightConstraint.priority = 999;
    _formHeightConstraint.active = YES;

    [self addTypeChanged];
}

- (void)updateAddFormSizing {
    if (!_showingAddForm) return;
    CGFloat maxHeight = self.view.bounds.size.height - self.view.safeAreaInsets.top - _keyboardOverlap - 24;
    maxHeight = MAX(200.0, maxHeight);
    CGFloat needed = [_formContentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    CGFloat height = MIN(needed, maxHeight);
    if (fabs(_formHeightConstraint.constant - height) > 0.5) {
        _formHeightConstraint.constant = height;
    }
    _formScrollView.scrollEnabled = needed > height + 1.0;
    _formScrollView.alwaysBounceVertical = _formScrollView.scrollEnabled;
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.verticalSizeClass != self.traitCollection.verticalSizeClass ||
        previousTraitCollection.horizontalSizeClass != self.traitCollection.horizontalSizeClass) {
        [self viewWillLayoutSubviews];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_showingAddForm && !_keyboardVisible) {
        self.formBottomConstraint.constant = -16 - self.view.safeAreaInsets.bottom;
    }
    [self updateAddFormSizing];
}

- (void)closeFormTapped {
    [self toggleAddForm:NO animated:YES];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openDetailForAccount:(NSDictionary *)account {
    AccountDetailViewController *detail = [[AccountDetailViewController alloc] init];
    detail.account = account;
    detail.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:detail animated:YES completion:nil];
}

#pragma mark - Account list state

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _tableView.backgroundColor = theme.contentBackgroundColor;
    _headerView.backgroundColor = theme.contentBackgroundColor;
    _titleLabel.textColor = theme.primaryTextColor;
    _subtitleLabel.textColor = theme.secondaryTextColor;
    _addButton.tintColor = theme.buttonTextColor;
    _addButton.backgroundColor = theme.accentColor;
    _addFormView.backgroundColor = theme.cardBackgroundColor;
    _addFormView.layer.borderColor = theme.separatorColor.CGColor;
    [ThemeManager.shared styleSegmentedControl:_addTypeControl];
    [_addActionBtn setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
    _addActionBtn.backgroundColor = theme.accentColor;
    _usernameField.textColor = theme.primaryTextColor;
    _usernameField.backgroundColor = [theme.primaryTextColor colorWithAlphaComponent:0.06];
    _usernameField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:_usernameField.placeholder
        attributes:@{NSForegroundColorAttributeName: theme.secondaryTextColor}];
    _passwordField.textColor = theme.primaryTextColor;
    _passwordField.backgroundColor = [theme.primaryTextColor colorWithAlphaComponent:0.06];
    _passwordField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:_passwordField.placeholder
        attributes:@{NSForegroundColorAttributeName: theme.secondaryTextColor}];
    _closeFormButton.tintColor = theme.secondaryTextColor;
    _closeFormButton.backgroundColor = [theme.primaryTextColor colorWithAlphaComponent:0.10];
    [_oauthLinkBtn setTitleColor:theme.accentColor forState:UIControlStateNormal];
    _addTypeControl.selectedSegmentIndex = MAX(0, _addTypeControl.selectedSegmentIndex);
}

- (void)accountListChanged {
    [self loadAccounts];
}

- (void)updateCountLabel {
    NSInteger count = _accountsArray.count;
    _subtitleLabel.text = count == 0 ? localize(@"account.screen.subtitle", nil)
                                     : [NSString stringWithFormat:localize(@"account.count_format", nil), (long)count];
}

- (NSDictionary *)selectedAccount {
    NSString *selected = getPrefObject(@"internal.selected_account");
    if (![selected isKindOfClass:[NSString class]] || selected.length == 0) return nil;
    return [self accountForUsername:selected];
}

- (void)loadAccounts {
    _accountsArray = [NSMutableArray array];
    NSString *accountDir = amethyst_hidden_dir(@"accounts");
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
    [_accountsArray sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [(a[@"username"] ?: @"") localizedCaseInsensitiveCompare:(b[@"username"] ?: @"")];
    }];

    // Keep a valid active selection: silently fall back to the first account
    // if the saved name is missing or unknown.
    NSString *selectedName = getPrefObject(@"internal.selected_account");
    BOOL selectedIsValid = selectedName.length > 0 && [self accountForUsername:selectedName] != nil;
    if (!selectedIsValid && _accountsArray.count > 0) {
        NSString *fallback = _accountsArray.firstObject[@"username"];
        [BaseAuthenticator loadSavedName:fallback];
        setPrefObject(@"internal.selected_account", fallback);
    }

    [self.tableView reloadData];
    [self updateCountLabel];
    [self refreshState];
    [self toggleAddForm:NO animated:NO];
}

- (void)refreshState {
    BOOL hasAccounts = _accountsArray.count > 0;
    _emptyStateView.hidden = hasAccounts;
    _tableView.hidden = !hasAccounts;
}

- (void)toggleAddForm:(BOOL)show animated:(BOOL)animated {
    if (show == _showingAddForm) return;
    _showingAddForm = show;
    _addFormView.userInteractionEnabled = show;
    if (show) [self updateAddFormSizing];
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            self->_addFormView.alpha = show ? 1 : 0;
            if (show) {
                self.formBottomConstraint.constant = -16 - self.view.safeAreaInsets.bottom;
            } else {
                self.formBottomConstraint.constant = self.view.frame.size.height + 40;
            }
            [self.view layoutIfNeeded];
        }];
    } else {
        _addFormView.alpha = show ? 1 : 0;
        if (show) {
            self.formBottomConstraint.constant = -16 - self.view.safeAreaInsets.bottom;
        } else {
            self.formBottomConstraint.constant = self.view.frame.size.height + 40;
        }
        [self.view layoutIfNeeded];
    }
}

- (void)addButtonTapped {
    [self toggleAddForm:YES animated:YES];
}

- (void)addTypeChanged {
    NSInteger selected = _addTypeControl.selectedSegmentIndex;
    BOOL isLocal = selected == 1;
    BOOL isEly = selected == 2;

    _usernameField.hidden = !(isLocal || isEly);
    _usernameField.placeholder = isEly ? localize(@"account.ely.placeholder", nil) : localize(@"account.username.placeholder", nil);
    if (isLocal && _usernameField.text.length == 0) _usernameField.text = @"Player";
    if (!isLocal && [_usernameField.text isEqualToString:@"Player"]) _usernameField.text = @"";
    if (!isLocal && !isEly) _passwordField.text = @"";

    _passwordField.hidden = !isEly;
    self.passwordTopConstraint.constant = isEly ? 10 : 0;
    self.passwordHeightConstraint.constant = isEly ? 44 : 0;

    _oauthLinkBtn.hidden = !isEly;
    self.oauthTopConstraint.constant = isEly ? 6 : 0;
    self.oauthHeightConstraint.constant = isEly ? 30 : 0;

    _addActionBtn.hidden = NO;
    if (isLocal) {
        [_addActionBtn setTitle:localize(@"Add Local Account", nil) forState:UIControlStateNormal];
    } else if (isEly) {
        [_addActionBtn setTitle:localize(@"Login with Ely.by", nil) forState:UIControlStateNormal];
    } else {
        [_addActionBtn setTitle:localize(@"account.login_ms", nil) forState:UIControlStateNormal];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:kbFrame fromView:self.view.window];
    CGFloat overlap = self.view.frame.size.height - converted.origin.y;
    if (overlap <= 1) {
        // Keyboard went fully off-screen (rotation, dismissal gesture).
        self.keyboardVisible = NO;
        self.keyboardOverlap = 0;
        if (_showingAddForm) {
            self.formBottomConstraint.constant = -16 - self.view.safeAreaInsets.bottom;
            [UIView animateWithDuration:0.3 animations:^{ [self.view layoutIfNeeded]; }];
        }
        [self updateAddFormSizing];
        return;
    }
    self.keyboardVisible = YES;
    self.keyboardOverlap = overlap;
    [self updateAddFormSizing];
    if (_showingAddForm) {
        self.formBottomConstraint.constant = -16 - overlap;
        [UIView animateWithDuration:0.3 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardVisible = NO;
    self.keyboardOverlap = 0;
    [self updateAddFormSizing];
    if (!_showingAddForm) return;
    self.formBottomConstraint.constant = -16 - self.view.safeAreaInsets.bottom;
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)selectAndSaveAccount:(BaseAuthenticator *)auth {
    BaseAuthenticator.current = auth;
    setPrefObject(@"internal.selected_account", auth.authData[@"username"] ?: @"");
    [self loadAccounts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (void)selectAccount:(NSDictionary *)account showToast:(BOOL)showToast {
    NSString *username = account[@"username"];
    if (![username isKindOfClass:[NSString class]] || username.length == 0) return;
    [BaseAuthenticator loadSavedName:username]; // sets BaseAuthenticator.current
    setPrefObject(@"internal.selected_account", username);
    [self loadAccounts];
    if (showToast) {
        [HapticManager.shared play:HapticTypeSuccess];
        [ErrorPresenter showToast:[NSString stringWithFormat:localize(@"account.selected_toast", nil), username] success:YES];
    }
}

#pragma mark - Add account

- (void)addAccountTapped {
    if (_addTypeControl.selectedSegmentIndex == 0) {
        [self addMicrosoftAccount];
    } else if (_addTypeControl.selectedSegmentIndex == 2) {
        [self addElyByAccount];
    } else {
        [self addLocalAccount];
    }
}

- (void)addMicrosoftAccount {
    self.elyOAuthFlowActive = NO;
    NSString *authURL = @"https://login.live.com/oauth20_authorize.srf?client_id=00000000402b5328&response_type=code&redirect_uri=https://login.live.com/oauth20_desktop.srf&scope=service::user.auth.xboxlive.com::MBI_SSL";
    [self presentLoginWebViewWithURL:[NSURL URLWithString:authURL] title:@"Microsoft Login"];
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
                [self toggleAddForm:NO animated:YES];
            }
        });
    }];
}

- (void)addElyByAccount {
    NSString *login = _usernameField.text;
    NSString *password = _passwordField.text;
    if (login.length == 0 || password.length == 0) {
        showDialog(localize(@"Error", nil), @"Please enter your Ely.by email/username and password.");
        return;
    }
    [self elyLoginWithLogin:login password:password totp:nil];
}

- (void)elyLoginWithLogin:(NSString *)login password:(NSString *)password totp:(nullable NSString *)totp {
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
                [self toggleAddForm:NO animated:YES];
            }
        });
    }];
}

- (void)promptElyTOTPWithLogin:(NSString *)login password:(NSString *)password {
    [AppSheet showPromptWithTitle:localize(@"account.2fa_title", nil) message:localize(@"account.2fa_message", nil) placeholder:@"123456" initialText:@"" onConfirm:^(NSString *code) {
        NSString *trimmed = [code stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        [self elyLoginWithLogin:login password:password totp:trimmed];
    }];
}

- (void)addElyOAuthTapped {
    NSURL *url = [ElyAuthenticator oauthAuthorizeURL];
    if (!url) {
        showDialog(@"Ely.by OAuth2 Not Configured",
            @"Register an application at https://account.ely.by/dev/applications/new (type: Website), then set WITCH_ELY_OAUTH_CLIENT_ID and WITCH_ELY_OAUTH_CLIENT_SECRET in Natives/Config/WitchConfig.h (or via --ely-client-id / --ely-client-secret of scripts/encrypt_witch_config.py).");
        return;
    }
    self.elyOAuthFlowActive = YES;
    [self presentLoginWebViewWithURL:url title:@"Ely.by Login"];
}

#pragma mark - Web login (Microsoft / Ely OAuth)

- (void)presentLoginWebViewWithURL:(NSURL *)url title:(NSString *)title {
    UIView *webContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    webContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webContainer.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:webContainer];

    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, webContainer.bounds.size.width, 44)];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    [webContainer addSubview:topBar];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(8, 0, 60, 44);
    [closeBtn setTitle:localize(@"Cancel", nil) forState:UIControlStateNormal];
    closeBtn.tintColor = ThemeManager.shared.accentColor;
    [closeBtn addTarget:self action:@selector(dismissWebView) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:closeBtn];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, topBar.bounds.size.width, 44)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = ThemeManager.shared.primaryTextColor;
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
                        [self toggleAddForm:NO animated:YES];
                    });
                }];
            } else if (params[@"error_message"] || params[@"error_description"] || params[@"error"]) {
                showDialog(localize(@"Error", nil), params[@"error_message"] ?: params[@"error_description"] ?: params[@"error"]);
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
                        [self toggleAddForm:NO animated:YES];
                    } else if ([status isEqualToString:@"DEMO"]) {
                        [self selectAndSaveAccount:auth];
                        showDialog(@"Demo Account", @"Your Microsoft account has not purchased Minecraft. You will not be able to play the full game.");
                        [self toggleAddForm:NO animated:YES];
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

#pragma mark - Delete account

- (void)deleteAccountByUsername:(NSString *)username {
    NSString *path = amethyst_hidden_path([NSString stringWithFormat:@"accounts/%@.json", username]);
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    NSDictionary *account = [self accountForUsername:username];
    if (account) {
        if ([account[@"username"] isEqualToString:getPrefObject(@"internal.selected_account")]) {
            BaseAuthenticator.current = nil;
            setPrefObject(@"internal.selected_account", @"");
        }
        NSString *xuid = account[@"xuid"];
        if (xuid) {
            [MicrosoftAuthenticator clearTokenDataOfProfile:xuid];
        }
        if (AccountIsEly(account)) {
            [ElyAuthenticator invalidateAccessToken:account[@"accessToken"] clientToken:account[@"clientToken"]];
            NSString *elyProfileId = account[@"profileId"];
            if (elyProfileId.length > 0) {
                [ElyAuthenticator clearTokenDataOfProfile:elyProfileId];
            }
        }
        [[SkinTextureManager shared] evictCachedSkinForAccount:account];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"account.local_skin_model.%@", username.lowercaseString]];
    }

    [self loadAccounts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountDidChangeNotification" object:nil];
}

- (NSDictionary *)accountForUsername:(NSString *)username {
    for (NSDictionary *acc in _accountsArray) {
        if ([acc[@"username"] isEqualToString:username]) return acc;
    }
    return nil;
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _accountsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AccountCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AccountCell" forIndexPath:indexPath];
    NSDictionary *account = _accountsArray[indexPath.row];
    NSString *selected = getPrefObject(@"internal.selected_account");
    BOOL isSelected = [account[@"username"] isEqualToString:selected];
    [cell configureWithAccount:account isSelected:isSelected];

    cell.selectButton.tag = indexPath.row;
    [cell.selectButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.selectButton addTarget:self action:@selector(selectTapped:) forControlEvents:UIControlEventTouchUpInside];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self openDetailForAccount:_accountsArray[indexPath.row]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self confirmDeleteButtonTapped:indexPath.row];
    }
}

- (nullable UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    NSDictionary *account = _accountsArray[indexPath.row];
    return [UIContextMenuConfiguration configurationWithIdentifier:@(indexPath.row)
                                                      previewProvider:nil
                                                       actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *details = [UIAction actionWithTitle:localize(@"account.menu.details", nil)
                                                image:[UIImage systemImageNamed:@"info.circle"]
                                           identifier:nil
                                              handler:^(__kindof UIAction *action) {
            [self openDetailForAccount:account];
        }];
        UIAction *activate = [UIAction actionWithTitle:localize(@"account.set_active", nil)
                                                 image:[UIImage systemImageNamed:@"checkmark.circle.fill"]
                                            identifier:nil
                                               handler:^(__kindof UIAction *action) {
            [self selectAccount:account showToast:YES];
        }];
        UIAction *delete = [UIAction actionWithTitle:localize(@"Delete", nil)
                                               image:[UIImage systemImageNamed:@"trash"]
                                          identifier:nil
                                             handler:^(__kindof UIAction *action) {
            [self confirmDeleteForAccount:account];
        }];
        delete.attributes = UIMenuElementAttributesDestructive;
        return [UIMenu menuWithTitle:@"" children:@[details, activate, delete]];
    }];
}

#pragma mark - Actions

- (void)selectTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)_accountsArray.count) return;
    [self selectAccount:_accountsArray[index] showToast:YES];
}

- (void)confirmDeleteButtonTapped:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_accountsArray.count) return;
    [self confirmDeleteForAccount:_accountsArray[index]];
}

- (void)confirmDeleteForAccount:(NSDictionary *)account {
    [AppSheet showConfirmWithTitle:localize(@"account.delete_title", nil)
                           message:[NSString stringWithFormat:@"Delete '%@'?", account[@"username"]]
                     confirmTitle:localize(@"Delete", nil)
                      destructive:YES
                        onConfirm:^{
                            [self deleteAccountByUsername:account[@"username"]];
                        }];
}

#pragma mark - Change Skin / Cape

- (void)ensureFreshMSTokenForAccount:(NSDictionary *)account completion:(void (^)(NSString * _Nullable accessToken))completion {
    NSString *username = account[@"username"];
    NSString *xuid = account[@"xuid"];
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

- (void)presentCapePickerWithProfile:(NSDictionary *)profile accessToken:(NSString *)accessToken sourceView:(UIView *)sourceView {
    NSArray *capes = profile[@"capes"] ?: @[];
    if (capes.count == 0) {
        showDialog(@"No Capes", @"This account does not own any capes. Capes can only be equipped if they were obtained through official Minecraft events or the Marketplace.");
        return;
    }

    NSMutableArray *opts = [NSMutableArray array];
    NSMutableArray *ids = [NSMutableArray array];
    NSMutableArray *actives = [NSMutableArray array];
    NSInteger sel = NSNotFound;
    for (NSDictionary *cape in capes) {
        NSString *capeId = cape[@"id"];
        BOOL isActive = [cape[@"state"] isEqualToString:@"ACTIVE"];
        NSString *title = cape[@"alias"] ?: capeId;
        [opts addObject:@{@"title": title}];
        [ids addObject:capeId ?: @""];
        [actives addObject:@(isActive)];
        if (isActive) sel = ids.count - 1;
    }
    [AppSheet showOptionsWithTitle:localize(@"cape.change", nil) message:localize(@"cape.select_hint", nil) options:opts selectedIndex:sel selection:^(NSInteger idx) {
        [self equipCapeWithId:ids[idx] isActive:[actives[idx] boolValue] accessToken:accessToken];
    }];
}

- (void)equipCapeWithId:(NSString *)capeId isActive:(BOOL)isActive accessToken:(NSString *)accessToken {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.minecraftservices.com/minecraft/profile/capes/active"]];
    if (isActive) {
        request.HTTPMethod = @"DELETE";
    } else {
        request.HTTPMethod = @"PUT";
        NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"capeId": capeId ?: @""} options:0 error:nil];
        request.HTTPBody = body;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:localize(@"progress.changing_cape", nil)];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (!error && (httpResp.statusCode == 200 || httpResp.statusCode == 204)) {
                [overlay finishWithMessage:isActive ? localize(@"account.cape_removed", nil) : localize(@"account.cape_equipped", nil)];
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

NS_ASSUME_NONNULL_END
