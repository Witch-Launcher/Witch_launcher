#import "DownloadTasksViewController.h"
#import "ThemeManager.h"
#import "DownloadManager.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "MinecraftResourceDownloadTask.h"
#import "utils.h"

typedef NS_ENUM(NSInteger, DownloadRowState) {
    DownloadRowStateActive,
    DownloadRowStateDone,
    DownloadRowStateFailed,
    DownloadRowStateCancelled
};

@interface DownloadTaskRow : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *iconName;
@property (nonatomic) float progress;
@property (nonatomic) double bytesPerSecond;
@property (nonatomic) DownloadRowState state;
@property (nonatomic, weak) DownloadTask *task;
@end

@implementation DownloadTaskRow
@end

static NSString * const kTaskCellId = @"DownloadTaskCell";

@interface DownloadTasksCell : UITableViewCell
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UIProgressView *progressBar;
@property (nonatomic) UILabel *percentLabel;
@property (nonatomic) UILabel *speedLabel;
@property (nonatomic) UIButton *cancelBtn;
@property (nonatomic, copy) void (^cancelHandler)(void);
@end

@implementation DownloadTasksCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = ThemeManager.shared.accentColor;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_nameLabel];

        _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        _progressBar.progressTintColor = ThemeManager.shared.accentColor;
        _progressBar.trackTintColor = ThemeManager.shared.separatorColor;
        _progressBar.layer.cornerRadius = 2;
        _progressBar.clipsToBounds = YES;
        [self.contentView addSubview:_progressBar];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _percentLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
        _percentLabel.textColor = ThemeManager.shared.accentColor;
        _percentLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_percentLabel];

        _speedLabel = [[UILabel alloc] init];
        _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _speedLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
        _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _speedLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_speedLabel];

        _cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_cancelBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        _cancelBtn.tintColor = ThemeManager.shared.errorColor;
        [_cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_cancelBtn];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_iconView.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:28],
            [_iconView.heightAnchor constraintEqualToConstant:28],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:10],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_cancelBtn.leadingAnchor constant:-8],

            [_cancelBtn.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_cancelBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_cancelBtn.widthAnchor constraintEqualToConstant:26],
            [_cancelBtn.heightAnchor constraintEqualToConstant:26],

            [_progressBar.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:10],
            [_progressBar.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_progressBar.trailingAnchor constraintEqualToAnchor:_percentLabel.leadingAnchor constant:-8],
            [_progressBar.heightAnchor constraintEqualToConstant:5],

            [_percentLabel.centerYAnchor constraintEqualToAnchor:_progressBar.centerYAnchor],
            [_percentLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_percentLabel.widthAnchor constraintEqualToConstant:42],

            [_speedLabel.topAnchor constraintEqualToAnchor:_progressBar.bottomAnchor constant:5],
            [_speedLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_speedLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _progressBar.progressTintColor = ThemeManager.shared.accentColor;
    _progressBar.trackTintColor = ThemeManager.shared.separatorColor;
    _percentLabel.textColor = ThemeManager.shared.accentColor;
    _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _cancelBtn.tintColor = ThemeManager.shared.errorColor;
    _iconView.tintColor = ThemeManager.shared.accentColor;
}

- (void)configureWithRow:(DownloadTaskRow *)row {
    ThemeManager *theme = ThemeManager.shared;
    _iconView.image = [UIImage systemImageNamed:row.iconName ?: @"doc"];
    _nameLabel.text = row.name;
    _progressBar.progress = row.progress;
    _percentLabel.text = [NSString stringWithFormat:@"%d%%", (int)(row.progress * 100)];
    _progressBar.progressTintColor = theme.accentColor;
    _percentLabel.textColor = theme.accentColor;
    _speedLabel.textColor = theme.secondaryTextColor;

    switch (row.state) {
        case DownloadRowStateDone:
            _progressBar.progressTintColor = theme.successColor;
            _percentLabel.textColor = theme.successColor;
            _speedLabel.text = localize(@"Completed", nil);
            _speedLabel.textColor = theme.successColor;
            _cancelBtn.hidden = YES;
            break;
        case DownloadRowStateFailed:
            _progressBar.progressTintColor = theme.errorColor;
            _percentLabel.textColor = theme.errorColor;
            _speedLabel.text = localize(@"Failed", nil);
            _speedLabel.textColor = theme.errorColor;
            _cancelBtn.hidden = YES;
            break;
        case DownloadRowStateCancelled:
            _progressBar.progressTintColor = theme.warningColor;
            _percentLabel.textColor = theme.warningColor;
            _speedLabel.text = localize(@"Cancelled", nil);
            _speedLabel.textColor = theme.warningColor;
            _cancelBtn.hidden = YES;
            break;
        default:
            _speedLabel.text = [self formatSpeed:row.bytesPerSecond];
            _cancelBtn.hidden = row.task == nil;
            break;
    }
}

- (NSString *)formatSpeed:(double)bytesPerSecond {
    if (bytesPerSecond >= 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB/s", bytesPerSecond / (1024.0 * 1024.0)];
    } else if (bytesPerSecond >= 1024) {
        return [NSString stringWithFormat:@"%.0f KB/s", bytesPerSecond / 1024.0];
    } else if (bytesPerSecond > 0) {
        return [NSString stringWithFormat:@"%.0f B/s", bytesPerSecond];
    }
    return nil;
}

- (void)cancelTapped {
    if (self.cancelHandler) self.cancelHandler();
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _cancelHandler = nil;
    _cancelBtn.hidden = NO;
    _speedLabel.text = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#pragma mark - View Controller

@interface DownloadTasksViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) NSArray<DownloadTaskRow *> *rows;
@property (nonatomic) MinecraftResourceDownloadTask *launchTask;
@property (nonatomic) BOOL isLaunchMode;
@property (nonatomic) NSTimer *refreshTimer;
@end

@implementation DownloadTasksViewController

- (instancetype)initWithHubTasks {
    self = [super init];
    if (self) {
        _isLaunchMode = NO;
    }
    return self;
}

- (instancetype)initWithLaunchTask:(MinecraftResourceDownloadTask *)launchTask {
    self = [super init];
    if (self) {
        _isLaunchMode = YES;
        _launchTask = launchTask;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = localize(@"Downloads", nil);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped)];
    if (!_isLaunchMode) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Cancel All", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelAllTapped)];
    }

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 76;
    _tableView.contentInset = UIEdgeInsetsMake(8, 16, 16, 16);
    [_tableView registerClass:[DownloadTasksCell class] forCellReuseIdentifier:kTaskCellId];
    [self.view addSubview:_tableView];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.text = localize(@"No downloads", nil);
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadRows) name:DownloadTasksDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [AmethystBlurView installInView:self.view];
    [self updateColors];
    [self reloadRows];

    __weak typeof(self) weakSelf = self;
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf reloadRows];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadRows];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
}

- (void)reloadRows {
    if (_isLaunchMode) {
        _rows = [self launchRows];
    } else {
        _rows = [self hubRows];
    }
    _emptyLabel.hidden = _rows.count > 0;
    _tableView.hidden = _rows.count == 0;
    [_tableView reloadData];
    if (!_isLaunchMode) {
        BOOL hasActive = [DownloadManager.shared activeTasks].count > 0;
        self.navigationItem.leftBarButtonItem.enabled = hasActive;
    }
}

- (NSArray<DownloadTaskRow *> *)hubRows {
    NSMutableArray *rows = [NSMutableArray array];
    for (DownloadTask *task in [DownloadManager.shared allTasks]) {
        DownloadTaskRow *row = [[DownloadTaskRow alloc] init];
        row.name = task.name;
        row.iconName = [self iconNameForType:task.type];
        row.progress = task.progress;
        row.bytesPerSecond = task.bytesPerSecond;
        row.task = task;
        if (task.cancelled) row.state = DownloadRowStateCancelled;
        else if (task.isFinished && task.error) row.state = DownloadRowStateFailed;
        else if (task.isFinished) row.state = DownloadRowStateDone;
        else row.state = DownloadRowStateActive;
        if (row.state == DownloadRowStateDone) row.progress = 1.0f;
        [rows addObject:row];
    }
    return rows;
}

- (NSArray<DownloadTaskRow *> *)launchRows {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSProgress *p in [_launchTask.progressList copy]) {
        if (![p isKindOfClass:[NSProgress class]]) continue;
        DownloadTaskRow *row = [[DownloadTaskRow alloc] init];
        NSString *name = p.localizedDescription;
        if (![name isKindOfClass:[NSString class]] || name.length == 0) {
            name = p.localizedAdditionalDescription ?: @"file";
        }
        row.name = name;
        row.iconName = @"doc";
        row.progress = (float)MAX(0.0, MIN(p.fractionCompleted, 1.0));
        row.bytesPerSecond = 0;
        row.state = (p.fractionCompleted >= 1.0 || p.finished) ? DownloadRowStateDone : DownloadRowStateActive;
        if (row.state == DownloadRowStateDone) row.progress = 1.0f;
        [rows addObject:row];
    }
    return rows;
}

- (NSString *)iconNameForType:(DownloadType)type {
    switch (type) {
        case DownloadTypeShader: return @"paintpalette";
        case DownloadTypeResourcePack: return @"paintbrush.fill";
        case DownloadTypeMap: return @"map";
        case DownloadTypeServer: return @"server.rack";
        case DownloadTypeModpack: return @"shippingbox.fill";
        case DownloadTypeLaunch: return @"play.circle.fill";
        default: return @"puzzlepiece.extension";
    }
}

- (void)doneTapped {
    [HapticManager.shared play:HapticTypeLight];
    if (!_isLaunchMode && [DownloadManager.shared activeTasks].count == 0) {
        [DownloadManager.shared clearFinishedTasks];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelAllTapped {
    [HapticManager.shared play:HapticTypeMedium];
    [DownloadManager.shared cancelAllTasks];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DownloadTasksCell *cell = [tableView dequeueReusableCellWithIdentifier:kTaskCellId forIndexPath:indexPath];
    DownloadTaskRow *row = _rows[indexPath.row];
    [cell configureWithRow:row];
    if (row.task) {
        __weak typeof(self) weakSelf = self;
        DownloadTask *task = row.task;
        cell.cancelHandler = ^{
            [DownloadManager.shared cancelTask:task];
            [weakSelf reloadRows];
        };
    }
    return cell;
}

- (void)dealloc {
    [_refreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
