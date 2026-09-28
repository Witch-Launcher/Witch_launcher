#import "RuntimeDownloadViewController.h"
#import "WitchRuntimeService.h"
#import "ThemeManager.h"

@interface RuntimeDownloadViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *table;
@property (nonatomic) NSArray *items;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *headerLabel;
@end

@implementation RuntimeDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.onboardingMode ? @"Tải Runtime (bản Simple)" : @"Quản lý Runtime";
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;

    _headerLabel = [[UILabel alloc] init];
    _headerLabel.numberOfLines = 0;
    _headerLabel.font = [UIFont systemFontOfSize:13];
    _headerLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _headerLabel.text = @"Bản Simple không kèm runtime. Chọn file cần tải (chữ [quan trọng] nên tải). Tải xong cài luôn không cần khởi động lại. Có thể mở lại bảng này trong Settings.";
    _headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_headerLabel];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table.delegate = self;
    _table.dataSource = self;
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_table];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];

    if (self.onboardingMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Bỏ qua" style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    }
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    self.navigationItem.leftBarButtonItem = self.onboardingMode ? nil : refresh;
    if (self.onboardingMode) {
        self.navigationItem.leftBarButtonItem = refresh;
    }

    [NSLayoutConstraint activateConstraints:@[
        [_headerLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_headerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_headerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_table.topAnchor constraintEqualToAnchor:_headerLabel.bottomAnchor constant:8],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:@"WitchRuntimesDidChange" object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)reload {
    [_spinner startAnimating];
    [WitchRuntimeService.shared refreshStatuses:^(NSArray *items, NSError *error) {
        [self->_spinner stopAnimating];
        self.items = items;
        [self.table reloadData];
        if (error) {
            self->_headerLabel.text = [NSString stringWithFormat:@"Không tải được manifest (dùng trạng thái local). Lỗi: %@\nManifest: %@", error.localizedDescription, WitchRuntimeService.shared.manifestURL];
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *rid = @"rt";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:rid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid];
    WitchRuntimeItem *it = self.items[ip.row];
    NSString *badge = it.important ? @" [quan trọng]" : @"";
    cell.textLabel.text = [it.displayName stringByAppendingString:badge];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    NSString *state = it.installed ? [NSString stringWithFormat:@"Đã cài (%@)", it.localVersion] : @"Chưa cài";
    if (it.updateAvailable) state = [state stringByAppendingFormat:@" • Có update (%@)", it.remoteVersion];
    else if (!it.installed && it.remoteVersion) state = [state stringByAppendingFormat:@" • mới: %@", it.remoteVersion];
    cell.detailTextLabel.text = state;
    cell.detailTextLabel.textColor = it.important && !it.installed ? [UIColor systemRedColor] : ThemeManager.shared.secondaryTextColor;
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WitchRuntimeItem *it = self.items[ip.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:it.displayName message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tải / Cập nhật" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self doDownload:it];
    }]];
    if (it.installed) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self doDelete:it];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doDownload:(WitchRuntimeItem *)it {
    UIAlertController *prog = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Đang tải %@", it.displayName] message:@"..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:prog animated:YES completion:nil];
    [WitchRuntimeService.shared downloadItem:it progress:^(float p) {
        dispatch_async(dispatch_get_main_queue(), ^{ prog.message = [NSString stringWithFormat:@"%.0f%%", p*100]; });
    } completion:^(BOOL ok, NSError *error) {
        [prog dismissViewControllerAnimated:YES completion:^{
            NSString *msg = ok ? @"Đã tải xong và ghi nhận (JDK cần giải nén .tar.xz trong Manage Runtime nếu chưa tự bung; LWJGL đã ghi marker, không cần restart)." : [NSString stringWithFormat:@"Thất bại: %@", error.localizedDescription];
            UIAlertController *done = [UIAlertController alertControllerWithTitle:it.displayName message:msg preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:done animated:YES completion:nil];
            [self reload];
        }];
    }];
}

- (void)doDelete:(WitchRuntimeItem *)it {
    NSError *e = nil;
    BOOL ok = [WitchRuntimeService.shared deleteItem:it error:&e];
    NSString *msg = ok ? @"Đã xóa." : [NSString stringWithFormat:@"Không xóa được: %@", e.localizedDescription];
    UIAlertController *done = [UIAlertController alertControllerWithTitle:it.displayName message:msg preferredStyle:UIAlertControllerStyleAlert];
    [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:done animated:YES completion:nil];
    [self reload];
}

@end
