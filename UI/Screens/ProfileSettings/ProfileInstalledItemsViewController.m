#import "ProfileInstalledItemsViewController.h"
#import "ThemeManager.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "ModrinthService.h"
#import "DownloadManager.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "UIImageView+AFNetworking.h"
#import "AmethystBlurView.h"
#import "LauncherPreferences.h"
#import "DependencyResolver.h"
#import "DependencyDownloadViewController.h"
#import <objc/runtime.h>

static NSString * const kItemCell = @"InstalledItemCell";

@interface InstalledItemCell : UITableViewCell
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *versionLabel;
@property (nonatomic) UILabel *sourceLabel;
@property (nonatomic) UISwitch *enabledSwitch;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic) UIActivityIndicatorView *checkSpinner;
@property (nonatomic) NSDictionary *itemData;
@property (nonatomic) BOOL isMod;
@property (nonatomic, copy) void(^onToggle)(NSDictionary *item, BOOL enabled);
@property (nonatomic, copy) void(^onAction)(NSDictionary *item, UIButton *sender);
@end

@implementation InstalledItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 8;
        _iconView.backgroundColor = ThemeManager.shared.separatorColor;
        _iconView.image = [UIImage systemImageNamed:@"puzzlepiece.extension"];
        _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        _nameLabel.numberOfLines = 1;
        [self.contentView addSubview:_nameLabel];

        _versionLabel = [[UILabel alloc] init];
        _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _versionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _versionLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_versionLabel];

        _sourceLabel = [[UILabel alloc] init];
        _sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _sourceLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _sourceLabel.textColor = UIColor.whiteColor;
        _sourceLabel.textAlignment = NSTextAlignmentCenter;
        _sourceLabel.layer.cornerRadius = 4;
        _sourceLabel.clipsToBounds = YES;
        [self.contentView addSubview:_sourceLabel];

        _enabledSwitch = [[UISwitch alloc] init];
        _enabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
        [_enabledSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_enabledSwitch];

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _actionButton.layer.cornerRadius = 6;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(4, 10, 4, 10);
        [_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];

        _checkSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _checkSpinner.translatesAutoresizingMaskIntoConstraints = NO;
        _checkSpinner.hidesWhenStopped = YES;
        [self.contentView addSubview:_checkSpinner];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:40],
            [_iconView.heightAnchor constraintEqualToConstant:40],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_versionLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_versionLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],

            [_sourceLabel.topAnchor constraintEqualToAnchor:_versionLabel.bottomAnchor constant:3],
            [_sourceLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_sourceLabel.heightAnchor constraintEqualToConstant:16],
            [_sourceLabel.widthAnchor constraintGreaterThanOrEqualToConstant:48],

            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_actionButton.trailingAnchor constraintEqualToAnchor:_enabledSwitch.leadingAnchor constant:-8],
            [_actionButton.heightAnchor constraintEqualToConstant:28],

            [_checkSpinner.centerXAnchor constraintEqualToAnchor:_actionButton.centerXAnchor],
            [_checkSpinner.centerYAnchor constraintEqualToAnchor:_actionButton.centerYAnchor],

            [_enabledSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
            [_enabledSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _versionLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
    _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
}

- (void)switchChanged {
    if (_onToggle) _onToggle(_itemData, _enabledSwitch.isOn);
}

- (void)actionTapped {
    if (_onAction) _onAction(_itemData, _actionButton);
}

- (void)configureWithItem:(NSDictionary *)item category:(InstalledItemCategory)category {
    _itemData = item;
    _isMod = [category isEqualToString:InstalledItemCategoryMod];

    _nameLabel.text = item[@"title"] ?: item[@"filename"] ?: @"Unknown";
    _versionLabel.text = item[@"version_number"] ?: @"";

    NSString *source = item[@"source"] ?: @"";
    if ([source isEqualToString:@"curseforge"]) {
        _sourceLabel.text = @" CurseForge ";
        _sourceLabel.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.73 alpha:1.0];
    } else {
        _sourceLabel.text = @" Modrinth ";
        _sourceLabel.backgroundColor = [UIColor colorWithRed:0.34 green:0.76 blue:0.42 alpha:1.0];
    }

    _enabledSwitch.hidden = !_isMod;

    UIImage *placeholder = [UIImage systemImageNamed:@"puzzlepiece.extension"];
    _iconView.image = placeholder;
    _iconView.tintColor = ThemeManager.shared.secondaryTextColor;

    NSString *iconURL = item[@"icon_url"];
    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:iconURL]];
        [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
        [_iconView setImageWithURLRequest:request placeholderImage:placeholder success:^(NSURLRequest *req, NSHTTPURLResponse *resp, UIImage *img) {
            weakSelf.iconView.image = img;
            weakSelf.iconView.tintColor = [UIColor clearColor];
        } failure:nil];
    }
}

- (void)setActionTitle:(NSString *)title color:(UIColor *)color {
    [_actionButton setTitle:title forState:UIControlStateNormal];
    [_actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _actionButton.backgroundColor = color;
    _actionButton.hidden = NO;
}

- (void)hideAction {
    _actionButton.hidden = YES;
}

- (void)setChecking:(BOOL)checking {
    if (checking) {
        [_checkSpinner startAnimating];
        _actionButton.titleLabel.alpha = 0;
        _actionButton.hidden = NO;
    } else {
        [_checkSpinner stopAnimating];
        _actionButton.titleLabel.alpha = 1;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _iconView.image = nil;
    _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
    _nameLabel.text = nil;
    _versionLabel.text = nil;
    _sourceLabel.text = nil;
    _actionButton.hidden = YES;
    [_checkSpinner stopAnimating];
    _itemData = nil;
    _onToggle = nil;
    _onAction = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#pragma mark - View Controller

@interface ProfileInstalledItemsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) NSArray<NSDictionary *> *manifestItems;
@property (nonatomic) NSArray<NSDictionary *> *orphanFiles;
@property (nonatomic) NSMutableArray<NSDictionary *> *versionCheckResults;
@end

@implementation ProfileInstalledItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = YES;
    [AmethystBlurView installInView:self.view];

    NSString *title;
    NSString *placeholder;
    if ([_category isEqualToString:InstalledItemCategoryResourcePack]) {
        title = @"Resource Packs";
        placeholder = @"paintpalette";
    } else if ([_category isEqualToString:InstalledItemCategoryShaderPack]) {
        title = @"Shader Packs";
        placeholder = @"paintbrush.pointed";
    } else {
        title = @"Mods";
        placeholder = @"puzzlepiece.extension";
    }
    self.navigationItem.title = title;
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = [NSString stringWithFormat:@"No %@ installed.", title.lowercaseString];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 64;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[InstalledItemCell class] forCellReuseIdentifier:kItemCell];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadItems];
}

- (void)loadItems {
    [_spinner startAnimating];
    _tableView.hidden = YES;
    _emptyLabel.hidden = YES;

    _manifestItems = [[InstalledModsManager shared] allInstalledForCategory:_category];

    // Scan directory for orphan files (installed manually, not through launcher)
    NSString *dir = [self dirForCategory];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSMutableArray *orphanNames = [NSMutableArray array];
    NSSet *manifestFilenames = [NSSet setWithArray:[_manifestItems valueForKey:@"filename"]];
    for (NSString *f in files) {
        if ([f isEqualToString:kInstalledModsManifestName]) continue;
        if ([f hasSuffix:@".jar"] || [f hasSuffix:@".zip"]) {
            if (![manifestFilenames containsObject:f]) {
                [orphanNames addObject:f];
            }
        }
    }

    NSMutableArray *orphanItems = [NSMutableArray array];
    for (NSString *name in orphanNames) {
        [orphanItems addObject:@{
            @"title": [name stringByDeletingPathExtension],
            @"filename": name,
            @"version_number": @"",
            @"icon_url": @"",
            @"source": @"",
            @"category": _category,
            @"isOrphan": @YES,
        }];
    }
    _orphanFiles = orphanItems;

    [_spinner stopAnimating];

    if (_manifestItems.count + _orphanFiles.count == 0) {
        _emptyLabel.hidden = NO;
        _tableView.hidden = YES;
    } else {
        _tableView.hidden = NO;
        _emptyLabel.hidden = YES;
        [_tableView reloadData];
    }

    // Check for updates on background
    [self checkForUpdates];
}

static NSString * const kInstalledModsManifestName = @"installed_mods.json";

- (NSString *)dirForCategory {
    if ([_category isEqualToString:InstalledItemCategoryResourcePack]) {
        return [[InstalledModsManager shared] resourcePacksDirForCurrentProfile];
    } else if ([_category isEqualToString:InstalledItemCategoryShaderPack]) {
        return [[InstalledModsManager shared] shaderPacksDirForCurrentProfile];
    }
    return [[InstalledModsManager shared] modsDirForCurrentProfile];
}

#pragma mark - Update checking (batch + cache)

- (void)checkForUpdates {
    _versionCheckResults = [NSMutableArray arrayWithCapacity:_manifestItems.count];
    for (NSUInteger i = 0; i < _manifestItems.count; i++) {
        [_versionCheckResults addObject:@{@"status": @"checking"}];
    }
    [_tableView reloadData];
    
    // Get current profile's MC version and mod loader for filtering
    VersionProfile *currentProfile = VersionDirectoryManager.shared.currentProfile;
    NSString *targetVersion = currentProfile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
    NSString *targetLoader = [currentProfile.modLoader lowercaseString] ?: [getPrefObject(@"internal.mod_loader") lowercaseString] ?: @"";
    if ([targetLoader isEqualToString:@"vanilla"]) targetLoader = @"";
    
    // Collect all project IDs that have a valid project_id
    NSMutableArray *projectIds = [NSMutableArray array];
    NSMutableArray *indices = [NSMutableArray array]; // map back to manifestItems index
    for (NSUInteger i = 0; i < _manifestItems.count; i++) {
        NSDictionary *item = _manifestItems[i];
        NSString *pid = item[@"project_id"];
        if (pid && pid.length > 0) {
            [projectIds addObject:pid];
            [indices addObject:@(i)];
        } else {
            _versionCheckResults[i] = @{@"status": @"none"};
        }
    }
    
    if (projectIds.count == 0) {
        [_tableView reloadData];
        return;
    }
    
    // Single batch call to get latest versions for ALL projects
    __weak typeof(self) weakSelf = self;
    [ModrinthService.shared loadLatestVersionsForProjects:projectIds completion:^(NSDictionary<NSString *,NSDictionary *> *versionsMap, NSError *error) {
        if (error || !versionsMap) {
            // On error, mark all as "none" — don't crash
            for (NSUInteger i = 0; i < weakSelf.manifestItems.count; i++) {
                if ([weakSelf.versionCheckResults[i][@"status"] isEqualToString:@"checking"]) {
                    weakSelf.versionCheckResults[i] = @{@"status": @"none"};
                }
            }
            [weakSelf.tableView reloadData];
            return;
        }
        
        for (NSUInteger j = 0; j < indices.count; j++) {
            NSUInteger idx = [indices[j] unsignedIntegerValue];
            NSDictionary *item = weakSelf.manifestItems[idx];
            NSString *pid = item[@"project_id"];
            NSString *currentVersion = item[@"version_number"];
            
            NSDictionary *latestVersion = versionsMap[pid];
            if (!latestVersion) {
                weakSelf.versionCheckResults[idx] = @{@"status": @"none"};
                continue;
            }
            
            // Check compatibility with current profile
            NSArray *gameVersions = latestVersion[@"game_versions"] ?: @[];
            NSArray *loaders = latestVersion[@"loaders"] ?: @[];
            
            BOOL versionCompatible = targetVersion.length == 0 || [gameVersions containsObject:targetVersion];
            BOOL loaderCompatible = targetLoader.length == 0 || [loaders containsObject:targetLoader];
            
            if (!versionCompatible || !loaderCompatible) {
                // Latest version not compatible with current profile
                weakSelf.versionCheckResults[idx] = @{
                    @"status": @"incompatible",
                    @"latest_version": latestVersion[@"version_number"] ?: @"",
                    @"reason": [NSString stringWithFormat:localize(@"profiles.reason_incompatible", nil),
                        [gameVersions componentsJoinedByString:@", "],
                        [loaders componentsJoinedByString:@", "]]
                };
                continue;
            }
            
            NSString *latestVersionNumber = latestVersion[@"version_number"] ?: @"";
            if (currentVersion.length > 0 && ![latestVersionNumber isEqualToString:currentVersion]) {
                weakSelf.versionCheckResults[idx] = @{
                    @"status": @"update",
                    @"latest_version": latestVersionNumber,
                    @"latest_url": latestVersion[@"url"] ?: @"",
                    @"latest_filename": latestVersion[@"filename"] ?: @"",
                };
            } else {
                weakSelf.versionCheckResults[idx] = @{
                    @"status": @"latest",
                    @"latest_version": latestVersionNumber,
                };
            }
        }
        [weakSelf.tableView reloadData];
    }];
}

#pragma mark - Toggle (enable/disable mod)

- (void)toggleMod:(NSDictionary *)item enabled:(BOOL)enabled {
    [HapticManager.shared play:HapticTypeLight];
    NSString *filename = item[@"filename"];
    if (!filename || filename.length == 0) return;

    NSString *dir = [self dirForCategory];
    if (enabled) {
        // .jar.off -> .jar
        NSString *offPath = [dir stringByAppendingPathComponent:[filename stringByAppendingString:@".off"]];
        NSString *onPath = [dir stringByAppendingPathComponent:filename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:offPath]) {
            [[NSFileManager defaultManager] moveItemAtPath:offPath toPath:onPath error:nil];
        }
    } else {
        // .jar -> .jar.off
        NSString *onPath = [dir stringByAppendingPathComponent:filename];
        NSString *offPath = [dir stringByAppendingPathComponent:[filename stringByAppendingString:@".off"]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:onPath]) {
            [[NSFileManager defaultManager] moveItemAtPath:onPath toPath:offPath error:nil];
        }
    }
}

#pragma mark - Update / Reinstall

- (void)updateItem:(NSDictionary *)item sender:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeMedium];
    NSString *projectId = item[@"project_id"];
    if (!projectId || projectId.length == 0) return;

    InstalledItemCell *cell = (InstalledItemCell *)sender.superview.superview;
    [cell setChecking:YES];

    [self installWithDependenciesForItem:item isUpdate:YES];
}

- (void)reinstallItem:(NSDictionary *)item sender:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeMedium];
    NSString *projectId = item[@"project_id"];
    if (!projectId || projectId.length == 0) {
        showDialog(@"Error", @"This item was not installed through the launcher.");
        return;
    }

    InstalledItemCell *cell = (InstalledItemCell *)sender.superview.superview;
    [cell setChecking:YES];

    [self installWithDependenciesForItem:item isUpdate:NO];
}

- (void)installWithDependenciesForItem:(NSDictionary *)item isUpdate:(BOOL)isUpdate {
    NSString *projectId = item[@"project_id"];
    if (!projectId) {
        [self downloadAndReplaceItem:item url:item[@"latest_url"] ?: item[@"url"] filename:item[@"latest_filename"] ?: item[@"filename"] versionNumber:item[@"latest_version"] ?: item[@"version_number"] sender:nil];
        return;
    }

    VersionProfile *currentProfile = VersionDirectoryManager.shared.currentProfile;
    NSString *mcVersion = currentProfile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
    NSString *loader = currentProfile.modLoader ?: [getPrefObject(@"internal.mod_loader") lowercaseString] ?: @"fabric";

    [HapticManager.shared play:HapticTypeMedium];

    UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:localize(@"profiles.deps_analyzing", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidesWhenStopped = NO;
    [spinner startAnimating];
    [loadingAlert.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:loadingAlert.view.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:loadingAlert.view.topAnchor constant:60],
        [spinner.widthAnchor constraintEqualToConstant:40],
        [spinner.heightAnchor constraintEqualToConstant:40],
        [loadingAlert.view.heightAnchor constraintGreaterThanOrEqualToConstant:100],
    ]];
    [self presentViewController:loadingAlert animated:YES completion:nil];

    __weak typeof(self) weakSelf = self;
    [[DependencyResolver shared] resolveDependenciesForProjectId:projectId source:item[@"source"] ?: @"modrinth" targetVersion:mcVersion targetLoader:loader completion:^(NSArray<NSDictionary *> *deps, NSError *error) {
        [weakSelf handleDependencyResolution:deps error:error item:item isUpdate:isUpdate loadingAlert:loadingAlert];
    }];
}

- (void)handleDependencyResolution:(NSArray<NSDictionary *> *)deps error:(NSError *)error item:(NSDictionary *)item isUpdate:(BOOL)isUpdate loadingAlert:(UIAlertController *)loadingAlert {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [loadingAlert dismissViewControllerAnimated:YES completion:^{
            if (error) {
                [weakSelf showAlert:localize(@"Error", nil) message:[NSString stringWithFormat:localize(@"profiles.deps_load_fail", nil), error.localizedDescription]];
                return;
            }

            NSMutableArray *downloadItems = [NSMutableArray array];

            for (NSDictionary *dep in deps) {
                if (![weakSelf isAlreadyInstalled:dep[@"project_id"]]) {
                    [downloadItems addObject:@{
                        @"url": dep[@"url"],
                        @"name": dep[@"title"],
                        @"filename": dep[@"filename"],
                        @"targetPath": [[VersionDirectoryManager.shared modsPathForVersion:VersionDirectoryManager.shared.currentVersion] stringByAppendingPathComponent:dep[@"filename"]],
                        @"identifier": dep[@"project_id"],
                        @"type": @(DownloadTypeDependency),
                        @"isMain": @NO,
                        @"icon_url": dep[@"icon_url"],
                        @"project_id": dep[@"project_id"],
                        @"version_number": dep[@"version"],
                    }];
                }
            }

            // Add main mod
            NSString *filename = isUpdate ? (item[@"latest_filename"] ?: item[@"filename"]) : item[@"filename"];
            NSString *url = isUpdate ? (item[@"latest_url"] ?: item[@"url"]) : item[@"url"];
            NSString *versionNumber = isUpdate ? (item[@"latest_version"] ?: item[@"version_number"]) : item[@"version_number"];

            [downloadItems insertObject:@{
                @"url": url,
                @"name": item[@"title"],
                @"filename": filename,
                @"targetPath": [[VersionDirectoryManager.shared modsPathForVersion:VersionDirectoryManager.shared.currentVersion] stringByAppendingPathComponent:filename],
                @"identifier": item[@"project_id"],
                @"type": @(DownloadTypeMod),
                @"isMain": @YES,
                @"icon_url": item[@"icon_url"],
                @"project_id": item[@"project_id"],
                @"version_number": versionNumber,
            } atIndex:0];

            if (downloadItems.count == 1) {
                [weakSelf downloadAndReplaceItem:item url:url filename:filename versionNumber:versionNumber sender:nil];
            } else {
                DependencyDownloadViewController *depVC = [[DependencyDownloadViewController alloc] initWithMainModTitle:item[@"title"] items:downloadItems groupIdentifier:item[@"project_id"]];
                depVC.delegate = weakSelf;
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:depVC];
                [weakSelf presentViewController:nav animated:YES completion:nil];
            }
        }];
    });
}

- (BOOL)isAlreadyInstalled:(NSString *)projectId {
    if (!projectId) return NO;
    return [[DependencyResolver shared] isProjectInstalled:projectId category:_category];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)downloadAndReplaceItem:(NSDictionary *)item url:(NSString *)url filename:(NSString *)filename versionNumber:(NSString *)versionNumber sender:(UIButton *)sender {
    NSString *dir = [self dirForCategory];
    NSString *targetPath = [dir stringByAppendingPathComponent:filename];

    DownloadTask *hubTask = [[DownloadManager shared] beginTaskWithName:item[@"title"] ?: filename type:DownloadTypeMod];
    __weak typeof(self) weakSelf = self;
    [hubTask setCancelBlock:^{}];

    [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [[DownloadManager shared] updateProgress:p forTask:hubTask];
    } completion:^(NSString *dlPath, NSError *dlError) {
        [[DownloadManager shared] completeTask:hubTask error:dlError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!dlPath) return;
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:dlPath toPath:targetPath error:nil];

            [[InstalledModsManager shared] recordProjectId:item[@"project_id"]
                                                      title:item[@"title"]
                                             versionNumber:versionNumber
                                                   filename:filename
                                                    iconURL:item[@"icon_url"]
                                                     source:item[@"source"]
                                                   category:weakSelf.category];
            [weakSelf loadItems];
        });
    }];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _manifestItems.count + _orphanFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    InstalledItemCell *cell = [tableView dequeueReusableCellWithIdentifier:kItemCell forIndexPath:indexPath];

    BOOL isOrphan = indexPath.row >= (NSInteger)_manifestItems.count;
    NSDictionary *item;
    if (isOrphan) {
        item = _orphanFiles[indexPath.row - _manifestItems.count];
    } else {
        item = _manifestItems[indexPath.row];
    }

    [cell configureWithItem:item category:_category];

    // Determine if mod is enabled (file exists without .off)
    if ([_category isEqualToString:InstalledItemCategoryMod]) {
        NSString *dir = [self dirForCategory];
        NSString *filename = item[@"filename"];
        NSString *onPath = [dir stringByAppendingPathComponent:filename];
        NSString *offPath = [dir stringByAppendingPathComponent:[filename stringByAppendingString:@".off"]];
        BOOL isOn = [[NSFileManager defaultManager] fileExistsAtPath:onPath];
        BOOL isOff = [[NSFileManager defaultManager] fileExistsAtPath:offPath];
        cell.enabledSwitch.hidden = NO;
        cell.enabledSwitch.on = (isOn || !isOff);

        __weak typeof(self) weakSelf = self;
        cell.onToggle = ^(NSDictionary *itemData, BOOL enabled) {
            [weakSelf toggleMod:itemData enabled:enabled];
        };
    } else {
        cell.enabledSwitch.hidden = YES;
    }

    // Action button
    if (isOrphan) {
        [cell setActionTitle:@"?" color:ThemeManager.shared.secondaryTextColor];
        cell.actionButton.hidden = YES;
    } else if (indexPath.row < (NSInteger)_versionCheckResults.count) {
        NSDictionary *status = _versionCheckResults[indexPath.row];
        NSString *st = status[@"status"];
        if ([st isEqualToString:@"checking"]) {
            [cell setChecking:YES];
            cell.onAction = nil;
        } else if ([st isEqualToString:@"update"]) {
            [cell setActionTitle:@"↑ Update" color:ThemeManager.shared.warningColor];
            __weak typeof(self) weakSelf = self;
            cell.onAction = ^(NSDictionary *itemData, UIButton *sender) {
                [weakSelf updateItem:itemData sender:sender];
            };
        } else if ([st isEqualToString:@"latest"]) {
            [cell setActionTitle:@"Reinstall" color:ThemeManager.shared.accentColor];
            __weak typeof(self) weakSelf = self;
            cell.onAction = ^(NSDictionary *itemData, UIButton *sender) {
                [weakSelf reinstallItem:itemData sender:sender];
            };
        } else if ([st isEqualToString:@"incompatible"]) {
            [cell setActionTitle:localize(@"profiles.incompatible", nil) color:ThemeManager.shared.errorColor];
            cell.onAction = nil;
        } else {
            [cell hideAction];
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Theme

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    if ([AmethystBlurView blurEnabled]) {
        self.view.backgroundColor = [UIColor clearColor];
    } else {
        self.view.backgroundColor = theme.contentBackgroundColor;
    }
    _emptyLabel.textColor = theme.secondaryTextColor;
    _tableView.backgroundColor = [UIColor clearColor];
}

#pragma mark - DependencyDownloadViewControllerDelegate

- (void)dependencyDownloadDidComplete:(DependencyDownloadViewController *)controller success:(BOOL)allSuccess {
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (allSuccess) {
        [self showAlert:localize(@"profiles.success", nil) message:localize(@"profiles.install_success", nil)];
    } else {
        [self showAlert:localize(@"Warning", nil) message:localize(@"profiles.install_partial", nil)];
    }
    [self loadItems];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
