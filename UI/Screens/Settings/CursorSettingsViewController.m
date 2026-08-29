#import "CursorSettingsViewController.h"
#import "CursorTypeDetailViewController.h"
#import "CursorTypeManager.h"
#import "CursorManager.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface CursorSettingsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *cursorTypes;

@end

@implementation CursorSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    self.navigationItem.title = localize(@"cursor.settings.title", nil);

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self reloadData];
    [AmethystBlurView installInView:self.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    _cursorTypes = [CursorTypeManager allCursorTypes];
    [_tableView reloadData];
}

#pragma mark - Master toggle

- (void)masterToggleChanged:(UISwitch *)sender {
    [HapticManager.shared play:HapticTypeLight];
    [CursorTypeManager setMasterToggleEnabled:sender.isOn];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Section 0: master toggle, Section 1: cursor types
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return _cursorTypes.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MasterToggleCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MasterToggleCell"];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        }
        cell.textLabel.text = localize(@"cursor.settings.enable_switching", nil);
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [CursorTypeManager isMasterToggleEnabled];
        [toggle addTarget:self action:@selector(masterToggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;

        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CursorTypeCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CursorTypeCell"];
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }

    NSDictionary *typeDef = _cursorTypes[indexPath.row];
    NSString *typeId = typeDef[kCursorTypeId];
    BOOL isEnabled = [CursorTypeManager isEnabledForType:typeId];
    BOOL isActive = [[CursorTypeManager currentActiveTypeId] isEqualToString:typeId];

    cell.textLabel.text = [CursorTypeManager localizedNameForType:typeId];
    cell.textLabel.textColor = isActive ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;

    NSString *assignedCursor = [CursorTypeManager cursorForType:typeId];
    NSString *cursorDisplayName = [CursorManager isDefaultCursor:assignedCursor] ? localize(@"cursor.detail.default_builtin", nil) : assignedCursor;
    NSString *status = @"";
    if (!isEnabled) status = [NSString stringWithFormat:@"  (%@)", localize(@"general.disabled", nil)];
    else if (isActive) status = [NSString stringWithFormat:@"  (%@)", localize(@"general.active", nil)];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@%@", localize(@"cursor.settings.cursor", nil), cursorDisplayName, status];
    cell.detailTextLabel.textColor = isActive ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.image = [CursorTypeManager imageForType:typeId];
    cell.accessoryView = iconView;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;

    [HapticManager.shared play:HapticTypeLight];
    NSString *typeId = _cursorTypes[indexPath.row][kCursorTypeId];
    CursorTypeDetailViewController *detail = [[CursorTypeDetailViewController alloc] init];
    detail.typeId = typeId;
    [self.navigationController pushViewController:detail animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return localize(@"cursor.settings.master_switch", nil);
    return localize(@"cursor.settings.cursor_types", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return localize(@"cursor.settings.master_switch.footer", nil);
    return localize(@"cursor.settings.cursor_types.footer", nil);
}

@end
