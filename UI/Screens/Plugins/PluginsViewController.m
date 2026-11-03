#import "PluginsViewController.h"
#import "PluginDetailViewController.h"
#import "WitchPluginManager.h"
#import "WitchPlugin.h"
#import "WitchPluginTheme.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "DownloadProgressOverlay.h"
#import "AppSheet.h"
#import "HapticManager.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface WitchPluginCell : UITableViewCell
@property (nonatomic, copy) NSString *pluginID;
@end

@implementation WitchPluginCell
@end

@interface PluginsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray<WitchPlugin *> *plugins;
@property (nonatomic) DownloadProgressOverlay *verificationOverlay;
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(pickPackage)];
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
    [self.tableView reloadData];
}

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
    self.verificationOverlay = [DownloadProgressOverlay showInView:self.view title:localize(@"Verifying Plugin", nil)];
    [self.verificationOverlay updateProgress:0.5f message:localize(@"Checking the Witch registry", nil)];
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
        NSDictionary *manifest = info[@"manifest"];
        NSString *name = [manifest[@"name"] isKindOfClass:[NSString class]] ? manifest[@"name"] : @"Plugin";
        NSString *pluginID = [manifest[@"id"] isKindOfClass:[NSString class]] ? manifest[@"id"] : @"";
        NSString *version = [manifest[@"version"] isKindOfClass:[NSString class]] ? manifest[@"version"] : @"";
        NSString *author = [manifest[@"author"] isKindOfClass:[NSString class]] ? manifest[@"author"] : @"Unknown";
        NSString *license = [manifest[@"license"] isKindOfClass:[NSString class]] ? manifest[@"license"] : @"";
        NSString *source = [manifest[@"source"] isKindOfClass:[NSString class]] ? manifest[@"source"] : @"";
        NSString *message = [NSString stringWithFormat:@"%@ %@\nAuthor: %@\nLicense: %@\nSource: %@\n\n%@", name, version, author, license, source, localize(@"Verified by the Witch plugin registry. Signature and checksums are valid.", nil)];
        [AppSheet showConfirmWithTitle:localize(@"Install Plugin", nil) message:message confirmTitle:localize(@"Install", nil) destructive:NO onConfirm:^{
            [strongSelf installLocalPackage:localURL info:info name:name pluginID:pluginID];
        } onCancel:^{
            [[NSFileManager defaultManager] removeItemAtPath:localURL.path error:nil];
        }];
    }];
}

- (void)hideVerificationOverlay {
    [self.verificationOverlay dismiss];
    self.verificationOverlay = nil;
}

- (void)installLocalPackage:(NSURL *)url info:(NSDictionary *)info name:(NSString *)name pluginID:(NSString *)pluginID {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL installed = [WitchPluginManager.shared installPackageAtURL:url expectedInfo:info error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtPath:url.path error:nil];
            if (!installed) {
                showDialog(localize(@"Install Failed", nil), error.localizedDescription ?: @"Cannot install plugin");
                return;
            }
            NSLog(@"[Plugins] Installed %@ (%@) after registry verification", pluginID, name);
            [self reloadContent];
            [WitchPluginTheme reload];
            [ThemeManager.shared broadcastThemeChange];
            showDialog(localize(@"Plugin Installed", nil), [NSString stringWithFormat:localize(@"%@ was installed. Restart the launcher to load it.", nil), name]);
        });
    });
}

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.plugins.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? localize(@"Safe Mode", nil) : localize(@"Installed Plugins", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return WitchPluginManager.shared.safeMode ? localize(@"All plugins are paused. Turn off safe mode to load them again.", nil) : localize(@"Turn on to skip all plugins at launch. Changes apply after restart.", nil);
    if (self.plugins.count == 0) return localize(@"No plugins installed. Tap + to install a .plgw package.", nil);
    return [NSString stringWithFormat:localize(@"Advanced: edit %@ in the app folder to disable a plugin manually.", nil), WitchPluginManager.shared.configurationPath.lastPathComponent ?: @"plugins.json"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
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

    WitchPluginCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PluginCell"];
    if (!cell) {
        cell = [[WitchPluginCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PluginCell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    WitchPlugin *plugin = self.plugins[indexPath.row];
    cell.pluginID = plugin.pluginID;
    cell.textLabel.text = plugin.name;
    NSString *status = localize(@"Unverified", nil);
    if (plugin.verificationState == WitchPluginVerificationStateVerified) status = localize(@"Verified", nil);
    else if (plugin.verificationState == WitchPluginVerificationStateRevoked) status = localize(@"Revoked", nil);
    else if (plugin.verificationState == WitchPluginVerificationStateInvalid) status = localize(@"Blocked", nil);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"v%@  ·  %@  ·  %@", plugin.version, plugin.license, status];
    cell.imageView.image = [plugin iconImage] ?: [UIImage systemImageNamed:@"puzzlepiece.extension"];
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = plugin.enabled;
    toggle.enabled = plugin.verificationState != WitchPluginVerificationStateRevoked && plugin.verificationState != WitchPluginVerificationStateInvalid;
    [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
        UISwitch *sender = (UISwitch *)action.sender;
        NSError *error = nil;
        if (![WitchPluginManager.shared setPluginID:plugin.pluginID enabled:sender.isOn error:&error]) {
            sender.on = !sender.isOn;
            showDialog(localize(@"Error", nil), error.localizedDescription);
        }
        [self reloadContent];
    }] forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    WitchPlugin *plugin = self.plugins[indexPath.row];
    [HapticManager.shared play:HapticTypeLight];
    PluginDetailViewController *detail = [[PluginDetailViewController alloc] initWithPlugin:plugin];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
