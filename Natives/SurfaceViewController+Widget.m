#import "SurfaceViewController+Widget.h"
#import "LauncherPreferences.h"
#import "ThemeManager.h"
#import "utils.h"
#import "system_monitor.h"

#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSTimer *widgetTimer;
static BOOL widgetLastMenuOn;
static uint64_t widgetLastSwapCount;
static double widgetLastFpsTime;
static CGPoint widgetDragStartCenter;
static double widgetNormX = 0.5;
static double widgetNormY = 0.12;

static const CGFloat kWarnThreshold = 90.0;
static const CGFloat kTempWarnC = 42.0;
static const CGFloat kBatWarnPct = 20.0;
static const CGFloat kWidgetMinW = 170;
static double widgetCpuAvg = -1.0;
static double widgetGpuUsage = -1.0;
static double widgetTempC = -1.0;
static double widgetBattPct = -1.0;
static double widgetCores[TM_MAX_CORES];
static int widgetCoreCount = 0;
static double widgetSampleAt = 0;

static CGFloat widgetPrefScale(void) {
    id v = getPrefObject(@"general.widget_scale");
    double s = 100.0;
    if ([v respondsToSelector:@selector(doubleValue)]) s = [v doubleValue];
    if (!isfinite(s) || s <= 0.0) s = 100.0;
    return MAX(0.5, MIN(2.0, s / 100.0));
}

static UIColor *widgetCpuColor(void) {
    return [UIColor colorWithHue:0.56 saturation:0.85 brightness:1 alpha:1];
}

static UIColor *widgetGpuColor(void) {
    return [UIColor colorWithHue:0.09 saturation:0.85 brightness:1 alpha:1];
}

static UIColor *widgetTempColor(void) {
    return [UIColor colorWithHue:0.5 saturation:0.8 brightness:1 alpha:1];
}

static UIColor *widgetBattColor(void) {
    return [UIColor colorWithHue:0.32 saturation:0.9 brightness:1 alpha:1];
}

static NSString *widgetFormatBytes(uint64_t bytes) {
    if (bytes >= 1024ULL * 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f GB", bytes / 1073741824.0];
    }
    return [NSString stringWithFormat:@"%.0f MB", bytes / 1048576.0];
}

static NSString *widgetShortBytes(uint64_t bytes) {
    double gb = bytes / 1073741824.0;
    if (gb >= 1.0) {
        return [NSString stringWithFormat:gb >= 10.0 ? @"%.0fG" : @"%.1fG", gb];
    }
    return [NSString stringWithFormat:@"%.0fM", bytes / 1048576.0];
}

@interface TMWaveView : UIView
@property(nonatomic) CGFloat startHue;
@property(nonatomic) CGFloat endHue;
- (void)addSample:(double)value;
- (void)clearSamples;
@end

@implementation TMWaveView {
    NSMutableArray<NSNumber *> *_samples;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _samples = [NSMutableArray arrayWithCapacity:60];
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)addSample:(double)value {
    [_samples addObject:@(MAX(0.0, MIN(100.0, value)))];
    if (_samples.count > 60) {
        [_samples removeObjectAtIndex:0];
    }
    [self setNeedsDisplay];
}

- (void)clearSamples {
    [_samples removeAllObjects];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    NSUInteger count = _samples.count;
    CGFloat W = self.bounds.size.width;
    CGFloat H = self.bounds.size.height;
    if (count == 0 || W < 8) return;

    static const CGFloat step = 3.0;
    NSInteger maxN = (NSInteger)(W / step);
    NSInteger n = MIN((NSInteger)count, maxN);
    if (n < 1) return;

    CGFloat ys[60];
    CGFloat xs[60];
    CGFloat baseY = H - 2;
    for (NSInteger j = 0; j < n; j++) {
        double v = _samples[count - n + j].doubleValue;
        xs[j] = W - n * step + j * step;
        ys[j] = MAX(1, baseY - (CGFloat)(v / 100.0) * (H - 4));
    }

    UIColor *base = [UIColor colorWithHue:_startHue saturation:0.85 brightness:1 alpha:1];
    for (NSInteger j = 0; j < n - 1; j++) {
        double peak = MAX(_samples[count - n + j].doubleValue, _samples[count - n + j + 1].doubleValue);
        UIColor *segColor = peak >= kWarnThreshold ? UIColor.systemRedColor : base;
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(ctx, segColor.CGColor);
        CGContextSetLineWidth(ctx, 2);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx, xs[j], ys[j]);
        CGContextAddLineToPoint(ctx, xs[j + 1], ys[j + 1]);
        CGContextStrokePath(ctx);
    }

    UIBezierPath *area = [UIBezierPath bezierPath];
    [area moveToPoint:CGPointMake(xs[0], baseY)];
    for (NSInteger j = 0; j < n; j++) {
        [area addLineToPoint:CGPointMake(xs[j], ys[j])];
    }
    [area addLineToPoint:CGPointMake(xs[n - 1], baseY)];
    [area closePath];
    [[base colorWithAlphaComponent:0.22] setFill];
    [area fill];

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, UIColor.whiteColor.CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(xs[n - 1] - 1.5, ys[n - 1] - 1.5, 3, 3));
}

@end

@interface TMUsageRingView : UIView
@property(nonatomic) CGFloat usage;     // 0..1
@property(nonatomic) CGFloat startHue;
@property(nonatomic) CGFloat endHue;
@end

@implementation TMUsageRingView

- (void)setUsage:(CGFloat)usage {
    if (!isfinite(usage)) usage = 0.0;
    _usage = MAX(0.0, MIN(1.0, usage));
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
    if (side < 8) return;
    CGFloat center = side / 2;
    CGFloat radius = center - 2;
    CGFloat thickness = 2.5;

    // Subtle track so the ring is always visible even at 0%
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.16].CGColor);
    CGContextSetLineWidth(ctx, thickness);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextBeginPath(ctx);
    CGContextAddArc(ctx, center, center, radius, 0, M_PI * 2, 0);
    CGContextStrokePath(ctx);

    if (!isfinite(_usage) || _usage <= 0.001) return;

    static const int kSegments = 24;
    CGFloat startAngle = -M_PI * 0.5;
    for (int i = 0; i < kSegments; i++) {
        CGFloat fracStart = (CGFloat)i / kSegments;
        if (fracStart >= _usage) break;
        CGFloat fracEnd = MIN((CGFloat)(i + 1) / kSegments, _usage);
        CGFloat fracMid = (fracStart + fracEnd) / 2;
        CGFloat a1 = startAngle + fracStart * M_PI * 2;
        CGFloat a2 = startAngle + fracEnd * M_PI * 2;

        UIColor *color;
        if (fracMid >= 0.90) {
            color = UIColor.systemRedColor;
        } else {
            CGFloat hue = _startHue + (_endHue - _startHue) * fracMid;
            color = [UIColor colorWithHue:hue saturation:0.85 brightness:1 alpha:1];
        }
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextSetLineWidth(ctx, thickness);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextBeginPath(ctx);
        CGContextAddArc(ctx, center, center, radius, a1, a2, 0);
        CGContextStrokePath(ctx);
    }
}

@end

@implementation SurfaceViewController(Widget)

- (void)setupCategory_Widget {
    widgetLastMenuOn = getPrefBool(@"general.widget_menu");
    self.savedEdgeGestureEnabled = self.edgeGesture.enabled;

    if (!self.widgetView) {
        self.widgetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kWidgetMinW, 44)];
        self.widgetView.backgroundColor = UIColor.clearColor;
        self.widgetView.layer.cornerRadius = 14;
        self.widgetView.clipsToBounds = YES;
        self.widgetView.userInteractionEnabled = YES;
        [self.view addSubview:self.widgetView];

        self.widgetEmptyIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.widgetEmptyIcon.contentMode = UIViewContentModeScaleAspectFit;
        self.widgetEmptyIcon.image = [UIImage imageNamed:@"AppLogo-Vector"];
        if (!self.widgetEmptyIcon.image) {
            self.widgetEmptyIcon.image = [UIImage systemImageNamed:@"gauge"];
            self.widgetEmptyIcon.tintColor = [UIColor colorWithWhite:1 alpha:0.75];
        }
        self.widgetEmptyIcon.hidden = YES;
        [self.widgetView addSubview:self.widgetEmptyIcon];


        self.widgetFpsLabel = [self widgetMakeLabelWithFontSize:14 weight:UIFontWeightSemibold];
        [self.widgetView addSubview:self.widgetFpsLabel];

        self.widgetRamLabel = [self widgetMakeLabelWithFontSize:12 weight:UIFontWeightMedium];
        self.widgetRamLabel.textColor = [UIColor colorWithWhite:1 alpha:0.92];
        [self.widgetView addSubview:self.widgetRamLabel];

        self.widgetTempLabel = [self widgetMakeLabelWithFontSize:12 weight:UIFontWeightMedium];
        self.widgetTempLabel.textColor = widgetTempColor();
        [self.widgetView addSubview:self.widgetTempLabel];

        self.widgetBattLabel = [self widgetMakeLabelWithFontSize:12 weight:UIFontWeightMedium];
        self.widgetBattLabel.textColor = widgetBattColor();
        [self.widgetView addSubview:self.widgetBattLabel];

        self.widgetBarView = [[UIView alloc] initWithFrame:CGRectZero];
        self.widgetBarView.layer.cornerRadius = 5;
        self.widgetBarView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        self.widgetBarView.clipsToBounds = YES;
        [self.widgetView addSubview:self.widgetBarView];

        self.widgetBarSegLauncher = [[UIView alloc] initWithFrame:CGRectZero];
        self.widgetBarSegLauncher.layer.cornerRadius = 4;
        [self.widgetBarView addSubview:self.widgetBarSegLauncher];

        self.widgetBarSegDevice = [[UIView alloc] initWithFrame:CGRectZero];
        self.widgetBarSegDevice.layer.cornerRadius = 4;
        [self.widgetBarView addSubview:self.widgetBarSegDevice];

        self.widgetBarSegLauncherLabel = [self widgetMakeBarLabel];
        [self.widgetBarView addSubview:self.widgetBarSegLauncherLabel];

        self.widgetBarSegDeviceLabel = [self widgetMakeBarLabel];
        [self.widgetBarView addSubview:self.widgetBarSegDeviceLabel];

        self.widgetBarSegFreeLabel = [self widgetMakeBarLabel];
        self.widgetBarSegFreeLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
        [self.widgetBarView addSubview:self.widgetBarSegFreeLabel];

        self.widgetCpuPercentLabel = [self widgetMakeLabelWithFontSize:12 weight:UIFontWeightSemibold];
        [self.widgetView addSubview:self.widgetCpuPercentLabel];
        self.widgetGpuPercentLabel = [self widgetMakeLabelWithFontSize:12 weight:UIFontWeightSemibold];
        [self.widgetView addSubview:self.widgetGpuPercentLabel];

        self.widgetCpuNameLabel = [self widgetMakeMiniNameLabel];
        [self.widgetView addSubview:self.widgetCpuNameLabel];
        TMWaveView *cpuWave = [[TMWaveView alloc] initWithFrame:CGRectZero];
        cpuWave.startHue = 0.54;
        cpuWave.endHue = 0.68;
        self.widgetCpuBar = cpuWave;
        [self.widgetView addSubview:self.widgetCpuBar];
        self.widgetCpuBarLabel = [self widgetMakeChipLabel];
        self.widgetCpuBarLabel.textAlignment = NSTextAlignmentRight;
        [self.widgetCpuBar addSubview:self.widgetCpuBarLabel];

        self.widgetGpuNameLabel = [self widgetMakeMiniNameLabel];
        [self.widgetView addSubview:self.widgetGpuNameLabel];
        TMWaveView *gpuWave = [[TMWaveView alloc] initWithFrame:CGRectZero];
        gpuWave.startHue = 0.07;
        gpuWave.endHue = 0.12;
        self.widgetGpuBar = gpuWave;
        [self.widgetView addSubview:self.widgetGpuBar];
        self.widgetGpuBarLabel = [self widgetMakeChipLabel];
        self.widgetGpuBarLabel.textAlignment = NSTextAlignmentRight;
        [self.widgetGpuBar addSubview:self.widgetGpuBarLabel];

        TMUsageRingView *cpuRing = [[TMUsageRingView alloc] initWithFrame:CGRectZero];
        cpuRing.startHue = 0.54;
        cpuRing.endHue = 0.68;
        self.widgetCpuRing = cpuRing;
        [self.widgetView addSubview:self.widgetCpuRing];
        self.widgetCpuRingLabel = [self widgetMakeMiniNameLabel];
        self.widgetCpuRingLabel.textAlignment = NSTextAlignmentCenter;
        [self.widgetView addSubview:self.widgetCpuRingLabel];
        self.widgetCpuRingPercentLabel = [self widgetMakeRingPercentLabel];
        [self.widgetView addSubview:self.widgetCpuRingPercentLabel];

        TMUsageRingView *gpuRing = [[TMUsageRingView alloc] initWithFrame:CGRectZero];
        gpuRing.startHue = 0.07;
        gpuRing.endHue = 0.12;
        self.widgetGpuRing = gpuRing;
        [self.widgetView addSubview:self.widgetGpuRing];
        self.widgetGpuRingLabel = [self widgetMakeMiniNameLabel];
        self.widgetGpuRingLabel.textAlignment = NSTextAlignmentCenter;
        [self.widgetView addSubview:self.widgetGpuRingLabel];
        self.widgetGpuRingPercentLabel = [self widgetMakeRingPercentLabel];
        [self.widgetView addSubview:self.widgetGpuRingPercentLabel];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(widgetTapped:)];
        [self.widgetView addGestureRecognizer:tap];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(widgetDragged:)];
        [self.widgetView addGestureRecognizer:pan];

        [self buildWidgetPanel];
    }

    [self widgetRepositionFromDefaults];
    [self updateWidgetMode];

    [self widgetStopTimer];
    widgetTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(widgetTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:widgetTimer forMode:NSRunLoopCommonModes];
    [self widgetTick];
}

- (void)buildWidgetPanel {
    CGFloat panelW = MIN(220, self.view.bounds.size.width * 0.6);
    NSInteger count = self.menuArray.count;
    CGFloat panelH = 6 + count * 46 + 6;

    self.widgetPanelBackdrop = [[UIView alloc] initWithFrame:self.view.bounds];
    self.widgetPanelBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.widgetPanelBackdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    self.widgetPanelBackdrop.hidden = YES;
    UITapGestureRecognizer *backdropTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(widgetClosePanel)];
    [self.widgetPanelBackdrop addGestureRecognizer:backdropTap];
    [self.view addSubview:self.widgetPanelBackdrop];

    self.widgetPanelView = [[UIView alloc] initWithFrame:CGRectMake(-panelW, 0, panelW, panelH)];
    self.widgetPanelView.backgroundColor = [UIColor colorWithWhite:0.09 alpha:0.85];
    self.widgetPanelView.layer.cornerRadius = 16;
    self.widgetPanelView.clipsToBounds = YES;
    self.widgetPanelView.hidden = YES;

    CGFloat py = 6;
    for (NSInteger i = 0; i < count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = i;
        btn.frame = CGRectMake(6, py, panelW - 12, 40);
        [btn setTitle:localize(self.menuArray[i], nil) forState:UIControlStateNormal];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
        btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        btn.layer.cornerRadius = 10;
        [btn addTarget:self action:@selector(widgetPanelSelect:) forControlEvents:UIControlEventTouchUpInside];
        [self.widgetPanelView addSubview:btn];
        py += 46;
    }
    [self.view addSubview:self.widgetPanelView];
}

- (UILabel *)widgetMakeLabelWithFontSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentLeft;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.6;
    [self widgetApplyTextShadow:label];
    return label;
}

- (UILabel *)widgetMakeBarLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    [self widgetApplyTextShadow:label];
    return label;
}

- (UILabel *)widgetMakeChipLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont monospacedDigitSystemFontOfSize:7.5 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    [self widgetApplyTextShadow:label];
    return label;
}

- (UILabel *)widgetMakeMiniNameLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont systemFontOfSize:7 weight:UIFontWeightBold];
    label.textColor = UIColor.whiteColor;
    [self widgetApplyTextShadow:label];
    return label;
}

- (UILabel *)widgetMakeRingPercentLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.6;
    [self widgetApplyTextShadow:label];
    return label;
}

- (void)widgetApplyTextShadow:(UILabel *)label {
    label.shadowColor = [UIColor colorWithWhite:0 alpha:0.85];
    label.shadowOffset = CGSizeMake(0, 1);
}

- (void)widgetStopTimer {
    [widgetTimer invalidate];
    widgetTimer = nil;
}

- (void)widgetSetCenter:(CGPoint)center {
    UIView *parent = self.view;
    CGSize s = self.widgetView.frame.size;
    CGFloat minX = s.width / 2 + 4;
    CGFloat maxX = parent.bounds.size.width - s.width / 2 - 4;
    CGFloat minY = s.height / 2 + 4;
    CGFloat maxY = parent.bounds.size.height - s.height / 2 - 4;
    self.widgetView.center = CGPointMake(
        MAX(minX, MIN(maxX, center.x)),
        MAX(minY, MIN(maxY, center.y)));
    if (parent.bounds.size.width > 0 && parent.bounds.size.height > 0) {
        widgetNormX = self.widgetView.center.x / parent.bounds.size.width;
        widgetNormY = self.widgetView.center.y / parent.bounds.size.height;
    }
}

- (void)widgetSavePosition {
    CGSize b = self.view.bounds.size;
    if (b.width > 0 && b.height > 0) {
        NSString *pos = [NSString stringWithFormat:@"%.3f,%.3f",
            self.widgetView.center.x / b.width, self.widgetView.center.y / b.height];
        setPrefObject(@"general.widget_position", pos);
    }
}

- (void)widgetLayoutPanel:(BOOL)offscreen {
    CGFloat panelW = self.widgetPanelView.bounds.size.width;
    CGFloat cx = self.view.bounds.size.width / 2;
    CGFloat cy = self.view.bounds.size.height / 2;
    self.widgetPanelView.center = CGPointMake(offscreen ? -panelW / 2 : panelW / 2 + 12, cy);
}

- (void)widgetRepositionFromDefaults {
    if (!self.widgetView || self.view.bounds.size.width == 0) return;

    CGPoint p = CGPointMake(0.5, 0.12);
    NSString *saved = getPrefObject(@"general.widget_position");
    if ([saved isKindOfClass:[NSString class]] && saved.length > 0) {
        NSArray<NSString *> *parts = [saved componentsSeparatedByString:@","];
        if (parts.count == 2) {
            p = CGPointMake([parts[0] doubleValue], [parts[1] doubleValue]);
        }
    }
    CGSize b = self.view.bounds.size;
    [self widgetSetCenter:CGPointMake(
        b.width * MAX(0.02, MIN(0.98, p.x)),
        b.height * MAX(0.02, MIN(0.98, p.y)))];

    if (self.widgetPanelView) {
        self.widgetPanelBackdrop.frame = self.view.bounds;
        [self widgetLayoutPanel:self.widgetPanelView.hidden];
    }
}

#pragma mark - Panel

- (void)widgetOpenPanel {
    if (!self.widgetPanelView.hidden) return;
    self.widgetPanelView.hidden = NO;
    self.widgetPanelBackdrop.hidden = NO;
    [self widgetLayoutPanel:YES];
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5
        options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self widgetLayoutPanel:NO];
    } completion:nil];
}

- (void)widgetClosePanel {
    [self widgetClosePanelWithCompletion:nil];
}

- (void)widgetClosePanelWithCompletion:(void (^)(void))completion {
    if (self.widgetPanelView.hidden) {
        self.widgetPanelBackdrop.hidden = YES;
        if (completion) completion();
        return;
    }
    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        [self widgetLayoutPanel:YES];
    } completion:^(BOOL finished) {
        self.widgetPanelView.hidden = YES;
        self.widgetPanelBackdrop.hidden = YES;
        if (completion) completion();
    }];
}

- (void)widgetPanelSelect:(UIButton *)btn {
    NSInteger idx = btn.tag;
    [self widgetClosePanelWithCompletion:^{
        [self didSelectMenuItem:(int)idx];
    }];
}

- (void)widgetTapped:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateRecognized) return;
    if (self.menuView && !self.menuView.hidden) return;
    if (self.widgetPanelView.hidden) {
        [self widgetOpenPanel];
    } else {
        [self widgetClosePanel];
    }
}

- (void)widgetDragged:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        widgetDragStartCenter = self.widgetView.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [pan translationInView:self.view];
        [self widgetSetCenter:CGPointMake(widgetDragStartCenter.x + t.x, widgetDragStartCenter.y + t.y)];
    } else if (pan.state == UIGestureRecognizerStateEnded ||
               pan.state == UIGestureRecognizerStateCancelled) {
        [self widgetSavePosition];
    }
}

- (void)updateWidgetMode {
    BOOL on = getPrefBool(@"general.widget_menu");

    // Switching modes must always bring the game back to its neutral
    // full-screen state: if the edge-swipe menu (menuView) is stuck open or
    // the root view is mid-scale, restore it. Otherwise the user is left
    // stranded on the scaled "edge swipe" screen with no way to close it.
    if (self.menuView && !self.menuView.hidden) {
        [self animateMenuScale:1 duration:0.25];
    }
    if (self.widgetPanelView) {
        self.widgetPanelView.hidden = YES;
        self.widgetPanelBackdrop.hidden = YES;
        [self widgetLayoutPanel:YES];
    }

    if (on) {
        self.edgeGesture.enabled = NO;
        [self setEdgeSwipeUIHidden:YES];
    } else {
        self.edgeGesture.enabled = self.savedEdgeGestureEnabled;
        [self setEdgeSwipeUIHidden:NO];
    }
}

#pragma mark - Data

- (void)widgetTick {
    if (!self.widgetView) return;

    BOOL widgetOn = getPrefBool(@"general.widget_menu");
    if (widgetOn != widgetLastMenuOn) {
        widgetLastMenuOn = widgetOn;
        [self updateWidgetMode];
    }

    BOOL menuOpen = self.menuView != nil && !self.menuView.hidden;
    self.widgetView.hidden = !widgetOn || menuOpen;
    if (!widgetOn || menuOpen) return;

    // Adjustable backdrop: 0 = fully transparent, 80 = fairly dark
    CGFloat bgAlpha = MAX(0.0, MIN(0.8, getPrefFloat(@"general.widget_bg_opacity") / 100.0));
    self.widgetView.backgroundColor = [UIColor colorWithWhite:0 alpha:bgAlpha];

    BOOL fpsOn = getPrefBool(@"general.widget_show_fps");
    NSString *ramStyle = getPrefObject(@"general.widget_ram_style");
    if (![ramStyle isKindOfClass:[NSString class]]) ramStyle = @"none";

    // FPS: derive from actual game swap count
    uint64_t swapCount = pojavSwapCount();
    double now = CACurrentMediaTime();
    if (fpsOn) {
        if (widgetLastFpsTime > 0) {
            double dt = now - widgetLastFpsTime;
            if (dt >= 0.95) {
                double fps = (swapCount - widgetLastSwapCount) / dt;
                if (fps >= 0) {
                    self.widgetFpsLabel.text = [NSString stringWithFormat:@"FPS: %lu", (unsigned long)lround(fps)];
                }
                widgetLastSwapCount = swapCount;
                widgetLastFpsTime = now;
            }
        } else {
            widgetLastSwapCount = swapCount;
            widgetLastFpsTime = now;
        }
    } else {
        widgetLastSwapCount = 0;
        widgetLastFpsTime = 0;
    }

    // CPU/GPU/temperature/battery: sample at ~1Hz when any unit is enabled
    BOOL cpuOn = getPrefBool(@"general.widget_show_cpu");
    BOOL gpuOn = getPrefBool(@"general.widget_show_gpu");
    BOOL tempOn = getPrefBool(@"general.widget_show_temp");
    BOOL battOn = getPrefBool(@"general.widget_show_batt");
    NSString *cgStyle = getPrefObject(@"general.widget_cpu_style");
    if (![cgStyle isKindOfClass:[NSString class]]) cgStyle = @"percent";
    BOOL cgBars = [cgStyle isEqualToString:@"bars"];
    BOOL cgRing = [cgStyle isEqualToString:@"ring"];

    if (cpuOn || gpuOn || tempOn || battOn) {
        double nowSys = CACurrentMediaTime();
        if (widgetSampleAt == 0 || nowSys - widgetSampleAt >= 0.9) {
            [self widgetSampleSystemUsage];
            widgetSampleAt = nowSys;
        }
    } else {
        widgetSampleAt = 0;
        widgetCpuAvg = -1.0;
        widgetGpuUsage = -1.0;
        widgetTempC = -1.0;
        widgetBattPct = -1.0;
        widgetCoreCount = 0;
    }

    // RAM: device used, launcher (app) used, total, free
    uint64_t totalBytes = NSProcessInfo.processInfo.physicalMemory;
    uint64_t usedBytes = 0;
    uint64_t appBytes = 0;
    vm_size_t pageSize = 0;
    host_page_size(mach_host_self(), &pageSize);
    if (pageSize > 0) {
        vm_statistics64_data_t vmStats;
        mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
        if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStats, &count) == KERN_SUCCESS) {
            uint64_t availableBytes = (vmStats.free_count + vmStats.inactive_count + vmStats.speculative_count) * pageSize;
            usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0;
        }
        task_vm_info_data_t taskInfo;
        mach_msg_type_number_t tcount = TASK_VM_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&taskInfo, &tcount) == KERN_SUCCESS) {
            appBytes = taskInfo.phys_footprint;
        }
    }
    uint64_t freeBytes = totalBytes > usedBytes ? totalBytes - usedBytes : 0;

    BOOL ramTextOn = [ramStyle isEqualToString:@"text"];
    BOOL ramBarOn = [ramStyle isEqualToString:@"bar"];
    self.widgetFpsLabel.hidden = !fpsOn;
    self.widgetRamLabel.hidden = !ramTextOn;
    self.widgetBarView.hidden = !ramBarOn;

    if (cpuOn || gpuOn) {
        if (!cgBars && !cgRing) {
            [self widgetUpdatePercentLabel:self.widgetCpuPercentLabel name:@"CPU" usage:widgetCpuAvg color:widgetCpuColor()];
            [self widgetUpdatePercentLabel:self.widgetGpuPercentLabel name:@"GPU" usage:widgetGpuUsage color:widgetGpuColor()];
        } else if (cgBars) {
            self.widgetCpuNameLabel.text = @"CPU";
            self.widgetGpuNameLabel.text = @"GPU";
            self.widgetCpuNameLabel.textColor = (widgetCpuAvg >= kWarnThreshold) ? UIColor.systemRedColor : widgetCpuColor();
            self.widgetGpuNameLabel.textColor = (widgetGpuUsage >= kWarnThreshold) ? UIColor.systemRedColor : widgetGpuColor();
            if (cpuOn) {
                if (widgetCpuAvg >= 0) {
                    [(TMWaveView *)self.widgetCpuBar addSample:widgetCpuAvg];
                    self.widgetCpuBarLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(widgetCpuAvg)];
                } else {
                    [(TMWaveView *)self.widgetCpuBar clearSamples];
                    self.widgetCpuBarLabel.text = @"\u2013";
                }
            } else {
                [(TMWaveView *)self.widgetCpuBar clearSamples];
            }
            if (gpuOn) {
                if (widgetGpuUsage >= 0) {
                    [(TMWaveView *)self.widgetGpuBar addSample:widgetGpuUsage];
                    self.widgetGpuBarLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(widgetGpuUsage)];
                } else {
                    [(TMWaveView *)self.widgetGpuBar clearSamples];
                    self.widgetGpuBarLabel.text = @"\u2013";
                }
            } else {
                [(TMWaveView *)self.widgetGpuBar clearSamples];
            }
        } else {
            [(TMUsageRingView *)self.widgetCpuRing setUsage:widgetCpuAvg >= 0 ? (CGFloat)(widgetCpuAvg / 100.0) : 0];
            [(TMUsageRingView *)self.widgetGpuRing setUsage:widgetGpuUsage >= 0 ? (CGFloat)(widgetGpuUsage / 100.0) : 0];
            self.widgetCpuRingLabel.text = @"CPU";
            self.widgetGpuRingLabel.text = @"GPU";
            BOOL cpuWarn = widgetCpuAvg >= kWarnThreshold;
            BOOL gpuWarn = widgetGpuUsage >= kWarnThreshold;
            self.widgetCpuRingLabel.textColor = cpuWarn ? UIColor.systemRedColor : widgetCpuColor();
            self.widgetGpuRingLabel.textColor = gpuWarn ? UIColor.systemRedColor : widgetGpuColor();
            self.widgetCpuRingPercentLabel.text = widgetCpuAvg >= 0
                ? [NSString stringWithFormat:@"%d%%", (int)lround(widgetCpuAvg)]
                : @"\u2013";
            self.widgetGpuRingPercentLabel.text = widgetGpuUsage >= 0
                ? [NSString stringWithFormat:@"%d%%", (int)lround(widgetGpuUsage)]
                : @"\u2013";
            self.widgetCpuRingPercentLabel.textColor = cpuWarn ? UIColor.systemRedColor : UIColor.whiteColor;
            self.widgetGpuRingPercentLabel.textColor = gpuWarn ? UIColor.systemRedColor : UIColor.whiteColor;
        }
    }
    self.widgetCpuPercentLabel.hidden = !(cpuOn && !cgBars && !cgRing);
    self.widgetGpuPercentLabel.hidden = !(gpuOn && !cgBars && !cgRing);
    self.widgetCpuNameLabel.hidden = !(cpuOn && cgBars);
    self.widgetCpuBar.hidden = !(cpuOn && cgBars);
    self.widgetGpuNameLabel.hidden = !(gpuOn && cgBars);
    self.widgetGpuBar.hidden = !(gpuOn && cgBars);
    self.widgetCpuRing.hidden = !(cpuOn && cgRing);
    self.widgetCpuRingLabel.hidden = !(cpuOn && cgRing);
    self.widgetCpuRingPercentLabel.hidden = !(cpuOn && cgRing);
    self.widgetGpuRing.hidden = !(gpuOn && cgRing);
    self.widgetGpuRingLabel.hidden = !(gpuOn && cgRing);
    self.widgetGpuRingPercentLabel.hidden = !(gpuOn && cgRing);

    if (ramTextOn) {
        self.widgetRamLabel.text = [NSString stringWithFormat:@"RAM %@ / %@",
            widgetFormatBytes(usedBytes), widgetFormatBytes(totalBytes)];
    }

    self.widgetTempLabel.hidden = !tempOn;
    if (tempOn) {
        id unitObj = getPrefObject(@"general.widget_temp_unit");
        BOOL useF = [unitObj isKindOfClass:[NSString class]] && [unitObj isEqualToString:@"f"];
        if (widgetTempC >= 0) {
            double v = useF ? widgetTempC * 9.0 / 5.0 + 32.0 : widgetTempC;
            self.widgetTempLabel.text = [NSString stringWithFormat:@"TEMP %.1f\u00B0%@", v, useF ? @"F" : @"C"];
            self.widgetTempLabel.textColor = (widgetTempC >= kTempWarnC) ? UIColor.systemRedColor : widgetTempColor();
        } else {
            self.widgetTempLabel.text = @"TEMP \u2013";
            self.widgetTempLabel.textColor = widgetTempColor();
        }
    }

    self.widgetBattLabel.hidden = !battOn;
    if (battOn) {
        if (widgetBattPct >= 0) {
            self.widgetBattLabel.text = [NSString stringWithFormat:@"BAT %d%%", (int)lround(widgetBattPct)];
            self.widgetBattLabel.textColor = (widgetBattPct <= kBatWarnPct) ? UIColor.systemRedColor : widgetBattColor();
        } else {
            self.widgetBattLabel.text = @"BAT \u2013";
            self.widgetBattLabel.textColor = widgetBattColor();
        }
    }

    // Tight layout: size widget to content
    CGFloat xPad = 8;
    CGFloat yPad = 6;
    CGFloat barH = 18;
    CGFloat minBarW = 150;
    CGFloat contentW = 0;
    if (fpsOn) {
        contentW = MAX(contentW, ceil([self.widgetFpsLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 15)].width));
    }
    if (ramTextOn) {
        contentW = MAX(contentW, ceil([self.widgetRamLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width));
    }
    if (ramBarOn) {
        contentW = MAX(contentW, minBarW);
    }
    if (tempOn) {
        contentW = MAX(contentW, ceil([self.widgetTempLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width));
    }
    if (battOn) {
        contentW = MAX(contentW, ceil([self.widgetBattLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width));
    }
    if (cpuOn || gpuOn) {
        if (!cgBars && !cgRing) {
            CGFloat w1 = cpuOn ? ceil([self.widgetCpuPercentLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width) : 0;
            CGFloat w2 = gpuOn ? ceil([self.widgetGpuPercentLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width) : 0;
            if (w1 + w2 > 0) {
                contentW = MAX(contentW, w1 + w2 + (cpuOn && gpuOn ? 10 : 0));
            }
        } else if (cgBars) {
            contentW = MAX(contentW, 170);
        } else {
            NSInteger n = (cpuOn ? 1 : 0) + (gpuOn ? 1 : 0);
            if (n > 0) {
                contentW = MAX(contentW, 42 * n + 14 * (n - 1));
            }
        }
    }
    CGFloat widgetW = contentW + xPad * 2;
    CGFloat barW = widgetW - xPad * 2;

    CGFloat nameW = 20;
    CGFloat nameGap = 6;
    CGFloat cgBarW = barW - nameW - nameGap;
    if (cgBars) {
        self.widgetCpuBarLabel.hidden = cgBarW < 46;
        self.widgetGpuBarLabel.hidden = cgBarW < 46;
    }

    CGFloat y = yPad;
    if (fpsOn) {
        self.widgetFpsLabel.frame = CGRectMake(xPad, y, barW, 15);
        y += 17;
    }
    if (ramBarOn) {
        self.widgetBarView.frame = CGRectMake(xPad, y, barW, barH);
        [self widgetLayoutBarWithWidth:barW height:barH
            usedBytes:usedBytes appBytes:appBytes usedFrac:MIN(1.0, (CGFloat)usedBytes / MAX(totalBytes, 1))
            freeBytes:freeBytes totalBytes:totalBytes];
        y += barH + 5;
    } else if (ramTextOn) {
        self.widgetRamLabel.frame = CGRectMake(xPad, y, barW, 14);
        y += 16;
    }

    if (tempOn) {
        self.widgetTempLabel.frame = CGRectMake(xPad, y, barW, 14);
        y += 16;
    }

    if (battOn) {
        self.widgetBattLabel.frame = CGRectMake(xPad, y, barW, 14);
        y += 16;
    }

    if (cpuOn || gpuOn) {
        if (!cgBars && !cgRing) {
            CGFloat px = xPad;
            if (cpuOn) {
                CGFloat w = ceil([self.widgetCpuPercentLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width);
                self.widgetCpuPercentLabel.frame = CGRectMake(px, y, w, 13);
                px += w + 10;
            }
            if (gpuOn) {
                CGFloat w = ceil([self.widgetGpuPercentLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 14)].width);
                self.widgetGpuPercentLabel.frame = CGRectMake(px, y, w, 13);
            }
            y += 15;
        } else if (cgBars) {
            CGFloat waveH = 32;
            if (cpuOn) {
                self.widgetCpuNameLabel.frame = CGRectMake(xPad, y, nameW, 8);
                self.widgetCpuBar.frame = CGRectMake(xPad + nameW + nameGap, y + 8, cgBarW, waveH);
                self.widgetCpuBarLabel.frame = CGRectMake(cgBarW - 46, 1, 44, 8);
                y += 8 + waveH + 4;
            }
            if (gpuOn) {
                self.widgetGpuNameLabel.frame = CGRectMake(xPad, y, nameW, 8);
                self.widgetGpuBar.frame = CGRectMake(xPad + nameW + nameGap, y + 8, cgBarW, waveH);
                self.widgetGpuBarLabel.frame = CGRectMake(cgBarW - 46, 1, 44, 8);
                y += 8 + waveH + 4;
            }
        } else {
            CGFloat ringD = 42;
            if (cpuOn) {
                self.widgetCpuRing.frame = CGRectMake(xPad, y, ringD, ringD);
                self.widgetCpuRingPercentLabel.frame = CGRectMake(xPad + 3, y + 11, ringD - 6, 18);
                self.widgetCpuRingLabel.frame = CGRectMake(xPad - 6, y + ringD, ringD + 12, 9);
            }
            if (gpuOn) {
                CGFloat gx = cpuOn ? xPad + ringD + 14 : xPad;
                self.widgetGpuRing.frame = CGRectMake(gx, y, ringD, ringD);
                self.widgetGpuRingPercentLabel.frame = CGRectMake(gx + 3, y + 11, ringD - 6, 18);
                self.widgetGpuRingLabel.frame = CGRectMake(gx - 6, y + ringD, ringD + 12, 9);
            }
            y += ringD + 11;
        }
    }
    CGFloat height = y + yPad - 5;

    BOOL anyContentOn = fpsOn || ramTextOn || ramBarOn || tempOn || battOn || cpuOn || gpuOn;
    if (!anyContentOn) {
        // Nothing enabled yet: keep a visible tile instead of an invisible sliver
        self.widgetEmptyIcon.hidden = NO;
        self.widgetEmptyIcon.frame = CGRectMake((kWidgetMinW - 26) / 2, 9, 26, 26);
        widgetW = kWidgetMinW;
        height = 44;
    } else {
        self.widgetEmptyIcon.hidden = YES;
    }

    CGRect vf = self.widgetView.frame;
    vf.size = CGSizeMake(widgetW, height);
    CGFloat wscale = widgetPrefScale();
    self.widgetView.transform = CGAffineTransformIdentity;
    self.widgetView.frame = vf;
    self.widgetView.transform = CGAffineTransformMakeScale(wscale, wscale);
    CGSize par = self.view.bounds.size;
    [self widgetSetCenter:CGPointMake(par.width * widgetNormX, par.height * widgetNormY)];
}

- (void)widgetLayoutBarWithWidth:(CGFloat)trackW height:(CGFloat)barH
                       usedBytes:(uint64_t)usedBytes appBytes:(uint64_t)appBytes
                        usedFrac:(CGFloat)usedFrac freeBytes:(uint64_t)freeBytes totalBytes:(uint64_t)totalBytes {
    UIColor *accent = [ThemeManager.shared accentColor];
    UIColor *accentLight = [accent colorWithAlphaComponent:0.4];
    BOOL merged = !(appBytes > 0 && appBytes < usedBytes);

    CGFloat launcherEnd;
    CGFloat deviceEnd;
    self.widgetBarSegLauncher.backgroundColor = accent;
    self.widgetBarSegDevice.backgroundColor = accentLight;

    if (merged) {
        // Launcher RAM cannot be separated: launcher + device merged
        launcherEnd = trackW * usedFrac;
        deviceEnd = launcherEnd;
        self.widgetBarSegDevice.hidden = YES;
        self.widgetBarSegDeviceLabel.hidden = YES;
        self.widgetBarSegLauncher.frame = CGRectMake(0, 0, launcherEnd, barH);
        [self widgetSetSegmentLabel:self.widgetBarSegLauncherLabel frame:CGRectMake(0, 0, launcherEnd, barH) text:widgetShortBytes(usedBytes)];
    } else {
        CGFloat appF = MIN(1.0, (CGFloat)appBytes / MAX(totalBytes, 1));
        CGFloat otherFrac = MAX(0, MIN(usedFrac - appF, (CGFloat)(usedBytes - appBytes) / MAX(totalBytes, 1)));
        launcherEnd = trackW * appF;
        deviceEnd = launcherEnd + trackW * otherFrac;
        self.widgetBarSegDevice.hidden = NO;
        self.widgetBarSegDeviceLabel.hidden = NO;
        self.widgetBarSegLauncher.frame = CGRectMake(0, 0, launcherEnd, barH);
        self.widgetBarSegDevice.frame = CGRectMake(launcherEnd, 0, MAX(0, deviceEnd - launcherEnd), barH);
        [self widgetSetSegmentLabel:self.widgetBarSegLauncherLabel frame:CGRectMake(0, 0, launcherEnd, barH) text:widgetShortBytes(appBytes)];
        [self widgetSetSegmentLabel:self.widgetBarSegDeviceLabel frame:CGRectMake(launcherEnd, 0, MAX(0, deviceEnd - launcherEnd), barH) text:widgetShortBytes(usedBytes - appBytes)];
    }
    [self widgetSetSegmentLabel:self.widgetBarSegFreeLabel frame:CGRectMake(deviceEnd, 0, MAX(0, trackW - deviceEnd), barH) text:widgetShortBytes(freeBytes)];
}

- (void)widgetSampleSystemUsage {
    tm_cpu_usage_t usage;
    if (tm_cpu_usage(&usage) == 0) {
        widgetCpuAvg = usage.total;
        widgetCoreCount = MIN(usage.coreCount, TM_MAX_CORES);
        for (int i = 0; i < widgetCoreCount; i++) {
            widgetCores[i] = usage.cores[i];
        }
    } else {
        widgetCpuAvg = -1.0;
        widgetCoreCount = 0;
    }
    widgetGpuUsage = tm_gpu_usage_percent();
    widgetTempC = tm_battery_temperature_celsius();
    widgetBattPct = tm_battery_percent();
}

- (void)widgetUpdatePercentLabel:(UILabel *)label name:(NSString *)name usage:(double)usage color:(UIColor *)color {
    NSString *text;
    UIColor *textColor;
    if (usage < 0) {
        text = [NSString stringWithFormat:@"\u25CF %@ \u2013", name];
        textColor = [UIColor colorWithWhite:1 alpha:0.5];
    } else {
        text = [NSString stringWithFormat:@"\u25CF %@ %d%%", name, (int)lround(usage)];
        textColor = (usage >= kWarnThreshold) ? UIColor.systemRedColor : color;
    }
    label.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: textColor
    }];
}

- (void)widgetSetSegmentLabel:(UILabel *)label frame:(CGRect)frame text:(NSString *)text {
    label.frame = frame;
    label.hidden = frame.size.width < 26 || text.length == 0;
    label.text = text;
}

@end