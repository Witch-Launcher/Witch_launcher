#import "RuntimeDownloadViewController.h"
#import "WitchRuntimeService.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "AppSheet.h"
#import "utils.h"

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
        _nameLabel.numberOfLines = 1;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [self.contentView addSubview:_nameLabel];

        _detailLabel = [[UILabel alloc] init];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _detailLabel.numberOfLines = 1;
        _detailLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_detailLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [self.contentView addSubview:_detailLabel];

        _statusBadge = [[UILabel alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _statusBadge.textColor = UIColor.whiteColor;
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 4;
        _statusBadge.clipsToBounds = YES;
        _statusBadge.numberOfLines = 1;
        _statusBadge.adjustsFontSizeToFitWidth = YES;
        _statusBadge.minimumScaleFactor = 0.85;
        [_statusBadge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_statusBadge setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
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
        _actionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        _actionButton.titleLabel.minimumScaleFactor = 0.85;
        _actionButton.layer.cornerRadius = 8;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [_actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_actionButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];

        // Fixed two-line layout: badge (64) and action button (88) never
        // shrink — long names/details truncate instead. Every row is the
        // same height with the same two lines.
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
            [_statusBadge.widthAnchor constraintEqualToConstant:64],

            [_sizeLabel.centerYAnchor constraintEqualToAnchor:_detailLabel.centerYAnchor],
            [_sizeLabel.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_actionButton.heightAnchor constraintEqualToConstant:32],
            [_actionButton.widthAnchor constraintEqualToConstant:88],
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
        if (item.localVersion.length > 0) {
            [parts addObject:[NSString stringWithFormat:localize(@"runtime.detail.installed_version", nil), item.localVersion]];
        } else {
            [parts addObject:localize(@"runtime.status.installed", nil)];
        }
        if (item.updateAvailable && item.remoteVersion.length > 0) {
            [parts addObject:[NSString stringWithFormat:localize(@"runtime.detail.update_available", nil), item.remoteVersion]];
        }
    } else {
        [parts addObject:item.remoteVersion.length > 0
            ? [NSString stringWithFormat:localize(@"runtime.detail.not_installed_new", nil), item.remoteVersion]
            : localize(@"runtime.status.not_installed", nil)];
    }
    _detailLabel.text = [parts componentsJoinedByString:@"  •  "];
    _detailLabel.textColor = (item.important && !item.installed) ? ThemeManager.shared.errorColor : ThemeManager.shared.secondaryTextColor;

    if (item.installed) {
        if (item.updateAvailable) {
            _statusBadge.text = localize(@"runtime.status.update_available", nil);
            _statusBadge.backgroundColor = ThemeManager.shared.warningColor;
        } else {
            _statusBadge.text = localize(@"runtime.status.installed", nil);
            _statusBadge.backgroundColor = ThemeManager.shared.successColor;
        }
    } else {
        _statusBadge.text = localize(@"runtime.status.not_installed", nil);
        _statusBadge.backgroundColor = [UIColor grayColor];
    }
    _statusBadge.textColor = [ThemeManager.shared contrastTextColorForBackground:_statusBadge.backgroundColor];
    _sizeLabel.text = item.remoteSize > 0 ? [NSByteCountFormatter stringFromByteCount:item.remoteSize countStyle:NSByteCountFormatterCountStyleMemory] : @"";

    BOOL isDelete = item.installed && !item.updateAvailable;
    NSString *action = isDelete ? localize(@"runtime.action.delete", nil)
        : (item.updateAvailable ? localize(@"runtime.action.update", nil) : localize(@"runtime.action.download", nil));
    UIColor *actionBg = isDelete ? ThemeManager.shared.errorColor : ThemeManager.shared.accentColor;
    [_actionButton setTitle:action forState:UIControlStateNormal];
    [_actionButton setTitleColor:[ThemeManager.shared contrastTextColorForBackground:actionBg] forState:UIControlStateNormal];
    _actionButton.backgroundColor = actionBg;
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
@property (nonatomic) UIView *installPanel;
@property (nonatomic) UIImageView *installIconView;
@property (nonatomic) UILabel *installTitleLabel;
@property (nonatomic) UILabel *installStatusLabel;
@property (nonatomic) UIProgressView *installProgressView;
@end

@implementation RuntimeDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.onboardingMode ? localize(@"runtime.title.onboarding", nil) : localize(@"runtime.title.manage", nil);
    // Opaque base under the frost: without this the previous screen shows
    // through the pushed page.
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 80;
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

    [self buildInstallPanel];

    if (self.onboardingMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"runtime.skip", nil) style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    }
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    self.navigationItem.leftBarButtonItem = refresh;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self reload];
}

// Thẻ tiến trình nổi ở đáy: tải → giải nén → đăng ký, hiện cả trạng thái lẫn %.
- (void)buildInstallPanel {
    _installPanel = [[UIView alloc] init];
    _installPanel.translatesAutoresizingMaskIntoConstraints = NO;
    _installPanel.layer.cornerRadius = 14;
    _installPanel.clipsToBounds = YES;
    _installPanel.hidden = YES;
    [self.view addSubview:_installPanel];

    _installIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle"]];
    _installIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _installIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_installPanel addSubview:_installIconView];

    _installTitleLabel = [[UILabel alloc] init];
    _installTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _installTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _installTitleLabel.numberOfLines = 1;
    _installTitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_installPanel addSubview:_installTitleLabel];

    _installStatusLabel = [[UILabel alloc] init];
    _installStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _installStatusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _installStatusLabel.numberOfLines = 1;
    _installStatusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_installPanel addSubview:_installStatusLabel];

    _installProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _installProgressView.translatesAutoresizingMaskIntoConstraints = NO;
    [_installPanel addSubview:_installProgressView];

    [NSLayoutConstraint activateConstraints:@[
        [_installPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_installPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_installPanel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],

        [_installIconView.leadingAnchor constraintEqualToAnchor:_installPanel.leadingAnchor constant:14],
        [_installIconView.centerYAnchor constraintEqualToAnchor:_installPanel.centerYAnchor],
        [_installIconView.widthAnchor constraintEqualToConstant:28],
        [_installIconView.heightAnchor constraintEqualToConstant:28],

        [_installTitleLabel.topAnchor constraintEqualToAnchor:_installPanel.topAnchor constant:10],
        [_installTitleLabel.leadingAnchor constraintEqualToAnchor:_installIconView.trailingAnchor constant:10],
        [_installTitleLabel.trailingAnchor constraintEqualToAnchor:_installPanel.trailingAnchor constant:-14],

        [_installStatusLabel.topAnchor constraintEqualToAnchor:_installTitleLabel.bottomAnchor constant:2],
        [_installStatusLabel.leadingAnchor constraintEqualToAnchor:_installTitleLabel.leadingAnchor],
        [_installStatusLabel.trailingAnchor constraintEqualToAnchor:_installTitleLabel.trailingAnchor],

        [_installProgressView.topAnchor constraintEqualToAnchor:_installStatusLabel.bottomAnchor constant:8],
        [_installProgressView.leadingAnchor constraintEqualToAnchor:_installTitleLabel.leadingAnchor],
        [_installProgressView.trailingAnchor constraintEqualToAnchor:_installTitleLabel.trailingAnchor],
        [_installProgressView.heightAnchor constraintEqualToConstant:4],
        [_installProgressView.bottomAnchor constraintEqualToAnchor:_installPanel.bottomAnchor constant:-12],
    ]];
    [self applyPanelTheme];
}

- (void)applyPanelTheme {
    _installPanel.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _installIconView.tintColor = ThemeManager.shared.accentColor;
    _installTitleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _installStatusLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _installProgressView.progressTintColor = ThemeManager.shared.accentColor;
    _installProgressView.trackTintColor = [ThemeManager.shared.secondaryTextColor colorWithAlphaComponent:0.25];
}

- (void)setWorkingUI:(BOOL)working {
    _installPanel.hidden = !working;
    _tableView.userInteractionEnabled = !working;
    self.navigationItem.leftBarButtonItem.enabled = !working;
    self.navigationItem.rightBarButtonItem.enabled = !working;
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    [self applyPanelTheme];
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
                weakSelf.emptyLabel.text = [NSString stringWithFormat:localize(@"runtime.manifest_load_failed", nil), error.localizedDescription];
                return;
            }
            if (error) [ErrorPresenter showNetworkError:error message:localize(@"runtime.manifest_cache_fallback", nil)];
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
    if (section == 1) return localize(@"runtime.jdk_footer", nil);
    if (section == 2) return localize(@"runtime.lwjgl_footer", nil);
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
            ? localize(@"runtime.onboarding_hint", nil)
            : localize(@"runtime.list_hint", nil);
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
    if (_isWorking) return;
    NSMutableArray *opts = [NSMutableArray array];
    if (item.installed && !item.updateAvailable) {
        [opts addObject:@{@"key": @"delete", @"title": localize(@"runtime.action.delete", nil), @"icon": @"trash", @"destructive": @YES}];
    } else {
        if (item.updateAvailable) [opts addObject:@{@"key": @"update", @"title": localize(@"runtime.action.update", nil), @"icon": @"arrow.triangle.2.circlepath"}];
        else [opts addObject:@{@"key": @"download", @"title": localize(@"runtime.action.download", nil), @"icon": @"tray.and.arrow.down"}];
        if (item.installed) [opts addObject:@{@"key": @"delete_old", @"title": localize(@"runtime.action.delete_old", nil), @"icon": @"trash", @"destructive": @YES}];
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showOptionsWithTitle:item.displayName message:nil options:opts selectedIndex:NSNotFound selection:^(NSInteger idx) {
        NSString *action = opts[idx][@"key"];
        if ([action isEqualToString:@"delete"] || [action isEqualToString:@"delete_old"]) [weakSelf confirmDelete:item];
        else [weakSelf performDownload:item];
    }];
}

- (void)performActionForItem:(WitchRuntimeItem *)item {
    if (_isWorking) return;
    if (item.installed && !item.updateAvailable) [self confirmDelete:item];
    else [self performDownload:item];
}

- (void)performDownload:(WitchRuntimeItem *)item {
    if (!item.remoteURL.length) {
        [ErrorPresenter showInfo:localize(@"runtime.title_cannot_download", nil) message:localize(@"runtime.error_no_manifest", nil)];
        return;
    }
    if (_isWorking) return;
    _isWorking = YES;

    // Thẻ cài đặt: tải (thanh chạy) → giải nén → đăng ký xong mới ẩn.
    _installTitleLabel.text = item.displayName;
    _installStatusLabel.text = @"";
    _installProgressView.progress = 0.0f;
    [self setWorkingUI:YES];

    __weak typeof(self) weakSelf = self;
    [WitchRuntimeService.shared downloadItem:item progress:^(float fraction, NSString *status) {
        typeof(self) s = weakSelf; if (!s) return;
        float clamped = MAX(0.0f, MIN(fraction, 1.0f));
        s.installProgressView.progress = clamped;
        s.installStatusLabel.text = [NSString stringWithFormat:@"%@  %d%%", status, (int)roundf(clamped * 100.0f)];
    } completion:^(BOOL ok, NSError *error) {
        typeof(self) s = weakSelf; if (!s) return;
        s.isWorking = NO;
        [s setWorkingUI:NO];
        if (ok) {
            [ErrorPresenter showToast:localize(@"runtime.installed_toast", nil) success:YES];
        } else {
            [ErrorPresenter showNetworkError:error message:localize(@"runtime.install_failed_toast", nil)];
        }
        [s reload];
    }];
}

- (void)confirmDelete:(WitchRuntimeItem *)item {
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:localize(@"runtime.delete.title", nil) message:[NSString stringWithFormat:localize(@"runtime.delete.message", nil), item.displayName] confirmTitle:localize(@"runtime.action.delete", nil) destructive:YES onConfirm:^{
        NSError *error = nil;
        BOOL ok = [WitchRuntimeService.shared deleteItem:item error:&error];
        if (ok) [ErrorPresenter showToast:localize(@"runtime.deleted", nil) success:YES];
        else [ErrorPresenter showFileError:localize(@"runtime.action.delete", nil) path:item.displayName error:error];
        [weakSelf reload];
    }];
}

@end
