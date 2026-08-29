#import "CursorTypeManageViewController.h"
#import "CursorTypeManager.h"
#import "CursorManager.h"
#import "CursorHitboxEditorViewController.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CursorTypeManageViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *cursorTypes;
@property (nonatomic, strong) NSArray<NSString *> *cursorNames;
@property (nonatomic, copy) NSString *editingTypeId;
@property (nonatomic, strong) UIBarButtonItem *addButton;

@end

@implementation CursorTypeManageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    self.navigationItem.title = @"Cursor Types";

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

    [self reloadData];
    [AmethystBlurView installInView:self.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    _cursorTypes = [CursorTypeManager allCursorTypes];
    _cursorNames = [CursorManager cursorNames];
    [_tableView reloadData];
}

#pragma mark - Import

- (void)showImportOptions {
    [HapticManager.shared play:HapticTypeLight];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"cursor.manage.import_title", nil)
                                                                   message:localize(@"cursor.manage.import_message", nil)
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.photo_library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openPhotoPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.files", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openDocumentPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

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
            if (cursor) {
                [self reloadData];
                [self openHitboxEditorForCursor:cursor];
            } else {
                showDialog(@"Import Failed", error ? error.localizedDescription : @"Unsupported image format");
            }
        });
    });
}

- (void)finishImportImage:(UIImage *)image name:(NSString *)name {
    NSError *error = nil;
    NSString *cursor = [CursorManager importCursorFromImage:image withName:name error:&error];
    if (cursor) {
        [self reloadData];
        [self openHitboxEditorForCursor:cursor];
    } else {
        showDialog(@"Import Failed", error ? error.localizedDescription : @"Unsupported image format");
    }
}

#pragma mark - Hitbox editor

- (void)openHitboxEditorForCursor:(NSString *)cursorName {
    CursorHitboxEditorViewController *editor = [[CursorHitboxEditorViewController alloc] init];
    editor.cursorName = cursorName;
    [self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - Cursor type detail

- (void)openDetailForType:(NSString *)typeId {
    self.editingTypeId = typeId;

    NSDictionary *typeDef = nil;
    for (NSDictionary *t in _cursorTypes) {
        if ([t[kCursorTypeId] isEqualToString:typeId]) {
            typeDef = t;
            break;
        }
    }
    if (!typeDef) return;

    NSString *currentCursor = [CursorManager currentCursorName];
    BOOL isEnabled = [CursorTypeManager isEnabledForType:typeId];

UIAlertController *alert = [UIAlertController alertControllerWithTitle:typeDef[kCursorTypeName]
                                                                   message:typeDef[kCursorTypeDescription]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // Toggle enable/disable (cannot disable "normal")
    if (![typeId isEqualToString:@"normal"]) {
        NSString *toggleTitle = isEnabled ? localize(@"Disable", nil) : localize(@"Enable", nil);
        [alert addAction:[UIAlertAction actionWithTitle:toggleTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [CursorTypeManager setEnabled:!isEnabled forType:typeId];
            [self reloadData];
        }]];
    }

    // Section: Choose cursor
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.choose_cursor", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showCursorPickerForType:typeId];
    }]];

    // Section: Set to default
    if (![[CursorTypeManager cursorForType:typeId] isEqualToString:[CursorManager defaultCursorName]]) {
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.reset_default", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [CursorTypeManager setCursor:[CursorManager defaultCursorName] forType:typeId];
            [self reloadData];
        }]];
    }

    // Section: Import new
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.import_new", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showImportOptions];
    }]];

    // Edit hitbox for assigned cursor
    NSString *assignedCursor = [CursorTypeManager cursorForType:typeId];
    if (![CursorManager isDefaultCursor:assignedCursor]) {
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.manage.edit_hitbox", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self openHitboxEditorForCursor:assignedCursor];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 0, 0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCursorPickerForType:(NSString *)typeId {
    NSString *currentCursor = [CursorTypeManager cursorForType:typeId];

UIAlertController *picker = [UIAlertController alertControllerWithTitle:localize(@"cursor.manage.select_title", nil)
                                                                    message:localize(@"cursor.manage.select_message", nil)
                                                             preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *cursorName in _cursorNames) {
        BOOL isCurrent = [cursorName isEqualToString:currentCursor];
        NSString *title = [CursorManager isDefaultCursor:cursorName] ? localize(@"cursor.detail.default_builtin", nil) : cursorName;
        if (isCurrent) {
            title = [title stringByAppendingString:@"  ✓"];
        }

        [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [CursorTypeManager setCursor:cursorName forType:typeId];
            [self reloadData];
        }]];
    }

    [picker addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = self.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 0, 0);
    }
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Section 0: Cursor Types, Section 1: Imported Cursors
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return _cursorTypes.count;
    return _cursorNames.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CursorTypeCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CursorTypeCell"];
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    }

    if (indexPath.section == 0) {
        // Cursor type row
        NSDictionary *typeDef = _cursorTypes[indexPath.row];
        NSString *typeId = typeDef[kCursorTypeId];
        BOOL isEnabled = [CursorTypeManager isEnabledForType:typeId];
        NSString *assignedCursor = [CursorTypeManager cursorForType:typeId];
        BOOL isActive = [[CursorTypeManager currentActiveTypeId] isEqualToString:typeId];

        cell.textLabel.text = [NSString stringWithFormat:@"%@  %@", typeDef[kCursorTypeIcon], typeDef[kCursorTypeName]];
        cell.textLabel.textColor = isActive ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;

        NSString *cursorDisplayName = [CursorManager isDefaultCursor:assignedCursor] ? @"Default" : assignedCursor;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Cursor: %@%@", cursorDisplayName, isActive ? @"  (active)" : @""];
        cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;

        // Toggle switch for enable/disable
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = isEnabled;
        toggle.tag = indexPath.row;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];

        if ([typeId isEqualToString:@"normal"]) {
            toggle.on = YES;
            toggle.enabled = NO; // Cannot disable normal cursor
        }

        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    } else {
        // Imported cursor row
        NSString *cursorName = _cursorNames[indexPath.row];
        BOOL isDefault = [CursorManager isDefaultCursor:cursorName];
        BOOL isUsed = NO;
        for (NSDictionary *typeDef in _cursorTypes) {
            if ([[CursorTypeManager cursorForType:typeDef[kCursorTypeId]] isEqualToString:cursorName]) {
                isUsed = YES;
                break;
            }
        }

        cell.textLabel.text = isDefault ? localize(@"cursor.detail.default_builtin", nil) : cursorName;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;

        CGPoint hitbox = [CursorManager hitboxForCursor:cursorName];
        cell.detailTextLabel.text = [NSString stringWithFormat:localize(@"cursor.detail.hitbox_format", nil),
                                     hitbox.x, hitbox.y,
                                     isUsed ? localize(@"In use", nil) : @""];
        cell.detailTextLabel.textColor = isUsed ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;

        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];

    if (indexPath.section == 0) {
        NSString *typeId = _cursorTypes[indexPath.row][kCursorTypeId];
        [self openDetailForType:typeId];
    } else {
        NSString *cursorName = _cursorNames[indexPath.row];
        if (![CursorManager isDefaultCursor:cursorName]) {
            [self openHitboxEditorForCursor:cursorName];
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        NSString *cursorName = _cursorNames[indexPath.row];
        BOOL isDefault = [CursorManager isDefaultCursor:cursorName];

        if (isDefault) return nil;

        UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                          title:@"Delete"
                                                                        handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            [self confirmDeleteCursor:cursorName];
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
    }
    return nil;
}

- (void)confirmDeleteCursor:(NSString *)name {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Cursor"
                                                                  message:[NSString stringWithFormat:@"Delete cursor \"%@\"?", name]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // Reset any type using this cursor to default
        for (NSDictionary *typeDef in self.cursorTypes) {
            if ([[CursorTypeManager cursorForType:typeDef[kCursorTypeId]] isEqualToString:name]) {
                [CursorTypeManager setCursor:[CursorManager defaultCursorName] forType:typeDef[kCursorTypeId]];
            }
        }
        [CursorManager deleteCursor:name];
        [self reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSInteger row = sender.tag;
    NSString *typeId = _cursorTypes[row][kCursorTypeId];
    [HapticManager.shared play:HapticTypeLight];
    [CursorTypeManager setEnabled:sender.isOn forType:typeId];
    [_tableView reloadData];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Cursor Types (enable/disable & customize)";
    return @"Imported Cursors";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Enable cursor types to have the virtual cursor switch automatically when the game requests a different cursor. The Normal Select cursor is always enabled.";
    return @"Swipe left to delete. Tap to edit hitbox. Import new cursors with the + button.";
}

@end
