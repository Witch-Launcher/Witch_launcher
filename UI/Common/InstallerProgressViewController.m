#import "InstallerProgressViewController.h"
#import "JavaGUIViewController.h"
#import "JavaLauncher.h"
#import "ThemeManager.h"
#import "authenticator/BaseAuthenticator.h"
#import "ios_uikit_bridge.h"
#include "utils.h"

@interface InstallerProgressViewController ()
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *statusLabel;
@property (nonatomic) UILabel *percentLabel;
@property (nonatomic) UIProgressView *progressView;
@property (nonatomic) UITextView *logTextView;
@property (nonatomic) UIButton *cancelBtn;
@property (nonatomic) NSTimer *logTimer;
@property (nonatomic, copy) NSString *accumulatedLog;
@property (nonatomic) unsigned long long logOffset;
@property (nonatomic) float progress;
@property (nonatomic) float stageTarget;
@property (nonatomic) BOOL isFinished;
@end

@implementation InstallerProgressViewController

+ (void)presentInstallerFrom:(UIViewController *)hostVC
                     jarPath:(NSString *)jarPath
                       title:(NSString *)title
                     jvmArgs:(NSArray<NSString *> *)args
                  completion:(void (^)(BOOL success, BOOL cancelled, int exitCode))completion {
    InstallerProgressViewController *vc = [[InstallerProgressViewController alloc] init];
    vc.jarPath = jarPath;
    vc.jvmArgs = args;
    vc.installTitle = title;
    vc.completion = completion;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [hostVC presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.text = self.installTitle ?: localize(@"Installing...", nil);
    [self.view addSubview:self.titleLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 1;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.statusLabel.text = localize(@"Starting JVM...", nil);
    [self.view addSubview:self.statusLabel];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progressTintColor = ThemeManager.shared.accentColor;
    self.progressView.trackTintColor = [UIColor colorWithWhite:0.3 alpha:1];
    [self.view addSubview:self.progressView];

    self.percentLabel = [[UILabel alloc] init];
    self.percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.percentLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    self.percentLabel.textColor = ThemeManager.shared.accentColor;
    self.percentLabel.textAlignment = NSTextAlignmentCenter;
    self.percentLabel.text = localize(@"0%", nil);
    [self.view addSubview:self.percentLabel];

    self.logTextView = [[UITextView alloc] init];
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logTextView.editable = NO;
    self.logTextView.selectable = YES;
    self.logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    self.logTextView.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    self.logTextView.font = [UIFont fontWithName:@"Menlo-Regular" size:10];
    self.logTextView.layer.cornerRadius = 10;
    self.logTextView.clipsToBounds = YES;
    self.logTextView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.logTextView.text = @"";
    [self.view addSubview:self.logTextView];

    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelBtn setTitle:localize(@"Cancel", nil) forState:UIControlStateNormal];
    [self.cancelBtn setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    self.cancelBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.cancelBtn addTarget:self action:@selector(cancelPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancelBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.progressView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:14],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.progressView.heightAnchor constraintEqualToConstant:4],

        [self.percentLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:6],
        [self.percentLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [self.logTextView.topAnchor constraintEqualToAnchor:self.percentLabel.bottomAnchor constant:14],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:self.cancelBtn.topAnchor constant:-14],

        [self.cancelBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.cancelBtn.widthAnchor constraintEqualToConstant:160],
        [self.cancelBtn.heightAnchor constraintEqualToConstant:40],
        [self.cancelBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];

    [self startInstall];
}

- (NSString *)cancelMarkerPath {
    return [NSString stringWithFormat:@"%s/installers/cancel-install", getenv("POJAV_HOME") ?: ""];
}

- (void)startInstall {
    // The installers only need the embedded JVM + stdout; skip the GLFW
    // surface machinery used by the regular JavaGUIViewController jar runner.
    setenv("POJAV_SKIP_JNI_GLFW", "1", 1);

    NSString *latestlogPath = [NSString stringWithFormat:@"%s/latestlog.txt", getenv("POJAV_HOME") ?: ""];
    self.logOffset = [[[NSFileManager defaultManager] attributesOfItemAtPath:latestlogPath error:nil][NSFileSize] unsignedLongLongValue];
    self.progress = 0.02;
    self.stageTarget = 0.12;
    self.accumulatedLog = @"";

    self.logTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 target:self selector:@selector(tickLog) userInfo:nil repeats:YES];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int version = [JavaGUIViewController requiredJavaVersionForJar:self.jarPath];
        if (version <= 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = localize(@"Failed to read installer jar", nil);
                [self finishWithExitCode:-1 fatal:YES];
            });
            return;
        }
        int code = launchJVMWithArgs(BaseAuthenticator.current.authData[@"username"] ?: @"Player",
            self.jarPath, windowWidth, windowHeight, version, self.jvmArgs);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishWithExitCode:code fatal:NO];
        });
    });
}

- (void)tickLog {
    // Slow creep toward the current stage target while the JVM is working.
    if (self.progress < self.stageTarget) {
        self.progress = MIN(self.progress + 0.003, self.stageTarget);
        self.progressView.progress = self.progress;
        self.percentLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(self.progress * 100)];
    }

    NSString *path = [NSString stringWithFormat:@"%s/latestlog.txt", getenv("POJAV_HOME") ?: ""];
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) {
        return;
    }
    unsigned long long total = [fh seekToEndOfFile];
    if (total < self.logOffset) {
        self.logOffset = 0; // log rotated
    }
    if (total > self.logOffset) {
        [fh seekToFileOffset:self.logOffset];
        NSData *data = [fh readDataToEndOfFile];
        self.logOffset = total;
        NSString *chunk = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (chunk.length > 0) {
            self.accumulatedLog = [self.accumulatedLog stringByAppendingString:chunk];
            if (self.accumulatedLog.length > 50000) {
                self.accumulatedLog = [self.accumulatedLog substringFromIndex:self.accumulatedLog.length - 50000];
            }
            self.logTextView.text = self.accumulatedLog;
            [self.logTextView scrollRangeToVisible:NSMakeRange(self.accumulatedLog.length - 1, 1)];
            [self parseProgress:chunk];
        }
    }
    [fh closeFile];
}

- (void)parseProgress:(NSString *)chunk {
    NSRange range = NSMakeRange(0, chunk.length);
    if ([chunk rangeOfString:@"Downloading" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.35];
    }
    if ([chunk rangeOfString:@"Extracting" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.55];
    }
    if ([chunk rangeOfString:@"Processing" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.70];
    }
    if ([chunk rangeOfString:@"Installing" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.72];
    }
    if ([chunk rangeOfString:@"Running" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.78];
    }
    if ([chunk rangeOfString:@"Success" options:NSCaseInsensitiveSearch range:range].location != NSNotFound ||
        [chunk rangeOfString:@"Completed" options:NSCaseInsensitiveSearch range:range].location != NSNotFound ||
        [chunk rangeOfString:@"Done" options:NSCaseInsensitiveSearch range:range].location != NSNotFound) {
        [self setStageAtLeast:0.95];
    }
}

- (void)setStageAtLeast:(float)value {
    if (self.stageTarget < value) {
        self.stageTarget = value;
    }
    if (self.progress < value) {
        self.progress = value;
    }
}

- (void)cancelPressed {
    if (self.isFinished) {
        return;
    }
    self.cancelBtn.enabled = NO;
    self.statusLabel.text = localize(@"installer.status_cancelling", nil);
    NSString *marker = [self cancelMarkerPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[marker stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] createFileAtPath:marker contents:nil attributes:nil];
}

- (void)finishWithExitCode:(int)code fatal:(BOOL)fatal {
    if (self.isFinished) {
        return;
    }
    self.isFinished = YES;
    [self.logTimer invalidate];
    self.logTimer = nil;

    BOOL cancelled = [[NSFileManager defaultManager] fileExistsAtPath:[self cancelMarkerPath]];
    if (cancelled) {
        [[NSFileManager defaultManager] removeItemAtPath:[self cancelMarkerPath] error:nil];
    }

    self.progress = 1.0;
    self.progressView.progress = 1.0;
    if (fatal) {
        self.percentLabel.text = @"-";
        self.statusLabel.text = localize(@"installer.status_failed_start", nil);
    } else if (cancelled) {
        self.percentLabel.text = @"-";
        self.statusLabel.text = localize(@"installer.status_cancelled", nil);
    } else if (code != 0) {
        self.percentLabel.text = @"-";
        self.statusLabel.text = [NSString stringWithFormat:@"Install failed (exit code %d)", code];
    } else {
        self.percentLabel.text = @"100%";
        self.statusLabel.text = localize(@"installer.status_success", nil);
    }
    self.cancelBtn.hidden = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        void (^completion)(BOOL, BOOL, int) = self.completion;
        [self dismissViewControllerAnimated:YES completion:^{
            if (completion) {
                completion(!fatal && code == 0, cancelled, code);
            }
        }];
    });
}

@end
