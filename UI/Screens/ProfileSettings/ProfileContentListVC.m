#import "ProfileContentListVC.h"
#import "ProfileItemCell.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "ModMetadataReader.h"
#import "ModUpdateChecker.h"
#import "ModSourceService.h"
#import "DownloadManager.h"
#import "DependencyResolver.h"
#import "FileBrowserViewController.h"
#import "LauncherPreferences.h"
#import "AppSheet.h"
#import "utils.h"

typedef NS_ENUM(NSInteger, ProfileListFilter) {
    ProfileListFilterAll = 0,
    ProfileListFilterOn,
    ProfileListFilterOff,
    ProfileListFilterOutdated,
};

@interface ProfileContentListVC () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UISegmentedControl *filterControl;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UIToolbar *bottomBar;
@property (nonatomic) ProfileListFilter filter;
@property (nonatomic, copy) NSString *query;
@property (nonatomic) NSArray<NSDictionary *> *manifestItems;
@property (nonatomic) NSArray<NSDictionary *> *orphanItems;
@property (nonatomic) NSArray<NSDictionary *> *visibleItems;
@property (nonatomic) NSArray<NSDictionary *> *checkResults;
@property (nonatomic) BOOL checking;
@end

@implementation ProfileContentListVC

- (instancetype)initWithProfile:(NSMutableDictionary *)profile category:(NSString *)category {
    self = [super init];
    if (self) {
        _profile = profile ?: [NSMutableDictionary dictionary];
        _category = [category copy];
        NSString *title = localize(@"profiles.tab_mods", nil);
        NSString *icon = @"puzzlepiece.extension";
        if ([category isEqualToString:InstalledItemCategoryShaderPack]) { title = localize(@"profiles.tab_shader", nil); icon = @"paintbrush.pointed"; }
        else if ([category isEqualToString:InstalledItemCategoryResourcePack]) { title = localize(@"profiles.tab_resourcepack", nil); icon = @"paintpalette"; }
        self.title = title;
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                       image:[UIImage systemImageNamed:icon]
                                               selectedImage:[UIImage systemImageNamed:[icon stringByAppendingString:@".fill"]]];
    }
    return self;
}

- (NSString *)profileMcVersion {
    NSString *v = self.profile[@"lastVersionId"];
    if ([v isKindOfClass:[NSString class]] && v.length > 0) return [VersionProfile cleanMinecraftVersion:v] ?: v;
    VersionProfile *p = VersionDirectoryManager.shared.currentProfile;
    return p.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
}

- (NSString *)profileLoader {
    NSString *loader = self.profile[@"modLoader"];
    if ([loader isKindOfClass:[NSString class]] && loader.length > 0) return loader.lowercaseString;
    VersionProfile *p = VersionDirectoryManager.shared.currentProfile;
    if ([p.modLoader isKindOfClass:[NSString class]] && p.modLoader.length > 0) return p.modLoader.lowercaseString;
    NSString *pref = getPrefObject(@"internal.mod_loader");
    if ([pref isKindOfClass:[NSString class]] && pref.length > 0) return pref.lowercaseString;
    return @"fabric";
}

- (NSString *)contentDir {
    NSString *dir = [[InstalledModsManager shared] dirForCategory:self.category profile:self.profile];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    // One-time: legacy "<name>.off" -> "off/<name>".
    [[InstalledModsManager shared] migrateLegacyOffFilesForCategory:self.category profile:self.profile];
    return dir;
}

// Fill display fields straight from the file when the manifest lacks them.
- (NSMutableDictionary *)enrichedItem:(NSDictionary *)entry filePath:(NSString *)full {
    NSMutableDictionary *e = [entry mutableCopy] ?: [NSMutableDictionary dictionary];
    e[@"_profile"] = self.profile;
    BOOL needParse = NO;
    for (NSString *k in @[@"title", @"version_number", @"author", @"description"]) {
        id v = e[k];
        if (![v isKindOfClass:[NSString class]] || [(NSString *)v length] == 0) { needParse = YES; break; }
    }
    if (needParse && full.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:full]) {
        NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:full category:self.category];
        for (NSString *k in @[@"title", @"version", @"authors", @"description"]) {
            NSString *dst = [k isEqualToString:@"version"] ? @"version_number" : ([k isEqualToString:@"authors"] ? @"author" : k);
            id cur = e[dst];
            id got = meta[k];
            if ((!([cur isKindOfClass:[NSString class]]) || [(NSString *)cur length] == 0) &&
                [got isKindOfClass:[NSString class]] && [(NSString *)got length] > 0) {
                e[dst] = got;
            }
        }
        if ((![e[@"version_number"] isKindOfClass:[NSString class]] || [(NSString *)e[@"version_number"] length] == 0) &&
            [meta[@"pack_format"] isKindOfClass:[NSString class]]) {
            e[@"version_number"] = [ModMetadataReader displayVersionForPackFormat:meta[@"pack_format"]];
        }
    }
    if (![e[@"mc_version"] isKindOfClass:[NSString class]] || [(NSString *)e[@"mc_version"] length] == 0) {
        e[@"mc_version"] = [self profileMcVersion];
    }
    if ([self.category isEqualToString:InstalledItemCategoryMod] &&
        (![e[@"loader"] isKindOfClass:[NSString class]] || [(NSString *)e[@"loader"] length] == 0)) {
        e[@"loader"] = [self profileLoader];
    }
    return e;
}

#pragma mark - View

- (void)viewDidLoad {
    [super viewDidLoad];
    [AmethystBlurView installInView:self.view];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 84;
    // Keep the last rows clear of the bottom toolbar/home indicator.
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 12, 0);
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    [_tableView registerClass:[ProfileItemCell class] forCellReuseIdentifier:@"ProfileItemCell"];
    [self.view addSubview:_tableView];

    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    [rc addTarget:self action:@selector(forceRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = rc;

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Search name or file";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _tableView.tableHeaderView = [self headerView];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.font = [UIFont systemFontOfSize:14];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _bottomBar = [[UIToolbar alloc] init];
    _bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomBar.layer.cornerRadius = 18;
    _bottomBar.clipsToBounds = YES;
    _bottomBar.layer.borderWidth = 1;
    _bottomBar.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.25].CGColor;
    [self.view addSubview:_bottomBar];
    [self rebuildBottomBar];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
        [_bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_bottomBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-4],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onExternalChange) name:InstalledModsDidChangeNotification object:nil];
    [self onTheme];
}

- (UIView *)headerView {
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 96)];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.frame = CGRectMake(0, 0, 320, 44);
    [wrap addSubview:_searchBar];
    _filterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"On", @"Off", @"Outdated"]];
    _filterControl.selectedSegmentIndex = 0;
    _filterControl.layer.cornerRadius = 10;
    _filterControl.clipsToBounds = YES;
    [ThemeManager.shared styleSegmentedControl:_filterControl];
    _filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [wrap addSubview:_filterControl];
    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [_searchBar.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:8],
        [_searchBar.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-8],
        [_searchBar.heightAnchor constraintEqualToConstant:44],
        [_filterControl.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_filterControl.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:12],
        [_filterControl.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-12],
        [_filterControl.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-8],
    ]];
    return wrap;
}

- (void)rebuildBottomBar {
    UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:@"Import" style:UIBarButtonItemStylePlain target:self action:@selector(importTapped)];
    importItem.image = [UIImage systemImageNamed:@"tray.and.arrow.down"];
    UIBarButtonItem *browseItem = [[UIBarButtonItem alloc] initWithTitle:@"Files" style:UIBarButtonItemStylePlain target:self action:@selector(browseTapped)];
    browseItem.image = [UIImage systemImageNamed:@"folder"];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *updateAll = [[UIBarButtonItem alloc] initWithTitle:@"Update all" style:UIBarButtonItemStylePlain target:self action:@selector(updateAllTapped)];
    updateAll.image = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"];
    _bottomBar.items = @[importItem, flex, browseItem, flex, updateAll];
}

- (void)onTheme {
    self.view.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [ThemeManager.shared styleSegmentedControl:_filterControl];
    [_tableView reloadData];
}

- (void)onExternalChange { [self reloadContent]; }

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContent];
}

- (void)filterChanged {
    _filter = (ProfileListFilter)_filterControl.selectedSegmentIndex;
    [self applyFilter];
}

- (void)forceRefresh {
    [self checkForUpdatesForce:YES];
}

#pragma mark - Data

- (void)reloadContent {
    NSString *dir = [self contentDir];
    NSString *offDir = [[InstalledModsManager shared] offDirForCategory:self.category profile:self.profile];
    NSArray *manifest = [[InstalledModsManager shared] allInstalledForCategory:self.category profile:self.profile];
    NSMutableArray *enriched = [NSMutableArray arrayWithCapacity:manifest.count];
    for (NSDictionary *m in manifest) {
        NSString *fn = m[@"filename"];
        NSString *base = ([fn isKindOfClass:[NSString class]] && fn.length > 0)
            ? [[InstalledModsManager shared] baseNameForFilename:fn] : @"";
        NSString *full = base.length > 0 ? [dir stringByAppendingPathComponent:base] : @"";
        if (base.length > 0 && ![[NSFileManager defaultManager] fileExistsAtPath:full]) {
            NSString *off = [offDir stringByAppendingPathComponent:base];
            if ([[NSFileManager defaultManager] fileExistsAtPath:off]) full = off;
        }
        NSMutableDictionary *e = [self enrichedItem:m filePath:full];
        // Manifest always stores the base name; the file may live in off/.
        if (base.length > 0) e[@"filename"] = base;
        [enriched addObject:e];
    }
    _manifestItems = enriched;

    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSArray *offFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:offDir error:nil] ?: @[];
    NSSet *known = [NSSet setWithArray:[_manifestItems valueForKey:@"filename"]];
    BOOL isMod = [self.category isEqualToString:InstalledItemCategoryMod];
    NSMutableArray *orphans = [NSMutableArray array];
    // Live files...
    for (NSString *f in files) {
        if ([f isEqualToString:@"off"] || [f hasSuffix:@".json"] || [f hasSuffix:@".off"]) continue;
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:f] isDirectory:&isDir] || isDir) continue;
        BOOL match = isMod ? [f hasSuffix:@".jar"] : [f hasSuffix:@".zip"];
        if (!match || [known containsObject:f]) continue;
        [orphans addObject:[self orphanItemForFilename:f inDir:dir]];
    }
    // ...plus disabled files in off/ (they stay listed, switch OFF).
    for (NSString *f in offFiles) {
        if ([f hasPrefix:@"."]) continue;
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:[offDir stringByAppendingPathComponent:f] isDirectory:&isDir] || isDir) continue;
        BOOL match = isMod ? [f hasSuffix:@".jar"] : [f hasSuffix:@".zip"];
        if (!match || [known containsObject:f]) continue;
        NSMutableDictionary *o = [self orphanItemForFilename:f inDir:offDir];
        o[@"_wasOff"] = @YES;
        [orphans addObject:o];
    }
    _orphanItems = orphans;
    _checkResults = nil;
    [self applyFilter];
    [self checkForUpdatesForce:NO];
}

- (NSMutableDictionary *)orphanItemForFilename:(NSString *)f inDir:(NSString *)dir {
    NSString *full = [dir stringByAppendingPathComponent:f];
    NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:full category:self.category];
    NSString *title = meta[@"title"];
    if (![title isKindOfClass:[NSString class]] || title.length == 0) {
        title = [[f stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    }
    NSString *ver = meta[@"version"];
    if (![ver isKindOfClass:[NSString class]]) {
        NSString *pf = meta[@"pack_format"];
        ver = [pf isKindOfClass:[NSString class]] ? [ModMetadataReader displayVersionForPackFormat:pf] : @"";
    }
    BOOL isMod = [self.category isEqualToString:InstalledItemCategoryMod];
    return [@{
        @"title": title,
        @"filename": f,
        @"version_number": ver ?: @"",
        @"author": ([meta[@"authors"] isKindOfClass:[NSString class]] ? meta[@"authors"] : @""),
        @"description": ([meta[@"description"] isKindOfClass:[NSString class]] ? meta[@"description"] : @""),
        @"icon_url": @"",
        @"source": @"local",
        @"category": self.category,
        @"mc_version": [self profileMcVersion] ?: @"",
        @"loader": (isMod ? [self profileLoader] : @""),
        @"isOrphan": @YES,
        @"_profile": self.profile,
    } mutableCopy];
}

- (void)applyFilter {
    NSMutableArray *all = [NSMutableArray array];
    if (_manifestItems) [all addObjectsFromArray:_manifestItems];
    if (_orphanItems) [all addObjectsFromArray:_orphanItems];
    NSString *q = [_query isKindOfClass:[NSString class]] ? _query.lowercaseString : @"";
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *item in all) {
        if (q.length > 0) {
            NSString *hay = [NSString stringWithFormat:@"%@ %@ %@",
                             item[@"title"] ?: @"", item[@"filename"] ?: @"", item[@"author"] ?: @""].lowercaseString;
            if ([hay rangeOfString:q].location == NSNotFound) continue;
        }
        NSString *fn = item[@"filename"];
        BOOL enabled = YES;
        if ([fn isKindOfClass:[NSString class]]) {
            enabled = [[InstalledModsManager shared] isEnabledForFilename:fn category:self.category profile:self.profile];
        }
        if (_filter == ProfileListFilterOn && !enabled) continue;
        if (_filter == ProfileListFilterOff && enabled) continue;
        if (_filter == ProfileListFilterOutdated) {
            NSUInteger idx = [_manifestItems indexOfObject:item];
            if (idx == NSNotFound || !_checkResults || idx >= _checkResults.count) continue;
            if (![_checkResults[idx][@"status"] isEqualToString:@"update"]) continue;
        }
        [out addObject:item];
    }
    _visibleItems = out;
    _emptyLabel.hidden = (out.count > 0);
    if (out.count == 0) {
        NSString *kind = [self.category isEqualToString:InstalledItemCategoryMod] ? @"mods"
            : [self.category isEqualToString:InstalledItemCategoryShaderPack] ? @"shaders" : @"resource packs";
        _emptyLabel.text = [NSString stringWithFormat:@"No %@ here yet.\nUse Import to add files.", kind];
    }
    [_tableView reloadData];
}

- (void)checkForUpdatesForce:(BOOL)force {
    if (_manifestItems.count == 0) {
        _checkResults = @[];
        [_tableView.refreshControl endRefreshing];
        [self applyFilter];
        return;
    }
    if (_checking && !force) return;
    _checking = YES;
    NSMutableArray *checking = [NSMutableArray arrayWithCapacity:_manifestItems.count];
    for (NSUInteger i = 0; i < _manifestItems.count; i++) [checking addObject:@{@"status": @"checking"}];
    _checkResults = checking;
    [_tableView reloadData];
    __weak typeof(self) weakSelf = self;
    [[ModUpdateChecker shared] checkItems:_manifestItems mcVersion:[self profileMcVersion] loader:[self profileLoader] forceRefresh:force completion:^(NSArray *results) {
        weakSelf.checking = NO;
        [weakSelf.tableView.refreshControl endRefreshing];
        weakSelf.checkResults = results ?: @[];
        [weakSelf applyFilter];
    }];
}

- (NSDictionary *)checkStatusForItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue]) return @{@"status": @"local"};
    NSUInteger idx = [_manifestItems indexOfObject:item];
    if (idx != NSNotFound && _checkResults && idx < _checkResults.count) return _checkResults[idx];
    return @{@"status": @"none"};
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _visibleItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProfileItemCell" forIndexPath:indexPath];
    NSDictionary *item = _visibleItems[indexPath.row];
    [cell configureWithItem:item status:[self checkStatusForItem:item] category:self.category];
    cell.iconView.image = [UIImage systemImageNamed:[ModMetadataReader placeholderSystemImageForCategory:self.category]];
    cell.iconView.tintColor = ThemeManager.shared.secondaryTextColor;

    NSString *fn = item[@"filename"];
    NSString *requested = ([fn isKindOfClass:[NSString class]] ? fn : @"");
    if (requested.length > 0) {
        // Resolve the real file: live dir first, then off/, then legacy .off.
        NSString *full = [self diskPathForItem:item];
        if (!full) full = [[self contentDir] stringByAppendingPathComponent:requested];
        __weak ProfileItemCell *weakCell = cell;
        __weak typeof(self) weakSelf = self;
        [[ModMetadataReader shared] iconForFileAtPath:full category:weakSelf.category completion:^(UIImage *image, NSDictionary *meta) {
            if (![weakCell.requestToken isEqualToString:requested]) return; // reused cell
            if (image) {
                weakCell.iconView.image = image;
                weakCell.iconView.tintColor = [UIColor clearColor];
                return;
            }
            NSString *remote = item[@"icon_url"];
            if ([remote isKindOfClass:[NSString class]] && remote.length > 0) {
                [[ModMetadataReader shared] remoteIconForURLString:remote completion:^(UIImage *rimg) {
                    if (![weakCell.requestToken isEqualToString:requested]) return;
                    if (rimg) {
                        weakCell.iconView.image = rimg;
                        weakCell.iconView.tintColor = [UIColor clearColor];
                    }
                }];
            }
        }];
    }
    __weak typeof(self) weakSelf = self;
    cell.onToggle = ^(NSDictionary *it, BOOL enabled) {
        [weakSelf setEnabled:enabled forItem:it];
    };
    cell.onAction = ^(NSDictionary *it) {
        [weakSelf primaryActionForItem:it status:[weakSelf checkStatusForItem:it]];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self detailForItem:_visibleItems[indexPath.row]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)_visibleItems.count) return nil;
    NSDictionary *item = _visibleItems[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:localize(@"Share", nil) handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf shareItem:item]; done(YES);
    }];
    share.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:localize(@"Rename", nil) handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf renameItem:item]; done(YES);
    }];
    rename.image = [UIImage systemImageNamed:@"pencil"];
    rename.backgroundColor = ThemeManager.shared.warningColor;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:localize(@"Delete", nil) handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf deleteItem:item]; done(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash"];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[del, rename, share]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _query = searchText;
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Toggle

- (void)setEnabled:(BOOL)enabled forItem:(NSDictionary *)item {
    [HapticManager.shared play:HapticTypeLight];
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Missing file name."];
        return;
    }
    NSString *base = [[InstalledModsManager shared] baseNameForFilename:fn];
    BOOL ok = [[InstalledModsManager shared] setEnabled:enabled forFilename:base category:self.category profile:self.profile];
    if (!ok) {
        [ErrorPresenter showFileError:enabled ? @"Enable" : @"Disable" path:base error:nil];
    }
    // setEnabled posts InstalledModsDidChangeNotification -> onExternalChange reloads.
}

#pragma mark - Import / share / rename / delete / browse

- (void)importTapped {
    [HapticManager.shared play:HapticTypeLight];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    BOOL isMod = [self.category isEqualToString:InstalledItemCategoryMod];
    NSString *dir = [self contentDir];
    NSUInteger imported = 0;
    for (NSURL *url in urls) {
        BOOL accessing = [url startAccessingSecurityScopedResource];
        NSString *name = url.lastPathComponent;
        BOOL valid = isMod ? [name hasSuffix:@".jar"] : [name hasSuffix:@".zip"];
        if (valid) {
            NSString *dest = [dir stringByAppendingPathComponent:name];
            [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
            NSError *err = nil;
            if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&err]) {
                imported++;
            } else {
                [ErrorPresenter showFileError:@"Import" path:name error:err];
            }
        }
        if (accessing) [url stopAccessingSecurityScopedResource];
    }
    if (imported == 0) {
        [ErrorPresenter showValidation:@"file" message:isMod ? @"Pick .jar mod files." : @"Pick .zip files."];
        return;
    }
    [HapticManager.shared play:HapticTypeSuccess];
    [self reloadContent];
}

- (NSString *)diskPathForItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) return nil;
    NSString *base = [[InstalledModsManager shared] baseNameForFilename:fn];
    NSString *dir = [self contentDir];
    NSString *path = [dir stringByAppendingPathComponent:base];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    NSString *offDir = [[InstalledModsManager shared] offDirForCategory:self.category profile:self.profile];
    NSString *off = [offDir stringByAppendingPathComponent:base];
    if ([[NSFileManager defaultManager] fileExistsAtPath:off]) return off;
    // Legacy "<name>.off" next to the dir.
    NSString *legacy = [dir stringByAppendingPathComponent:[base stringByAppendingString:@".off"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:legacy]) return legacy;
    return nil;
}

- (void)shareItem:(NSDictionary *)item {
    NSString *path = [self diskPathForItem:item];
    if (!path) {
        [ErrorPresenter showFileError:@"Share" path:item[@"filename"] error:nil];
        return;
    }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:av animated:YES completion:nil];
}

- (void)renameItem:(NSDictionary *)item {
    NSString *path = [self diskPathForItem:item];
    if (!path) {
        [ErrorPresenter showFileError:@"Rename" path:item[@"filename"] error:nil];
        return;
    }
    NSString *fn = path.lastPathComponent;
    NSString *base = [[InstalledModsManager shared] baseNameForFilename:fn];
    NSString *ext = base.pathExtension.length > 0 ? [@"." stringByAppendingString:base.pathExtension] : @"";
    NSString *stem = [base stringByDeletingPathExtension];
    __weak typeof(self) weakSelf = self;
    [AppSheet showPromptWithTitle:@"Rename file" message:fn placeholder:@"File name" initialText:stem onConfirm:^(NSString *newStem) {
        if (![newStem isKindOfClass:[NSString class]] || newStem.length == 0) {
            [ErrorPresenter showValidation:@"name" message:@"Enter a file name."];
            return;
        }
        NSString *newBase = [newStem stringByAppendingString:ext];
        // Rename inside the same folder (live dir or off/); name never changes form.
        NSString *dst = [path.stringByDeletingLastPathComponent stringByAppendingPathComponent:newBase];
        if ([[NSFileManager defaultManager] fileExistsAtPath:dst]) {
            [ErrorPresenter showError:@"Name exists" message:@"A file with that name already exists."];
            return;
        }
        NSError *err = nil;
        if (![[NSFileManager defaultManager] moveItemAtPath:path toPath:dst error:&err]) {
            [ErrorPresenter showFileError:@"Rename" path:fn error:err];
            return;
        }
        NSString *pid = item[@"project_id"];
        if ([pid isKindOfClass:[NSString class]] && pid.length > 0 && ![item[@"isOrphan"] boolValue]) {
            [[InstalledModsManager shared] updateFilename:newBase forProjectId:pid category:weakSelf.category profile:weakSelf.profile];
        }
        [weakSelf reloadContent];
    }];
}

- (void)deleteItem:(NSDictionary *)item {
    NSString *path = [self diskPathForItem:item];
    if (!path) {
        [ErrorPresenter showFileError:@"Delete" path:item[@"filename"] error:nil];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:@"Delete file?" message:path.lastPathComponent confirmTitle:@"Delete" destructive:YES onConfirm:^{
        NSError *err = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&err]) {
            [ErrorPresenter showFileError:@"Delete" path:path.lastPathComponent error:err];
            return;
        }
        NSString *pid = item[@"project_id"];
        if ([pid isKindOfClass:[NSString class]] && pid.length > 0) {
            [[InstalledModsManager shared] removeProjectId:pid category:weakSelf.category profile:weakSelf.profile];
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf reloadContent];
    }];
}

- (void)browseTapped {
    FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
    vc.rootPath = [self contentDir];
    vc.title = [self contentDir].lastPathComponent;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)detailForItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"] ?: @"";
    NSString *desc = item[@"description"];
    if (![desc isKindOfClass:[NSString class]] || desc.length == 0) {
        NSString *path = [self diskPathForItem:item];
        if (path) {
            NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:path category:self.category];
            if ([meta[@"description"] isKindOfClass:[NSString class]]) desc = meta[@"description"];
        }
        if (![desc isKindOfClass:[NSString class]]) desc = @"";
    }
    NSDictionary *status = [self checkStatusForItem:item];
    NSString *state = status[@"status"] ?: @"";
    NSString *latest = status[@"latest_version"] ?: @"";
    NSString *msg = [NSString stringWithFormat:@"File: %@\nVersion: %@\nAuthor: %@\nMC: %@\nLoader: %@\nSource: %@\nState: %@%@\n\n%@",
                     fn, item[@"version_number"] ?: @"?",
                     item[@"author"] ?: @"?", item[@"mc_version"] ?: @"?",
                     item[@"loader"] ?: @"?", item[@"source"] ?: @"local",
                     state, (latest.length > 0 ? [NSString stringWithFormat:@" (latest %@)", latest] : @""),
                     (desc.length > 0 ? desc : @"No description available.")];
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:item[@"title"] ?: fn message:msg options:@[
        @{@"title": @"Share file", @"icon": @"square.and.arrow.up"},
        @{@"title": localize(@"Done", nil), @"icon": @"checkmark"},
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0) [weakSelf shareItem:item];
    }];
}

#pragma mark - Update / reinstall

- (void)primaryActionForItem:(NSDictionary *)item status:(NSDictionary *)status {
    NSString *st = status[@"status"];
    if ([st isEqualToString:@"update"]) [self updateItem:item];
    else if ([st isEqualToString:@"latest"]) [self reinstallItem:item];
    else [self detailForItem:item];
}

- (void)updateItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue] || ![item[@"project_id"] isKindOfClass:[NSString class]]) {
        [ErrorPresenter showInfo:@"Manual file" message:@"This file was added manually. Re-import it to track updates."];
        return;
    }
    [HapticManager.shared play:HapticTypeMedium];
    [self installWithDependenciesForItem:item isUpdate:YES done:nil];
}

- (void)reinstallItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue] || ![item[@"project_id"] isKindOfClass:[NSString class]]) {
        [ErrorPresenter showInfo:@"Manual file" message:@"This file was added manually."];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:@"Reinstall?" message:item[@"title"] confirmTitle:@"Reinstall" destructive:NO onConfirm:^{
        [weakSelf installWithDependenciesForItem:item isUpdate:NO done:nil];
    }];
}

- (void)updateAllTapped {
    if (_manifestItems.count == 0) {
        [ErrorPresenter showInfo:@"Nothing to update" message:@"No managed files in this tab."];
        return;
    }
    NSMutableArray *pending = [NSMutableArray array];
    for (NSUInteger i = 0; i < _manifestItems.count; i++) {
        if (i < _checkResults.count && [_checkResults[i][@"status"] isEqualToString:@"update"]) {
            NSMutableDictionary *m = [_manifestItems[i] mutableCopy];
            m[@"latest_url"] = _checkResults[i][@"latest_url"] ?: @"";
            m[@"latest_filename"] = _checkResults[i][@"latest_filename"] ?: m[@"filename"];
            m[@"latest_version"] = _checkResults[i][@"latest_version"] ?: @"";
            [pending addObject:m];
        }
    }
    if (pending.count == 0) {
        [ErrorPresenter showSuccess:@"Up to date" message:@"Everything is already on the latest version."];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:@"Update all?" message:[NSString stringWithFormat:@"%lu files", (unsigned long)pending.count] confirmTitle:@"Update" destructive:NO onConfirm:^{
        [weakSelf updateQueue:[pending copy]];
    }];
}

- (void)updateQueue:(NSArray *)queue {
    if (queue.count == 0) {
        [self reloadContent];
        return;
    }
    NSMutableArray *rest = [queue mutableCopy];
    NSDictionary *first = rest[0];
    [rest removeObjectAtIndex:0];
    __weak typeof(self) weakSelf = self;
    [self installWithDependenciesForItem:first isUpdate:YES done:^{
        [weakSelf updateQueue:[rest copy]];
    }];
}

- (void)installWithDependenciesForItem:(NSDictionary *)item isUpdate:(BOOL)isUpdate done:(void(^)(void))done {
    NSString *projectId = item[@"project_id"];
    if (![projectId isKindOfClass:[NSString class]] || projectId.length == 0) {
        if (done) done();
        return;
    }
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Resolving dependencies" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [loading.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:loading.view.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:loading.view.topAnchor constant:56],
        [spinner.widthAnchor constraintEqualToConstant:40],
        [spinner.heightAnchor constraintEqualToConstant:40],
        [loading.view.heightAnchor constraintGreaterThanOrEqualToConstant:110],
    ]];
    [self presentViewController:loading animated:YES completion:nil];
    __weak typeof(self) weakSelf = self;
    NSString *source = [item[@"source"] isKindOfClass:[NSString class]] && [(NSString *)item[@"source"] length] > 0 ? item[@"source"] : @"modrinth";
    [[DependencyResolver shared] resolveDependenciesForProjectId:projectId source:source targetVersion:[self profileMcVersion] targetLoader:[self profileLoader] completion:^(NSArray *deps, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    [ErrorPresenter showError:@"Error" message:[NSString stringWithFormat:@"Could not resolve dependencies: %@", error.localizedDescription]];
                    if (done) done();
                    return;
                }
                [weakSelf continueInstall:item deps:deps isUpdate:isUpdate done:done];
            }];
        });
    }];
}

- (void)continueInstall:(NSDictionary *)item deps:(NSArray *)deps isUpdate:(BOOL)isUpdate done:(void(^)(void))done {
    NSMutableArray *jobs = [NSMutableArray array];
    NSDictionary *status = [self checkStatusForItem:item];
    NSString *filename = isUpdate ? (status[@"latest_filename"] ?: item[@"filename"]) : item[@"filename"];
    NSString *versionNumber = isUpdate ? (status[@"latest_version"] ?: item[@"version_number"]) : item[@"version_number"];
    NSDictionary *versionDict = nil;
    if (isUpdate && [status[@"latest_version_dict"] isKindOfClass:[NSDictionary class]]) {
        versionDict = status[@"latest_version_dict"];
    } else {
        versionDict = @{@"url": item[@"url"] ?: @"", @"filename": filename ?: @""};
    }
    NSString *itemSource = ([item[@"source"] isKindOfClass:[NSString class]] && [(NSString *)item[@"source"] length] > 0) ? item[@"source"] : @"modrinth";
    NSMutableDictionary *mainMod = [@{@"project_id": item[@"project_id"] ?: @""} mutableCopy];
    if ([itemSource isEqualToString:@"curseforge"]) mainMod[@"_source"] = @"curseforge";
    [jobs addObject:@{
        @"versionDict": versionDict ?: @{},
        @"modRef": [mainMod copy],
        @"filename": filename ?: @"file.jar",
        @"versionNumber": versionNumber ?: @"",
        @"title": item[@"title"] ?: @"",
        @"projectId": item[@"project_id"] ?: @"",
        @"iconURL": ([item[@"icon_url"] isKindOfClass:[NSString class]] ? item[@"icon_url"] : @""),
        @"source": itemSource,
        @"recordCategory": self.category ?: InstalledItemCategoryMod,
        @"projectType": ([item[@"project_type"] isKindOfClass:[NSString class]] ? item[@"project_type"] : @"mod"),
    }];
    for (NSDictionary *dep in deps) {
        if (![dep isKindOfClass:[NSDictionary class]]) continue;
        NSString *depPid = dep[@"project_id"];
        if (![depPid isKindOfClass:[NSString class]] || depPid.length == 0) continue;
        if ([[DependencyResolver shared] isProjectInstalled:depPid category:InstalledItemCategoryMod]) continue;
        NSString *depSource = ([dep[@"source"] isKindOfClass:[NSString class]] && [(NSString *)dep[@"source"] length] > 0) ? dep[@"source"] : @"modrinth";
        NSMutableDictionary *depMod = [@{@"project_id": depPid} mutableCopy];
        if ([depSource isEqualToString:@"curseforge"]) depMod[@"_source"] = @"curseforge";
        NSMutableDictionary *depVer = [NSMutableDictionary dictionary];
        if ([dep[@"url"] isKindOfClass:[NSString class]]) depVer[@"url"] = dep[@"url"];
        if ([dep[@"filename"] isKindOfClass:[NSString class]]) depVer[@"filename"] = dep[@"filename"];
        if (dep[@"_cfFileId"]) depVer[@"_cfFileId"] = dep[@"_cfFileId"];
        NSString *depFile = ([dep[@"filename"] isKindOfClass:[NSString class]] && [(NSString *)dep[@"filename"] length] > 0) ? dep[@"filename"] : [NSString stringWithFormat:@"%@.jar", depPid];
        [jobs addObject:@{
            @"versionDict": [depVer copy],
            @"modRef": [depMod copy],
            @"filename": depFile,
            @"versionNumber": ([dep[@"version"] isKindOfClass:[NSString class]] ? dep[@"version"] : @""),
            @"title": ([dep[@"title"] isKindOfClass:[NSString class]] ? dep[@"title"] : depPid),
            @"projectId": depPid,
            @"iconURL": ([dep[@"icon_url"] isKindOfClass:[NSString class]] ? dep[@"icon_url"] : @""),
            @"source": depSource,
            @"recordCategory": InstalledItemCategoryMod,
            @"projectType": @"mod",
        }];
    }
    [self downloadJobQueue:[jobs copy] index:0 done:done];
}

- (void)downloadJobQueue:(NSArray *)jobs index:(NSUInteger)index done:(void(^)(void))done {
    if (index >= jobs.count) {
        [HapticManager.shared play:HapticTypeSuccess];
        [self reloadContent];
        if (done) done();
        return;
    }
    NSDictionary *job = jobs[index];
    __weak typeof(self) weakSelf = self;
    [self downloadSingleJob:job completion:^(BOOL ok) {
        if (!ok && index == 0) {
            if (done) done();
            return;
        }
        [weakSelf downloadJobQueue:jobs index:index + 1 done:done];
    }];
}

- (void)downloadSingleJob:(NSDictionary *)job completion:(void(^)(BOOL ok))completion {
    NSString *recordCategory = job[@"recordCategory"] ?: self.category;
    NSString *filename = job[@"filename"];
    NSString *dir = [[InstalledModsManager shared] dirForCategory:recordCategory profile:self.profile];
    NSString *targetPath = [dir stringByAppendingPathComponent:filename];
    DownloadType dtype = DownloadTypeMod;
    if ([recordCategory isEqualToString:InstalledItemCategoryShaderPack]) dtype = DownloadTypeShader;
    else if ([recordCategory isEqualToString:InstalledItemCategoryResourcePack]) dtype = DownloadTypeResourcePack;
    DownloadTask *hubTask = [[DownloadManager shared] beginTaskWithName:job[@"title"] ?: filename type:dtype];
    [hubTask setCancelBlock:^{}];
    __weak typeof(self) weakSelf = self;
    [ModSourceService downloadVersion:job[@"versionDict"] ofMod:job[@"modRef"] progress:^(float p) {
        [[DownloadManager shared] updateProgress:p forTask:hubTask];
    } completion:^(NSString *dlPath, NSError *dlError) {
        [[DownloadManager shared] completeTask:hubTask error:dlError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!dlPath || dlError) {
                [ErrorPresenter showNetworkError:dlError message:@"Download failed."];
                if (completion) completion(NO);
                return;
            }
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            NSError *moveErr = nil;
            [[NSFileManager defaultManager] moveItemAtPath:dlPath toPath:targetPath error:&moveErr];
            if (moveErr) {
                [ErrorPresenter showFileError:@"Install" path:filename error:moveErr];
                if (completion) completion(NO);
                return;
            }
            [[InstalledModsManager shared] recordProjectId:job[@"projectId"]
                                                     title:job[@"title"]
                                             versionNumber:job[@"versionNumber"]
                                                  filename:filename
                                                   iconURL:job[@"iconURL"]
                                                    source:job[@"source"]
                                                  category:recordCategory
                                                 mcVersion:[weakSelf profileMcVersion]
                                                    loader:[weakSelf profileLoader]
                                               projectType:job[@"projectType"]
                                                   profile:weakSelf.profile];
            if (completion) completion(YES);
        });
    }];
}

@end
