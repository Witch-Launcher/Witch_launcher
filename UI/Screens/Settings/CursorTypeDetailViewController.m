#import "CursorTypeDetailViewController.h"
#import "CursorHitboxEditorViewController.h"
#import "CursorTypeManager.h"
#import "CursorManager.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CursorTypeDetailViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *cursorNames;
@property (nonatomic, strong) NSDictionary *typeDef;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, assign) BOOL isImporting;

@end

@implementation CursorTypeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;

    _typeDef = nil;
    for (NSDictionary *t in [CursorTypeManager allCursorTypes]) {
        if ([t[kCursorTypeId] isEqualToString:self.typeId]) {
            _typeDef = t;
            break;
        }
    }
    self.navigationItem.title = [CursorTypeManager localizedNameForType:self.typeId];

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
    _cursorNames = [CursorManager cursorNamesForType:self.typeId];
    [_tableView reloadData];
}

#pragma mark - Enable/disable toggle

- (void)enableToggleChanged:(UISwitch *)sender {
    [HapticManager.shared play:HapticTypeLight];
    [CursorTypeManager setEnabled:sender.isOn forType:self.typeId];
    [_tableView reloadData];
}

#pragma mark - Import

- (void)showImportOptions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"cursor.detail.add_cursor", nil)
                                                                   message:localize(@"cursor.detail.choose_image", nil)
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.photo_library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openPhotoPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.files", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
        NSString *cursor = [CursorManager importCursorFromURL:url withName:name forType:self.typeId error:&error];
        if (access) [url stopAccessingSecurityScopedResource];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isImporting = YES;
            if (cursor) {
                [CursorManager setCurrentCursor:cursor forType:self.typeId];
                [self reloadData];
                [self openHitboxEditorForCursor:cursor];
            } else {
                showDialog(localize(@"cursor.detail.import_failed", nil), error ? error.localizedDescription : localize(@"cursor.detail.unsupported_format", nil));
            }
            self.isImporting = NO;
        });
    });
}

- (void)finishImportImage:(UIImage *)image name:(NSString *)name {
    NSError *error = nil;
    NSString *cursor = [CursorManager importCursorFromImage:image withName:name forType:self.typeId error:&error];
    if (cursor) {
        [CursorManager setCurrentCursor:cursor forType:self.typeId];
        [self reloadData];
        [self openHitboxEditorForCursor:cursor];
    } else {
        showDialog(localize(@"cursor.detail.import_failed", nil), error ? error.localizedDescription : localize(@"cursor.detail.unsupported_format", nil));
    }
}

#pragma mark - Hitbox editor

- (void)openHitboxEditorForCursor:(NSString *)cursorName {
    CursorHitboxEditorViewController *editor = [[CursorHitboxEditorViewController alloc] init];
    editor.cursorName = cursorName;
    editor.typeId = self.typeId;
    [self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Section 0: header + toggle, Section 1: cursor pool
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2; // toggle + preview
    return _cursorNames.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return indexPath.row == 0 ? 50 : 80;
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ToggleCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ToggleCell"];
                cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            }
            BOOL isEnabled = [CursorTypeManager isEnabledForType:self.typeId];
            cell.textLabel.text = isEnabled ? localize(@"general.enabled", nil) : localize(@"general.disabled", nil);
            cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            cell.textLabel.textColor = isEnabled ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = isEnabled;
            if ([self.typeId isEqualToString:@"normal"] || [self.typeId isEqualToString:@"hidden"]) {
                toggle.on = YES;
                toggle.enabled = NO;
            }
            [toggle addTarget:self action:@selector(enableToggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;

            return cell;
        }

        // Preview cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PreviewCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PreviewCell"];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        }
        cell.textLabel.text = localize(@"cursor.detail.current_cursor", nil);
        cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;

        UIImageView *preview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 56, 56)];
        preview.contentMode = UIViewContentModeScaleAspectFit;
        preview.backgroundColor = UIColor.blackColor;
        preview.layer.cornerRadius = 8;
        preview.clipsToBounds = YES;
        preview.image = [CursorTypeManager imageForType:self.typeId];
        cell.accessoryView = preview;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        return cell;
    }

    // Cursor pool rows
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CursorCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CursorCell"];
        cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }

    NSString *cursorName = _cursorNames[indexPath.row];
    BOOL isDefault = [CursorManager isDefaultCursor:cursorName];
    BOOL isSelected = [[CursorTypeManager cursorForType:self.typeId] isEqualToString:cursorName];

    cell.textLabel.text = isDefault ? localize(@"cursor.detail.default_builtin", nil) : cursorName;
    cell.textLabel.textColor = isSelected ? ThemeManager.shared.accentColor : ThemeManager.shared.primaryTextColor;

    CGPoint hitbox = [CursorManager hitboxForCursor:cursorName inType:self.typeId];
cell.detailTextLabel.text = [NSString stringWithFormat:localize(@"cursor.detail.hitbox_format", nil),
                                  hitbox.x, hitbox.y,
                                  isSelected ? localize(@"cursor.detail.hitbox_selected", nil) : @""];
    cell.detailTextLabel.textColor = isSelected ? ThemeManager.shared.accentColor : ThemeManager.shared.secondaryTextColor;

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.backgroundColor = UIColor.blackColor;
    icon.layer.cornerRadius = 6;
    icon.clipsToBounds = YES;
    icon.image = [CursorManager imageForCursor:cursorName inType:self.typeId];
    icon.layer.borderWidth = isSelected ? 2 : 0;
    icon.layer.borderColor = ThemeManager.shared.accentColor.CGColor;
    cell.accessoryView = icon;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];

    if (indexPath.section == 1) {
        NSString *cursorName = _cursorNames[indexPath.row];
        [CursorTypeManager setCursor:cursorName forType:self.typeId];
        [_tableView reloadData];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return nil;

    NSString *cursorName = _cursorNames[indexPath.row];
    BOOL isDefault = [CursorManager isDefaultCursor:cursorName];

UIContextualAction *editHitbox = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:localize(@"cursor.detail.hitbox", nil)
                                                                           handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        completionHandler(YES);
        [self openHitboxEditorForCursor:cursorName];
    }];
    editHitbox.backgroundColor = ThemeManager.shared.accentColor;

    NSMutableArray *actions = [NSMutableArray arrayWithObject:editHitbox];

    if (!isDefault) {
UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                            title:localize(@"cursor.detail.delete", nil)
                                                                          handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            [self confirmDeleteCursor:cursorName];
        }];
        [actions addObject:delete];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (void)confirmDeleteCursor:(NSString *)name {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"cursor.detail.delete_title", nil)
                                                                    message:[NSString stringWithFormat:localize(@"cursor.detail.delete_confirm", nil), name]
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"cursor.detail.delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        if ([[CursorTypeManager cursorForType:self.typeId] isEqualToString:name]) {
            [CursorTypeManager setCursor:[CursorManager defaultCursorName] forType:self.typeId];
        }
        [CursorManager deleteCursor:name inType:self.typeId];
        [self reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return localize(@"cursor.detail.section.header", nil);
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return _typeDef[kCursorTypeDescription];
    return localize(@"cursor.detail.section.footer", nil);
}

@end
