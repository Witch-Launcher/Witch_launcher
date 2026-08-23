#import "ShaderListViewController.h"
#import "ThemeManager.h"
#import "MainCoordinator.h"
#import "ModrinthService.h"
#import "ModDetailViewController.h"
#import "AmethystProjectCell.h"
#import "HapticManager.h"
#import "DownloadProgressOverlay.h"
#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "ios_uikit_bridge.h"
#import "AmethystBlurView.h"

@interface ShaderListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UISegmentedControl *typeControl;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *shaders;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) NSString *currentCategoryFilter;

@property (nonatomic) NSMutableDictionary *pageCache;
@property (nonatomic) NSMutableArray *pageOffsets;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL isLoadingMore;
@property (nonatomic) BOOL isRestoringPage;
@property (nonatomic) BOOL adjustingContentOffset;
@property (nonatomic) NSString *currentQuery;
@end

@implementation ShaderListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [AmethystBlurView installInView:self.view];
    _currentCategoryFilter = @"";
    _pageCache = [NSMutableDictionary dictionary];
    _pageOffsets = [NSMutableArray array];
    _hasMore = YES;
    _isLoadingMore = NO;
    _shaders = [NSMutableArray array];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [self updateColors];
    [self loadShadersWithQuery:@"" offset:0];
}

- (void)setup {
    self.view.clipsToBounds = YES;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.text = @"Shaders";
    [self.view addSubview:_titleLabel];

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Search shader packs...";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:_searchBar];

    _typeControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Iris", @"Optifine"]];
    _typeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _typeControl.selectedSegmentIndex = 0;
    [_typeControl addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_typeControl];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = @"No shader packs found.\nTry a different search.";
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 64;
    _tableView.separatorInset = UIEdgeInsetsZero;
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pullToRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[AmethystProjectCell class] forCellReuseIdentifier:@"ShaderCell"];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [_searchBar.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [_typeControl.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:8],
        [_typeControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_typeControl.widthAnchor constraintGreaterThanOrEqualToConstant:280],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

        [_tableView.topAnchor constraintEqualToAnchor:_typeControl.bottomAnchor constant:8],
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
    _titleLabel.textColor = theme.primaryTextColor;
    _searchBar.searchTextField.textColor = theme.primaryTextColor;
    _searchBar.tintColor = theme.accentColor;
    _typeControl.selectedSegmentTintColor = theme.accentColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
}

- (void)typeChanged {
    switch (_typeControl.selectedSegmentIndex) {
        case 1: _currentCategoryFilter = @"iris"; break;
        case 2: _currentCategoryFilter = @"optifine"; break;
        default: _currentCategoryFilter = @""; break;
    }
    [self loadShadersWithQuery:_searchBar.text ?: @"" offset:0];
}

- (void)loadShadersWithQuery:(NSString *)query offset:(NSInteger)offset {
    if (offset == 0) {
        _hasMore = YES;
        _currentQuery = query;
        [_pageCache removeAllObjects];
        [_pageOffsets removeAllObjects];
        [_spinner startAnimating];
        _tableView.hidden = YES;
        _emptyLabel.hidden = YES;
    } else {
        _isLoadingMore = YES;
    }

    [ModrinthService.shared searchProjectsWithType:@"shader" query:query offset:offset limit:50 categoryFilter:_currentCategoryFilter loaderFilter:nil gameVersionFilter:nil completion:^(NSArray<NSDictionary *> *results, NSError *error) {
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
                self.shaders = [results mutableCopy];
            } else {
                [self.shaders addObjectsFromArray:results];
            }
            self.tableView.hidden = NO;
            self.emptyLabel.hidden = self.shaders.count > 0;
            [self.tableView reloadData];
            [self trimShadersIfNeeded];
        }
    }];
}

- (void)trimShadersIfNeeded {
    if (self.shaders.count <= 150) return;
    NSInteger removeCount = ((self.shaders.count - 150) / 50) * 50;
    if (removeCount <= 0) return;
    [self.shaders removeObjectsInRange:NSMakeRange(0, removeCount)];
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

- (void)loadMoreShaders {
    if (_isLoadingMore || !_hasMore || _isRestoringPage) return;
    NSInteger nextOffset = _pageOffsets.count > 0 ? [_pageOffsets.lastObject integerValue] + 50 : 50;
    [self loadShadersWithQuery:_currentQuery ?: @"" offset:nextOffset];
}

- (void)restorePreviousShaderPage {
    if (_pageOffsets.count == 0 || _isRestoringPage || _isLoadingMore) return;
    _isRestoringPage = YES;
    NSNumber *firstOffset = _pageOffsets.firstObject;
    if ([firstOffset integerValue] <= 0) { _isRestoringPage = NO; return; }
    NSNumber *prevOffset = @([firstOffset integerValue] - 50);
    NSArray *cachedPage = _pageCache[prevOffset];
    if (!cachedPage) { _isRestoringPage = NO; return; }

    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, cachedPage.count)];
    [self.shaders insertObjects:cachedPage atIndexes:indexes];
    [_pageOffsets insertObject:prevOffset atIndex:0];

    CGFloat offsetY = self.tableView.contentOffset.y;
    self.adjustingContentOffset = YES;
    [self.tableView reloadData];
    self.tableView.contentOffset = CGPointMake(0, offsetY + cachedPage.count * 64);
    self.adjustingContentOffset = NO;
    _isRestoringPage = NO;
}

#pragma mark - Scroll (pagination)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;

    if (offsetY > contentHeight - frameHeight - 150 && _hasMore && !_isLoadingMore && !_isRestoringPage && _shaders.count > 0 && scrollView.isDragging) {
        [self loadMoreShaders];
    }
    if (offsetY < 80 && !_isLoadingMore && !_isRestoringPage && _pageOffsets.count > 0 && scrollView.isDragging) {
        if ([_pageOffsets.firstObject integerValue] > 0) {
            [self restorePreviousShaderPage];
        }
    }
}

// Load one more page when a flick/drag releases near the bottom.
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) return;
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _shaders.count > 0) {
        [self loadMoreShaders];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _shaders.count > 0) {
        [self loadMoreShaders];
    }
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self loadShadersWithQuery:searchBar.text ?: @"" offset:0];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self loadShadersWithQuery:@"" offset:0];
    }
}

- (void)pullToRefresh {
    [self loadShadersWithQuery:_searchBar.text ?: @"" offset:0];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _shaders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AmethystProjectCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ShaderCell" forIndexPath:indexPath];

    NSDictionary *shader = _shaders[indexPath.row];
    NSNumber *downloads = shader[@"downloads"];
    NSString *dlStr = downloads ? [NSString stringWithFormat:@"↑ %@", [self formatNumber:downloads]] : @"";
    NSString *subtitle = [NSString stringWithFormat:@"%@  |  %@", dlStr, shader[@"author"] ?: @""];

    [cell configureWithTitle:shader[@"title"] subtitle:subtitle iconURL:shader[@"icon_url"] placeholder:@"paintpalette"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];
    NSDictionary *shader = _shaders[indexPath.row];
    ModDetailViewController *detail = [[ModDetailViewController alloc] initWithMod:shader];
    detail.coordinator = self.coordinator;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:detail];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
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