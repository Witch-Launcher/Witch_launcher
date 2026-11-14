#import "WitchJITSettingsViewController.h"

#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "LauncherPreferences.h"
#import "ThemeManager.h"
#import "WitchJITCoordinator.h"
#import "WitchVPNHelper.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#if TARGET_OS_IOS

@interface WitchJITCoordinator (MethodList)
/// Every method id the picker offers. Declared here so the picker and the
/// resolver (WitchJITCoordinator) can never drift apart.
+ (NSArray<NSString *> *)supportedMethods;
@end

@interface WitchJITSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic, copy) NSString *vpnStatus;
@property (nonatomic) BOOL vpnReachable;
@end

@implementation WitchJITSettingsViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = localize(@"jit.title", nil);
        _vpnStatus = localize(@"jit.vpn.unknown", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];

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

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
                                                 name:WitchJITStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)refresh {
    [WitchVPNHelper probeWithCompletion:^(BOOL reachable) {
        self.vpnReachable = reachable;
        if ([WitchVPNHelper isInstalled]) {
            self.vpnStatus = reachable ? localize(@"jit.vpn.connected", nil) : localize(@"jit.vpn.not_connected", nil);
        } else {
            self.vpnStatus = localize(@"jit.vpn.not_installed", nil);
        }
        [self.tableView reloadData];
    }];
    [self.tableView reloadData];
}

#pragma mark - Table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2; // method, force script
        case 1: return 5; // status, TXM, pairing, prepare, reset DDI
        case 2: return [WitchVPNHelper isInstalled] ? 2 : 1; // status + connect/get
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return localize(@"jit.section.method", nil);
        case 1: return localize(@"jit.section.builtin", nil);
        case 2: return localize(@"jit.section.network", nil);
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return [self methodRequirementText:[WitchJITCoordinator shared].selectedMethod];
    }
    if (section == 3) {
        return localize(@"jit.help.footer", nil);
    }
    if (section == 1) {
        if (![WitchJITCoordinator shared].isBuiltInAvailable) {
            if ([WitchJITCoordinator shared].isLiveContainer) {
                return localize(@"jit.help.livecontainer", nil);
            }
            return localize(@"jit.help.unavailable", nil);
        }
        if (![WitchJITCoordinator shared].hasPairingFile) {
            return localize(@"jit.help.pairing_required", nil);
        }
        return localize(@"jit.help.ready", nil);
    }
    return nil;
}

- (UITableViewCell *)cellWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WitchJITCoordinator *coordinator = WitchJITCoordinator.shared;

    if (indexPath.section == 0 && indexPath.row == 0) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"method"];
        cell.textLabel.text = localize(@"jit.method", nil);
        cell.detailTextLabel.text = [self methodDisplayName:coordinator.selectedMethod];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    if (indexPath.section == 0 && indexPath.row == 1) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"force"];
        cell.textLabel.text = localize(@"jit.force_script", nil);
        cell.accessoryView = nil;
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = ThemeManager.shared.accentColor;
        toggle.on = coordinator.forceScript;
        [toggle addTarget:self action:@selector(forceScriptChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    if (indexPath.section == 1) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"builtin"];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = localize(@"jit.status", nil);
                cell.detailTextLabel.text = coordinator.isBuiltInAvailable
                    ? (coordinator.isBuiltInConfigured ? localize(@"jit.status.ready", nil) : localize(@"jit.status.needs_pairing", nil))
                    : localize(@"jit.status.unavailable", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            case 1:
                cell.textLabel.text = localize(@"jit.txm", nil);
                cell.detailTextLabel.text = coordinator.txmPresent
                    ? localize(@"jit.txm.present", nil)
                    : localize(@"jit.txm.absent", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            case 2:
                cell.textLabel.text = localize(@"jit.pairing_file", nil);
                cell.detailTextLabel.text = coordinator.hasPairingFile
                    ? coordinator.pairingFileName
                    : localize(@"jit.pairing_file.none", nil);
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 3:
                cell.textLabel.text = localize(@"jit.prepare", nil);
                cell.detailTextLabel.text = coordinator.lastPreparationMessage ?: @"";
                break;
            default:
                cell.textLabel.text = localize(@"jit.reset_ddi", nil);
                cell.detailTextLabel.text = @"";
                break;
        }
        return cell;
    }

    UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"network"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (indexPath.row == 0) {
        cell.textLabel.text = localize(@"jit.vpn.title", nil);
        cell.detailTextLabel.text = self.vpnStatus;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.textLabel.text = [WitchVPNHelper isInstalled] ? localize(@"jit.vpn.connect", nil) : localize(@"jit.vpn.get", nil);
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 0) {
        [self showMethodPicker];
        return;
    }
    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 2: [self importPairingFile]; break;
            case 3: [self prepareJIT]; break;
            case 4: [self confirmResetDDI]; break;
            default: break;
        }
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 1) {
        if ([WitchVPNHelper isInstalled]) {
            // LocalDevVPN returns through witch://; the settings screen refreshes
            // on UIApplicationDidBecomeActiveNotification.
            [WitchVPNHelper connect];
        } else {
            [WitchVPNHelper openAppStore];
        }
    }
}

#pragma mark - Actions

- (NSString *)methodDisplayName:(NSString *)method {
    if ([method isEqualToString:@"builtin"]) return [self localizedMethodName:@"jit.method.builtin" fallback:@"Built-in StikJIT"];
    if ([method isEqualToString:@"stikdebug"]) return [self localizedMethodName:@"jit.method.stikdebug" fallback:@"StikDebug"];
    if ([method isEqualToString:@"wait"]) return [self localizedMethodName:@"jit.method.wait" fallback:@"Wait for Debugger"];
    if ([method isEqualToString:@"trollstore"]) return [self localizedMethodName:@"jit.method.trollstore" fallback:@"TrollStore"];
    if ([method isEqualToString:@"sidestore"]) return [self localizedMethodName:@"jit.method.sidestore" fallback:@"SideStore"];
    if ([method isEqualToString:@"livecontainer"]) return [self localizedMethodName:@"jit.method.livecontainer" fallback:@"LiveContainer"];
    return [self localizedMethodName:@"jit.method.auto" fallback:@"Auto"];
}

// localize() returns the key itself when a translation is missing, so the
// picker shows an English name instead of a raw key in untranslated locales.
- (NSString *)localizedMethodName:(NSString *)key fallback:(NSString *)fallback {
    NSString *name = localize(key, nil);
    if ([name hasPrefix:@"jit.method."]) return fallback;
    return name;
}

// One line under every method in the picker: what the method does here and
// whether this device can run it. The user picks a method before the game is
// launched, so the state has to be visible at that point.
- (NSString *)methodSubtitle:(NSString *)method {
    WitchJITCoordinator *coordinator = WitchJITCoordinator.shared;
    if ([method isEqualToString:@"auto"]) {
        return [self localizedMethodName:@"jit.method.auto.hint" fallback:@"Picks the best method this device supports."];
    }
    if ([method isEqualToString:@"builtin"]) {
        if (!coordinator.isBuiltInAvailable) {
            return [self localizedMethodName:@"jit.method.builtin.unavailable" fallback:@"Not available on this device"];
        }
        if (!coordinator.hasPairingFile) {
            return [self localizedMethodName:@"jit.method.builtin.pairing" fallback:@"Needs a pairing file"];
        }
        return [self localizedMethodName:@"jit.method.builtin.ready" fallback:@"Ready"];
    }
    if ([method isEqualToString:@"stikdebug"]) {
        return [self localizedMethodName:@"jit.method.stikdebug.hint" fallback:@"Opens StikDebug to enable JIT."];
    }
    if ([method isEqualToString:@"wait"]) {
        return [self localizedMethodName:@"jit.method.wait.hint" fallback:@"Waits for a debugger to attach."];
    }
    if ([method isEqualToString:@"trollstore"]) {
        BOOL ready = getEntitlementValue(@"com.apple.private.local.sandboxed-jit");
        return ready ? [self localizedMethodName:@"jit.method.trollstore.ready" fallback:@"TrollStore JIT entitlement found"]
                     : [self localizedMethodName:@"jit.method.trollstore.missing" fallback:@"Needs the TrollStore JIT entitlement"];
    }
    if ([method isEqualToString:@"sidestore"]) {
        BOOL ready = [self sideStoreInstalled];
        return ready ? [self localizedMethodName:@"jit.method.sidestore.ready" fallback:@"SideStore is installed"]
                     : [self localizedMethodName:@"jit.method.sidestore.missing" fallback:@"SideStore is not installed"];
    }
    if ([method isEqualToString:@"livecontainer"]) {
        BOOL ready = coordinator.isLiveContainer;
        return ready ? [self localizedMethodName:@"jit.method.livecontainer.ready" fallback:@"LiveContainer is running Witch"]
                     : [self localizedMethodName:@"jit.method.livecontainer.missing" fallback:@"LiveContainer is not running Witch"];
    }
    return nil;
}

// What the selected method still needs from the device, shown under the
// method row so the user knows what to prepare before the next launch.
- (NSString *)methodRequirementText:(NSString *)method {
    WitchJITCoordinator *coordinator = [WitchJITCoordinator shared];
    if ([method isEqualToString:@"trollstore"] && !getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) {
        return localize(@"jit.method.trollstore.hint", nil);
    }
    if ([method isEqualToString:@"sidestore"]) {
        // The install hint only matters while SideStore is missing. Once it is
        // there the user only has to hand the request over to it.
        return [self sideStoreInstalled] ? localize(@"jit.method.sidestore.hint.installed", nil)
                                         : localize(@"jit.method.sidestore.hint", nil);
    }
    if ([method isEqualToString:@"livecontainer"] && !coordinator.isLiveContainer) {
        return localize(@"jit.method.livecontainer.hint", nil);
    }
    if ([method isEqualToString:@"builtin"] && !coordinator.isBuiltInAvailable) {
        return coordinator.isLiveContainer ? localize(@"jit.help.livecontainer", nil) : localize(@"jit.help.unavailable", nil);
    }
    if ([method isEqualToString:@"builtin"] && !coordinator.hasPairingFile) {
        // The helper cannot attach without a remote pairing file, so say that
        // before the user launches with a method that cannot work yet.
        return localize(@"jit.help.pairing_required", nil);
    }
    return nil;
}

// SideStore registers its own URL scheme, so the scheme being handled means
// the app is installed and can take the JIT request.
- (BOOL)sideStoreInstalled {
    NSURL *url = [NSURL URLWithString:@"sidestore://"];
    if (!url) return NO;
    return [UIApplication.sharedApplication canOpenURL:url];
}

- (void)showMethodPicker {
    NSMutableArray *options = [NSMutableArray array];
    NSArray *methods = [WitchJITCoordinator supportedMethods];
    NSString *current = WitchJITCoordinator.shared.selectedMethod;
    NSInteger selected = 0;
    for (NSUInteger i = 0; i < methods.count; i++) {
        NSString *method = methods[i];
        [options addObject:@{@"title": [self methodDisplayName:method],
                             @"subtitle": [self methodSubtitle:method] ?: @""}];
        if ([method isEqualToString:current]) selected = (NSInteger)i;
    }
    [AppSheet showOptionsWithTitle:localize(@"jit.method", nil)
                           message:nil
                           options:options
                     selectedIndex:selected
                         selection:^(NSInteger index) {
        if (index < 0 || index >= (NSInteger)methods.count) return;
        WitchJITCoordinator.shared.selectedMethod = methods[index];
        [self.tableView reloadData];
    }];
}

- (void)forceScriptChanged:(UISwitch *)sender {
    setPrefBool(@"jit.force_script", sender.on);
}

- (void)importPairingFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeItem]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSError *error = nil;
    if (![WitchJITCoordinator.shared importPairingFileAtURL:url error:&error]) {
        showDialog(localize(@"jit.import_failed", nil), error.localizedDescription ?: @"Unknown error");
        return;
    }
    [self refresh];
    showDialog(localize(@"jit.imported", nil), localize(@"jit.imported.message", nil));
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (void)prepareJIT {
    if (!WitchJITCoordinator.shared.isBuiltInAvailable) {
        showDialog(localize(@"jit.unavailable", nil), localize(@"jit.help.unavailable", nil));
        return;
    }
    if (!WitchJITCoordinator.shared.hasPairingFile) {
        showDialog(localize(@"jit.pairing_required", nil), localize(@"jit.help.pairing_required", nil));
        return;
    }
    if (![WitchVPNHelper isInstalled]) {
        [self promptInstallVPN];
        return;
    }
    [WitchVPNHelper probeWithCompletion:^(BOOL reachable) {
        if (!reachable) {
            [self promptConnectVPN];
            return;
        }
        [self runPrepare];
    }];
}

- (void)runPrepare {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"jit.preparing", nil)
                                                                   message:localize(@"jit.preparing.message", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    [WitchJITCoordinator.shared prepareWithCompletion:^(NSDictionary *response, NSError *error) {
        [alert dismissViewControllerAnimated:YES completion:^{
            BOOL success = [response[@"success"] boolValue];
            NSString *message = [response[@"message"] isKindOfClass:NSString.class] ? response[@"message"] : nil;
            if (error) message = error.localizedDescription;
            showDialog(success ? localize(@"jit.prepare_ready", nil) : localize(@"jit.prepare_failed", nil),
                       message ?: (success ? localize(@"jit.prepare_ready.message", nil) : localize(@"jit.prepare_failed.message", nil)));
            [self.tableView reloadData];
        }];
    }];
}

- (void)confirmResetDDI {
    [AppSheet showConfirmWithTitle:localize(@"jit.reset_ddi", nil)
                           message:localize(@"jit.reset_ddi.message", nil)
                      confirmTitle:localize(@"jit.reset_ddi.confirm", nil)
                       destructive:YES
                         onConfirm:^{
        [WitchJITCoordinator.shared resetDDIWithCompletion:^(NSDictionary *response, NSError *error) {
            NSString *message = [response[@"message"] isKindOfClass:NSString.class] ? response[@"message"] : nil;
            if (error) message = error.localizedDescription;
            showDialog(localize(@"jit.reset_ddi", nil), message ?: @"");
            [self.tableView reloadData];
        }];
    }];
}

- (void)promptInstallVPN {
    [AppSheet showConfirmWithTitle:localize(@"jit.vpn.required", nil)
                           message:localize(@"jit.vpn.install.message", nil)
                      confirmTitle:localize(@"jit.vpn.get", nil)
                       destructive:NO
                         onConfirm:^{ [WitchVPNHelper openAppStore]; }];
}

- (void)promptConnectVPN {
    [AppSheet showConfirmWithTitle:localize(@"jit.vpn.required", nil)
                           message:localize(@"jit.vpn.connect.message", nil)
                      confirmTitle:localize(@"jit.vpn.connect", nil)
                       destructive:NO
                         onConfirm:^{ [WitchVPNHelper connect]; }];
}

@end

#else

@implementation WitchJITSettingsViewController
@end

#endif
