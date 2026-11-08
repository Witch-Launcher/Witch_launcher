#import "BackupScopeViewController.h"
#import "BackupRecord.h"
#import "ThemeManager.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface BackupScopeViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *options;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@property (nonatomic, copy) NSString *versionPath;
@end

@implementation BackupScopeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"What to back up", nil);
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;

    NSString *version = VersionDirectoryManager.shared.currentVersion;
    self.versionPath = [VersionDirectoryManager.shared versionPathForVersion:version];
    self.options = [BackupScope selectableRootsAtVersionPath:self.versionPath];

    NSArray *saved = getPrefObject(@"backup.scope_paths");
    NSArray *initial = [saved isKindOfClass:[NSArray class]] && saved.count > 0 ? saved : [BackupScope defaultRoots];
    self.selected = [NSMutableSet setWithArray:initial];
    [self.selected intersectSet:[NSSet setWithArray:self.options]];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = 48;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(saveAndClose)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Recommended", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectRecommended)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.options.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return localize(@"Select folders and files", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.options.count == 0) return localize(@"No version folder is installed yet.", nil);
    return localize(@"Only the selected items inside the current version folder are archived. Logs, caches and launcher libraries are always excluded.", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"BackupScopeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
        cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    }
    NSString *name = self.options[indexPath.row];
    cell.textLabel.text = name;
    BOOL on = [self.selected containsObject:name];
    cell.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = ThemeManager.shared.accentColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *name = self.options[indexPath.row];
    if ([self.selected containsObject:name]) {
        [self.selected removeObject:name];
    } else {
        [self.selected addObject:name];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)selectRecommended {
    [self.selected removeAllObjects];
    for (NSString *name in [BackupScope defaultRoots]) {
        if ([self.options containsObject:name]) [self.selected addObject:name];
    }
    [self.tableView reloadData];
}

- (void)saveAndClose {
    if (self.selected.count == 0) {
        [ErrorPresenter showValidation:localize(@"Nothing selected", nil) message:localize(@"Select at least one folder or file.", nil)];
        return;
    }
    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    for (NSString *name in self.options) {
        if ([self.selected containsObject:name]) [ordered addObject:name];
    }
    setPrefObject(@"backup.scope_paths", ordered);
    [self.navigationController popViewControllerAnimated:YES];
}

@end
