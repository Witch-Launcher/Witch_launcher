#import "ProfileSettingsViewController.h"
#import "ThemeManager.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "MinecraftResourceUtils.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"

@interface ProfileSettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray *sections;

@property (nonatomic) NSString *pendingVersion;

@property (nonatomic) NSArray *rendererKeys;
@property (nonatomic) NSArray *rendererNames;
@property (nonatomic) NSArray *lwjglList;
@property (nonatomic) NSArray *touchControlList;
@property (nonatomic) NSArray *gamepadControlList;
@property (nonatomic) NSArray *javaList;
@end

@implementation ProfileSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadLists];
    [self buildSections];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];

    self.oldName = self.profile[@"name"];
    if (self.oldName.length == 0) {
        self.profile[@"name"] = @"New Profile";
    }
    self.pendingVersion = self.profile[@"lastVersionId"];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)loadLists {
    _rendererKeys = getRendererKeys(YES);
    _rendererNames = getRendererNames(YES);
    _lwjglList = getLwjglVersions(YES);

    NSString *ctrlPath = [NSString stringWithFormat:@"%s/controlmap", getenv("POJAV_HOME")];
    _touchControlList = [self listFilesAtPath:ctrlPath];

    NSString *gamepadPath = [NSString stringWithFormat:@"%s/controlmap/gamepads", getenv("POJAV_HOME")];
    _gamepadControlList = [self listFilesAtPath:gamepadPath];

    NSMutableArray *java = [getPrefObject(@"java.java_homes") allKeys].mutableCopy;
    [java sortUsingSelector:@selector(compare:)];
    java[0] = @"(default)";
    _javaList = java;
}

- (void)buildSections {
    NSString *gameDirPlaceholder = [NSString stringWithFormat:@". -> /Documents/instances/%@", getPrefObject(@"general.game_directory")];

    _sections = @[
        @{@"title": @"General", @"items": @[
            @{@"type": @"text", @"label": localize(@"preference.profile.title.name", nil), @"key": @"name", @"placeholder": @"(Default)"},
            @{@"type": @"version", @"label": localize(@"preference.profile.title.version", nil), @"key": @"lastVersionId"},
            @{@"type": @"text", @"label": localize(@"preference.title.game_directory", nil), @"key": @"gameDir", @"placeholder": gameDirPlaceholder},
        ]},
        @{@"title": @"Video", @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.title.renderer", nil), @"key": @"renderer", @"options": [self buildRendererOptions]},
            @{@"type": @"picker", @"label": localize(@"preference.title.lwjgl_version", nil), @"key": @"lwjglVersion", @"options": _lwjglList},
        ]},
        @{@"title": @"Controls", @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.profile.title.default_touch_control", nil), @"key": @"defaultTouchCtrl", @"options": _touchControlList},
            @{@"type": @"picker", @"label": localize(@"preference.profile.title.default_gamepad_control", nil), @"key": @"defaultGamepadCtrl", @"options": _gamepadControlList},
        ]},
        @{@"title": @"Java", @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.manage_runtime.header.default", nil), @"key": @"javaVersion", @"options": _javaList},
            @{@"type": @"text", @"label": localize(@"preference.title.java_args", nil), @"key": @"javaArgs", @"placeholder": @"(default)"},
        ]},
    ];
}

- (NSArray *)buildRendererOptions {
    NSMutableArray *opts = [NSMutableArray array];
    for (NSUInteger i = 0; i < _rendererKeys.count && i < _rendererNames.count; i++) {
        [opts addObject:@{
            @"key": _rendererKeys[i],
            @"name": _rendererNames[i]
        }];
    }
    return opts;
}

- (NSArray *)listFilesAtPath:(NSString *)path {
    NSArray *dirContents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil];
    NSMutableArray *files = dirContents ? [dirContents mutableCopy] : [NSMutableArray array];
    for (int i = 0; i < files.count;) {
        if ([files[i] hasSuffix:@".json"]) {
            i++;
        } else {
            [files removeObjectAtIndex:i];
        }
    }
    [files insertObject:@"(default)" atIndex:0];
    return files;
}

#pragma mark - Value helpers

- (NSString *)profileValueForKey:(NSString *)key {
    NSString *value = _profile[key];
    if (value.length > 0) return value;
    return @"(default)";
}

- (void)setProfileValue:(NSString *)value forKey:(NSString *)key {
    if ([value isEqualToString:@"(default)"]) {
        [_profile removeObjectForKey:key];
    } else if (value) {
        _profile[key] = value;
    }
}

- (NSString *)rendererDisplayForKey:(NSString *)key {
    for (NSDictionary *opt in [self buildRendererOptions]) {
        if ([opt[@"key"] isEqualToString:key]) return opt[@"name"];
    }
    return key;
}

#pragma mark - Setup UI

- (void)setup {
    self.view.clipsToBounds = YES;
    self.navigationItem.title = @"Profile Settings";
    if (self.navigationController) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveProfile)];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    }

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)saveProfile {
    if ([_profile[@"name"] length] == 0 && self.oldName.length > 0) {
        _profile[@"name"] = self.oldName;
    }

    NSString *newName = _profile[@"name"];
    if ([self.oldName isEqualToString:newName]) {
        PLProfiles.current.profiles[self.oldName] = _profile;
    } else if (!PLProfiles.current.profiles[newName]) {
        if (self.oldName.length > 0) {
            [PLProfiles.current.profiles removeObjectForKey:self.oldName];
        }
        PLProfiles.current.profiles[newName] = _profile;
        if ([PLProfiles.current.selectedProfileName isEqualToString:self.oldName]) {
            PLProfiles.current.selectedProfileName = newName;
        }
    } else {
        showDialog(localize(@"Error", nil), localize(@"profile.error.name_exists", nil));
        return;
    }

    [PLProfiles.current save];
    [self dismissSelf];
}

- (void)cancel {
    if ([self.oldName length] > 0 && _profile[@"name"] != self.oldName) {
        _profile[@"name"] = self.oldName;
    }
    [self dismissSelf];
}

- (void)dismissSelf {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _tableView.backgroundColor = theme.contentBackgroundColor;
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = _sections[section][@"title"];
    if (!title) return nil;

    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);
    [btn setTitleColor:ThemeManager.shared.secondaryTextColor forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(scrollToSection:) forControlEvents:UIControlEventTouchUpInside];
    btn.tag = section;
    [header addSubview:btn];

    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:header.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],
    ]];

    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    NSString *cellId = type;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        if ([type isEqualToString:@"text"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.font = [UIFont systemFontOfSize:15];
            label.textColor = ThemeManager.shared.primaryTextColor;
            label.tag = 101;
            [cell.contentView addSubview:label];

            UITextField *tf = [[UITextField alloc] init];
            tf.translatesAutoresizingMaskIntoConstraints = NO;
            tf.font = [UIFont systemFontOfSize:14];
            tf.textColor = ThemeManager.shared.secondaryTextColor;
            tf.textAlignment = NSTextAlignmentRight;
            tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
            tf.autocorrectionType = UITextAutocorrectionTypeNo;
            tf.tag = 100;
            [tf addTarget:self action:@selector(textFieldChanged:) forControlEvents:UIControlEventEditingChanged];
            [cell.contentView addSubview:tf];

            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [label.trailingAnchor constraintLessThanOrEqualToAnchor:tf.leadingAnchor constant:-8],

                [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [tf.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [tf.widthAnchor constraintEqualToConstant:200],
            ]];
        } else if ([type isEqualToString:@"picker"] || [type isEqualToString:@"version"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.detailTextLabel.textColor = ThemeManager.shared.accentColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }

    if ([type isEqualToString:@"text"]) {
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:101];
        label.text = item[@"label"];
        UITextField *tf = (UITextField *)[cell.contentView viewWithTag:100];
        tf.placeholder = item[@"placeholder"] ?: @"";
        NSString *val = [self profileValueForKey:item[@"key"]];
        tf.text = [val isEqualToString:@"(default)"] ? nil : val;
    } else if ([type isEqualToString:@"picker"] || [type isEqualToString:@"version"]) {
        cell.textLabel.text = item[@"label"];
    }

    if ([type isEqualToString:@"picker"]) {
        NSString *value = [self profileValueForKey:item[@"key"]];
        if ([item[@"key"] isEqualToString:@"renderer"]) {
            cell.detailTextLabel.text = [self rendererDisplayForKey:value];
        } else {
            cell.detailTextLabel.text = value;
        }
    } else if ([type isEqualToString:@"version"]) {
        NSString *v = self.pendingVersion ?: @"(not set)";
        cell.detailTextLabel.text = v;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];

    if ([type isEqualToString:@"picker"]) {
        [self showPickerForItem:item];
    } else if ([type isEqualToString:@"version"]) {
        [self showVersionPicker];
    }
}

- (void)scrollToSection:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    NSInteger section = sender.tag;
    NSInteger firstRow = [_tableView numberOfRowsInSection:section];
    if (firstRow > 0) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:0 inSection:section];
        [_tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

#pragma mark - Actions

- (void)textFieldChanged:(UITextField *)sender {
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    NSIndexPath *ip = [_tableView indexPathForCell:cell];
    if (!ip) return;
    NSDictionary *item = _sections[ip.section][@"items"][ip.row];
    [self setProfileValue:sender.text ?: @"" forKey:item[@"key"]];
}

- (void)showPickerForItem:(NSDictionary *)item {
    NSArray *options = item[@"options"];
    NSString *currentValue = [self profileValueForKey:item[@"key"]];
    BOOL isRenderer = [item[@"key"] isEqualToString:@"renderer"];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item[@"label"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    if (![options isKindOfClass:[NSArray class]] || options.count == 0) {
        showDialog(@"No Options", @"No options available for this setting.");
        return;
    }

    if (isRenderer && [options.firstObject isKindOfClass:[NSDictionary class]]) {
        for (NSDictionary *opt in options) {
            NSString *key = opt[@"key"];
            NSString *name = opt[@"name"];
            BOOL isSelected = [currentValue isEqualToString:key];
            NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", name] : name;
            [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self setProfileValue:key forKey:item[@"key"]];
                [self.tableView reloadData];
            }]];
        }
    } else {
        for (NSString *opt in options) {
            if (![opt isKindOfClass:[NSString class]]) continue;
            BOOL isSelected = [currentValue isEqualToString:opt];
            NSString *display = opt;
            if ([opt isEqualToString:@"(default)"]) display = opt;
            else display = [opt stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[opt substringToIndex:1] capitalizedString]];
            NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", display] : display;
            [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self setProfileValue:opt forKey:item[@"key"]];
                [self.tableView reloadData];
            }]];
        }
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showVersionPicker {
    NSArray *types = @[@"installed", @"release", @"snapshot", @"old_beta", @"old_alpha"];
    NSArray *typeNames = @[
        localize(@"Installed", nil),
        localize(@"Releases", nil),
        localize(@"Snapshot", nil),
        localize(@"Old-beta", nil),
        localize(@"Old-alpha", nil)
    ];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"Select Version", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSUInteger ti = 0; ti < types.count; ti++) {
        [sheet addAction:[UIAlertAction actionWithTitle:typeNames[ti] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self showVersionSubPickerForType:types[ti] typeName:typeNames[ti]];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showVersionSubPickerForType:(NSString *)type typeName:(NSString *)typeName {
    NSArray *list;
    if ([type isEqualToString:@"installed"]) {
        list = localVersionList;
    } else {
        list = remoteVersionList ? [remoteVersionList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(type == %@)", type]] : nil;
    }

    if (list == nil || list.count == 0) {
        showDialog(@"No Versions", [NSString stringWithFormat:@"No %@ versions found.", typeName]);
        return;
    }

    UIAlertController *subSheet = [UIAlertController alertControllerWithTitle:typeName
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

    NSInteger maxItems = MIN(list.count, 60);
    for (NSInteger i = 0; i < maxItems; i++) {
        NSObject *obj = list[i];
        NSString *verId;
        if ([obj isKindOfClass:[NSString class]]) {
            verId = (NSString *)obj;
        } else {
            verId = [obj valueForKey:@"id"];
        }
        if (verId.length == 0) continue;
        BOOL isSelected = [self.pendingVersion isEqualToString:verId];
        NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", verId] : verId;
        [subSheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.pendingVersion = verId;
            [self setProfileValue:verId forKey:@"lastVersionId"];
            [self.tableView reloadData];
        }]];
    }

    [subSheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        subSheet.popoverPresentationController.sourceView = self.view;
        subSheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    } else if (subSheet.actions.count > 10) {
        subSheet.popoverPresentationController.sourceView = self.tableView;
        subSheet.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    }

    [self presentViewController:subSheet animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
