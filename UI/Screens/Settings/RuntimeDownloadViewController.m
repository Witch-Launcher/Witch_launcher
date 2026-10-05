#import "RuntimeDownloadViewController.h"
#import "WitchRuntimeService.h"
#import "ThemeManager.h"

typedef NS_ENUM(NSInteger, RuntimeSection) {
    RuntimeSectionJDK = 0,
    RuntimeSectionLWJGL,
    RuntimeSectionCount
};

@interface RuntimeDownloadViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray<WitchRuntimeItem *> *jdkItems;
@property (nonatomic) NSArray<WitchRuntimeItem *> *lwjglItems;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *headerLabel;
@property (nonatomic) UILabel *footerLabel;
@property (nonatomic) BOOL isLoading;
@property (nonatomic) NSError *loadError;
@end

@implementation RuntimeDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.onboardingMode ? @"Tải Runtime (bản Simple)" : @"Quản lý Runtime JDK / LWJGL";
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    
    [self setupTableView];
    [self setupHeaderAndFooter];
    [self setupNavigationItems];
    [self reload];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorColor = ThemeManager.shared.separatorColor;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.alwaysBounceVertical = YES;
    _tableView.estimatedRowHeight = 72;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    _tableView.estimatedSectionHeaderHeight = 40;
    [self.view addSubview:_tableView];
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)setupHeaderAndFooter {
    _headerLabel = [[UILabel alloc] init];
    _headerLabel.numberOfLines = 0;
    _headerLabel.font = [UIFont systemFontOfSize:14];
    _headerLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _headerLabel.textAlignment = NSTextAlignmentCenter;
    _headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (self.onboardingMode) {
        _headerLabel.text = @"Bản Simple không kèm sẵn JDK/LWJGL.\nChọn các runtime cần thiết (đánh dấu 🔴 = quan trọng) rồi bấm Tải.\nCó thể mở lại màn này sau trong Settings → Quản lý Runtime.";
    } else {
        _headerLabel.text = @"Quản lý JDK và LWJGL. Bản Full đã kèm sẵn; bản Simple cần tải thêm.\n🔴 = khuyến nghị tải. Bấm vào từng dòng để Tải/Cập nhật/Xóa.";
    }
    
    _footerLabel = [[UILabel alloc] init];
    _footerLabel.numberOfLines = 0;
    _footerLabel.font = [UIFont systemFontOfSize:12];
    _footerLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _footerLabel.textAlignment = NSTextAlignmentCenter;
    _footerLabel.text = @"Nguồn: Witch-Launcher/JDK-Java_iOS (runtimes-latest). JDK: .tar.xz cần giải nén trong Manage Runtime. LWJGL: tự ghi marker, dùng ngay.";
    _footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:_headerLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_headerLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:16],
        [_headerLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16],
        [_headerLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16],
        [_headerLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-16]
    ]];
    _tableView.tableHeaderView = headerView;
    
    UIView *footerView = [[UIView alloc] init];
    footerView.translatesAutoresizingMaskIntoConstraints = NO;
    [footerView addSubview:_footerLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_footerLabel.topAnchor constraintEqualToAnchor:footerView.topAnchor constant:16],
        [_footerLabel.leadingAnchor constraintEqualToAnchor:footerView.leadingAnchor constant:16],
        [_footerLabel.trailingAnchor constraintEqualToAnchor:footerView.trailingAnchor constant:-16],
        [_footerLabel.bottomAnchor constraintEqualToAnchor:footerView.bottomAnchor constant:-16]
    ]];
    _tableView.tableFooterView = footerView;
    
    // Force layout
    [headerView setNeedsLayout];
    [headerView layoutIfNeeded];
    _tableView.tableHeaderView = headerView;
    [footerView setNeedsLayout];
    [footerView layoutIfNeeded];
    _tableView.tableFooterView = footerView;
}

- (void)setupNavigationItems {
    if (self.onboardingMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Bỏ qua" style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    }
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    self.navigationItem.leftBarButtonItem = refresh;
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.loadError = nil;
    [_spinner startAnimating];
    _tableView.tableHeaderView.hidden = YES;
    
    [WitchRuntimeService.shared refreshStatuses:^(NSArray<WitchRuntimeItem *> *items, NSError *error) {
        self.isLoading = NO;
        self.loadError = error;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_spinner stopAnimating];
            _tableView.tableHeaderView.hidden = NO;
            
            if (error) {
                _headerLabel.text = [NSString stringWithFormat:@"⚠️ Không tải được manifest (dùng cache local).\nLỗi: %@\nURL: %@", error.localizedDescription, WitchRuntimeService.shared.manifestURL];
            } else {
                _headerLabel.text = self.onboardingMode ? @"Bản Simple không kèm sẵn JDK/LWJGL.\nChọn các runtime cần thiết (🔴 = quan trọng) rồi bấm Tải." : @"Quản lý JDK và LWJGL. 🔴 = khuyến nghị tải. Bấm vào dòng để Tải/Cập nhật/Xóa.";
            }
            
            // Split items by kind
            NSMutableArray *jdk = [NSMutableArray array];
            NSMutableArray *lwjgl = [NSMutableArray array];
            for (WitchRuntimeItem *it in items) {
                if (it.kind == WitchRuntimeKindJDK) [jdk addObject:it];
                else [lwjgl addObject:it];
            }
            self.jdkItems = jdk;
            self.lwjglItems = lwjgl;
            
            [_tableView reloadData];
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return RuntimeSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == RuntimeSectionJDK) return self.jdkItems.count;
    if (section == RuntimeSectionLWJGL) return self.lwjglItems.count;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"RuntimeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // Custom layout with status badge
        UIView *statusContainer = [[UIView alloc] init];
        statusContainer.translatesAutoresizingMaskIntoConstraints = NO;
        statusContainer.tag = 10;
        [cell.contentView addSubview:statusContainer];
        
        UILabel *statusLabel = [[UILabel alloc] init];
        statusLabel.tag = 11;
        statusLabel.font = [UIFont boldSystemFontOfSize:11];
        statusLabel.textAlignment = NSTextAlignmentCenter;
        statusLabel.layer.cornerRadius = 8;
        statusLabel.clipsToBounds = YES;
        statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [statusContainer addSubview:statusLabel];
        
        UILabel *sizeLabel = [[UILabel alloc] init];
        sizeLabel.tag = 12;
        sizeLabel.font = [UIFont systemFontOfSize:11];
        sizeLabel.textColor = ThemeManager.shared.secondaryTextColor;
        sizeLabel.textAlignment = NSTextAlignmentRight;
        sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [statusContainer addSubview:sizeLabel];
        
        UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        actionButton.tag = 13;
        actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        actionButton.layer.cornerRadius = 6;
        actionButton.clipsToBounds = YES;
        actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        [actionButton addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [statusContainer addSubview:actionButton];
        
        NSArray *constraints = @[
            [statusContainer.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
            [statusContainer.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [statusContainer.widthAnchor constraintGreaterThanOrEqualToConstant:80],
            [statusContainer.heightAnchor constraintEqualToConstant:28],
            
            [statusLabel.leadingAnchor constraintEqualToAnchor:statusContainer.leadingAnchor constant:8],
            [statusLabel.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
            [statusLabel.heightAnchor constraintEqualToConstant:20],
            
            [sizeLabel.leadingAnchor constraintEqualToAnchor:statusLabel.trailingAnchor constant:4],
            [sizeLabel.trailingAnchor constraintEqualToAnchor:actionButton.leadingAnchor constant:-4],
            [sizeLabel.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
            [sizeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:50],
            
            [actionButton.trailingAnchor constraintEqualToAnchor:statusContainer.trailingAnchor constant:-8],
            [actionButton.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
            [actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:56],
            [actionButton.heightAnchor constraintEqualToConstant:24]
        ];
        [NSLayoutConstraint activateConstraints:constraints];
    }
    
    NSArray *items = (indexPath.section == RuntimeSectionJDK) ? self.jdkItems : self.lwjglItems;
    WitchRuntimeItem *item = items[indexPath.row];
    
    // Main text
    NSString *importantBadge = item.important ? @" 🔴" : @"";
    cell.textLabel.text = [item.displayName stringByAppendingString:importantBadge];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    
    // Detail text (version info)
    NSString *detailText = @"";
    if (item.installed) {
        detailText = [NSString stringWithFormat:@"Đã cài • %@", item.localVersion ?: @"đang chạy"];
        if (item.updateAvailable) {
            detailText = [detailText stringByAppendingFormat:@" → Có update (%@)", item.remoteVersion];
        }
    } else {
        detailText = item.remoteVersion ? [NSString stringWithFormat:@"Chưa cài • Mới: %@", item.remoteVersion] : @"Chưa cài • Không có thông tin remote";
    }
    cell.detailTextLabel.text = detailText;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = item.important && !item.installed ? ThemeManager.shared.errorColor : ThemeManager.shared.secondaryTextColor;
    
    // Status badge
    UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:11];
    UIButton *actionButton = (UIButton *)[cell.contentView viewWithTag:13];
    UILabel *sizeLabel = (UILabel *)[cell.contentView viewWithTag:12];
    
    // Configure status badge
    if (item.installed) {
        if (item.updateAvailable) {
            statusLabel.text = @"  Cập nhật  ";
            statusLabel.backgroundColor = ThemeManager.shared.warningColor;
            statusLabel.textColor = UIColor.blackColor;
        } else {
            statusLabel.text = @"  Đã cài  ";
            statusLabel.backgroundColor = ThemeManager.shared.successColor;
            statusLabel.textColor = UIColor.whiteColor;
        }
    } else {
        statusLabel.text = @"  Chưa cài  ";
        statusLabel.backgroundColor = ThemeManager.shared.separatorColor;
        statusLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }
    
    // Size
    if (item.remoteSize > 0) {
        sizeLabel.text = [NSByteCountFormatter stringFromByteCount:item.remoteSize countStyle:NSByteCountFormatterCountStyleMemory];
    } else {
        sizeLabel.text = @"";
    }
    
    // Action button
    if (item.installed && !item.updateAvailable) {
        [actionButton setTitle:@"Xóa" forState:UIControlStateNormal];
        actionButton.backgroundColor = ThemeManager.shared.errorColor;
        [actionButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
    } else if (item.updateAvailable) {
        [actionButton setTitle:@"Cập nhật" forState:UIControlStateNormal];
        actionButton.backgroundColor = ThemeManager.shared.accentColor;
        [actionButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
    } else {
        [actionButton setTitle:@"Tải" forState:UIControlStateNormal];
        actionButton.backgroundColor = ThemeManager.shared.accentColor;
        [actionButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
    }
    
    actionButton.enabled = item.remoteURL.length > 0 || item.installed;
    actionButton.alpha = actionButton.enabled ? 1.0 : 0.5;
    actionButton.accessibilityIdentifier = item.identifier; // Store identifier for action
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.clearColor;
    
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont boldSystemFontOfSize:14];
    label.textColor = ThemeManager.shared.primaryTextColor;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:label];
    
    if (section == RuntimeSectionJDK) {
        label.text = @"  Java Development Kit (JDK)";
    } else {
        label.text = @"  LWJGL (Lightweight Java Game Library)";
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16],
        [label.topAnchor constraintEqualToAnchor:view.topAnchor constant:8],
        [label.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-8]
    ]];
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == RuntimeSectionJDK) {
        return @"JDK 8 cho Minecraft ≤1.16.5. JDK 17/21 cho 1.17–1.21. JDK 25 cho 1.21+ (snapshot).";
    }
    if (section == RuntimeSectionLWJGL) {
        return @"LWJGL 3.3.3 cho bản cũ. 3.3.6 cho bản trung gian. 3.4.1 cho mới nhất (khuyến nghị).";
    }
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSArray *items = (indexPath.section == RuntimeSectionJDK) ? self.jdkItems : self.lwjglItems;
    WitchRuntimeItem *item = items[indexPath.row];
    [self showActionSheetForItem:item];
}

- (void)actionButtonTapped:(UIButton *)sender {
    NSString *identifier = sender.accessibilityIdentifier;
    WitchRuntimeItem *item = nil;
    for (WitchRuntimeItem *it in self.jdkItems) {
        if ([it.identifier isEqualToString:identifier]) { item = it; break; }
    }
    if (!item) {
        for (WitchRuntimeItem *it in self.lwjglItems) {
            if ([it.identifier isEqualToString:identifier]) { item = it; break; }
        }
    }
    if (item) {
        [self performActionForItem:item];
    }
}

- (void)showActionSheetForItem:(WitchRuntimeItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.displayName message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (item.installed && !item.updateAvailable) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self performDelete:item];
        }]];
    } else if (item.updateAvailable) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Cập nhật" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self performDownload:item];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Xóa bản cũ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self performDelete:item];
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"Tải về" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self performDownload:item];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performActionForItem:(WitchRuntimeItem *)item {
    if (item.installed && !item.updateAvailable) {
        [self performDelete:item];
    } else {
        [self performDownload:item];
    }
}

- (void)performDownload:(WitchRuntimeItem *)item {
    if (!item.remoteURL.length) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Không thể tải" message:@"Chưa có manifest runtimes.json trên JDK-Java_iOS (runtimes-latest). Hãy publish repo JDK trước, hoặc import tay file .tar.xz trong Manage Runtime." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIAlertController *prog = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Đang tải %@", item.displayName] message:@"Đang chuẩn bị..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:prog animated:YES completion:nil];
    
    [WitchRuntimeService.shared downloadItem:item progress:^(float p) {
        dispatch_async(dispatch_get_main_queue(), ^{
            prog.message = [NSString stringWithFormat:@"Đang tải... %.0f%%", p * 100];
        });
    } completion:^(BOOL ok, NSError *error) {
        [prog dismissViewControllerAnimated:YES completion:^{
            NSString *msg;
            if (ok) {
                msg = @"Đã tải xong và ghi nhận.\n• JDK: cần giải nén .tar.xz trong Manage Runtime (nếu chưa tự bung).\n• LWJGL: đã ghi marker, dùng ngay không cần restart.";
            } else {
                msg = [NSString stringWithFormat:@"Thất bại: %@", error.localizedDescription];
            }
            UIAlertController *done = [UIAlertController alertControllerWithTitle:item.displayName message:msg preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:done animated:YES completion:nil];
            [self reload];
        }];
    }];
}

- (void)performDelete:(WitchRuntimeItem *)item {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Xác nhận xóa" message:[NSString stringWithFormat:@"Bạn có chắc muốn xóa %@?", item.displayName] preferredStyle:UIAlertControllerStyleActionSheet];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        BOOL ok = [WitchRuntimeService.shared deleteItem:item error:&error];
        NSString *msg = ok ? @"Đã xóa." : [NSString stringWithFormat:@"Không xóa được: %@", error.localizedDescription];
        UIAlertController *done = [UIAlertController alertControllerWithTitle:item.displayName message:msg preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
        [self reload];
    }]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:confirm animated:YES completion:nil];
}

@end