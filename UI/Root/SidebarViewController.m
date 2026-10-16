#import "SidebarViewController.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "LauncherPreferences.h"
#import "AmethystBlurView.h"

@interface SidebarTabItem : UIView
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIView *indicatorView;
@property (nonatomic) BOOL isSelected;
@property (nonatomic) BOOL indicatorHorizontal;
@property (nonatomic) NSArray<NSLayoutConstraint *> *indicatorConstraints;
@property (nonatomic, copy) void (^tapHandler)(void);
@end

@implementation SidebarTabItem

- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.text = title;
        [self addSubview:_titleLabel];

        _indicatorView = [[UIView alloc] init];
        _indicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _indicatorView.layer.cornerRadius = 1.5;
        _indicatorView.hidden = YES;
        [self addSubview:_indicatorView];
        [self applyIndicatorConstraints];

        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [NSLayoutConstraint constraintWithItem:_iconView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:-8],
            [_iconView.widthAnchor constraintEqualToConstant:24],
            [_iconView.heightAnchor constraintEqualToConstant:24],

            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:2],
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:2],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-2],
        ]];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)applyIndicatorConstraints {
    if (_indicatorConstraints) [NSLayoutConstraint deactivateConstraints:_indicatorConstraints];
    if (_indicatorHorizontal) {
        _indicatorConstraints = @[
            [_indicatorView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_indicatorView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3],
            [_indicatorView.widthAnchor constraintEqualToConstant:16],
            [_indicatorView.heightAnchor constraintEqualToConstant:3],
        ];
    } else {
        _indicatorConstraints = @[
            [_indicatorView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2],
            [_indicatorView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_indicatorView.widthAnchor constraintEqualToConstant:3],
            [_indicatorView.heightAnchor constraintEqualToConstant:16],
        ];
    }
    [NSLayoutConstraint activateConstraints:_indicatorConstraints];
}

- (void)setIndicatorHorizontal:(BOOL)indicatorHorizontal {
    if (_indicatorHorizontal == indicatorHorizontal) return;
    _indicatorHorizontal = indicatorHorizontal;
    [self applyIndicatorConstraints];
}

- (void)didTap {
    if (self.tapHandler) self.tapHandler();
}

- (void)setIsSelected:(BOOL)isSelected {
    _isSelected = isSelected;
    self.indicatorView.hidden = !isSelected;
}

@end

@interface SidebarViewController ()
@property (nonatomic) NSArray<SidebarTabItem *> *items;
@property (nonatomic) UIView *stackContainer;
@property (nonatomic) NSArray<NSDictionary *> *tabConfig;
@property (nonatomic) NSArray<NSLayoutConstraint *> *itemConstraints;
@end

@implementation SidebarViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.stackContainer = [[UIView alloc] init];
    self.stackContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stackContainer];

    NSArray *tabConfig = @[
        @{@"icon": @"gamecontroller", @"title": @"Game"},
        @{@"icon": @"wrench.adjustable", @"title": @"Mod"},
        @{@"icon": @"shippingbox", @"title": @"Modpack"},
        @{@"icon": @"paintpalette", @"title": @"Shader"},
        @{@"icon": @"paintbrush.fill", @"title": @"Resource Pack"},
        @{@"icon": @"map", @"title": @"Maps"},
    ];
    _tabConfig = tabConfig;

    NSMutableArray *itemArray = [NSMutableArray array];
    for (int i = 0; i < tabConfig.count; i++) {
        NSDictionary *config = tabConfig[i];
        SidebarTabItem *item = [[SidebarTabItem alloc] initWithIcon:config[@"icon"] title:config[@"title"]];
        item.tag = i;
        __weak typeof(self) weakSelf = self;
        item.tapHandler = ^{
            [HapticManager.shared play:HapticTypeLight];
            [weakSelf selectItemAtIndex:i];
        };
        [self.stackContainer addSubview:item];
        [itemArray addObject:item];
    }
    [self rebuildItemConstraints];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stackContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.stackContainer.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.stackContainer.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.85],
    ]];

    self.items = itemArray;
    self.selectedTab = SidebarTabGame;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
        [self updateColors];
    }

// Rebuilds item layout for vertical (side rails) vs horizontal (bottom bar).
- (void)rebuildItemConstraints {
    if (_itemConstraints) [NSLayoutConstraint deactivateConstraints:_itemConstraints];
    NSMutableArray *c = [NSMutableArray array];
    NSUInteger n = self.items.count;
    if (_horizontal) {
        SidebarTabItem *prev = nil;
        for (SidebarTabItem *item in self.items) {
            [c addObjectsFromArray:@[
                [item.topAnchor constraintEqualToAnchor:self.stackContainer.topAnchor],
                [item.bottomAnchor constraintEqualToAnchor:self.stackContainer.bottomAnchor],
                [item.widthAnchor constraintEqualToAnchor:self.stackContainer.widthAnchor multiplier:1.0/n],
            ]];
            if (prev) [c addObject:[item.leadingAnchor constraintEqualToAnchor:prev.trailingAnchor]];
            else [c addObject:[item.leadingAnchor constraintEqualToAnchor:self.stackContainer.leadingAnchor]];
            prev = item;
        }
        if (prev) [c addObject:[prev.trailingAnchor constraintEqualToAnchor:self.stackContainer.trailingAnchor]];
    } else {
        SidebarTabItem *prev = nil;
        for (SidebarTabItem *item in self.items) {
            [c addObjectsFromArray:@[
                [item.leadingAnchor constraintEqualToAnchor:self.stackContainer.leadingAnchor],
                [item.trailingAnchor constraintEqualToAnchor:self.stackContainer.trailingAnchor],
                [item.heightAnchor constraintEqualToAnchor:self.stackContainer.heightAnchor multiplier:1.0/n],
            ]];
            if (prev) [c addObject:[item.topAnchor constraintEqualToAnchor:prev.bottomAnchor]];
            else [c addObject:[item.topAnchor constraintEqualToAnchor:self.stackContainer.topAnchor]];
            prev = item;
        }
        if (prev) [c addObject:[prev.bottomAnchor constraintEqualToAnchor:self.stackContainer.bottomAnchor]];
    }
    _itemConstraints = c;
    [NSLayoutConstraint activateConstraints:c];
    for (SidebarTabItem *item in self.items) {
        item.indicatorHorizontal = _horizontal;
    }
}

- (void)setHorizontal:(BOOL)horizontal {
    if (_horizontal == horizontal && _itemConstraints) return;
    _horizontal = horizontal;
    if (!self.items) return;
    [self rebuildItemConstraints];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    if ([AmethystBlurView blurEnabledForKey:@"amethyst_sidebar_blur"]) {
        self.view.backgroundColor = [theme.sidebarBackgroundColor colorWithAlphaComponent:0.25 * theme.uiOpacity];
    } else {
        self.view.backgroundColor = theme.sidebarBackgroundColor;
    }
    for (SidebarTabItem *item in self.items) {
        item.iconView.tintColor = item.isSelected ? theme.accentColor : theme.secondaryTextColor;
        item.titleLabel.textColor = item.isSelected ? theme.accentColor : theme.secondaryTextColor;
        item.indicatorView.backgroundColor = theme.accentColor;
    }
}

- (void)selectItemAtIndex:(NSInteger)index {
    if (index == self.selectedTab) return;

    for (SidebarTabItem *item in self.items) {
        item.isSelected = NO;
    }
    self.items[index].isSelected = YES;
    self.selectedTab = index;
    [self updateColors];

    if (self.delegate) {
        [self.delegate sidebarDidSelectTab:index];
    }
}

- (void)setSelectedTab:(SidebarTab)tab {
    _selectedTab = tab;
    for (SidebarTabItem *item in self.items) {
        item.isSelected = NO;
    }
    self.items[tab].isSelected = YES;
    [self updateColors];
}

- (void)setSelectedTab:(SidebarTab)tab animated:(BOOL)animated {
    [self selectItemAtIndex:tab];
}

- (void)updateTabAvailabilityForLoader:(NSString *)loader {
    BOOL isVanilla = !loader || [loader isEqualToString:@"Vanilla"] || loader.length == 0;
    for (NSUInteger i = 0; i < self.items.count; i++) {
        SidebarTabItem *item = self.items[i];
        if (i == SidebarTabMod || i == SidebarTabShader) {
            item.alpha = isVanilla ? 0.35 : 1.0;
            item.userInteractionEnabled = !isVanilla;
        } else {
            item.alpha = 1.0;
            item.userInteractionEnabled = YES;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
