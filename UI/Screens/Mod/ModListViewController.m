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

        [NSLayoutConstraint activateConstraints:@[
            [_projectIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
            [_projectIcon.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_projectIcon.widthAnchor constraintEqualToConstant:48],
            [_projectIcon.heightAnchor constraintEqualToConstant:48],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_projectIcon.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],

            [_downloadsLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_downloadsLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],

            [_descLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_descLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_descLabel.topAnchor constraintEqualToAnchor:_downloadsLabel.bottomAnchor constant:1],

            [_tagsStack.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
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
}

- (void)configureWithDict:(NSDictionary *)mod {
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

- (void)dealloc {
    [_timeoutTimer invalidate];
    [_currentDownloadTask cancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end