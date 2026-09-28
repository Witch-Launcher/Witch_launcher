#import "LauncherUpdateViewController.h"
#import "WitchUpdateService.h"
#import "LauncherPreferences.h"
#import "ThemeManager.h"

@interface LauncherUpdateViewController ()
@property (nonatomic) UISegmentedControl *channelSeg;
@property (nonatomic) UISegmentedControl *variantSeg;
@property (nonatomic) UILabel *statusLabel;
@property (nonatomic) UITextView *notesView;
@property (nonatomic) UIButton *checkButton;
@property (nonatomic) UIButton *downloadButton;
@property (nonatomic) UIProgressView *progressView;
@property (nonatomic) WitchReleaseInfo *lastInfo;
@end

@implementation LauncherUpdateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Cập nhật Launcher";
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;

    WitchUpdateChannel ch = WitchUpdateService.shared.selectedChannel;
    _channelSeg = [[UISegmentedControl alloc] initWithItems:@[@"Tự động", @"Beta", @"Ổn định"]];
    _channelSeg.selectedSegmentIndex = (NSInteger)ch;
    [_channelSeg addTarget:self action:@selector(channelChanged) forControlEvents:UIControlEventValueChanged];
    _channelSeg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_channelSeg];

    UILabel *hint = [[UILabel alloc] init];
    hint.text = @"Beta → pre-release • Ổn định → release • Tự động theo bản đang chạy";
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = ThemeManager.shared.secondaryTextColor;
    hint.numberOfLines = 0;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hint];

    _variantSeg = [[UISegmentedControl alloc] initWithItems:@[@"Bản Full", @"Bản Simple"]];
    _variantSeg.selectedSegmentIndex = 0;
    _variantSeg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_variantSeg];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.numberOfLines = 0;
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.textColor = ThemeManager.shared.primaryTextColor;
    _statusLabel.text = [NSString stringWithFormat:@"Phiên bản hiện tại: v%@ (%@)\nKênh: %@",
        WitchUpdateService.shared.currentVersion,
        WitchUpdateService.shared.isBetaBuild ? @"beta" : @"release",
        [WitchUpdateService.shared channelDisplayName:ch]];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_statusLabel];

    _checkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_checkButton setTitle:@"Kiểm tra cập nhật" forState:UIControlStateNormal];
    _checkButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_checkButton addTarget:self action:@selector(checkNow) forControlEvents:UIControlEventTouchUpInside];
    _checkButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_checkButton];

    _downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_downloadButton setTitle:@"Tải và cài đặt" forState:UIControlStateNormal];
    _downloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    _downloadButton.enabled = NO;
    [_downloadButton addTarget:self action:@selector(downloadAndInstall) forControlEvents:UIControlEventTouchUpInside];
    _downloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_downloadButton];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.hidden = YES;
    [self.view addSubview:_progressView];

    _notesView = [[UITextView alloc] init];
    _notesView.editable = NO;
    _notesView.font = [UIFont systemFontOfSize:13];
    _notesView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _notesView.textColor = ThemeManager.shared.primaryTextColor;
    _notesView.layer.cornerRadius = 8;
    _notesView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_notesView];

    [NSLayoutConstraint activateConstraints:@[
        [_channelSeg.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [_channelSeg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_channelSeg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [hint.topAnchor constraintEqualToAnchor:_channelSeg.bottomAnchor constant:6],
        [hint.leadingAnchor constraintEqualToAnchor:_channelSeg.leadingAnchor],
        [hint.trailingAnchor constraintEqualToAnchor:_channelSeg.trailingAnchor],
        [_variantSeg.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:12],
        [_variantSeg.leadingAnchor constraintEqualToAnchor:_channelSeg.leadingAnchor],
        [_variantSeg.trailingAnchor constraintEqualToAnchor:_channelSeg.trailingAnchor],
        [_statusLabel.topAnchor constraintEqualToAnchor:_variantSeg.bottomAnchor constant:12],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_channelSeg.leadingAnchor],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_channelSeg.trailingAnchor],
        [_checkButton.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:12],
        [_checkButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_downloadButton.topAnchor constraintEqualToAnchor:_checkButton.bottomAnchor constant:8],
        [_downloadButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_progressView.topAnchor constraintEqualToAnchor:_downloadButton.bottomAnchor constant:8],
        [_progressView.leadingAnchor constraintEqualToAnchor:_channelSeg.leadingAnchor],
        [_progressView.trailingAnchor constraintEqualToAnchor:_channelSeg.trailingAnchor],
        [_notesView.topAnchor constraintEqualToAnchor:_progressView.bottomAnchor constant:8],
        [_notesView.leadingAnchor constraintEqualToAnchor:_channelSeg.leadingAnchor],
        [_notesView.trailingAnchor constraintEqualToAnchor:_channelSeg.trailingAnchor],
        [_notesView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)channelChanged {
    WitchUpdateChannel ch = (WitchUpdateChannel)_channelSeg.selectedSegmentIndex;
    [WitchUpdateService.shared setSelectedChannel:ch];
    _lastInfo = nil;
    _downloadButton.enabled = NO;
    _statusLabel.text = [NSString stringWithFormat:@"Phiên bản hiện tại: v%@\nKênh: %@ (%@) — hãy bấm Kiểm tra cập nhật",
        WitchUpdateService.shared.currentVersion,
        [WitchUpdateService.shared channelDisplayName:ch],
        WitchUpdateService.shared.effectiveTag];
}

- (void)checkNow {
    _checkButton.enabled = NO;
    _statusLabel.text = @"Đang kiểm tra...";
    [WitchUpdateService.shared checkForUpdateForce:YES completion:^(WitchReleaseInfo *info, BOOL hasUpdate, NSError *error) {
        self->_checkButton.enabled = YES;
        if (error) {
            self->_statusLabel.text = [NSString stringWithFormat:@"Lỗi: %@", error.localizedDescription];
            return;
        }
        self->_lastInfo = info;
        WitchAppVariant v = self->_variantSeg.selectedSegmentIndex == 1 ? WitchAppVariantSlimmed : WitchAppVariantFull;
        WitchReleaseAsset *a = [info assetForVariant:v isTrollStore:WitchUpdateService.shared.isTrollStoreInstall];
        if (!a) a = info.assets.firstObject;
        NSString *assetLine = a ? [NSString stringWithFormat:@"\nFile sẽ tải: %@ (%.1f MB)", a.name, (double)a.size/1048576.0] : @"\n(Không thấy file ipa/tipa trong release)";
        self->_statusLabel.text = [NSString stringWithFormat:@"Kênh %@ (%@)\n%@%@", [WitchUpdateService.shared channelDisplayName:WitchUpdateService.shared.selectedChannel], info.tagName, hasUpdate ? @"Có bản mới!" : @"Đã ở bản mới nhất (theo updated_at).", assetLine];
        self->_notesView.text = info.body.length ? info.body : @"(Không có release notes)";
        self->_downloadButton.enabled = (a != nil);
    }];
}

- (void)downloadAndInstall {
    WitchAppVariant v = _variantSeg.selectedSegmentIndex == 1 ? WitchAppVariantSlimmed : WitchAppVariantFull;
    WitchReleaseAsset *a = [_lastInfo assetForVariant:v isTrollStore:WitchUpdateService.shared.isTrollStoreInstall];
    if (!a) {
        _statusLabel.text = @"Chưa có thông tin release — bấm Kiểm tra cập nhật trước.";
        return;
    }
    _downloadButton.enabled = NO;
    _progressView.hidden = NO;
    _progressView.progress = 0.1f;
    _statusLabel.text = [NSString stringWithFormat:@"Đang tải %@...", a.name];
    [WitchUpdateService.shared downloadAsset:a progress:^(float p) {
        dispatch_async(dispatch_get_main_queue(), ^{ self->_progressView.progress = p; });
    } completion:^(NSURL *fileURL, NSError *error) {
        self->_progressView.hidden = YES;
        self->_downloadButton.enabled = YES;
        if (error || !fileURL) {
            self->_statusLabel.text = [NSString stringWithFormat:@"Tải thất bại: %@", error.localizedDescription];
            return;
        }
        self->_statusLabel.text = [NSString stringWithFormat:@"Đã tải xong. Đang mở cài đặt...\nTrollStore sẽ tự nhận file, Sideload dùng Share Sheet."];
        [WitchUpdateService.shared installFileAtURL:fileURL fromViewController:self];
    }];
}

@end
