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
#import "AppSheet.h"
#import "ErrorPresenter.h"

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

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIView *backgroundDimView;
@property (nonatomic, strong) UIStackView *rootStack;
@property (nonatomic, strong) UIView *summaryPanel;
@property (nonatomic, strong) UIStackView *summaryStack;
@property (nonatomic, strong) UIView *summarySpacer;
@property (nonatomic, strong) UIView *contentPanel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *toolbarCard;
@property (nonatomic, strong) UIStackView *toolbarStack;

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *codeLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) UIStackView *actionGrid;
@property (nonatomic, strong) UIStackView *buttonRowAI;
@property (nonatomic, strong) UIStackView *buttonRowFile;
@property (nonatomic, strong) CustomButton *shareButton;
@property (nonatomic, strong) CustomButton *toggleButton;
@property (nonatomic, strong) CustomButton *aiChatButton;
@property (nonatomic, strong) CustomButton *sendButton;

@property (nonatomic, strong) UISearchBar *logSearchBar;
@property (nonatomic, strong) UILabel *matchLabel;
@property (nonatomic, strong) UISegmentedControl *fileSegments;
@property (nonatomic, strong) UIStackView *navRow;
@property (nonatomic, strong) CustomButton *topButton;
@property (nonatomic, strong) CustomButton *bottomButton;
@property (nonatomic, strong) CustomButton *goButton;

@property (nonatomic, strong) UITableView *logTable;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong) NSLayoutConstraint *summaryWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *summaryHeightConstraint;
@property (nonatomic) BOOL horizontalLayout;
@property (nonatomic) CGSize lastLayoutSize;

// Log engine state. Heavy objects live here; UI only holds a window.
@property (nonatomic) LogViewMode viewMode;
@property (nonatomic, copy) NSString *currentPath;
@property (nonatomic, strong) WitchLogFileInfo *fileInfo;   // lite (excerpt) or indexed (full)
@property (nonatomic, strong) WitchLogReader *reader;
@property (nonatomic, strong) WitchLogIndexer *indexer;
@property (nonatomic) BOOL indexing;
@property (nonatomic, copy) NSArray<NSString *> *excerptLines;
@property (nonatomic, copy) NSArray<NSString *> *filteredExcerpt; // excerpt search
@property (nonatomic) NSUInteger excerptStartLine;
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

#pragma mark - Log cell

// A fixed-height cell keeps 100k-line logs smooth. Two lines are enough to
// scan a crash; long lines can be copied from the context menu.
@interface CrashLogCell : UITableViewCell
@property (nonatomic, strong) UILabel *numberLabel;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIFont *numberFont;
@property (nonatomic, strong) UIFont *logFont;
- (void)applyTheme:(ThemeManager *)theme;
- (void)setNumber:(NSUInteger)number text:(NSString *)text showNumber:(BOOL)showNumber;
@end

@implementation CrashLogCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        _numberLabel = [[UILabel alloc] init];
        _numberLabel.textAlignment = NSTextAlignmentRight;
        _numberLabel.numberOfLines = 1;
        _numberLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_numberLabel];

        _logLabel = [[UILabel alloc] init];
        _logLabel.numberOfLines = 2;
        _logLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_logLabel];

        _separator = [[UIView alloc] init];
        [self.contentView addSubview:_separator];

        _numberFont = [UIFont monospacedDigitSystemFontOfSize:10.5 weight:UIFontWeightRegular];
        _logFont = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
        _numberLabel.font = _numberFont;
        _logLabel.font = _logFont;
    }
    return self;
}

- (void)applyTheme:(ThemeManager *)theme {
    _numberLabel.textColor = [theme.secondaryTextColor colorWithAlphaComponent:0.85];
    _logLabel.textColor = theme.primaryTextColor;
    _separator.backgroundColor = [theme.separatorColor colorWithAlphaComponent:0.45];
}

- (void)setNumber:(NSUInteger)number text:(NSString *)text showNumber:(BOOL)showNumber {
    _numberLabel.hidden = !showNumber;
    _numberLabel.text = showNumber ? [NSString stringWithFormat:@"%lu", (unsigned long)number] : nil;
    _logLabel.text = text ?: @"";
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    CGFloat inset = 12.0;
    CGFloat numberWidth = 48.0;
    CGFloat logX = _numberLabel.hidden ? inset : inset + numberWidth + 8.0;
    CGFloat logWidth = MAX(0, CGRectGetWidth(bounds) - logX - inset);
    CGFloat textY = 5.0;
    CGFloat textH = MAX(0, CGRectGetHeight(bounds) - 10.0);
    _numberLabel.frame = _numberLabel.hidden ? CGRectZero : CGRectMake(inset, textY, numberWidth, textH);
    _logLabel.frame = CGRectMake(logX, textY, logWidth, textH);
    _separator.frame = CGRectMake(inset, CGRectGetHeight(bounds) - 0.5, MAX(0, CGRectGetWidth(bounds) - inset * 2), 0.5);
}

@end

@implementation CrashScreenViewController

- (instancetype)initWithExitCode:(int)code {
    self = [super init];
    if (self) {
        _exitCode = code;
        _showingFullLog = NO;
        _viewMode = LogViewModeExcerpt;
        _excerptStartLine = 0;
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
    [self updateLayoutForSize:self.view.bounds.size];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearLineCache) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [self runAnalysis];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateLayoutForSize:size];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    if (fabs(size.width - self.lastLayoutSize.width) > 0.5 ||
        fabs(size.height - self.lastLayoutSize.height) > 0.5) {
        [self updateLayoutForSize:size];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_indexer cancel];
    _searchSeq++;
}

#pragma mark - Setup

- (void)setupViews {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.backgroundColor;
    self.view.clipsToBounds = YES;

    _backgroundImageView = [[UIImageView alloc] init];
    _backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    _backgroundImageView.clipsToBounds = YES;
    _backgroundImageView.hidden = YES;
    [self.view addSubview:_backgroundImageView];

    _backgroundDimView = [[UIView alloc] init];
    _backgroundDimView.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundDimView.userInteractionEnabled = NO;
    [self.view addSubview:_backgroundDimView];

    _rootStack = [[UIStackView alloc] init];
    _rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    _rootStack.axis = UILayoutConstraintAxisVertical;
    _rootStack.alignment = UIStackViewAlignmentFill;
    _rootStack.distribution = UIStackViewDistributionFill;
    _rootStack.spacing = 10;
    [self.view addSubview:_rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [_backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_backgroundImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_backgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_backgroundDimView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_backgroundDimView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_backgroundDimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_backgroundDimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_rootStack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [_rootStack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_rootStack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_rootStack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];

    // Summary card: compact on top in portrait, a proper sidebar in landscape.
    _summaryPanel = [[UIView alloc] init];
    _summaryPanel.translatesAutoresizingMaskIntoConstraints = NO;
    _summaryPanel.backgroundColor = theme.cardBackgroundColor;
    _summaryPanel.layer.cornerRadius = 18;
    _summaryPanel.layer.borderWidth = 1;
    _summaryPanel.layer.borderColor = [theme.separatorColor colorWithAlphaComponent:0.55].CGColor;
    _summaryPanel.clipsToBounds = YES;
    [_rootStack addArrangedSubview:_summaryPanel];

    _summaryStack = [[UIStackView alloc] init];
    _summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
    _summaryStack.axis = UILayoutConstraintAxisVertical;
    _summaryStack.spacing = 8;
    _summaryStack.alignment = UIStackViewAlignmentFill;
    [_summaryPanel addSubview:_summaryStack];

    _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _titleLabel.text = localize(@"crash.screen.title", nil);
    _titleLabel.numberOfLines = 2;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    _closeButton.accessibilityLabel = localize(@"crash.screen.close", nil);
    [_closeButton addTarget:self action:@selector(actionClose) forControlEvents:UIControlEventTouchUpInside];
    [_closeButton.widthAnchor constraintEqualToConstant:32].active = YES;
    [_closeButton.heightAnchor constraintEqualToConstant:32].active = YES;

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _titleLabel, _closeButton]];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.spacing = 10;
    [_summaryStack addArrangedSubview:headerRow];
    [_iconView.widthAnchor constraintEqualToConstant:32].active = YES;
    [_iconView.heightAnchor constraintEqualToConstant:32].active = YES;

    _codeLabel = [[UILabel alloc] init];
    _codeLabel.font = [UIFont monospacedDigitSystemFontOfSize:36 weight:UIFontWeightHeavy];
    _codeLabel.adjustsFontSizeToFitWidth = YES;
    _codeLabel.minimumScaleFactor = 0.65;
    _codeLabel.numberOfLines = 1;
    [_summaryStack addArrangedSubview:_codeLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
    _categoryLabel.numberOfLines = 2;
    [_summaryStack addArrangedSubview:_categoryLabel];

    _versionLabel = [[UILabel alloc] init];
    _versionLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular];
    _versionLabel.numberOfLines = 1;
    _versionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    _versionLabel.text = [NSString stringWithFormat:@"Witch v%@", ver];
    [_summaryStack addArrangedSubview:_versionLabel];

    // 2x2 action grid: every crash action stays visible on narrow phones
    // without a horizontally scrolling strip that hid the toggles.
    _aiChatButton = [[CustomButton alloc] initWithStyle:CustomButtonStylePrimary title:localize(@"crash.screen.ai_chat", nil)];
    [_aiChatButton addTarget:self action:@selector(actionAIChat) forControlEvents:UIControlEventTouchUpInside];

    _sendButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.send", nil)];
    [_sendButton addTarget:self action:@selector(actionSendToDiscord) forControlEvents:UIControlEventTouchUpInside];

    _shareButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.share", nil)];
    [_shareButton addTarget:self action:@selector(actionShare) forControlEvents:UIControlEventTouchUpInside];

    _toggleButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.toggle_full", nil)];
    [_toggleButton addTarget:self action:@selector(actionToggleLog) forControlEvents:UIControlEventTouchUpInside];

    _buttonRowAI = [[UIStackView alloc] initWithArrangedSubviews:@[_aiChatButton, _sendButton]];
    _buttonRowAI.axis = UILayoutConstraintAxisHorizontal;
    _buttonRowAI.spacing = 8;
    _buttonRowAI.distribution = UIStackViewDistributionFillEqually;

    _buttonRowFile = [[UIStackView alloc] initWithArrangedSubviews:@[_shareButton, _toggleButton]];
    _buttonRowFile.axis = UILayoutConstraintAxisHorizontal;
    _buttonRowFile.spacing = 8;
    _buttonRowFile.distribution = UIStackViewDistributionFillEqually;

    _actionGrid = [[UIStackView alloc] initWithArrangedSubviews:@[_buttonRowAI, _buttonRowFile]];
    _actionGrid.translatesAutoresizingMaskIntoConstraints = NO;
    _actionGrid.axis = UILayoutConstraintAxisVertical;
    _actionGrid.spacing = 8;
    _actionGrid.distribution = UIStackViewDistributionFillEqually;
    [_summaryStack addArrangedSubview:_actionGrid];
    [_actionGrid.heightAnchor constraintEqualToConstant:84].active = YES;

    for (UIButton *button in @[_aiChatButton, _sendButton, _shareButton, _toggleButton]) {
        [button.heightAnchor constraintEqualToConstant:38].active = YES;
    }

    _summarySpacer = [[UIView alloc] init];
    _summarySpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [_summarySpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_summarySpacer.heightAnchor constraintGreaterThanOrEqualToConstant:0].active = YES;
    [_summaryStack addArrangedSubview:_summarySpacer];

    [NSLayoutConstraint activateConstraints:@[
        [_summaryStack.topAnchor constraintEqualToAnchor:_summaryPanel.topAnchor constant:14],
        [_summaryStack.leadingAnchor constraintEqualToAnchor:_summaryPanel.leadingAnchor constant:14],
        [_summaryStack.trailingAnchor constraintEqualToAnchor:_summaryPanel.trailingAnchor constant:-14],
        [_summaryStack.bottomAnchor constraintEqualToAnchor:_summaryPanel.bottomAnchor constant:-14],

    ]];

    _summaryWidthConstraint = [_summaryPanel.widthAnchor constraintEqualToConstant:280];
    _summaryHeightConstraint = [_summaryPanel.heightAnchor constraintEqualToAnchor:_summaryStack.heightAnchor constant:28];
    _summaryHeightConstraint.active = YES;

    // Main content: file picker + search + virtualized log table.
    _contentPanel = [[UIView alloc] init];
    _contentPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [_rootStack addArrangedSubview:_contentPanel];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 10;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.distribution = UIStackViewDistributionFill;
    [_contentPanel addSubview:_contentStack];
    [NSLayoutConstraint activateConstraints:@[
        [_contentStack.topAnchor constraintEqualToAnchor:_contentPanel.topAnchor],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_contentPanel.leadingAnchor],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_contentPanel.trailingAnchor],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_contentPanel.bottomAnchor],
    ]];

    _toolbarCard = [[UIView alloc] init];
    _toolbarCard.translatesAutoresizingMaskIntoConstraints = NO;
    _toolbarCard.backgroundColor = theme.cardBackgroundColor;
    _toolbarCard.layer.cornerRadius = 14;
    _toolbarCard.layer.borderWidth = 1;
    _toolbarCard.layer.borderColor = [theme.separatorColor colorWithAlphaComponent:0.55].CGColor;
    _toolbarCard.clipsToBounds = YES;
    [_contentStack addArrangedSubview:_toolbarCard];

    _toolbarStack = [[UIStackView alloc] init];
    _toolbarStack.translatesAutoresizingMaskIntoConstraints = NO;
    _toolbarStack.axis = UILayoutConstraintAxisVertical;
    _toolbarStack.spacing = 6;
    _toolbarStack.alignment = UIStackViewAlignmentFill;
    [_toolbarCard addSubview:_toolbarStack];
    [NSLayoutConstraint activateConstraints:@[
        [_toolbarStack.topAnchor constraintEqualToAnchor:_toolbarCard.topAnchor constant:10],
        [_toolbarStack.leadingAnchor constraintEqualToAnchor:_toolbarCard.leadingAnchor constant:10],
        [_toolbarStack.trailingAnchor constraintEqualToAnchor:_toolbarCard.trailingAnchor constant:-10],
        [_toolbarStack.bottomAnchor constraintEqualToAnchor:_toolbarCard.bottomAnchor constant:-10],
    ]];

    _fileSegments = [[UISegmentedControl alloc] initWithItems:@[
        localize(@"crash.screen.file.log", nil),
        localize(@"crash.screen.file.crash", nil),
        localize(@"crash.screen.file.hserr", nil),
    ]];
    _fileSegments.selectedSegmentIndex = 0;
    [ThemeManager.shared styleSegmentedControl:_fileSegments];
    [_fileSegments addTarget:self action:@selector(actionSwitchFile) forControlEvents:UIControlEventValueChanged];
    [_toolbarStack addArrangedSubview:_fileSegments];
    [_fileSegments.heightAnchor constraintEqualToConstant:32].active = YES;

    _logSearchBar = [[UISearchBar alloc] init];
    _logSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    _logSearchBar.placeholder = localize(@"crash.screen.search_placeholder", nil);
    _logSearchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _logSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    _logSearchBar.spellCheckingType = UITextSpellCheckingTypeNo;
    _logSearchBar.enablesReturnKeyAutomatically = NO;
    _logSearchBar.delegate = self;
    [_toolbarStack addArrangedSubview:_logSearchBar];
    [_logSearchBar.heightAnchor constraintEqualToConstant:44].active = YES;

    _navRow = [[UIStackView alloc] init];
    _navRow.axis = UILayoutConstraintAxisHorizontal;
    _navRow.spacing = 8;
    _navRow.alignment = UIStackViewAlignmentCenter;
    [_toolbarStack addArrangedSubview:_navRow];
    [_navRow.heightAnchor constraintEqualToConstant:30].active = YES;

    _topButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.top", nil)];
    [_topButton addTarget:self action:@selector(actionGoTop) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_topButton];

    _bottomButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.bottom", nil)];
    [_bottomButton addTarget:self action:@selector(actionGoBottom) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_bottomButton];

    _goButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"crash.screen.go_line", nil)];
    [_goButton addTarget:self action:@selector(actionGoLine) forControlEvents:UIControlEventTouchUpInside];
    [_navRow addArrangedSubview:_goButton];

    UIView *navSpacer = [[UIView alloc] init];
    [navSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [navSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_navRow addArrangedSubview:navSpacer];

    _matchLabel = [[UILabel alloc] init];
    _matchLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
    _matchLabel.textAlignment = NSTextAlignmentRight;
    _matchLabel.numberOfLines = 1;
    _matchLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    [_matchLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_matchLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_navRow addArrangedSubview:_matchLabel];

    for (UIButton *button in @[_topButton, _bottomButton, _goButton]) {
        [button.heightAnchor constraintEqualToConstant:30].active = YES;
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:62].active = YES;
    }

    _logTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _logTable.translatesAutoresizingMaskIntoConstraints = NO;
    _logTable.delegate = self;
    _logTable.dataSource = self;
    _logTable.prefetchDataSource = self;
    _logTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    _logTable.backgroundColor = theme.cardBackgroundColor;
    _logTable.layer.cornerRadius = 14;
    _logTable.clipsToBounds = YES;
    _logTable.rowHeight = 40;
    _logTable.estimatedRowHeight = 40;
    _logTable.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_logTable registerClass:[CrashLogCell class] forCellReuseIdentifier:@"LogCell"];
    [_contentStack addArrangedSubview:_logTable];
    [_logTable.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    [_logTable setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [_logTable setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];

    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:_loadingIndicator];
    [NSLayoutConstraint activateConstraints:@[
        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:_logTable.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_logTable.centerYAnchor],
    ]];

    [self updateNavVisibility];
}

- (void)updateLayoutForSize:(CGSize)size {
    if (size.width < 1 || size.height < 1) return;
    self.lastLayoutSize = size;
    BOOL horizontal = size.width > size.height;
    self.horizontalLayout = horizontal;

    _rootStack.axis = horizontal ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    _rootStack.spacing = horizontal ? 14 : 10;

    _summaryWidthConstraint.constant = MIN(300, MAX(260, size.width * 0.3));
    _summaryWidthConstraint.active = horizontal;
    _summaryHeightConstraint.active = !horizontal;
    // The spacer soaks up slack in the landscape sidebar. Keep it out of the
    // vertical layout, otherwise its low hugging leaves the summary height
    // ambiguous and the panel keeps the tall height from the rotated state.
    _summarySpacer.hidden = !horizontal;

    [self.view setNeedsLayout];
}

- (void)updateNavVisibility {
    BOOL full = (self.viewMode == LogViewModeFull);
    _navRow.hidden = !full;
    // File segments stay visible in every mode so users can switch files.
    _fileSegments.hidden = NO;
}

- (void)updateBackground {
    ThemeManager *theme = ThemeManager.shared;
    _backgroundImageView.image = theme.blurredBackgroundImage ?: theme.backgroundImage;
    _backgroundImageView.hidden = !theme.hasCustomBackground;
    _backgroundDimView.backgroundColor = theme.hasCustomBackground
        ? [theme.backgroundColor colorWithAlphaComponent:0.62]
        : theme.backgroundColor;
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.backgroundColor;
    [self updateBackground];

    _summaryPanel.backgroundColor = theme.cardBackgroundColor;
    _summaryPanel.layer.borderColor = [theme.separatorColor colorWithAlphaComponent:0.55].CGColor;
    _toolbarCard.backgroundColor = theme.cardBackgroundColor;
    _toolbarCard.layer.borderColor = [theme.separatorColor colorWithAlphaComponent:0.55].CGColor;
    _logTable.backgroundColor = theme.cardBackgroundColor;

    _iconView.tintColor = theme.errorColor;
    _titleLabel.textColor = theme.primaryTextColor;
    _codeLabel.textColor = theme.errorColor;
    _categoryLabel.textColor = theme.secondaryTextColor;
    _versionLabel.textColor = theme.secondaryTextColor;
    _matchLabel.textColor = theme.secondaryTextColor;
    _closeButton.tintColor = theme.secondaryTextColor;
    _loadingIndicator.color = theme.accentColor;

    [theme styleSegmentedControl:_fileSegments];
    _logSearchBar.tintColor = theme.accentColor;
    UITextField *searchField = _logSearchBar.searchTextField;
    searchField.textColor = theme.primaryTextColor;
    searchField.backgroundColor = [theme.separatorColor colorWithAlphaComponent:0.32];
    searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:localize(@"crash.screen.search_placeholder", nil)
                                                                       attributes:@{NSForegroundColorAttributeName: theme.secondaryTextColor}];

    for (UITableViewCell *cell in _logTable.visibleCells) {
        if ([cell isKindOfClass:[CrashLogCell class]]) [(CrashLogCell *)cell applyTheme:theme];
    }
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
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    if (analysis.totalBytes > 0) {
        NSString *size = [NSByteCountFormatter stringFromByteCount:(long long)analysis.totalBytes
                                                        countStyle:NSByteCountFormatterCountStyleFile];
        self.versionLabel.text = [NSString stringWithFormat:@"Witch v%@ · %@", ver, size];
    } else {
        self.versionLabel.text = [NSString stringWithFormat:@"Witch v%@", ver];
    }
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
    self.excerptStartLine = 0;
    [self.lineCache removeAllObjects];
    self.hitLines = nil;
    self.hitTexts = nil;
    self.filteredExcerpt = nil;
    self.searchQuery = nil;
    self.logSearchBar.text = @"";
    [self updateNavVisibility];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *name = [self displayNameForSegment:seg];
        NSString *base = localize(@"ai.no_log_file", nil);
        self.excerptLines = @[[NSString stringWithFormat:@"%@ (%@)", base, name]];
        self.filteredExcerpt = nil;
        self.reader = nil;
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
            strong.excerptStartLine = tail.count > 0 ? start : 0;
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
            NSString *line = strong.lineCache[@((NSUInteger)ip.row)];
            if (!line) [missing addObject:ip];
            else {
                CrashLogCell *cell = (CrashLogCell *)[strong.logTable cellForRowAtIndexPath:ip];
                [cell setNumber:(NSUInteger)ip.row + 1 text:line showNumber:YES];
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

- (nullable NSString *)lineTextAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0) return nil;
    switch (self.viewMode) {
        case LogViewModeExcerpt: {
            NSArray<NSString *> *lines = self.filteredExcerpt ?: self.excerptLines;
            return indexPath.row < (NSInteger)lines.count ? lines[indexPath.row] : nil;
        }
        case LogViewModeResults:
            return indexPath.row < (NSInteger)self.hitTexts.count ? self.hitTexts[indexPath.row] : nil;
        case LogViewModeFull:
            return self.lineCache[@((NSUInteger)indexPath.row)];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CrashLogCell *cell = (CrashLogCell *)[tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
    [cell applyTheme:ThemeManager.shared];

    if (self.viewMode == LogViewModeExcerpt) {
        NSArray<NSString *> *lines = self.filteredExcerpt ?: self.excerptLines;
        if (indexPath.row < (NSInteger)lines.count) {
            BOOL filtered = (self.filteredExcerpt != nil);
            NSUInteger number = filtered ? 0 : self.excerptStartLine + (NSUInteger)indexPath.row + 1;
            [cell setNumber:number text:lines[indexPath.row] showNumber:!filtered];
        } else {
            [cell setNumber:0 text:@"" showNumber:NO];
        }
    } else if (self.viewMode == LogViewModeResults) {
        if (indexPath.row < (NSInteger)self.hitLines.count) {
            NSUInteger number = [self.hitLines[indexPath.row] unsignedIntegerValue];
            [cell setNumber:number + 1 text:self.hitTexts[indexPath.row] showNumber:YES];
        } else {
            [cell setNumber:0 text:@"" showNumber:NO];
        }
    } else {
        NSString *line = self.lineCache[@((NSUInteger)indexPath.row)];
        if (line) {
            [cell setNumber:(NSUInteger)indexPath.row + 1 text:line showNumber:YES];
        } else {
            [cell setNumber:(NSUInteger)indexPath.row + 1 text:@"…" showNumber:YES];
            [self requestWindowAround:(NSUInteger)indexPath.row];
        }
    }
    return cell;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    NSString *line = [self lineTextAtIndexPath:indexPath];
    if (line.length == 0) return nil;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UIAction *copy = [UIAction actionWithTitle:localize(@"Copy", nil)
                                            image:[UIImage systemImageNamed:@"doc.on.doc"]
                                       identifier:nil
                                          handler:^(__kindof UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = line;
        }];
        return [UIMenu menuWithTitle:@"" children:@[copy]];
    }];
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
        [self updateNavVisibility];
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
    __weak typeof(self) weakSelf = self;
    [AppSheet showPromptWithTitle:localize(@"crash.screen.go_line", nil)
                          message:[NSString stringWithFormat:localize(@"crash.screen.go_line_msg", nil), (unsigned long)self.totalLines]
                      placeholder:@"1" initialText:@"" onConfirm:^(NSString *text) {
        NSInteger n = [text integerValue];
        if (n >= 1) [weakSelf jumpToLine:(NSUInteger)(n - 1)];
    }];
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
        self.hitTexts = nil;
        [self updateNavVisibility];
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
                strong.viewMode = LogViewModeResults;
                strong.hitLines = @[];
                strong.hitTexts = @[];
                strong.matchLabel.text = localize(@"crash.screen.no_match", nil);
                [strong updateNavVisibility];
                [strong.logTable reloadData];
                return;
            }
            strong.viewMode = LogViewModeResults;
            strong.hitLines = nums;
            strong.hitTexts = texts;
            strong.matchLabel.text = [NSString stringWithFormat:localize(@"crash.screen.hits", nil),
                                      (unsigned long)nums.count,
                                      nums.count >= kMaxSearchHits ? @"+" : @""];
            [strong updateNavVisibility];
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
    // OverFullScreen on iPhone: the chat's backdrop is the themed translucent
    // color, so the crash screen must stay underneath it.
    nav.modalPresentationStyle = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
        ? UIModalPresentationFormSheet : UIModalPresentationOverFullScreen;
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
    __weak typeof(self) weakSelf = self;
    [AppSheet showPromptWithTitle:localize(@"crash.screen.send_title", nil) message:localize(@"crash.screen.send_msg", nil) placeholder:localize(@"crash.screen.send_note_placeholder", nil) initialText:@"" onConfirm:^(NSString *noteText) {
        NSString *note = noteText ?: @"";
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
                    if (success) {
                        [ErrorPresenter showSuccess:localize(@"crash.screen.send_ok", nil)
                                           message:[NSString stringWithFormat:localize(@"crash.screen.send_ok_msg", nil), logId ?: @""]];
                    } else {
                        [ErrorPresenter showNetworkError:error message:@"Send failed."];
                    }
                }];
            });
        }];
        (void)job;
    }];
}

- (void)actionClose {
    crashScreenCloseLauncher();
}

@end
