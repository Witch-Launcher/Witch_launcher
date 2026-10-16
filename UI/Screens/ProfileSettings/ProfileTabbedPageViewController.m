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
@property (nonatomic) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic) NSArray<UIViewController *> *tabs;
@property (nonatomic) ProfileOverviewVC *overviewVC;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic) NSArray<NSLayoutConstraint *> *chromeConstraints;
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
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = i;
        UIImage *img = [UIImage systemImageNamed:icons[i]];
        [btn setImage:img forState:UIControlStateNormal];
        [btn setTitle:labels[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightMedium];
        btn.tintColor = ThemeManager.shared.secondaryTextColor;
        [btn setTitleColor:ThemeManager.shared.secondaryTextColor forState:UIControlStateNormal];
        // Stack image above label
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [btn setImageEdgeInsets:UIEdgeInsetsMake(-12, 0, 0, -30)];
        [btn setTitleEdgeInsets:UIEdgeInsetsMake(16, -28, 0, 0)];
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabStack addArrangedSubview:btn];
        [_tabButtons addObject:btn];
    }

    [self applyTabPosition:[self tabPosition] animate:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self selectTab:0];
}

#pragma mark - Tab pill position (left / top / right / bottom, default left)

- (NSString *)tabPosition {
    // NOTE: must live under an existing pref section ("general") — keys under
    // unknown sections are silently dropped by PLPreferences and never persist.
    NSString *pos = getPrefObject(@"general.profile_tabbar");
    if ([pos isKindOfClass:[NSString class]] &&
        ([pos isEqualToString:@"top"] || [pos isEqualToString:@"bottom"] ||
         [pos isEqualToString:@"left"] || [pos isEqualToString:@"right"])) return pos;
    // Migrate the old (never-persisted) key if present in memory.
    NSString *legacy = getPrefObject(@"profile.tabbar_position");
    if ([legacy isKindOfClass:[NSString class]] &&
        ([legacy isEqualToString:@"top"] || [legacy isEqualToString:@"bottom"] ||
         [legacy isEqualToString:@"left"] || [legacy isEqualToString:@"right"])) {
        setPrefObject(@"general.profile_tabbar", legacy);
        return legacy;
    }
    // No explicit choice yet: portrait defaults to bottom, landscape to left.
    CGSize size = self.view.bounds.size;
    if (size.width > 0 && size.width < size.height) return @"bottom";
    return @"left";
}

- (BOOL)hasExplicitTabPosition {
    NSString *pos = getPrefObject(@"general.profile_tabbar");
    return [pos isKindOfClass:[NSString class]] && pos.length > 0;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    // Auto-follow orientation until the user picks a position explicitly.
    if (![self hasExplicitTabPosition]) {
        NSString *next = (size.width > 0 && size.width < size.height) ? @"bottom" : @"left";
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
            [self applyTabPosition:next animate:NO];
        } completion:nil];
    }
}

- (void)cycleTabPosition {
    NSString *pos = [self tabPosition];
    NSString *next = @"left";
    if ([pos isEqualToString:@"left"]) next = @"top";
    else if ([pos isEqualToString:@"top"]) next = @"right";
    else if ([pos isEqualToString:@"right"]) next = @"bottom";
    setPrefObject(@"general.profile_tabbar", next);
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
    _tabPill.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.30].CGColor;
    [self refreshTabColors];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)tabTapped:(UIButton *)sender {
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
        UIButton *btn = _tabButtons[i];
        BOOL sel = ((NSInteger)i == _selectedIndex);
        UIColor *c = sel ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;
        btn.tintColor = c;
        [btn setTitleColor:c forState:UIControlStateNormal];
    }
}

- (void)saveTapped {
    // Save lives in the overview tab; forward and stay on this page.
    [_overviewVC saveProfile];
    NSString *name = self.profile[@"name"];
    if ([name isKindOfClass:[NSString class]] && name.length > 0) self.navigationItem.title = name;
}

@end
