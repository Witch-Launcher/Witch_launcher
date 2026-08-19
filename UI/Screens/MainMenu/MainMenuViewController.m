#import "MainMenuViewController.h"
#import "ThemeManager.h"
#import "MarkdownRenderer.h"
#import "CreditsService.h"

static NSString *const NewsURLString = @"https://raw.githubusercontent.com/Ynnyny/Angel-Aura-Amethyst-iOS/refs/heads/main/news.md";
static const NSTimeInterval NewsRefreshInterval = 300.0; // 5 minutes

@interface MainMenuViewController () <WKNavigationDelegate>
@property (nonatomic) WKWebView *webView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *versionLabel;
@property (nonatomic) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) NSTimer *newsRefreshTimer;
@property (nonatomic) NSString *cachedMarkdown;
@end

@implementation MainMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [CreditsService.shared refreshIfNeeded];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [self loadNews];
    [self startNewsRefreshTimer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadNews];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_newsRefreshTimer invalidate];
}

- (void)startNewsRefreshTimer {
    [_newsRefreshTimer invalidate];
    _newsRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:NewsRefreshInterval
                                                         target:self
                                                       selector:@selector(loadNews)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)setup {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    _titleLabel.text = @"Witch Launcher";
    [self.view addSubview:_titleLabel];

    _versionLabel = [[UILabel alloc] init];
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
    _versionLabel.text = [NSString stringWithFormat:@"v%@", ver];
    [self.view addSubview:_versionLabel];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    _webView.navigationDelegate = self;
    _webView.layer.cornerRadius = 8;
    _webView.layer.masksToBounds = YES;
    _webView.backgroundColor = [UIColor clearColor];
    _webView.opaque = NO;
    _webView.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [self.view addSubview:_webView];

    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:_loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [_versionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
        [_versionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor constant:1],

        [_webView.topAnchor constraintEqualToAnchor:_versionLabel.bottomAnchor constant:12],
        [_webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16],

        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - News

- (void)loadNews {
    NSURL *url = [NSURL URLWithString:NewsURLString];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (self.cachedMarkdown) {
                    [self renderNews];
                } else {
                    [self showLoadError];
                }
                return;
            }
            NSString *markdown = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (markdown.length == 0) {
                if (self.cachedMarkdown) {
                    [self renderNews];
                } else {
                    [self showLoadError];
                }
                return;
            }
            self.cachedMarkdown = [self markdownForCurrentVersion:markdown];
            [self renderNews];
        });
    }] resume];
}

// news.md holds one "# … — <version>" section per release. Only keep the
// section matching the running launcher version; fall back to the whole
// file when the version isn't listed.
- (NSString *)markdownForCurrentVersion:(NSString *)markdown {
    NSString *appVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    if (appVersion.length == 0) return markdown;

    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    NSMutableString *currentSection = [NSMutableString string];

    for (NSString *line in [markdown componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"# "] && ![line hasPrefix:@"## "]) {
            if (currentSection.length > 0) {
                [sections addObject:currentSection];
            }
            currentSection = [NSMutableString stringWithString:line];
        } else if (currentSection.length > 0) {
            [currentSection appendFormat:@"\n%@", line];
        }
    }
    if (currentSection.length > 0) {
        [sections addObject:currentSection];
    }

    for (NSString *section in sections) {
        if ([section containsString:appVersion]) {
            return section;
        }
    }
    return markdown;
}

- (void)renderNews {
    if (self.cachedMarkdown.length == 0) return;

    ThemeManager *theme = ThemeManager.shared;
    UIColor *textColor = theme.primaryTextColor;
    UIColor *secondaryColor = theme.secondaryTextColor;
    UIColor *accentColor = theme.accentColor;
    UIColor *codeBgColor = theme.isDarkMode
        ? [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0]
        : [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1.0];

    NSString *html = [MarkdownRenderer htmlFromMarkdown:self.cachedMarkdown
                                              textColor:textColor
                                        secondaryColor:secondaryColor
                                           accentColor:accentColor
                                           codeBgColor:codeBgColor
                                                isDark:theme.isDarkMode];
    [self.webView loadHTMLString:html baseURL:nil];
}

- (void)showLoadError {
    ThemeManager *theme = ThemeManager.shared;
    NSString *html = [NSString stringWithFormat:
        @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0'>"
        "<style>body{font-family:-apple-system,sans-serif;padding:24px;background:transparent;color:%@}"
        "h2{color:%@;font-size:17px;margin:0 0 8px 0}p{color:%@;font-size:14px;line-height:1.5}</style></head>"
        "<body><h2>Latest News</h2><p>Unable to load news. Check your internet connection.</p></body></html>",
        [self hexStringFromColor:theme.primaryTextColor],
        [self hexStringFromColor:theme.accentColor],
        [self hexStringFromColor:theme.secondaryTextColor]];
    [self.webView loadHTMLString:html baseURL:nil];
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return @"#FFFFFF";
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _titleLabel.textColor = theme.primaryTextColor;
    _versionLabel.textColor = theme.secondaryTextColor;
    _webView.scrollView.indicatorStyle = theme.isDarkMode ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self renderNews];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [_loadingIndicator startAnimating];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [_loadingIndicator stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [_loadingIndicator stopAnimating];
}

@end
