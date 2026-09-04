#import "CrashScreenViewController.h"
#import "CrashLogAnalyzer.h"
#import "ThemeManager.h"
#import "CustomButton.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import "WitchAIChatViewController.h"
#import "WitchLogReporter.h"
#import "WitchLogIndex.h"
#import <limits.h>

static NSString *categoryLocalizedKey(CrashLogCategory category) {
    switch (category) {
        case CrashLogCategoryModConflict: return @"crash.screen.category.mod";
        case CrashLogCategoryError: return @"crash.screen.category.error";
        default: return @"crash.screen.category.raw";
    }
}

typedef NS_ENUM(NSInteger, LogViewMode) {
    LogViewModeExcerpt = 0, // last 100 lines of current file
    LogViewModeFull,        // indexed whole file, virtualized rows
    LogViewModeResults,     // search hits (tap to jump)
};

static const NSUInteger kWindowRadius = 200;   // lines before target
static const NSUInteger kWindowSize = 800;     // lines per window fetch
static const NSUInteger kCacheKeep = 2400;     // max cached lines
static const NSUInteger kMaxSearchHits = 2000;

@interface CrashScreenViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching>
@property (nonatomic) int exitCode;
@property (nonatomic) BOOL showingFullLog;
@property (nonatomic, strong) CrashLogAnalyzerResult *analysis;

@property (nonatomic, strong) UIView *leftPanel;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *codeLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, strong) UIStackView *buttonRow;
@property (nonatomic, strong) CustomButton *shareButton;
@property (nonatomic, strong) CustomButton *toggleButton;
@property (nonatomic, strong) CustomButton *aiChatButton;
@property (nonatomic, strong) CustomButton *sendButton;
@property (nonatomic, strong) CustomButton *closeButton;

@property (nonatomic, strong) UISearchBar *logSearchBar;
@property (nonatomic, strong) UILabel *matchLabel;
@property (nonatomic, strong) UISegmentedControl *fileSegments;
@property (nonatomic, strong) UIStackView *navRow;
@property (nonatomic, strong) CustomButton *topButton;
@property (nonatomic, strong) CustomButton *bottomButton;
@property (nonatomic, strong) CustomButton *goButton;

@property (nonatomic, strong) UITableView *logTable;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Log engine state. Heavy objects live here; UI only holds a window.
@property (nonatomic) LogViewMode viewMode;
@property (nonatomic, copy) NSString *currentPath;
@property (nonatomic, strong) WitchLogFileInfo *fileInfo;   // lite (excerpt) or indexed (full)
@property (nonatomic, strong) WitchLogReader *reader;
@property (nonatomic, strong) WitchLogIndexer *indexer;
@property (nonatomic) BOOL indexing;
@property (nonatomic, copy) NSArray<NSString *> *excerptLines;
@property (nonatomic, copy) NSArray<NSString *> *filteredExcerpt; // excerpt search
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *lineCache;
@property (nonatomic) NSUInteger totalLines;
@property (nonatomic) NSUInteger windowBase; // base line of cached window
@property (nonatomic) BOOL windowLoading;
@property (nonatomic) NSUInteger pendingLine;
@property (nonatomic) BOOL windowLoadQueued;
@property (nonatomic, copy) NSArray<NSNumber *> *hitLines;
@property (nonatomic, copy) NSArray<NSString *> *hitTexts;
@property (nonatomic, copy) NSString *searchQuery;
@property (atomic) NSUInteger searchSeq;
@end

@implementation CrashScreenViewController

- (instancetype)initWithExitCode:(int)code {
    self = [super init];
    if (self) {
        _exitCode = code;
        _showingFullLog = NO;
        _viewMode = LogViewModeExcerpt;
        _lineCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)shouldAutorotate {
    // Locking rotation prevents the freeze that happened when the crash
    // screen rotated after unlock (the frozen game surface below could not
    // relayout safely).
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return amethyst_orientation_mask();
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [UIApplication.sharedApplication.windows.firstObject windowScene].interfaceOrientation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [self updateColors];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearLineCache) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [self runAnalysis];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_indexer cancel];
    _searchSeq++;
}

#pragma mark - Setup

- (void)setupViews {
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;

    _leftPanel = [[UIView alloc] init];
    _leftPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_leftPanel];

    _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_leftPanel addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _titleLabel.text = localize(@"crash.screen.title", nil);
    [_leftPanel addSubview:_titleLabel];

    _codeLabel = [[UILabel alloc] init];
    _codeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _codeLabel.font = [UIFont monospacedDigitSystemFontOfSize:42 weight:UIFontWeightHeavy];
    [_leftPanel addSubview:_codeLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _categoryLabel.numberOfLines = 0;
    [_leftPanel addSubview:_categoryLabel];

    _versionLabel = [[UILabel alloc] init];
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    _versionLabel.text = [NSString stringWithFormat:@"Witch v%@", ver];
    [_leftPanel addSubview:_versionLabel];

    _buttonRow = [[UIStackView alloc] init];
    _buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    _buttonRow.axis = UILayoutConstraintAxisHorizontal;
    _buttonRow.spacing = 10;
    _buttonRow.alignment = UIStackViewAlignmentCenter;
    [self.view addSubview:_buttonRow];

    _shareButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.share", nil)];
    [_shareButton addTarget:self action:@selector(actionShare) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_shareButton];

    _toggleButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.toggle_full", nil)];
    [_toggleButton addTarget:self action:@selector(actionToggleLog) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_toggleButton];

    _aiChatButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.ai_chat", nil)];
    [_aiChatButton addTarget:self action:@selector(actionAIChat) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_aiChatButton];

    _sendButton = [[CustomButton alloc] initWithStyle:CustomButtonStylePrimary title:localize(@"crash.screen.send", nil)];
    [_sendButton addTarget:self action:@selector(actionSendToDiscord) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_sendButton];

    _closeButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleDestructive title:localize(@"crash.screen.close", nil)];
    [_closeButton addTarget:self action:@selector(actionClose) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_closeButton];

    _fileSegments = [[UISegmentedControl alloc] initWithItems:@[
        localize(@"crash.screen.file.log", nil),
        localize(@"crash.screen.file.crash", nil),
        localize(@"crash.screen.file.hserr", nil),
    ]];
    _fileSegments.translatesAutoresizingMaskIntoConstraints = NO;
    _fileSegments.selectedSegmentIndex = 0;
    [_fileSegments addTarget:self action:@selector(actionSwitchFile) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_fileSegments];

    _logSearchBar = [[UISearchBar alloc] init];
    _logSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _logSearchBar.placeholder = localize(@"crash.screen.search_placeholder", nil);
    _logSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    _logSearchBar.delegate = self;
    [self.view addSubview:_logSearchBar];

    _navRow = [[UIStackView alloc] init];
    _navRow.translatesAutoresizingMaskIntoConstraints = NO;
    _navRow.axis = UILayoutConstraintAxisHorizontal;
    _navRow.spacing = 8;
    _navRow.alignment = UIStackViewAlignmentCenter;
    [self.view addSubview:_navRow];

    _topButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.top", nil)];
    [_topButton addTarget:self action:@selector(actionGoTop) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_topButton];

    _bottomButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.bottom", nil)];
    [_bottomButton addTarget:self action:@selector(actionGoBottom) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_bottomButton];

    _goButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.go_line", nil)];
    [_goButton addTarget:self action:@selector(actionGoLine) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_goButton];

    _matchLabel = [[UILabel alloc] init];
    _matchLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _matchLabel.font = [UIFont systemFontOfSize:12];
    _matchLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _matchLabel.textAlignment = NSTextAlignmentRight;
    [self.view addSubview:_matchLabel];

    _logTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _logTable.translatesAutoresizingMaskIntoConstraints = NO;
    _logTable.delegate = self;
    _logTable.dataSource = self;
    _logTable.prefetchDataSource = self;
    _logTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    _logTable.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    _logTable.layer.cornerRadius = 10;
    _logTable.layer.masksToBounds = YES;
    _logTable.estimatedRowHeight = 20;
    _logTable.rowHeight = UITableViewAutomaticDimension;
    [_logTable registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
    [self.view addSubview:_logTable];

    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.hidesWhenStopped = YES;
    _loadingIndicator.color = ThemeManager.shared.accentColor;
    [self.view addSubview:_loadingIndicator];

    [self layoutViews];
    [self updateNavVisibility];
}

- (void)layoutViews {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [_leftPanel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_leftPanel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [_leftPanel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
        [_leftPanel.widthAnchor constraintEqualToConstant:220],

        [_iconView.topAnchor constraintEqualToAnchor:_leftPanel.topAnchor constant:8],
        [_iconView.leadingAnchor constraintEqualToAnchor:_leftPanel.leadingAnchor constant:4],
        [_iconView.widthAnchor constraintEqualToConstant:40],
        [_iconView.heightAnchor constraintEqualToConstant:40],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:10],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconView.centerYAnchor],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_leftPanel.trailingAnchor],

        [_codeLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:28],
        [_codeLabel.leadingAnchor constraintEqualToAnchor:_leftPanel.leadingAnchor constant:4],
        [_codeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_leftPanel.trailingAnchor],

        [_categoryLabel.topAnchor constraintEqualToAnchor:_codeLabel.bottomAnchor constant:10],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_leftPanel.leadingAnchor constant:4],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor],

        [_versionLabel.bottomAnchor constraintEqualToAnchor:_leftPanel.bottomAnchor constant:-4],
        [_versionLabel.leadingAnchor constraintEqualToAnchor:_leftPanel.leadingAnchor constant:4],
        [_versionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_leftPanel.trailingAnchor],

        [_buttonRow.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [_buttonRow.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_buttonRow.leadingAnchor constraintGreaterThanOrEqualToAnchor:_leftPanel.trailingAnchor constant:16],

        [_fileSegments.topAnchor constraintEqualToAnchor:_buttonRow.bottomAnchor constant:8],
        [_fileSegments.leadingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor constant:16],
        [_fileSegments.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [_logSearchBar.topAnchor constraintEqualToAnchor:_fileSegments.bottomAnchor constant:4],
        [_logSearchBar.leadingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor constant:16],
        [_logSearchBar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_logSearchBar.heightAnchor constraintEqualToConstant:36],

        [_navRow.topAnchor constraintEqualToAnchor:_logSearchBar.bottomAnchor constant:2],
        [_navRow.leadingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor constant:16],
        [_navRow.heightAnchor constraintEqualToConstant:26],

        [_matchLabel.centerYAnchor constraintEqualToAnchor:_navRow.centerYAnchor],
        [_matchLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_matchLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_navRow.trailingAnchor constant:8],

        [_logTable.topAnchor constraintEqualToAnchor:_navRow.bottomAnchor constant:4],
        [_logTable.leadingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor constant:16],
        [_logTable.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_logTable.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],

        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)updateNavVisibility {
    BOOL full = (self.viewMode == LogViewModeFull);
    _navRow.hidden = !full;
    // File segments stay visible in every mode so users can switch files.
    _fileSegments.hidden = NO;
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.backgroundColor;
    _leftPanel.backgroundColor = theme.cardBackgroundColor;
    _iconView.tintColor = theme.errorColor;
    _titleLabel.textColor = theme.primaryTextColor;
    _codeLabel.textColor = theme.errorColor;
    _categoryLabel.textColor = theme.secondaryTextColor;
    _versionLabel.textColor = theme.secondaryTextColor;
    _loadingIndicator.color = theme.accentColor;
    _logTable.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    [_logTable reloadData];
}

- (void)clearLineCache {
    [_lineCache removeAllObjects];
    [_logTable reloadData];
}

#pragma mark - Analysis (streaming, background)

- (void)runAnalysis {
    [_loadingIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CrashLogAnalyzerResult *analysis = [CrashLogAnalyzer analyzeWithExitCode:weakSelf.exitCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf applyAnalysis:analysis];
        });
    });
}

- (void)applyAnalysis:(CrashLogAnalyzerResult *)analysis {
    self.analysis = analysis;
    [_loadingIndicator stopAnimating];

    self.codeLabel.text = [NSString stringWithFormat:localize(@"crash.screen.code", nil), self.exitCode];
    self.categoryLabel.text = localize(categoryLocalizedKey(analysis.category), nil);
    [self updateFileSegments];
    // Default to the first AVAILABLE file (not always latestlog): if the game
    // never wrote latestlog but did write a crash report, show the crash.
    NSInteger firstAvailable = 0;
    if (analysis.latestLogPath.length && [[NSFileManager defaultManager] fileExistsAtPath:analysis.latestLogPath]) {
        firstAvailable = 0;
    } else if (analysis.crashReportPath.length && [[NSFileManager defaultManager] fileExistsAtPath:analysis.crashReportPath]) {
        firstAvailable = 1;
    } else if (analysis.hsErrPath.length && [[NSFileManager defaultManager] fileExistsAtPath:analysis.hsErrPath]) {
        firstAvailable = 2;
    }
    self.fileSegments.selectedSegmentIndex = firstAvailable;
    [self openCurrentFileExcerpt];
}

- (void)updateFileSegments {
    // NEVER disable segments: a nil cached path often just means the analyzer
    // ran before the crash report was flushed to disk. Tapping re-scans live
    // (see pathForSegment:) and shows a friendly "no file" state instead of
    // a dead button ("có file mà không cho xem").
    for (NSInteger i = 0; i < 3; i++) [_fileSegments setEnabled:YES forSegmentAtIndex:i];
    // Annotate titles with availability: "Crash •" when present.
    NSString *logT = localize(@"crash.screen.file.log", nil);
    NSString *crashT = localize(@"crash.screen.file.crash", nil);
    NSString *hsT = localize(@"crash.screen.file.hserr", nil);
    BOOL hasLog = self.analysis.latestLogPath.length && [[NSFileManager defaultManager] fileExistsAtPath:self.analysis.latestLogPath];
    BOOL hasCrash = self.analysis.crashReportPath.length && [[NSFileManager defaultManager] fileExistsAtPath:self.analysis.crashReportPath];
    BOOL hasHs = self.analysis.hsErrPath.length && [[NSFileManager defaultManager] fileExistsAtPath:self.analysis.hsErrPath];
    [_fileSegments setTitle:hasLog ? [logT stringByAppendingString:@" •"] : logT forSegmentAtIndex:0];
    [_fileSegments setTitle:hasCrash ? [crashT stringByAppendingString:@" •"] : crashT forSegmentAtIndex:1];
    [_fileSegments setTitle:hasHs ? [hsT stringByAppendingString:@" •"] : hsT forSegmentAtIndex:2];
}

- (nullable NSString *)pathForSegment:(NSInteger)seg {
    // Live rescan: if the cached path is nil or vanished, ask the analyzer
    // again (cheap stat + dir listing, no file reads). This picks up crash
    // reports written after the crash screen appeared.
    if (self.analysis) [CrashLogAnalyzer refreshPathsForResult:self.analysis];
    NSString *p = nil;
    if (seg == 1) p = self.analysis.crashReportPath;
    else if (seg == 2) p = self.analysis.hsErrPath;
    else p = self.analysis.latestLogPath;
    if (p.length && [[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    // Fallback direct query (in case refresh kept a stale nil).
    if (seg == 1) {
        NSString *fresh = [CrashLogAnalyzer newestCrashReportPath];
        if (fresh.length) { self.analysis.crashReportPath = fresh; return fresh; }
    } else if (seg == 2) {
        NSString *fresh = [CrashLogAnalyzer newestHsErrPath];
        if (fresh.length) { self.analysis.hsErrPath = fresh; return fresh; }
    } else {
        NSString *fresh = [CrashLogAnalyzer latestLogPath];
        if (fresh.length && [[NSFileManager defaultManager] fileExistsAtPath:fresh]) {
            self.analysis.latestLogPath = fresh; return fresh;
        }
    }
    return p;
}

- (NSString *)displayNameForSegment:(NSInteger)seg {
    if (seg == 1) return localize(@"crash.screen.file.crash", nil);
    if (seg == 2) return localize(@"crash.screen.file.hserr", nil);
    return localize(@"crash.screen.file.log", nil);
}

#pragma mark - File opening (bounded reads only)

/// Lite file info (stat only, no line scan) for excerpt mode.
- (WitchLogFileInfo *)liteInfoForPath:(NSString *)path {
    WitchLogFileInfo *info = [WitchLogFileInfo new];
    info.path = path;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    info.fileSize = attrs ? [attrs fileSize] : 0;
    info.modDate = attrs[NSFileModificationDate];
    info.lineCount = NSNotFound;
    WitchLogCheckpoint *zero = [WitchLogCheckpoint new];
    zero.line = 0; zero.byteOffset = 0;
    info.checkpoints = @[zero];
    return info;
}

- (void)openCurrentFileExcerpt {
    NSInteger seg = self.fileSegments.selectedSegmentIndex;
    NSString *path = [self pathForSegment:seg];
    [self updateFileSegments];
    self.currentPath = path;
    self.viewMode = LogViewModeExcerpt;
    self.showingFullLog = NO;
    [self.toggleButton setTitle:localize(@"crash.screen.toggle_full", nil) forState:UIControlStateNormal];
    [self.indexer cancel];
    self.indexer = nil;
    self.indexing = NO;
    self.windowLoading = NO;
    self.windowLoadQueued = NO;
    [self.lineCache removeAllObjects];
    self.hitLines = nil;
    self.hitTexts = nil;
    self.logSearchBar.text = @"";
    [self updateNavVisibility];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *name = [self displayNameForSegment:seg];
        NSString *base = localize(@"ai.no_log_file", nil);
        self.excerptLines = @[[NSString stringWithFormat:@"%@ (%@)", base, name]];
        self.matchLabel.text = @"0";
        [self.logTable reloadData];
        return;
    }
    self.matchLabel.text = localize(@"crash.screen.loading", nil);
    __weak typeof(self) weakSelf = self;
    WitchLogFileInfo *lite = [self liteInfoForPath:path];
    self.fileInfo = lite;
    self.reader = [[WitchLogReader alloc] initWithFileInfo:lite];
    WitchLogReader *reader = self.reader;
    NSString *wantPath = path;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger start = 0;
        NSArray<NSString *> *tail = [reader syncReadTail:100 startLine:&start];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strong = weakSelf;
            if (!strong || ![strong.currentPath isEqualToString:wantPath]) return;
            strong.excerptLines = tail.count > 0 ? tail : @[localize(@"ai.no_log_file", nil)];
            strong.filteredExcerpt = nil;
            strong.matchLabel.text = [NSString stringWithFormat:localize(@"crash.lines", nil),
                                      (unsigned long)strong.excerptLines.count];
            [strong.logTable reloadData];
            if (tail.count > 0) {
                [strong.logTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                       atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
        });
    });
}

- (void)actionSwitchFile {
    self.searchQuery = nil;
    self.logSearchBar.text = @"";
    // Refresh availability dots immediately so the user sees what exists.
    [self updateFileSegments];
    if (self.showingFullLog) [self enterFullMode];
    else [self openCurrentFileExcerpt];
}

#pragma mark - Full mode (sparse index + virtualized rows)

- (void)actionToggleLog {
    if (!self.analysis) return;
    // Rescan before toggling: the file may have appeared since analysis.
    [CrashLogAnalyzer refreshPathsForResult:self.analysis];
    [self updateFileSegments];
    if (self.showingFullLog) {
        [self openCurrentFileExcerpt];
    } else {
        [self enterFullMode];
    }
}

- (void)enterFullMode {
    NSInteger seg = self.fileSegments.selectedSegmentIndex;
    NSString *path = [self pathForSegment:seg];
    [self updateFileSegments];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        // Do NOT fall back to latestlog here — that showed the wrong file and
        // made users think Crash/hs_err "không cho xem". Stay on excerpt with
        // the friendly empty state.
        [self openCurrentFileExcerpt];
        return;
    }
    self.currentPath = path;
    self.showingFullLog = YES;
    self.viewMode = LogViewModeFull;
    [self.toggleButton setTitle:localize(@"crash.screen.toggle_excerpt", nil) forState:UIControlStateNormal];
    [self.logSearchBar setText:@""];
    self.searchQuery = nil;
    self.hitLines = nil;
    [self.lineCache removeAllObjects];
    [self updateNavVisibility];
    [self.indexer cancel];
    self.totalLines = 0;
    self.indexing = YES;
    self.windowLoading = NO;
    self.windowLoadQueued = NO;
    [self.logTable reloadData];
    self.matchLabel.text = localize(@"crash.screen.indexing", nil);
    __weak typeof(self) weakSelf = self;
    NSString *wantPath = path;
    WitchLogIndexer *indexer = [[WitchLogIndexer alloc] initWithPath:path checkpointEvery:4096];
    self.indexer = indexer;
    [indexer buildWithProgress:^(double fraction) {
        typeof(self) strong = weakSelf;
        if (!strong || ![strong.currentPath isEqualToString:wantPath]) return;
        strong.matchLabel.text = [NSString stringWithFormat:localize(@"crash.screen.indexing_pct", nil),
                                  (int)(fraction * 100)];
    } completion:^(WitchLogFileInfo *info, NSError *error) {
        typeof(self) strong = weakSelf;
        if (!strong || ![strong.currentPath isEqualToString:wantPath]) return;
        strong.indexing = NO;
        if (!info || error) {
            strong.matchLabel.text = error.localizedDescription ?: @"Error";
            return;
        }
        strong.fileInfo = info;
        strong.reader = [[WitchLogReader alloc] initWithFileInfo:info];
        strong.totalLines = info.lineCount;
        strong.matchLabel.text = [NSString stringWithFormat:localize(@"crash.lines", nil),
                                  (unsigned long)info.lineCount];
        [strong.logTable reloadData];
        // Start at the tail (where crashes are) with a real window loaded.
        if (info.lineCount > 0) [strong jumpToLine:info.lineCount - 1];
    }];
}

#pragma mark - Windowed cache (only viewport lives in RAM)

- (void)fillCache:(NSArray<NSString *> *)lines base:(NSUInteger)base {
    // Evict anything outside the keep window.
    NSUInteger lo = base > 1000 ? base - 1000 : 0;
    NSUInteger hi = base + kWindowSize + 1000;
    NSMutableArray *drop = [NSMutableArray array];
    for (NSNumber *k in self.lineCache) {
        NSUInteger n = k.unsignedIntegerValue;
        if (n < lo || n >= hi) [drop addObject:k];
    }
    [self.lineCache removeObjectsForKeys:drop];
    // Enforce hard cap (evict farthest first).
    while (self.lineCache.count + lines.count > kCacheKeep && self.lineCache.count > 0) {
        NSNumber *farthest = nil;
        NSUInteger farDist = 0;
        for (NSNumber *k in self.lineCache) {
            NSUInteger n = k.unsignedIntegerValue;
            NSUInteger d = n > base ? n - base : base - n;
            if (!farthest || d > farDist) { farthest = k; farDist = d; }
        }
        if (farthest) [self.lineCache removeObjectForKey:farthest];
        else break;
    }
    for (NSUInteger i = 0; i < lines.count; i++) {
        self.lineCache[@(base + i)] = lines[i];
    }
    self.windowBase = base;
}

- (void)requestWindowAround:(NSUInteger)line {
    if (!self.reader || self.indexing || self.totalLines == 0) return;
    self.pendingLine = line;
    if (self.windowLoading) { self.windowLoadQueued = YES; return; }
    [self loadPendingWindow];
}

- (void)loadPendingWindow {
    NSUInteger target = self.pendingLine;
    NSUInteger start = target > kWindowRadius ? target - kWindowRadius : 0;
    self.windowLoading = YES;
    self.windowLoadQueued = NO;
    __weak typeof(self) weakSelf = self;
    WitchLogReader *reader = self.reader;
    NSString *wantPath = self.currentPath;
    [reader readLinesFrom:start count:kWindowSize completion:^(NSArray<NSString *> *lines, NSUInteger actualStart) {
        typeof(self) strong = weakSelf;
        if (!strong) return;
        strong.windowLoading = NO;
        if (![strong.currentPath isEqualToString:wantPath] ||
            strong.viewMode != LogViewModeFull) {
            if (strong.windowLoadQueued) [strong loadPendingWindow];
            return;
        }
        [strong fillCache:lines base:actualStart];
        // Reload only visible rows (no scroll jitter).
        NSArray<NSIndexPath *> *visible = [strong.logTable indexPathsForVisibleRows] ?: @[];
        NSMutableArray<NSIndexPath *> *missing = [NSMutableArray array];
        for (NSIndexPath *ip in visible) {
            if (!strong.lineCache[@((NSUInteger)ip.row)]) [missing addObject:ip];
            else {
                UITableViewCell *cell = [strong.logTable cellForRowAtIndexPath:ip];
                [strong configureCell:cell line:strong.lineCache[@((NSUInteger)ip.row)] number:(NSUInteger)ip.row];
            }
        }
        if (missing.count > 0) [strong.logTable reloadRowsAtIndexPaths:missing withRowAnimation:UITableViewRowAnimationNone];
        if (strong.windowLoadQueued) [strong loadPendingWindow];
    }];
}

- (void)jumpToLine:(NSUInteger)line {
    if (self.viewMode != LogViewModeFull || self.indexing || self.totalLines == 0) return;
    if (line >= self.totalLines) line = self.totalLines - 1;
    NSUInteger start = line > kWindowRadius ? line - kWindowRadius : 0;
    self.matchLabel.text = localize(@"crash.screen.loading", nil);
    __weak typeof(self) weakSelf = self;
    WitchLogReader *reader = self.reader;
    NSString *wantPath = self.currentPath;
    NSUInteger wantLine = line;
    [reader readLinesFrom:start count:kWindowSize completion:^(NSArray<NSString *> *lines, NSUInteger actualStart) {
        typeof(self) strong = weakSelf;
        if (!strong || ![strong.currentPath isEqualToString:wantPath] ||
            strong.viewMode != LogViewModeFull) return;
        [strong fillCache:lines base:actualStart];
        strong.windowLoading = NO;
        [strong.logTable reloadData];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:wantLine inSection:0];
        [strong.logTable scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        [strong updatePositionLabel];
    }];
}

- (void)updatePositionLabel {
    NSArray<NSIndexPath *> *visible = [self.logTable indexPathsForVisibleRows];
    NSUInteger first = self.totalLines;
    for (NSIndexPath *ip in visible) first = MIN(first, (NSUInteger)ip.row);
    if (first == self.totalLines) first = 0;
    self.matchLabel.text = [NSString stringWithFormat:localize(@"crash.screen.position", nil),
                            (unsigned long)(first + 1), (unsigned long)self.totalLines];
}

#pragma mark - Table (virtualized: only visible rows exist)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (self.viewMode) {
        case LogViewModeExcerpt:
            return (self.filteredExcerpt ?: self.excerptLines).count;
        case LogViewModeResults:
            return self.hitLines.count;
        default:
            return self.indexing ? 0 : (NSInteger)self.totalLines;
    }
}

- (void)configureCell:(UITableViewCell *)cell line:(NSString *)line number:(NSInteger)number {
    if (self.viewMode == LogViewModeFull || self.viewMode == LogViewModeResults) {
        cell.textLabel.text = [NSString stringWithFormat:@"%ld  %@", (long)number + 1, line];
    } else {
        cell.textLabel.text = line;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:12];
    cell.textLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    if (self.viewMode == LogViewModeExcerpt) {
        NSArray *lines = self.filteredExcerpt ?: self.excerptLines;
        cell.textLabel.text = (indexPath.row < (NSInteger)lines.count) ? lines[indexPath.row] : @"";
    } else if (self.viewMode == LogViewModeResults) {
        if (indexPath.row < (NSInteger)self.hitLines.count) {
            NSUInteger num = [self.hitLines[indexPath.row] unsignedIntegerValue];
            [self configureCell:cell line:self.hitTexts[indexPath.row] number:(NSInteger)num];
        }
    } else {
        NSString *line = self.lineCache[@((NSUInteger)indexPath.row)];
        if (line) {
            [self configureCell:cell line:line number:indexPath.row];
        } else {
            cell.textLabel.text = @"…";
            [self requestWindowAround:(NSUInteger)indexPath.row];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (self.viewMode != LogViewModeFull || self.indexing) return;
    NSIndexPath *first = indexPaths.firstObject;
    if (first && !self.lineCache[@((NSUInteger)first.row)]) {
        [self requestWindowAround:(NSUInteger)first.row];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.viewMode == LogViewModeResults && indexPath.row < (NSInteger)self.hitLines.count) {
        NSUInteger line = [self.hitLines[indexPath.row] unsignedIntegerValue];
        self.viewMode = LogViewModeFull;
        [self.logTable reloadData];
        [self jumpToLine:line];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.logTable && self.viewMode == LogViewModeFull) [self updatePositionLabel];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView == self.logTable && self.viewMode == LogViewModeFull && !decelerate) [self updatePositionLabel];
}

#pragma mark - Nav actions

- (void)actionGoTop {
    if (self.totalLines > 0) [self jumpToLine:0];
}
- (void)actionGoBottom {
    if (self.totalLines > 0) [self jumpToLine:self.totalLines - 1];
}
- (void)actionGoLine {
    if (self.viewMode != LogViewModeFull || self.totalLines == 0) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"crash.screen.go_line", nil)
                                                                   message:[NSString stringWithFormat:localize(@"crash.screen.go_line_msg", nil),
                                                                            (unsigned long)self.totalLines]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = @"1";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSInteger n = [alert.textFields.firstObject.text integerValue];
        if (n >= 1) [weakSelf jumpToLine:(NSUInteger)(n - 1)];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Search (debounced, background, capped)

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // Debounce: coalesce fast typing into one background search.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runDebouncedSearch) object:nil];
    [self performSelector:@selector(runDebouncedSearch) withObject:nil afterDelay:0.3];
}
- (void)runDebouncedSearch {
    [self runSearch:self.logSearchBar.text ?: @""];
}

- (void)runSearch:(NSString *)query {
    NSString *q = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.searchQuery = q;
    self.searchSeq++;
    if (q.length == 0) {
        // Restore current mode.
        if (self.viewMode == LogViewModeResults) {
            self.viewMode = self.showingFullLog ? LogViewModeFull : LogViewModeExcerpt;
        }
        self.filteredExcerpt = nil;
        self.hitLines = nil;
        [self.logTable reloadData];
        if (self.viewMode == LogViewModeFull) [self updatePositionLabel];
        else self.matchLabel.text = [NSString stringWithFormat:localize(@"crash.lines", nil),
                                     (unsigned long)self.excerptLines.count];
        return;
    }
    // Excerpt mode (or full mode before index is ready): filter the ~100 lines inline.
    if (self.viewMode == LogViewModeExcerpt || self.indexing || !self.reader) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *line in self.excerptLines) {
            if ([line rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:line];
            }
        }
        if (filtered.count == 0) {
            self.filteredExcerpt = @[localize(@"crash.screen.no_match", nil)];
            self.matchLabel.text = @"0 match";
        } else {
            self.filteredExcerpt = filtered;
            self.matchLabel.text = [NSString stringWithFormat:@"%lu / %lu",
                                    (unsigned long)filtered.count, (unsigned long)self.excerptLines.count];
        }
        [self.logTable reloadData];
        return;
    }
    // Full mode: stream the file on a background queue, cap hits.
    NSUInteger seq = self.searchSeq;
    self.matchLabel.text = localize(@"crash.screen.searching", nil);
    WitchLogReader *reader = self.reader;
    NSString *wantPath = self.currentPath;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSNumber *> *nums = [NSMutableArray array];
        NSMutableArray<NSString *> *texts = [NSMutableArray array];
        // Whole-file scan, one pass, bounded result set.
        [reader syncEnumerateLinesWithMaxBytes:ULLONG_MAX batchSize:1024
                                       handler:^(NSArray<NSString *> *batch, NSUInteger startLine, BOOL *stop) {
            typeof(self) strong = weakSelf;
            if (!strong || strong.searchSeq != seq) { *stop = YES; return; }
            for (NSUInteger i = 0; i < batch.count; i++) {
                if ([batch[i] rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [nums addObject:@(startLine + i)];
                    [texts addObject:batch[i]];
                    if (nums.count >= kMaxSearchHits) { *stop = YES; break; }
                }
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strong = weakSelf;
            if (!strong || strong.searchSeq != seq || ![strong.currentPath isEqualToString:wantPath]) return;
            if (nums.count == 0) {
                strong.matchLabel.text = localize(@"crash.screen.no_match", nil);
                return;
            }
            strong.viewMode = LogViewModeResults;
            strong.hitLines = nums;
            strong.hitTexts = texts;
            strong.matchLabel.text = [NSString stringWithFormat:localize(@"crash.screen.hits", nil),
                                      (unsigned long)nums.count,
                                      nums.count >= kMaxSearchHits ? @"+" : @""];
            [strong.logTable reloadData];
            [strong.logTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                   atScrollPosition:UITableViewScrollPositionTop animated:NO];
        });
    });
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar { searchBar.text = @""; [self runSearch:@""]; [searchBar resignFirstResponder]; }

#pragma mark - Actions

- (void)actionAIChat {
    if (self.analysis) [CrashLogAnalyzer refreshPathsForResult:self.analysis];
    [self updateFileSegments];
    WitchAIChatViewController *vc = [[WitchAIChatViewController alloc] initWithAnalysis:self.analysis exitCode:self.exitCode];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)actionShare {
    if (self.analysis) [CrashLogAnalyzer refreshPathsForResult:self.analysis];
    [self updateFileSegments];
    NSMutableArray *items = [NSMutableArray array];
    if (self.analysis.latestLogPath && [NSFileManager.defaultManager fileExistsAtPath:self.analysis.latestLogPath]) {
        [items addObject:[NSURL fileURLWithPath:self.analysis.latestLogPath]];
    }
    if (self.analysis.crashReportPath && [NSFileManager.defaultManager fileExistsAtPath:self.analysis.crashReportPath]) {
        [items addObject:[NSURL fileURLWithPath:self.analysis.crashReportPath]];
    }
    if (self.analysis.hsErrPath && [NSFileManager.defaultManager fileExistsAtPath:self.analysis.hsErrPath]) {
        [items addObject:[NSURL fileURLWithPath:self.analysis.hsErrPath]];
    }
    if (items.count == 0) {
        // Fallback: share visible text (bounded).
        NSMutableString *s = [NSMutableString string];
        NSArray *lines = self.filteredExcerpt ?: self.excerptLines;
        for (NSString *l in lines) {
            if (s.length > 200000) break;
            [s appendString:l];
            [s appendString:@"\n"];
        }
        [items addObject:s.length > 0 ? s : @""];
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityVC.popoverPresentationController.sourceView = self.shareButton;
    activityVC.popoverPresentationController.sourceRect = self.shareButton.bounds;
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)actionSendToDiscord {
    if (!self.analysis) return;
    [CrashLogAnalyzer refreshPathsForResult:self.analysis];
    [self updateFileSegments];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"crash.screen.send_title", nil) message:localize(@"crash.screen.send_msg", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = localize(@"crash.screen.send_note_placeholder", nil);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"crash.screen.send", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *note = alert.textFields.firstObject.text ?: @"";
        UIAlertController *progress = [UIAlertController alertControllerWithTitle:localize(@"crash.screen.sending", nil)
                                                                          message:@"0%"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        [weakSelf presentViewController:progress animated:YES completion:nil];
        WitchLogUploadJob *job = [WitchLogReporter sendReportWithAnalysis:weakSelf.analysis
                                                                 exitCode:weakSelf.exitCode
                                                                     note:note
                                                                 progress:^(double f) {
            dispatch_async(dispatch_get_main_queue(), ^{
                progress.message = [NSString stringWithFormat:@"%d%%", (int)(f * 100)];
            });
        } completion:^(BOOL success, NSString *logId, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    NSString *title = success ? localize(@"crash.screen.send_ok", nil) : localize(@"Error", nil);
                    NSString *msg = success ? [NSString stringWithFormat:localize(@"crash.screen.send_ok_msg", nil), logId ?: @""] : error.localizedDescription;
                    UIAlertController *res = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [res addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                    [weakSelf presentViewController:res animated:YES completion:nil];
                }];
            });
        }];
        (void)job;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)actionClose {
    crashScreenCloseLauncher();
}

@end
