#import "PluginDetailViewController.h"
#import "PluginSettingsViewController.h"
#import "PluginInstallFlow.h"
#import "PluginRiskBadgeView.h"
#import "WitchPluginManager.h"
#import "WitchPluginTheme.h"
#import "WitchPluginUpdateService.h"
#import "WitchPluginVersion.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "utils.h"
#import "ios_uikit_bridge.h"

typedef NS_ENUM(NSInteger, PluginDetailSection) {
    PluginDetailSectionAbout = 0,
    PluginDetailSectionSecurity = 1,
    PluginDetailSectionAnalysis = 2,
    PluginDetailSectionManage = 3
};

@interface PluginDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, strong) WitchPlugin *plugin;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIView *headerView;
@end

static NSString *WPRiskString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation PluginDetailViewController

- (instancetype)initWithPlugin:(WitchPlugin *)plugin {
    self = [super init];
    if (self) {
        _pluginID = [plugin.pluginID copy];
        _plugin = plugin;
        self.title = plugin.name;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadContent) name:WitchPluginsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContent];
}

- (void)reloadContent {
    WitchPlugin *latest = [WitchPluginManager.shared pluginWithID:self.pluginID];
    if (latest) {
        self.plugin = latest;
        self.title = latest.name;
    }
    [self rebuildHeader];
    [self.tableView reloadData];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [self rebuildHeader];
    [self.tableView reloadData];
}

- (void)rebuildHeader {
    CGFloat width = self.view.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 200)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(20, 20, 72, 72)];
    icon.contentMode = UIViewContentModeScaleAspectFill;
    icon.layer.cornerRadius = 16;
    icon.clipsToBounds = YES;
    icon.image = [self.plugin iconImage] ?: [UIImage systemImageNamed:@"puzzlepiece.extension"];
    icon.tintColor = ThemeManager.shared.accentColor;
    icon.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    [header addSubview:icon];
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(108, 24, width - 128, 30)];
    name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    name.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    name.textColor = ThemeManager.shared.primaryTextColor;
    name.text = self.plugin.name;
    [header addSubview:name];
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(108, 56, width - 128, 22)];
    subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    subtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    subtitle.textColor = ThemeManager.shared.secondaryTextColor;
    subtitle.text = [NSString stringWithFormat:@"v%@  ·  %@", self.plugin.version, self.plugin.license];
    [header addSubview:subtitle];
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(20, 112, width - 140, 22)];
    status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    status.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    if (self.plugin.verificationState == WitchPluginVerificationStateVerified) {
        status.textColor = ThemeManager.shared.successColor;
        status.text = localize(@"Verified by the Witch registry", nil);
    } else if (self.plugin.verificationState == WitchPluginVerificationStateRevoked) {
        status.textColor = ThemeManager.shared.errorColor;
        status.text = localize(@"Revoked by the Witch registry", nil);
    } else if (self.plugin.verificationState == WitchPluginVerificationStateInvalid) {
        status.textColor = ThemeManager.shared.errorColor;
        status.text = localize(@"Blocked by the Witch registry", nil);
    } else {
        status.textColor = ThemeManager.shared.warningColor;
        status.text = localize(@"Unverified. Install only if you trust the author.", nil);
    }
    [header addSubview:status];

    // Risk badge: red for a dangerous plugin, yellow for one that needs a
    // second look.
    PluginRiskBadgeView *badge = [PluginRiskBadgeView badgeForLevel:self.plugin.riskLevel];
    badge.frame = CGRectMake(width - 20 - 86, 112, 86, 20);
    badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [header addSubview:badge];

    UILabel *summary = [[UILabel alloc] initWithFrame:CGRectMake(20, 142, width - 40, 48)];
    summary.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    summary.font = [UIFont systemFontOfSize:13];
    summary.textColor = ThemeManager.shared.secondaryTextColor;
    summary.numberOfLines = 3;
    summary.text = self.plugin.summaryText;
    [header addSubview:summary];
    self.headerView = header;
    self.tableView.tableHeaderView = header;
}

#pragma mark - Catalog

- (nullable WitchPluginCatalogEntry *)updateEntry {
    WitchPluginCatalogEntry *entry = [WitchPluginUpdateService.shared entryForPluginID:self.pluginID];
    if (!entry) return nil;
    if (![WitchPluginVersion isVersion:entry.version newerThan:self.plugin.version]) return nil;
    return entry;
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == PluginDetailSectionAbout) return 5;
    if (section == PluginDetailSectionSecurity) return 4;
    if (section == PluginDetailSectionAnalysis) return [self analysisRows].count;
    return [self manageRows].count;
}

// The analysis section is built from a list so the sandbox rows and the
// findings always stay in the same order.
- (NSArray<NSDictionary *> *)analysisRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSString *level = localize(@"Safe", nil);
    if (self.plugin.riskLevel == WitchPluginRiskLevelWarning) level = localize(@"Warning", nil);
    else if (self.plugin.riskLevel == WitchPluginRiskLevelDangerous) level = localize(@"Dangerous", nil);
    [rows addObject:@{@"kind": @"risk", @"title": localize(@"Risk level", nil), @"value": level}];
    [rows addObject:@{@"kind": @"runs",
                       @"title": localize(@"What the launcher runs", nil),
                       @"value": self.plugin.riskSummary.count > 0 ? [self.plugin.riskSummary componentsJoinedByString:@"\n"] : localize(@"Nothing", nil)}];
    [rows addObject:@{@"kind": @"sandbox",
                       @"title": localize(@"Sandbox rehearsal", nil),
                       @"value": [self sandboxSummary]}];
    for (NSDictionary *finding in self.plugin.riskFindings) {
        NSString *findingLevel = [finding[@"level"] integerValue] == WitchPluginRiskLevelDangerous ? localize(@"Dangerous", nil) : localize(@"Warning", nil);
        [rows addObject:@{@"kind": @"finding",
                           @"title": [NSString stringWithFormat:@"%@  ·  %@", findingLevel, WPRiskString(finding[@"title"])],
                           @"value": WPRiskString(finding[@"detail"])}];
    }
    for (NSString *blocked in self.plugin.sandboxBlocked) {
        [rows addObject:@{@"kind": @"blocked",
                           @"title": [NSString stringWithFormat:localize(@"Blocked: %@", nil), blocked],
                           @"value": localize(@"The sandbox refused this call while the package was verified.", nil)}];
    }
    for (NSString *error in self.plugin.sandboxErrors) {
        [rows addObject:@{@"kind": @"error",
                           @"title": localize(@"Failed while it was verified", nil),
                           @"value": error}];
    }
    for (NSString *capability in self.plugin.sandboxCapabilities) {
        [rows addObject:@{@"kind": @"capability",
                           @"title": capability,
                           @"value": localize(@"The payload carries this system API.", nil)}];
    }
    if (self.plugin.sandboxObservations.count > 0) {
        NSMutableArray *calls = [NSMutableArray array];
        for (NSString *observation in self.plugin.sandboxObservations) {
            if (calls.count >= 8) break;
            [calls addObject:observation];
        }
        NSString *value = [calls componentsJoinedByString:@"\n"];
        if (self.plugin.sandboxObservations.count > calls.count) {
            value = [value stringByAppendingFormat:@"\n%@", [NSString stringWithFormat:localize(@"and %lu more", nil), (unsigned long)(self.plugin.sandboxObservations.count - calls.count)]];
        }
        [rows addObject:@{@"kind": @"calls",
                           @"title": [NSString stringWithFormat:localize(@"Calls recorded (%lu)", nil), (unsigned long)self.plugin.sandboxObservations.count],
                           @"value": value}];
    }
    return rows;
}

- (NSString *)sandboxSummary {
    WitchPluginSandboxReport *report = [WitchPluginSandboxReport reportFromDictionary:@{
        @"verdict": @(self.plugin.sandboxVerdict),
        @"observations": self.plugin.sandboxObservations ?: @[],
        @"blocked": self.plugin.sandboxBlocked ?: @[],
        @"errors": self.plugin.sandboxErrors ?: @[],
        @"capabilities": self.plugin.sandboxCapabilities ?: @[]
    }];
    if (!self.plugin.sandboxVerdict && self.plugin.sandboxObservations.count == 0 && self.plugin.sandboxCapabilities.count == 0) {
        return localize(@"Nothing was executed during the verification.", nil);
    }
    NSMutableArray *parts = [NSMutableArray array];
    if (self.plugin.sandboxObservations.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu calls recorded", nil), (unsigned long)self.plugin.sandboxObservations.count]];
    }
    if (self.plugin.sandboxBlocked.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu blocked attempts", nil), (unsigned long)self.plugin.sandboxBlocked.count]];
    }
    if (self.plugin.sandboxErrors.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu errors", nil), (unsigned long)self.plugin.sandboxErrors.count]];
    }
    if (self.plugin.sandboxCapabilities.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu capabilities", nil), (unsigned long)self.plugin.sandboxCapabilities.count]];
    }
    return [NSString stringWithFormat:@"%@ — %@", [report verdictLabel], [parts componentsJoinedByString:@", "]];
}

// The manage section is built from a list so a new row never shifts the
// meaning of the rows below it.
- (NSArray<NSString *> *)manageRows {
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    if ([self updateEntry]) [rows addObject:@"update"];
    if (self.plugin.settingsSchema.count > 0) [rows addObject:@"settings"];
    [rows addObject:@"enabled"];
    [rows addObject:@"trust"];
    [rows addObject:@"sandbox"];
    [rows addObject:@"uninstall"];
    return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == PluginDetailSectionAbout) return localize(@"About", nil);
    if (section == PluginDetailSectionSecurity) return localize(@"Security", nil);
    if (section == PluginDetailSectionAnalysis) return localize(@"Analysis", nil);
    return localize(@"Manage", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != PluginDetailSectionAnalysis) return nil;
    if (self.plugin.riskFindings.count == 0) {
        return localize(@"No finding. The plugin only declares settings and theme data.", nil);
    }
    return localize(@"The analysis is computed from the manifest and from the files the launcher would execute.", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DetailCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";

    if (indexPath.section == PluginDetailSectionAbout) {
        NSArray *labels = @[localize(@"Version", nil), localize(@"Author", nil), localize(@"License", nil), localize(@"Source Code", nil), localize(@"Plugin API", nil)];
        NSArray *values = @[self.plugin.version ?: @"", self.plugin.author ?: @"", self.plugin.license ?: @"", self.plugin.sourceURL ?: @"", [NSString stringWithFormat:@"%ld", (long)self.plugin.apiVersion]];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        if (indexPath.row == 3) {
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == PluginDetailSectionSecurity) {
        NSString *state = localize(@"Unverified", nil);
        if (self.plugin.verificationState == WitchPluginVerificationStateVerified) state = localize(@"Verified", nil);
        else if (self.plugin.verificationState == WitchPluginVerificationStateRevoked) state = localize(@"Revoked", nil);
        else if (self.plugin.verificationState == WitchPluginVerificationStateInvalid) state = localize(@"Blocked", nil);
        NSArray *labels = @[localize(@"Registry status", nil), localize(@"Signature", nil), localize(@"Signing key", nil), localize(@"Checksums SHA-256", nil)];
        NSArray *values = @[
            self.plugin.verificationMessage ?: state,
            self.plugin.trustedSignature ? localize(@"Trusted publisher key", nil) : localize(@"Valid self-signed / developer key", nil),
            self.plugin.signatureKeyID ?: @"",
            self.plugin.checksumsSha256 ?: @""
        ];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
    } else if (indexPath.section == PluginDetailSectionAnalysis) {
        NSDictionary *row = [self analysisRows][indexPath.row];
        cell.textLabel.text = WPRiskString(row[@"title"]);
        cell.detailTextLabel.text = WPRiskString(row[@"value"]);
        NSString *kind = WPRiskString(row[@"kind"]);
        if ([kind isEqualToString:@"risk"]) {
            if (self.plugin.riskLevel == WitchPluginRiskLevelDangerous) cell.detailTextLabel.textColor = ThemeManager.shared.errorColor;
            else if (self.plugin.riskLevel == WitchPluginRiskLevelWarning) cell.detailTextLabel.textColor = ThemeManager.shared.warningColor;
            else cell.detailTextLabel.textColor = ThemeManager.shared.successColor;
        } else if ([kind isEqualToString:@"blocked"] || [kind isEqualToString:@"error"]) {
            cell.detailTextLabel.textColor = ThemeManager.shared.warningColor;
        } else {
            cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
        }
    } else {
        NSString *row = [self manageRows][indexPath.row];
        if ([row isEqualToString:@"update"]) {
            WitchPluginCatalogEntry *update = [self updateEntry];
            cell.textLabel.text = localize(@"Update", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:localize(@"Version %@ is available", nil), update.version ?: @""];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.textColor = ThemeManager.shared.accentColor;
        } else if ([row isEqualToString:@"settings"]) {
            cell.textLabel.text = localize(@"Plugin Settings", nil);
            cell.detailTextLabel.text = localize(@"Options provided by the plugin", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([row isEqualToString:@"enabled"]) {
            cell.textLabel.text = localize(@"Enabled", nil);
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = self.plugin.enabled;
            toggle.enabled = self.plugin.verificationState != WitchPluginVerificationStateRevoked && self.plugin.verificationState != WitchPluginVerificationStateInvalid;
            [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
                UISwitch *sender = (UISwitch *)action.sender;
                NSError *error = nil;
                if (![WitchPluginManager.shared setPluginID:self.pluginID enabled:sender.isOn error:&error]) {
                    sender.on = !sender.isOn;
                    showDialog(localize(@"Error", nil), error.localizedDescription);
                }
                [self reloadContent];
            }] forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        } else if ([row isEqualToString:@"trust"]) {
            cell.textLabel.text = self.plugin.developerSigned ? localize(@"Trust this developer key", nil) : localize(@"Publisher key trusted", nil);
            cell.detailTextLabel.text = localize(@"Trusting a key allows its plugins to use advanced UI hooks.", nil);
            cell.selectionStyle = self.plugin.developerSigned ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        } else if ([row isEqualToString:@"sandbox"]) {
            cell.textLabel.text = localize(@"Sandbox", nil);
            BOOL nativeBlocked = self.plugin.sandboxed && [self.plugin.entrypoints[@"native"] isKindOfClass:[NSString class]] && [(NSString *)self.plugin.entrypoints[@"native"] length] > 0;
            if (self.plugin.sandboxed) {
                cell.detailTextLabel.text = nativeBlocked
                    ? localize(@"Native code is blocked. Turn the sandbox off to let the plugin run.", nil)
                    : localize(@"Native code is blocked and the script runs isolated.", nil);
            } else {
                cell.detailTextLabel.text = localize(@"The plugin runs with the full launcher permissions.", nil);
            }
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = self.plugin.sandboxed;
            [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
                UISwitch *sender = (UISwitch *)action.sender;
                [self confirmSandboxChange:sender.isOn sender:sender];
            }] forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        } else {
            cell.textLabel.text = localize(@"Uninstall Plugin", nil);
            cell.textLabel.textColor = ThemeManager.shared.errorColor;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == PluginDetailSectionAbout && indexPath.row == 3 && self.plugin.sourceURL.length > 0) {
        openLink(self, [NSURL URLWithString:self.plugin.sourceURL]);
        return;
    }
    if (indexPath.section != PluginDetailSectionManage) return;
    NSString *row = [self manageRows][indexPath.row];
    if ([row isEqualToString:@"update"]) {
        WitchPluginCatalogEntry *update = [self updateEntry];
        if (update) [PluginInstallFlow.shared installCatalogEntry:update fromViewController:self];
        return;
    }
    if ([row isEqualToString:@"settings"]) {
        PluginSettingsViewController *settings = [[PluginSettingsViewController alloc] initWithPluginID:self.pluginID];
        [self.navigationController pushViewController:settings animated:YES];
        return;
    }
    if ([row isEqualToString:@"trust"]) {
        [self confirmTrustDeveloperKey];
        return;
    }
    if ([row isEqualToString:@"uninstall"]) {
        [self confirmUninstall];
    }
}

#pragma mark - Actions

- (void)confirmSandboxChange:(BOOL)sandboxed sender:(UISwitch *)sender {
    if (sandboxed) {
        [self applySandbox:YES];
        return;
    }
    NSString *message = localize(@"Turning the sandbox off lets the plugin run native code inside the launcher process again.", nil);
    if (self.plugin.riskLevel == WitchPluginRiskLevelDangerous) {
        message = [NSString stringWithFormat:@"%@\n\n%@", message, localize(@"This plugin is marked as dangerous. Only continue if you built it yourself or you fully trust its source.", nil)];
    }
    __weak typeof(self) weakSelf = self;
    [AppSheet showConfirmWithTitle:localize(@"Disable Sandbox", nil)
                           message:message
                      confirmTitle:localize(@"Disable", nil)
                       destructive:YES
                         onConfirm:^{
        [weakSelf applySandbox:NO];
    } onCancel:^{
        sender.on = YES;
    }];
}

- (void)applySandbox:(BOOL)sandboxed {
    NSError *error = nil;
    if (![WitchPluginManager.shared setPluginID:self.pluginID sandboxed:sandboxed error:&error]) {
        showDialog(localize(@"Error", nil), error.localizedDescription);
        return;
    }
    [self reloadContent];
}

- (void)confirmTrustDeveloperKey {
    if (!self.plugin.developerSigned) return;
    NSString *message = [NSString stringWithFormat:localize(@"Trust key %@? Plugins signed by this key will be treated as trusted until removed.", nil), self.plugin.signatureKeyID ?: @""];
    [AppSheet showConfirmWithTitle:localize(@"Trust Developer Key", nil) message:message confirmTitle:localize(@"Trust", nil) destructive:NO onConfirm:^{
        NSError *error = nil;
        if (![WitchPluginManager.shared trustKeyForPluginID:self.pluginID error:&error]) {
            showDialog(localize(@"Error", nil), error.localizedDescription);
            return;
        }
        [self reloadContent];
    }];
}

- (void)confirmUninstall {
    [AppSheet showConfirmWithTitle:localize(@"Uninstall Plugin", nil) message:[NSString stringWithFormat:localize(@"Remove %@ and its settings?", nil), self.plugin.name] confirmTitle:localize(@"Uninstall", nil) destructive:YES onConfirm:^{
        NSError *error = nil;
        if (![WitchPluginManager.shared uninstallPluginID:self.pluginID error:&error]) {
            showDialog(localize(@"Error", nil), error.localizedDescription);
            return;
        }
        [WitchPluginTheme reload];
        [ThemeManager.shared broadcastThemeChange];
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

@end
