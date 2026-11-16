#import "PluginsViewController.h"
#import "PluginDetailViewController.h"
#import "PluginInstallFlow.h"
#import "PluginRiskBadgeView.h"
#import "WitchPluginManager.h"
#import "WitchPlugin.h"
#import "WitchPluginRisk.h"
#import "WitchPluginTheme.h"
#import "WitchPluginUpdateService.h"
#import "WitchPluginVersion.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "DownloadProgressOverlay.h"
#import "AppSheet.h"
#import "HapticManager.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSInteger, PluginsSection) {
    PluginsSectionSafeMode = 0,
    PluginsSectionCatalog = 1,
    PluginsSectionInstalled = 2
};

@interface WitchPluginCell : UITableViewCell
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *catalogEntryID;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) PluginRiskBadgeView *riskBadge;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UIStackView *controlStack;
- (void)applyIcon:(nullable UIImage *)icon title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)applyRiskLevel:(WitchPluginRiskLevel)level;
- (void)applyActionTitle:(nullable NSString *)title color:(nullable UIColor *)color;
@end

@implementation WitchPluginCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = ThemeManager.shared.cardBackgroundColor;

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 8;
        _iconView.tintColor = ThemeManager.shared.accentColor;
        [self.contentView addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subtitleLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _subtitleLabel.numberOfLines = 2;
        [self.contentView addSubview:_subtitleLabel];

        _riskBadge = [PluginRiskBadgeView badgeForLevel:WitchPluginRiskLevelSafe];
        _riskBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _riskBadge.hidden = YES;

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _actionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        _actionButton.titleLabel.minimumScaleFactor = 0.8;
        _actionButton.layer.cornerRadius = 8;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        _actionButton.hidden = YES;

        _enabledSwitch = [[UISwitch alloc] init];
        _enabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _enabledSwitch.hidden = YES;

        // One trailing column holds the risk badge and the row action. Hidden
        // arranged views collapse, so a row never reserves space for a control
        // it does not show.
        _controlStack = [[UIStackView alloc] init];
        _controlStack.translatesAutoresizingMaskIntoConstraints = NO;
        _controlStack.axis = UILayoutConstraintAxisHorizontal;
        _controlStack.alignment = UIStackViewAlignmentCenter;
        _controlStack.spacing = 8;
        [_controlStack addArrangedSubview:_riskBadge];
        [_controlStack addArrangedSubview:_actionButton];
        [_controlStack addArrangedSubview:_enabledSwitch];
        [self.contentView addSubview:_controlStack];

        [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow + 1 forAxis:UILayoutConstraintAxisHorizontal];
        [_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow + 1 forAxis:UILayoutConstraintAxisHorizontal];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_iconView.widthAnchor constraintEqualToConstant:36],
            [_iconView.heightAnchor constraintEqualToConstant:36],

            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_controlStack.leadingAnchor constant:-8],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_controlStack.leadingAnchor constant:-8],
            [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],

            [_controlStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_controlStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_controlStack.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:8],
            [_riskBadge.heightAnchor constraintEqualToConstant:18],
        ]];
    }
    return self;
}

- (void)applyIcon:(UIImage *)icon title:(NSString *)title subtitle:(NSString *)subtitle {
    self.iconView.image = icon ?: [UIImage systemImageNamed:@"puzzlepiece.extension"];
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
}

- (void)applyRiskLevel:(WitchPluginRiskLevel)level {
    [self.riskBadge applyLevel:level];
    self.riskBadge.hidden = NO;
}

- (void)applyActionTitle:(NSString *)title color:(UIColor *)color {
    if (title.length == 0) {
        self.actionButton.hidden = YES;
        return;
    }
    [self.actionButton setTitle:title forState:UIControlStateNormal];
    self.actionButton.backgroundColor = color;
    [self.actionButton setTitleColor:[ThemeManager.shared contrastTextColorForBackground:color] forState:UIControlStateNormal];
    self.actionButton.hidden = NO;
}

@end

@interface PluginsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray<WitchPlugin *> *plugins;
@property (nonatomic) NSArray<WitchPluginCatalogEntry *> *catalogEntries;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *catalogRiskLevels;
@property (nonatomic) DownloadProgressOverlay *verificationOverlay;
@property (nonatomic) BOOL catalogLoading;
@end

@implementation PluginsViewController

- (instancetype)init {
    self = [super init];
    if (self) self.title = localize(@"Plugins", nil);
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    self.catalogRiskLevels = [NSMutableDictionary dictionary];
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(pickPackage)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshCatalogTapped)]
    ];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadContent) name:WitchPluginsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self reloadContent];
    [self refreshCatalog];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContent];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [self.tableView reloadData];
}

- (void)reloadContent {
    self.plugins = WitchPluginManager.shared.plugins;
    self.catalogEntries = WitchPluginUpdateService.shared.entries;
    [self.tableView reloadData];
}

#pragma mark - Catalog

- (void)refreshCatalog {
    [self refreshCatalogForcing:NO];
}

// The catalog lives in a shared service, so the screen does not hit the
// GitHub API on every visit. A manual refresh always goes through.
- (void)refreshCatalogForcing:(BOOL)force {
    if (self.catalogLoading) return;
    WitchPluginUpdateService *service = WitchPluginUpdateService.shared;
    if (!force && service.entries.count > 0 && service.lastRefreshDate) {
        if ([[NSDate date] timeIntervalSinceDate:service.lastRefreshDate] < 600) {
            self.catalogEntries = service.entries;
            [self.tableView reloadData];
            return;
        }
    }
    self.catalogLoading = YES;
    __weak typeof(self) weakSelf = self;
    [service refreshCatalogWithCompletion:^(BOOL ok, NSError *error) {
        PluginsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.catalogLoading = NO;
        strongSelf.catalogEntries = WitchPluginUpdateService.shared.entries;
        [strongSelf.tableView reloadData];
        if (!ok && error) {
            NSLog(@"[Plugins] Catalog refresh failed: %@", error.localizedDescription);
        }
    }];
}

- (void)refreshCatalogTapped {
    [self refreshCatalogForcing:YES];
}

- (nullable WitchPlugin *)installedPluginForCatalogEntry:(WitchPluginCatalogEntry *)entry {
    for (WitchPlugin *plugin in self.plugins) {
        if ([plugin.pluginID isEqualToString:entry.pluginID]) return plugin;
    }
    return nil;
}

#pragma mark - Install from a file

- (void)pickPackage {
    UTType *type = [UTType typeWithIdentifier:@"com.witch.plugin-package"];
    if (!type) type = [UTType typeWithFilenameExtension:@"plgw"];
    if (!type) type = UTTypeData;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.firstObject) [self installFromPackageURL:urls.firstObject];
}

- (void)installFromPackageURL:(NSURL *)url {
    BOOL access = [url startAccessingSecurityScopedResource];
    NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plgw", NSUUID.UUID.UUIDString]];
    NSError *copyError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
    BOOL copied = [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:temp error:&copyError];
    if (access) [url stopAccessingSecurityScopedResource];
    if (!copied) {
        showDialog(localize(@"Install Failed", nil), copyError.localizedDescription ?: @"Cannot read the package");
        return;
    }
    NSURL *localURL = [NSURL fileURLWithPath:temp];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *inspectError = nil;
        NSDictionary *info = [WitchPluginManager.shared inspectPackageAtURL:localURL error:&inspectError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!info) {
                [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
                showDialog(localize(@"Install Failed", nil), inspectError.localizedDescription ?: @"Invalid plugin package");
                return;
            }
            [self verifyPackage:info localURL:localURL];
        });
    });
}

- (void)verifyPackage:(NSDictionary *)info localURL:(NSURL *)localURL {
    [self showVerificationOverlay];
    __weak typeof(self) weakSelf = self;
    [WitchPluginManager.shared verifyPackageInfo:info completion:^(BOOL verified, NSError *verifyError) {
        PluginsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf hideVerificationOverlay];
        if (!verified) {
            [[NSFileManager defaultManager] removeItemAtPath:localURL.path error:nil];
            showDialog(localize(@"Verification Failed", nil), verifyError.localizedDescription ?: localize(@"Registry verification failed.", nil));
            return;
        }
        WitchPluginRiskReport *risk = [info[@"risk"] isKindOfClass:[WitchPluginRiskReport class]] ? info[@"risk"] : nil;
        [strongSelf presentInstallForPackage:localURL info:info risk:risk isUpdate:NO];
    }];
}

- (void)showVerificationOverlay {
    self.verificationOverlay = [DownloadProgressOverlay showInView:self.view title:localize(@"Verifying Plugin", nil)];
    [self.verificationOverlay updateProgress:0.5f message:localize(@"Checking the Witch registry", nil)];
}

- (void)hideVerificationOverlay {
    [self.verificationOverlay dismiss];
    self.verificationOverlay = nil;
}

#pragma mark - Install decision

// A plugin that raises no finding is installed right away. A plugin that
// needs attention or is dangerous is shown with everything it is going to do,
// and the user decides.
- (void)presentInstallForPackage:(NSURL *)packageURL
                            info:(NSDictionary *)info
                            risk:(WitchPluginRiskReport *)risk
                         isUpdate:(BOOL)isUpdate {
    NSDictionary *manifest = info[@"manifest"];
    NSString *pluginID = [manifest[@"id"] isKindOfClass:[NSString class]] ? manifest[@"id"] : @"";
    if (pluginID.length > 0 && risk) {
        self.catalogRiskLevels[pluginID] = @(risk.level);
        [self.tableView reloadData];
    }
    [PluginInstallFlow.shared presentInstallForPackageURL:packageURL
                                                     info:info
                                                     risk:risk
                                                  isUpdate:isUpdate
                                        fromViewController:self];
}

#pragma mark - Catalog actions

- (void)installCatalogEntry:(WitchPluginCatalogEntry *)entry {
    [PluginInstallFlow.shared installCatalogEntry:entry fromViewController:self];
}

#pragma mark - Links

+ (BOOL)handleIncomingURL:(NSURL *)url presenter:(UIViewController *)presenter {
    if (!url) return NO;
    if (url.isFileURL && [url.pathExtension.lowercaseString isEqualToString:@"plgw"]) {
        PluginsViewController *vc = [self presentManagerFrom:presenter];
        [vc installFromPackageURL:url];
        return YES;
    }
    if ([url.scheme.lowercaseString isEqualToString:@"witch"] && [url.host.lowercaseString isEqualToString:@"install-plugin"]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *remote = nil;
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"url"]) remote = item.value;
        }
        NSURL *remoteURL = remote.length > 0 ? [NSURL URLWithString:remote] : nil;
        if (!remoteURL) return NO;
        NSString *scheme = remoteURL.scheme.lowercaseString;
        NSString *host = remoteURL.host.lowercaseString;
        BOOL localHTTP = [scheme isEqualToString:@"http"] && ([host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"::1"]);
        if (![scheme isEqualToString:@"https"] && !localHTTP) return NO;
        PluginsViewController *vc = [self presentManagerFrom:presenter];
        [vc downloadAndInstallFromURL:remoteURL];
        return YES;
    }
    return NO;
}

+ (PluginsViewController *)presentManagerFrom:(UIViewController *)presenter {
    UIViewController *host = presenter ?: currentVC();
    PluginsViewController *vc = [[PluginsViewController alloc] init];
    if (host.navigationController) {
        [host.navigationController pushViewController:vc animated:YES];
    } else if (host) {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [host presentViewController:nav animated:YES completion:nil];
    }
    return vc;
}

- (void)downloadAndInstallFromURL:(NSURL *)url {
    NSURLSessionDownloadTask *task = [NSURLSession.sharedSession downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 200;
        if (error || status >= 400 || !location) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showDialog(localize(@"Install Failed", nil), error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld", (long)status]);
            });
            return;
        }
        unsigned long long downloadedSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:nil][NSFileSize] unsignedLongLongValue];
        if (downloadedSize > 32ULL * 1024 * 1024) {
            [[NSFileManager defaultManager] removeItemAtPath:location.path error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                showDialog(localize(@"Install Failed", nil), localize(@"Plugin package is too large", nil));
            });
            return;
        }
        NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plgw", NSUUID.UUID.UUIDString]];
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:temp] error:&moveError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (moveError) {
                showDialog(localize(@"Install Failed", nil), moveError.localizedDescription);
                return;
            }
            [self installFromPackageURL:[NSURL fileURLWithPath:temp]];
            [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
        });
    }];
    [task resume];
}

- (void)safeModeChanged:(UISwitch *)sender {
    NSError *error = nil;
    if (![WitchPluginManager.shared setSafeMode:sender.isOn error:&error]) {
        sender.on = !sender.isOn;
        showDialog(localize(@"Error", nil), error.localizedDescription);
    }
    [self reloadContent];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == PluginsSectionSafeMode) return 1;
    if (section == PluginsSectionCatalog) return self.catalogEntries.count;
    return self.plugins.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == PluginsSectionSafeMode) return localize(@"Safe Mode", nil);
    if (section == PluginsSectionCatalog) return localize(@"Available Plugins", nil);
    return localize(@"Installed Plugins", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == PluginsSectionSafeMode) {
        return WitchPluginManager.shared.safeMode ? localize(@"All plugins are paused. Turn off safe mode to load them again.", nil) : localize(@"Turn on to skip all plugins at launch. Changes apply after restart.", nil);
    }
    if (section == PluginsSectionCatalog) {
        WitchPluginUpdateService *service = WitchPluginUpdateService.shared;
        if (self.catalogLoading) return localize(@"Loading the plugin catalog...", nil);
        if (service.entries.count == 0) {
            NSString *reason = service.lastErrorMessage.length > 0 ? service.lastErrorMessage : localize(@"No plugin catalog is available.", nil);
            return [NSString stringWithFormat:localize(@"The plugin catalog could not be loaded: %@", nil), reason];
        }
        NSString *source = [NSString stringWithFormat:@"%@ (%@)", service.repository, service.repositoryDescription.length > 0 ? service.repositoryDescription : @"GitHub"];
        return [NSString stringWithFormat:localize(@"Plugins come from %@. Every package is pinned by hash and verified before it is installed.", nil), source];
    }
    if (self.plugins.count == 0) return localize(@"No plugins installed. Tap + to install a .plgw package.", nil);
    return [NSString stringWithFormat:localize(@"Advanced: edit %@ in the app folder to disable a plugin manually.", nil), WitchPluginManager.shared.configurationPath.lastPathComponent ?: @"plugins.json"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == PluginsSectionSafeMode) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SafeModeCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SafeModeCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = localize(@"Safe Mode", nil);
        cell.detailTextLabel.text = WitchPluginManager.shared.safeMode ? localize(@"Plugins are skipped at launch.", nil) : localize(@"Plugins load normally at launch.", nil);
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        if (![toggle isKindOfClass:[UISwitch class]]) {
            toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(safeModeChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        toggle.on = WitchPluginManager.shared.safeMode;
        return cell;
    }

    if (indexPath.section == PluginsSectionCatalog) {
        return [self catalogCellForRow:indexPath.row];
    }
    return [self installedCellForRow:indexPath.row];
}

- (UITableViewCell *)catalogCellForRow:(NSInteger)row {
    WitchPluginCatalogEntry *entry = self.catalogEntries[row];
    WitchPluginCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"CatalogCell"];
    if (!cell) {
        cell = [[WitchPluginCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CatalogCell"];
    }
    cell.pluginID = nil;
    cell.catalogEntryID = entry.pluginID;
    cell.enabledSwitch.hidden = YES;
    cell.riskBadge.hidden = YES;
    [cell applyIcon:nil title:entry.name.length > 0 ? entry.name : entry.pluginID subtitle:[NSString stringWithFormat:@"v%@%@", entry.version, entry.summary.length > 0 ? [NSString stringWithFormat:@"  ·  %@", entry.summary] : @""]];
    NSNumber *riskLevel = self.catalogRiskLevels[entry.pluginID];
    if (riskLevel) {
        [cell applyRiskLevel:(WitchPluginRiskLevel)riskLevel.integerValue];
    }
    [cell.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    WitchPlugin *installed = [self installedPluginForCatalogEntry:entry];
    if (installed) {
        BOOL hasUpdate = [WitchPluginVersion isVersion:entry.version newerThan:installed.version];
        if (hasUpdate) {
            [cell applyActionTitle:localize(@"Update", nil) color:ThemeManager.shared.accentColor];
            [cell.actionButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
                [self installCatalogEntry:entry];
            }] forControlEvents:UIControlEventTouchUpInside];
        } else {
            [cell applyActionTitle:localize(@"Installed", nil) color:ThemeManager.shared.successColor];
        }
    } else {
        [cell applyActionTitle:localize(@"Install", nil) color:ThemeManager.shared.accentColor];
        [cell.actionButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [self installCatalogEntry:entry];
        }] forControlEvents:UIControlEventTouchUpInside];
    }
    return cell;
}

- (UITableViewCell *)installedCellForRow:(NSInteger)row {
    WitchPlugin *plugin = self.plugins[row];
    WitchPluginCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"PluginCell"];
    if (!cell) {
        cell = [[WitchPluginCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PluginCell"];
    }
    cell.pluginID = plugin.pluginID;
    cell.catalogEntryID = nil;
    cell.actionButton.hidden = YES;
    NSString *status = localize(@"Unverified", nil);
    if (plugin.verificationState == WitchPluginVerificationStateVerified) status = localize(@"Verified", nil);
    else if (plugin.verificationState == WitchPluginVerificationStateRevoked) status = localize(@"Revoked", nil);
    else if (plugin.verificationState == WitchPluginVerificationStateInvalid) status = localize(@"Blocked", nil);
    NSMutableString *subtitle = [NSMutableString stringWithFormat:@"v%@  ·  %@  ·  %@", plugin.version, plugin.license, status];
    if (plugin.sandboxed) [subtitle appendFormat:@"  ·  %@", localize(@"Sandboxed", nil)];
    [cell applyIcon:[plugin iconImage] title:plugin.name subtitle:subtitle];
    if (plugin.riskLevel != WitchPluginRiskLevelSafe) {
        [cell applyRiskLevel:plugin.riskLevel];
    } else {
        cell.riskBadge.hidden = YES;
    }
    cell.enabledSwitch.hidden = NO;
    cell.enabledSwitch.on = plugin.enabled;
    cell.enabledSwitch.enabled = plugin.verificationState != WitchPluginVerificationStateRevoked && plugin.verificationState != WitchPluginVerificationStateInvalid;
    [cell.enabledSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [cell.enabledSwitch addAction:[UIAction actionWithHandler:^(UIAction *action) {
        UISwitch *sender = (UISwitch *)action.sender;
        NSError *error = nil;
        if (![WitchPluginManager.shared setPluginID:plugin.pluginID enabled:sender.isOn error:&error]) {
            sender.on = !sender.isOn;
            showDialog(localize(@"Error", nil), error.localizedDescription);
        }
        [self reloadContent];
    }] forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == PluginsSectionSafeMode) return;
    if (indexPath.section == PluginsSectionCatalog) {
        WitchPluginCatalogEntry *entry = self.catalogEntries[indexPath.row];
        WitchPlugin *installed = [self installedPluginForCatalogEntry:entry];
        if (installed) {
            PluginDetailViewController *detail = [[PluginDetailViewController alloc] initWithPlugin:installed];
            [self.navigationController pushViewController:detail animated:YES];
            return;
        }
        [self installCatalogEntry:entry];
        return;
    }
    WitchPlugin *plugin = self.plugins[indexPath.row];
    [HapticManager.shared play:HapticTypeLight];
    PluginDetailViewController *detail = [[PluginDetailViewController alloc] initWithPlugin:plugin];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
