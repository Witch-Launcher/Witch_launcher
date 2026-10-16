#import "RuntimeDownloadViewController.h"
#import "WitchRuntimeService.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "AppSheet.h"

typedef NS_ENUM(NSInteger, RuntimeSection) {
    RuntimeSectionJDK = 0,
    RuntimeSectionLWJGL,
    RuntimeSectionCount
};

@interface RuntimeItemCell : UITableViewCell
@property (nonatomic) UIView *dotView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UILabel *statusBadge;
@property (nonatomic) UILabel *sizeLabel;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic, copy) void(^onAction)(void);
@end

@implementation RuntimeItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.contentView.layer.cornerRadius = 14;
        self.contentView.clipsToBounds = YES;

        _dotView = [[UIView alloc] init];
        _dotView.translatesAutoresizingMaskIntoConstraints = NO;
        _dotView.layer.cornerRadius = 5;
        _dotView.clipsToBounds = YES;
        [self.contentView addSubview:_dotView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        [self.contentView addSubview:_nameLabel];

        _detailLabel = [[UILabel alloc] init];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_detailLabel];

        _statusBadge = [[UILabel alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _statusBadge.textColor = UIColor.whiteColor;
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 4;
        _statusBadge.clipsToBounds = YES;
        [self.contentView addSubview:_statusBadge];

        _sizeLabel = [[UILabel alloc] init];
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _sizeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _sizeLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _sizeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_sizeLabel];

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _actionButton.layer.cornerRadius = 8;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [_actionButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];

        // Fixed two-line layout: nothing overlaps, nothing clips.
        [NSLayoutConstraint activateConstraints:@[
            [_dotView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [_dotView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
            [_dotView.widthAnchor constraintEqualToConstant:10],
            [_dotView.heightAnchor constraintEqualToConstant:10],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_dotView.trailingAnchor constant:8],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_statusBadge.leadingAnchor constant:-8],

            [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3],
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],
            [_detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_statusBadge.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_statusBadge.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-8],
            [_statusBadge.heightAnchor constraintEqualToConstant:18],
            [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:56],

            [_sizeLabel.centerYAnchor constraintEqualToAnchor:_detailLabel.centerYAnchor],
            [_sizeLabel.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_actionButton.heightAnchor constraintEqualToConstant:32],
        ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.contentView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _sizeLabel.textColor = ThemeManager.shared.secondaryTextColor;
}

- (void)buttonTapped {
    if (_onAction) _onAction();
}

- (void)configureWithItem:(WitchRuntimeItem *)item {
    _nameLabel.text = item.displayName;
    // Important marker as a colored dot (no emoji).
    _dotView.backgroundColor = (item.important && !item.installed) ? ThemeManager.shared.errorColor : [UIColor clearColor];

    NSMutableArray *parts = [NSMutableArray array];
    if (item.installed) {
        [parts addObject:[NSString stringWithFormat:@"Đã cài%@", item.localVersion.length > 0 ? [@" • " stringByAppendingString:item.localVersion] : @""]];
        if (item.updateAvailable && item.remoteVersion.length > 0) {
            [parts addObject:[NSString stringWithFormat:@"Có update (%@)", item.remoteVersion]];
        }
    } else {
        [parts addObject:item.remoteVersion.length > 0 ? [NSString stringWithFormat:@"Chưa cài • Mới: %@", item.remoteVersion] : @"Chưa cài"];
    }
    _detailLabel.text = [parts componentsJoinedByString:@"  •  "];
    _detailLabel.textColor = (item.important && !item.installed) ? ThemeManager.shared.errorColor : ThemeManager.shared.secondaryTextColor;

    if (item.installed) {
        if (item.updateAvailable) {
            _statusBadge.text = @"  Cập nhật  ";
            _statusBadge.backgroundColor = ThemeManager.shared.warningColor;
        } else {
            _statusBadge.text = @"  Đã cài  ";
            _statusBadge.backgroundColor = ThemeManager.shared.successColor;
        }
    } else {
        _statusBadge.text = @"  Chưa cài  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
    }
    _sizeLabel.text = item.remoteSize > 0 ? [NSByteCountFormatter stringFromByteCount:item.remoteSize countStyle:NSByteCountFormatterCountStyleMemory] : @"";

    NSString *action = (item.installed && !item.updateAvailable) ? @"Xóa" : (item.updateAvailable ? @"Cập nhật" : @"Tải");
    [_actionButton setTitle:action forState:UIControlStateNormal];
    [_actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _actionButton.backgroundColor = ([action isEqualToString:@"Xóa"] ? ThemeManager.shared.errorColor : ThemeManager.shared.accentColor);
    [_actionButton setTitleColor:ThemeManager.shared.buttonTextColor forState:UIControlStateNormal];
    BOOL enabled = item.remoteURL.length > 0 || item.installed;
    _actionButton.enabled = enabled;
    _actionButton.alpha = enabled ? 1.0 : 0.5;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _onAction = nil;
    _nameLabel.text = nil;
    _detailLabel.text = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@interface RuntimeDownloadViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray<WitchRuntimeItem *> *jdkItems;
@property (nonatomic) NSArray<WitchRuntimeItem *> *lwjglItems;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) BOOL isLoading;
@property (nonatomic) BOOL isWorking;
@end

@implementation RuntimeDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.onboardingMode ? @"Tải Runtime" : @"Runtime JDK / LWJGL";
    [AmethystBlurView installInView:self.view];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 76;
    _tableView.alwaysBounceVertical = YES;
    [_tableView registerClass:[RuntimeItemCell class] forCellReuseIdentifier:@"RuntimeItemCell"];
    [self.view addSubview:_tableView];

    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    [rc addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = rc;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    // Header as section 0 content (plain label row) + footer note.
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];

    if (self.onboardingMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Bỏ qua" style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    }
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    self.navigationItem.leftBarButtonItem = refresh;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self reload];
}

- (void)onTheme {
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [_tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reload {
    if (self.isLoading) return;
    self.isLoading = YES;
    [_spinner startAnimating];
    _emptyLabel.hidden = YES;
    __weak typeof(self) weakSelf = self;
    [WitchRuntimeService.shared refreshStatuses:^(NSArray<WitchRuntimeItem *> *items, NSError *error) {
        weakSelf.isLoading = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.spinner stopAnimating];
            [weakSelf.tableView.refreshControl endRefreshing];
            if (error && items.count == 0) {
                weakSelf.emptyLabel.hidden = NO;
                weakSelf.emptyLabel.text = [NSString stringWithFormat:@"Không tải được manifest.\n%@", error.localizedDescription];
                return;
            }
            if (error) [ErrorPresenter showNetworkError:error message:@"Dùng cache local (không tải được manifest)."];
            NSMutableArray *jdk = [NSMutableArray array];
            NSMutableArray *lwjgl = [NSMutableArray array];
            for (WitchRuntimeItem *it in items) {
                if (it.kind == WitchRuntimeKindJDK) [jdk addObject:it];
                else [lwjgl addObject:it];
            }
            weakSelf.jdkItems = jdk;
            weakSelf.lwjglItems = lwjgl;
            [weakSelf.tableView reloadData];
        });
    }];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return RuntimeSectionCount + 1; // +1 intro section
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return self.jdkItems.count;
    return self.lwjglItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return @"Java Development Kit (JDK)";
    if (section == 2) return @"LWJGL (Java Game Library)";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"JDK 8 cho Minecraft ≤ 1.16.5 • 17/21 cho 1.17 – 1.21 • 25 cho bản mới.";
    if (section == 2) return @"3.3.3 cho bản cũ • 3.3.6 trung gian • 3.4.1 mới nhất.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.layer.cornerRadius = 14;
        cell.clipsToBounds = YES;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.text = self.onboardingMode
            ? @"Bản Simple không kèm sẵn JDK/LWJGL. Chấm đỏ = quan trọng. Bấm Tải rồi dùng."
            : @"Chấm đỏ = khuyến nghị tải. Bấm vào dòng để Tải / Cập nhật / Xóa.";
        return cell;
    }
    RuntimeItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RuntimeItemCell" forIndexPath:indexPath];
    NSArray *items = (indexPath.section == 1) ? self.jdkItems : self.lwjglItems;
    WitchRuntimeItem *item = items[indexPath.row];
    [cell configureWithItem:item];
    __weak typeof(self) weakSelf = self;
    cell.onAction = ^{
        [weakSelf performActionForItem:item];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    NSArray *items = (indexPath.section == 1) ? self.jdkItems : self.lwjglItems;
    [self showActionSheetForItem:items[indexPath.row]];
}

- (void)showActionSheetForItem:(WitchRuntimeItem *)item {
    NSMutableArray *opts = [NSMutableArray array];
    if (item.installed && !item.updateAvailable) {
        [opts addObject:@{@"title": @"Xóa", @"icon": @"trash", @"destructive": @YES}];
    } else {
        if (item.updateAvailable) [opts addObject:@{@"title": @"Cập nhật", @"icon": @"arrow.triangle.2.circlepath"}];
        else [opts addObject:@{@"title": @"Tải về", @"icon": @"tray.and.arrow.down"}];
        if (item.installed) [opts addObject:@{@"title": @"Xóa bản cũ", @"icon": @"trash", @"destructive": @YES}];
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:item.displayName message:nil options:opts selectedIndex:NSNotFound selection:^(NSInteger idx) {
        NSString *t = opts[idx][@"title"];
        if ([t isEqualToString:@"Xóa"] || [t isEqualToString:@"Xóa bản cũ"]) [weakSelf confirmDelete:item];
        else [weakSelf performDownload:item];
    }];
}

- (void)performActionForItem:(WitchRuntimeItem *)item {
    if (item.installed && !item.updateAvailable) [self confirmDelete:item];
    else [self performDownload:item];
}

- (void)performDownload:(WitchRuntimeItem *)item {
    if (!item.remoteURL.length) {
        [ErrorPresenter showInfo:@"Không thể tải" message:@"Chưa có manifest runtimes.json. Hãy publish repo JDK trước, hoặc import tay file .tar.xz trong Manage Runtime."];
        return;
    }
    if (_isWorking) return;
    _isWorking = YES;
    [ErrorPresenter showToast:[NSString stringWithFormat:@"Đang tải %@…", item.displayName] success:YES];
    __weak typeof(self) weakSelf = self;
    [WitchRuntimeService.shared downloadItem:item progress:nil completion:^(BOOL ok, NSError *error) {
        weakSelf.isWorking = NO;
        if (ok) {
            [ErrorPresenter showToast:@"Đã tải xong." success:YES];
        } else {
            [ErrorPresenter showNetworkError:error message:@"Tải thất bại."];
        }
        [weakSelf reload];
    }];
}

- (void)confirmDelete:(WitchRuntimeItem *)item {
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:@"Xác nhận xóa" message:[NSString stringWithFormat:@"Bạn có chắc muốn xóa %@?", item.displayName] confirmTitle:@"Xóa" destructive:YES onConfirm:^{
        NSError *error = nil;
        BOOL ok = [WitchRuntimeService.shared deleteItem:item error:&error];
        if (ok) [ErrorPresenter showToast:@"Đã xóa." success:YES];
        else [ErrorPresenter showFileError:@"Xóa" path:item.displayName error:error];
        [weakSelf reload];
    }];
}

@end
