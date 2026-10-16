#import "ProfileOverviewVC.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "ProfileAvatarManager.h"
#import "FileBrowserViewController.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "MinecraftResourceUtils.h"
#import "ModMetadataReader.h"
#import "utils.h"

@interface ProfileOverviewVC () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIView *headerCard;
@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *subLabel;
@property (nonatomic) UIButton *avatarButton;
@property (nonatomic) NSArray *sections;
@property (nonatomic, copy) NSString *pendingVersion;
@property (nonatomic) NSArray *rendererKeys;
@property (nonatomic) NSArray *rendererNames;
@property (nonatomic) NSArray *lwjglList;
@property (nonatomic) NSArray *touchControlList;
@property (nonatomic) NSArray *gamepadControlList;
@property (nonatomic) NSArray *javaList;
@property (nonatomic) BOOL pickingAvatar;
@end

@implementation ProfileOverviewVC

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew {
    self = [super init];
    if (self) {
        _profile = profile ?: [NSMutableDictionary dictionary];
        _isNewProfile = isNew;
        _originalName = [profile[@"name"] copy];
        self.title = localize(@"profiles.tab_overview", nil);
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:localize(@"profiles.tab_overview", nil)
                                                       image:[UIImage systemImageNamed:@"person.crop.circle"]
                                               selectedImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [AmethystBlurView installInView:self.view];
    [self loadSettingLists];
    [self buildSettingSections];
    self.pendingVersion = self.profile[@"lastVersionId"];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.rowHeight = 48;
    [self.view addSubview:_tableView];

    _headerCard = [[UIView alloc] init];
    _headerCard.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _headerCard.layer.cornerRadius = 16;
    _headerCard.clipsToBounds = YES;
    _headerCard.translatesAutoresizingMaskIntoConstraints = NO;

    _avatarView = [[UIImageView alloc] init];
    _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = 28;
    _avatarView.tintColor = ThemeManager.shared.accentColor;
    [_headerCard addSubview:_avatarView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    [_headerCard addSubview:_nameLabel];

    _subLabel = [[UILabel alloc] init];
    _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subLabel.font = [UIFont systemFontOfSize:13];
    _subLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _subLabel.numberOfLines = 3;
    [_headerCard addSubview:_subLabel];

    _avatarButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_avatarButton setImage:[UIImage systemImageNamed:@"camera.fill"] forState:UIControlStateNormal];
    _avatarButton.tintColor = ThemeManager.shared.accentColor;
    [_avatarButton addTarget:self action:@selector(changeAvatarTapped) forControlEvents:UIControlEventTouchUpInside];
    [_headerCard addSubview:_avatarButton];

    UIView *headerWrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 108)];
    [headerWrap addSubview:_headerCard];
    _headerCard.frame = CGRectMake(12, 8, 296, 92);
    _headerCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [NSLayoutConstraint activateConstraints:@[
        [_avatarView.leadingAnchor constraintEqualToAnchor:_headerCard.leadingAnchor constant:14],
        [_avatarView.centerYAnchor constraintEqualToAnchor:_headerCard.centerYAnchor],
        [_avatarView.widthAnchor constraintEqualToConstant:56],
        [_avatarView.heightAnchor constraintEqualToConstant:56],
        [_nameLabel.topAnchor constraintEqualToAnchor:_headerCard.topAnchor constant:14],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_avatarButton.leadingAnchor constant:-8],
        [_subLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
        [_subLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_avatarButton.leadingAnchor constant:-8],
        [_subLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_headerCard.bottomAnchor constant:-12],
        [_avatarButton.trailingAnchor constraintEqualToAnchor:_headerCard.trailingAnchor constant:-12],
        [_avatarButton.centerYAnchor constraintEqualToAnchor:_headerCard.centerYAnchor],
        [_avatarButton.widthAnchor constraintEqualToConstant:36],
        [_avatarButton.heightAnchor constraintEqualToConstant:36],
    ]];
    _tableView.tableHeaderView = headerWrap;

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHeader) name:InstalledModsDidChangeNotification object:nil];
    [self refreshHeader];
}

- (void)onTheme {
    _headerCard.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _subLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _avatarView.tintColor = ThemeManager.shared.accentColor;
    _avatarButton.tintColor = ThemeManager.shared.accentColor;
    [_tableView reloadData];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshHeader];
    [_tableView reloadData];
}

#pragma mark - Header

- (void)refreshHeader {
    _avatarView.image = [ProfileAvatarManager.shared avatarImageForProfile:self.profile];
    NSString *name = self.profile[@"name"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) name = @"New Profile";
    _nameLabel.text = name;
    NSString *mc = self.profile[@"lastVersionId"];
    if (![mc isKindOfClass:[NSString class]] || mc.length == 0) mc = @"?";
    NSString *loader = self.profile[@"modLoader"];
    if (![loader isKindOfClass:[NSString class]] || loader.length == 0) loader = @"?";
    NSUInteger mods = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryMod profile:self.profile].count;
    NSUInteger shaders = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryShaderPack profile:self.profile].count;
    NSUInteger rps = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryResourcePack profile:self.profile].count;
    NSString *savesDir = [[InstalledModsManager shared] savesDirForProfile:self.profile];
    NSArray *saves = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:savesDir error:nil] ?: @[];
    NSUInteger worlds = 0;
    for (NSString *e in saves) {
        BOOL isDir = NO;
        NSString *full = [savesDir stringByAppendingPathComponent:e];
        if ([[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:[full stringByAppendingPathComponent:@"level.dat"]]) worlds++;
        }
    }
    NSString *gameDir = self.profile[@"gameDir"];
    if (![gameDir isKindOfClass:[NSString class]] || gameDir.length == 0) gameDir = @"default";
    _subLabel.text = [NSString stringWithFormat:@"MC %@  •  %@\n%lu mods  •  %lu shaders  •  %lu resources  •  %lu worlds\nFolder: %@",
                      mc, [loader capitalizedString] ?: @"?",
                      (unsigned long)mods, (unsigned long)shaders, (unsigned long)rps, (unsigned long)worlds, gameDir];
}

#pragma mark - Avatar (fixed)

- (void)changeAvatarTapped {
    [HapticManager.shared play:HapticTypeLight];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Profile Icon" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *key in @[@"fabric", @"forge", @"neoforge", @"quilt", @"modpack", @"vanilla", @"custom"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[key capitalizedString] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if ([key isEqualToString:@"custom"]) [self pickCustomAvatar];
            else [self persistAvatarKey:key];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = _avatarButton;
        sheet.popoverPresentationController.sourceRect = _avatarButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)persistAvatarKey:(NSString *)key {
    self.profile[@"avatar"] = key;
    [self persistProfileObject];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{}];
    [self refreshHeader];
}

- (void)persistProfileObject {
    NSString *name = self.profile[@"name"];
    if ([name isKindOfClass:[NSString class]] && name.length > 0) {
        PLProfiles.current.profiles[name] = self.profile;
        [PLProfiles.current save];
    }
}

- (void)pickCustomAvatar {
    _pickingAvatar = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (_pickingAvatar) {
        _pickingAvatar = NO;
        [self handleAvatarURL:urls.firstObject];
        return;
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    if (_pickingAvatar) {
        _pickingAvatar = NO;
        [self handleAvatarURL:url];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    _pickingAvatar = NO;
}

- (void)handleAvatarURL:(NSURL *)url {
    if (!url) {
        [ErrorPresenter showValidation:@"image" message:@"Pick an image file."];
        return;
    }
    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    __block NSData *data = nil;
    __block NSError *readErr = nil;
    [coordinator coordinateReadingItemAtURL:url options:0 error:&readErr byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfURL:newURL];
    }];
    if (accessing) [url stopAccessingSecurityScopedResource];
    if (readErr || !data) {
        [ErrorPresenter showFileError:@"Read image" path:url.lastPathComponent error:readErr];
        return;
    }
    if (![UIImage imageWithData:data]) {
        [ErrorPresenter showValidation:@"image" message:@"That file is not a valid image."];
        return;
    }
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *profileName = self.profile[@"name"];
    if (![profileName isKindOfClass:[NSString class]] || profileName.length == 0) profileName = @"profile";
    NSString *safe = [[profileName componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"]] componentsJoinedByString:@"_"];
    NSString *fileName = [NSString stringWithFormat:@"avatar_%@_%lld.png", safe, (long long)([[NSDate date] timeIntervalSince1970])];
    NSString *dest = [[docs stringByAppendingPathComponent:@"profile_avatars"] stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] createDirectoryAtPath:dest.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *err = nil;
    if (![data writeToFile:dest options:NSDataWritingAtomic error:&err]) {
        [ErrorPresenter showFileError:@"Save avatar" path:fileName error:err];
        return;
    }
    self.profile[@"avatar"] = dest;
    [self persistProfileObject];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{}];
    [HapticManager.shared play:HapticTypeSuccess];
    [self refreshHeader];
}

#pragma mark - Settings form

- (void)loadSettingLists {
    _rendererKeys = getRendererKeys(YES);
    _rendererNames = getRendererNames(YES);
    NSString *ctrlPath = [NSString stringWithFormat:@"%s/controlmap", getenv("POJAV_HOME")];
    _touchControlList = [self listFilesAtPath:ctrlPath];
    NSString *gamepadPath = [NSString stringWithFormat:@"%s/controlmap/gamepads", getenv("POJAV_HOME")];
    _gamepadControlList = [self listFilesAtPath:gamepadPath];
    _lwjglList = getLwjglVersions(YES);
    NSMutableArray *java = [getPrefObject(@"java.java_homes") allKeys].mutableCopy ?: [NSMutableArray array];
    [java sortUsingSelector:@selector(compare:)];
    if (java.count > 0) java[0] = @"(default)";
    else [java addObject:@"(default)"];
    _javaList = java;
}

- (NSArray *)listFilesAtPath:(NSString *)path {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil];
    NSMutableArray *files = contents ? [contents mutableCopy] : [NSMutableArray array];
    for (NSInteger i = files.count - 1; i >= 0; i--) {
        if (![files[i] hasSuffix:@".json"]) [files removeObjectAtIndex:i];
    }
    [files insertObject:@"(default)" atIndex:0];
    return files;
}

- (void)buildSettingSections {
    NSMutableArray *rendererOpts = [NSMutableArray array];
    for (NSUInteger i = 0; i < _rendererKeys.count && i < _rendererNames.count; i++) {
        [rendererOpts addObject:@{@"key": _rendererKeys[i], @"name": _rendererNames[i]}];
    }
    _sections = @[
        @{@"title": @"General", @"items": @[
            @{@"type": @"text", @"label": localize(@"preference.profile.title.name", nil), @"key": @"name", @"placeholder": @"(Default)"},
            @{@"type": @"version", @"label": localize(@"preference.profile.title.version", nil), @"key": @"lastVersionId"},
            @{@"type": @"text", @"label": localize(@"preference.title.game_directory", nil), @"key": @"gameDir", @"placeholder": @". -> instances"},
            @{@"type": @"picker", @"label": @"Mod Loader", @"key": @"modLoader", @"options": @[@"(default)", @"fabric", @"forge", @"quilt", @"neoforge", @"vanilla"]},
        ]},
        @{@"title": @"Storage", @"items": @[
            @{@"type": @"action", @"label": @"Open profile folder", @"key": @"__openFolder"},
            @{@"type": @"action", @"label": @"Open saves folder", @"key": @"__openSaves"},
        ]},
        @{@"title": @"Video", @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.title.renderer", nil), @"key": @"renderer", @"options": rendererOpts},
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

- (NSString *)profileValueForKey:(NSString *)key {
    NSString *v = _profile[key];
    if ([v isKindOfClass:[NSString class]] && v.length > 0) return v;
    return @"(default)";
}

- (void)setProfileValue:(NSString *)value forKey:(NSString *)key {
    if ([value isEqualToString:@"(default)"]) [_profile removeObjectForKey:key];
    else if (value) _profile[key] = value;
    if ([key isEqualToString:@"name"] || [key isEqualToString:@"lastVersionId"] ||
        [key isEqualToString:@"modLoader"] || [key isEqualToString:@"gameDir"]) {
        [self refreshHeader];
    }
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:type];
    if (!cell) {
        if ([type isEqualToString:@"text"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:type];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.font = [UIFont systemFontOfSize:15];
            label.tag = 101;
            [cell.contentView addSubview:label];
            UITextField *tf = [[UITextField alloc] init];
            tf.translatesAutoresizingMaskIntoConstraints = NO;
            tf.font = [UIFont systemFontOfSize:14];
            tf.textAlignment = NSTextAlignmentRight;
            tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
            tf.autocorrectionType = UITextAutocorrectionTypeNo;
            tf.tag = 100;
            [tf addTarget:self action:@selector(settingTextChanged:) forControlEvents:UIControlEventEditingChanged];
            [cell.contentView addSubview:tf];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [tf.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [tf.widthAnchor constraintEqualToConstant:180],
            ]];
        } else {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:type];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        }
    }
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.accentColor;
    if ([type isEqualToString:@"text"]) {
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:101];
        label.text = item[@"label"];
        label.textColor = ThemeManager.shared.primaryTextColor;
        UITextField *tf = (UITextField *)[cell.contentView viewWithTag:100];
        tf.placeholder = item[@"placeholder"] ?: @"";
        tf.textColor = ThemeManager.shared.secondaryTextColor;
        NSString *val = [self profileValueForKey:item[@"key"]];
        tf.text = [val isEqualToString:@"(default)"] ? nil : val;
    } else if ([type isEqualToString:@"picker"]) {
        cell.textLabel.text = item[@"label"];
        cell.detailTextLabel.text = [self profileValueForKey:item[@"key"]];
    } else if ([type isEqualToString:@"version"]) {
        cell.textLabel.text = item[@"label"];
        cell.detailTextLabel.text = self.pendingVersion ?: @"(not set)";
    } else if ([type isEqualToString:@"action"]) {
        cell.textLabel.text = item[@"label"];
        cell.detailTextLabel.text = @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
    if ([item[@"type"] isEqualToString:@"picker"]) [self showPickerForSetting:item];
    else if ([item[@"type"] isEqualToString:@"version"]) [self showVersionPicker];
    else if ([item[@"type"] isEqualToString:@"action"]) {
        if ([item[@"key"] isEqualToString:@"__openFolder"]) [self openFolder:[[InstalledModsManager shared] dirForCategory:InstalledItemCategoryMod profile:self.profile].stringByDeletingLastPathComponent];
        else if ([item[@"key"] isEqualToString:@"__openSaves"]) [self openFolder:[[InstalledModsManager shared] savesDirForProfile:self.profile]];
    }
}

- (void)openFolder:(NSString *)path {
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
    vc.rootPath = path;
    vc.title = path.lastPathComponent;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)settingTextChanged:(UITextField *)sender {
    UIView *v = sender.superview;
    while (v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
    NSIndexPath *ip = [_tableView indexPathForCell:(UITableViewCell *)v];
    if (!ip) return;
    NSDictionary *item = _sections[ip.section][@"items"][ip.row];
    [self setProfileValue:sender.text ?: @"" forKey:item[@"key"]];
}

- (void)showPickerForSetting:(NSDictionary *)item {
    NSArray *options = item[@"options"];
    if (![options isKindOfClass:[NSArray class]] || options.count == 0) {
        [ErrorPresenter showInfo:@"No Options" message:@"No options available for this setting."];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item[@"label"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if ([options.firstObject isKindOfClass:[NSDictionary class]]) {
        for (NSDictionary *opt in options) {
            NSString *key = opt[@"key"];
            NSString *name = opt[@"name"];
            [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [self setProfileValue:key forKey:item[@"key"]];
                [self.tableView reloadData];
            }]];
        }
    } else {
        for (id opt in options) {
            if (![opt isKindOfClass:[NSString class]]) continue;
            [sheet addAction:[UIAlertAction actionWithTitle:opt style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
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
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"Select Version", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *t in types) {
        [sheet addAction:[UIAlertAction actionWithTitle:t style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self showVersionSubPicker:t];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showVersionSubPicker:(NSString *)type {
    NSArray *list;
    if ([type isEqualToString:@"installed"]) list = localVersionList;
    else list = remoteVersionList ? [remoteVersionList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(type == %@)", type]] : nil;
    if (!list || list.count == 0) {
        [ErrorPresenter showInfo:@"No Versions" message:[NSString stringWithFormat:@"No %@ versions found.", type]];
        return;
    }
    UIAlertController *sub = [UIAlertController alertControllerWithTitle:type message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger max = MIN((NSInteger)list.count, 60);
    for (NSInteger i = 0; i < max; i++) {
        NSObject *obj = list[i];
        NSString *verId = [obj isKindOfClass:[NSString class]] ? (NSString *)obj : [obj valueForKey:@"id"];
        if (verId.length == 0) continue;
        [sub addAction:[UIAlertAction actionWithTitle:verId style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.pendingVersion = verId;
            [self setProfileValue:verId forKey:@"lastVersionId"];
            [self.tableView reloadData];
            [self refreshHeader];
        }]];
    }
    [sub addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sub.popoverPresentationController.sourceView = self.view;
        sub.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:sub animated:YES completion:nil];
}

#pragma mark - Save

- (BOOL)saveProfile {
    static BOOL saving = NO;
    if (saving) return NO;
    saving = YES;
    [self.view endEditing:YES];
    [HapticManager.shared play:HapticTypeMedium];
    BOOL result = [self doSaveProfile];
    saving = NO;
    return result;
}

- (BOOL)doSaveProfile {
    NSString *name = _profile[@"name"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) {
        if ([_originalName isKindOfClass:[NSString class]] && _originalName.length > 0) {
            _profile[@"name"] = _originalName;
            name = _originalName;
        } else {
            [ErrorPresenter showValidation:@"profile name" message:@"Enter a profile name."];
            return NO;
        }
    }
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    BOOL isRename = _originalName && ![name isEqualToString:_originalName];
    if ((isRename && profiles[name]) || (_isNewProfile && profiles[name])) {
        [ErrorPresenter showError:@"Error" message:@"A profile with this name already exists."];
        return NO;
    }
    if (isRename && _originalName.length > 0) [profiles removeObjectForKey:_originalName];
    profiles[name] = _profile;
    if (!_originalName || [PLProfiles.current.selectedProfileName isEqualToString:_originalName]) {
        PLProfiles.current.selectedProfileName = name;
    }
    if (self.pendingVersion) _profile[@"lastVersionId"] = self.pendingVersion;
    [PLProfiles.current save];
    // NOTE: intentionally NOT calling updateAppIconForCurrentProfile here.
    // Saving a profile must only change the profile's own avatar, never the
    // Witch launcher icon on the home screen.
    _originalName = [name copy];
    _isNewProfile = NO;
    // Non-modal toast: never steals the key window, so saving can never hang UI.
    [ErrorPresenter showToast:localize(@"profile.saved", nil)];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{}];
    [self refreshHeader];
    return YES;
}

@end
