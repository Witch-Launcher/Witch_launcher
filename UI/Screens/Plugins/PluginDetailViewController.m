#import "PluginDetailViewController.h"
#import "PluginSettingsViewController.h"
#import "WitchPluginManager.h"
#import "WitchPluginTheme.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "utils.h"
#import "ios_uikit_bridge.h"

@interface PluginDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, strong) WitchPlugin *plugin;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIView *headerView;
@end

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
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 176)];
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
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(20, 108, width - 40, 22)];
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
    UILabel *summary = [[UILabel alloc] initWithFrame:CGRectMake(20, 136, width - 40, 34)];
    summary.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    summary.font = [UIFont systemFontOfSize:13];
    summary.textColor = ThemeManager.shared.secondaryTextColor;
    summary.numberOfLines = 2;
    summary.text = self.plugin.summaryText;
    [header addSubview:summary];
    self.headerView = header;
    self.tableView.tableHeaderView = header;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 5;
    if (section == 1) return 4;
    return 3 + (self.plugin.settingsSchema.count > 0 ? 1 : 0);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return localize(@"About", nil);
    if (section == 1) return localize(@"Security", nil);
    return localize(@"Manage", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DetailCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";

    if (indexPath.section == 0) {
        NSArray *labels = @[localize(@"Version", nil), localize(@"Author", nil), localize(@"License", nil), localize(@"Source Code", nil), localize(@"Plugin API", nil)];
        NSArray *values = @[self.plugin.version ?: @"", self.plugin.author ?: @"", self.plugin.license ?: @"", self.plugin.sourceURL ?: @"", [NSString stringWithFormat:@"%ld", (long)self.plugin.apiVersion]];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        if (indexPath.row == 3) {
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 1) {
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
    } else {
        if (self.plugin.settingsSchema.count > 0 && indexPath.row == 0) {
            cell.textLabel.text = localize(@"Plugin Settings", nil);
            cell.detailTextLabel.text = localize(@"Options provided by the plugin", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            NSInteger row = indexPath.row - (self.plugin.settingsSchema.count > 0 ? 1 : 0);
            if (row == 0) {
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
            } else if (row == 1) {
                cell.textLabel.text = self.plugin.developerSigned ? localize(@"Trust this developer key", nil) : localize(@"Publisher key trusted", nil);
                cell.detailTextLabel.text = localize(@"Trusting a key allows its plugins to use advanced UI hooks.", nil);
                cell.selectionStyle = self.plugin.developerSigned ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.text = localize(@"Uninstall Plugin", nil);
                cell.textLabel.textColor = ThemeManager.shared.errorColor;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 3 && self.plugin.sourceURL.length > 0) {
        openLink(self, [NSURL URLWithString:self.plugin.sourceURL]);
        return;
    }
    if (indexPath.section == 2) {
        NSInteger offset = self.plugin.settingsSchema.count > 0 ? 1 : 0;
        if (offset == 1 && indexPath.row == 0) {
            PluginSettingsViewController *settings = [[PluginSettingsViewController alloc] initWithPluginID:self.pluginID];
            [self.navigationController pushViewController:settings animated:YES];
            return;
        }
        NSInteger row = indexPath.row - offset;
        if (row == 1) {
            [self confirmTrustDeveloperKey];
            return;
        }
        if (row == 2) {
            [self confirmUninstall];
        }
    }
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
