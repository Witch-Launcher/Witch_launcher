#import "ModListViewController.h"
#import "ModDetailViewController.h"
#import "ThemeManager.h"
#import "MainCoordinator.h"
#import "ModrinthService.h"
#import "AmethystProjectCell.h"
#import "HapticManager.h"
#import "DownloadProgressOverlay.h"
#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "UIImageView+AFNetworking.h"
#import "CurseForgeService.h"
#import "AFImageDownloader.h"

@interface ModTagView : UIView
@property (nonatomic) UILabel *label;
@end

@implementation ModTagView
- (instancetype)initWithText:(NSString *)text color:(UIColor *)color {
    self = [super init];
    if (self) {
        _label = [[UILabel alloc] init];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.text = text;
        _label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _label.textColor = UIColor.whiteColor;
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
        self.backgroundColor = color;
        self.layer.cornerRadius = 3;
        self.clipsToBounds = YES;
        [NSLayoutConstraint activateConstraints:@[
            [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5],
            [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5],
        ]];
    }
    return self;
}
@end

@interface ModCell : UITableViewCell
@property (nonatomic) UIImageView *projectIcon;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *downloadsLabel;
@property (nonatomic) UILabel *descLabel;
@property (nonatomic) UIStackView *tagsStack;
@property (nonatomic) UIButton *versionBtn;
@property (nonatomic) UIButton *downloadBtn;
@property (nonatomic) NSDictionary *modData;
@property (nonatomic, copy) void(^onVersionTap)(NSDictionary *mod, UIButton *sender);
@property (nonatomic, copy) void(^onDownloadTap)(NSDictionary *mod, UIButton *sender);
- (void)configureWithDict:(NSDictionary *)mod;
@end

@implementation ModCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 8;
        self.clipsToBounds = YES;

        _projectIcon = [[UIImageView alloc] init];
        _projectIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _projectIcon.contentMode = UIViewContentModeScaleAspectFill;
        _projectIcon.clipsToBounds = YES;
        _projectIcon.layer.cornerRadius = 8;
        _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_projectIcon];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
        _titleLabel.numberOfLines = 1;
        [self.contentView addSubview:_titleLabel];

        _downloadsLabel = [[UILabel alloc] init];
        _downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _downloadsLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _downloadsLabel.textColor = ThemeManager.shared.accentColor;
        _downloadsLabel.numberOfLines = 1;
        [self.contentView addSubview:_downloadsLabel];

        _descLabel = [[UILabel alloc] init];
        _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _descLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _descLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _descLabel.numberOfLines = 1;
        [self.contentView addSubview:_descLabel];

        _tagsStack = [[UIStackView alloc] init];
        _tagsStack.translatesAutoresizingMaskIntoConstraints = NO;
        _tagsStack.axis = UILayoutConstraintAxisHorizontal;
        _tagsStack.spacing = 4;
        _tagsStack.alignment = UIStackViewAlignmentLeading;
        _tagsStack.distribution = UIStackViewDistributionEqualSpacing;
        [self.contentView addSubview:_tagsStack];

        _versionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _versionBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_versionBtn setTitle:@"Select Version" forState:UIControlStateNormal];
        [_versionBtn setTitleColor:ThemeManager.shared.primaryTextColor forState:UIControlStateNormal];
        _versionBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        _versionBtn.layer.cornerRadius = 6;
        _versionBtn.layer.borderWidth = 1;
        _versionBtn.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
        _versionBtn.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        _versionBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        _versionBtn.titleLabel.minimumScaleFactor = 0.7;
        _versionBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _versionBtn.contentEdgeInsets = UIEdgeInsetsMake(2, 4, 2, 4);
        [_versionBtn addTarget:self action:@selector(versionBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_versionBtn];

        _downloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _downloadBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_downloadBtn setTitle:@"Download" forState:UIControlStateNormal];
        [_downloadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        _downloadBtn.backgroundColor = ThemeManager.shared.accentColor;
        _downloadBtn.layer.cornerRadius = 6;
        _downloadBtn.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        _downloadBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        _downloadBtn.titleLabel.minimumScaleFactor = 0.7;
        _downloadBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _downloadBtn.contentEdgeInsets = UIEdgeInsetsMake(2, 4, 2, 4);
        [_downloadBtn addTarget:self action:@selector(downloadBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_downloadBtn];

        CGFloat actionBtnWidth = 72;
        CGFloat actionBtnHeight = 24;

        [NSLayoutConstraint activateConstraints:@[
            [_projectIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
            [_projectIcon.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_projectIcon.widthAnchor constraintEqualToConstant:48],
            [_projectIcon.heightAnchor constraintEqualToConstant:48],

            [_versionBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_versionBtn.widthAnchor constraintEqualToConstant:actionBtnWidth],
            [_versionBtn.heightAnchor constraintEqualToConstant:actionBtnHeight],
            [_versionBtn.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-(actionBtnHeight / 2.0 + 2)],

            [_downloadBtn.trailingAnchor constraintEqualToAnchor:_versionBtn.trailingAnchor],
            [_downloadBtn.leadingAnchor constraintEqualToAnchor:_versionBtn.leadingAnchor],
            [_downloadBtn.widthAnchor constraintEqualToConstant:actionBtnWidth],
            [_downloadBtn.heightAnchor constraintEqualToConstant:actionBtnHeight],
            [_downloadBtn.topAnchor constraintEqualToAnchor:_versionBtn.bottomAnchor constant:4],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_projectIcon.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_versionBtn.leadingAnchor constant:-8],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],

            [_downloadsLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_downloadsLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_versionBtn.leadingAnchor constant:-8],
            [_downloadsLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],

            [_descLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_descLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_versionBtn.leadingAnchor constant:-8],
            [_descLabel.topAnchor constraintEqualToAnchor:_downloadsLabel.bottomAnchor constant:1],

            [_tagsStack.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_tagsStack.trailingAnchor constraintLessThanOrEqualToAnchor:_versionBtn.leadingAnchor constant:-8],
            [_tagsStack.topAnchor constraintEqualToAnchor:_descLabel.bottomAnchor constant:4],
            [_tagsStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _downloadsLabel.textColor = ThemeManager.shared.accentColor;
    _descLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
    _versionBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _versionBtn.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    [_versionBtn setTitleColor:ThemeManager.shared.primaryTextColor forState:UIControlStateNormal];
    _downloadBtn.backgroundColor = ThemeManager.shared.accentColor;
}

- (void)versionBtnTapped {
    if (_onVersionTap && _modData) {
        _onVersionTap(_modData, _versionBtn);
    }
}

- (void)downloadBtnTapped {
    if (_onDownloadTap && _modData) {
        _onDownloadTap(_modData, _downloadBtn);
    }
}

- (void)configureWithDict:(NSDictionary *)mod {
    _modData = mod;
    _titleLabel.text = mod[@"title"];

    NSNumber *downloads = mod[@"downloads"];
    NSString *dlStr = downloads ? [self formatNumber:downloads] : @"0";
    _downloadsLabel.text = [NSString stringWithFormat:@"\u2191 %@ downloads", dlStr];

    _descLabel.text = mod[@"description"];

    UIImage *placeholder = [UIImage systemImageNamed:@"wrench.and.screwdriver"];
    _projectIcon.image = placeholder;
    _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;

    NSString *iconURL = mod[@"icon_url"];
    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:iconURL]];
        [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
        [_projectIcon setImageWithURLRequest:request
                           placeholderImage:placeholder
                                    success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                        weakSelf.projectIcon.image = image;
                                        weakSelf.projectIcon.tintColor = [UIColor clearColor];
                                    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                        weakSelf.projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
                                        NSLog(@"[ModList] Icon load failed: %@, error: %@", iconURL, error);
                                    }];
    }

    for (UIView *v in _tagsStack.arrangedSubviews) {
        [_tagsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    NSArray *loaders = mod[@"loaders"];
    for (NSString *loader in loaders) {
        UIColor *color;
        if ([loader isEqualToString:@"fabric"]) color = [UIColor colorWithRed:0.85 green:0.65 blue:0.13 alpha:1];
        else if ([loader isEqualToString:@"forge"]) color = [UIColor colorWithRed:0.20 green:0.60 blue:0.86 alpha:1];
        else if ([loader isEqualToString:@"neoforge"]) color = [UIColor colorWithRed:0.90 green:0.40 blue:0.20 alpha:1];
        else if ([loader isEqualToString:@"quilt"]) color = [UIColor colorWithRed:0.50 green:0.30 blue:0.80 alpha:1];
        else color = ThemeManager.shared.secondaryTextColor;
        ModTagView *tag = [[ModTagView alloc] initWithText:[loader capitalizedString] color:color];
        [_tagsStack addArrangedSubview:tag];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _projectIcon.image = nil;
    _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
    _titleLabel.text = nil;
    _downloadsLabel.text = nil;
    _descLabel.text = nil;
    _modData = nil;
    _onVersionTap = nil;
    _onDownloadTap = nil;
    for (UIView *v in _tagsStack.arrangedSubviews) {
        [_tagsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
}

- (NSString *)formatNumber:(NSNumber *)num {
    long long n = num.longLongValue;
    if (n >= 1000000) return [NSString stringWithFormat:@"%.1fM", n / 1000000.0];
    if (n >= 1000) return [NSString stringWithFormat:@"%.1fK", n / 1000.0];
    return [NSString stringWithFormat:@"%lld", n];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

#pragma mark - Version Picker (scrollable table, avoids UIAlertController lag)

@interface ModVersionPickerViewController : UITableViewController
@property (nonatomic, copy) NSArray<NSDictionary *> *compatibleVersions;
@property (nonatomic, copy) NSArray<NSDictionary *> *otherVersions;
@property (nonatomic, copy) void(^onSelect)(NSDictionary *version);
@end

@implementation ModVersionPickerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Chọn Version";
        self.tableView.rowHeight = 52;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    self.tableView.backgroundColor = ThemeManager.shared.contentBackgroundColor;
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)hasCompatibleSection {
    return _compatibleVersions.count > 0;
}

- (BOOL)hasOtherSection {
    return _otherVersions.count > 0;
}

- (NSArray<NSDictionary *> *)versionsInSection:(NSInteger)section {
    if ([self hasCompatibleSection] && [self hasOtherSection]) {
        return section == 0 ? _compatibleVersions : _otherVersions;
    }
    if ([self hasCompatibleSection]) return _compatibleVersions;
    return _otherVersions;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count = 0;
    if ([self hasCompatibleSection]) count++;
    if ([self hasOtherSection]) count++;
    return MAX(count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (![self hasCompatibleSection] && ![self hasOtherSection]) return nil;
    if ([self hasCompatibleSection] && [self hasOtherSection]) {
        return section == 0 ? @"Tương thích profile" : @"Các version khác";
    }
    if ([self hasCompatibleSection]) return @"Tương thích profile";
    return @"Các version khác";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self versionsInSection:section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *kVerCell = @"ModVerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kVerCell];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kVerCell];
    }
    NSDictionary *ver = [self versionsInSection:indexPath.section][indexPath.row];
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.textLabel.text = ver[@"version_number"];

    NSString *loaders = [ver[@"loaders"] componentsJoinedByString:@", "];
    NSString *mc = [ver[@"game_versions"] componentsJoinedByString:@", "];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", mc, loaders];
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];
    NSDictionary *ver = [self versionsInSection:indexPath.section][indexPath.row];
    void (^callback)(NSDictionary *) = _onSelect;
    [self dismissViewControllerAnimated:YES completion:^{
        if (callback) callback(ver);
    }];
}

@end

@interface ModListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *mods;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UILabel *errorLabel;
@property (nonatomic) NSTimer *timeoutTimer;
@property (nonatomic) NSString *selectedSource;

@property (nonatomic) NSMutableDictionary *pageCache;
@property (nonatomic) NSMutableArray *pageOffsets;
@property (nonatomic) NSInteger currentOffset;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL isLoadingMore;
@property (nonatomic) NSString *currentQuery;

@property (nonatomic) UIButton *downloadBtn;
@property (nonatomic) UIButton *installBtn;
@property (nonatomic) UISegmentedControl *sourceControl;
@property (nonatomic) NSDictionary *selectedMod;
@property (nonatomic) NSInteger currentRequestId;

@property (nonatomic) NSURLSessionDownloadTask *currentDownloadTask;
@property (nonatomic) NSMutableArray *currentModDownloadTasks;

@property (nonatomic) NSInteger lastContentOffsetY;
@property (nonatomic) NSInteger pageSize;
@property (nonatomic) BOOL isRestoringPage;
@property (nonatomic) BOOL adjustingContentOffset;

@property (nonatomic) NSDictionary *versionSelectionMod;
@property (nonatomic) NSDictionary *downloadMod;
@property (nonatomic) NSArray *downloadDependencies;
@property (nonatomic) NSMutableArray *dependencyInstallTasks;
@property (nonatomic) DownloadProgressOverlay *dependencyOverlay;
@end

@implementation ModListViewController

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AFImageDownloader *downloader = [AFImageDownloader defaultInstance];
        AFImageResponseSerializer *serializer = (AFImageResponseSerializer *)downloader.sessionManager.responseSerializer;
        if ([serializer isKindOfClass:[AFImageResponseSerializer class]]) {
            NSMutableSet *types = [serializer.acceptableContentTypes mutableCopy];
            [types addObject:@"image/webp"];
            serializer.acceptableContentTypes = types;
        }
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _selectedSource = @"modrinth";
    _currentModDownloadTasks = [NSMutableArray array];
    _pageSize = 50;

    _pageCache = [NSMutableDictionary dictionary];
    _pageOffsets = [NSMutableArray array];
    _currentOffset = 0;
    _hasMore = YES;
    _isLoadingMore = NO;
    _mods = [NSMutableArray array];
    _lastContentOffsetY = 0;

    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(versionDidChangeExternal) name:@"VersionDidChangeNotification" object:nil];
    [self loadModsWithQuery:@"" offset:0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _selectedMod = nil;
    _downloadBtn.hidden = YES;
    _installBtn.hidden = YES;
}

- (void)setup {
    self.view.clipsToBounds = YES;

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Search mods...";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:_searchBar];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = @"No mods found.\nTry a different search.";
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _errorLabel = [[UILabel alloc] init];
    _errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _errorLabel.numberOfLines = 0;
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _errorLabel.hidden = YES;
    [self.view addSubview:_errorLabel];

    UIView *sidePanel = [[UIView alloc] init];
    sidePanel.translatesAutoresizingMaskIntoConstraints = NO;
    sidePanel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:sidePanel];

    _sourceControl = [[UISegmentedControl alloc] initWithItems:@[@"Modrinth", @"CurseForge"]];
    _sourceControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sourceControl.selectedSegmentIndex = 0;
    _sourceControl.selectedSegmentTintColor = ThemeManager.shared.accentColor;
    [_sourceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateSelected];
    [_sourceControl addTarget:self action:@selector(sourceChanged) forControlEvents:UIControlEventValueChanged];
    [sidePanel addSubview:_sourceControl];

    _downloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_downloadBtn setTitle:@"Download" forState:UIControlStateNormal];
    [_downloadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _downloadBtn.backgroundColor = ThemeManager.shared.accentColor;
    _downloadBtn.layer.cornerRadius = 8;
    _downloadBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_downloadBtn addTarget:self action:@selector(downloadCurrentMod) forControlEvents:UIControlEventTouchUpInside];
    _downloadBtn.hidden = YES;
    [sidePanel addSubview:_downloadBtn];

    _installBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _installBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_installBtn setTitle:@"Install" forState:UIControlStateNormal];
    [_installBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _installBtn.backgroundColor = ThemeManager.shared.successColor;
    _installBtn.layer.cornerRadius = 8;
    _installBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_installBtn addTarget:self action:@selector(installCurrentMod) forControlEvents:UIControlEventTouchUpInside];
    _installBtn.hidden = YES;
    [sidePanel addSubview:_installBtn];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 80;
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pullToRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[ModCell class] forCellReuseIdentifier:@"ModCell"];

    CGFloat sideWidth = 130;
    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_searchBar.trailingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor constant:-8],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

        [_errorLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_errorLabel.topAnchor constraintEqualToAnchor:_spinner.bottomAnchor constant:12],
        [_errorLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_errorLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

        [sidePanel.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sidePanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [sidePanel.widthAnchor constraintEqualToConstant:sideWidth],
        [sidePanel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_sourceControl.topAnchor constraintEqualToAnchor:sidePanel.topAnchor constant:16],
        [_sourceControl.leadingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor constant:6],
        [_sourceControl.trailingAnchor constraintEqualToAnchor:sidePanel.trailingAnchor constant:-6],

        [_downloadBtn.topAnchor constraintEqualToAnchor:_sourceControl.bottomAnchor constant:20],
        [_downloadBtn.leadingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor constant:6],
        [_downloadBtn.trailingAnchor constraintEqualToAnchor:sidePanel.trailingAnchor constant:-6],
        [_downloadBtn.heightAnchor constraintEqualToConstant:36],

        [_installBtn.topAnchor constraintEqualToAnchor:_downloadBtn.bottomAnchor constant:8],
        [_installBtn.leadingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor constant:6],
        [_installBtn.trailingAnchor constraintEqualToAnchor:sidePanel.trailingAnchor constant:-6],
        [_installBtn.heightAnchor constraintEqualToConstant:36],

        [_tableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = ThemeManager.shared.separatorColor;
    [self.view addSubview:separator];
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:sidePanel.leadingAnchor],
        [separator.widthAnchor constraintEqualToConstant:1],
    ]];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    if (@available(iOS 13.0, *)) {
        _searchBar.searchTextField.textColor = theme.primaryTextColor;
    }
    _searchBar.tintColor = theme.accentColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
    _errorLabel.textColor = theme.errorColor;
    _sourceControl.selectedSegmentTintColor = theme.accentColor;
}

- (NSString *)selectedVersion {
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    if (profile.mcVersion) return profile.mcVersion;
    NSString *cv = VersionDirectoryManager.shared.currentVersion;
    if (cv.length > 0) return [VersionProfile cleanMinecraftVersion:cv];
    return @"";
}

- (NSString *)selectedModloader {
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    if (profile.modLoader) return profile.modLoader;
    return getPrefObject(@"internal.mod_loader") ?: @"Vanilla";
}

- (void)loadModsWithQuery:(NSString *)query offset:(NSInteger)offset {
    _currentRequestId++;
    NSInteger requestId = _currentRequestId;

    if (offset == 0) {
        _currentOffset = 0;
        _hasMore = YES;
        _currentQuery = query;
        [_pageCache removeAllObjects];
        [_pageOffsets removeAllObjects];
        [_spinner startAnimating];
        _tableView.hidden = YES;
        _emptyLabel.hidden = YES;
        _errorLabel.hidden = YES;
        [_timeoutTimer invalidate];

        __weak typeof(self) weakSelf = self;
        _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:15 repeats:NO block:^(NSTimer *timer) {
            if (weakSelf.spinner.isAnimating) {
                [weakSelf.spinner stopAnimating];
                weakSelf.errorLabel.text = @"Request timed out.\nCheck your internet connection.";
                [weakSelf.view bringSubviewToFront:weakSelf.errorLabel];
                weakSelf.errorLabel.hidden = NO;
            }
        }];
    } else {
        _isLoadingMore = YES;
    }

    NSString *loaderFilter = nil;
    NSString *selectedLoader = [self selectedModloader];
    if (selectedLoader && ![selectedLoader isEqualToString:@"Vanilla"]) {
        loaderFilter = selectedLoader.lowercaseString;
    }
    NSString *gameVersionFilter = nil;
    NSString *selVer = [self selectedVersion];
    if (selVer.length > 0) {
        gameVersionFilter = selVer;
    }

    void (^handleResults)(NSArray *, NSError *) = ^(NSArray<NSDictionary *> *results, NSError *error) {
        if (requestId != self.currentRequestId && offset > 0) return;
        if (requestId != self.currentRequestId && offset == 0) {
            [self.timeoutTimer invalidate];
            [self.spinner stopAnimating];
            [self.tableView.refreshControl endRefreshing];
            return;
        }
        [self.timeoutTimer invalidate];
        [self.spinner stopAnimating];
        [self.tableView.refreshControl endRefreshing];
        self.isLoadingMore = NO;

        if (results) {
            self.hasMore = results.count >= 50;
            self.pageCache[@(offset)] = results;
            if (![self.pageOffsets containsObject:@(offset)]) {
                [self.pageOffsets addObject:@(offset)];
                [self.pageOffsets sortUsingSelector:@selector(compare:)];
            }

            if (offset == 0) {
                self.mods = [results mutableCopy];
            } else {
                [self.mods addObjectsFromArray:results];
            }

            self.tableView.hidden = NO;
            self.emptyLabel.hidden = self.mods.count > 0;
            [self.tableView reloadData];
            [self trimModsIfNeeded];
        } else if (error && offset == 0) {
            self.errorLabel.text = error.localizedDescription ?: @"Failed to load mods.";
            self.errorLabel.hidden = NO;
            [self.view bringSubviewToFront:self.errorLabel];
        }
    };

    if ([_selectedSource isEqualToString:@"curseforge"]) {
        [CurseForgeService.shared searchProjectsWithClassId:6 query:query offset:offset limit:50 loaderFilter:loaderFilter gameVersionFilter:gameVersionFilter completion:handleResults];
    } else {
        [ModrinthService.shared searchProjectsWithType:@"mod" query:query offset:offset limit:50 categoryFilter:nil loaderFilter:loaderFilter gameVersionFilter:gameVersionFilter completion:handleResults];
    }
}

- (void)trimModsIfNeeded {
    NSInteger maxVisible = 60;
    if (self.mods.count <= maxVisible) return;

    NSInteger pagesToRemove = (self.mods.count - maxVisible) / self.pageSize;
    if (pagesToRemove <= 0) return;

    NSInteger removeCount = pagesToRemove * self.pageSize;
    NSRange range = NSMakeRange(0, removeCount);
    [self.mods removeObjectsInRange:range];

    CGFloat offsetY = self.tableView.contentOffset.y;
    CGFloat estimatedCellHeight = 80;
    CGFloat adjustedOffset = offsetY - removeCount * estimatedCellHeight;
    if (adjustedOffset < 0) adjustedOffset = 0;

    // Only drop the *offsets* that left the screen; the cached pages are kept
    // so scrolling back up can restore the trimmed rows (restorePreviousPage
    // inserts from this cache).
    NSInteger remainingRemove = removeCount;
    while (self.pageOffsets.count > 0) {
        NSNumber *firstOffset = self.pageOffsets.firstObject;
        NSArray *page = self.pageCache[firstOffset];
        if (!page) {
            [self.pageOffsets removeObjectAtIndex:0];
            continue;
        }
        if (page.count <= remainingRemove) {
            remainingRemove -= page.count;
            [self.pageOffsets removeObjectAtIndex:0];
        } else {
            break;
        }
    }

    // The programmatic offset change below must not re-arm the auto-load /
    // restore triggers in scrollViewDidScroll (otherwise every page load
    // chains into the next one while the user holds the scroll at the end).
    self.adjustingContentOffset = YES;
    self.tableView.contentOffset = CGPointMake(0, adjustedOffset);
    [self.tableView reloadData];
    self.adjustingContentOffset = NO;
}

- (void)loadMoreMods {
    if (_isLoadingMore || !_hasMore) return;
    NSInteger nextOffset = 0;
    if (self.pageOffsets.count > 0) {
        nextOffset = [self.pageOffsets.lastObject integerValue] + 50;
    }
    [self loadModsWithQuery:_currentQuery ?: @"" offset:nextOffset];
}

- (void)restorePreviousPage {
    if (self.pageOffsets.count == 0 || _isRestoringPage) return;
    _isRestoringPage = YES;
    NSNumber *firstOffset = self.pageOffsets.firstObject;
    if ([firstOffset integerValue] <= 0) { _isRestoringPage = NO; return; }
    NSNumber *prevOffset = @([firstOffset integerValue] - 50);
    NSArray *cachedPage = self.pageCache[prevOffset];
    if (!cachedPage) { _isRestoringPage = NO; return; }

    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, cachedPage.count)];
    [self.mods insertObjects:cachedPage atIndexes:indexes];
    [self.pageOffsets insertObject:prevOffset atIndex:0];

    CGFloat offsetY = self.tableView.contentOffset.y;
    self.adjustingContentOffset = YES;
    [self.tableView reloadData];
    CGFloat estimatedCellHeight = 80;
    self.tableView.contentOffset = CGPointMake(0, offsetY + cachedPage.count * estimatedCellHeight);
    self.adjustingContentOffset = NO;
    _isRestoringPage = NO;
}

#pragma mark - Scroll (pagination)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset) return;

    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;

    // Only auto-load while the user is actually dragging; never while the
    // view is decelerating into a clamped position or right after our own
    // offset adjustments (see adjustingContentOffset).
    if (offsetY > contentHeight - frameHeight - 150 && _hasMore && !_isLoadingMore && _mods.count > 0 && scrollView.isDragging) {
        [self loadMoreMods];
    }

    if (offsetY < 80 && !_isLoadingMore && !_isRestoringPage && _pageOffsets.count > 0 && scrollView.isDragging) {
        NSNumber *firstOffset = _pageOffsets.firstObject;
        if ([firstOffset integerValue] > 0) {
            [self restorePreviousPage];
        }
    }
}

// Load one more page when a flick/drag releases near the bottom, so the
// auto-load works after the finger lifts without chaining while holding.
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) return;
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _mods.count > 0) {
        [self loadMoreMods];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _mods.count > 0) {
        [self loadMoreMods];
    }
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self loadModsWithQuery:searchBar.text ?: @"" offset:0];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self loadModsWithQuery:@"" offset:0];
    }
}

- (void)pullToRefresh {
    [self loadModsWithQuery:_searchBar.text ?: @"" offset:0];
}

- (void)sourceChanged {
    _selectedSource = _sourceControl.selectedSegmentIndex == 0 ? @"modrinth" : @"curseforge";
    [self loadModsWithQuery:_searchBar.text ?: @"" offset:0];
}

#pragma mark - TableView (main mod list)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    [cell configureWithDict:_mods[indexPath.row]];
    __weak typeof(self) weakSelf = self;
    cell.onVersionTap = ^(NSDictionary *mod, UIButton *sender) {
        [weakSelf showVersionSelectorForMod:mod fromButton:sender];
    };
    cell.onDownloadTap = ^(NSDictionary *mod, UIButton *sender) {
        [weakSelf showDownloadPopupForMod:mod fromButton:sender];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];
    ModDetailViewController *detail = [[ModDetailViewController alloc] initWithMod:_mods[indexPath.row]];
    detail.coordinator = self.coordinator;
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark - Side panel actions

- (void)downloadCurrentMod {
    if (!_selectedMod) {
        showDialog(@"No Mod Selected", @"Tap a mod in the list first.");
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Downloading Mod"];
    [overlay updateProgress:0 message:@"Loading versions..."];
    __weak typeof(self) weakSelf = self;

    NSString *projectId = _selectedMod[@"project_id"];
    [ModrinthService.shared loadProjectVersions:projectId completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error || versions.count == 0) {
            [overlay dismiss];
            showDialog(@"Error", @"No versions found for this mod.");
            return;
        }

        NSDictionary *best = [weakSelf bestVersionForSelected:versions];
        if (!best) best = versions.firstObject;

        NSString *url = best[@"url"];
        NSString *filename = best[@"filename"] ?: @"mod.jar";

        [overlay setCancelBlock:^{
            [weakSelf.currentDownloadTask cancel];
            weakSelf.currentDownloadTask = nil;
        }];

        weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
            [overlay updateProgress:p message:[NSString stringWithFormat:@"Downloading %@", filename]];
        } completion:^(NSString *path, NSError *dlError) {
            weakSelf.currentDownloadTask = nil;
            if (path) {
                [overlay finishWithMessage:@"Downloaded!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    showDialog(@"Downloaded", [NSString stringWithFormat:@"%@ saved to temp.", filename]);
                });
            } else {
                if ([dlError.domain isEqualToString:NSURLErrorDomain] && dlError.code == NSURLErrorCancelled) {
                    [overlay dismiss];
                } else {
                    [overlay dismiss];
                    showDialog(@"Download Failed", dlError.localizedDescription ?: @"Unknown error");
                }
            }
        }];
    }];
}

- (void)installCurrentMod {
    if (!_selectedMod) {
        showDialog(@"No Mod Selected", @"Tap a mod in the list first.");
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Installing Mod"];
    [overlay updateProgress:0 message:@"Loading versions..."];
    __weak typeof(self) weakSelf = self;

    NSString *projectId = _selectedMod[@"project_id"];
    [ModrinthService.shared loadProjectVersions:projectId completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error || versions.count == 0) {
            [overlay dismiss];
            showDialog(@"Error", @"No versions found for this mod.");
            return;
        }

        NSDictionary *best = [weakSelf bestVersionForSelected:versions];
        if (!best) best = versions.firstObject;

        NSString *url = best[@"url"];
        NSString *filename = best[@"filename"] ?: @"mod.jar";
        NSString *targetVersion = VersionDirectoryManager.shared.currentVersion ?: [weakSelf selectedVersion];

        [overlay setCancelBlock:^{
            [weakSelf.currentDownloadTask cancel];
            weakSelf.currentDownloadTask = nil;
        }];

        weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
            [overlay updateProgress:p message:@"Downloading..."];
        } completion:^(NSString *path, NSError *dlError) {
            weakSelf.currentDownloadTask = nil;
            if (path) {
                [overlay updateProgress:1.0 message:@"Copying to profile..."];
                NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:targetVersion];
                NSString *targetPath = [modsDir stringByAppendingPathComponent:filename];
                if (![targetPath hasSuffix:@".jar"]) targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
                [[NSFileManager defaultManager] createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
                NSError *moveError = nil;
                [[NSFileManager defaultManager] moveItemAtPath:path toPath:targetPath error:&moveError];
                BOOL success = moveError == nil;
                if (success) {
                    [overlay finishWithMessage:@"Installed!"];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [overlay dismiss];
                        showDialog(@"Installed", [NSString stringWithFormat:@"%@ installed.", _selectedMod[@"title"]]);
                    });
                } else {
                    [overlay dismiss];
                    showDialog(@"Install Failed", moveError.localizedDescription ?: @"Unknown error");
                }
            } else {
                if ([dlError.domain isEqualToString:NSURLErrorDomain] && dlError.code == NSURLErrorCancelled) {
                    [overlay dismiss];
                } else {
                    [overlay dismiss];
                    showDialog(@"Download Failed", dlError.localizedDescription ?: @"Unknown error");
                }
            }
        }];
    }];
}

- (NSDictionary *)bestVersionForSelected:(NSArray<NSDictionary *> *)versions {
    NSString *targetVersion = [self selectedVersion];
    NSString *targetLoader = [[self selectedModloader] lowercaseString];
    for (NSDictionary *ver in versions) {
        NSArray *gameVersions = ver[@"game_versions"];
        NSArray *loaders = ver[@"loaders"];
        BOOL versionMatch = [gameVersions containsObject:targetVersion];
        BOOL loaderMatch = [loaders containsObject:targetLoader];
        if (versionMatch && loaderMatch) return ver;
    }
    for (NSDictionary *ver in versions) {
        if ([ver[@"game_versions"] containsObject:targetVersion]) return ver;
    }
    return nil;
}

- (void)versionDidChangeExternal {
    [self loadModsWithQuery:@"" offset:0];
}

#pragma mark - Version Selector

static const NSInteger kModActionLoadingTag = 9001;

- (void)setModActionButtonLoading:(UIButton *)button loading:(BOOL)loading {
    if (!button) return;
    button.enabled = !loading;
    UIActivityIndicatorView *spinner = [button viewWithTag:kModActionLoadingTag];
    if (loading) {
        if (!spinner) {
            spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            spinner.tag = kModActionLoadingTag;
            spinner.translatesAutoresizingMaskIntoConstraints = NO;
            spinner.color = [button titleColorForState:UIControlStateNormal] ?: ThemeManager.shared.primaryTextColor;
            [button addSubview:spinner];
            [NSLayoutConstraint activateConstraints:@[
                [spinner.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
                [spinner.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
            ]];
        }
        button.titleLabel.alpha = 0;
        [spinner startAnimating];
    } else {
        button.titleLabel.alpha = 1;
        [spinner stopAnimating];
        [spinner removeFromSuperview];
    }
}

- (void)splitVersions:(NSArray *)versions
          compatible:(NSMutableArray **)compatibleOut
               other:(NSMutableArray **)otherOut
        targetVersion:(NSString *)targetVersion
         targetLoader:(NSString *)targetLoader {
    NSMutableArray *compatible = [NSMutableArray array];
    NSMutableArray *other = [NSMutableArray array];
    for (NSDictionary *ver in versions) {
        BOOL versionMatch = targetVersion.length == 0 || [ver[@"game_versions"] containsObject:targetVersion];
        BOOL loaderMatch = targetLoader.length == 0 || [targetLoader isEqualToString:@"vanilla"] || [ver[@"loaders"] containsObject:targetLoader];
        if (versionMatch && loaderMatch) {
            [compatible addObject:ver];
        } else {
            [other addObject:ver];
        }
    }
    *compatibleOut = compatible;
    *otherOut = other;
}

- (void)presentVersionPickerWithCompatible:(NSArray *)compatible
                                    other:(NSArray *)other
                               fromButton:(UIButton *)sender {
    ModVersionPickerViewController *picker = [[ModVersionPickerViewController alloc] init];
    picker.compatibleVersions = compatible;
    picker.otherVersions = other;

    __weak typeof(self) weakSelf = self;
    picker.onSelect = ^(NSDictionary *version) {
        [weakSelf selectModVersion:version];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent],
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        }
    }

    UIPopoverPresentationController *popover = nav.popoverPresentationController;
    if (popover && sender) {
        popover.sourceView = sender;
        popover.sourceRect = sender.bounds;
    }

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showVersionSelectorForMod:(NSDictionary *)mod fromButton:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    _versionSelectionMod = mod;

    NSString *projectId = mod[@"project_id"];
    if (!projectId || projectId.length == 0) {
        showDialog(@"Error", @"Mod project ID not found.");
        return;
    }

    [self setModActionButtonLoading:sender loading:YES];

    NSString *targetVersion = [self selectedVersion];
    NSString *targetLoader = [[self selectedModloader] lowercaseString];
    __weak typeof(self) weakSelf = self;
    __weak UIButton *weakSender = sender;

    [ModrinthService.shared loadProjectVersions:projectId completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        [weakSelf handleLoadedVersions:versions error:error targetVersion:targetVersion targetLoader:targetLoader sender:weakSender];
    }];
}

- (void)handleLoadedVersions:(NSArray<NSDictionary *> *)versions
                       error:(NSError *)error
               targetVersion:(NSString *)targetVersion
                targetLoader:(NSString *)targetLoader
                      sender:(UIButton *)sender {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *compatible = nil;
        NSMutableArray *other = nil;
        if (versions.count > 0) {
            [self splitVersions:versions compatible:&compatible other:&other targetVersion:targetVersion targetLoader:targetLoader];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setModActionButtonLoading:sender loading:NO];

            if (error || versions.count == 0) {
                showDialog(@"Error", @"No versions found for this mod.");
                return;
            }

            [self presentVersionPickerWithCompatible:compatible other:other fromButton:sender];
        });
    });
}

- (void)selectModVersion:(NSDictionary *)version {
    if (_versionSelectionMod) {
        [self showDownloadPopupForMod:_versionSelectionMod withSelectedVersion:version];
    }
}

#pragma mark - Download Popup with Dependencies

- (void)showDownloadPopupForMod:(NSDictionary *)mod fromButton:(UIButton *)sender {
    [self showDownloadPopupForMod:mod withSelectedVersion:nil];
}

- (void)showDownloadPopupForMod:(NSDictionary *)mod withSelectedVersion:(NSDictionary *)selectedVersion {
    [HapticManager.shared play:HapticTypeLight];
    _downloadMod = mod;

    if (selectedVersion) {
        _downloadDependencies = selectedVersion[@"dependencies"] ?: @[];
        [self showDependencyPopupWithVersion:selectedVersion];
        return;
    }

    NSString *projectId = mod[@"project_id"];
    if (!projectId || projectId.length == 0) {
        showDialog(@"Error", @"Mod project ID not found.");
        return;
    }

    __weak typeof(self) weakSelf = self;
    [ModrinthService.shared loadProjectVersions:projectId completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || versions.count == 0) {
                showDialog(@"Error", @"No versions found for this mod.");
                return;
            }

            NSDictionary *versionToUse = [weakSelf bestVersionForSelected:versions];
            if (!versionToUse) versionToUse = versions.firstObject;

            weakSelf.downloadDependencies = versionToUse[@"dependencies"] ?: @[];
            [weakSelf showDependencyPopupWithVersion:versionToUse];
        });
    }];
}

- (void)showDependencyPopupWithVersion:(NSDictionary *)version {
    __weak typeof(self) weakSelf = self;
    
    NSArray *deps = version[@"dependencies"];
    NSMutableArray *requiredDeps = [NSMutableArray array];
    for (NSDictionary *dep in deps) {
        if ([dep[@"dependency_type"] isEqualToString:@"required"]) {
            [requiredDeps addObject:dep];
        }
    }
    
    NSString *modTitle = _downloadMod[@"title"] ?: @"Mod";
    NSString *versionNumber = version[@"version_number"] ?: @"";
    NSString *message = [NSString stringWithFormat:@"Install %@ %@ to current profile?", modTitle, versionNumber];
    
    if (requiredDeps.count > 0) {
        message = [message stringByAppendingString:[NSString stringWithFormat:@"\n\nThis mod requires %ld dependencies:", (long)requiredDeps.count]];
        for (NSDictionary *dep in requiredDeps) {
            message = [message stringByAppendingString:[NSString stringWithFormat:@"\n• %@", dep[@"project_id"] ?: @"Unknown"]];
        }
    }
    
    // Check if mod is already installed
    BOOL isInstalled = [self isModInstalled:version];
    NSString *installTitle = isInstalled ? @"Cài đặt lại" : @"Install to Profile";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:modTitle message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:installTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf installModWithDependencies:version];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Download Only" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf downloadModOnly:version];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)isModInstalled:(NSDictionary *)version {
    NSString *filename = version[@"filename"] ?: @"";
    if (filename.length == 0) return NO;
    
    NSString *mcVersion = VersionDirectoryManager.shared.currentVersion;
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    if (profile && profile.mcVersion) {
        mcVersion = profile.mcVersion;
    }
    
    NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:mcVersion];
    NSString *modPath = [modsDir stringByAppendingPathComponent:filename];
    if (![modPath hasSuffix:@".jar"]) {
        modPath = [modPath stringByAppendingPathExtension:@"jar"];
    }
    
    return [[NSFileManager defaultManager] fileExistsAtPath:modPath];
}

- (void)installModWithDependencies:(NSDictionary *)version {
    _dependencyInstallTasks = [NSMutableArray array];
    
    // First, install dependencies
    NSArray *deps = version[@"dependencies"];
    NSMutableArray *requiredDeps = [NSMutableArray array];
    for (NSDictionary *dep in deps) {
        if ([dep[@"dependency_type"] isEqualToString:@"required"]) {
            [requiredDeps addObject:dep];
        }
    }
    
    if (requiredDeps.count > 0) {
        _dependencyOverlay = [DownloadProgressOverlay showInView:self.view title:@"Installing Dependencies"];
        [_dependencyOverlay updateProgress:0 message:@"Loading dependencies..."];
        
        __weak typeof(self) weakSelf = self;
        [self installDependencies:requiredDeps index:0 version:version completion:^(BOOL success) {
            if (success) {
                [weakSelf installMainMod:version];
            } else {
                [_dependencyOverlay dismiss];
            }
        }];
    } else {
        [self installMainMod:version];
    }
}

- (void)installDependencies:(NSArray *)deps index:(NSInteger)index version:(NSDictionary *)mainVersion completion:(void(^)(BOOL))completion {
    if (index >= deps.count) {
        completion(YES);
        return;
    }
    
    NSDictionary *dep = deps[index];
    NSString *depProjectId = dep[@"project_id"];
    if (!depProjectId) {
        [self installDependencies:deps index:index + 1 version:mainVersion completion:completion];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [ModrinthService.shared loadProjectDetails:depProjectId completion:^(NSDictionary *project, NSError *error) {
        if (error || !project) {
            [weakSelf installDependencies:deps index:index + 1 version:mainVersion completion:completion];
            return;
        }
        
        [ModrinthService.shared loadProjectVersions:depProjectId completion:^(NSArray<NSDictionary *> *depVersions, NSError *vError) {
            if (vError || depVersions.count == 0) {
                [weakSelf installDependencies:deps index:index + 1 version:mainVersion completion:completion];
                return;
            }
            
            VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
            NSString *targetVersion = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
            NSString *targetLoader = [profile.modLoader lowercaseString] ?: @"";
            
            NSDictionary *bestVer = nil;
            for (NSDictionary *dv in depVersions) {
                BOOL vm = targetVersion.length == 0 || [dv[@"game_versions"] containsObject:targetVersion];
                BOOL lm = targetLoader.length == 0 || [targetLoader isEqualToString:@"vanilla"] || [dv[@"loaders"] containsObject:targetLoader];
                if (vm && lm) {
                    bestVer = dv;
                    break;
                }
            }
            if (!bestVer) bestVer = depVersions.firstObject;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *depTitle = project[@"title"] ?: @"Unknown";
                [_dependencyOverlay updateProgress:(float)index / deps.count message:[NSString stringWithFormat:@"Installing %@...", depTitle]];
                
                NSString *url = bestVer[@"url"];
                NSString *filename = bestVer[@"filename"] ?: @"mod.jar";
                NSString *mcVersion = VersionDirectoryManager.shared.currentVersion;
                if (mcVersion.length == 0) {
                    mcVersion = VersionDirectoryManager.shared.currentProfile.mcVersion ?: @"1.21.4";
                }
                
                NSURLSessionDownloadTask *task = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
                    // Progress handled by overlay
                } completion:^(NSString *path, NSError *dlError) {
                    if (path) {
                        NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:mcVersion];
                        NSString *targetPath = [modsDir stringByAppendingPathComponent:filename];
                        if (![targetPath hasSuffix:@".jar"]) targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
                        [[NSFileManager defaultManager] createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
                        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
                        [[NSFileManager defaultManager] moveItemAtPath:path toPath:targetPath error:nil];
                    }
                    [weakSelf installDependencies:deps index:index + 1 version:mainVersion completion:completion];
                }];
                [weakSelf.dependencyInstallTasks addObject:task];
            });
        }];
    }];
}

- (void)installMainMod:(NSDictionary *)version {
    NSString *url = version[@"url"];
    NSString *filename = version[@"filename"] ?: @"mod.jar";
    NSString *mcVersion = VersionDirectoryManager.shared.currentVersion;
    if (mcVersion.length == 0) {
        mcVersion = VersionDirectoryManager.shared.currentProfile.mcVersion ?: @"1.21.4";
    }
    
    __weak typeof(self) weakSelf = self;
    if (!_dependencyOverlay) {
        _dependencyOverlay = [DownloadProgressOverlay showInView:self.view title:@"Installing Mod"];
    }
    [_dependencyOverlay updateProgress:0 message:@"Downloading main mod..."];
    
    NSURLSessionDownloadTask *task = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [_dependencyOverlay updateProgress:p message:[NSString stringWithFormat:@"Downloading %@", filename]];
    } completion:^(NSString *path, NSError *dlError) {
        if (path) {
            [_dependencyOverlay updateProgress:1.0 message:@"Copying to profile..."];
            NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:mcVersion];
            NSString *targetPath = [modsDir stringByAppendingPathComponent:filename];
            if (![targetPath hasSuffix:@".jar"]) targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
            [[NSFileManager defaultManager] createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:targetPath error:&moveError];
            
            if (moveError == nil) {
                [_dependencyOverlay finishWithMessage:@"Installed!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [_dependencyOverlay dismiss];
                    showDialog(@"Installed", [NSString stringWithFormat:@"%@ installed to profile.", _downloadMod[@"title"]]);
                    [weakSelf.tableView reloadData];
                });
            } else {
                [_dependencyOverlay finishWithMessage:@"Install failed"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [_dependencyOverlay dismiss];
                });
            }
        } else {
            [_dependencyOverlay finishWithMessage:@"Failed"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [_dependencyOverlay dismiss];
            });
        }
    }];
    [_dependencyInstallTasks addObject:task];
}

- (void)downloadModOnly:(NSDictionary *)version {
    NSString *url = version[@"url"];
    NSString *filename = version[@"filename"] ?: @"mod.jar";
    
    NSString *downloadsPath = VersionDirectoryManager.shared.downloadsPath;
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadsPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *targetPath = [downloadsPath stringByAppendingPathComponent:filename];
    
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Downloading Mod"];
    [overlay updateProgress:0 message:@"Downloading..."];
    
    __weak typeof(self) weakSelf = self;
    [overlay setCancelBlock:^{
        [weakSelf.currentDownloadTask cancel];
        weakSelf.currentDownloadTask = nil;
    }];
    weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [overlay updateProgress:p message:[NSString stringWithFormat:@"Downloading %@", filename]];
    } completion:^(NSString *dlPath, NSError *error) {
        if (dlPath) {
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:dlPath toPath:targetPath error:nil];
            [overlay finishWithMessage:@"Downloaded!"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [overlay dismiss];
                showDialog(@"Downloaded", [NSString stringWithFormat:@"%@ saved to Downloads.", filename]);
            });
        } else {
            [overlay finishWithMessage:@"Failed"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [overlay dismiss];
            });
        }
    }];
}

- (void)dealloc {
    [_timeoutTimer invalidate];
    [_currentDownloadTask cancel];
    for (NSURLSessionDownloadTask *task in _dependencyInstallTasks) {
        [task cancel];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
