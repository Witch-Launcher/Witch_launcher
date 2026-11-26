#import "StorageManagerViewController.h"
#import "ThemeManager.h"
#import "AppSheet.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "AmethystBlurView.h"
#import "VersionDirectoryManager.h"
#import "WitchRuntimeService.h"
#import "WitchUpdateService.h"
#import "PLProfiles.h"
#import "utils.h"

typedef NS_ENUM(NSInteger, StorageRowKind) {
    StorageRowKindVersion = 0,
    StorageRowKindRuntime,
    StorageRowKindInstaller,
};

@interface StorageRow : NSObject
@property (nonatomic) StorageRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *path;          // version dir / installer file
@property (nonatomic) WitchRuntimeItem *runtimeItem;
@end

@implementation StorageRow
@end

@interface StorageManagerViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray<StorageRow *> *versionRows;
@property (nonatomic) NSMutableArray<StorageRow *> *runtimeRows;
@property (nonatomic) NSMutableArray<StorageRow *> *installerRows;
@end

@implementation StorageManagerViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = localize(@"settings.storage", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Opaque base under the frost: without this the previous screen shows
    // through the pushed page.
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
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
    [self reloadContent];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [_tableView reloadData];
}

#pragma mark - Data

- (void)reloadContent {
    _versionRows = [NSMutableArray array];
    _runtimeRows = [NSMutableArray array];
    _installerRows = [NSMutableArray array];

    // Minecraft versions (POJAV_HOME/versions/*)
    NSString *versionsRoot = [VersionDirectoryManager shared].versionsRootPath;
    NSArray<NSString *> *versionDirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:versionsRoot error:nil] ?: @[];
    NSString *currentVersion = [VersionDirectoryManager shared].currentVersion;
    for (NSString *name in [versionDirs sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        BOOL isDir = NO;
        NSString *full = [versionsRoot stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            StorageRow *row = [StorageRow new];
            row.kind = StorageRowKindVersion;
            row.title = name;
            row.path = full;
            row.subtitle = [self versionSubtitleFor:name isCurrent:[name isEqualToString:currentVersion]];
            [_versionRows addObject:row];
        }
    }

    // JDK + LWJGL from the runtime service (installed entries first).
    NSArray<WitchRuntimeItem *> *items = [WitchRuntimeService.shared builtinItems];
    NSMutableArray<WitchRuntimeItem *> *sorted = [items mutableCopy];
    [sorted sortUsingComparator:^NSComparisonResult(WitchRuntimeItem *a, WitchRuntimeItem *b) {
        if (a.installed != b.installed) return a.installed ? NSOrderedAscending : NSOrderedDescending;
        return [a.displayName compare:b.displayName];
    }];
    for (WitchRuntimeItem *item in sorted) {
        StorageRow *row = [StorageRow new];
        row.kind = StorageRowKindRuntime;
        row.title = item.displayName;
        row.runtimeItem = item;
        row.subtitle = item.installed
            ? [NSString stringWithFormat:@"%@  •  %@", localize(@"storage.installed", nil), item.localVersion ?: @""]
            : localize(@"storage.not_installed", nil);
        [_runtimeRows addObject:row];
    }

    // Saved launcher installers (.amethyst/updates/*.ipa|tipa)
    NSString *updatesDir = amethyst_hidden_dir(@"updates");
    NSArray<NSString *> *updates = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:updatesDir error:nil] ?: @[];
    for (NSString *name in [updates sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        NSString *ext = name.pathExtension.lowercaseString;
        if (!([ext isEqualToString:@"ipa"] || [ext isEqualToString:@"tipa"])) continue;
        NSString *full = [updatesDir stringByAppendingPathComponent:name];
        StorageRow *row = [StorageRow new];
        row.kind = StorageRowKindInstaller;
        row.title = name;
        row.path = full;
        [self fillSizeSubtitle:row path:full];
        [_installerRows addObject:row];
    }

    [_tableView reloadData];
}

- (void)fillSizeSubtitle:(StorageRow *)row path:(NSString *)path {
    row.subtitle = [self sizeStringForPath:path];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *date = attrs[NSFileModificationDate];
    if (date) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterMediumStyle;
        fmt.timeStyle = NSDateFormatterNoStyle;
        row.subtitle = [NSString stringWithFormat:@"%@  •  %@", row.subtitle, [fmt stringFromDate:date]];
    }
}

- (NSString *)versionSubtitleFor:(NSString *)version isCurrent:(BOOL)isCurrent {
    NSUInteger count = 0;
    NSDictionary *profiles = [PLProfiles current].profiles;
    for (NSString *key in profiles) {
        NSString *last = profiles[key][@"lastVersionId"];
        if ([last isKindOfClass:[NSString class]] && [last isEqualToString:version]) count++;
    }
    NSMutableArray *parts = [NSMutableArray array];
    if (isCurrent) [parts addObject:localize(@"storage.current", nil)];
    if (count > 0) [parts addObject:[NSString stringWithFormat:localize(@"storage.in_use", nil), (unsigned long)count]];
    [parts addObject:[self sizeStringForPath:[self versionPathFor:version]]];
    return [parts componentsJoinedByString:@"  •  "];
}

- (NSString *)versionPathFor:(NSString *)version {
    return [[VersionDirectoryManager shared].versionsRootPath stringByAppendingPathComponent:version];
}

- (NSString *)sizeStringForPath:(NSString *)path {
    unsigned long long bytes = [self directorySize:path];
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

- (unsigned long long)directorySize:(NSString *)path {
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) return 0;
    if (!isDir) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        return [attrs fileSize];
    }
    unsigned long long total = 0;
    NSDirectoryEnumerator *en = [[NSFileManager defaultManager] enumeratorAtPath:path];
    for (NSString *rel in en) {
        NSString *full = [path stringByAppendingPathComponent:rel];
        BOOL subIsDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&subIsDir];
        if (subIsDir) continue;
        total += [[[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil] fileSize];
    }
    return total;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return MAX((NSInteger)_versionRows.count, 1);
    if (section == 1) return MAX((NSInteger)_runtimeRows.count, 1);
    return MAX((NSInteger)_installerRows.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return localize(@"storage.section.versions", nil);
    if (section == 1) return localize(@"storage.section.runtimes", nil);
    return localize(@"storage.section.updates", nil);
}

- (NSArray<StorageRow *> *)rowsForSection:(NSInteger)section {
    if (section == 0) return _versionRows;
    if (section == 1) return _runtimeRows;
    return _installerRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<StorageRow *> *rows = [self rowsForSection:indexPath.section];
    if (rows.count == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = indexPath.section == 0 ? localize(@"storage.empty.versions", nil)
            : (indexPath.section == 1 ? localize(@"storage.empty.runtimes", nil) : localize(@"storage.empty.updates", nil));
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StorageCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"StorageCell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    StorageRow *row = rows[indexPath.row];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<StorageRow *> *rows = [self rowsForSection:indexPath.section];
    if (indexPath.row >= (NSInteger)rows.count) return;
    StorageRow *row = rows[indexPath.row];
    if (row.kind == StorageRowKindVersion) [self showVersionActions:row];
    else if (row.kind == StorageRowKindRuntime) [self showRuntimeActions:row];
    else [self showInstallerActions:row];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<StorageRow *> *rows = [self rowsForSection:indexPath.section];
    if (indexPath.row >= (NSInteger)rows.count) return nil;
    StorageRow *row = rows[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:localize(@"Delete", nil) handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf confirmDeleteRow:row];
        done(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash"];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[del]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

#pragma mark - Actions

- (void)showVersionActions:(StorageRow *)row {
    NSString *version = row.title;
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:version
                           message:row.subtitle
                           options:@[
        @{@"title": localize(@"storage.action.use_version", nil), @"icon": @"plus.circle"},
        @{@"title": localize(@"Delete", nil), @"icon": @"trash", @"destructive": @YES},
        @{@"title": localize(@"Done", nil), @"icon": @"checkmark"},
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0) [weakSelf createProfileWithVersion:version];
        else if (idx == 1) [weakSelf confirmDeleteVersion:version];
    }];
}

- (void)createProfileWithVersion:(NSString *)version {
    NSMutableDictionary *profiles = [PLProfiles current].profiles;
    NSString *name = version;
    NSInteger n = 2;
    while (profiles[name] && n < 100) {
        name = [NSString stringWithFormat:@"%@ (%ld)", version, (long)n];
        n++;
    }
    VersionProfile *vp = [VersionProfile profileWithVersionId:version];
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    profile[@"name"] = name;
    profile[@"lastVersionId"] = version;
    profile[@"modLoader"] = vp.modLoader.length > 0 ? vp.modLoader : @"fabric";
    profile[@"avatar"] = profile[@"modLoader"];
    profiles[name] = profile;
    [[PLProfiles current] save];
    [HapticManager.shared play:HapticTypeSuccess];
    showDialog(localize(@"storage.profile_created_title", nil),
               [NSString stringWithFormat:localize(@"storage.profile_created", nil), name]);
    [self reloadContent];
}

- (void)confirmDeleteRow:(StorageRow *)row {
    if (row.kind == StorageRowKindVersion) [self confirmDeleteVersion:row.title];
    else if (row.kind == StorageRowKindRuntime) [self confirmDeleteRuntime:row.runtimeItem];
    else [self confirmDeleteInstaller:row];
}

- (void)confirmDeleteVersion:(NSString *)version {
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:localize(@"storage.delete_version_title", nil)
                           message:[NSString stringWithFormat:localize(@"storage.delete_version_msg", nil), version]
                      confirmTitle:localize(@"Delete", nil)
                       destructive:YES
                          onConfirm:^{
        NSError *err = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:[weakSelf versionPathFor:version] error:&err]) {
            [ErrorPresenter showFileError:@"Delete" path:version error:err];
            return;
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf reloadContent];
    }];
}

- (void)showRuntimeActions:(StorageRow *)row {
    WitchRuntimeItem *item = row.runtimeItem;
    NSMutableArray *options = [NSMutableArray array];
    [options addObject:@{@"title": localize(@"storage.action.manage", nil), @"icon": @"gearshape"}];
    if (item.installed) [options addObject:@{@"title": localize(@"Delete", nil), @"icon": @"trash", @"destructive": @YES}];
    [options addObject:@{@"title": localize(@"Done", nil), @"icon": @"checkmark"}];
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:item.displayName message:row.subtitle options:options selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0) [weakSelf openRuntimeManager];
        else if (idx == 1 && item.installed) [weakSelf confirmDeleteRuntime:item];
    }];
}

- (void)openRuntimeManager {
    Class vcClass = NSClassFromString(@"RuntimeDownloadViewController");
    if (!vcClass) return;
    UIViewController *vc = [[vcClass alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)confirmDeleteRuntime:(WitchRuntimeItem *)item {
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:localize(@"storage.delete_runtime_title", nil)
                           message:item.displayName
                      confirmTitle:localize(@"Delete", nil)
                       destructive:YES
                          onConfirm:^{
        NSError *err = nil;
        if (![WitchRuntimeService.shared deleteItem:item error:&err]) {
            showDialog(localize(@"Error", nil), err.localizedDescription ?: @"Delete failed.");
            return;
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf reloadContent];
    }];
}

- (void)showInstallerActions:(StorageRow *)row {
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:row.title
                           message:row.subtitle
                           options:@[
        @{@"title": localize(@"storage.action.install_share", nil), @"icon": @"square.and.arrow.up"},
        @{@"title": localize(@"Delete", nil), @"icon": @"trash", @"destructive": @YES},
        @{@"title": localize(@"Done", nil), @"icon": @"checkmark"},
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0) [weakSelf installInstallerFile:row];
        else if (idx == 1) [weakSelf confirmDeleteInstaller:row];
    }];
}

- (void)installInstallerFile:(StorageRow *)row {
    NSURL *url = [NSURL fileURLWithPath:row.path];
    // Try the TrollStore deep-link install first; share sheet is the fallback
    // inside the service.
    [WitchUpdateService.shared installFileAtURL:url fromViewController:self];
}

- (void)confirmDeleteInstaller:(StorageRow *)row {
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:localize(@"storage.delete_update_title", nil)
                           message:row.title
                      confirmTitle:localize(@"Delete", nil)
                       destructive:YES
                          onConfirm:^{
        NSError *err = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:row.path error:&err]) {
            [ErrorPresenter showFileError:@"Delete" path:row.title error:err];
            return;
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf reloadContent];
    }];
}

@end
