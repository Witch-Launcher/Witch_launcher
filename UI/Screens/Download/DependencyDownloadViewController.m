#import "DependencyDownloadViewController.h"
#import "ThemeManager.h"
#import "DownloadManager.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "UIImageView+AFNetworking.h"
#import "utils.h"

static NSString * const kDownloadCell = @"DependencyDownloadCell";

@interface DependencyDownloadCell : UITableViewCell
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UIProgressView *progressBar;
@property (nonatomic) UILabel *progressLabel;
@property (nonatomic) UILabel *speedLabel;
@property (nonatomic) UIButton *cancelBtn;
@property (nonatomic) UIView *statusBadge;
@property (nonatomic) UILabel *statusLabel;
@end

@implementation DependencyDownloadCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;
        
        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 8;
        _iconView.backgroundColor = ThemeManager.shared.separatorColor;
        _iconView.image = [UIImage systemImageNamed:@"puzzlepiece.extension"];
        _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_iconView];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        _nameLabel.numberOfLines = 1;
        [self.contentView addSubview:_nameLabel];
        
        _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        _progressBar.progressTintColor = ThemeManager.shared.accentColor;
        _progressBar.trackTintColor = ThemeManager.shared.separatorColor;
        _progressBar.layer.cornerRadius = 2;
        _progressBar.clipsToBounds = YES;
        _progressBar.progress = 0;
        [self.contentView addSubview:_progressBar];
        
        _progressLabel = [[UILabel alloc] init];
        _progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _progressLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
        _progressLabel.textColor = ThemeManager.shared.accentColor;
        _progressLabel.textAlignment = NSTextAlignmentRight;
        _progressLabel.text = @"0%";
        [self.contentView addSubview:_progressLabel];
        
        _speedLabel = [[UILabel alloc] init];
        _speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _speedLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
        _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _speedLabel.textAlignment = NSTextAlignmentRight;
        _speedLabel.text = @"--";
        [self.contentView addSubview:_speedLabel];
        
        _cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_cancelBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        _cancelBtn.tintColor = ThemeManager.shared.errorColor;
        [_cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_cancelBtn];
        
        _statusBadge = [[UIView alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.layer.cornerRadius = 4;
        _statusBadge.clipsToBounds = YES;
        _statusBadge.hidden = YES;
        [self.contentView addSubview:_statusBadge];
        
        _statusLabel = [[UILabel alloc] init];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        [_statusBadge addSubview:_statusLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_iconView.widthAnchor constraintEqualToConstant:40],
            [_iconView.heightAnchor constraintEqualToConstant:40],
            
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_cancelBtn.leadingAnchor constant:-8],
            
            [_progressBar.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:8],
            [_progressBar.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_progressBar.trailingAnchor constraintEqualToAnchor:_progressLabel.leadingAnchor constant:-8],
            [_progressBar.heightAnchor constraintEqualToConstant:6],
            
            [_progressLabel.centerYAnchor constraintEqualToAnchor:_progressBar.centerYAnchor],
            [_progressLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_progressLabel.widthAnchor constraintEqualToConstant:45],
            
            [_speedLabel.topAnchor constraintEqualToAnchor:_progressBar.bottomAnchor constant:4],
            [_speedLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_speedLabel.widthAnchor constraintEqualToConstant:70],
            [_speedLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            
            [_cancelBtn.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [_cancelBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_cancelBtn.widthAnchor constraintEqualToConstant:24],
            [_cancelBtn.heightAnchor constraintEqualToConstant:24],
            
            [_statusBadge.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_statusBadge.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_statusBadge.heightAnchor constraintEqualToConstant:18],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusBadge.leadingAnchor constant:6],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_statusBadge.trailingAnchor constant:-6],
            [_statusLabel.centerYAnchor constraintEqualToAnchor:_statusBadge.centerYAnchor],
        ]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _iconView.backgroundColor = ThemeManager.shared.separatorColor;
    _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _progressBar.progressTintColor = ThemeManager.shared.accentColor;
    _progressBar.trackTintColor = ThemeManager.shared.separatorColor;
    _progressLabel.textColor = ThemeManager.shared.accentColor;
    _speedLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _cancelBtn.tintColor = ThemeManager.shared.errorColor;
}

- (void)configureWithTask:(DownloadTask *)task isMain:(BOOL)isMain {
    _nameLabel.text = task.name;
    _progressBar.progress = task.progress;
    _progressLabel.text = [NSString stringWithFormat:@"%d%%", (int)(task.progress * 100)];
    
    if (task.averageSpeed > 0) {
        _speedLabel.text = [self formatSpeed:task.averageSpeed];
    } else if (task.progress > 0 && task.progress < 1.0) {
        _speedLabel.text = localize(@"Calculating...", nil);
    } else {
        _speedLabel.text = @"--";
    }
    
    if (task.isFinished) {
        if (task.error) {
            _statusBadge.hidden = NO;
            _statusBadge.backgroundColor = ThemeManager.shared.errorColor;
            _statusLabel.text = localize(@"Failed", nil);
            _cancelBtn.hidden = YES;
            _progressBar.progressTintColor = ThemeManager.shared.errorColor;
        } else {
            _statusBadge.hidden = NO;
            _statusBadge.backgroundColor = ThemeManager.shared.successColor;
            _statusLabel.text = localize(@"Completed", nil);
            _cancelBtn.hidden = YES;
            _progressBar.progressTintColor = ThemeManager.shared.successColor;
        }
    } else if (task.cancelled) {
        _statusBadge.hidden = NO;
        _statusBadge.backgroundColor = ThemeManager.shared.warningColor;
        _statusLabel.text = localize(@"Cancelled", nil);
        _cancelBtn.hidden = YES;
    } else {
        _statusBadge.hidden = YES;
        _cancelBtn.hidden = NO;
    }
    
    if (isMain) {
        _iconView.layer.borderWidth = 2;
        _iconView.layer.borderColor = ThemeManager.shared.accentColor.CGColor;
    } else {
        _iconView.layer.borderWidth = 0;
    }
}

- (void)updateProgress:(float)progress speed:(double)speed finished:(BOOL)finished error:(NSError *)error {
    _progressBar.progress = progress;
    _progressLabel.text = [NSString stringWithFormat:@"%d%%", (int)(progress * 100)];
    
    if (speed > 0) {
        _speedLabel.text = [self formatSpeed:speed];
    }
    
    if (finished) {
        _cancelBtn.hidden = YES;
        _statusBadge.hidden = NO;
        if (error) {
            _statusBadge.backgroundColor = ThemeManager.shared.errorColor;
            _statusLabel.text = localize(@"Failed", nil);
            _progressBar.progressTintColor = ThemeManager.shared.errorColor;
        } else {
            _statusBadge.backgroundColor = ThemeManager.shared.successColor;
            _statusLabel.text = localize(@"Completed", nil);
            _progressBar.progressTintColor = ThemeManager.shared.successColor;
        }
    }
}

- (NSString *)formatSpeed:(double)bytesPerSecond {
    if (bytesPerSecond >= 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB/s", bytesPerSecond / (1024.0 * 1024.0)];
    } else if (bytesPerSecond >= 1024) {
        return [NSString stringWithFormat:@"%.1f KB/s", bytesPerSecond / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.0f B/s", bytesPerSecond];
    }
}

- (void)cancelTapped {
    // Handled by parent VC via delegate pattern
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _iconView.image = nil;
    _iconView.layer.borderWidth = 0;
    _nameLabel.text = nil;
    _progressBar.progress = 0;
    _progressLabel.text = @"0%";
    _speedLabel.text = @"--";
    _statusBadge.hidden = YES;
    _cancelBtn.hidden = NO;
    _progressBar.progressTintColor = ThemeManager.shared.accentColor;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


#pragma mark - View Controller

@interface DependencyDownloadViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIView *headerView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *overallProgressLabel;
@property (nonatomic) UIProgressView *overallProgressBar;
@property (nonatomic) UIButton *cancelAllBtn;
@property (nonatomic) UIButton *closeBtn;
@property (nonatomic) NSMutableDictionary<NSString *, DownloadTask *> *taskMap;
@property (nonatomic) NSInteger completedCount;
@property (nonatomic) BOOL isCompleted;
@end

@implementation DependencyDownloadViewController

- (instancetype)initWithMainModTitle:(NSString *)title items:(NSArray<NSDictionary *> *)items groupIdentifier:(NSString *)groupId {
    self = [super init];
    if (self) {
        _mainModTitle = title;
        _downloadItems = items;
        _groupIdentifier = groupId ?: [NSString stringWithFormat:@"dep_%@", [[NSUUID UUID] UUIDString]];
        _taskMap = [NSMutableDictionary dictionary];
        _completedCount = 0;
        _isCompleted = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = YES;
    self.navigationItem.title = localize(@"Download Dependencies", nil);
    self.navigationItem.hidesBackButton = YES;
    [self setupUI];
    [self startDownloads];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTaskUpdate:) name:DownloadTasksDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSpeedUpdate:) name:DownloadTaskSpeedUpdatedNotification object:nil];
    [self updateColors];
    [AmethystBlurView installInView:self.view];
}

- (void)setupUI {
    // Header with overall progress
    _headerView = [[UIView alloc] init];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    _headerView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    [self.view addSubview:_headerView];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _titleLabel.text = [NSString stringWithFormat:@"%@ %@", localize(@"Installing:", nil), _mainModTitle];
    _titleLabel.numberOfLines = 2;
    [_headerView addSubview:_titleLabel];
    
    _overallProgressLabel = [[UILabel alloc] init];
    _overallProgressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _overallProgressLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _overallProgressLabel.textColor = ThemeManager.shared.accentColor;
    _overallProgressLabel.text = localize(@"0 / 0", nil);
    [_headerView addSubview:_overallProgressLabel];
    
    _overallProgressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _overallProgressBar.translatesAutoresizingMaskIntoConstraints = NO;
    _overallProgressBar.progressTintColor = ThemeManager.shared.accentColor;
    _overallProgressBar.trackTintColor = ThemeManager.shared.separatorColor;
    _overallProgressBar.layer.cornerRadius = 3;
    _overallProgressBar.clipsToBounds = YES;
    _overallProgressBar.progress = 0;
    [_headerView addSubview:_overallProgressBar];
    
    _cancelAllBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelAllBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelAllBtn setTitle:localize(@"Cancel All", nil) forState:UIControlStateNormal];
    [_cancelAllBtn setTitleColor:ThemeManager.shared.errorColor forState:UIControlStateNormal];
    _cancelAllBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_cancelAllBtn addTarget:self action:@selector(cancelAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [_headerView addSubview:_cancelAllBtn];
    
    _closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeBtn setTitle:localize(@"Close", nil) forState:UIControlStateNormal];
    [_closeBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    _closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    _closeBtn.hidden = YES;
    [_headerView addSubview:_closeBtn];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 72;
    _tableView.contentInset = UIEdgeInsetsMake(8, 16, 16, 16);
    [_tableView registerClass:[DependencyDownloadCell class] forCellReuseIdentifier:kDownloadCell];
    [self.view addSubview:_tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [_titleLabel.topAnchor constraintEqualToAnchor:_headerView.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        
        [_overallProgressLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:12],
        [_overallProgressLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        
        [_overallProgressBar.topAnchor constraintEqualToAnchor:_overallProgressLabel.bottomAnchor constant:8],
        [_overallProgressBar.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        [_overallProgressBar.trailingAnchor constraintEqualToAnchor:_cancelAllBtn.leadingAnchor constant:-12],
        [_overallProgressBar.heightAnchor constraintEqualToConstant:6],
        
        [_cancelAllBtn.centerYAnchor constraintEqualToAnchor:_overallProgressBar.centerYAnchor],
        [_cancelAllBtn.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        [_cancelAllBtn.heightAnchor constraintEqualToConstant:32],
        
        [_closeBtn.centerYAnchor constraintEqualToAnchor:_overallProgressBar.centerYAnchor],
        [_closeBtn.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        [_closeBtn.heightAnchor constraintEqualToConstant:32],
        
        [_headerView.bottomAnchor constraintEqualToAnchor:_closeBtn.bottomAnchor constant:16],
        
        [_tableView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)startDownloads {
    __weak typeof(self) weakSelf = self;
    __block NSInteger started = 0;
    
    for (NSDictionary *item in _downloadItems) {
        NSString *url = item[@"url"];
        NSString *name = item[@"name"] ?: item[@"filename"] ?: @"file";
        NSString *targetPath = item[@"targetPath"];
        NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, name];
        DownloadType type = [item[@"type"] integerValue] ?: DownloadTypeDependency;
        BOOL isMain = [item[@"isMain"] boolValue] ?: NO;
        
        DownloadTask *task = [[DownloadManager shared] beginTaskWithIdentifier:identifier name:name type:type group:_groupIdentifier isMain:isMain];
        if (task) {
            _taskMap[identifier] = task;
            
            [DownloadManager.shared downloadToPathWithTask:task url:url targetPath:targetPath completion:^(BOOL success, NSError *error) {
                // Completion handled by notifications
            }];
            started++;
        }
    }
    
    [self updateOverallProgress];
}

- (void)updateOverallProgress {
    NSInteger total = _downloadItems.count;
    NSInteger finished = 0;
    float totalProgress = 0;
    
    for (NSDictionary *item in _downloadItems) {
        NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, item[@"name"] ?: item[@"filename"]];
        DownloadTask *task = _taskMap[identifier];
        if (task) {
            totalProgress += task.progress;
            if (task.isFinished) finished++;
        }
    }
    
    _overallProgressBar.progress = total > 0 ? totalProgress / total : 0;
    _overallProgressLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)finished, (long)total];
    
    if (finished == total && total > 0) {
        _isCompleted = YES;
        _cancelAllBtn.hidden = YES;
        _closeBtn.hidden = NO;
        [HapticManager.shared play:HapticTypeSuccess];
    }
    
    [_tableView reloadData];
}

- (void)onTaskUpdate:(NSNotification *)note {
    [self updateOverallProgress];
}

- (void)onSpeedUpdate:(NSNotification *)note {
    DownloadTask *task = note.object;
    // Find cell and update speed
    for (NSUInteger i = 0; i < _downloadItems.count; i++) {
        NSDictionary *item = _downloadItems[i];
        NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, item[@"name"] ?: item[@"filename"]];
        if ([identifier isEqualToString:task.identifier]) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
            DependencyDownloadCell *cell = (DependencyDownloadCell *)[_tableView cellForRowAtIndexPath:ip];
            if (cell) {
                [cell updateProgress:task.progress speed:task.averageSpeed finished:task.isFinished error:task.error];
            }
            break;
        }
    }
}

- (void)cancelAllTapped {
    [HapticManager.shared play:HapticTypeMedium];
    [DownloadManager.shared cancelGroup:_groupIdentifier];
    _cancelAllBtn.hidden = YES;
    _closeBtn.hidden = NO;
}

- (void)closeTapped {
    [HapticManager.shared play:HapticTypeLight];
    BOOL allSuccess = YES;
    for (NSDictionary *item in _downloadItems) {
        NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, item[@"name"] ?: item[@"filename"]];
        DownloadTask *task = _taskMap[identifier];
        if (task && (task.error || !task.isFinished)) {
            allSuccess = NO;
            break;
        }
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(dependencyDownloadDidComplete:success:)]) {
        [_delegate dependencyDownloadDidComplete:self success:allSuccess];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _downloadItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DependencyDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:kDownloadCell forIndexPath:indexPath];
    NSDictionary *item = _downloadItems[indexPath.row];
    NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, item[@"name"] ?: item[@"filename"]];
    DownloadTask *task = _taskMap[identifier];
    BOOL isMain = [item[@"isMain"] boolValue] ?: (indexPath.row == 0);
    
    if (task) {
        [cell configureWithTask:task isMain:isMain];
        
        __weak typeof(self) weakSelf = self;
        cell.cancelBtn.tag = indexPath.row;
        [cell.cancelBtn addTarget:self action:@selector(cancelSingleTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        // Load icon
        NSString *iconURL = item[@"icon_url"];
        if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
            __weak typeof(cell) weakCell = cell;
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:iconURL]];
            [req setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
            [weakCell.iconView setImageWithURLRequest:req placeholderImage:[UIImage systemImageNamed:@"puzzlepiece.extension"] success:^(NSURLRequest *r, NSHTTPURLResponse *resp, UIImage *img) {
                weakCell.iconView.image = img;
                weakCell.iconView.tintColor = [UIColor clearColor];
            } failure:nil];
        }
    }
    
    return cell;
}

- (void)cancelSingleTapped:(UIButton *)sender {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:sender.tag inSection:0];
    if (ip.row < _downloadItems.count) {
        NSDictionary *item = _downloadItems[ip.row];
        NSString *identifier = item[@"identifier"] ?: [NSString stringWithFormat:@"%@_%@", _groupIdentifier, item[@"name"] ?: item[@"filename"]];
        DownloadTask *task = _taskMap[identifier];
        if (task) {
            [DownloadManager.shared cancelTask:task];
        }
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _headerView.backgroundColor = theme.cardBackgroundColor;
    _tableView.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = theme.primaryTextColor;
    _overallProgressLabel.textColor = theme.accentColor;
    _overallProgressBar.progressTintColor = theme.accentColor;
    _overallProgressBar.trackTintColor = theme.separatorColor;
    [_cancelAllBtn setTitleColor:theme.errorColor forState:UIControlStateNormal];
    [_closeBtn setTitleColor:theme.accentColor forState:UIControlStateNormal];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end