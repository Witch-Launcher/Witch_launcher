#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "WitchPluginAPI.h"
#import "WitchRootHost.h"
#import "SidebarViewController.h"

@interface MainCoordinator : NSObject
- (void)start;
- (void)switchToTab:(SidebarTab)tab;
- (void)showAccount;
- (void)showSettings;
- (void)showFileManager;
- (void)showVersionPicker;
- (void)showDownloadHub;
- (void)showDownloadTasks;
- (void)launchGame;
@end

static UIColor *AuroraThemeColor(NSString *key, UIColor *fallback) {
    Class themeClass = NSClassFromString(@"ThemeManager");
    if (!themeClass) return fallback;
    id theme = [themeClass performSelector:NSSelectorFromString(@"shared")];
    id value = [theme valueForKey:key];
    return [value isKindOfClass:[UIColor class]] ? value : fallback;
}

static BOOL AuroraIsPortrait(CGSize size) {
    return size.width < 700.0;
}

@interface AuroraGradientView : UIView
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@end

@implementation AuroraGradientView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.startPoint = CGPointMake(0, 0);
        _gradientLayer.endPoint = CGPointMake(1, 1);
        [self.layer insertSublayer:_gradientLayer atIndex:0];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}
@end

@interface AuroraNavButton : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic) BOOL active;
- (instancetype)initWithTitle:(NSString *)title symbol:(NSString *)symbol;
- (void)setAccentColor:(UIColor *)accentColor;
@end

@implementation AuroraNavButton
- (instancetype)initWithTitle:(NSString *)title symbol:(NSString *)symbol {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 14;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];
        _captionLabel = [[UILabel alloc] init];
        _captionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _captionLabel.text = title;
        _captionLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _captionLabel.textAlignment = NSTextAlignmentCenter;
        _captionLabel.userInteractionEnabled = NO;
        [self addSubview:_captionLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:9],
            [_iconView.widthAnchor constraintEqualToConstant:20],
            [_iconView.heightAnchor constraintEqualToConstant:20],
            [_captionLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2],
            [_captionLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2],
            [_captionLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:3],
        ]];
    }
    return self;
}
- (void)setActive:(BOOL)active {
    _active = active;
    self.backgroundColor = active ? [self.accentColor colorWithAlphaComponent:0.16] : UIColor.clearColor;
    self.iconView.tintColor = active ? self.accentColor : AuroraThemeColor(@"secondaryTextColor", UIColor.secondaryLabelColor);
    self.captionLabel.textColor = active ? self.accentColor : AuroraThemeColor(@"secondaryTextColor", UIColor.secondaryLabelColor);
}
- (void)setAccentColor:(UIColor *)accentColor {
    _accentColor = accentColor;
    [self setActive:self.active];
}
@end

@interface AuroraActionCard : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIColor *accentColor;
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol;
- (void)applyTheme;
@end

@implementation AuroraActionCard
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 18;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1;
        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = title;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [self addSubview:_titleLabel];
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.text = subtitle;
        _subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _subtitleLabel.numberOfLines = 1;
        [self addSubview:_subtitleLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_iconView.widthAnchor constraintEqualToConstant:22],
            [_iconView.heightAnchor constraintEqualToConstant:22],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.leadingAnchor],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-12],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:10],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-10],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        ]];
        [self applyTheme];
    }
    return self;
}
- (void)applyTheme {
    self.backgroundColor = [AuroraThemeColor(@"cardBackgroundColor", UIColor.secondarySystemBackgroundColor) colorWithAlphaComponent:0.86];
    self.layer.borderColor = [AuroraThemeColor(@"separatorColor", UIColor.separatorColor) colorWithAlphaComponent:0.55].CGColor;
    self.iconView.tintColor = self.accentColor ?: AuroraThemeColor(@"accentColor", UIColor.systemPurpleColor);
    self.titleLabel.textColor = AuroraThemeColor(@"primaryTextColor", UIColor.labelColor);
    self.subtitleLabel.textColor = AuroraThemeColor(@"secondaryTextColor", UIColor.secondaryLabelColor);
}
@end

@interface AuroraRootViewController : UIViewController <WitchRootHost>
@property (nonatomic, strong) MainCoordinator *coordinator;
@property (nonatomic, strong) RightPanelViewController *rightPanelVC;
@property (nonatomic, strong) UIViewController *currentContentVC;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *rail;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIView *homeScroll;
@property (nonatomic, strong) UIStackView *homeStack;
@property (nonatomic, strong) AuroraGradientView *heroCard;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *accountLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *versionButton;
@property (nonatomic, strong) UIButton *avatarButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *downloadsButton;
@property (nonatomic, strong) NSMutableArray<AuroraNavButton *> *navButtons;
@property (nonatomic, strong) NSMutableArray<AuroraActionCard *> *actionCards;
@property (nonatomic) SidebarTab selectedTab;
@property (nonatomic) BOOL didStartCoordinator;
@property (nonatomic, strong) NSArray<NSDictionary *> *tabDefinitions;
@end

@implementation AuroraRootViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedTab = SidebarTabGame;
        _navButtons = [NSMutableArray array];
        _actionCards = [NSMutableArray array];
        _tabDefinitions = @[
            @{@"title": @"Home", @"symbol": @"house.fill", @"tab": @(SidebarTabGame)},
            @{@"title": @"Mods", @"symbol": @"puzzlepiece.extension.fill", @"tab": @(SidebarTabMod)},
            @{@"title": @"Packs", @"symbol": @"shippingbox.fill", @"tab": @(SidebarTabModpack)},
            @{@"title": @"Shaders", @"symbol": @"sparkles", @"tab": @(SidebarTabShader)},
            @{@"title": @"Textures", @"symbol": @"paintpalette.fill", @"tab": @(SidebarTabResourcePack)},
            @{@"title": @"Maps", @"symbol": @"map.fill", @"tab": @(SidebarTabMap)}
        ];
        Class panelClass = NSClassFromString(@"RightPanelViewController");
        if (panelClass) {
            _rightPanelVC = (RightPanelViewController *)[[panelClass alloc] init];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AuroraThemeColor(@"backgroundColor", UIColor.systemBackgroundColor);
    [self buildBackground];
    [self buildTopBar];
    [self buildRail];
    [self buildBottomBar];
    [self buildContent];
    [self buildHome];
    [self refreshTheme];
    [self refreshAccountAndVersion];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTheme) name:@"ThemeDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountAndVersion) name:@"VersionDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountAndVersion) name:@"AccountDidChangeNotification" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildBackground {
    AuroraGradientView *background = [[AuroraGradientView alloc] initWithFrame:self.view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.userInteractionEnabled = NO;
    [self.view addSubview:background];
    background.tag = 7001;
}

- (UIButton *)chromeButtonWithSymbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.tintColor = AuroraThemeColor(@"primaryTextColor", UIColor.labelColor);
    button.backgroundColor = [AuroraThemeColor(@"cardBackgroundColor", UIColor.secondarySystemBackgroundColor) colorWithAlphaComponent:0.7];
    button.layer.cornerRadius = 15;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:38].active = YES;
    [button.heightAnchor constraintEqualToConstant:38].active = YES;
    return button;
}

- (void)buildTopBar {
    self.topBar = [[UIView alloc] init];
    self.topBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBar.layer.cornerRadius = 20;
    self.topBar.layer.cornerCurve = kCACornerCurveContinuous;
    self.topBar.layer.borderWidth = 1;
    [self.view addSubview:self.topBar];

    UIView *brandIcon = [[UIView alloc] init];
    brandIcon.translatesAutoresizingMaskIntoConstraints = NO;
    brandIcon.layer.cornerRadius = 12;
    brandIcon.layer.cornerCurve = kCACornerCurveContinuous;
    brandIcon.tag = 7002;
    [self.topBar addSubview:brandIcon];
    UIImageView *bolt = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bolt.fill"]];
    bolt.translatesAutoresizingMaskIntoConstraints = NO;
    bolt.contentMode = UIViewContentModeScaleAspectFit;
    bolt.tintColor = UIColor.whiteColor;
    [brandIcon addSubview:bolt];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"WITCH";
    title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBlack];
    title.tag = 7003;
    [self.topBar addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"AURORA";
    subtitle.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
    subtitle.tag = 7004;
    [self.topBar addSubview:subtitle];

    self.avatarButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    self.avatarButton.layer.cornerRadius = 18;
    self.avatarButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.avatarButton addTarget:self action:@selector(accountTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.avatarButton];

    self.settingsButton = [self chromeButtonWithSymbol:@"gearshape.fill" action:@selector(settingsTapped)];
    [self.topBar addSubview:self.settingsButton];

    self.downloadsButton = [self chromeButtonWithSymbol:@"arrow.down.circle.fill" action:@selector(downloadsTapped)];
    [self.topBar addSubview:self.downloadsButton];

    [NSLayoutConstraint activateConstraints:@[
        [brandIcon.leadingAnchor constraintEqualToAnchor:self.topBar.leadingAnchor constant:14],
        [brandIcon.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [brandIcon.widthAnchor constraintEqualToConstant:38],
        [brandIcon.heightAnchor constraintEqualToConstant:38],
        [bolt.centerXAnchor constraintEqualToAnchor:brandIcon.centerXAnchor],
        [bolt.centerYAnchor constraintEqualToAnchor:brandIcon.centerYAnchor],
        [bolt.widthAnchor constraintEqualToConstant:20],
        [bolt.heightAnchor constraintEqualToConstant:20],
        [title.leadingAnchor constraintEqualToAnchor:brandIcon.trailingAnchor constant:10],
        [title.topAnchor constraintEqualToAnchor:brandIcon.topAnchor constant:-2],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor constant:1],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:-1],
        [self.avatarButton.trailingAnchor constraintEqualToAnchor:self.topBar.trailingAnchor constant:-14],
        [self.avatarButton.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.avatarButton.widthAnchor constraintEqualToConstant:36],
        [self.avatarButton.heightAnchor constraintEqualToConstant:36],
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.avatarButton.leadingAnchor constant:-8],
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.downloadsButton.trailingAnchor constraintEqualToAnchor:self.settingsButton.leadingAnchor constant:-8],
        [self.downloadsButton.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
    ]];
}

- (void)buildRail {
    self.rail = [[UIView alloc] init];
    self.rail.translatesAutoresizingMaskIntoConstraints = NO;
    self.rail.layer.cornerRadius = 22;
    self.rail.layer.cornerCurve = kCACornerCurveContinuous;
    self.rail.layer.borderWidth = 1;
    [self.view addSubview:self.rail];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 5;
    stack.alignment = UIStackViewAlignmentFill;
    [self.rail addSubview:stack];

    for (NSDictionary *definition in self.tabDefinitions) {
        AuroraNavButton *button = [[AuroraNavButton alloc] initWithTitle:definition[@"title"] symbol:definition[@"symbol"]];
        button.tag = [definition[@"tab"] integerValue];
        [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:56].active = YES;
        [stack addArrangedSubview:button];
        [self.navButtons addObject:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.rail.leadingAnchor constant:7],
        [stack.trailingAnchor constraintEqualToAnchor:self.rail.trailingAnchor constant:-7],
        [stack.topAnchor constraintEqualToAnchor:self.rail.topAnchor constant:8],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.rail.bottomAnchor constant:-8],
    ]];
}

- (void)buildBottomBar {
    self.bottomBar = [[UIView alloc] init];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBar.layer.cornerRadius = 22;
    self.bottomBar.layer.cornerCurve = kCACornerCurveContinuous;
    self.bottomBar.layer.borderWidth = 1;
    [self.view addSubview:self.bottomBar];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 4;
    stack.distribution = UIStackViewDistributionFillEqually;
    [self.bottomBar addSubview:stack];

    for (NSDictionary *definition in self.tabDefinitions) {
        AuroraNavButton *button = [[AuroraNavButton alloc] initWithTitle:definition[@"title"] symbol:definition[@"symbol"]];
        button.tag = [definition[@"tab"] integerValue];
        [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:55].active = YES;
        [stack addArrangedSubview:button];
        [self.navButtons addObject:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.bottomBar.leadingAnchor constant:7],
        [stack.trailingAnchor constraintEqualToAnchor:self.bottomBar.trailingAnchor constant:-7],
        [stack.topAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:5],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomBar.bottomAnchor constant:-5],
    ]];
}

- (void)buildContent {
    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentContainer.layer.cornerRadius = 24;
    self.contentContainer.layer.cornerCurve = kCACornerCurveContinuous;
    self.contentContainer.layer.borderWidth = 1;
    self.contentContainer.clipsToBounds = YES;
    [self.view addSubview:self.contentContainer];
}

- (UIButton *)primaryButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    button.layer.cornerRadius = 16;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    return button;
}

- (void)buildHome {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.alwaysBounceVertical = YES;
    [self.contentContainer addSubview:scroll];
    self.homeScroll = scroll;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [scroll addSubview:stack];
    self.homeStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-18],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    self.heroCard = [[AuroraGradientView alloc] initWithFrame:CGRectZero];
    self.heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCard.layer.cornerRadius = 22;
    self.heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroCard.clipsToBounds = YES;
    [self.heroCard.heightAnchor constraintEqualToConstant:186].active = YES;
    [stack addArrangedSubview:self.heroCard];

    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.08];
    glow.layer.cornerRadius = 80;
    [self.heroCard addSubview:glow];
    [NSLayoutConstraint activateConstraints:@[
        [glow.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:35],
        [glow.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:-55],
        [glow.widthAnchor constraintEqualToConstant:160],
        [glow.heightAnchor constraintEqualToConstant:160],
    ]];

    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.text = @"YOUR NEXT ADVENTURE";
    eyebrow.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    eyebrow.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.7];
    [self.heroCard addSubview:eyebrow];

    self.heroTitle = [[UILabel alloc] init];
    self.heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitle.text = @"Ready to play";
    self.heroTitle.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBlack];
    self.heroTitle.textColor = UIColor.whiteColor;
    [self.heroCard addSubview:self.heroTitle];

    self.heroSubtitle = [[UILabel alloc] init];
    self.heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitle.text = @"Pick a version and jump back in.";
    self.heroSubtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.heroSubtitle.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.74];
    [self.heroCard addSubview:self.heroSubtitle];

    self.versionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.versionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.versionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.versionButton.tintColor = UIColor.whiteColor;
    self.versionButton.layer.cornerRadius = 12;
    self.versionButton.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.13];
    self.versionButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [self.versionButton addTarget:self action:@selector(versionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.heroCard addSubview:self.versionButton];

    self.playButton = [self primaryButtonWithTitle:@"PLAY" action:@selector(playTapped)];
    self.playButton.backgroundColor = UIColor.whiteColor;
    self.playButton.tintColor = UIColor.blackColor;
    [self.playButton.widthAnchor constraintEqualToConstant:104].active = YES;
    [self.heroCard addSubview:self.playButton];

    [NSLayoutConstraint activateConstraints:@[
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:20],
        [eyebrow.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:22],
        [self.heroTitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.heroTitle.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:5],
        [self.heroSubtitle.leadingAnchor constraintEqualToAnchor:self.heroTitle.leadingAnchor],
        [self.heroSubtitle.topAnchor constraintEqualToAnchor:self.heroTitle.bottomAnchor constant:3],
        [self.versionButton.leadingAnchor constraintEqualToAnchor:self.heroTitle.leadingAnchor],
        [self.versionButton.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-20],
        [self.versionButton.widthAnchor constraintGreaterThanOrEqualToConstant:120],
        [self.versionButton.heightAnchor constraintEqualToConstant:32],
        [self.playButton.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-20],
        [self.playButton.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-20],
    ]];

    UILabel *quickTitle = [[UILabel alloc] init];
    quickTitle.text = @"QUICK ACTIONS";
    quickTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    quickTitle.tag = 7005;
    [stack addArrangedSubview:quickTitle];

    UIStackView *actions = [[UIStackView alloc] init];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 10;
    actions.distribution = UIStackViewDistributionFillEqually;
    [actions.heightAnchor constraintEqualToConstant:94].active = YES;
    [stack addArrangedSubview:actions];

    NSArray *actionDefinitions = @[
        @{@"title": @"Account", @"subtitle": @"Profile", @"symbol": @"person.crop.circle.fill", @"action": @"accountTapped"},
        @{@"title": @"Settings", @"subtitle": @"Tune UI", @"symbol": @"slider.horizontal.3", @"action": @"settingsTapped"},
        @{@"title": @"Files", @"subtitle": @"Browse", @"symbol": @"folder.fill", @"action": @"filesTapped"},
        @{@"title": @"Downloads", @"subtitle": @"Queue", @"symbol": @"arrow.down.circle.fill", @"action": @"downloadsTapped"}
    ];
    for (NSDictionary *definition in actionDefinitions) {
        AuroraActionCard *card = [[AuroraActionCard alloc] initWithTitle:definition[@"title"] subtitle:definition[@"subtitle"] symbol:definition[@"symbol"]];
        [card addTarget:self action:NSSelectorFromString(definition[@"action"]) forControlEvents:UIControlEventTouchUpInside];
        [actions addArrangedSubview:card];
        [self.actionCards addObject:card];
    }

    UILabel *libraryTitle = [[UILabel alloc] init];
    libraryTitle.text = @"LIBRARY";
    libraryTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    libraryTitle.tag = 7006;
    [stack addArrangedSubview:libraryTitle];

    UIStackView *library = [[UIStackView alloc] init];
    library.axis = UILayoutConstraintAxisHorizontal;
    library.spacing = 10;
    library.distribution = UIStackViewDistributionFillEqually;
    [library.heightAnchor constraintEqualToConstant:102].active = YES;
    [stack addArrangedSubview:library];

    NSArray *libraryDefinitions = @[
        @{@"title": @"Mods", @"subtitle": @"Extend the game", @"symbol": @"puzzlepiece.extension.fill", @"tab": @(SidebarTabMod)},
        @{@"title": @"Modpacks", @"subtitle": @"Curated worlds", @"symbol": @"shippingbox.fill", @"tab": @(SidebarTabModpack)},
        @{@"title": @"Shaders", @"subtitle": @"Make it shine", @"symbol": @"sparkles", @"tab": @(SidebarTabShader)}
    ];
    for (NSDictionary *definition in libraryDefinitions) {
        AuroraActionCard *card = [[AuroraActionCard alloc] initWithTitle:definition[@"title"] subtitle:definition[@"subtitle"] symbol:definition[@"symbol"]];
        card.tag = [definition[@"tab"] integerValue];
        [card addTarget:self action:@selector(libraryTapped:) forControlEvents:UIControlEventTouchUpInside];
        [library addArrangedSubview:card];
        [self.actionCards addObject:card];
    }

    self.accountLabel = [[UILabel alloc] init];
    self.accountLabel.text = @"Not signed in";
    self.accountLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.accountLabel.textAlignment = NSTextAlignmentCenter;
    self.accountLabel.tag = 7007;
    [stack addArrangedSubview:self.accountLabel];
    [self.accountLabel.heightAnchor constraintEqualToConstant:20].active = YES;
}

- (void)refreshTheme {
    UIColor *background = AuroraThemeColor(@"backgroundColor", UIColor.systemBackgroundColor);
    UIColor *card = AuroraThemeColor(@"cardBackgroundColor", UIColor.secondarySystemBackgroundColor);
    UIColor *accent = AuroraThemeColor(@"accentColor", UIColor.systemPurpleColor);
    UIColor *primary = AuroraThemeColor(@"primaryTextColor", UIColor.labelColor);
    UIColor *secondary = AuroraThemeColor(@"secondaryTextColor", UIColor.secondaryLabelColor);
    UIColor *separator = AuroraThemeColor(@"separatorColor", UIColor.separatorColor);
    CGFloat alpha = 0.94;

    self.view.backgroundColor = background;
    AuroraGradientView *gradient = [self.view viewWithTag:7001];
    gradient.gradientLayer.colors = @[
        (id)[background colorWithAlphaComponent:1.0].CGColor,
        (id)[card colorWithAlphaComponent:0.92].CGColor,
        (id)[background colorWithAlphaComponent:0.98].CGColor
    ];
    gradient.gradientLayer.locations = @[@0.0, @0.55, @1.0];

    self.topBar.backgroundColor = [card colorWithAlphaComponent:alpha];
    self.topBar.layer.borderColor = [separator colorWithAlphaComponent:0.5].CGColor;
    self.rail.backgroundColor = [card colorWithAlphaComponent:alpha];
    self.rail.layer.borderColor = [separator colorWithAlphaComponent:0.5].CGColor;
    self.bottomBar.backgroundColor = [card colorWithAlphaComponent:alpha];
    self.bottomBar.layer.borderColor = [separator colorWithAlphaComponent:0.5].CGColor;
    self.contentContainer.backgroundColor = [card colorWithAlphaComponent:0.46];
    self.contentContainer.layer.borderColor = [separator colorWithAlphaComponent:0.35].CGColor;

    UILabel *title = [self.topBar viewWithTag:7003];
    title.textColor = primary;
    UILabel *subtitle = [self.topBar viewWithTag:7004];
    subtitle.textColor = accent;
    UIView *brandIcon = [self.topBar viewWithTag:7002];
    brandIcon.backgroundColor = accent;
    self.avatarButton.backgroundColor = [accent colorWithAlphaComponent:0.18];
    [self.avatarButton setTitleColor:accent forState:UIControlStateNormal];
    self.settingsButton.tintColor = primary;
    self.downloadsButton.tintColor = primary;

    self.heroCard.gradientLayer.colors = @[
        (id)[accent colorWithAlphaComponent:0.95].CGColor,
        (id)[card colorWithAlphaComponent:0.98].CGColor
    ];
    self.versionButton.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.14];
    [self.versionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.playButton.backgroundColor = UIColor.whiteColor;
    self.playButton.tintColor = UIColor.blackColor;

    for (AuroraNavButton *button in self.navButtons) {
        [button setAccentColor:accent];
    }
    for (AuroraActionCard *cardView in self.actionCards) {
        cardView.accentColor = accent;
        [cardView applyTheme];
    }
    UILabel *quick = [self.contentContainer viewWithTag:7005];
    quick.textColor = secondary;
    UILabel *libraryLabel = [self.contentContainer viewWithTag:7006];
    libraryLabel.textColor = secondary;
    self.accountLabel.textColor = secondary;
    self.heroTitle.textColor = UIColor.whiteColor;
    self.heroSubtitle.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.74];
    [self updateSelection];
}

- (void)refreshAccountAndVersion {
    NSString *version = [self currentVersion];
    [self.versionButton setTitle:[NSString stringWithFormat:@"  %@  ›", version.length ? version : @"Select version"] forState:UIControlStateNormal];
    if (version.length) {
        self.heroSubtitle.text = [NSString stringWithFormat:@"Minecraft %@ is ready.", version];
    }
    NSString *name = [self currentAccountName];
    self.accountLabel.text = name.length ? [NSString stringWithFormat:@"Signed in as %@", name] : @"Not signed in";
    NSString *initial = name.length ? [[name substringToIndex:1] uppercaseString] : @"?";
    [self.avatarButton setTitle:initial forState:UIControlStateNormal];
}

- (NSString *)currentVersion {
    Class managerClass = NSClassFromString(@"VersionDirectoryManager");
    id manager = [managerClass performSelector:NSSelectorFromString(@"shared")];
    id version = [manager valueForKey:@"currentVersion"];
    return [version isKindOfClass:[NSString class]] ? version : @"";
}

- (NSString *)currentAccountName {
    Class authClass = NSClassFromString(@"BaseAuthenticator");
    id authenticator = [authClass performSelector:NSSelectorFromString(@"current")];
    NSDictionary *data = [authenticator valueForKey:@"authData"];
    id name = [data isKindOfClass:[NSDictionary class]] ? data[@"username"] : nil;
    return [name isKindOfClass:[NSString class]] ? name : @"";
}

- (void)layoutChrome {
    CGSize size = self.view.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    BOOL portrait = AuroraIsPortrait(size);
    CGFloat gap = 14.0;
    CGFloat topHeight = 64.0;
    CGFloat bottomHeight = portrait ? 68.0 : 0.0;
    CGFloat railWidth = portrait ? 0.0 : 76.0;
    CGFloat left = safe.left + gap;
    CGFloat right = safe.right + gap;
    CGFloat top = safe.top + gap;
    CGFloat usableWidth = size.width - left - right;

    self.topBar.frame = CGRectMake(left, top, usableWidth, topHeight);

    CGFloat contentTop = CGRectGetMaxY(self.topBar.frame) + gap;
    CGFloat contentBottom = size.height - safe.bottom - gap - (portrait ? bottomHeight + gap : 0.0);
    CGFloat contentHeight = MAX(1.0, contentBottom - contentTop);

    if (portrait) {
        self.rail.hidden = YES;
        self.bottomBar.hidden = NO;
        self.bottomBar.frame = CGRectMake(left, size.height - safe.bottom - gap - bottomHeight, usableWidth, bottomHeight);
        self.contentContainer.frame = CGRectMake(left, contentTop, usableWidth, contentHeight);
    } else {
        self.rail.hidden = NO;
        self.bottomBar.hidden = YES;
        self.rail.frame = CGRectMake(left, contentTop, railWidth, contentHeight);
        CGFloat contentX = CGRectGetMaxX(self.rail.frame) + gap;
        CGFloat contentWidth = size.width - contentX - right;
        self.contentContainer.frame = CGRectMake(contentX, contentTop, MAX(1.0, contentWidth), contentHeight);
    }

    self.homeScroll.frame = self.contentContainer.bounds;
    if (self.currentContentVC) {
        self.currentContentVC.view.frame = self.contentContainer.bounds;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutChrome];
    if (!self.didStartCoordinator && self.coordinator) {
        self.didStartCoordinator = YES;
        [self.coordinator start];
    }
}

- (void)switchContentTo:(UIViewController *)vc animated:(BOOL)animated {
    if ([vc isKindOfClass:NSClassFromString(@"MainMenuViewController")]) {
        [self showHome];
        return;
    }
    if (self.currentContentVC == vc) return;
    [self removeCurrentContentAnimated:NO];
    self.homeScroll.hidden = YES;
    [self addChildViewController:vc];
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vc.view.frame = self.contentContainer.bounds;
    [self.contentContainer addSubview:vc.view];
    [vc didMoveToParentViewController:self];
    self.currentContentVC = vc;
    if (animated) {
        vc.view.alpha = 0;
        [UIView animateWithDuration:0.22 animations:^{
            vc.view.alpha = 1;
        }];
    }
}

- (void)removeCurrentContentAnimated:(BOOL)animated {
    UIViewController *old = self.currentContentVC;
    if (!old) return;
    self.currentContentVC = nil;
    [old willMoveToParentViewController:nil];
    [old.view removeFromSuperview];
    [old removeFromParentViewController];
}

- (void)showHome {
    [self removeCurrentContentAnimated:NO];
    self.homeScroll.hidden = NO;
    [self.contentContainer bringSubviewToFront:self.homeScroll];
    self.selectedTab = SidebarTabGame;
    [self refreshAccountAndVersion];
    [self updateSelection];
}

- (void)presentContentAsSheet:(UIViewController *)vc {
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pushContent:(UIViewController *)vc animated:(BOOL)animated {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
    nav.transitioningDelegate = (id<UIViewControllerTransitioningDelegate>)self.coordinator;
    [self presentViewController:nav animated:animated completion:nil];
}

- (void)tabTapped:(AuroraNavButton *)sender {
    self.selectedTab = (SidebarTab)sender.tag;
    [self updateSelection];
    [self.coordinator switchToTab:self.selectedTab];
}

- (void)libraryTapped:(AuroraActionCard *)sender {
    self.selectedTab = (SidebarTab)sender.tag;
    [self updateSelection];
    [self.coordinator switchToTab:self.selectedTab];
}

- (void)updateSelection {
    for (AuroraNavButton *button in self.navButtons) {
        [button setActive:button.tag == self.selectedTab];
    }
}

- (void)playTapped {
    [self.coordinator launchGame];
}

- (void)versionTapped {
    [self.coordinator showVersionPicker];
}

- (void)accountTapped {
    [self.coordinator showAccount];
}

- (void)settingsTapped {
    [self.coordinator showSettings];
}

- (void)filesTapped {
    [self.coordinator showFileManager];
}

- (void)downloadsTapped {
    [self.coordinator showDownloadTasks];
}

@end

static void *AuroraCreateRootView(void *userdata) {
    (void)userdata;
    AuroraRootViewController *root = [[AuroraRootViewController alloc] init];
    return (__bridge_retained void *)root;
}

int witch_plugin_init(const WitchPluginHostAPI *host) {
    if (!host || host->abi_version < 2 || !host->set_root_view_factory) return 1;
    host->set_root_view_factory(host->userdata, AuroraCreateRootView);
    return 0;
}
