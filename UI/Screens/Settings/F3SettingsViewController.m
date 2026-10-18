#import "F3SettingsViewController.h"

#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "ThemeManager.h"
#import "utils.h"

@interface F3SettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray<NSMutableDictionary *> *masterRows;
@property (nonatomic) NSMutableArray<NSMutableDictionary *> *lineRows;
@end

@implementation F3SettingsViewController

static NSArray<NSString *> *F3LineKeys(void) {
    return @[
        @"show_chip",
        @"show_ios",
        @"show_launcher_name",
        @"show_launcher_version",
        @"show_build",
        @"show_build_type",
    ];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = localize(@"f3.title", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];

    _masterRows = [NSMutableArray arrayWithArray:@[
        [@{@"kind": @"switch", @"key": @"f3.enabled", @"label": localize(@"f3.settings.enable", nil)} mutableCopy],
    ]];
    _lineRows = [NSMutableArray new];
    for (NSString *name in F3LineKeys()) {
        NSString *key = [@"f3." stringByAppendingString:name];
        NSString *label = localize([@"f3.settings." stringByAppendingString:name], nil);
        [_lineRows addObject:[@{@"kind": @"switch", @"key": key, @"label": label} mutableCopy]];
    }

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [_tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? _masterRows.count : _lineRows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? localize(@"f3.settings.section", nil) : localize(@"f3.settings.lines", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 1 ? localize(@"f3.settings.footer", nil) : nil;
}

- (NSArray<NSMutableDictionary *> *)rowsForSection:(NSInteger)section {
    return section == 0 ? _masterRows : _lineRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *item = [self rowsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switch"];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = ThemeManager.shared.accentColor;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.textLabel.text = item[@"label"];
    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.on = getPrefBool(item[@"key"]);
    sw.tag = indexPath.section == 0 ? -1 : (NSInteger)indexPath.row;
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    if (sender.tag < 0) {
        setPrefBool(@"f3.enabled", sender.on);
        return;
    }
    NSArray<NSString *> *names = F3LineKeys();
    if ((NSUInteger)sender.tag >= names.count) {
        return;
    }
    NSString *key = [@"f3." stringByAppendingString:names[sender.tag]];
    setPrefBool(key, sender.on);
}

@end
