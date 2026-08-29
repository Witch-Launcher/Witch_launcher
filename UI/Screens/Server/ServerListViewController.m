#import "ServerListViewController.h"
#import "ThemeManager.h"
#import "CustomButton.h"
#import "MainCoordinator.h"
#import "HapticManager.h"
#import "utils.h"

@interface ServerListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSMutableArray *servers;
@property (nonatomic) UIButton *addButton;
@end

static NSString *kServersFilePath;

@implementation ServerListViewController

+ (void)initialize {
    if (self == [ServerListViewController self]) {
        NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        kServersFilePath = [docDir stringByAppendingPathComponent:@"servers.json"];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [self loadServers];
}

- (void)setup {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.text = localize(@"server.add.title", nil);
    [self.view addSubview:_titleLabel];

    _addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_addButton setTitle:localize(@"server.connect", nil) forState:UIControlStateNormal];
    _addButton.backgroundColor = [UIColor clearColor];
    _addButton.tintColor = ThemeManager.shared.accentColor;
    [_addButton addTarget:self action:@selector(addServerTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_addButton];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 64;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ServerCell"];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [_addButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_addButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_addButton.heightAnchor constraintEqualToConstant:36],

        [_tableView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:12],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _titleLabel.textColor = theme.primaryTextColor;
    _addButton.tintColor = theme.accentColor;
}

- (void)loadServers {
    NSData *data = [NSData dataWithContentsOfFile:kServersFilePath];
    if (data) {
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        _servers = [NSMutableArray arrayWithArray:arr ?: @[]];
    } else {
        _servers = [NSMutableArray array];
    }
    [_tableView reloadData];
}

- (void)saveServers {
    NSData *data = [NSJSONSerialization dataWithJSONObject:_servers options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:kServersFilePath atomically:YES];
}

- (void)addServerTapped {
    [HapticManager.shared play:HapticTypeLight];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"server.add.title", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = localize(@"server.name.placeholder", nil);
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = localize(@"server.address.placeholder", nil);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"server.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"server.connect", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields[0].text;
        NSString *address = alert.textFields[1].text;
        if (name.length > 0 && address.length > 0) {
            [self.servers addObject:@{@"name": name, @"address": address}];
            [self.tableView reloadData];
            [self saveServers];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _servers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ServerCell" forIndexPath:indexPath];
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.layer.cornerRadius = 8;
    cell.clipsToBounds = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSDictionary *server = _servers[indexPath.row];
    cell.textLabel.text = server[@"name"];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = server[@"address"];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.imageView.image = [UIImage systemImageNamed:@"globe"];
    cell.imageView.tintColor = ThemeManager.shared.accentColor;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.coordinator) {
        [self.coordinator launchWithServer:_servers[indexPath.row]];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_servers removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self saveServers];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
