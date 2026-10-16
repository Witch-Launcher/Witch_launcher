#import "ProfileWorldsVC.h"
#import "ProfileItemCell.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "InstalledModsManager.h"
#import "ModMetadataReader.h"
#import "FileBrowserViewController.h"
#import "utils.h"

@interface ProfileWorldsVC () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UIToolbar *bottomBar;
@property (nonatomic) NSArray<NSDictionary *> *worlds;
@end

@implementation ProfileWorldsVC

- (instancetype)initWithProfile:(NSMutableDictionary *)profile {
    self = [super init];
    if (self) {
        _profile = profile ?: [NSMutableDictionary dictionary];
        self.title = localize(@"profiles.tab_worlds", nil);
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:localize(@"profiles.tab_worlds", nil)
                                                       image:[UIImage systemImageNamed:@"globe"]
                                               selectedImage:[UIImage systemImageNamed:@"globe.fill"]];
    }
    return self;
}

- (NSString *)savesDir {
    NSString *dir = [[InstalledModsManager shared] savesDirForProfile:self.profile];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

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
    [_tableView registerClass:[ProfileItemCell class] forCellReuseIdentifier:@"ProfileItemCell"];
    [self.view addSubview:_tableView];

    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    [rc addTarget:self action:@selector(reloadContent) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = rc;

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.font = [UIFont systemFontOfSize:14];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.text = @"No worlds yet.\nUse Import to add a world .zip.";
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _bottomBar = [[UIToolbar alloc] init];
    _bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomBar.layer.cornerRadius = 18;
    _bottomBar.clipsToBounds = YES;
    _bottomBar.layer.borderWidth = 1;
    _bottomBar.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.25].CGColor;
    [self.view addSubview:_bottomBar];
    UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:@"Import" style:UIBarButtonItemStylePlain target:self action:@selector(importTapped)];
    importItem.image = [UIImage systemImageNamed:@"tray.and.arrow.down"];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *browseItem = [[UIBarButtonItem alloc] initWithTitle:@"Files" style:UIBarButtonItemStylePlain target:self action:@selector(browseTapped)];
    browseItem.image = [UIImage systemImageNamed:@"folder"];
    _bottomBar.items = @[importItem, flex, browseItem];

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
}

- (void)onTheme {
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [_tableView reloadData];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContent];
}

- (void)reloadContent {
    NSString *dir = [self savesDir];
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *e in entries) {
        if ([e hasPrefix:@"."]) continue;
        NSString *full = [dir stringByAppendingPathComponent:e];
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir];
        if (isDir) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:[full stringByAppendingPathComponent:@"level.dat"]]) continue;
            NSMutableDictionary *info = [[ModMetadataReader worldInfoForWorldDir:full] mutableCopy];
            info[@"path"] = full;
            info[@"isZip"] = @NO;
            [out addObject:info];
        } else if ([e hasSuffix:@".zip"]) {
            NSMutableDictionary *info = [[ModMetadataReader worldInfoForWorldZip:full] mutableCopy];
            info[@"path"] = full;
            info[@"isZip"] = @YES;
            info[@"filename"] = e;
            [out addObject:info];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSNumber *la = a[@"last_played_ms"] ?: @0;
        NSNumber *lb = b[@"last_played_ms"] ?: @0;
        return [lb compare:la];
    }];
    _worlds = out;
    _emptyLabel.hidden = (out.count > 0);
    [_tableView.refreshControl endRefreshing];
    [_tableView reloadData];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _worlds.count;
}

- (NSString *)lastPlayedString:(NSNumber *)ms {
    if (![ms isKindOfClass:[NSNumber class]] || ms.longLongValue <= 0) return @"";
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:ms.longLongValue / 1000.0];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterNoStyle;
    return [fmt stringFromDate:date];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProfileItemCell" forIndexPath:indexPath];
    NSDictionary *w = _worlds[indexPath.row];
    NSString *ver = [w[@"version"] isKindOfClass:[NSString class]] ? w[@"version"] : @"";
    NSString *last = [self lastPlayedString:w[@"last_played_ms"]];
    NSMutableArray *parts = [NSMutableArray array];
    if (ver.length > 0) [parts addObject:[NSString stringWithFormat:@"MC %@", ver]];
    if (last.length > 0) [parts addObject:last];
    NSArray *dps = w[@"datapacks"];
    if ([dps isKindOfClass:[NSArray class]] && dps.count > 0) {
        [parts addObject:[NSString stringWithFormat:@"%lu datapacks", (unsigned long)dps.count]];
    }
    NSDictionary *item = @{
        @"title": w[@"title"] ?: @"World",
        @"version_number": [parts componentsJoinedByString:@"  •  "],
        @"source": @"local",
    };
    [cell configureWithItem:item status:@{@"status": @"none"} category:ModContentKindWorld];
    cell.enabledSwitch.hidden = YES;
    cell.actionButton.hidden = YES;
    UIImage *icon = w[@"icon_image"];
    if ([icon isKindOfClass:[UIImage class]]) {
        cell.iconView.image = icon;
        cell.iconView.tintColor = [UIColor clearColor];
    } else {
        cell.iconView.image = [UIImage systemImageNamed:@"globe"];
        cell.iconView.tintColor = ThemeManager.shared.secondaryTextColor;
    }
    cell.requestToken = w[@"path"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showWorldDetail:_worlds[indexPath.row]];
}

- (NSArray *)tableView:(UITableView *)tableView trailingSwipeActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *w = _worlds[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Share" handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf shareWorld:w]; done(YES);
    }];
    share.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction *a, UIView *v, void(^done)(BOOL)) {
        [weakSelf deleteWorld:w]; done(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash"];
    return @[del, share];
}

#pragma mark - Detail (datapacks inside world)

- (void)showWorldDetail:(NSDictionary *)w {
    NSString *path = w[@"path"];
    BOOL isDir = ![w[@"isZip"] boolValue];
    NSString *dpDir = isDir ? [path stringByAppendingPathComponent:@"datapacks"] : nil;
    NSArray *dpFiles = dpDir ? ([[NSFileManager defaultManager] contentsOfDirectoryAtPath:dpDir error:nil] ?: @[]) : @[];
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"Name: %@", w[@"title"] ?: @"?"]];
    if ([w[@"version"] isKindOfClass:[NSString class]]) [lines addObject:[NSString stringWithFormat:@"Version: %@", w[@"version"]]];
    NSString *last = [self lastPlayedString:w[@"last_played_ms"]];
    if (last.length > 0) [lines addObject:[NSString stringWithFormat:@"Last played: %@", last]];
    if ([w[@"game_type"] isKindOfClass:[NSNumber class]]) {
        [lines addObject:[NSString stringWithFormat:@"Game type: %@", w[@"game_type"]]];
    }
    NSMutableArray *dpNames = [NSMutableArray array];
    for (NSString *f in dpFiles) {
        if (![f hasSuffix:@".zip"]) continue;
        NSString *full = [dpDir stringByAppendingPathComponent:f];
        NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:full category:ModContentKindDatapack];
        NSString *t = meta[@"title"];
        if (![t isKindOfClass:[NSString class]] || t.length == 0) t = [f stringByDeletingPathExtension];
        NSString *pf = meta[@"pack_format"];
        if ([pf isKindOfClass:[NSString class]] && pf.length > 0) {
            t = [t stringByAppendingFormat:@" (%@)", [ModMetadataReader displayVersionForPackFormat:pf]];
        }
        [dpNames addObject:t];
    }
    NSString *msg = [[lines arrayByAddingObject:[NSString stringWithFormat:@"\nDatapacks (%lu):\n%@",
                                                 (unsigned long)dpNames.count,
                                                 dpNames.count > 0 ? [dpNames componentsJoinedByString:@"\n"] : @"none"]] componentsJoinedByString:@"\n"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:w[@"title"] ?: @"World" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Open folder" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
        vc.rootPath = isDir ? path : [path stringByDeletingLastPathComponent];
        vc.title = @"World files";
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Import / share / delete / browse

- (void)importTapped {
    [HapticManager.shared play:HapticTypeLight];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *dir = [self savesDir];
    NSUInteger imported = 0;
    for (NSURL *url in urls) {
        BOOL accessing = [url startAccessingSecurityScopedResource];
        NSString *name = url.lastPathComponent;
        if ([name hasSuffix:@".zip"]) {
            NSString *dest = [dir stringByAppendingPathComponent:name];
            [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
            NSError *err = nil;
            if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&err]) imported++;
            else [ErrorPresenter showFileError:@"Import" path:name error:err];
        }
        if (accessing) [url stopAccessingSecurityScopedResource];
    }
    if (imported == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Pick world .zip files."];
        return;
    }
    [HapticManager.shared play:HapticTypeSuccess];
    [self reloadContent];
}

- (void)shareWorld:(NSDictionary *)w {
    NSString *path = w[@"path"];
    if (![path isKindOfClass:[NSString class]] || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [ErrorPresenter showFileError:@"Share" path:@"" error:nil];
        return;
    }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:av animated:YES completion:nil];
}

- (void)deleteWorld:(NSDictionary *)w {
    NSString *path = w[@"path"];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete world?" message:w[@"title"] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSError *err = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&err]) {
            [ErrorPresenter showFileError:@"Delete" path:path.lastPathComponent error:err];
            return;
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf reloadContent];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)browseTapped {
    FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
    vc.rootPath = [self savesDir];
    vc.title = @"Saves";
    [self.navigationController pushViewController:vc animated:YES];
}

@end
