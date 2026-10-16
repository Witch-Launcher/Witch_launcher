#import "RightPanelViewController.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "VersionDirectoryManager.h"
#import "MinecraftResourceUtils.h"
#import "PLProfiles.h"
#import "utils.h"
#import "AmethystBlurView.h"
#import "DownloadManager.h"
#import "ProfileAvatarManager.h"
#import <objc/runtime.h>

@interface RightPanelViewController ()
@property (nonatomic) BOOL launchIsCancel;
@property (nonatomic) UIButton *accountButton;
@property (nonatomic) UILabel *accountNameLabel;
@property (nonatomic) UIImageView *skinPreviewView;
@property (nonatomic) UIButton *launchButton;
@property (nonatomic) UILabel *versionsLabel;
@property (nonatomic) UIStackView *versionsStack;
@property (nonatomic) UIScrollView *versionsScroll;
@property (nonatomic) UIButton *addVersionButton;
@property (nonatomic) NSArray *installedVersions;
@end

@implementation RightPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [self refreshVersions];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshVersions) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshVersions) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(versionDidChange:) name:@"VersionDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:AmethystBlurIntensityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTasksDidChange) name:DownloadTasksDidChangeNotification object:nil];
    [self updateColors];
    [self downloadTasksDidChange];
}

#pragma mark - Launch <-> Cancel morph

- (void)downloadTasksDidChange {
    BOOL busy = [DownloadManager.shared activeTasks].count > 0;
    ThemeManager *theme = ThemeManager.shared;
    if (busy && !_launchIsCancel) {
        _launchIsCancel = YES;
        [_launchButton setTitle:@"✕" forState:UIControlStateNormal];
        _launchButton.backgroundColor = theme.errorColor;
        _launchButton.accessibilityLabel = @"Cancel downloads";
    } else if (!busy && _launchIsCancel) {
        _launchIsCancel = NO;
        [_launchButton setTitle:@"▶" forState:UIControlStateNormal];
        _launchButton.backgroundColor = theme.accentColor;
        _launchButton.accessibilityLabel = nil;
    }
}

- (BOOL)launchIsCancel { return _launchIsCancel; }

- (void)setup {
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:contentView];

    _skinPreviewView = [[UIImageView alloc] init];
    _skinPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    _skinPreviewView.contentMode = UIViewContentModeScaleAspectFit;
    _skinPreviewView.layer.cornerRadius = 8;
    _skinPreviewView.clipsToBounds = YES;
    _skinPreviewView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    _skinPreviewView.image = [UIImage systemImageNamed:@"person.circle"];
    _skinPreviewView.tintColor = [UIColor lightGrayColor];
    [contentView addSubview:_skinPreviewView];

    _accountNameLabel = [[UILabel alloc] init];
    _accountNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _accountNameLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    _accountNameLabel.textAlignment = NSTextAlignmentCenter;
    _accountNameLabel.text = localize(@"account.no_account", nil);
    _accountNameLabel.numberOfLines = 2;
    [contentView addSubview:_accountNameLabel];

    _accountButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _accountButton.translatesAutoresizingMaskIntoConstraints = NO;
    _accountButton.backgroundColor = [UIColor clearColor];
    [_accountButton addTarget:self action:@selector(didTapAccount) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:_accountButton];

    UIView *separator1 = [[UIView alloc] init];
    separator1.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:separator1];

    _versionsLabel = [[UILabel alloc] init];
    _versionsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _versionsLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _versionsLabel.text = localize(@"versions.header", nil);
    [contentView addSubview:_versionsLabel];

    _versionsScroll = [[UIScrollView alloc] init];
    _versionsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _versionsScroll.showsVerticalScrollIndicator = NO;
    [contentView addSubview:_versionsScroll];

    _versionsStack = [[UIStackView alloc] init];
    _versionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _versionsStack.axis = UILayoutConstraintAxisVertical;
    _versionsStack.spacing = 2;
    [_versionsScroll addSubview:_versionsStack];

    _addVersionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addVersionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addVersionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [_addVersionButton setTitle:localize(@"version.add", nil) forState:UIControlStateNormal];
    _addVersionButton.layer.cornerRadius = 8;
    _addVersionButton.clipsToBounds = YES;
    [_addVersionButton addTarget:self action:@selector(didTapAddVersion) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:_addVersionButton];

    UIView *separator2 = [[UIView alloc] init];
    separator2.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:separator2];

    _launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    _launchButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [_launchButton setTitle:@"▶" forState:UIControlStateNormal];
    _launchButton.layer.cornerRadius = 20;
    _launchButton.clipsToBounds = YES;
    [_launchButton addTarget:self action:@selector(didTapLaunch) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:_launchButton];

    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-8],

        [_skinPreviewView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:4],
        [_skinPreviewView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [_skinPreviewView.widthAnchor constraintEqualToConstant:40],
        [_skinPreviewView.heightAnchor constraintEqualToConstant:40],

        [_accountNameLabel.topAnchor constraintEqualToAnchor:_skinPreviewView.bottomAnchor constant:2],
        [_accountNameLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_accountNameLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],

        [_accountButton.topAnchor constraintEqualToAnchor:_skinPreviewView.topAnchor],
        [_accountButton.leadingAnchor constraintEqualToAnchor:_skinPreviewView.leadingAnchor],
        [_accountButton.trailingAnchor constraintEqualToAnchor:_accountNameLabel.trailingAnchor],
        [_accountButton.bottomAnchor constraintEqualToAnchor:_accountNameLabel.bottomAnchor],

        [separator1.topAnchor constraintEqualToAnchor:_accountNameLabel.bottomAnchor constant:8],
        [separator1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:4],
        [separator1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-4],
        [separator1.heightAnchor constraintEqualToConstant:1],

        [_versionsLabel.topAnchor constraintEqualToAnchor:separator1.bottomAnchor constant:6],
        [_versionsLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:4],
        [_versionsLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],

        [_versionsScroll.topAnchor constraintEqualToAnchor:_versionsLabel.bottomAnchor constant:4],
        [_versionsScroll.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_versionsScroll.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_versionsScroll.heightAnchor constraintEqualToConstant:120],

        [_versionsStack.topAnchor constraintEqualToAnchor:_versionsScroll.topAnchor],
        [_versionsStack.leadingAnchor constraintEqualToAnchor:_versionsScroll.leadingAnchor],
        [_versionsStack.trailingAnchor constraintEqualToAnchor:_versionsScroll.trailingAnchor],
        [_versionsStack.bottomAnchor constraintEqualToAnchor:_versionsScroll.bottomAnchor],
        [_versionsStack.widthAnchor constraintEqualToAnchor:_versionsScroll.widthAnchor],

        [_addVersionButton.topAnchor constraintEqualToAnchor:_versionsScroll.bottomAnchor constant:4],
        [_addVersionButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:4],
        [_addVersionButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-4],
        [_addVersionButton.heightAnchor constraintEqualToConstant:28],

        [separator2.topAnchor constraintEqualToAnchor:_addVersionButton.bottomAnchor constant:8],
        [separator2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:4],
        [separator2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-4],
        [separator2.heightAnchor constraintEqualToConstant:1],

        [_launchButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:4],
        [_launchButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-4],
        [_launchButton.topAnchor constraintEqualToAnchor:separator2.bottomAnchor constant:8],
        [_launchButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-4],
        [_launchButton.heightAnchor constraintEqualToConstant:44],
    ]];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    if ([AmethystBlurView blurEnabledForKey:@"amethyst_rightpanel_blur"]) {
        self.view.backgroundColor = [theme.rightPanelBackgroundColor colorWithAlphaComponent:0.25 * theme.uiOpacity];
    } else {
        self.view.backgroundColor = theme.rightPanelBackgroundColor;
    }
    _accountNameLabel.textColor = theme.primaryTextColor;
    _versionsLabel.textColor = theme.secondaryTextColor;
    _addVersionButton.tintColor = theme.accentColor;
    _addVersionButton.backgroundColor = [theme.accentColor colorWithAlphaComponent:0.12];
    _launchButton.backgroundColor = theme.accentColor;
    [_launchButton setTitleColor:theme.buttonTextColor forState:UIControlStateNormal];
}

- (void)updateAccountWithName:(NSString *)name skin:(UIImage *)skin {
    _accountNameLabel.text = name ?: localize(@"account.no_account", nil);
    if (skin) {
        _skinPreviewView.image = skin;
    }
}

- (void)setLaunchEnabled:(BOOL)enabled {
    _launchButton.enabled = enabled;
    _launchButton.alpha = enabled ? 1.0 : 0.5;
}

- (void)versionDidChange:(NSNotification *)note {
    NSString *version = note.userInfo[@"version"];
    [self refreshVersions];
}

- (void)refreshVersions {
    NSString *versionsDir = VersionDirectoryManager.shared.versionsRootPath;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:versionsDir error:nil];
    NSMutableArray *versions = [NSMutableArray array];
    for (NSString *item in contents) {
        NSString *fullPath = [versionsDir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [versions addObject:item];
        }
    }
    _installedVersions = [versions sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self rebuildVersionList];
    });
}

- (void)rebuildVersionList {
    [self rebuildVersionListWithCurrentVersion:VersionDirectoryManager.shared.currentVersion];
}

- (void)rebuildVersionListWithCurrentVersion:(NSString *)currentVersion {
    for (UIView *v in _versionsStack.arrangedSubviews) {
        [_versionsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    if (_installedVersions.count == 0) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = localize(@"versions.empty", nil);
        empty.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
        empty.textColor = ThemeManager.shared.secondaryTextColor;
        empty.textAlignment = NSTextAlignmentCenter;
        [_versionsStack addArrangedSubview:empty];
        return;
    }

    for (NSString *ver in _installedVersions) {
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.layer.cornerRadius = 6;
        row.clipsToBounds = YES;
        objc_setAssociatedObject(row, @selector(versionTapped:), ver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        BOOL isCurrent = [ver isEqualToString:currentVersion];
        if (isCurrent) {
            row.backgroundColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.15];
            row.layer.borderWidth = 1;
            row.layer.borderColor = ThemeManager.shared.accentColor.CGColor;
        }

        VersionProfile *profile = [VersionProfile profileWithVersionId:ver];
        NSString *displayName = nil;
        NSString *avatarKey = nil;
        for (NSString *key in PLProfiles.current.profiles) {
            NSDictionary *p = PLProfiles.current.profiles[key];
            if ([p[@"lastVersionId"] isEqualToString:ver]) {
                if ([p[@"name"] isKindOfClass:[NSString class]]) displayName = p[@"name"];
                if ([p[@"avatar"] isKindOfClass:[NSString class]]) avatarKey = p[@"avatar"];
                break;
            }
        }
        if (!displayName) {
            NSString *mcVersion = profile.mcVersion ?: ver;
            if (![profile.modLoader isEqualToString:@"Vanilla"]) {
                displayName = [NSString stringWithFormat:@"%@-%@", mcVersion, profile.modLoader];
            } else {
                displayName = mcVersion;
            }
        }
        BOOL isLoader = ![profile.modLoader isEqualToString:@"Vanilla"];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = isCurrent ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;
        // Profile avatar wins (user-changeable); loader icon is the fallback.
        UIImage *avatarImg = avatarKey ? [ProfileAvatarManager.shared avatarImageForKey:avatarKey] : nil;
        iconView.image = avatarImg ?: [UIImage systemImageNamed:profile.iconName];
        [row addSubview:iconView];

        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = isCurrent ? [NSString stringWithFormat:@"► %@", displayName] : displayName;
        label.font = [UIFont systemFontOfSize:11 weight:isCurrent ? UIFontWeightBold : UIFontWeightMedium];
        label.textColor = isCurrent ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;
        label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        label.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(versionTapped:)];
        [label addGestureRecognizer:tap];
        [row addSubview:label];

        UILabel *loaderTag = nil;
        if (isLoader) {
            loaderTag = [[UILabel alloc] init];
            loaderTag.translatesAutoresizingMaskIntoConstraints = NO;
            loaderTag.text = [NSString stringWithFormat:@" %@ ", profile.modLoader];
            loaderTag.font = [UIFont systemFontOfSize:8 weight:UIFontWeightBold];
            loaderTag.textColor = ThemeManager.shared.accentColor;
            loaderTag.backgroundColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.12];
            loaderTag.layer.cornerRadius = 4;
            loaderTag.clipsToBounds = YES;
            loaderTag.textAlignment = NSTextAlignmentCenter;
            [loaderTag setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [loaderTag setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [row addSubview:loaderTag];
        }

        UIButton *settingsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        settingsBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [settingsBtn setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
        settingsBtn.tintColor = ThemeManager.shared.secondaryTextColor;
        settingsBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [settingsBtn addTarget:self action:@selector(settingsTapped:) forControlEvents:UIControlEventTouchUpInside];
        [settingsBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [row addSubview:settingsBtn];

        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        delBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [delBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        delBtn.tintColor = ThemeManager.shared.errorColor;
        delBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [delBtn addTarget:self action:@selector(deleteTapped:) forControlEvents:UIControlEventTouchUpInside];
        [delBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [row addSubview:delBtn];

        // Layout: icon | label (flex, truncates middle) | [tag] | gear | del.
        // Nothing overlaps the version text anymore.
        NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
            [iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:6],
            [iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:16],
            [iconView.heightAnchor constraintEqualToConstant:16],

            [label.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:6],
            [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

            [settingsBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [settingsBtn.widthAnchor constraintEqualToConstant:24],
            [settingsBtn.heightAnchor constraintEqualToConstant:24],

            [delBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-4],
            [delBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [delBtn.widthAnchor constraintEqualToConstant:24],
            [delBtn.heightAnchor constraintEqualToConstant:24],

            [row.heightAnchor constraintEqualToConstant:30],
        ]];
        if (loaderTag) {
            [constraints addObjectsFromArray:@[
                [loaderTag.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:4],
                [loaderTag.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [loaderTag.trailingAnchor constraintEqualToAnchor:settingsBtn.leadingAnchor constant:-4],
                [settingsBtn.trailingAnchor constraintEqualToAnchor:delBtn.leadingAnchor constant:-2],
            ]];
        } else {
            [constraints addObjectsFromArray:@[
                [label.trailingAnchor constraintEqualToAnchor:settingsBtn.leadingAnchor constant:-4],
                [settingsBtn.trailingAnchor constraintEqualToAnchor:delBtn.leadingAnchor constant:-2],
            ]];
        }
        [NSLayoutConstraint activateConstraints:constraints];

        [_versionsStack addArrangedSubview:row];
    }
}

#pragma mark - Actions

- (void)versionTapped:(UITapGestureRecognizer *)tap {
    [HapticManager.shared play:HapticTypeLight];
    UIView *row = tap.view.superview;
    NSString *versionId = objc_getAssociatedObject(row, @selector(versionTapped:));
    if (!versionId) {
        UILabel *label = (UILabel *)tap.view;
        versionId = label.text;
    }
    if (self.delegate && versionId) [self.delegate rightPanelDidSelectVersion:versionId];
}

- (void)deleteTapped:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    UIView *row = sender.superview;
    NSString *versionId = objc_getAssociatedObject(row, @selector(versionTapped:));
    if (self.delegate && versionId) [self.delegate rightPanelDidRemoveVersion:versionId];
}

- (void)settingsTapped:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    UIView *row = sender.superview;
    NSString *versionId = objc_getAssociatedObject(row, @selector(versionTapped:));
    if (self.delegate && versionId) [self.delegate rightPanelDidEditVersion:versionId];
}

- (void)didTapAccount {
    [HapticManager.shared play:HapticTypeLight];
    if (self.delegate) [self.delegate rightPanelDidTapAccount];
}

- (void)didTapLaunch {
    if (_launchIsCancel) {
        [HapticManager.shared play:HapticTypeHeavy];
        [DownloadManager.shared cancelAllTasks];
        return;
    }
    [HapticManager.shared play:HapticTypeMedium];
    if (self.delegate) [self.delegate rightPanelDidTapLaunch];
}

- (void)didTapDownloadHub {
    [HapticManager.shared play:HapticTypeLight];
    if (self.delegate) [self.delegate rightPanelDidTapDownloadHub];
}

- (void)didTapAddVersion {
    [HapticManager.shared play:HapticTypeLight];
    if (self.delegate) [self.delegate rightPanelDidAddVersion];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
