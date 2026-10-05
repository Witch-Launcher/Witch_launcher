#import "LauncherUpdateViewController.h"
#import "WitchUpdateService.h"
#import "ThemeManager.h"

typedef NS_ENUM(NSInteger, UpdateSection) {
    UpdateSectionChannel = 0,
    UpdateSectionCurrentVersion,
    UpdateSectionStatus,
    UpdateSectionActions,
    UpdateSectionReleaseNotes,
    UpdateSectionCount
};

@interface LauncherUpdateViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) WitchUpdateChannel selectedChannel;
@property (nonatomic) WitchAppVariant selectedVariant;
@property (nonatomic) WitchReleaseInfo *lastInfo;
@property (nonatomic) BOOL hasUpdate;
@property (nonatomic) BOOL isChecking;
@property (nonatomic) BOOL isDownloading;
@property (nonatomic) float downloadProgress;
@property (nonatomic) UIActivityIndicatorView *checkingSpinner;
@property (nonatomic) UIProgressView *downloadProgressView;
@property (nonatomic) UIButton *downloadButton;
@property (nonatomic) UILabel *emptyLabel;
@end

@implementation LauncherUpdateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Cập nhật Launcher";
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    
    self.selectedChannel = WitchUpdateService.shared.selectedChannel;
    self.selectedVariant = WitchAppVariantFull;
    
    [self setupTableView];
    [self setupEmptyLabel];
    [self refreshCurrentVersionInfo];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorColor = ThemeManager.shared.separatorColor;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.alwaysBounceVertical = YES;
    [self.view addSubview:_tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    _checkingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _checkingSpinner.hidesWhenStopped = YES;
    
    _downloadProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _downloadProgressView.trackTintColor = ThemeManager.shared.separatorColor;
    _downloadProgressView.progressTintColor = ThemeManager.shared.accentColor;
    _downloadProgressView.hidden = YES;
}

- (void)setupEmptyLabel {
    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:15];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.text = @"Chưa kiểm tra cập nhật.\nBấm \"Kiểm tra cập nhật\" để bắt đầu.";
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32]
    ]];
}

- (void)refreshCurrentVersionInfo {
    // Force table reload for current version section
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:UpdateSectionCurrentVersion] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return UpdateSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case UpdateSectionChannel:
            return 2; // Channel + Variant
        case UpdateSectionCurrentVersion:
            return 1;
        case UpdateSectionStatus:
            return self.lastInfo ? 1 : 0;
        case UpdateSectionActions:
            return 1;
        case UpdateSectionReleaseNotes:
            return (self.lastInfo && self.lastInfo.body.length > 0) ? 1 : 0;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case UpdateSectionChannel:
            return [self tableView:tableView channelCellForRowAtIndexPath:indexPath];
        case UpdateSectionCurrentVersion:
            return [self tableView:tableView currentVersionCellForRowAtIndexPath:indexPath];
        case UpdateSectionStatus:
            return [self tableView:tableView statusCellForRowAtIndexPath:indexPath];
        case UpdateSectionActions:
            return [self tableView:tableView actionsCellForRowAtIndexPath:indexPath];
        case UpdateSectionReleaseNotes:
            return [self tableView:tableView releaseNotesCellForRowAtIndexPath:indexPath];
        default:
            return [[UITableViewCell alloc] init];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView channelCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Kênh cập nhật";
        cell.detailTextLabel.text = [WitchUpdateService.shared channelDisplayName:self.selectedChannel];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = @"Bản phân phối";
        cell.detailTextLabel.text = (self.selectedVariant == WitchAppVariantSlimmed) ? @"Bản Simple (nhẹ)" : @"Bản Full (đầy đủ)";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView currentVersionCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"CurrentVersionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
        cell.detailTextLabel.numberOfLines = 0;
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"Phiên bản hiện tại: v%@", WitchUpdateService.shared.currentVersion];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • Kênh mặc định: %@",
        WitchUpdateService.shared.isBetaBuild ? @"Beta build" : @"Release build",
        [WitchUpdateService.shared channelDisplayName:self.selectedChannel]];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView statusCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"StatusCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }
    
    if (!self.lastInfo) {
        cell.textLabel.text = @"Chưa kiểm tra";
        cell.detailTextLabel.text = nil;
        cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;
        return cell;
    }
    
    WitchReleaseAsset *asset = [self.lastInfo assetForVariant:self.selectedVariant isTrollStore:WitchUpdateService.shared.isTrollStoreInstall];
    if (!asset) asset = self.lastInfo.assets.firstObject;
    
    if (self.hasUpdate) {
        cell.textLabel.text = @"🎉 Có bản cập nhật mới!";
        cell.textLabel.textColor = ThemeManager.shared.successColor;
        if (asset) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)\nKích thước: %.1f MB", self.lastInfo.tagName, asset.name, (double)asset.size / 1048576.0];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (không tìm thấy file cài đặt phù hợp)", self.lastInfo.tagName];
        }
    } else {
        cell.textLabel.text = @"✅ Đã ở bản mới nhất";
        cell.textLabel.textColor = ThemeManager.shared.successColor;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ là bản hiện tại", self.lastInfo.tagName];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView actionsCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ActionsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = UIColor.clearColor;
        
        _downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _downloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _downloadButton.layer.cornerRadius = 10;
        _downloadButton.clipsToBounds = YES;
        _downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_downloadButton addTarget:self action:@selector(downloadAndInstall) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:_downloadButton];
        
        [cell.contentView addSubview:_downloadProgressView];
        _downloadProgressView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [_downloadButton.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [_downloadButton.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [_downloadButton.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_downloadButton.heightAnchor constraintEqualToConstant:48],
            [_downloadProgressView.topAnchor constraintEqualToAnchor:_downloadButton.bottomAnchor constant:8],
            [_downloadProgressView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [_downloadProgressView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_downloadProgressView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
            [_downloadProgressView.heightAnchor constraintEqualToConstant:4]
        ]];
    }
    
    BOOL canDownload = self.lastInfo && self.hasUpdate;
    WitchReleaseAsset *asset = canDownload ? [self.lastInfo assetForVariant:self.selectedVariant isTrollStore:WitchUpdateService.shared.isTrollStoreInstall] : nil;
    if (!asset) asset = self.lastInfo.assets.firstObject;
    canDownload = canDownload && asset != nil;
    
    if (self.isDownloading) {
        [_downloadButton setTitle:[NSString stringWithFormat:@"Đang tải... %.0f%%", self.downloadProgress * 100] forState:UIControlStateNormal];
        _downloadButton.backgroundColor = ThemeManager.shared.accentColor;
        _downloadButton.enabled = NO;
        [_downloadButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
        _downloadProgressView.hidden = NO;
        _downloadProgressView.progress = self.downloadProgress;
    } else if (canDownload) {
        [_downloadButton setTitle:[NSString stringWithFormat:@"Tải & Cài đặt %@", asset.name] forState:UIControlStateNormal];
        _downloadButton.backgroundColor = ThemeManager.shared.accentColor;
        _downloadButton.enabled = YES;
        [_downloadButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
        _downloadProgressView.hidden = YES;
    } else if (self.lastInfo && !self.hasUpdate) {
        [_downloadButton setTitle:@"Đã ở bản mới nhất" forState:UIControlStateNormal];
        _downloadButton.backgroundColor = ThemeManager.shared.separatorColor;
        _downloadButton.enabled = NO;
        [_downloadButton setTitleColor:ThemeManager.shared.secondaryTextColor forState:UIControlStateNormal];
        _downloadProgressView.hidden = YES;
    } else {
        [_downloadButton setTitle:@"Kiểm tra cập nhật trước" forState:UIControlStateNormal];
        _downloadButton.backgroundColor = ThemeManager.shared.separatorColor;
        _downloadButton.enabled = NO;
        [_downloadButton setTitleColor:ThemeManager.shared.secondaryTextColor forState:UIControlStateNormal];
        _downloadProgressView.hidden = YES;
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView releaseNotesCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ReleaseNotesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        
        UITextView *textView = [[UITextView alloc] init];
        textView.editable = NO;
        textView.scrollEnabled = NO;
        textView.font = [UIFont systemFontOfSize:13];
        textView.textColor = ThemeManager.shared.primaryTextColor;
        textView.backgroundColor = UIColor.clearColor;
        textView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
        textView.translatesAutoresizingMaskIntoConstraints = NO;
        textView.tag = 100;
        [cell.contentView addSubview:textView];
        
        [NSLayoutConstraint activateConstraints:@[
            [textView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [textView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [textView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
            [textView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
        ]];
    }
    
    UITextView *textView = (UITextView *)[cell.contentView viewWithTag:100];
    textView.text = self.lastInfo.body.length > 0 ? self.lastInfo.body : @"(Không có release notes)";
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case UpdateSectionChannel:
            return @"Tùy chọn";
        case UpdateSectionCurrentVersion:
            return @"Thông tin phiên bản";
        case UpdateSectionStatus:
            return @"Trạng thái cập nhật";
        case UpdateSectionActions:
            return @"Hành động";
        case UpdateSectionReleaseNotes:
            return @"Release Notes";
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == UpdateSectionChannel) {
        return @"Tự động: Beta build → pre-release, Release build → release. Beta: luôn pre-release. Ổn định: luôn release.";
    }
    if (section == UpdateSectionCurrentVersion) {
        return @"Phiên bản đang chạy trên thiết bị này.";
    }
    if (section == UpdateSectionStatus) {
        return self.hasUpdate ? @"Có bản cập nhật sẵn sàng tải về." : (self.lastInfo ? @"Không có bản cập nhật mới." : nil);
    }
    if (section == UpdateSectionActions) {
        return self.isDownloading ? @"Đang tải file cập nhật..." : (self.lastInfo && self.hasUpdate ? @"Bấm để tải và cài đặt bản cập nhật." : @"Kiểm tra cập nhật để xem bản mới có sẵn không.");
    }
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == UpdateSectionChannel) {
        if (indexPath.row == 0) {
            [self showChannelPicker];
        } else {
            [self showVariantPicker];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == UpdateSectionReleaseNotes) return 200;
    if (indexPath.section == UpdateSectionStatus) return 80;
    if (indexPath.section == UpdateSectionActions) return 70;
    return 50;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == UpdateSectionReleaseNotes) return UITableViewAutomaticDimension;
    if (indexPath.section == UpdateSectionStatus) return UITableViewAutomaticDimension;
    if (indexPath.section == UpdateSectionActions) return UITableViewAutomaticDimension;
    return 50;
}

#pragma mark - Actions

- (void)showChannelPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn kênh cập nhật" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *channels = @[@"Tự động", @"Beta (pre-release)", @"Ổn định (release)"];
    for (NSInteger i = 0; i < channels.count; i++) {
        UIAlertActionStyle style = (i == self.selectedChannel) ? UIAlertActionStyleDefault : UIAlertActionStyleDefault;
        [alert addAction:[UIAlertAction actionWithTitle:channels[i] style:style handler:^(UIAlertAction *action) {
            self.selectedChannel = (WitchUpdateChannel)i;
            [WitchUpdateService.shared setSelectedChannel:self.selectedChannel];
            self.lastInfo = nil;
            self.hasUpdate = NO;
            [_tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(UpdateSectionChannel, 3)] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self refreshCurrentVersionInfo];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showVariantPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn bản phân phối" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *variants = @[@"Bản Full (đầy đủ tính năng)", @"Bản Simple (nhẹ, không kèm JDK/LWJGL)"];
    for (NSInteger i = 0; i < variants.count; i++) {
        [alert addAction:[UIAlertAction actionWithTitle:variants[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedVariant = (WitchAppVariant)i;
            if (self.lastInfo) {
                self.hasUpdate = YES; // Re-check asset availability
                WitchReleaseAsset *asset = [self.lastInfo assetForVariant:self.selectedVariant isTrollStore:WitchUpdateService.shared.isTrollStoreInstall];
                if (!asset) self.hasUpdate = NO;
            }
            [_tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(UpdateSectionChannel, 3)] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)checkNow {
    if (self.isChecking || self.isDownloading) return;
    
    self.isChecking = YES;
    self.lastInfo = nil;
    self.hasUpdate = NO;
    [_tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(UpdateSectionStatus, 3)] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    // Show spinner in check button cell
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:UpdateSectionActions]] withRowAnimation:UITableViewRowAnimationNone];
    
    [WitchUpdateService.shared checkForUpdateForce:YES completion:^(WitchReleaseInfo *info, BOOL hasUpdate, NSError *error) {
        self.isChecking = NO;
        
        if (error) {
            self.hasUpdate = NO;
            self.lastInfo = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(UpdateSectionStatus, 3)] withRowAnimation:UITableViewRowAnimationAutomatic];
                // Show error in status
                UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Lỗi kiểm tra" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errAlert animated:YES completion:nil];
            });
            return;
        }
        
        self.lastInfo = info;
        self.hasUpdate = hasUpdate;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(UpdateSectionStatus, 3)] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];
}

- (void)downloadAndInstall {
    if (!self.lastInfo || self.isDownloading) return;
    
    WitchReleaseAsset *asset = [self.lastInfo assetForVariant:self.selectedVariant isTrollStore:WitchUpdateService.shared.isTrollStoreInstall];
    if (!asset) asset = self.lastInfo.assets.firstObject;
    if (!asset) return;
    
    self.isDownloading = YES;
    self.downloadProgress = 0.1f;
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:UpdateSectionActions]] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [WitchUpdateService.shared downloadAsset:asset progress:^(float p) {
        self.downloadProgress = p;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:UpdateSectionActions]] withRowAnimation:UITableViewRowAnimationNone];
        });
    } completion:^(NSURL *fileURL, NSError *error) {
        self.isDownloading = NO;
        self.downloadProgress = 0;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:UpdateSectionActions]] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            if (error || !fileURL) {
                UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Tải thất bại" message:[NSString stringWithFormat:@"%@", error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errAlert animated:YES completion:nil];
                return;
            }
            
            UIAlertController *doneAlert = [UIAlertController alertControllerWithTitle:@"Đã tải xong" message:@"File cập nhật đã sẵn sàng. Đang mở trình cài đặt..." preferredStyle:UIAlertControllerStyleAlert];
            [doneAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:doneAlert animated:YES completion:^{
                [WitchUpdateService.shared installFileAtURL:fileURL fromViewController:self];
            }];
        });
    }];
}

@end