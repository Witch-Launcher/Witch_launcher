#import "ModpackListViewController.h"
#import "ThemeManager.h"
#import "MainCoordinator.h"
#import "ModrinthService.h"
#import "ModDetailViewController.h"
#import "AmethystProjectCell.h"
#import "HapticManager.h"
#import "DownloadProgressOverlay.h"
#import "MrpackInstaller.h"
#import "ios_uikit_bridge.h"
#import "AmethystBlurView.h"
#import "utils.h"
#import "CurseForgeService.h"
#import "LauncherPreferences.h"

@interface ModpackListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIDocumentPickerDelegate>
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIButton *importButton;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *modpacks;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;

@property (nonatomic) NSMutableDictionary *pageCache;
@property (nonatomic) NSMutableArray *pageOffsets;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL isLoadingMore;
@property (nonatomic) BOOL isRestoringPage;
@property (nonatomic) BOOL adjustingContentOffset;
@property (nonatomic) NSString *currentQuery;
@property (nonatomic) NSInteger pageSize;
@property (nonatomic) NSString *selectedSource;
@property (nonatomic) UISegmentedControl *sourceControl;
@property (nonatomic) NSLayoutConstraint *sourceControlWidthConstraint;
@end

@implementation ModpackListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [AmethystBlurView installInView:self.view];
    _selectedSource = @"modrinth";
    _pageCache = [NSMutableDictionary dictionary];
    _pageOffsets = [NSMutableArray array];
    _hasMore = YES;
    _isLoadingMore = NO;
    _modpacks = [NSMutableArray array];
    _pageSize = 50;
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [self updateColors];
    [self loadModpacksWithQuery:@"" offset:0];
}

- (void)setup {
    self.view.clipsToBounds = YES;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.text = localize(@"Modpacks", nil);
    [self.view addSubview:_titleLabel];

    _importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_importButton setTitle:localize(@"Import .mrpack", nil) forState:UIControlStateNormal];
    [_importButton setImage:[UIImage systemImageNamed:@"square.and.arrow.down"] forState:UIControlStateNormal];
    _importButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [_importButton addTarget:self action:@selector(importMrpack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_importButton];

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.placeholder = localize(@"download.search.modpacks", nil);
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:_searchBar];

    _sourceControl = [[UISegmentedControl alloc] initWithItems:@[@"Modrinth", @"CurseForge"]];
    _sourceControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sourceControl.selectedSegmentIndex = 0;
    _sourceControl.selectedSegmentTintColor = ThemeManager.shared.accentColor;
    _sourceControl.layer.cornerRadius = 8;
    _sourceControl.clipsToBounds = YES;
    [_sourceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: ThemeManager.shared.primaryTextColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [_sourceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
    [_sourceControl addTarget:self action:@selector(sourceChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_sourceControl];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = localize(@"download.empty.modpacks", nil);
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

    [_tableView registerClass:[AmethystProjectCell class] forCellReuseIdentifier:@"ModpackCell"];

    _sourceControlWidthConstraint = [_sourceControl.widthAnchor constraintEqualToConstant:160];
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [_importButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_importButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_importButton.heightAnchor constraintEqualToConstant:30],

        [_searchBar.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_searchBar.trailingAnchor constraintEqualToAnchor:_sourceControl.leadingAnchor constant:-8],

        [_sourceControl.centerYAnchor constraintEqualToAnchor:_searchBar.centerYAnchor],
        [_sourceControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        _sourceControlWidthConstraint,
        [_sourceControl.heightAnchor constraintEqualToConstant:32],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

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
    _titleLabel.textColor = theme.primaryTextColor;
    _importButton.tintColor = theme.accentColor;
    _searchBar.searchTextField.textColor = theme.primaryTextColor;
    _searchBar.tintColor = theme.accentColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
    _sourceControl.selectedSegmentTintColor = theme.accentColor;
    [_sourceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: theme.primaryTextColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [_sourceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
}

#pragma mark - Import local .mrpack

- (void)importMrpack {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    [url startAccessingSecurityScopedResource];

    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *importDir = [docsDir stringByAppendingPathComponent:@"ImportedModpacks"];
    [[NSFileManager defaultManager] createDirectoryAtPath:importDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *destPath = [importDir stringByAppendingPathComponent:url.lastPathComponent];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        NSString *base = [url.lastPathComponent stringByDeletingPathExtension];
        NSString *ext = [url.lastPathComponent pathExtension];
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        destPath = [importDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.%@", base, timestamp, ext]];
    }

    NSError *error = nil;
    if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&error]) {
        [url stopAccessingSecurityScopedResource];
        // The installer parses modrinth.index.json and downloads every file listed
        // inside, extracts overrides and sets up loaders, exactly like a Modrinth
        // download. The imported copy is deleted on completion.
        [MrpackInstaller installMrpackAtPath:destPath title:nil hostVC:self removeOnCompletion:YES];
    } else {
        [url stopAccessingSecurityScopedResource];
        showDialog(@"Import Failed", error.localizedDescription ?: @"Unknown error");
    }
}

- (void)sourceChanged {
    _selectedSource = _sourceControl.selectedSegmentIndex == 0 ? @"modrinth" : @"curseforge";
    [self loadModpacksWithQuery:_searchBar.text ?: @"" offset:0];
}

- (void)loadModpacksWithQuery:(NSString *)query offset:(NSInteger)offset {
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

    void (^handleResults)(NSArray *, NSError *) = ^(NSArray<NSDictionary *> *results, NSError *error) {
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
                self.modpacks = [results mutableCopy];
            } else {
                [self.modpacks addObjectsFromArray:results];
            }
            self.tableView.hidden = NO;
            self.emptyLabel.hidden = self.modpacks.count > 0;
            [self.tableView reloadData];
            [self trimModpacksIfNeeded];
        }
    };
    if ([_selectedSource isEqualToString:@"curseforge"]) {
        [CurseForgeService.shared searchProjectsWithClassId:4471 query:query offset:offset limit:50 loaderFilter:nil gameVersionFilter:nil completion:handleResults];
    } else {
        [ModrinthService.shared searchProjectsWithType:@"modpack" query:query offset:offset limit:50 categoryFilter:nil loaderFilter:nil gameVersionFilter:nil completion:handleResults];
    }
}

- (void)trimModpacksIfNeeded {
    NSInteger maxVisible = 60;
    if (self.modpacks.count <= maxVisible) return;

    NSInteger pagesToRemove = (self.modpacks.count - maxVisible) / self.pageSize;
    if (pagesToRemove <= 0) return;

    NSInteger removeCount = pagesToRemove * self.pageSize;
    [self.modpacks removeObjectsInRange:NSMakeRange(0, removeCount)];

    CGFloat offsetY = self.tableView.contentOffset.y;
    CGFloat adjustedOffset = offsetY - removeCount * 64;
    if (adjustedOffset < 0) adjustedOffset = 0;

    // Only drop the offsets that left the screen; keep cached pages so
    // restorePreviousModpackPage can put the trimmed rows back on scroll-up.
    NSInteger remainingRemove = removeCount;
    while (self.pageOffsets.count > 0) {
        NSNumber *firstOffset = self.pageOffsets.firstObject;
        NSArray *page = self.pageCache[firstOffset];
        if (!page) { [self.pageOffsets removeObjectAtIndex:0]; continue; }
        if (page.count <= remainingRemove) {
            remainingRemove -= page.count;
            [self.pageOffsets removeObjectAtIndex:0];
        } else {
            break;
        }
    }

    // Programmatic offset changes must not re-trigger loadMore/restore.
    self.adjustingContentOffset = YES;
    self.tableView.contentOffset = CGPointMake(0, adjustedOffset);
    self.adjustingContentOffset = NO;
    [self.tableView reloadData];
}

- (void)loadMoreModpacks {
    if (_isLoadingMore || !_hasMore || _isRestoringPage) return;
    NSInteger nextOffset = _pageOffsets.count > 0 ? [_pageOffsets.lastObject integerValue] + 50 : 50;
    [self loadModpacksWithQuery:_currentQuery ?: @"" offset:nextOffset];
}

- (void)restorePreviousModpackPage {
    if (_pageOffsets.count == 0 || _isRestoringPage || _isLoadingMore) return;
    _isRestoringPage = YES;
    NSNumber *firstOffset = _pageOffsets.firstObject;
    if ([firstOffset integerValue] <= 0) { _isRestoringPage = NO; return; }
    NSNumber *prevOffset = @([firstOffset integerValue] - 50);
    NSArray *cachedPage = _pageCache[prevOffset];
    if (!cachedPage) { _isRestoringPage = NO; return; }

    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, cachedPage.count)];
    [self.modpacks insertObjects:cachedPage atIndexes:indexes];
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

    if (offsetY > contentHeight - frameHeight - 150 && _hasMore && !_isLoadingMore && !_isRestoringPage && _modpacks.count > 0 && scrollView.isDragging) {
        [self loadMoreModpacks];
    }
    if (offsetY < 80 && !_isLoadingMore && !_isRestoringPage && _pageOffsets.count > 0 && scrollView.isDragging) {
        if ([_pageOffsets.firstObject integerValue] > 0) {
            [self restorePreviousModpackPage];
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
    if (offsetY > contentHeight - frameHeight - 150 && _modpacks.count > 0) {
        [self loadMoreModpacks];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _tableView || _adjustingContentOffset || _isLoadingMore || !_hasMore) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (offsetY > contentHeight - frameHeight - 150 && _modpacks.count > 0) {
        [self loadMoreModpacks];
    }
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self loadModpacksWithQuery:searchBar.text ?: @"" offset:0];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self loadModpacksWithQuery:@"" offset:0];
    }
}

- (void)pullToRefresh {
    [self loadModpacksWithQuery:_searchBar.text ?: @"" offset:0];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _modpacks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AmethystProjectCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModpackCell" forIndexPath:indexPath];

    NSDictionary *mp = _modpacks[indexPath.row];
    NSNumber *downloads = mp[@"downloads"];
    NSString *dlStr = downloads ? [NSString stringWithFormat:@"\u2191 %@", [self formatNumber:downloads]] : @"";
    NSString *subtitle = [NSString stringWithFormat:@"%@  |  %@", dlStr, mp[@"author"] ?: @""];

    [cell configureWithTitle:mp[@"title"] subtitle:subtitle iconURL:mp[@"icon_url"] placeholder:@"square.stack.3d.up"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];
    NSDictionary *mp = _modpacks[indexPath.row];
    ModDetailViewController *detail = [[ModDetailViewController alloc] initWithMod:mp];
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
