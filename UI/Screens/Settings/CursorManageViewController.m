#import "CursorManageViewController.h"
#import "CursorHitboxEditorViewController.h"
#import "CursorManager.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import "LauncherPreferences.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AmethystBlurView.h"

@interface CursorManageViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *cursorNames;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, assign) BOOL isImporting;

@end

@implementation CursorManageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    self.navigationItem.title = @"Mouse Cursors";

    _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showImportOptions)];
    self.navigationItem.rightBarButtonItem = _addButton;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self reloadCursors];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadCursors];
}

- (void)reloadCursors {
    _cursorNames = [CursorManager cursorNames];
    [_tableView reloadData];
}

#pragma mark - Import

- (void)showImportOptions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Add Cursor"
                                                                   message:@"Choose an image, GIF, or cursor file"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Photo Library" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openPhotoPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openDocumentPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.barButtonItem = _addButton;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openPhotoPicker {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)openDocumentPicker {
    NSArray *types = @[
        [UTType typeWithFilenameExtension:@"png"],
        [UTType typeWithFilenameExtension:@"jpg"],
        [UTType typeWithFilenameExtension:@"jpeg"],
        [UTType typeWithFilenameExtension:@"gif"],
        [UTType typeWithFilenameExtension:@"webp"],
        [UTType typeWithFilenameExtension:@"cur"],
        [UTType typeWithFilenameExtension:@"ani"],
        [UTType typeWithFilenameExtension:@"ico"],
        [UTType typeWithFilenameExtension:@"bmp"],
        [UTType typeWithFilenameExtension:@"tiff"],
    ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;
    NSString *name = provider.suggestedName ?: @"Cursor";

    if ([provider hasItemConformingToTypeIdentifier:UTTypeGIF.identifier]) {
        [provider loadFileRepresentationForTypeIdentifier:UTTypeGIF.identifier completionHandler:^(NSURL *url, NSError *error) {
            if (error || !url) return;
            [self finishImportAtURL:url name:name];
        }];
        return;
    }

    [provider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
        if (error || !object) return;
        UIImage *image = (UIImage *)object;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishImportImage:image name:name];
        });
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;
    NSURL *url = urls.firstObject;
    NSString *name = url.lastPathComponent.stringByDeletingPathExtension ?: @"Cursor";
    [self finishImportAtURL:url name:name];
}

- (void)finishImportAtURL:(NSURL *)url name:(NSString *)name {
    BOOL access = [url startAccessingSecurityScopedResource];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *cursor = [CursorManager importCursorFromURL:url withName:name error:&error];
        if (access) [url stopAccessingSecurityScopedResource];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isImporting = YES;
            [self handleImportResult:cursor error:error];
        });
    });
}

- (void)finishImportImage:(UIImage *)image name:(NSString *)name {
    NSError *error = nil;
    NSString *cursor = [CursorManager importCursorFromImage:image withName:name error:&error];
    [self handleImportResult:cursor error:error];
}

- (void)handleImportResult:(NSString *)cursor error:(NSError *)error {
    self.isImporting = NO;
    if (!cursor) {
        showDialog(@"Import Failed", error ? error.localizedDescription : @"Unsupported image format");
        return;
    }
    // Auto-select the newly imported cursor
    [CursorManager setCurrentCursorName:cursor];
    [self reloadCursors];
    [self openHitboxEditorForCursor:cursor];
}

#pragma mark - Hitbox editor

- (void)openHitboxEditorForCursor:(NSString *)cursorName {
    CursorHitboxEditorViewController *editor = [[CursorHitboxEditorViewController alloc] init];
    editor.cursorName = cursorName;
    [self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _cursorNames.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 72;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CursorCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CursorCell"];
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.tag = 100;
        icon.backgroundColor = UIColor.blackColor;
        icon.layer.cornerRadius = 6;
        icon.clipsToBounds = YES;
        cell.accessoryView = icon;
    }

    NSString *name = _cursorNames[indexPath.row];
    BOOL isDefault = [CursorManager isDefaultCursor:name];
    BOOL isCurrent = [[CursorManager currentCursorName] isEqualToString:name];

    cell.textLabel.text = isDefault ? @"Default (built-in)" : name;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;

    CGPoint hitbox = [CursorManager hitboxForCursor:name];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Hitbox: (%.0f, %.0f)%@",
                                 hitbox.x, hitbox.y,
                                 isCurrent ? @"  •  In use" : @""];
    cell.detailTextLabel.textColor = isCurrent ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;

    UIImageView *icon = (UIImageView *)cell.accessoryView;
    icon.image = [CursorManager imageForCursor:name];
    icon.layer.borderWidth = isCurrent ? 2 : 0;
    icon.layer.borderColor = ThemeManager.shared.accentColor.CGColor;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *name = _cursorNames[indexPath.row];
    [HapticManager.shared play:HapticTypeLight];
    [CursorManager setCurrentCursorName:name];
    [tableView reloadData];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = _cursorNames[indexPath.row];
    BOOL isDefault = [CursorManager isDefaultCursor:name];

    UIContextualAction *editHitbox = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:@"Hitbox"
                                                                            handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        completionHandler(YES);
        [self openHitboxEditorForCursor:name];
    }];
    editHitbox.backgroundColor = ThemeManager.shared.accentColor;

    NSMutableArray *actions = [NSMutableArray arrayWithObject:editHitbox];

    if (!isDefault) {
        UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                             title:@"Delete"
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            [self confirmDeleteCursor:name];
        }];
        [actions addObject:delete];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (void)confirmDeleteCursor:(NSString *)name {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Cursor"
                                                                   message:[NSString stringWithFormat:@"Delete cursor \"%@\"?", name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        BOOL ok = [CursorManager deleteCursor:name];
        if (!ok) {
            showDialog(@"Error", @"Failed to delete cursor.");
            return;
        }
        if ([[CursorManager currentCursorName] isEqualToString:name]) {
            [CursorManager setCurrentCursorName:[CursorManager defaultCursorName]];
        }
        [self reloadCursors];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"The default cursor cannot be deleted. Swipe a cursor left to edit its hitbox or delete it.";
}

@end
