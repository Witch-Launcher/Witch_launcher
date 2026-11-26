#import "PerfChartViewController.h"

#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "PerfChartRenderer.h"
#import "PerfRecorder.h"
#import "ThemeManager.h"
#import "utils.h"

@interface PerfChartViewController ()
@property (nonatomic) NSArray<PerfSession *> *sessions;
@property (nonatomic) PerfChartType chartType;
@property (nonatomic) NSString *metric;
@property (nonatomic) BOOL combine;
@property (nonatomic) UISegmentedControl *typeControl;
@property (nonatomic) UIButton *metricButton;
@property (nonatomic) UISwitch *combineSwitch;
@property (nonatomic) UIImageView *previewView;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UIView *exportBar;
@property (nonatomic) NSArray<UIButton *> *exportButtons;
@property (nonatomic, copy) UIImage *renderedImage;
@end

@implementation PerfChartViewController

- (instancetype)initWithSessions:(NSArray<PerfSession *> *)sessions {
    self = [super init];
    if (self) {
        _sessions = sessions;
        _chartType = PerfChartTypeLine;
        _metric = @"fps";
        _combine = NO;
        self.title = localize(@"perf.chart.title", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [scroll addSubview:stack];

    _typeControl = [[UISegmentedControl alloc] initWithItems:@[
        localize(@"perf.chart.type.line", nil),
        localize(@"perf.chart.type.bar", nil),
        localize(@"perf.chart.type.pie", nil),
    ]];
    _typeControl.selectedSegmentIndex = 0;
    [_typeControl addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_typeControl];

    UIView *metricRow = [self makeRow];
    _metricButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_metricButton setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    _metricButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    _metricButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [_metricButton addTarget:self action:@selector(pickMetric) forControlEvents:UIControlEventTouchUpInside];
    [self addRowTitle:localize(@"perf.chart.metric", nil) content:_metricButton toRow:metricRow];
    [stack addArrangedSubview:metricRow];

    UIView *combineRow = [self makeRow];
    _combineSwitch = [[UISwitch alloc] init];
    _combineSwitch.onTintColor = ThemeManager.shared.accentColor;
    [_combineSwitch addTarget:self action:@selector(combineChanged) forControlEvents:UIControlEventValueChanged];
    [self addRowTitle:localize(@"perf.chart.combine", nil) content:_combineSwitch toRow:combineRow];
    [stack addArrangedSubview:combineRow];

    _previewView = [[UIImageView alloc] init];
    _previewView.translatesAutoresizingMaskIntoConstraints = NO;
    _previewView.backgroundColor = UIColor.whiteColor;
    _previewView.contentMode = UIViewContentModeScaleAspectFit;
    _previewView.layer.borderWidth = 1;
    _previewView.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _previewView.layer.cornerRadius = 10;
    _previewView.clipsToBounds = YES;
    [stack addArrangedSubview:_previewView];
    [_previewView.heightAnchor constraintEqualToAnchor:_previewView.widthAnchor].active = YES;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.color = ThemeManager.shared.accentColor;
    [_previewView addSubview:_spinner];
    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerXAnchor constraintEqualToAnchor:_previewView.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:_previewView.centerYAnchor],
    ]];

    _exportBar = [[UIView alloc] init];
    _exportBar.translatesAutoresizingMaskIntoConstraints = NO;
    _exportBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _exportBar.layer.cornerRadius = 14;
    _exportBar.layer.cornerCurve = kCACornerCurveContinuous;

    UIStackView *exportRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self makeExportButton:localize(@"perf.chart.export_png", nil) icon:@"photo" action:@selector(exportPNG)],
        [self makeExportButton:localize(@"perf.chart.export_pdf", nil) icon:@"doc.richtext" action:@selector(exportPDF)],
        [self makeExportButton:localize(@"perf.chart.share", nil) icon:@"square.and.arrow.up" action:@selector(shareImage)],
    ]];
    exportRow.translatesAutoresizingMaskIntoConstraints = NO;
    exportRow.axis = UILayoutConstraintAxisHorizontal;
    exportRow.distribution = UIStackViewDistributionFillEqually;
    exportRow.spacing = 8;
    [_exportBar addSubview:exportRow];
    _exportButtons = (NSArray<UIButton *> *)exportRow.arrangedSubviews;

    [NSLayoutConstraint activateConstraints:@[
        [exportRow.topAnchor constraintEqualToAnchor:_exportBar.topAnchor],
        [exportRow.bottomAnchor constraintEqualToAnchor:_exportBar.bottomAnchor],
        [exportRow.leadingAnchor constraintEqualToAnchor:_exportBar.leadingAnchor constant:8],
        [exportRow.trailingAnchor constraintEqualToAnchor:_exportBar.trailingAnchor constant:-8],
        [_exportBar.heightAnchor constraintEqualToConstant:52],
    ]];
    [stack addArrangedSubview:_exportBar];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-32],
    ]];

    [self updateMetricButtonTitle];
    [self renderPreview];
}

- (UIView *)makeRow {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    row.layer.cornerRadius = 12;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    return row;
}

- (void)addRowTitle:(NSString *)title content:(UIView *)content toRow:(UIView *)row {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:15];
    label.textColor = ThemeManager.shared.primaryTextColor;
    label.text = title;
    [row addSubview:label];

    content.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:content.leadingAnchor constant:-8],

        [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [content.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (UIButton *)makeExportButton:(NSString *)title icon:(NSString *)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = ThemeManager.shared.accentColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 7, 0, 0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    _exportBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    for (UIButton *button in _exportButtons) {
        button.tintColor = ThemeManager.shared.accentColor;
    }
    _previewView.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
}

#pragma mark - Controls

- (void)typeChanged {
    _chartType = (PerfChartType)_typeControl.selectedSegmentIndex;
    [self renderPreview];
}

- (void)combineChanged {
    _combine = _combineSwitch.isOn;
    _metricButton.enabled = !_combine;
    _metricButton.alpha = _combine ? 0.4 : 1;
    [self renderPreview];
}

- (void)updateMetricButtonTitle {
    [_metricButton setTitle:[PerfChartRenderer displayNameForMetric:_metric] forState:UIControlStateNormal];
}

- (void)pickMetric {
    if (_combine) {
        return;
    }
    NSArray<NSString *> *names = PerfMetricNames();
    NSMutableArray<NSDictionary *> *options = [NSMutableArray new];
    NSInteger selected = 0;
    for (NSUInteger i = 0; i < names.count; i++) {
        [options addObject:@{@"title": [PerfChartRenderer displayNameForMetric:names[i]]}];
        if ([names[i] isEqualToString:_metric]) {
            selected = i;
        }
    }
    [AppSheet showOptionsWithTitle:localize(@"perf.chart.metric", nil)
                           message:nil
                           options:options
                     selectedIndex:selected
                         selection:^(NSInteger index) {
        if (index >= 0 && (NSUInteger)index < names.count) {
            self->_metric = names[index];
            [self updateMetricButtonTitle];
            [self renderPreview];
        }
    }];
}

#pragma mark - Rendering

- (NSArray<NSString *> *)metricsToRender {
    if (!_combine) {
        return @[_metric];
    }
    NSMutableArray<NSString *> *metrics = [NSMutableArray new];
    for (NSString *name in PerfMetricNames()) {
        for (PerfSession *session in _sessions) {
            if ([session hasMetric:name]) {
                [metrics addObject:name];
                break;
            }
        }
    }
    if (metrics.count == 0) {
        [metrics addObject:_metric];
    }
    if (metrics.count == 1) {
        return metrics;
    }
    return metrics;
}

- (void)renderPreview {
    [_spinner startAnimating];
    NSArray<PerfSession *> *sessions = _sessions;
    NSArray<NSString *> *metrics = [self metricsToRender];
    PerfChartType type = _chartType;
    BOOL combined = _combine;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [PerfChartRenderer imageForSessions:sessions
                                                     metrics:metrics
                                                        type:type
                                                    combined:combined && metrics.count > 1
                                                        side:1000];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.renderedImage = image;
            self.previewView.image = image;
            [self.spinner stopAnimating];
        });
    });
}

#pragma mark - Export

- (NSString *)writeTempFile:(NSData *)data extension:(NSString *)extension {
    NSString *name = [NSString stringWithFormat:@"witch_perf_%.0f.%@", NSDate.date.timeIntervalSince1970, extension];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:path atomically:YES];
    return path;
}

- (void)presentShareForItem:(id)item sourceView:(UIView *)sourceView {
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    avc.popoverPresentationController.sourceView = sourceView;
    avc.popoverPresentationController.sourceRect = sourceView.bounds;
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)exportPNG {
    UIImage *image = _renderedImage;
    if (!image) {
        return;
    }
    NSData *data = UIImagePNGRepresentation(image);
    NSString *path = [self writeTempFile:data extension:@"png"];
    [self presentShareForItem:[NSURL fileURLWithPath:path] sourceView:self.view];
}

- (void)exportPDF {
    NSArray<NSString *> *metrics = [self metricsToRender];
    NSData *data = [PerfChartRenderer pdfDataForSessions:_sessions
                                                 metrics:metrics
                                                    type:_chartType
                                                combined:_combine && metrics.count > 1
                                                    side:1000];
    NSString *path = [self writeTempFile:data extension:@"pdf"];
    [self presentShareForItem:[NSURL fileURLWithPath:path] sourceView:self.view];
}

- (void)shareImage {
    UIImage *image = _renderedImage;
    if (!image) {
        return;
    }
    [self presentShareForItem:image sourceView:self.view];
}

@end
