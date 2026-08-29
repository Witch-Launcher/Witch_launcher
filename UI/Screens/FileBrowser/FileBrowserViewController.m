#import "FileBrowserViewController.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AmethystBlurView.h"
#import "utils.h"

@interface FileBrowserViewController ()
@property (nonatomic) UILabel *pathLabel;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UIButton *addFileBtn;
@property (nonatomic) UIButton *addFolderBtn;
@property (nonatomic) UIButton *pasteBtn;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSMutableArray<NSString *> *pathStack;
@property (nonatomic) NSString *clipboardPath;
@property (nonatomic) BOOL isCutOperation;
@end

@implementation FileBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"File Manager", nil);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissFileBrowser)];
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;

    if (!_rootPath) {
        NSString *gameDir = [NSString stringWithUTF8String:getenv("POJAV_GAME_DIR") ?: ""];
        if (gameDir.length == 0) {
            gameDir = [NSString stringWithUTF8String:getenv("POJAV_HOME") ?: ""];
        }
        if (gameDir.length == 0) {
            gameDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        }
        _rootPath = gameDir;
    }

    _pathStack = [NSMutableArray arrayWithObject:_rootPath];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [self loadItems];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)setup {
    UIView *topBar = [[UIView alloc] init];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    topBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    topBar.layer.cornerRadius = 8;
    topBar.clipsToBounds = YES;
    [self.view addSubview:topBar];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [backBtn setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    backBtn.tintColor = ThemeManager.shared.accentColor;
    [backBtn addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:backBtn];

    _pathLabel = [[UILabel alloc] init];
    _pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _pathLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _pathLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _pathLabel.numberOfLines = 2;
    _pathLabel.text = _rootPath;
    [topBar addSubview:_pathLabel];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [_tableView addGestureRecognizer:longPress];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = localize(@"filebrowser.empty", nil);
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 52;
    [self.view addSubview:_tableView];

    UIView *bottomBar = [[UIView alloc] init];
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    bottomBar.layer.cornerRadius = 8;
    bottomBar.clipsToBounds = YES;
    [self.view addSubview:bottomBar];

    _addFileBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _addFileBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_addFileBtn setImage:[UIImage systemImageNamed:@"doc.badge.plus"] forState:UIControlStateNormal];
    [_addFileBtn setTitle:localize(@"Add File", nil) forState:UIControlStateNormal];
    _addFileBtn.tintColor = ThemeManager.shared.accentColor;
    _addFileBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [_addFileBtn addTarget:self action:@selector(addFileTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:_addFileBtn];

    _addFolderBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _addFolderBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_addFolderBtn setImage:[UIImage systemImageNamed:@"folder.badge.plus"] forState:UIControlStateNormal];
    [_addFolderBtn setTitle:localize(@"Add Folder", nil) forState:UIControlStateNormal];
    _addFolderBtn.tintColor = ThemeManager.shared.accentColor;
    _addFolderBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [_addFolderBtn addTarget:self action:@selector(addFolderTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:_addFolderBtn];

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = ThemeManager.shared.separatorColor;
    [bottomBar addSubview:separator];

    _pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _pasteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_pasteBtn setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    [_pasteBtn setTitle:localize(@"Paste", nil) forState:UIControlStateNormal];
    _pasteBtn.tintColor = ThemeManager.shared.accentColor;
    _pasteBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _pasteBtn.hidden = YES;
    [_pasteBtn addTarget:self action:@selector(pasteTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:_pasteBtn];

    UIView *separator2 = [[UIView alloc] init];
    separator2.translatesAutoresizingMaskIntoConstraints = NO;
    separator2.backgroundColor = ThemeManager.shared.separatorColor;
    [bottomBar addSubview:separator2];

    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [topBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [topBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [topBar.heightAnchor constraintEqualToConstant:44],

        [backBtn.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:8],
        [backBtn.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [backBtn.widthAnchor constraintEqualToConstant:28],

        [_pathLabel.leadingAnchor constraintEqualToAnchor:backBtn.trailingAnchor constant:4],
        [_pathLabel.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-8],
        [_pathLabel.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:topBar.bottomAnchor constant:8],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_tableView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-8],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [bottomBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [bottomBar.heightAnchor constraintEqualToConstant:44],

        [_addFileBtn.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:12],
        [_addFileBtn.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],

        [separator.leadingAnchor constraintEqualToAnchor:_addFileBtn.trailingAnchor constant:12],
        [separator.widthAnchor constraintEqualToConstant:1],
        [separator.heightAnchor constraintEqualToConstant:24],
        [separator.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],

        [_addFolderBtn.leadingAnchor constraintEqualToAnchor:separator.trailingAnchor constant:12],
        [_addFolderBtn.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],

        [separator2.leadingAnchor constraintEqualToAnchor:_addFolderBtn.trailingAnchor constant:12],
        [separator2.widthAnchor constraintEqualToConstant:1],
        [separator2.heightAnchor constraintEqualToConstant:24],
        [separator2.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],

        [_pasteBtn.leadingAnchor constraintEqualToAnchor:separator2.trailingAnchor constant:12],
        [_pasteBtn.centerYAnchor constraintEqualToAnchor:bottomBar.centerYAnchor],
    ]];
}

- (void)updateColors {
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;
}

- (void)loadItems {
    NSString *currentPath = _pathStack.lastObject;
    _pathLabel.text = currentPath;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:currentPath error:nil];
    NSMutableArray *dirs = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];

    for (NSString *name in contents) {
        NSString *fullPath = [currentPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) {
            [dirs addObject:@{@"name": name, @"path": fullPath, @"isDir": @YES}];
        } else {
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
            [files addObject:@{@"name": name, @"path": fullPath, @"isDir": @NO,
                               @"size": attrs[NSFileSize] ?: @0,
                               @"date": attrs[NSFileModificationDate] ?: @""}];
        }
    }

    [dirs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];
    [files sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];

    _items = [NSMutableArray array];
    [_items addObjectsFromArray:dirs];
    [_items addObjectsFromArray:files];

    _emptyLabel.hidden = _items.count > 0;
    _tableView.hidden = _items.count == 0;
    [_tableView reloadData];
}

- (void)goBack {
    if (_pathStack.count <= 1) return;
    [_pathStack removeLastObject];
    [self loadItems];
}

- (void)addFileTapped {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)addFolderTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"New Folder", nil)
                                                                    message:localize(@"Enter folder name:", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = localize(@"filebrowser.folder_name.placeholder", nil);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Create", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields[0].text;
        if (name.length == 0) return;
        NSString *currentPath = _pathStack.lastObject;
        NSString *newPath = [currentPath stringByAppendingPathComponent:name];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:NO attributes:nil error:&error];
        if (error) {
            showDialog(localize(@"Error", nil), error.localizedDescription);
        } else {
            [self loadItems];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *currentPath = _pathStack.lastObject;
    for (NSURL *url in urls) {
        NSString *destPath = [currentPath stringByAppendingPathComponent:url.lastPathComponent];
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&error];
        if (error) {
            showDialog(localize(@"Import Error", nil), [NSString stringWithFormat:@"%@: %@", url.lastPathComponent, error.localizedDescription]);
        }
    }
    [self loadItems];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"FileCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.layer.cornerRadius = 6;
        cell.clipsToBounds = YES;
    }

    NSDictionary *item = _items[indexPath.row];
    BOOL isDir = [item[@"isDir"] boolValue];
    cell.textLabel.text = item[@"name"];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:isDir ? UIFontWeightSemibold : UIFontWeightRegular];

    if (isDir) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
        cell.detailTextLabel.text = nil;
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"doc"];
        NSNumber *size = item[@"size"];
        NSString *sizeStr = [self formatSize:size.unsignedLongLongValue];
        cell.detailTextLabel.text = sizeStr;
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    }
    cell.imageView.tintColor = isDir ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;

    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
    if (!indexPath) return;
    [HapticManager.shared play:HapticTypeLight];
    [self showActionSheetForItem:_items[indexPath.row]];
}

- (void)showActionSheetForItem:(NSDictionary *)item {
    NSString *name = item[@"name"];
    NSString *fullPath = item[@"path"];
    BOOL isDir = [item[@"isDir"] boolValue];

    NSString *message;
    if (isDir) {
        message = [NSString stringWithFormat:@"Folder\nPath: %@", fullPath];
    } else {
        NSNumber *size = item[@"size"];
        NSString *sizeStr = [self formatSize:size.unsignedLongLongValue];
        NSDate *date = item[@"date"];
        NSString *dateStr = date ? [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle] : @"Unknown";
        message = [NSString stringWithFormat:@"Size: %@\nModified: %@\nPath: %@", sizeStr, dateStr, fullPath];
    }

    UIAlertController *info = [UIAlertController alertControllerWithTitle:name
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [info addAction:[UIAlertAction actionWithTitle:@"Copy Path" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = fullPath;
    }]];
    [info addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.clipboardPath = fullPath;
        self.isCutOperation = NO;
        self.pasteBtn.hidden = NO;
    }]];
    [info addAction:[UIAlertAction actionWithTitle:@"Cut" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.clipboardPath = fullPath;
        self.isCutOperation = YES;
        self.pasteBtn.hidden = NO;
    }]];
    [info addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *delError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&delError];
        if (delError) {
            showDialog(@"Error", delError.localizedDescription);
        } else {
            [self loadItems];
        }
    }]];
    if (isDir) {
        [info addAction:[UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [_pathStack addObject:fullPath];
            [self loadItems];
        }]];
    }
    [info addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:info animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];

    NSDictionary *item = _items[indexPath.row];
    BOOL isDir = [item[@"isDir"] boolValue];
    if (isDir) {
        [_pathStack addObject:item[@"path"]];
        [self loadItems];
    } else {
        [self showActionSheetForItem:item];
    }
}

- (void)pasteTapped {
    if (!_clipboardPath || ![[NSFileManager defaultManager] fileExistsAtPath:_clipboardPath]) {
        showDialog(@"Error", @"Source file no longer exists.");
        _clipboardPath = nil;
        _pasteBtn.hidden = YES;
        return;
    }
    NSString *currentPath = _pathStack.lastObject;
    NSString *fileName = _clipboardPath.lastPathComponent;
    NSString *destPath = [currentPath stringByAppendingPathComponent:fileName];

    // Avoid overwrite: append number if exists
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destPath]) {
        NSString *baseName = fileName.stringByDeletingPathExtension;
        NSString *ext = fileName.pathExtension;
        int counter = 1;
        do {
            NSString *newName = ext.length > 0
                ? [NSString stringWithFormat:@"%@_%d.%@", baseName, counter, ext]
                : [NSString stringWithFormat:@"%@_%d", baseName, counter];
            destPath = [currentPath stringByAppendingPathComponent:newName];
            counter++;
        } while ([fm fileExistsAtPath:destPath]);
    }

    NSError *error = nil;
    if (_isCutOperation) {
        [fm moveItemAtPath:_clipboardPath toPath:destPath error:&error];
    } else {
        [fm copyItemAtPath:_clipboardPath toPath:destPath error:&error];
    }
    if (error) {
        showDialog(@"Error", error.localizedDescription);
    } else {
        if (_isCutOperation) {
            _clipboardPath = nil;
            _pasteBtn.hidden = YES;
        }
        [self loadItems];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *item = _items[indexPath.row];
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:item[@"path"] error:&error];
        if (error) {
            showDialog(@"Error", error.localizedDescription);
        } else {
            [_items removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            if (_items.count == 0) [self loadItems];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _items[indexPath.row];
    return [item[@"isDir"] boolValue] ? 44 : 52;
}

#pragma mark - Dismiss

- (void)dismissFileBrowser {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (NSString *)formatSize:(unsigned long long)bytes {
    if (bytes >= 1073741824) return [NSString stringWithFormat:@"%.2f GB", bytes / 1073741824.0];
    if (bytes >= 1048576) return [NSString stringWithFormat:@"%.1f MB", bytes / 1048576.0];
    if (bytes >= 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes == 0) return @"Empty";
    return [NSString stringWithFormat:@"%llu B", bytes];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
