#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "AppSheet.h"

#import "input/ControllerInput.h"
#import "customcontrols/CustomControlsUtils.h"
#import "FileListViewController.h"
#import "MinecraftResourceUtils.h"
#import "LauncherPreferences.h"
#import "LauncherPrefContCfgViewController.h"
#import "PickTextField.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#include "glfw_keycodes.h"

typedef void(^CreateView)(UITableViewCell *, NSString *, NSDictionary *);

@interface LauncherPrefContCfgViewController ()<UITextFieldDelegate, UIPopoverPresentationControllerDelegate, UIPickerViewDataSource, UIPickerViewDelegate>
@property(nonatomic) NSString *currentFileName;
@property(nonatomic) NSMutableDictionary *currentMappings;
@property(nonatomic) NSDictionary *keycodePlist;
@property(nonatomic) UIPickerView *editPickMapping;
@property(nonatomic) UITextField *activeTextField;
@property(nonatomic) NSArray<NSString*>* prefSections;
@property(nonatomic) NSMutableArray<NSNumber*>* prefSectionsVisibility;
@property(nonatomic) NSArray<NSDictionary*> *prefControllerTypes;
@property(nonatomic) NSMutableArray *keyCodeMap, *keyValueMap;

@end

@implementation LauncherPrefContCfgViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:localize(@"preference.title.default_gamepad_ctrl", nil)];
    
    self.keycodePlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"glfw_keycodes" ofType:@"plist"]];
    
    self.keyCodeMap = [[NSMutableArray alloc] init];
    self.keyValueMap = [[NSMutableArray alloc] init];
    initKeycodeTable(self.keyCodeMap, self.keyValueMap);
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.sectionFooterHeight = 50;
    
    [self loadGamepadConfigurationFile];
    self.prefControllerTypes = @[@{@"name": @"xbox"}, @{@"name": @"playstation"}];
    
    self.prefSections = @[@"config_files", @"game_mappings", @"menu_mappings", @"controller_style",
                          @"keyboard_mappings", @"keyboard_menu_mappings",
                          @"mouse_mappings", @"mouse_menu_mappings"];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(actionMenuSave)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(exitButtonSelector)];
    
    self.editPickMapping = [[UIPickerView alloc] init];
    self.editPickMapping.delegate = self;
    self.editPickMapping.dataSource = self;
}

- (void)loadGamepadConfigurationFile {
    NSString *gamepadPath = [NSString stringWithFormat:@"%s/controlmap/gamepads/%@", getenv("POJAV_HOME"), getPrefObject(@"control.default_gamepad_ctrl")];
    self.currentMappings = parseJSONFromFile(gamepadPath);
    self.currentFileName = [getPrefObject(@"control.default_gamepad_ctrl") stringByDeletingPathExtension];
    NSPredicate *filterPredicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *dict) {
        return ![obj[@"name"] hasPrefix:@"mouse_"];
    }];
    [self.currentMappings[@"mGameMappingList"] filterUsingPredicate:filterPredicate];
    [self.currentMappings[@"mMenuMappingList"] filterUsingPredicate:filterPredicate];

    if (self.currentMappings[@"mKeyboardGameMappingList"] == nil) {
        self.currentMappings[@"mKeyboardGameMappingList"] = [self defaultKeyboardGameMappings];
    }
    if (self.currentMappings[@"mKeyboardMenuMappingList"] == nil) {
        self.currentMappings[@"mKeyboardMenuMappingList"] = [self defaultKeyboardMenuMappings];
    }
    if (self.currentMappings[@"mMouseGameMappingList"] == nil) {
        self.currentMappings[@"mMouseGameMappingList"] = [self defaultMouseGameMappings];
    }
    if (self.currentMappings[@"mMouseMenuMappingList"] == nil) {
        self.currentMappings[@"mMouseMenuMappingList"] = [self defaultMouseMenuMappings];
    }
}

- (NSMutableArray *)defaultKeyboardGameMappings {
    return [NSMutableArray arrayWithArray:@[
        @{@"name": @"key_w", @"keycode": @(GLFW_KEY_W)},
        @{@"name": @"key_a", @"keycode": @(GLFW_KEY_A)},
        @{@"name": @"key_s", @"keycode": @(GLFW_KEY_S)},
        @{@"name": @"key_d", @"keycode": @(GLFW_KEY_D)},
        @{@"name": @"key_space", @"keycode": @(GLFW_KEY_SPACE)},
        @{@"name": @"key_shift", @"keycode": @(GLFW_KEY_LEFT_SHIFT)},
        @{@"name": @"key_ctrl", @"keycode": @(GLFW_KEY_LEFT_CONTROL)},
        @{@"name": @"key_e", @"keycode": @(GLFW_KEY_E)},
        @{@"name": @"key_q", @"keycode": @(GLFW_KEY_Q)},
        @{@"name": @"key_1", @"keycode": @(GLFW_KEY_1)},
        @{@"name": @"key_2", @"keycode": @(GLFW_KEY_2)},
        @{@"name": @"key_3", @"keycode": @(GLFW_KEY_3)},
        @{@"name": @"key_4", @"keycode": @(GLFW_KEY_4)},
        @{@"name": @"key_5", @"keycode": @(GLFW_KEY_5)},
        @{@"name": @"key_6", @"keycode": @(GLFW_KEY_6)},
        @{@"name": @"key_7", @"keycode": @(GLFW_KEY_7)},
        @{@"name": @"key_8", @"keycode": @(GLFW_KEY_8)},
        @{@"name": @"key_9", @"keycode": @(GLFW_KEY_9)},
        @{@"name": @"key_tab", @"keycode": @(GLFW_KEY_TAB)},
        @{@"name": @"key_esc", @"keycode": @(GLFW_KEY_ESCAPE)},
        @{@"name": @"key_f", @"keycode": @(GLFW_KEY_F)},
        @{@"name": @"key_enter", @"keycode": @(GLFW_KEY_ENTER)},
    ]];
}

- (NSMutableArray *)defaultKeyboardMenuMappings {
    return [NSMutableArray arrayWithArray:@[
        @{@"name": @"key_w", @"keycode": @(GLFW_KEY_DPAD_UP)},
        @{@"name": @"key_s", @"keycode": @(GLFW_KEY_DPAD_DOWN)},
        @{@"name": @"key_a", @"keycode": @(GLFW_KEY_DPAD_LEFT)},
        @{@"name": @"key_d", @"keycode": @(GLFW_KEY_DPAD_RIGHT)},
        @{@"name": @"key_enter", @"keycode": @(GLFW_KEY_ENTER)},
        @{@"name": @"key_esc", @"keycode": @(GLFW_KEY_ESCAPE)},
        @{@"name": @"key_space", @"keycode": @(GLFW_KEY_SPACE)},
        @{@"name": @"key_tab", @"keycode": @(GLFW_KEY_TAB)},
    ]];
}

- (NSMutableArray *)defaultMouseGameMappings {
    return [NSMutableArray arrayWithArray:@[
        @{@"name": @"mouse_left", @"keycode": @(SPECIALBTN_MOUSEPRI)},
        @{@"name": @"mouse_right", @"keycode": @(SPECIALBTN_MOUSESEC)},
        @{@"name": @"mouse_middle", @"keycode": @(SPECIALBTN_MOUSEMID)},
        @{@"name": @"mouse_scroll_up", @"keycode": @(SPECIALBTN_SCROLLUP)},
        @{@"name": @"mouse_scroll_down", @"keycode": @(SPECIALBTN_SCROLLDOWN)},
    ]];
}

- (NSMutableArray *)defaultMouseMenuMappings {
    return [NSMutableArray arrayWithArray:@[
        @{@"name": @"mouse_left", @"keycode": @(SPECIALBTN_MOUSEPRI)},
        @{@"name": @"mouse_right", @"keycode": @(SPECIALBTN_MOUSESEC)},
        @{@"name": @"mouse_scroll_up", @"keycode": @(SPECIALBTN_SCROLLUP)},
        @{@"name": @"mouse_scroll_down", @"keycode": @(SPECIALBTN_SCROLLDOWN)},
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

#pragma mark External UITableView functions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.prefSections.count;
}

- (NSArray *)prefContentForIndex:(NSInteger)index {
    switch (index) {
        case 0: return nil;
        case 1: return self.currentMappings[@"mGameMappingList"];
        case 2: return self.currentMappings[@"mMenuMappingList"];
        case 3: return self.prefControllerTypes;
        case 4: return self.currentMappings[@"mKeyboardGameMappingList"];
        case 5: return self.currentMappings[@"mKeyboardMenuMappingList"];
        case 6: return self.currentMappings[@"mMouseGameMappingList"];
        case 7: return self.currentMappings[@"mMouseMenuMappingList"];
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return [self prefContentForIndex:section].count;
    }
}

- (UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *item = [self prefContentForIndex:indexPath.section][indexPath.row];
    NSString *cellID = [NSString stringWithFormat:@"cellValue%ld", indexPath.section];
    UITableViewCellStyle cellStyle = UITableViewCellStyleValue1;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellID];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    if(indexPath.section == 0) {
        cell.textLabel.text = localize(@"controller_configurator.title.current", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.text = getPrefObject(@"control.default_gamepad_ctrl");
    } else if(indexPath.section == 1 || indexPath.section == 2) {
        NSNumber *keycode = (NSNumber *)item[@"keycode"];
        cell.textLabel.text = localize(([NSString stringWithFormat:@"controller_configurator.%@.title.%@", getPrefObject(@"control.controller_type"), item[@"name"]]), nil);
        PickTextField *view = (id)cell.accessoryView;
        if (view == nil) {
            view = [[PickTextField alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2.1, cell.bounds.size.height)];
            [view addTarget:view action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
            view.autocorrectionType = UITextAutocorrectionTypeNo;
            view.autocapitalizationType = UITextAutocapitalizationTypeNone;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
            view.delegate = self;
            view.returnKeyType = UIReturnKeyDone;
            view.tag = indexPath.section;
            view.textAlignment = NSTextAlignmentRight;
            view.tintColor = UIColor.clearColor;
            view.adjustsFontSizeToFitWidth = YES;
            view.inputView = self.editPickMapping;
            [view setupDoneButtonWithTarget:self action:@selector(closeTextField:)];
            cell.accessoryView = view;
        }
        view.text = self.keyCodeMap[[self.keyValueMap indexOfObject:keycode]];
        objc_setAssociatedObject(view, @"gamepad_button", item[@"name"], OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(view, @"item", item, OBJC_ASSOCIATION_ASSIGN);
    } else if(indexPath.section == 3) {
        cell.textLabel.text = localize([NSString stringWithFormat:@"controller_configurator.title.type.%@", item[@"name"]], nil);
        if ([getPrefObject(@"control.controller_type") isEqualToString:item[@"name"]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if(indexPath.section == 4 || indexPath.section == 5) {
        NSNumber *keycode = (NSNumber *)item[@"keycode"];
        cell.textLabel.text = localize(([NSString stringWithFormat:@"controller_configurator.keyboard.title.%@", item[@"name"]]), nil);
        PickTextField *view = (id)cell.accessoryView;
        if (view == nil) {
            view = [[PickTextField alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2.1, cell.bounds.size.height)];
            [view addTarget:view action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
            view.autocorrectionType = UITextAutocorrectionTypeNo;
            view.autocapitalizationType = UITextAutocapitalizationTypeNone;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
            view.delegate = self;
            view.returnKeyType = UIReturnKeyDone;
            view.tag = indexPath.section;
            view.textAlignment = NSTextAlignmentRight;
            view.tintColor = UIColor.clearColor;
            view.adjustsFontSizeToFitWidth = YES;
            view.inputView = self.editPickMapping;
            [view setupDoneButtonWithTarget:self action:@selector(closeTextField:)];
            cell.accessoryView = view;
        }
        view.text = self.keyCodeMap[[self.keyValueMap indexOfObject:keycode]];
        objc_setAssociatedObject(view, @"gamepad_button", item[@"name"], OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(view, @"item", item, OBJC_ASSOCIATION_ASSIGN);
    } else if(indexPath.section == 6 || indexPath.section == 7) {
        NSNumber *keycode = (NSNumber *)item[@"keycode"];
        cell.textLabel.text = localize(([NSString stringWithFormat:@"controller_configurator.mouse.title.%@", item[@"name"]]), nil);
        PickTextField *view = (id)cell.accessoryView;
        if (view == nil) {
            view = [[PickTextField alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2.1, cell.bounds.size.height)];
            [view addTarget:view action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
            view.autocorrectionType = UITextAutocorrectionTypeNo;
            view.autocapitalizationType = UITextAutocapitalizationTypeNone;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
            view.delegate = self;
            view.returnKeyType = UIReturnKeyDone;
            view.tag = indexPath.section;
            view.textAlignment = NSTextAlignmentRight;
            view.tintColor = UIColor.clearColor;
            view.adjustsFontSizeToFitWidth = YES;
            view.inputView = self.editPickMapping;
            [view setupDoneButtonWithTarget:self action:@selector(closeTextField:)];
            cell.accessoryView = view;
        }
        view.text = self.keyCodeMap[[self.keyValueMap indexOfObject:keycode]];
        objc_setAssociatedObject(view, @"gamepad_button", item[@"name"], OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(view, @"item", item, OBJC_ASSOCIATION_ASSIGN);
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return localize([NSString stringWithFormat:@"controller_configurator.section.%@", self.prefSections[section]], nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *key = [NSString stringWithFormat:@"controller_configurator.section.footer.%@", self.prefSections[section]];
    NSString *footer = localize(key, nil);
    return [footer isEqualToString:key] ? nil : footer;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    NSDictionary *item = [self prefContentForIndex:indexPath.section][indexPath.row];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if(indexPath.section == 0) {
        [self actionMenuLoad];
    } else if(indexPath.section == 3) {
        setPrefObject(@"control.controller_type", self.prefControllerTypes[indexPath.row][@"name"]);
        NSIndexSet *section = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)];
        [self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationNone];
    }
    // 1 and 2 handle themselves with picker views.
}

#pragma mark UITextField + UIPickerView

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = (UILabel *)view;
    if (label == nil) {
        label = [UILabel new];
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.5;
        label.textAlignment = NSTextAlignmentCenter;
    }
    label.text = [self pickerView:pickerView titleForRow:row forComponent:component];

    return label;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.activeTextField.text = [self.keyCodeMap objectAtIndex:row];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.keyCodeMap.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [self.keyCodeMap objectAtIndex:row];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.activeTextField = textField;
    [self.editPickMapping selectRow:[self.keyCodeMap indexOfObject:textField.text] inComponent:0 animated:NO];
}
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    UITableViewCell *cell = (UITableViewCell *)textField.superview;
    NSMutableDictionary *item = objc_getAssociatedObject(cell.accessoryView, @"item");
    if(![textField.text hasPrefix:@"SPECIALBTN"]) {
        item[@"keycode"] = self.keycodePlist[[@"GLFW_KEY_" stringByAppendingString:textField.text]];
    } else {
        item[@"keycode"] = self.keycodePlist[textField.text];
    }
    self.activeTextField = nil;
}

- (void)closeTextField:(UIBarButtonItem *)sender {
    [self.activeTextField endEditing:YES];
}

#pragma mark UI

- (void) dismissModalViewController {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)actionOpenFilePicker:(void (^)(NSString *name))handler {
    FileListViewController *vc = [[FileListViewController alloc] init];
    vc.listPath = [NSString stringWithFormat:@"%s/controlmap/gamepads", getenv("POJAV_HOME")];
    
    vc.whenItemSelected = handler;
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = CGSizeMake(350, 250);

    UIPopoverPresentationController *popoverController = [vc popoverPresentationController];
    popoverController.sourceView = self.tableView;
    popoverController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    popoverController.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)actionMenuLoad {
    [self actionOpenFilePicker:^void(NSString* name) {
        NSString *currentFile = [NSString stringWithFormat:@"%@.json", getPrefObject(@"control.default_gamepad_ctrl")];
        if(![currentFile isEqualToString:name]) {
            setPrefObject(@"control.default_gamepad_ctrl", [NSString stringWithFormat:@"%@.json", name]);
            [self loadGamepadConfigurationFile];
            [self.tableView reloadData];
        }
    }];
}

- (void)actionMenuSaveWithExit:(BOOL)exit {
    if (exit) {
        [AppSheet showOptionsWithTitle:localize(@"custom_controls.control_menu.save", nil)
                               message:localize(@"custom_controls.control_menu.exit.warn", nil)
                               options:@[
            @{@"title": localize(@"OK", nil), @"icon": @"square.and.arrow.down"},
            @{@"title": localize(@"custom_controls.control_menu.discard_changes", nil), @"icon": @"trash", @"destructive": @YES},
        ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
            if (idx == 0) [self promptSaveNameWithExit:YES];
            else [self dismissModalViewController];
        }];
        return;
    }
    [self promptSaveNameWithExit:NO];
}

- (void)promptSaveNameWithExit:(BOOL)exit {
    [AppSheet showPromptWithTitle:localize(@"custom_controls.control_menu.save", nil)
                          message:exit ? localize(@"custom_controls.control_menu.exit.warn", nil) : @""
                      placeholder:@"Name"
                      initialText:self.currentFileName
                        onConfirm:^(NSString *name) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.currentMappings options:NSJSONWritingPrettyPrinted error:&error];
        if (jsonData == nil) {
            showDialog(localize(@"custom_controls.control_menu.save.error.json", nil), error.localizedDescription);
            return;
        }
        BOOL success = [jsonData writeToFile:[NSString stringWithFormat:@"%s/controlmap/gamepads/%@.json", getenv("POJAV_HOME"), name] options:NSDataWritingAtomic error:&error];
        if (!success) {
            showDialog(localize(@"custom_controls.control_menu.save.error.write", nil), error.localizedDescription);
            return;
        }

        if (exit) {
            [self dismissModalViewController];
        }

        setPrefObject(@"control.default_gamepad_ctrl", [NSString stringWithFormat:@"%@.json", name]);
    }];
}

- (void)actionMenuSave {
    [self actionMenuSaveWithExit:NO];
}

- (void)exitButtonSelector {
    NSString *gamepadPath = [NSString stringWithFormat:@"%s/controlmap/gamepads/%@", getenv("POJAV_HOME"), getPrefObject(@"control.default_gamepad_ctrl")];
    if([self.currentMappings isEqualToDictionary:parseJSONFromFile(gamepadPath)]) {
        [self dismissModalViewController];
    } else {
        [self actionMenuSaveWithExit:YES];
    }
}

@end
