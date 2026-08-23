#import "ResourcePackListViewController.h"
#import "ThemeManager.h"
#import "ModrinthService.h"
#import "AmethystProjectCell.h"
#import "HapticManager.h"
#import "DownloadProgressOverlay.h"
#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "ios_uikit_bridge.h"
#import "AmethystBlurView.h"

@interface ResourcePackListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *packs;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UILabel *errorLabel;
@property (nonatomic) NSTimer *timeoutTimer;

@property (nonatomic) NSMutableDictionary *pageCache;
@property (nonatomic) NSMutableArray *pageOffsets;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL isLoadingMore;
@property (nonatomic) BOOL adjustingContentOffset;
@property (nonatomic) NSString *currentQuery;
@end

@implementation ResourcePackListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [AmethystBlurView installInView:self.view];
    _pageCache = [NSMutableDictionary dictionary];
    _pageOffsets = [NSMutableArray array];
    _hasMore = YES;
    _isLoadingMore = NO;
    _packs = [NSMutableArray array];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [self updateColors];
    [self loadPacksWithQuery:@"" offset:0];
}

- (void)setup {
    self.navigationItem.title = @"Resource Packs";

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Search resource packs...";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:_searchBar];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = @"No resource packs found.\nTry a different search.";
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _errorLabel = [[UILabel alloc] init];
    _errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _errorLabel.text = @"";
    _errorLabel.numberOfLines = 0;
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _errorLabel.hidden = YES;
    [self.view addSubview:_errorLabel];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 64;
    _tableView.separatorInset = UIEdgeInsetsZero;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[AmethystProjectCell class] forCellReuseIdentifier:@"PackCell"];

    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

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

        [_tableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    if ([AmethystBlurView blurEnabled]) {
        self.view.backgroundColor = [UIColor clearColor];
    } else {
        self.view.backgroundColor = theme.contentBackgroundColor;
    }
    _searchBar.searchTextField.textColor = theme.primaryTextColor;
    _searchBar.tintColor = theme.accentColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
    _errorLabel.textColor = theme.errorColor;
}

- (void)loadPacksWithQuery:(NSString *)query offset:(NSInteger)offset {
    if (offset == 0) {
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
                weakSelf.errorLabel.hidden = NO;
            }
        }];
    } else {
        _isLoadingMore = YES;
    }

    [ModrinthService.shared searchProjectsWithType:@"resourcepack" query:query offset:offset limit:50 categoryFilter:nil loaderFilter:nil gameVersionFilter:nil completion:^(NSArray<NSDictionary *> *results, NSError *error) {
        [self.timeoutTimer invalidate];
        [self.spinner stopAnimating];
        self.isLoadingMore = NO;
        if (results) {
            self.hasMore = results.count >= 50;
            self.pageCache[@(offset)] = results;
            if (![self.pageOffsets containsObject:@(offset)]) {
                [self.pageOffsets addObject:@(offset)];
                [self.pageOffsets sortUsingSelector:@selector(compare:)];
            }
            if (offset == 0) {
                self.packs = [results mutableCopy];
            } else {
                [self.packs addObjectsFromArray:results];
            }
            self.tableView.hidden = NO;
            self.emptyLabel.hidden = self.packs.count > 0;
            [self.tableView reloadData];
            [self trimPacksIfNeeded];
        } else if (error && offset == 0) {
            self.errorLabel.text = error.localizedDescription ?: @"Failed to load resource packs.";
            self.errorLabel.hidden = NO;
        }
    }];
}

- (void)trimPacksIfNeeded {
    if (self.packs.count <= 150) return;
    NSInteger removeCount = ((self.packs.count - 150) / 50) * 50;
    if (removeCount <= 0) return;
    [self.packs removeObjectsInRange:NSMakeRange(0, removeCount)];
    while (self.pageOffsets.count > 0) {
        NSNumber *firstOffset = self.pageOffsets.firstObject;
        NSArray *page = self.pageCache[firstOffset];
        if (!page) { [self.pageOffsets removeObjectAtIndex:0]; continue; }
        if (page.count <= removeCount) {
            removeCount -= page.count;
            [self.pageOffsets removeObjectAtIndex:0];
        } else {
            break;
        }
    }
}

- (void)loadMorePacks {
    if (_isLoadingMore || !_hasMore) return;
    NSInteger nextOffset = _pageOffsets.count > 0 ? [_pageOffsets.lastObject integerValue] + 50 : 50;
    [self loadPacksWithQuery:_currentQuery ?: @"" offset:nextOffset];
}

#pragma mark - Scroll (pagination)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;

    if (offsetY > contentHeight - frameHeight - 150 && _hasMore && !_isLoadingMore && _packs.count > 0 && scrollView.isDragging) {
        [self loadMorePacks];
    }
}

// Load one more page when a flick/drag releases near the bottom.
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) return;
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _packs.count > 0) {
        [self loadMorePacks];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _packs.count > 0) {
        [self loadMorePacks];
    }
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self loadPacksWithQuery:searchBar.text ?: @"" offset:0];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self loadPacksWithQuery:@"" offset:0];
    }
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _packs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AmethystProjectCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PackCell" forIndexPath:indexPath];

    NSDictionary *pack = _packs[indexPath.row];
    NSNumber *downloads = pack[@"downloads"];
    NSString *dlStr = downloads ? [NSString stringWithFormat:@"↑ %@", [self formatNumber:downloads]] : @"";
    NSString *subtitle = [NSString stringWithFormat:@"%@  |  %@", dlStr, pack[@"author"] ?: @""];

    [cell configureWithTitle:pack[@"title"] subtitle:subtitle iconURL:pack[@"icon_url"] placeholder:@"paintpalette"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];
    NSDictionary *pack = _packs[indexPath.row];

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Loading Versions"];
    [overlay updateProgress:0 message:@"Fetching available versions..."];

    [ModrinthService.shared loadProjectVersions:pack[@"project_id"] completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        [overlay dismiss];
        if (versions.count == 0) return;

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:pack[@"title"]
                                                                        message:@"Select a version to install"
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSDictionary *ver in versions) {
            NSString *label = [NSString stringWithFormat:@"%@  [%@]", ver[@"name"], [ver[@"game_versions"] componentsJoinedByString:@", "]];
            [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *url = ver[@"url"];
                NSString *filename = ver[@"filename"] ?: @"pack.zip";
                if (url.length > 0) {
                    [self installResourcePack:url name:filename];
                }
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
    }];
}

- (void)installResourcePack:(NSString *)urlString name:(NSString *)name {
    NSString *version = VersionDirectoryManager.shared.currentVersion ?: @"";
    NSString *labelSuffix = version.length > 0 ? [NSString stringWithFormat:@" to %@", version] : @" to Downloads";

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:[NSString stringWithFormat:@"Installing Resource Pack%@", labelSuffix]];
    [overlay updateProgress:0 message:@"Downloading..."];

    [DownloadManager.shared downloadResourcePack:urlString name:name version:version completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [overlay finishWithMessage:@"Installed!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    showDialog(@"Installed", [NSString stringWithFormat:@"%@ installed to resourcepacks.", name]);
                });
            } else {
                [overlay finishWithMessage:@"Failed"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    showDialog(@"Error", error.localizedDescription ?: @"Download failed.");
                });
            }
        });
    }];
}

- (NSString *)formatNumber:(NSNumber *)num {
    long long n = num.longLongValue;
    if (n >= 1000000) return [NSString stringWithFormat:@"%.1fM", n / 1000000.0];
    if (n >= 1000) return [NSString stringWithFormat:@"%.1fK", n / 1000.0];
    return [NSString stringWithFormat:@"%lld", n];
}

- (void)dealloc {
    [_timeoutTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
