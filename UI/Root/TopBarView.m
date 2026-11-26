#import "TopBarView.h"
#import "ThemeManager.h"
#import "utils.h"
#import "LauncherPreferences.h"
#import "AmethystBlurView.h"
#import "UIView+LiquidGlass.h"
#import "DownloadManager.h"
#import <objc/runtime.h>

@interface TopBarView ()
@property (nonatomic) UILabel *jitStatusLabel;
@property (nonatomic) UILabel *timeLabel;
@property (nonatomic) UIStackView *progressStack;
@property (nonatomic) UIButton *fileManagerButton;
@property (nonatomic) UIButton *settingsButton;
@property (nonatomic) UIButton *downloadHubButton;
@property (nonatomic) UIButton *downloadInfoButton;
@property (nonatomic) NSTimer *timeTimer;
@property (nonatomic) NSTimer *jitTimer;
@end

@implementation TopBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _jitStatusLabel = [[UILabel alloc] init];
    _jitStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _jitStatusLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _jitStatusLabel.text = localize(@"jit.status", nil);
    [self addSubview:_jitStatusLabel];

    _timeLabel = [[UILabel alloc] init];
    _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_timeLabel];

    // Multi-download progress hub (replaces the clock while downloads run)
    _progressStack = [[UIStackView alloc] init];
    _progressStack.translatesAutoresizingMaskIntoConstraints = NO;
    _progressStack.axis = UILayoutConstraintAxisVertical;
    _progressStack.spacing = 3;
    _progressStack.alignment = UIStackViewAlignmentCenter;
    _progressStack.hidden = YES;
    [self addSubview:_progressStack];

    _fileManagerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _fileManagerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_fileManagerButton setImage:[UIImage systemImageNamed:@"folder"] forState:UIControlStateNormal];
    [_fileManagerButton addTarget:self action:@selector(fileTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_fileManagerButton];

    _settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_settingsButton setImage:[UIImage systemImageNamed:@"gearshape"] forState:UIControlStateNormal];
    [_settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_settingsButton];

    _downloadHubButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadHubButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_downloadHubButton setImage:[UIImage systemImageNamed:@"arrow.down.circle"] forState:UIControlStateNormal];
    [_downloadHubButton addTarget:self action:@selector(downloadHubTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_downloadHubButton];

    // Shown only while downloads are running: opens the detailed task list.
    _downloadInfoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadInfoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_downloadInfoButton setImage:[UIImage systemImageNamed:@"info.circle"] forState:UIControlStateNormal];
    [_downloadInfoButton addTarget:self action:@selector(downloadsInfoTapped) forControlEvents:UIControlEventTouchUpInside];
    _downloadInfoButton.hidden = YES;
    [self addSubview:_downloadInfoButton];

    [NSLayoutConstraint activateConstraints:@[
        [_jitStatusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [_jitStatusLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        [_timeLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_timeLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        [_progressStack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_progressStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_progressStack.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor multiplier:0.6],

        [_settingsButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [_settingsButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_settingsButton.widthAnchor constraintEqualToConstant:28],
        [_settingsButton.heightAnchor constraintEqualToConstant:28],

        [_fileManagerButton.trailingAnchor constraintEqualToAnchor:_settingsButton.leadingAnchor constant:-6],
        [_fileManagerButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_fileManagerButton.widthAnchor constraintEqualToConstant:28],
        [_fileManagerButton.heightAnchor constraintEqualToConstant:28],

        [_downloadHubButton.trailingAnchor constraintEqualToAnchor:_fileManagerButton.leadingAnchor constant:-6],
        [_downloadHubButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_downloadHubButton.widthAnchor constraintEqualToConstant:28],
        [_downloadHubButton.heightAnchor constraintEqualToConstant:28],

        [_downloadInfoButton.trailingAnchor constraintEqualToAnchor:_downloadHubButton.leadingAnchor constant:-4],
        [_downloadInfoButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_downloadInfoButton.widthAnchor constraintEqualToConstant:28],
        [_downloadInfoButton.heightAnchor constraintEqualToConstant:28],
    ]];

    [self updateTime];
    _timeTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(updateTime) userInfo:nil repeats:YES];

    // Check JIT status immediately and every 5 seconds
    [self checkJITStatus];
    _jitTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(checkJITStatus) userInfo:nil repeats:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:LiquidGlassDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildProgressRows) name:DownloadTasksDidChangeNotification object:nil];
        [self updateColors];
        [self rebuildProgressRows];
}

#pragma mark - Download progress hub

- (void)rebuildProgressRows {
    NSArray<DownloadTask *> *tasks = [DownloadManager.shared activeTasks];
    BOOL busy = tasks.count > 0;
    _timeLabel.hidden = busy;
    _progressStack.hidden = !busy;
    _downloadInfoButton.hidden = !busy;

    for (UIView *v in _progressStack.arrangedSubviews) [v removeFromSuperview];
    if (!busy) return;

    ThemeManager *theme = ThemeManager.shared;
    NSUInteger shown = MIN(tasks.count, (NSUInteger)3);
    for (NSUInteger i = 0; i < shown; i++) {
        DownloadTask *task = tasks[i];

        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *nameLabel = [[UILabel alloc] init];
        nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        nameLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        nameLabel.textColor = theme.primaryTextColor;
        nameLabel.text = task.name ?: localize(@"Downloading", nil);
        nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [row addSubview:nameLabel];

        UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.progressTintColor = theme.accentColor;
        bar.trackTintColor = theme.separatorColor;
        bar.progress = task.progress;
        [row addSubview:bar];

        UILabel *pct = [[UILabel alloc] init];
        pct.translatesAutoresizingMaskIntoConstraints = NO;
        pct.font = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightRegular];
        pct.textColor = theme.secondaryTextColor;
        pct.text = [NSString stringWithFormat:@"%d%%", (int)(task.progress * 100)];
        [row addSubview:pct];

        UILabel *speed = [[UILabel alloc] init];
        speed.translatesAutoresizingMaskIntoConstraints = NO;
        speed.font = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightRegular];
        speed.textColor = theme.secondaryTextColor;
        speed.textAlignment = NSTextAlignmentRight;
        speed.text = [self formatSpeed:task.bytesPerSecond];
        [row addSubview:speed];

        UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [cancelBtn setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
        cancelBtn.tintColor = theme.errorColor;
        objc_setAssociatedObject(cancelBtn, @selector(cancelTapped:), task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cancelBtn addTarget:self action:@selector(cancelTaskTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:cancelBtn];

        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintEqualToConstant:16],
            [nameLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [nameLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [nameLabel.widthAnchor constraintEqualToConstant:96],

            [bar.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:6],
            [bar.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [bar.widthAnchor constraintGreaterThanOrEqualToConstant:90],
            [bar.widthAnchor constraintLessThanOrEqualToConstant:150],

            [pct.leadingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:5],
            [pct.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [pct.widthAnchor constraintEqualToConstant:28],

            [speed.leadingAnchor constraintEqualToAnchor:pct.trailingAnchor constant:4],
            [speed.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [speed.widthAnchor constraintEqualToConstant:52],

            [cancelBtn.leadingAnchor constraintEqualToAnchor:speed.trailingAnchor constant:2],
            [cancelBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [cancelBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [cancelBtn.widthAnchor constraintEqualToConstant:20],
            [cancelBtn.heightAnchor constraintEqualToConstant:20],
        ]];
        [_progressStack addArrangedSubview:row];
    }

    if (tasks.count > shown) {
        UILabel *more = [[UILabel alloc] init];
        more.font = [UIFont systemFontOfSize:9 weight:UIFontWeightRegular];
        more.textColor = theme.secondaryTextColor;
        more.text = [NSString stringWithFormat:@"+%lu more", (unsigned long)(tasks.count - shown)];
        [_progressStack addArrangedSubview:more];
    }
}

- (void)cancelTaskTapped:(UIButton *)sender {
    DownloadTask *task = objc_getAssociatedObject(sender, @selector(cancelTapped:));
    if (task) [DownloadManager.shared cancelTask:task];
}

- (NSString *)formatSpeed:(double)bytesPerSecond {
    if (bytesPerSecond >= 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB/s", bytesPerSecond / (1024.0 * 1024.0)];
    } else if (bytesPerSecond >= 1024) {
        return [NSString stringWithFormat:@"%.0f KB/s", bytesPerSecond / 1024.0];
    } else if (bytesPerSecond > 0) {
        return [NSString stringWithFormat:@"%.0f B/s", bytesPerSecond];
    }
    return nil;
}

- (void)downloadsInfoTapped {
    if (self.delegate) [self.delegate topBarDidTapDownloads];
}

- (void)fileTapped {
    if (self.delegate) [self.delegate topBarDidTapFileManager];
}

- (void)settingsTapped {
    if (self.delegate) [self.delegate topBarDidTapSettings];
}

- (void)downloadHubTapped {
    if (self.delegate && [self.delegate respondsToSelector:@selector(topBarDidTapDownloadHub)]) {
        [self.delegate topBarDidTapDownloadHub];
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    // When the per-bar frost is enabled, fade the base color so the realtime
    // gaussian material shows through instead of an opaque slab.
    if ([UIView lg_isEnabled]) {
        // Let the navigation-layer glass sample the launcher content instead
        // of painting a custom bar background over it.
        self.backgroundColor = [UIColor clearColor];
    } else if ([AmethystBlurView blurEnabledForKey:@"amethyst_topbar_blur"]) {
        self.backgroundColor = [theme.topBarBackgroundColor colorWithAlphaComponent:0.25 * theme.uiOpacity];
    } else {
        self.backgroundColor = theme.topBarBackgroundColor;
    }
    _jitStatusLabel.textColor = theme.secondaryTextColor;
    _timeLabel.textColor = theme.primaryTextColor;
    _fileManagerButton.tintColor = theme.accentColor;
    _settingsButton.tintColor = theme.accentColor;
    _downloadHubButton.tintColor = theme.accentColor;
}

- (void)updateJITStatus:(BOOL)enabled {
    _jitStatusLabel.text = enabled ? @"JIT: ✓" : @"JIT: ✗";
    _jitStatusLabel.textColor = enabled ? ThemeManager.shared.successColor : ThemeManager.shared.warningColor;
}

- (void)updateTime {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    _timeLabel.text = [formatter stringFromDate:[NSDate date]];
}

- (void)checkJITStatus {
    BOOL enabled = isJITEnabled(false);
    [self updateJITStatus:enabled];
}

- (void)dealloc {
    [_timeTimer invalidate];
    [_jitTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
