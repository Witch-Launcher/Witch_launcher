#import "GameListViewController.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"

@interface GameListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *gameVersions;
@end

@implementation GameListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [self updateColors];
}

- (void)setup {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.text = @"Game Versions";
    [self.view addSubview:_titleLabel];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [_tableView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:12],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // MOCK DATA - thay bằng nguồn thật sau
    _gameVersions = [NSMutableArray arrayWithObjects:
        @{@"version": @"1.21.4", @"loader": @"Fabric", @"icon": @"gamecontroller"},
        @{@"version": @"1.21.3", @"loader": @"Forge", @"icon": @"gamecontroller"},
        nil
    ];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    // Clear when frost is on so the tab interior matches the shell exterior;
    // the realtime blur layer provides the backdrop.
    self.view.backgroundColor = [AmethystBlurView blurEnabled] ? [UIColor clearColor] : theme.contentBackgroundColor;
    _titleLabel.textColor = theme.primaryTextColor;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _gameVersions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSDictionary *version = _gameVersions[indexPath.row];
    cell.textLabel.text = version[@"version"];
    cell.detailTextLabel.text = version[@"loader"];
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.layer.cornerRadius = 8;
    cell.clipsToBounds = YES;
    return cell;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
