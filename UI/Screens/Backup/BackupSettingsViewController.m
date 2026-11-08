#import "BackupSettingsViewController.h"
#import "BackupHistoryViewController.h"
#import "BackupScopeViewController.h"
#import "BackupManager.h"
#import "BackupStore.h"
#import "BackupConfig.h"
#import "BackupKeychain.h"
#import "BackupOAuth.h"
#import "VersionDirectoryManager.h"
#import "ThemeManager.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "DownloadProgressOverlay.h"
#import "HapticManager.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

@interface BackupSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@property (nonatomic, strong) NSArray<id<BackupDestination>> *destinations;
@property (nonatomic, strong) DownloadProgressOverlay *progressOverlay;
@property (nonatomic) BOOL pickingFolder;
@end

@implementation BackupSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"Backup & Restore", nil);
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 52;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:BackupDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)doneTapped {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)reload {
    BackupManager *manager = [BackupManager shared];
    self.destinations = manager.destinations;

    NSMutableArray<NSDictionary *> *destinationRows = [NSMutableArray array];
    for (id<BackupDestination> destination in self.destinations) {
        NSString *detail = destination.detailText ?: @"";
        if (destination.enabled && destination.configured) {
            detail = [detail stringByAppendingString:localize(@" · On", nil)];
        }
        [destinationRows addObject:@{
            @"type": @"destination",
            @"title": destination.displayName,
            @"detail": detail,
            @"identifier": destination.identifier,
        }];
    }

    NSArray<NSString *> *scope = [BackupScope scopeForVersion:VersionDirectoryManager.shared.currentVersion roots:nil].roots;
    NSString *retention = [NSString stringWithFormat:localize(@"%ld backups", nil), (long)[manager retentionCount]];

    BOOL enabled = [manager isEnabled];
    self.sections = @[
        @{@"title": localize(@"Automatic backup", nil), @"items": @[
            @{@"type": @"switch", @"title": localize(@"Enable backup", nil), @"value": @(enabled), @"handler": ^(BOOL on) {
                [[BackupManager shared] setEnabled:on];
            }},
            @{@"type": @"switch", @"title": localize(@"Before launch", nil), @"value": @([manager isTriggerEnabled:@"launch"]), @"handler": ^(BOOL on) {
                [[BackupManager shared] setTrigger:@"launch" enabled:on];
            }},
            @{@"type": @"switch", @"title": localize(@"After game exit", nil), @"value": @([manager isTriggerEnabled:@"exit"]), @"handler": ^(BOOL on) {
                [[BackupManager shared] setTrigger:@"exit" enabled:on];
            }},
            @{@"type": @"switch", @"title": localize(@"When app opens", nil), @"value": @([manager isTriggerEnabled:@"open"]), @"handler": ^(BOOL on) {
                [[BackupManager shared] setTrigger:@"open" enabled:on];
            }},
            @{@"type": @"switch", @"title": localize(@"Scheduled", nil), @"value": @([manager isTriggerEnabled:@"schedule"]), @"handler": ^(BOOL on) {
                [[BackupManager shared] setTrigger:@"schedule" enabled:on];
            }},
            @{@"type": @"picker", @"title": localize(@"Schedule interval", nil), @"detail": [self intervalLabel], @"action": @"pickInterval"},
            @{@"type": @"action", @"title": localize(@"Back up now", nil), @"detail": [manager lastBackupDescription], @"action": @"backupNow"},
        ]},
        @{@"title": localize(@"Destinations", nil), @"items": destinationRows},
        @{@"title": localize(@"What to back up", nil), @"items": @[
            @{@"type": @"navigate", @"title": localize(@"Folders and files", nil), @"detail": [NSString stringWithFormat:localize(@"%lu selected", nil), (unsigned long)scope.count]},
        ]},
        @{@"title": localize(@"Storage", nil), @"items": @[
            @{@"type": @"picker", @"title": localize(@"Keep backups", nil), @"detail": retention, @"action": @"pickRetention"},
            @{@"type": @"action", @"title": localize(@"Local backup size", nil), @"detail": [BackupConfig humanSize:[manager totalLocalBytes]]},
            @{@"type": @"action", @"title": localize(@"Delete all local backups", nil), @"detail": @"", @"action": @"deleteAll", @"destructive": @YES},
        ]},
        @{@"title": localize(@"History", nil), @"items": @[
            @{@"type": @"navigate", @"title": localize(@"Backup history", nil), @"detail": [NSString stringWithFormat:localize(@"%lu backups", nil), (unsigned long)manager.records.count]},
        ]},
    ];
    [self.tableView reloadData];
}

- (NSString *)intervalLabel {
    NSNumber *hours = getPrefObject(@"backup.auto_interval_hours");
    double value = hours.doubleValue > 0 ? hours.doubleValue : 24.0;
    if (value >= 168) return localize(@"Every week", nil);
    if (value >= 48) return [NSString stringWithFormat:localize(@"Every %ld hours", nil), (long)value];
    if (value >= 24) return localize(@"Every day", nil);
    return [NSString stringWithFormat:localize(@"Every %ld hours", nil), (long)value];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return localize(@"Backups run in the background. iOS may delay scheduled backups until the device is charging or idle.", nil);
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = row[@"type"];
    BOOL detailStyle = ![type isEqualToString:@"switch"];
    NSString *reuse = detailStyle ? @"BackupDetailCell" : @"BackupSwitchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:detailStyle ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault reuseIdentifier:reuse];
        cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"detail"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if ([row[@"destructive"] boolValue]) {
        cell.textLabel.textColor = ThemeManager.shared.errorColor;
    } else {
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    }

    if ([type isEqualToString:@"switch"]) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.onTintColor = ThemeManager.shared.accentColor;
        toggle.on = [row[@"value"] boolValue];
        objc_setAssociatedObject(toggle, @selector(switchChanged:), row[@"handler"], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"navigate"] || [type isEqualToString:@"destination"] || [type isEqualToString:@"picker"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"action"] && !row[@"action"]) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    void (^handler)(BOOL) = objc_getAssociatedObject(sender, @selector(switchChanged:));
    if (handler) handler(sender.isOn);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reload];
    });
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = row[@"type"];
    NSString *action = row[@"action"];

    if ([type isEqualToString:@"switch"]) return;
    if ([type isEqualToString:@"destination"]) {
        [self configureDestinationIdentifier:row[@"identifier"]];
        return;
    }
    if ([type isEqualToString:@"navigate"]) {
        if (indexPath.section == 2) {
            [self.navigationController pushViewController:[[BackupScopeViewController alloc] init] animated:YES];
        } else {
            [self.navigationController pushViewController:[[BackupHistoryViewController alloc] init] animated:YES];
        }
        return;
    }
    if ([action isEqualToString:@"backupNow"]) {
        [self runBackup];
    } else if ([action isEqualToString:@"pickInterval"]) {
        [self pickInterval];
    } else if ([action isEqualToString:@"pickRetention"]) {
        [self pickRetention];
    } else if ([action isEqualToString:@"deleteAll"]) {
        [self deleteAllLocal];
    }
}

#pragma mark - Actions

- (void)pickInterval {
    NSArray *values = @[@6, @12, @24, @48, @168];
    NSMutableArray *options = [NSMutableArray array];
    NSNumber *current = getPrefObject(@"backup.auto_interval_hours");
    NSInteger selected = NSNotFound;
    for (NSUInteger i = 0; i < values.count; i++) {
        NSInteger value = [values[i] integerValue];
        NSString *title = value == 24 ? localize(@"Every day", nil) : (value == 168 ? localize(@"Every week", nil) : [NSString stringWithFormat:localize(@"Every %ld hours", nil), (long)value]);
        [options addObject:@{@"title": title, @"icon": @"clock"}];
        if (current.integerValue == value) selected = i;
    }
    [AppSheet showOptionsWithTitle:localize(@"Schedule interval", nil) message:nil options:options selectedIndex:selected selection:^(NSInteger index) {
        setPrefObject(@"backup.auto_interval_hours", values[index]);
        Class scheduler = NSClassFromString(@"BackupScheduler");
        if ([scheduler respondsToSelector:@selector(scheduleNext)]) [(id)scheduler performSelector:@selector(scheduleNext)];
        [self reload];
    }];
}

- (void)pickRetention {
    NSArray *values = @[@3, @5, @10, @20, @50];
    NSMutableArray *options = [NSMutableArray array];
    NSInteger selected = NSNotFound;
    for (NSUInteger i = 0; i < values.count; i++) {
        [options addObject:@{@"title": [NSString stringWithFormat:localize(@"%ld backups", nil), (long)[values[i] integerValue]], @"icon": @"archivebox"}];
        if ([BackupManager shared].retentionCount == [values[i] integerValue]) selected = i;
    }
    [AppSheet showOptionsWithTitle:localize(@"Keep backups", nil) message:localize(@"Older local archives are removed first. Cloud copies are kept.", nil) options:options selectedIndex:selected selection:^(NSInteger index) {
        [[BackupManager shared] setRetentionCount:[values[index] integerValue]];
        [[BackupManager shared] pruneOldBackups];
        [self reload];
    }];
}

- (void)runBackup {
    if (self.progressOverlay) return;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showBlurredInView:self.navigationController.view ?: self.view title:localize(@"Backing up...", nil) blurred:YES];
    [overlay updateProgress:0.15 message:localize(@"Compressing game data", nil)];
    self.progressOverlay = overlay;
    [[BackupManager shared] backupNowWithReason:@"manual" completion:^(BackupRecord *record, NSError *error) {
        [overlay updateProgress:1.0 message:error ? localize(@"Finished with errors", nil) : localize(@"Backup complete", nil)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [overlay dismiss];
            self.progressOverlay = nil;
            if (error) {
                [ErrorPresenter showWarning:localize(@"Backup", nil) message:error.localizedDescription];
            } else if (record) {
                [ErrorPresenter showToast:[NSString stringWithFormat:localize(@"Backup saved to %@", nil), record.destinationSummary] success:YES];
            }
            [self reload];
        });
    }];
}

- (void)deleteAllLocal {
    if ([BackupManager shared].busy) {
        [ErrorPresenter showWarning:localize(@"Backup", nil) message:localize(@"Another backup task is running.", nil)];
        return;
    }
    [AppSheet showConfirmWithTitle:localize(@"Delete local backups?", nil)
                           message:localize(@"Cloud copies are not deleted. This cannot be undone.", nil)
                      confirmTitle:localize(@"Delete", nil)
                       destructive:YES
                         onConfirm:^{
        [[BackupStore shared] removeAllLocalArchives];
        [[BackupManager shared] reload];
        [self reload];
    }];
}

- (void)configureDestinationIdentifier:(NSString *)identifier {
    id<BackupDestination> destination = nil;
    for (id<BackupDestination> item in self.destinations) {
        if ([item.identifier isEqualToString:identifier]) { destination = item; break; }
    }
    if (!destination) return;
    if ([destination isKindOfClass:[BackupFolderDestination class]]) {
        [self configureFolder:(BackupFolderDestination *)destination];
    } else if ([destination isKindOfClass:[BackupWebDAVDestination class]]) {
        [self configureWebDAV];
    } else {
        [self configureOAuthDestination:destination];
    }
}

- (void)configureFolder:(BackupFolderDestination *)folder {
    if (!folder.configured) {
        [self pickFolder];
        return;
    }
    NSMutableArray *options = [NSMutableArray arrayWithObject:@{@"title": localize(@"Back up now", nil), @"icon": @"arrow.up.circle"}];
    [options addObject:@{@"title": localize(@"Change folder", nil), @"icon": @"folder"}];
    [options addObject:@{@"title": folder.enabled ? localize(@"Disable", nil) : localize(@"Enable", nil), @"icon": @"power"}];
    [options addObject:@{@"title": localize(@"Disconnect", nil), @"icon": @"xmark.circle", @"destructive": @YES}];
    [AppSheet showOptionsWithTitle:folder.displayName message:folder.detailText options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        if (index == 0) {
            [folder setEnabled:YES];
            [self runBackup];
        } else if (index == 1) {
            [self pickFolder];
        } else if (index == 2) {
            [folder setEnabled:!folder.enabled];
            [self reload];
        } else if (index == 3) {
            [folder clearFolder];
            [folder setEnabled:NO];
            [self reload];
        }
    }];
}

- (void)pickFolder {
    self.pickingFolder = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (!self.pickingFolder) return;
    self.pickingFolder = NO;
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL accessed = [url startAccessingSecurityScopedResource];
    BackupFolderDestination *folder = [[BackupFolderDestination alloc] init];
    NSError *error = nil;
    BOOL ok = [folder setFolderURL:url error:&error];
    if (accessed) [url stopAccessingSecurityScopedResource];
    if (!ok) {
        [ErrorPresenter showError:localize(@"Backup", nil) message:error.localizedDescription];
        return;
    }
    [folder setEnabled:YES];
    [self reload];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.pickingFolder = NO;
}

- (void)configureWebDAV {
    BackupWebDAVDestination *webdav = [[BackupWebDAVDestination alloc] init];
    NSString *url = getPrefObject(@"backup.webdav_url");
    NSString *username = getPrefObject(@"backup.webdav_username");
    NSString *password = [BackupKeychain stringForKey:@"backup.webdav.password"] ?: @"";
    [AppSheet showPrompt3WithTitle:localize(@"WebDAV", nil)
                           message:localize(@"Enter your own WebDAV server. The password is stored in the iOS Keychain.", nil)
                      placeholder1:@"https://server.example.com/dav"
                      placeholder2:localize(@"Username", nil)
                      placeholder3:localize(@"Password", nil)
                      initialText1:[url isKindOfClass:[NSString class]] ? url : @""
                      initialText2:[username isKindOfClass:[NSString class]] ? username : @""
                      initialText3:password
                         onConfirm:^(NSString *text1, NSString *text2, NSString *text3) {
        NSString *urlValue = [text1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        setPrefObject(@"backup.webdav_url", urlValue);
        setPrefObject(@"backup.webdav_username", text2 ?: @"");
        [BackupKeychain setString:text3 ?: @"" forKey:@"backup.webdav.password"];
        [webdav setEnabled:urlValue.length > 0];
        [self reload];
    }];
}

- (void)configureOAuthDestination:(id<BackupDestination>)destination {
    BackupOAuthProvider provider;
    if ([destination.identifier isEqualToString:@"gdrive"]) provider = BackupOAuthProviderGoogleDrive;
    else if ([destination.identifier isEqualToString:@"onedrive"]) provider = BackupOAuthProviderOneDrive;
    else provider = BackupOAuthProviderDropbox;

    if (![BackupOAuth isProviderConfigured:provider]) {
        [ErrorPresenter showWarning:destination.displayName message:localize(@"This build does not include OAuth credentials for this service.", nil)];
        return;
    }
    if (![BackupOAuth.shared isAuthorizedForProvider:provider]) {
        [self authorizeProvider:provider destination:destination];
        return;
    }

    NSMutableArray *options = [NSMutableArray arrayWithObject:@{@"title": localize(@"Back up now", nil), @"icon": @"arrow.up.circle"}];
    [options addObject:@{@"title": destination.enabled ? localize(@"Disable", nil) : localize(@"Enable", nil), @"icon": @"power"}];
    [options addObject:@{@"title": localize(@"Reconnect account", nil), @"icon": @"arrow.clockwise"}];
    [options addObject:@{@"title": localize(@"Disconnect", nil), @"icon": @"xmark.circle", @"destructive": @YES}];
    [AppSheet showOptionsWithTitle:destination.displayName message:destination.detailText options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        if (index == 0) {
            [destination setEnabled:YES];
            [self runBackup];
        } else if (index == 1) {
            [destination setEnabled:!destination.enabled];
            [self reload];
        } else if (index == 2) {
            [BackupOAuth.shared disconnectProvider:provider];
            [self authorizeProvider:provider destination:destination];
        } else if (index == 3) {
            [BackupOAuth.shared disconnectProvider:provider];
            if (provider == BackupOAuthProviderGoogleDrive) setPrefObject(@"backup.gdrive_folderID", @"");
            [destination setEnabled:NO];
            [self reload];
        }
    }];
}

- (void)authorizeProvider:(BackupOAuthProvider)provider destination:(id<BackupDestination>)destination {
    [BackupOAuth.shared authorizeProvider:provider presenting:self completion:^(NSError *error) {
        if (error) {
            BOOL cancelled = [error.domain isEqualToString:@"WitchBackupOAuthErrorDomain"] && error.code == 4;
            if (!cancelled) {
                [ErrorPresenter showError:destination.displayName message:error.localizedDescription];
            }
            return;
        }
        if (provider == BackupOAuthProviderGoogleDrive) setPrefObject(@"backup.gdrive_folderID", @"");
        [destination setEnabled:YES];
        [self reload];
        [ErrorPresenter showToast:[NSString stringWithFormat:localize(@"%@ connected", nil), destination.displayName] success:YES];
    }];
}

@end
