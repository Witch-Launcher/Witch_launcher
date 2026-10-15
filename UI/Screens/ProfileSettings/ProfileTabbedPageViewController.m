#import "ProfileTabbedPageViewController.h"
#import "ProfileOverviewVC.h"
#import "ProfileContentListVC.h"
#import "ProfileWorldsVC.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "InstalledModsManager.h"

@interface ProfileTabbedPageViewController ()
@property (nonatomic) UIView *cardHost;
@property (nonatomic) UIView *tabPill;
@property (nonatomic) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic) NSArray<UIViewController *> *tabs;
@property (nonatomic) ProfileOverviewVC *overviewVC;
@property (nonatomic) NSInteger selectedIndex;
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTapped)];
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
    _tabPill.layer.cornerRadius = 22;
    _tabPill.clipsToBounds = YES;
    _tabPill.layer.borderWidth = 1;
    _tabPill.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.30].CGColor;
    [self.view addSubview:_tabPill];
    [AmethystBlurView installInView:_tabPill];

    NSArray *icons = @[@"person.crop.circle", @"puzzlepiece.extension", @"paintbrush.pointed", @"paintpalette", @"globe"];
    NSArray *labels = @[@"Home", @"Mods", @"Shader", @"Packs", @"Worlds"];
    _tabButtons = [NSMutableArray array];
    UIView *prev = nil;
    for (NSUInteger i = 0; i < 5; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.tag = i;
        UIImage *img = [UIImage systemImageNamed:icons[i]];
        [btn setImage:img forState:UIControlStateNormal];
        [btn setTitle:labels[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        btn.tintColor = ThemeManager.shared.secondaryTextColor;
        [btn setTitleColor:ThemeManager.shared.secondaryTextColor forState:UIControlStateNormal];
        // Stack image above label
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [btn setImageEdgeInsets:UIEdgeInsetsMake(-12, 0, 0, -30)];
        [btn setTitleEdgeInsets:UIEdgeInsetsMake(16, -28, 0, 0)];
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabPill addSubview:btn];
        [_tabButtons addObject:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.topAnchor constraintEqualToAnchor:_tabPill.topAnchor constant:6],
            [btn.bottomAnchor constraintEqualToAnchor:_tabPill.bottomAnchor constant:-6],
            [btn.widthAnchor constraintEqualToConstant:64],
        ]];
        if (prev) {
            [btn.leadingAnchor constraintEqualToAnchor:prev.trailingAnchor constant:2].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:_tabPill.leadingAnchor constant:8].active = YES;
        }
        prev = btn;
    }
    [prev.trailingAnchor constraintEqualToAnchor:_tabPill.trailingAnchor constant:-8].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [_cardHost.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [_cardHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_cardHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_cardHost.bottomAnchor constraintEqualToAnchor:_tabPill.topAnchor constant:-8],
        [_tabPill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_tabPill.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [_tabPill.heightAnchor constraintEqualToConstant:64],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self selectTab:0];
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
