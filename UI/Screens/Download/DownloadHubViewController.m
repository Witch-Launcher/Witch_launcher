#import "DownloadHubViewController.h"
#import "ThemeManager.h"
#import "MainCoordinator.h"
#import "HapticManager.h"
#import "VersionBrowserViewController.h"
#import "MapListViewController.h"
#import "ResourcePackListViewController.h"
#import "AmethystBlurView.h"

@interface DownloadHubCategoryCard : UIView
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *descLabel;
@property (nonatomic) NSString *categoryId;
@end

@implementation DownloadHubCategoryCard
- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title description:(NSString *)desc color:(UIColor *)color categoryId:(NSString *)categoryId {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _categoryId = categoryId;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 14;
        self.clipsToBounds = YES;
        self.backgroundColor = color;

        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [UIColor whiteColor];
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.text = title;
        [self addSubview:_titleLabel];

        _descLabel = [[UILabel alloc] init];
        _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _descLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _descLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
        _descLabel.text = desc;
        [self addSubview:_descLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_iconView.widthAnchor constraintEqualToConstant:32],
            [_iconView.heightAnchor constraintEqualToConstant:32],

            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:10],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],

            [_descLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_descLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_descLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        ]];
    }
    return self;
}
@end

@interface DownloadHubViewController ()

@end

@implementation DownloadHubViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)setup {
    self.navigationItem.title = @"Download Hub";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismissSelf)];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    subtitleLabel.text = @"Browse and install content for Minecraft";
    [self.view addSubview:subtitleLabel];

    UIColor *purple = [UIColor colorWithRed:0.37 green:0.37 blue:0.90 alpha:1];
    UIColor *green = [UIColor colorWithRed:0.20 green:0.84 blue:0.29 alpha:1];
    UIColor *orange = [UIColor colorWithRed:1.00 green:0.62 blue:0.04 alpha:1];
    UIColor *blue = [UIColor colorWithRed:0.39 green:0.82 blue:1.00 alpha:1];
    UIColor *teal = [UIColor colorWithRed:0.35 green:0.78 blue:0.70 alpha:1];
    UIColor *red = [UIColor colorWithRed:0.90 green:0.30 blue:0.30 alpha:1];

    NSArray *categories = @[
        @{@"icon": @"cube.box", @"title": @"Game", @"desc": @"Install & manage versions", @"color": purple, @"id": @"game"},
        @{@"icon": @"wrench.and.screwdriver", @"title": @"Mod", @"desc": @"Browse Modrinth mods", @"color": green, @"id": @"mod"},
        @{@"icon": @"square.stack.3d.up", @"title": @"Modpack", @"desc": @"Curated mod collections", @"color": orange, @"id": @"modpack"},
        @{@"icon": @"paintpalette", @"title": @"Shader", @"desc": @"Iris & Optifine packs", @"color": blue, @"id": @"shader"},
        @{@"icon": @"paintbrush.fill", @"title": @"Resource Pack", @"desc": @"Textures & visual overhauls", @"color": red, @"id": @"resourcepack"},
        @{@"icon": @"map", @"title": @"Maps", @"desc": @"Worlds & adventure maps", @"color": teal, @"id": @"map"},
    ];

    CGFloat cardHeight = 110;
    CGFloat spacing = 12;

    UIStackView *topRow = [[UIStackView alloc] init];
    topRow.translatesAutoresizingMaskIntoConstraints = NO;
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.distribution = UIStackViewDistributionFillEqually;
    topRow.spacing = spacing;

    UIStackView *bottomRow = [[UIStackView alloc] init];
    bottomRow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.distribution = UIStackViewDistributionFillEqually;
    bottomRow.spacing = spacing;

    for (NSUInteger i = 0; i < categories.count; i++) {
        NSDictionary *cat = categories[i];
        DownloadHubCategoryCard *card = [[DownloadHubCategoryCard alloc]
            initWithIcon:cat[@"icon"] title:cat[@"title"]
            description:cat[@"desc"] color:cat[@"color"] categoryId:cat[@"id"]];
        card.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cardTapped:)];
        [card addGestureRecognizer:tap];

        if (i < 3) {
            [topRow addArrangedSubview:card];
        } else {
            [bottomRow addArrangedSubview:card];
        }
    }

    [self.view addSubview:subtitleLabel];
    [self.view addSubview:topRow];
    [self.view addSubview:bottomRow];

    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [topRow.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:20],
        [topRow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [topRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [topRow.heightAnchor constraintEqualToConstant:cardHeight],

        [bottomRow.topAnchor constraintEqualToAnchor:topRow.bottomAnchor constant:spacing],
        [bottomRow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [bottomRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [bottomRow.heightAnchor constraintEqualToConstant:cardHeight],
    ]];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cardTapped:(UITapGestureRecognizer *)tap {
    [HapticManager.shared play:HapticTypeLight];
    DownloadHubCategoryCard *card = (DownloadHubCategoryCard *)tap.view;

    if ([card.categoryId isEqualToString:@"game"]) {
        VersionBrowserViewController *vc = [[VersionBrowserViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else if ([card.categoryId isEqualToString:@"map"]) {
        MapListViewController *vc = [[MapListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else if ([card.categoryId isEqualToString:@"mod"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.coordinator switchToTab:SidebarTabMod];
        }];
    } else if ([card.categoryId isEqualToString:@"modpack"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.coordinator switchToTab:SidebarTabModpack];
        }];
    } else if ([card.categoryId isEqualToString:@"shader"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.coordinator switchToTab:SidebarTabShader];
        }];
    } else if ([card.categoryId isEqualToString:@"resourcepack"]) {
        ResourcePackListViewController *vc = [[ResourcePackListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
