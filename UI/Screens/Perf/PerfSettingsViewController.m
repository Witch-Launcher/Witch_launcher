#import "PerfSettingsViewController.h"

#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "PerfHistoryViewController.h"
#import "PerfRecorder.h"
#import "PerfSessionStore.h"
#import "ThemeManager.h"
#import "utils.h"

@interface PerfSettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray<NSMutableDictionary *> *recordRows;
@property (nonatomic) NSMutableArray<NSMutableDictionary *> *metricRows;
@end

@implementation PerfSettingsViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = localize(@"perf.title", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];

    _recordRows = [NSMutableArray arrayWithArray:@[
        [@{@"kind": @"switch", @"key": @"perf.record", @"label": localize(@"perf.settings.record", nil)} mutableCopy],
        [@{@"kind": @"navigate", @"label": localize(@"perf.settings.history", nil), @"detail": @""} mutableCopy],
    ]];
    _metricRows = [NSMutableArray new];
    for (NSString *name in PerfMetricNames()) {
        NSString *key = [@"perf.metric_" stringByAppendingString:name];
        NSString *label = localize([@"perf.metric." stringByAppendingString:name], nil);
        [_metricRows addObject:[@{@"kind": @"switch", @"key": key, @"label": label} mutableCopy]];
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSInteger count = [PerfSessionStore sessionCount];
    _recordRows[1][@"detail"] = [NSString stringWithFormat:@"%ld", (long)count];
    [_tableView reloadData];
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
    return section == 0 ? _recordRows.count : _metricRows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? localize(@"perf.settings.record_section", nil) : localize(@"perf.settings.metrics", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 1 ? localize(@"perf.settings.metrics_footer", nil) : nil;
}

- (NSArray<NSMutableDictionary *> *)rowsForSection:(NSInteger)section {
    return section == 0 ? _recordRows : _metricRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *item = [self rowsForSection:indexPath.section][indexPath.row];
    NSString *kind = item[@"kind"];

    if ([kind isEqualToString:@"switch"]) {
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

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"navigate"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"navigate"];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.textLabel.text = item[@"label"];
    cell.detailTextLabel.text = item[@"detail"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSMutableDictionary *item = [self rowsForSection:indexPath.section][indexPath.row];
    if (![item[@"kind"] isEqualToString:@"navigate"]) {
        return;
    }
    PerfHistoryViewController *vc = [[PerfHistoryViewController alloc] init];
    vc.title = item[@"label"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)switchChanged:(UISwitch *)sender {
    if (sender.tag < 0) {
        setPrefBool(@"perf.record", sender.on);
        return;
    }
    NSArray<NSString *> *names = PerfMetricNames();
    if ((NSUInteger)sender.tag >= names.count) {
        return;
    }
    NSString *key = [@"perf.metric_" stringByAppendingString:names[sender.tag]];
    setPrefBool(key, sender.on);
}

@end
