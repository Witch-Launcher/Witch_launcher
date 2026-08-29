#import "VersionBrowserViewController.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "InstallerProgressViewController.h"
#import "JavaGUIViewController.h"
#import "ios_uikit_bridge.h"
#import "VersionDirectoryManager.h"
#import "UnzipKit.h"
#import "AmethystBlurView.h"
#import "utils.h"

@interface VersionBrowserViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic) UISegmentedControl *typeFilter;
@property (nonatomic) UIButton *loaderButton;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) UILabel *statusLabel;

@property (nonatomic) NSArray *allVersions;
@property (nonatomic) NSArray *filteredVersions;
@property (nonatomic) NSString *selectedLoader;
@property (nonatomic) NSArray *loaderVersions;
@property (nonatomic) NSString *selectedMCVersion;
@property (nonatomic) NSUInteger fetchSequenceID;
@end

static NSArray *kLoaders;

@implementation VersionBrowserViewController

+ (void)initialize {
    if (self == [VersionBrowserViewController self]) {
        kLoaders = @[@"Vanilla", @"Fabric", @"Forge", @"Quilt", @"NeoForge"];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _selectedLoader = @"Vanilla";
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [self fetchVersions];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)setup {
    self.navigationItem.title = @"Game Versions";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Execute .jar" style:UIBarButtonItemStylePlain target:self action:@selector(importJar)];

    _typeFilter = [[UISegmentedControl alloc] initWithItems:@[@"Release", @"Snapshot", @"Old"]];
    _typeFilter.translatesAutoresizingMaskIntoConstraints = NO;
    _typeFilter.selectedSegmentIndex = 0;
    [_typeFilter addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_typeFilter];

    _loaderButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _loaderButton.translatesAutoresizingMaskIntoConstraints = NO;
    _loaderButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _loaderButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    _loaderButton.layer.cornerRadius = 8;
    _loaderButton.layer.borderWidth = 1;
    [_loaderButton addTarget:self action:@selector(pickLoader) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_loaderButton];
    [self updateLoaderButton];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 0;
    [self.view addSubview:_statusLabel];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 56;
    [self.view addSubview:_tableView];

    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"VersionCell"];

    [NSLayoutConstraint activateConstraints:@[
        [_typeFilter.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_typeFilter.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [_loaderButton.topAnchor constraintEqualToAnchor:_typeFilter.bottomAnchor constant:8],
        [_loaderButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [_statusLabel.topAnchor constraintEqualToAnchor:_loaderButton.bottomAnchor constant:4],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:8],

        [_tableView.topAnchor constraintEqualToAnchor:_spinner.bottomAnchor constant:4],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _typeFilter.selectedSegmentTintColor = theme.accentColor;
    _loaderButton.tintColor = theme.primaryTextColor;
    _loaderButton.backgroundColor = theme.cardBackgroundColor;
    _loaderButton.layer.borderColor = theme.separatorColor.CGColor;
    _statusLabel.textColor = theme.secondaryTextColor;
}

- (void)updateLoaderButton {
    [_loaderButton setTitle:[NSString stringWithFormat:@"Mod Loader: %@", _selectedLoader] forState:UIControlStateNormal];
}

#pragma mark - Fetch versions

- (void)fetchVersions {
    [_spinner startAnimating];
    _statusLabel.text = localize(@"version.fetching", nil);
    _tableView.hidden = YES;

    NSURL *manifestURL = [NSURL URLWithString:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"];
    [[NSURLSession.sharedSession dataTaskWithURL:manifestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (error || !data) {
                self.statusLabel.text = [NSString stringWithFormat:@"Error: %@", error.localizedDescription ?: @"Failed to fetch"];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            self.allVersions = json[@"versions"] ?: @[];
            [self filterChanged];
        });
    }] resume];
}

- (void)filterChanged {
    NSString *targetType = @"release";
    switch (_typeFilter.selectedSegmentIndex) {
        case 1: targetType = @"snapshot"; break;
        case 2: targetType = @"old_beta"; break;
    }

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *v in _allVersions) {
        NSString *type = v[@"type"] ?: @"";
        if ([type isEqualToString:targetType] ||
            (_typeFilter.selectedSegmentIndex == 2 && ([type isEqualToString:@"old_beta"] || [type isEqualToString:@"old_alpha"]))) {
            [filtered addObject:v];
        }
    }
    _filteredVersions = filtered;
    _loaderVersions = nil;
    _selectedMCVersion = nil;
    [_tableView reloadData];
    _tableView.hidden = NO;
    _statusLabel.text = [NSString stringWithFormat:@"%lu versions | Loader: %@", (unsigned long)_filteredVersions.count, _selectedLoader];
}

#pragma mark - Loader Picker

- (void)pickLoader {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Select Mod Loader"
                                                                   message:@"Choose a mod loader to combine with Minecraft version"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *loader in kLoaders) {
        BOOL isSelected = [loader isEqualToString:_selectedLoader];
        NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", loader] : loader;
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedLoader = loader;
            [self updateLoaderButton];
            [self filterChanged];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    sheet.popoverPresentationController.sourceView = _loaderButton;
    sheet.popoverPresentationController.sourceRect = _loaderButton.bounds;

    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Fetch loader versions for a MC version

- (void)fetchLoaderVersionsForMCVersion:(NSString *)mcVersion {
    NSUInteger currentSequence = ++self.fetchSequenceID;
    [_spinner startAnimating];
    _selectedMCVersion = mcVersion;
    _statusLabel.text = [NSString stringWithFormat:@"Fetching %@ versions for %@...", _selectedLoader, mcVersion];
    _loaderVersions = nil;
    [_tableView reloadData];

    NSString *apiURL = nil;
    if ([_selectedLoader isEqualToString:@"Fabric"]) {
        apiURL = [NSString stringWithFormat:@"https://meta.fabricmc.net/v2/versions/loader/%@", mcVersion];
    } else if ([_selectedLoader isEqualToString:@"Quilt"]) {
        apiURL = [NSString stringWithFormat:@"https://meta.quiltmc.org/v3/versions/loader/%@", mcVersion];
    } else if ([_selectedLoader isEqualToString:@"Forge"]) {
        apiURL = [NSString stringWithFormat:@"https://bmclapi2.bangbang93.com/forge/minecraft/%@", mcVersion];
    } else if ([_selectedLoader isEqualToString:@"NeoForge"]) {
        apiURL = @"https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge";
    }

    if (!apiURL) {
        [self.spinner stopAnimating];
        _statusLabel.text = localize(@"version.unknown_loader", nil);
        return;
    }

    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:apiURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (currentSequence != self.fetchSequenceID) return;
            [self.spinner stopAnimating];
            if (error || !data) {
                self.statusLabel.text = [NSString stringWithFormat:@"Error fetching %@ versions: %@", self.selectedLoader, error.localizedDescription ?: @"No data"];
                return;
            }
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSMutableArray *loaderVersions = [NSMutableArray array];
            if ([self.selectedLoader isEqualToString:@"Fabric"] && [json isKindOfClass:[NSArray class]]) {
                for (id entryObj in json) {
                    NSDictionary *entry = entryObj;
                    if (![entry isKindOfClass:[NSDictionary class]]) continue;
                    NSString *loaderVer = [entry[@"loader"] isKindOfClass:[NSDictionary class]] ? entry[@"loader"][@"version"] : @"";
                    if (loaderVer.length == 0) continue;
                    BOOL stable = [entry[@"loader"][@"stable"] boolValue];
                    NSString *fullName = [NSString stringWithFormat:@"fabric-loader-%@-%@", loaderVer, mcVersion];
                    [loaderVersions addObject:@{
                        @"name": fullName,
                        @"version": loaderVer,
                        @"mc_version": mcVersion,
                        @"stable": @(stable),
                        @"download_url": [NSString stringWithFormat:@"https://meta.fabricmc.net/v2/versions/loader/%@/%@/profile/json", mcVersion, loaderVer]
                    }];
                }
            } else if ([self.selectedLoader isEqualToString:@"Quilt"] && [json isKindOfClass:[NSArray class]]) {
                for (id entryObj in json) {
                    NSDictionary *entry = entryObj;
                    if (![entry isKindOfClass:[NSDictionary class]]) continue;
                    NSString *loaderVer = [entry[@"loader"] isKindOfClass:[NSDictionary class]] ? entry[@"loader"][@"version"] : @"";
                    if (loaderVer.length == 0) continue;
                    NSString *fullName = [NSString stringWithFormat:@"quilt-loader-%@-%@", loaderVer, mcVersion];
                    [loaderVersions addObject:@{
                        @"name": fullName,
                        @"version": loaderVer,
                        @"mc_version": mcVersion,
                        @"stable": @YES,
                        @"download_url": [NSString stringWithFormat:@"https://meta.quiltmc.org/v3/versions/loader/%@/%@/profile/json", mcVersion, loaderVer]
                    }];
                }
            } else if ([self.selectedLoader isEqualToString:@"Forge"]) {
                if ([json isKindOfClass:[NSArray class]]) {
                    for (id entryObj in json) {
                        if ([entryObj isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *entry = entryObj;
                            NSString *ver = entry[@"version"] ?: @"";
                            if (ver.length == 0) continue;
                            [loaderVersions addObject:@{
                                @"name": [NSString stringWithFormat:@"forge-%@-%@", mcVersion, ver],
                                @"version": ver,
                                @"mc_version": mcVersion,
                                @"stable": @YES,
                                @"download_url": [NSString stringWithFormat:@"https://maven.minecraftforge.net/net/minecraftforge/forge/%@-%@/forge-%@-%@-installer.jar", mcVersion, ver, mcVersion, ver]
                            }];
                        } else if ([entryObj isKindOfClass:[NSString class]]) {
                            NSString *ver = (NSString *)entryObj;
                            [loaderVersions addObject:@{
                                @"name": [NSString stringWithFormat:@"forge-%@-%@", mcVersion, ver],
                                @"version": ver,
                                @"mc_version": mcVersion,
                                @"stable": @YES,
                                @"download_url": [NSString stringWithFormat:@"https://maven.minecraftforge.net/net/minecraftforge/forge/%@-%@/forge-%@-%@-installer.jar", mcVersion, ver, mcVersion, ver]
                            }];
                        }
                    }
                }
            } else if ([self.selectedLoader isEqualToString:@"NeoForge"]) {
                // NeoForge official API returns {"versions": ["21.4.1", "21.4.2", ...]}
                // MC 1.X.Y maps to NeoForge version prefix "X.Y"
                NSString *neoPrefix = @"";
                NSArray *mcParts = [mcVersion componentsSeparatedByString:@"."];
                if (mcParts.count >= 3) {
                    neoPrefix = [NSString stringWithFormat:@"%@.%@", mcParts[1], mcParts[2]];
                } else if (mcParts.count == 2) {
                    neoPrefix = mcParts[1];
                }

                NSArray *allVersions = nil;
                if ([json isKindOfClass:[NSDictionary class]]) {
                    allVersions = json[@"versions"];
                } else if ([json isKindOfClass:[NSArray class]]) {
                    allVersions = (NSArray *)json;
                }

                if ([allVersions isKindOfClass:[NSArray class]]) {
                    for (id verObj in allVersions) {
                        NSString *ver = [verObj isKindOfClass:[NSString class]] ? verObj : [verObj description];
                        // Filter: NeoForge version must start with the MC version prefix
                        if (neoPrefix.length > 0 && ![ver hasPrefix:neoPrefix]) continue;
                        NSString *downloadURL = [NSString stringWithFormat:@"https://maven.neoforged.net/releases/net/neoforged/neoforge/%@/neoforge-%@-installer.jar", ver, ver];
                        [loaderVersions addObject:@{
                            @"name": [NSString stringWithFormat:@"neoforge-%@-%@", mcVersion, ver],
                            @"version": ver,
                            @"mc_version": mcVersion,
                            @"stable": @YES,
                            @"download_url": downloadURL
                        }];
                    }
                    // Sort descending (newest first)
                    [loaderVersions sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                        return [b[@"version"] compare:a[@"version"] options:NSNumericSearch];
                    }];
                }
            }
            self.loaderVersions = loaderVersions;
            self.statusLabel.text = [NSString stringWithFormat:@"%@ %@: %lu versions available", mcVersion, self.selectedLoader, (unsigned long)loaderVersions.count];
            [self.tableView reloadData];
        });
    }] resume];
}

#pragma mark - Download version

- (void)downloadVersionProfile:(NSString *)urlStr named:(NSString *)name {
    [_spinner startAnimating];
    _statusLabel.text = [NSString stringWithFormat:@"Downloading %@...", name];

    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (error || !data) {
                self.statusLabel.text = [NSString stringWithFormat:@"Download failed: %@", error.localizedDescription ?: @"No data"];
                return;
            }

            NSData *versionData = data;
            NSString *finalName = name;

            // Forge/NeoForge entries download an installer JAR, not a version profile
            // JSON; anything else (vanilla/fabric/quilt) is a plain profile JSON.
            BOOL looksLikeInstaller = [name hasPrefix:@"neoforge-"] || [name containsString:@"-forge-"];

            // For Forge/NeoForge installers we keep the installer jar around and run it
            // headless (--installClient) in the embedded JVM after writing the profile,
            // so the patched client jar + libraries actually get produced.
            NSString *installerPath = nil;
            NSString *installerVersionId = nil;

            // Check if this is a Forge/NeoForge installer JAR (ZIP with PK header)
            const uint8_t *bytes = (const uint8_t *)data.bytes;
            if (data.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
                self.statusLabel.text = [NSString stringWithFormat:@"Processing %@ installer...", name];
                NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_installer.jar", name]];
                [data writeToFile:tmpPath atomically:NO];

                NSError *uzError;
                UZKArchive *archive = [[UZKArchive alloc] initWithPath:tmpPath error:&uzError];
                if (!uzError) {
                    NSData *profileData = [archive extractDataFromFile:@"install_profile.json" error:&uzError];
                    if (!uzError && profileData) {
                        NSDictionary *profileJson = [NSJSONSerialization JSONObjectWithData:profileData options:0 error:nil];
                        if ([profileJson isKindOfClass:[NSDictionary class]]) {
                            // Forge/NeoForge install_profile.json
                            // Legacy (<=1.12.2): versionInfo dictionary
                            NSDictionary *versionInfo = profileJson[@"versionInfo"];
                            if ([versionInfo isKindOfClass:[NSDictionary class]]) {
                                NSError *writeError;
                                versionData = [NSJSONSerialization dataWithJSONObject:versionInfo options:0 error:&writeError];
                            } else if ([profileJson[@"json"] isKindOfClass:[NSString class]]) {
                                NSString *jsonStr = profileJson[@"json"];
                                if ([jsonStr hasPrefix:@"/"]) {
                                    // Modern Forge/NeoForge (1.17+): json field is the path
                                    // to version.json INSIDE the installer jar
                                    NSData *innerJson = [archive extractDataFromFile:[jsonStr substringFromIndex:1] error:&uzError];
                                    if (!uzError && innerJson) {
                                        versionData = innerJson;
                                    }
                                } else {
                                    // Older Forge (1.13-1.16): json field contains the version json string
                                    versionData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                                }
                            } else if ([profileJson[@"json"] isKindOfClass:[NSDictionary class]]) {
                                versionData = [NSJSONSerialization dataWithJSONObject:profileJson[@"json"] options:0 error:nil];
                            } else if ([profileJson[@"install"] isKindOfClass:[NSDictionary class]] &&
                                       [profileJson[@"install"][@"versionInfo"] isKindOfClass:[NSDictionary class]]) {
                                // Forge 1.17+ (install.versionInfo format)
                                versionData = [NSJSONSerialization dataWithJSONObject:profileJson[@"install"][@"versionInfo"] options:0 error:nil];
                            } else {
                                // Fallback: use whole profile as version data
                                id possibleInfo = profileJson;
                                if ([possibleInfo isKindOfClass:[NSDictionary class]]) {
                                    versionData = [NSJSONSerialization dataWithJSONObject:possibleInfo options:0 error:nil];
                                }
                            }
                        }
                    }
                }

                // The real version id comes from the version JSON the installer will
                // write (e.g. "1.20.1-forge-47.3.0"); use it so our profile lands in
                // the same versions/<id> directory the installer uses.
                NSDictionary *parsedInfo = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
                if ([parsedInfo isKindOfClass:[NSDictionary class]]) {
                    id vId = parsedInfo[@"id"];
                    if ([vId isKindOfClass:[NSString class]] && [vId length] > 0) {
                        installerVersionId = vId;
                    }
                }

                if (installerVersionId.length > 0) {
                    // Keep the installer for the headless install run below
                    NSString *installersDir = [NSString stringWithFormat:@"%s/installers", getenv("POJAV_HOME") ?: ""];
                    if (installersDir.length > [@"/installers" length]) {
                        [[NSFileManager defaultManager] createDirectoryAtPath:installersDir withIntermediateDirectories:YES attributes:nil error:nil];
                        installerPath = [installersDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-installer.jar", name]];
                        [[NSFileManager defaultManager] removeItemAtPath:installerPath error:nil];
                        [data writeToFile:installerPath atomically:YES];
                    }
                }
                [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
                if (installerVersionId.length == 0) {
                    self.statusLabel.text = [NSString stringWithFormat:@"Download failed: invalid installer jar (%@)", name];
                    [self.tableView reloadData];
                    return;
                }
            } else if (looksLikeInstaller) {
                // The server did not return a real installer jar (e.g. 404/400 page).
                // Never fabricate a profile from garbage in this case.
                self.statusLabel.text = [NSString stringWithFormat:@"Download failed: server did not return an installer jar for %@", name];
                [self.tableView reloadData];
                return;
            }

            VersionDirectoryManager *mgr = VersionDirectoryManager.shared;
            if (installerPath) {
                // Forge/NeoForge: DO NOT pre-create a version profile. Run the installer
                // through the progress UI (InstallerProgressViewController); the installer
                // itself writes versions/<id>/<id>.json, the patched client jar and
                // libraries. requiredJavaVersion picks the right runtime from the
                // installer's own bytecode, so no manual min-version needed here.
                NSString *installDir = [NSString stringWithFormat:@"%s/instances/%@",
                    getenv("POJAV_HOME") ?: "", mgr.currentInstance ?: @"default"];
                self.statusLabel.text = [NSString stringWithFormat:@"Installing %@ ...", installerVersionId ?: name];
                [InstallerProgressViewController presentInstallerFrom:self
                    jarPath:installerPath
                    title:[NSString stringWithFormat:@"Installing %@", installerVersionId ?: name]
                    jvmArgs:@[@"--installClient", installDir]
                    completion:^(BOOL success, BOOL cancelled, int exitCode) {
                        if (success) {
                            self.statusLabel.text = [NSString stringWithFormat:@"✓ %@ installed!", installerVersionId ?: name];
                        } else if (cancelled) {
                            self.statusLabel.text = [NSString stringWithFormat:@"Install cancelled: %@", installerVersionId ?: name];
                        } else {
                            self.statusLabel.text = [NSString stringWithFormat:@"Install failed: %@", installerVersionId ?: name];
                        }
                        [self.tableView reloadData];
                        UIKit_returnToSplitView();
                    }];
                [self.tableView reloadData];
                return;
            }

            NSString *versionDir = [mgr versionPathForVersion:finalName];
            int counter = 1;
            while ([[NSFileManager defaultManager] fileExistsAtPath:versionDir]) {
                finalName = [NSString stringWithFormat:@"%@-%d", finalName, counter++];
                versionDir = [mgr versionPathForVersion:finalName];
            }
            [[NSFileManager defaultManager] createDirectoryAtPath:versionDir withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *jsonPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", finalName]];

            if ([NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil] == nil) {
                self.statusLabel.text = [NSString stringWithFormat:@"Failed to parse version profile: %@", finalName];
                return;
            }
            [versionData writeToFile:jsonPath atomically:YES];

            VersionDirectoryManager.shared.currentVersion = finalName;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{@"version": finalName}];
            self.statusLabel.text = [NSString stringWithFormat:@"✓ %@ installed!", finalName];
            [self.tableView reloadData];
        });
    }] resume];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_selectedMCVersion && _loaderVersions) return _loaderVersions.count;
    return _filteredVersions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VersionCell" forIndexPath:indexPath];
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.layer.cornerRadius = 8;
    cell.clipsToBounds = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;

    if (_selectedMCVersion && _loaderVersions) {
        NSDictionary *lv = _loaderVersions[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@ %@", lv[@"mc_version"], _selectedLoader, lv[@"version"]];
        cell.detailTextLabel.text = [lv[@"stable"] boolValue] ? @"✓ Stable" : @"⚠ Experimental";
        cell.imageView.image = [UIImage systemImageNamed:@"link.circle"];
        cell.imageView.tintColor = ThemeManager.shared.accentColor;
    } else {
        NSDictionary *v = _filteredVersions[indexPath.row];
        cell.textLabel.text = v[@"id"] ?: @"";
        NSString *type = v[@"type"] ?: @"";
        NSString *dateStr = [v[@"releaseTime"] ?: @"" componentsSeparatedByString:@"T"].firstObject ?: @"";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@", [type capitalizedString], dateStr];
        cell.imageView.image = [UIImage systemImageNamed:@"cube.box"];
        cell.imageView.tintColor = ThemeManager.shared.accentColor;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [HapticManager.shared play:HapticTypeLight];

    if (_selectedMCVersion && _loaderVersions) {
        NSDictionary *lv = _loaderVersions[indexPath.row];
        NSString *urlStr = lv[@"download_url"];
        NSString *name = lv[@"name"];
        [self downloadVersionProfile:urlStr named:name];
    } else {
        NSDictionary *v = _filteredVersions[indexPath.row];
        NSString *mcVer = v[@"id"] ?: @"";

        if ([_selectedLoader isEqualToString:@"Vanilla"]) {
            NSString *urlStr = v[@"url"] ?: @"";
            if (urlStr.length > 0) {
                [self downloadVersionProfile:urlStr named:mcVer];
            }
        } else {
            [self fetchLoaderVersionsForMCVersion:mcVer];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Import Jar

- (void)importJar {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    [url startAccessingSecurityScopedResource];

    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *jarDir = [docsDir stringByAppendingPathComponent:@"JarLauncher"];
    [[NSFileManager defaultManager] createDirectoryAtPath:jarDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *destPath = [jarDir stringByAppendingPathComponent:url.lastPathComponent];
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        NSString *base = [url.lastPathComponent stringByDeletingPathExtension];
        NSString *ext = [url.lastPathComponent pathExtension];
        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        destPath = [jarDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.%@", base, timestamp, ext]];
    }

    if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&error]) {
        [url stopAccessingSecurityScopedResource];
        UIView *topView = self.view.window.rootViewController.view;
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Launch JAR"
                                                                        message:[NSString stringWithFormat:@"Launch %@?", url.lastPathComponent]
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Launch" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            JavaGUIViewController *vc = [[JavaGUIViewController alloc] init];
            vc.filepath = destPath;
            [vc setHitEnterAfterWindowShown:YES];
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:vc animated:YES completion:nil];
        }]];

        // If this looks like a Forge/NeoForge installer, offer a headless install that
        // writes versions/<id> itself and then drops back to the home screen.
        NSData *head = [NSData dataWithContentsOfFile:destPath options:NSDataReadingMappedIfSafe error:nil];
        BOOL isInstaller = NO;
        if (head.length > 2) {
            const uint8_t *bytes = (const uint8_t *)head.bytes;
            if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
                NSError *uzError;
                UZKArchive *archive = [[UZKArchive alloc] initWithPath:destPath error:&uzError];
                isInstaller = (!uzError && [archive extractDataFromFile:@"install_profile.json" error:&uzError] != nil);
            }
        }
        if (isInstaller) {
            [confirm addAction:[UIAlertAction actionWithTitle:@"Install (headless)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *installDir = [NSString stringWithFormat:@"%s/instances/%@",
                    getenv("POJAV_HOME") ?: "", VersionDirectoryManager.shared.currentInstance ?: @"default"];
                [InstallerProgressViewController presentInstallerFrom:self
                    jarPath:destPath
                    title:[NSString stringWithFormat:@"Installing %@", destPath.lastPathComponent]
                    jvmArgs:@[@"--installClient", installDir]
                    completion:^(BOOL success, BOOL cancelled, int exitCode) {
                        if (!success && !cancelled) {
                            showDialog(@"Installer Failed", [NSString stringWithFormat:@"The installer exited with code %d. Check the log for details.", exitCode]);
                        }
                        UIKit_returnToSplitView();
                    }];
            }]];
        }

        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:confirm animated:YES completion:nil];
    } else {
        [url stopAccessingSecurityScopedResource];
        showDialog(@"Import Failed", error.localizedDescription ?: @"Unknown error");
    }
}

@end
