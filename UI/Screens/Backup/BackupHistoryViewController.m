#import "BackupHistoryViewController.h"
#import "BackupSettingsViewController.h"
#import "BackupManager.h"
#import "BackupConfig.h"
#import "BackupDestinations.h"
#import "ThemeManager.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "DownloadProgressOverlay.h"
#import "utils.h"

static NSString *formatterDate(NSDate *date);

@interface BackupHistoryViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<BackupRecord *> *records;
@property (nonatomic, strong) DownloadProgressOverlay *overlay;
@end

@implementation BackupHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"Backup history", nil);
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = localize(@"No backups yet.\nUse “Back up now” to create one.", nil);
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    self.tableView.backgroundView = self.emptyLabel;

    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    UIBarButtonItem *backup = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] style:UIBarButtonItemStylePlain target:self action:@selector(backupNow)];
    self.navigationItem.rightBarButtonItems = @[settings, backup];
    if (self.presentingViewController && self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Close", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:BackupDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)closeTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)openSettings {
    [self.navigationController pushViewController:[[BackupSettingsViewController alloc] init] animated:YES];
}

- (void)reload {
    self.records = [BackupManager shared].records;
    self.emptyLabel.hidden = self.records.count > 0;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.records.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.records.count == 0) return nil;
    return [NSString stringWithFormat:localize(@"%lu backups", nil), (unsigned long)self.records.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"BackupHistoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
        cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
        cell.detailTextLabel.numberOfLines = 2;
    }
    BackupRecord *record = self.records[indexPath.row];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", [record reasonTitle], [formatter stringFromDate:record.createdAt]];
    NSString *local = record.localPath.length > 0 ? localize(@"Local", nil) : localize(@"Cloud", nil);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ • %@ • %@", record.version ?: @"", [BackupConfig humanSize:record.size], record.destinationSummary, local];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    BackupRecord *record = self.records[indexPath.row];
    NSMutableArray *options = [NSMutableArray array];
    [options addObject:@{@"title": localize(@"Restore", nil), @"subtitle": localize(@"Merge or overwrite the current world data", nil), @"icon": @"arrow.down.circle"}];
    if (record.localPath.length > 0) {
        [options addObject:@{@"title": localize(@"Upload to cloud", nil), @"icon": @"icloud.and.arrow.up"}];
    }
    [options addObject:@{@"title": localize(@"Delete", nil), @"icon": @"trash", @"destructive": @YES}];
    [AppSheet showOptionsWithTitle:[record reasonTitle] message:[NSString stringWithFormat:@"%@ · %@", formatterDate(record.createdAt), [BackupConfig humanSize:record.size]] options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        if (index == 0) {
            [self chooseRestoreMode:record];
        } else if (record.localPath.length > 0 && index == 1) {
            [self chooseUploadDestination:record];
        } else {
            [self confirmDelete:record];
        }
    }];
}

static NSString *formatterDate(NSDate *date) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

#pragma mark - Restore

- (void)chooseRestoreMode:(BackupRecord *)record {
    NSArray *options = @[
        @{@"title": localize(@"Merge", nil), @"subtitle": localize(@"Keep existing files and add the backup", nil), @"icon": @"arrow.triangle.merge"},
        @{@"title": localize(@"Overwrite", nil), @"subtitle": localize(@"Replace the selected folders with the backup", nil), @"icon": @"arrow.down.doc", @"destructive": @NO},
    ];
    [AppSheet showOptionsWithTitle:localize(@"Restore backup", nil) message:localize(@"Close Minecraft before restoring.", nil) options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        [self performRestore:record overwrite:index == 1];
    }];
}

- (void)performRestore:(BackupRecord *)record overwrite:(BOOL)overwrite {
    if (self.overlay) return;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showBlurredInView:self.navigationController.view ?: self.view title:localize(@"Restoring...", nil) blurred:YES];
    self.overlay = overlay;
    [overlay updateProgress:0.02 message:localize(@"Preparing restore", nil)];
    [[BackupManager shared] restoreRecord:record overwrite:overwrite progress:^(double fraction, NSString *message) {
        [overlay updateProgress:(float)fraction message:message];
    } completion:^(NSError *error) {
        [overlay updateProgress:1.0 message:error ? localize(@"Restore failed", nil) : localize(@"Restore complete", nil)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [overlay dismiss];
            self.overlay = nil;
            if (error) {
                [ErrorPresenter showError:localize(@"Restore", nil) message:error.localizedDescription];
            } else {
                [ErrorPresenter showToast:localize(@"Backup restored", nil) success:YES];
            }
            [self reload];
        });
    }];
}

#pragma mark - Upload

- (void)chooseUploadDestination:(BackupRecord *)record {
    NSArray<id<BackupDestination>> *destinations = [BackupManager shared].destinations;
    NSMutableArray *configured = [NSMutableArray array];
    NSMutableArray *options = [NSMutableArray array];
    for (id<BackupDestination> destination in destinations) {
        if (!destination.configured) continue;
        [configured addObject:destination];
        [options addObject:@{@"title": destination.displayName, @"subtitle": destination.detailText, @"icon": @"icloud.and.arrow.up"}];
    }
    if (options.count == 0) {
        [ErrorPresenter showWarning:localize(@"No destination", nil) message:localize(@"Connect a cloud destination first.", nil)];
        return;
    }
    [AppSheet showOptionsWithTitle:localize(@"Upload to cloud", nil) message:record.fileName options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        id<BackupDestination> destination = configured[index];
        [self performUpload:record destination:destination];
    }];
}

- (void)performUpload:(BackupRecord *)record destination:(id<BackupDestination>)destination {
    if (self.overlay) return;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showBlurredInView:self.navigationController.view ?: self.view title:[NSString stringWithFormat:localize(@"Uploading to %@...", nil), destination.displayName] blurred:YES];
    self.overlay = overlay;
    [overlay updateProgress:0.3 message:record.fileName];
    [[BackupManager shared] uploadRecord:record toDestinationIdentifier:destination.identifier completion:^(NSError *error) {
        [overlay updateProgress:1.0 message:error ? localize(@"Upload failed", nil) : localize(@"Upload complete", nil)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [overlay dismiss];
            self.overlay = nil;
            if (error) {
                [ErrorPresenter showError:destination.displayName message:error.localizedDescription];
            } else {
                [ErrorPresenter showToast:[NSString stringWithFormat:localize(@"Uploaded to %@", nil), destination.displayName] success:YES];
            }
            [self reload];
        });
    }];
}

#pragma mark - Delete

- (void)confirmDelete:(BackupRecord *)record {
    NSMutableArray *options = [NSMutableArray array];
    NSMutableArray<NSString *> *actions = [NSMutableArray array];
    if (record.localPath.length > 0) {
        [options addObject:@{@"title": localize(@"Delete from this device", nil), @"subtitle": localize(@"Keep cloud copies", nil), @"icon": @"iphone", @"destructive": @YES}];
        [actions addObject:@"local"];
    }
    if (record.hasRemoteCopy) {
        [options addObject:@{@"title": localize(@"Delete everywhere", nil), @"subtitle": localize(@"Remove local and cloud copies", nil), @"icon": @"trash", @"destructive": @YES}];
        [actions addObject:@"remote"];
    }
    [AppSheet showOptionsWithTitle:localize(@"Delete backup?", nil) message:record.fileName options:options selectedIndex:NSNotFound selection:^(NSInteger index) {
        if (index < 0 || index >= (NSInteger)actions.count) return;
        BOOL deleteRemote = [actions[index] isEqualToString:@"remote"];
        [[BackupManager shared] deleteRecord:record deleteRemote:deleteRemote completion:^(NSError *error) {
            if (error) {
                [ErrorPresenter showError:localize(@"Delete", nil) message:error.localizedDescription];
            } else {
                [ErrorPresenter showToast:localize(@"Backup deleted", nil) success:YES];
            }
            [self reload];
        }];
    }];
}

#pragma mark - Backup now

- (void)backupNow {
    if (self.overlay) return;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showBlurredInView:self.navigationController.view ?: self.view title:localize(@"Backing up...", nil) blurred:YES];
    self.overlay = overlay;
    [overlay updateProgress:0.15 message:localize(@"Compressing game data", nil)];
    [[BackupManager shared] backupNowWithReason:@"manual" completion:^(BackupRecord *record, NSError *error) {
        [overlay updateProgress:1.0 message:error ? localize(@"Finished with errors", nil) : localize(@"Backup complete", nil)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [overlay dismiss];
            self.overlay = nil;
            if (error) {
                [ErrorPresenter showWarning:localize(@"Backup", nil) message:error.localizedDescription];
            } else if (record) {
                [ErrorPresenter showToast:[NSString stringWithFormat:localize(@"Backup saved to %@", nil), record.destinationSummary] success:YES];
            }
            [self reload];
        });
    }];
}

@end
