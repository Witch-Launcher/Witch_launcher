#import "LauncherUpdateViewController.h"
#import "WitchUpdateService.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "AppSheet.h"

typedef NS_ENUM(NSInteger, UpdateSection) {
    UpdateSectionInfo = 0,
    UpdateSectionOptions,
    UpdateSectionReleases,
    UpdateSectionCount
};

@interface LauncherUpdateViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) WitchUpdateChannel selectedChannel;
@property (nonatomic) WitchAppVariant selectedVariant;
@property (nonatomic) NSArray<WitchReleaseInfo *> *releases;
@property (nonatomic) BOOL isChecking;
@property (nonatomic) BOOL isDownloading;
@property (nonatomic) UIActivityIndicatorView *navSpinner;
@end

@implementation LauncherUpdateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Cập nhật Launcher";
    // Opaque base under the frost: without this the previous screen shows
    // through the pushed page.
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    self.selectedChannel = WitchUpdateService.shared.selectedChannel;
    self.selectedVariant = WitchAppVariantFull;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 64;
    _tableView.alwaysBounceVertical = YES;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UpdateCell"];
    [self.view addSubview:_tableView];

    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    [rc addTarget:self action:@selector(checkNow) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = rc;

    UIBarButtonItem *check = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(checkNow)];
    self.navigationItem.rightBarButtonItem = check;

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self checkNow];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [_tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setBusy:(BOOL)busy {
    _isChecking = busy;
    if (busy && !_navSpinner) {
        _navSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [_navSpinner startAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_navSpinner];
    } else if (!busy) {
        _navSpinner = nil;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(checkNow)];
    }
}

#pragma mark - Data

- (void)checkNow {
    if (_isChecking || _isDownloading) return;
    [self setBusy:YES];
    [_tableView.refreshControl beginRefreshing];
    dispatch_group_t g = dispatch_group_create();
    __block WitchReleaseInfo *tagInfo = nil;
    __block NSError *tagError = nil;
    __block NSArray *all = nil;
    __block NSError *listError = nil;
    dispatch_group_enter(g);
    [WitchUpdateService.shared checkForUpdateForce:YES completion:^(WitchReleaseInfo *info, BOOL hasUpdate, NSError *error) {
        tagInfo = info; tagError = error;
        dispatch_group_leave(g);
    }];
    dispatch_group_enter(g);
    [WitchUpdateService.shared fetchAllReleasesWithLimit:20 completion:^(NSArray *releases, NSError *error) {
        all = releases; listError = error;
        dispatch_group_leave(g);
    }];
    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        [self setBusy:NO];
        [self->_tableView.refreshControl endRefreshing];
        if (tagError && listError) {
            [ErrorPresenter showNetworkError:tagError message:@"Không kiểm tra được cập nhật."];
            return;
        }
        // Merge: channel tag release first, then the rest (dedupe by tag).
        NSMutableArray *merged = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        if (tagInfo && tagInfo.tagName.length > 0) {
            [merged addObject:tagInfo];
            [seen addObject:tagInfo.tagName];
        }
        for (WitchReleaseInfo *r in all ?: @[]) {
            if (r.tagName.length > 0 && ![seen containsObject:r.tagName]) {
                [merged addObject:r];
                [seen addObject:r.tagName];
            }
        }
        self->_releases = merged;
        [self->_tableView reloadData];
        if (tagError) [ErrorPresenter showNetworkError:tagError message:@"Không tải được bản mới nhất của kênh."];
    });
    (void)tagInfo;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return UpdateSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == UpdateSectionInfo) return 1;
    if (section == UpdateSectionOptions) return 2;
    return _releases.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == UpdateSectionInfo) return @"Thiết bị";
    if (section == UpdateSectionOptions) return @"Tùy chọn";
    return _releases.count > 0 ? [NSString stringWithFormat:@"Các bản phát hành (%lu)", (unsigned long)_releases.count] : @"Các bản phát hành";
}

- (UITableViewCell *)cardCellForTableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UpdateCell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.layer.cornerRadius = 14;
    cell.clipsToBounds = YES;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.detailTextLabel.numberOfLines = 2;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == UpdateSectionInfo) {
        UITableViewCell *cell = [self cardCellForTableView:tableView];
        NSString *cur = WitchUpdateService.shared.currentVersion;
        cell.textLabel.text = [NSString stringWithFormat:@"Đang chạy: v%@", cur];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • Kênh: %@",
                                     WitchUpdateService.shared.isBetaBuild ? @"Beta build" : @"Release build",
                                     [WitchUpdateService.shared channelDisplayName:self.selectedChannel]];
        cell.imageView.image = [UIImage systemImageNamed:@"app.badge"];
        cell.imageView.tintColor = ThemeManager.shared.accentColor;
        return cell;
    }
    if (indexPath.section == UpdateSectionOptions) {
        UITableViewCell *cell = [self cardCellForTableView:tableView];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Kênh cập nhật";
            cell.detailTextLabel.text = [WitchUpdateService.shared channelDisplayName:self.selectedChannel];
            cell.imageView.image = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
        } else {
            cell.textLabel.text = @"Bản phân phối";
            cell.detailTextLabel.text = (self.selectedVariant == WitchAppVariantSlimmed) ? @"Simple (nhẹ)" : @"Full (đầy đủ)";
            cell.imageView.image = [UIImage systemImageNamed:@"archivebox"];
        }
        cell.imageView.tintColor = ThemeManager.shared.accentColor;
        return cell;
    }
    WitchReleaseInfo *info = _releases[indexPath.row];
    UITableViewCell *cell = [self cardCellForTableView:tableView];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSString *title = info.tagName.length > 0 ? info.tagName : (info.name.length > 0 ? info.name : @"Bản phát hành");
    BOOL isCurrent = [self isReleaseCurrent:info];
    cell.textLabel.text = isCurrent ? [@"► " stringByAppendingString:title] : title;
    cell.textLabel.textColor = isCurrent ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;
    NSMutableArray *parts = [NSMutableArray array];
    if (isCurrent) [parts addObject:@"Đang dùng"];
    if (info.publishedAt.length > 0) [parts addObject:[self shortDate:info.publishedAt]];
    [parts addObject:[NSString stringWithFormat:@"%lu file", (unsigned long)info.assets.count]];
    cell.detailTextLabel.text = [parts componentsJoinedByString:@" • "];
    cell.imageView.image = [UIImage systemImageNamed:isCurrent ? @"checkmark.circle.fill" : @"arrow.down.circle"];
    cell.imageView.tintColor = isCurrent ? ThemeManager.shared.successColor : ThemeManager.shared.accentColor;
    return cell;
}

- (BOOL)isReleaseCurrent:(WitchReleaseInfo *)info {
    NSString *cur = WitchUpdateService.shared.currentVersion;
    if (cur.length == 0) return NO;
    NSString *tag = info.tagName;
    // Tags look like "v0.0.3" or "0.0.3(-tag)": match when either contains the version.
    return [tag containsString:cur] || [cur containsString:tag];
}

- (NSString *)shortDate:(NSString *)iso {
    // 2026-10-16T03:46:00Z -> 16/10/2026
    if (iso.length >= 10) {
        NSString *d = [iso substringToIndex:10];
        NSArray *p = [d componentsSeparatedByString:@"-"];
        if (p.count == 3) return [NSString stringWithFormat:@"%@/%@/%@", p[2], p[1], p[0]];
    }
    return iso;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == UpdateSectionOptions) {
        if (indexPath.row == 0) [self showChannelPicker];
        else [self showVariantPicker];
        return;
    }
    if (indexPath.section == UpdateSectionReleases) {
        [self showReleaseAssets:_releases[indexPath.row]];
    }
}

#pragma mark - Pickers (custom sheets, no UIKit alerts)

- (void)showChannelPicker {
    NSArray *titles = @[@"Tự động", @"Beta (pre-release)", @"Ổn định (release)"];
    NSMutableArray *opts = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        [opts addObject:@{@"title": titles[i], @"icon": @"antenna.radiowaves.left.and.right"}];
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:@"Kênh cập nhật" message:@"Tự động: Beta build theo pre-release, Release build theo release." options:opts selectedIndex:self.selectedChannel selection:^(NSInteger idx) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.selectedChannel = (WitchUpdateChannel)idx;
        [WitchUpdateService.shared setSelectedChannel:strongSelf.selectedChannel];
        [strongSelf->_tableView reloadData];
        [strongSelf checkNow];
    }];
}

- (void)showVariantPicker {
    NSArray *opts = @[
        @{@"title": @"Full (đầy đủ)", @"subtitle": @"Kèm JDK + LWJGL", @"icon": @"archivebox.fill"},
        @{@"title": @"Simple (nhẹ)", @"subtitle": @"Không kèm runtime", @"icon": @"archivebox"},
    ];
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:@"Bản phân phối" message:nil options:opts selectedIndex:self.selectedVariant selection:^(NSInteger idx) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.selectedVariant = (WitchAppVariant)idx;
        [strongSelf->_tableView reloadData];
    }];
}

- (void)showReleaseAssets:(WitchReleaseInfo *)info {
    if (info.assets.count == 0) {
        [ErrorPresenter showInfo:@"Trống" message:@"Bản này không có file cài đặt."];
        return;
    }
    NSMutableArray *opts = [NSMutableArray array];
    for (WitchReleaseAsset *a in info.assets) {
        NSString *sub = a.size > 0 ? [NSByteCountFormatter stringFromByteCount:a.size countStyle:NSByteCountFormatterCountStyleFile] : @"";
        [opts addObject:@{@"title": a.name, @"subtitle": sub, @"icon": @"arrow.down.circle"}];
    }
    NSString *notes = info.body.length > 200 ? [[info.body substringToIndex:200] stringByAppendingString:@"…"] : info.body;
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:info.tagName message:notes options:opts selectedIndex:NSNotFound selection:^(NSInteger idx) {
        [weakSelf showAssetActions:info.assets[idx]];
    }];
}

- (void)showAssetActions:(WitchReleaseAsset *)asset {
    BOOL ts = WitchUpdateService.shared.isTrollStoreInstall;
    BOOL isTipa = [[asset.name.pathExtension lowercaseString] isEqualToString:@"tipa"];
    NSMutableArray *opts = [NSMutableArray array];
    if (ts || isTipa) {
        [opts addObject:@{@"title": @"Tải & Cài qua TrollStore", @"subtitle": asset.name, @"icon": @"arrow.down.circle.fill"}];
    } else {
        [opts addObject:@{@"title": @"Cài qua SideStore", @"subtitle": @"Mở SideStore để cài (giữ nguyên dữ liệu)", @"icon": @"arrow.down.circle.fill"}];
    }
    [opts addObject:@{@"title": @"Chỉ tải về máy", @"subtitle": @"Lưu file rồi tự cài qua Share", @"icon": @"tray.and.arrow.down"}];
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:asset.name message:nil options:opts selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0 && !(ts || isTipa)) {
            // SideStore direct install (no download needed).
            if (![WitchUpdateService.shared installAssetRemotely:asset fromViewController:weakSelf]) {
                [weakSelf downloadAsset:asset];
            }
        } else {
            [weakSelf downloadAsset:asset];
        }
    }];
}

- (void)downloadAsset:(WitchReleaseAsset *)asset {
    if (_isDownloading) return;
    _isDownloading = YES;
    [ErrorPresenter showToast:[NSString stringWithFormat:@"Đang tải %@…", asset.name] success:YES];
    __weak typeof(self) weakSelf = self;
    [WitchUpdateService.shared downloadAsset:asset progress:nil completion:^(NSURL *fileURL, NSError *error) {
        weakSelf.isDownloading = NO;
        if (error || !fileURL) {
            [ErrorPresenter showNetworkError:error message:@"Tải thất bại."];
            return;
        }
        [WitchUpdateService.shared installFileAtURL:fileURL fromViewController:weakSelf];
    }];
}

@end
