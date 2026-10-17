#import "ProfileTabbedPageViewController.h"
#import "ProfileOverviewVC.h"
#import "ProfileContentListVC.h"
#import "ProfileWorldsVC.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "InstalledModsManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface ProfileTabbedPageViewController ()
@property (nonatomic) UIView *cardHost;
@property (nonatomic) UIView *tabPill;
@property (nonatomic) UIStackView *tabStack;
@property (nonatomic) NSMutableArray<UIControl *> *tabButtons;
@property (nonatomic) NSArray<UIViewController *> *tabs;
@property (nonatomic) ProfileOverviewVC *overviewVC;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic) NSArray<NSLayoutConstraint *> *chromeConstraints;
@end

// A rail tab: SF-symbol icon centered above the label in a vertical stack.
// No edge-inset hacks, so long/Vietnamese titles stay centered in every
// rail position (left/right/top/bottom) and every language.
@interface ProfileRailTabButton : UIControl
@property (nonatomic, readonly) UIImageView *iconView;
@property (nonatomic, readonly) UILabel *titleLabel;
- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title;
- (void)setActive:(BOOL)active;
@end

@implementation ProfileRailTabButton

- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = title;

        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName ?: @""]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = title ?: @"";
        _titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 1;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.8;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _titleLabel]];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.spacing = 3;
        stack.userInteractionEnabled = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.widthAnchor constraintEqualToConstant:22],
            [_iconView.heightAnchor constraintEqualToConstant:22],
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:2],
            [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-2],
            [_titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:stack.leadingAnchor],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:stack.trailingAnchor],
        ]];
    }
    return self;
}

- (void)setActive:(BOOL)active {
    UIColor *c = active ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;
    _iconView.tintColor = c;
    _titleLabel.textColor = c;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1.0;
}

@end

@implementation ProfileTabbedPageViewController

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew {
    self = [super init];
    if (self) {
        _profile = profile ?: [NSMutableDictionary dictionary];
        _isNewProfile = isNew;
        _selectedIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *name = self.profile[@"name"];
    self.navigationItem.title = ([name isKindOfClass:[NSString class]] && name.length > 0) ? name : @"Profile";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTapped)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"rectangle.3.group"] style:UIBarButtonItemStylePlain target:self action:@selector(cycleTabPosition)],
    ];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];

    _overviewVC = [[ProfileOverviewVC alloc] initWithProfile:self.profile isNew:_isNewProfile];
    ProfileContentListVC *modsVC = [[ProfileContentListVC alloc] initWithProfile:self.profile category:InstalledItemCategoryMod];
    ProfileContentListVC *shadersVC = [[ProfileContentListVC alloc] initWithProfile:self.profile category:InstalledItemCategoryShaderPack];
    ProfileContentListVC *resVC = [[ProfileContentListVC alloc] initWithProfile:self.profile category:InstalledItemCategoryResourcePack];
    ProfileWorldsVC *worldsVC = [[ProfileWorldsVC alloc] initWithProfile:self.profile];
    _tabs = @[_overviewVC, modsVC, shadersVC, resVC, worldsVC];

    // Floating content card
    _cardHost = [[UIView alloc] init];
    _cardHost.translatesAutoresizingMaskIntoConstraints = NO;
    _cardHost.backgroundColor = [UIColor clearColor];
    _cardHost.layer.cornerRadius = 20;
    _cardHost.clipsToBounds = YES;
    _cardHost.layer.masksToBounds = NO;
    _cardHost.layer.shadowColor = UIColor.blackColor.CGColor;
    _cardHost.layer.shadowOpacity = 0.18;
    _cardHost.layer.shadowRadius = 18;
    _cardHost.layer.shadowOffset = CGSizeMake(0, 6);
    [self.view addSubview:_cardHost];

    // Floating tab pill
    _tabPill = [[UIView alloc] init];
    _tabPill.translatesAutoresizingMaskIntoConstraints = NO;
    _tabPill.layer.cornerRadius = 19;
    _tabPill.clipsToBounds = YES;
    _tabPill.layer.borderWidth = 1;
    _tabPill.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.30].CGColor;
    [self.view addSubview:_tabPill];
    [AmethystBlurView installInView:_tabPill];

    NSArray *icons = @[@"person.crop.circle", @"puzzlepiece.extension", @"paintbrush.pointed", @"paintpalette", @"globe"];
    NSArray *labels = @[localize(@"profiles.tab_overview", nil), localize(@"profiles.tab_mods", nil), localize(@"profiles.tab_shader", nil), localize(@"profiles.tab_packs_short", nil), localize(@"profiles.tab_worlds", nil)];
    _tabButtons = [NSMutableArray array];
    _tabStack = [[UIStackView alloc] init];
    _tabStack.translatesAutoresizingMaskIntoConstraints = NO;
    _tabStack.spacing = 2;
    _tabStack.distribution = UIStackViewDistributionFillEqually;
    [_tabPill addSubview:_tabStack];
    [NSLayoutConstraint activateConstraints:@[
        [_tabStack.topAnchor constraintEqualToAnchor:_tabPill.topAnchor constant:5],
        [_tabStack.bottomAnchor constraintEqualToAnchor:_tabPill.bottomAnchor constant:-5],
        [_tabStack.leadingAnchor constraintEqualToAnchor:_tabPill.leadingAnchor constant:6],
        [_tabStack.trailingAnchor constraintEqualToAnchor:_tabPill.trailingAnchor constant:-6],
    ]];
    for (NSUInteger i = 0; i < 5; i++) {
        ProfileRailTabButton *btn = [[ProfileRailTabButton alloc] initWithIconName:icons[i] title:labels[i]];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabStack addArrangedSubview:btn];
        [_tabButtons addObject:btn];
    }

    [self applyTabPosition:[self tabPosition] animate:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self selectTab:0];
}

#pragma mark - Tab pill position (per orientation: bottom portrait / left landscape)

- (BOOL)isPortraitNow {
    CGSize size = self.view.bounds.size;
    return size.width > 0 && size.width < size.height;
}

- (NSString *)prefKeyForPortrait:(BOOL)isPortrait {
    return isPortrait ? @"general.profile_tabbar_portrait" : @"general.profile_tabbar_landscape";
}

- (BOOL)isValidTabPosition:(NSString *)pos {
    return [pos isKindOfClass:[NSString class]] &&
        ([pos isEqualToString:@"top"] || [pos isEqualToString:@"bottom"] ||
         [pos isEqualToString:@"left"] || [pos isEqualToString:@"right"]);
}

- (NSString *)tabPosition {
    // Stored under "general" so PLPreferences actually persists it.
    NSString *pos = getPrefObject([self prefKeyForPortrait:[self isPortraitNow]]);
    if ([self isValidTabPosition:pos]) return pos;
    // Migrate legacy single keys if present.
    for (NSString *k in @[@"general.profile_tabbar", @"profile.tabbar_position"]) {
        NSString *legacy = getPrefObject(k);
        if ([self isValidTabPosition:legacy]) {
            setPrefObject([self prefKeyForPortrait:[self isPortraitNow]], legacy);
            return legacy;
        }
    }
    return [self isPortraitNow] ? @"bottom" : @"left";
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    // Each orientation remembers its own position; apply on rotation.
    BOOL toPortrait = size.width > 0 && size.width < size.height;
    NSString *pos = getPrefObject([self prefKeyForPortrait:toPortrait]);
    if (![self isValidTabPosition:pos]) pos = toPortrait ? @"bottom" : @"left";
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
        [self applyTabPosition:pos animate:NO];
    } completion:nil];
}

- (void)cycleTabPosition {
    BOOL portrait = [self isPortraitNow];
    NSString *pos = [self tabPosition];
    NSString *next = @"left";
    if ([pos isEqualToString:@"left"]) next = @"top";
    else if ([pos isEqualToString:@"top"]) next = @"right";
    else if ([pos isEqualToString:@"right"]) next = @"bottom";
    setPrefObject([self prefKeyForPortrait:portrait], next);
    [HapticManager.shared play:HapticTypeSelection];
    [self applyTabPosition:next animate:YES];
}

- (void)applyTabPosition:(NSString *)pos animate:(BOOL)animate {
    if (![pos isKindOfClass:[NSString class]]) pos = @"left";
    if (_chromeConstraints) [NSLayoutConstraint deactivateConstraints:_chromeConstraints];
    BOOL vertical = [pos isEqualToString:@"left"] || [pos isEqualToString:@"right"];
    _tabStack.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    NSMutableArray *c = [NSMutableArray array];
    if ([pos isEqualToString:@"left"]) {
        [c addObjectsFromArray:@[
            [_tabPill.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_tabPill.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
            [_tabPill.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
            [_tabPill.widthAnchor constraintEqualToConstant:62],
            [_cardHost.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_cardHost.leadingAnchor constraintEqualToAnchor:_tabPill.trailingAnchor constant:8],
            [_cardHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
            [_cardHost.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        ]];
    } else if ([pos isEqualToString:@"right"]) {
        [c addObjectsFromArray:@[
            [_tabPill.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_tabPill.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
            [_tabPill.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
            [_tabPill.widthAnchor constraintEqualToConstant:62],
            [_cardHost.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_cardHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
            [_cardHost.trailingAnchor constraintEqualToAnchor:_tabPill.leadingAnchor constant:-8],
            [_cardHost.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        ]];
    } else if ([pos isEqualToString:@"top"]) {
        [c addObjectsFromArray:@[
            [_tabPill.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_tabPill.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
            [_tabPill.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
            [_tabPill.heightAnchor constraintEqualToConstant:56],
            [_cardHost.topAnchor constraintEqualToAnchor:_tabPill.bottomAnchor constant:8],
            [_cardHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
            [_cardHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
            [_cardHost.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        ]];
    } else {
        [c addObjectsFromArray:@[
            [_cardHost.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [_cardHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
            [_cardHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
            [_cardHost.bottomAnchor constraintEqualToAnchor:_tabPill.topAnchor constant:-8],
            [_tabPill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [_tabPill.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
            [_tabPill.heightAnchor constraintEqualToConstant:56],
        ]];
    }
    _chromeConstraints = c;
    void (^apply)(void) = ^{
        [NSLayoutConstraint activateConstraints:c];
        [self.view layoutIfNeeded];
    };
    if (animate) {
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.6 options:0 animations:apply completion:nil];
    } else {
        apply();
    }
}

- (void)doneTapped {
    [HapticManager.shared play:HapticTypeLight];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    _tabPill.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.30].CGColor;
    [self refreshTabColors];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)tabTapped:(ProfileRailTabButton *)sender {
    [HapticManager.shared play:HapticTypeSelection];
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_tabs.count) return;
    UIViewController *old = (self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)_tabs.count) ? _tabs[self.selectedIndex] : nil;
    UIViewController *vc = _tabs[index];
    _selectedIndex = index;
    if (old && old != vc) {
        [old willMoveToParentViewController:nil];
        [old.view removeFromSuperview];
        [old removeFromParentViewController];
    }
    if (vc.parentViewController != self) {
        [self addChildViewController:vc];
        vc.view.translatesAutoresizingMaskIntoConstraints = NO;
        vc.view.layer.cornerRadius = 20;
        vc.view.clipsToBounds = YES;
        [_cardHost addSubview:vc.view];
        [NSLayoutConstraint activateConstraints:@[
            [vc.view.topAnchor constraintEqualToAnchor:_cardHost.topAnchor],
            [vc.view.bottomAnchor constraintEqualToAnchor:_cardHost.bottomAnchor],
            [vc.view.leadingAnchor constraintEqualToAnchor:_cardHost.leadingAnchor],
            [vc.view.trailingAnchor constraintEqualToAnchor:_cardHost.trailingAnchor],
        ]];
        [vc didMoveToParentViewController:self];
    }
    [self refreshTabColors];
}

- (void)refreshTabColors {
    for (NSUInteger i = 0; i < _tabButtons.count; i++) {
        ProfileRailTabButton *btn = _tabButtons[i];
        [btn setActive:((NSInteger)i == _selectedIndex)];
    }
}

- (void)saveTapped {
    // Save lives in the overview tab; forward and stay on this page.
    [_overviewVC saveProfile];
    NSString *name = self.profile[@"name"];
    if ([name isKindOfClass:[NSString class]] && name.length > 0) self.navigationItem.title = name;
}

@end
