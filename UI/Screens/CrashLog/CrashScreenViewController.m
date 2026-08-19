#import "CrashScreenViewController.h"
#import "CrashLogAnalyzer.h"
#import "ThemeManager.h"
#import "CustomButton.h"
#import "utils.h"
#import "ios_uikit_bridge.h"

static NSString *categoryLocalizedKey(CrashLogCategory category) {
    switch (category) {
        case CrashLogCategoryModConflict: return @"crash.screen.category.mod";
        case CrashLogCategoryError: return @"crash.screen.category.error";
        default: return @"crash.screen.category.raw";
    }
}

@interface CrashScreenViewController ()
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
@property (nonatomic, strong) CustomButton *closeButton;

@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@end

@implementation CrashScreenViewController

- (instancetype)initWithExitCode:(int)code {
    self = [super init];
    if (self) {
        _exitCode = code;
        _showingFullLog = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [self updateColors];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self runAnalysis];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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

    _closeButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleDestructive title:localize(@"crash.screen.close", nil)];
    [_closeButton addTarget:self action:@selector(actionClose) forControlEvents:UIControlEventTouchUpInside];
    [_buttonRow addArrangedSubview:_closeButton];

    _logTextView = [[UITextView alloc] init];
    _logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    _logTextView.editable = NO;
    _logTextView.selectable = YES;
    _logTextView.scrollEnabled = YES;
    _logTextView.alwaysBounceVertical = YES;
    _logTextView.font = [UIFont fontWithName:@"Menlo-Regular" size:13];
    _logTextView.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    _logTextView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    _logTextView.layer.cornerRadius = 10;
    _logTextView.layer.masksToBounds = YES;
    _logTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    [self.view addSubview:_logTextView];

    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.hidesWhenStopped = YES;
    _loadingIndicator.color = ThemeManager.shared.accentColor;
    [_logTextView addSubview:_loadingIndicator];

    [self layoutViews];
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

        [_logTextView.topAnchor constraintEqualToAnchor:_buttonRow.bottomAnchor constant:12],
        [_logTextView.leadingAnchor constraintEqualToAnchor:_leftPanel.trailingAnchor constant:16],
        [_logTextView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_logTextView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],

        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:_logTextView.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_logTextView.centerYAnchor],
    ]];
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
    _logTextView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
}

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
    self.logTextView.text = analysis.excerpt;
    if (analysis.excerpt.length > 0) {
        [self.logTextView scrollRangeToVisible:NSMakeRange(0, 0)];
    }
}

- (void)actionToggleLog {
    if (!self.analysis) return;
    self.showingFullLog = !self.showingFullLog;
    self.logTextView.text = self.showingFullLog ? self.analysis.fullLog : self.analysis.excerpt;
    [self.toggleButton setTitle:localize(self.showingFullLog ? @"crash.screen.toggle_excerpt" : @"crash.screen.toggle_full", nil)
                       forState:UIControlStateNormal];
    [self.logTextView scrollRangeToVisible:NSMakeRange(0, 0)];
}

- (void)actionShare {
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
        [items addObject:self.logTextView.text ?: @""];
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityVC.popoverPresentationController.sourceView = self.shareButton;
    activityVC.popoverPresentationController.sourceRect = self.shareButton.bounds;
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)actionClose {
    crashScreenCloseLauncher();
}

@end
