#import "ModDetailViewController.h"
#import "ThemeManager.h"
#import "ModrinthService.h"
#import "DownloadProgressOverlay.h"
#import "DownloadManager.h"
#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import "JavaGUIViewController.h"
#import "UIImageView+AFNetworking.h"
#import "UnzipKit.h"
#import "ModpackUtils.h"
#import "PLProfiles.h"
#import "MrpackInstaller.h"
#import "utils.h"
#import "AmethystBlurView.h"

static NSString *readInstallerVersionId(NSString *jarPath) {
    NSError *uzError;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:jarPath error:&uzError];
    if (uzError) return nil;
    NSData *profileData = [archive extractDataFromFile:@"install_profile.json" error:&uzError];
    if (uzError || !profileData) return nil;
    NSDictionary *profileJson = [NSJSONSerialization JSONObjectWithData:profileData options:0 error:nil];
    if (![profileJson isKindOfClass:[NSDictionary class]]) return nil;

    NSData *verData = nil;
    NSDictionary *versionInfo = profileJson[@"versionInfo"];
    if ([versionInfo isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:versionInfo options:0 error:nil];
    } else if ([profileJson[@"json"] isKindOfClass:[NSString class]]) {
        NSString *jsonStr = profileJson[@"json"];
        if ([jsonStr hasPrefix:@"/"]) {
            verData = [archive extractDataFromFile:[jsonStr substringFromIndex:1] error:&uzError];
        } else {
            verData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
        }
    } else if ([profileJson[@"json"] isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:profileJson[@"json"] options:0 error:nil];
    } else if ([profileJson[@"install"] isKindOfClass:[NSDictionary class]] &&
               [profileJson[@"install"][@"versionInfo"] isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:profileJson[@"install"][@"versionInfo"] options:0 error:nil];
    }
    NSDictionary *parsed = verData ? [NSJSONSerialization JSONObjectWithData:verData options:0 error:nil] : nil;
    if ([parsed isKindOfClass:[NSDictionary class]]) {
        id vId = parsed[@"id"];
        if ([vId isKindOfClass:[NSString class]] && [vId length] > 0) return vId;
    }
    return nil;
}

@interface ModDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) NSDictionary *mod;
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *authorLabel;
@property (nonatomic) UILabel *descLabel;
@property (nonatomic) UILabel *downloadsLabel;
@property (nonatomic) UILabel *followsLabel;

@property (nonatomic) UITableView *versionTable;
@property (nonatomic) NSArray *versions;
@property (nonatomic) NSInteger selectedVersionIndex;
@property (nonatomic) NSString *selectedLoader;
@property (nonatomic) NSLayoutConstraint *versionTableHeight;

@property (nonatomic) UIView *actionsContainer;
@property (nonatomic) UIButton *downloadBtn;
@property (nonatomic) UIButton *profileBtn;

@property (nonatomic) UIView *depsContainer;
@property (nonatomic) UILabel *depsHeader;
@property (nonatomic) NSMutableArray *dependencyMods;
@property (nonatomic) NSLayoutConstraint *depsBottom;

@property (nonatomic) BOOL hasLoadedVersions;
@property (nonatomic) BOOL versionsExpanded;
@property (nonatomic) BOOL isModpack;
@property (nonatomic) NSURLSessionDownloadTask *currentDownloadTask;
@property (nonatomic) NSMutableArray *currentModDownloadTasks;

@property (nonatomic) UIButton *mcVersionBtn;
@property (nonatomic) NSString *selectedMcVersion;
@property (nonatomic) NSArray *availableMcVersions;
@end

static NSString *const kVerCell = @"VerCell";

@implementation ModDetailViewController

- (instancetype)initWithMod:(NSDictionary *)mod {
    self = [super init];
    if (self) {
        _mod = mod;
        _selectedVersionIndex = -1;
        [self detectDefaultLoader];
    _dependencyMods = [NSMutableArray array];
    _versionsExpanded = YES;
}
    return self;
}

- (void)detectDefaultLoader {
    _selectedLoader = @"fabric";
    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    if (profile) {
        NSString *loader = [profile.modLoader lowercaseString];
        if (loader.length > 0 && ![loader isEqualToString:@"vanilla"]) {
            _selectedLoader = loader;
            return;
        }
    }
    NSString *internalLoader = [getPrefObject(@"internal.mod_loader") lowercaseString] ?: @"";
    if (internalLoader.length > 0 && ![internalLoader isEqualToString:@"vanilla"]) {
        _selectedLoader = internalLoader;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _mod[@"title"] ?: @"Mod";
    self.view.clipsToBounds = YES;
    [self setupViews];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [self loadVersions];
    // Realtime frosted backdrop behind the whole panel
    [AmethystBlurView installInView:self.view];

}

- (void)setupViews {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:content];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFill;
    _iconView.clipsToBounds = YES;
    _iconView.layer.cornerRadius = 16;
    _iconView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _iconView.image = [UIImage systemImageNamed:@"wrench.and.screwdriver"];
    _iconView.tintColor = ThemeManager.shared.secondaryTextColor;
    [content addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _titleLabel.numberOfLines = 0;
    _titleLabel.text = _mod[@"title"];
    [content addSubview:_titleLabel];

    _authorLabel = [[UILabel alloc] init];
    _authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _authorLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _authorLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _authorLabel.text = [NSString stringWithFormat:@"by %@", _mod[@"author"] ?: @"Unknown"];
    [content addSubview:_authorLabel];

    UIView *statsBar = [[UIView alloc] init];
    statsBar.translatesAutoresizingMaskIntoConstraints = NO;
    statsBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    statsBar.layer.cornerRadius = 8;
    [content addSubview:statsBar];

    _downloadsLabel = [[UILabel alloc] init];
    _downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _downloadsLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _downloadsLabel.textColor = ThemeManager.shared.accentColor;
    _downloadsLabel.textAlignment = NSTextAlignmentCenter;
    _downloadsLabel.text = [NSString stringWithFormat:@"%@ downloads", [self formatNumber:_mod[@"downloads"]]];
    [statsBar addSubview:_downloadsLabel];

    _followsLabel = [[UILabel alloc] init];
    _followsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _followsLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _followsLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _followsLabel.textAlignment = NSTextAlignmentCenter;
    _followsLabel.text = [NSString stringWithFormat:@"%@ follows", [self formatNumber:_mod[@"follows"]]];
    [statsBar addSubview:_followsLabel];

    _descLabel = [[UILabel alloc] init];
    _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _descLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _descLabel.numberOfLines = 0;
    _descLabel.text = _mod[@"description"];
    [content addSubview:_descLabel];

    _isModpack = [_mod[@"project_type"] isEqualToString:@"modpack"];

    UILabel *verHeader = [[UILabel alloc] init];
    verHeader.translatesAutoresizingMaskIntoConstraints = NO;
    verHeader.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    verHeader.textColor = ThemeManager.shared.primaryTextColor;
    verHeader.text = @"Versions  ▼";
    verHeader.userInteractionEnabled = YES;
    [verHeader addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleVersions)]];
    [content addSubview:verHeader];

    if (_isModpack) {
        _mcVersionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _mcVersionBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_mcVersionBtn setTitle:@"Select MC Version" forState:UIControlStateNormal];
        [_mcVersionBtn setTitleColor:ThemeManager.shared.primaryTextColor forState:UIControlStateNormal];
        _mcVersionBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        _mcVersionBtn.layer.cornerRadius = 8;
        _mcVersionBtn.layer.borderWidth = 1;
        _mcVersionBtn.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
        _mcVersionBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _mcVersionBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
        _mcVersionBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_mcVersionBtn addTarget:self action:@selector(pickMcVersion) forControlEvents:UIControlEventTouchUpInside];
        [content addSubview:_mcVersionBtn];
    }

    _versionTable = [[UITableView alloc] init];
    _versionTable.translatesAutoresizingMaskIntoConstraints = NO;
    _versionTable.delegate = self;
    _versionTable.dataSource = self;
    _versionTable.backgroundColor = [UIColor clearColor];
    _versionTable.layer.cornerRadius = 8;
    _versionTable.layer.borderWidth = 1;
    _versionTable.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _versionTable.rowHeight = 44;
    _versionTable.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    _versionTable.scrollEnabled = YES;
    [_versionTable registerClass:[UITableViewCell class] forCellReuseIdentifier:kVerCell];
    [content addSubview:_versionTable];

    _actionsContainer = [[UIView alloc] init];
    _actionsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _actionsContainer.hidden = YES;
    [content addSubview:_actionsContainer];

    _downloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_downloadBtn setTitle:@"Download" forState:UIControlStateNormal];
    [_downloadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _downloadBtn.backgroundColor = ThemeManager.shared.accentColor;
    _downloadBtn.layer.cornerRadius = 10;
    _downloadBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [_downloadBtn addTarget:self action:@selector(downloadMod) forControlEvents:UIControlEventTouchUpInside];
    [_actionsContainer addSubview:_downloadBtn];

    _profileBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _profileBtn.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *profileTitle = _isModpack ? @"Install Modpack" : @"Download to Profile";
    [_profileBtn setTitle:profileTitle forState:UIControlStateNormal];
    [_profileBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _profileBtn.backgroundColor = ThemeManager.shared.successColor;
    _profileBtn.layer.cornerRadius = 10;
    _profileBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [_profileBtn addTarget:self action:@selector(installToProfile) forControlEvents:UIControlEventTouchUpInside];
    [_actionsContainer addSubview:_profileBtn];

    _depsContainer = [[UIView alloc] init];
    _depsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _depsContainer.hidden = YES;
    [content addSubview:_depsContainer];

    _depsHeader = [[UILabel alloc] init];
    _depsHeader.translatesAutoresizingMaskIntoConstraints = NO;
    _depsHeader.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _depsHeader.textColor = ThemeManager.shared.primaryTextColor;
    _depsHeader.text = @"Dependencies";
    [_depsContainer addSubview:_depsHeader];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
        [content.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],

        [_iconView.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [_iconView.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:96],
        [_iconView.heightAnchor constraintEqualToConstant:96],

        [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:12],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_titleLabel.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],

        [_authorLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_authorLabel.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],

        [statsBar.topAnchor constraintEqualToAnchor:_authorLabel.bottomAnchor constant:12],
        [statsBar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [statsBar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [statsBar.heightAnchor constraintEqualToConstant:36],

        [_downloadsLabel.leadingAnchor constraintEqualToAnchor:statsBar.leadingAnchor],
        [_downloadsLabel.centerYAnchor constraintEqualToAnchor:statsBar.centerYAnchor],
        [_downloadsLabel.widthAnchor constraintEqualToAnchor:statsBar.widthAnchor multiplier:0.5],

        [_followsLabel.trailingAnchor constraintEqualToAnchor:statsBar.trailingAnchor],
        [_followsLabel.centerYAnchor constraintEqualToAnchor:statsBar.centerYAnchor],
        [_followsLabel.widthAnchor constraintEqualToAnchor:statsBar.widthAnchor multiplier:0.5],

        [_descLabel.topAnchor constraintEqualToAnchor:statsBar.bottomAnchor constant:16],
        [_descLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_descLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [verHeader.topAnchor constraintEqualToAnchor:_descLabel.bottomAnchor constant:20],
        [verHeader.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],

        [_versionTable.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_versionTable.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_actionsContainer.topAnchor constraintEqualToAnchor:_versionTable.bottomAnchor constant:16],
        [_actionsContainer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_actionsContainer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [_downloadBtn.topAnchor constraintEqualToAnchor:_actionsContainer.topAnchor],
        [_downloadBtn.leadingAnchor constraintEqualToAnchor:_actionsContainer.leadingAnchor],
        [_downloadBtn.trailingAnchor constraintEqualToAnchor:_actionsContainer.trailingAnchor],
        [_downloadBtn.heightAnchor constraintEqualToConstant:48],

        [_profileBtn.topAnchor constraintEqualToAnchor:_downloadBtn.bottomAnchor constant:10],
        [_profileBtn.leadingAnchor constraintEqualToAnchor:_actionsContainer.leadingAnchor],
        [_profileBtn.trailingAnchor constraintEqualToAnchor:_actionsContainer.trailingAnchor],
        [_profileBtn.heightAnchor constraintEqualToConstant:48],
        [_profileBtn.bottomAnchor constraintEqualToAnchor:_actionsContainer.bottomAnchor],

        [_depsContainer.topAnchor constraintEqualToAnchor:_actionsContainer.bottomAnchor constant:8],
        [_depsContainer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_depsContainer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [_depsHeader.topAnchor constraintEqualToAnchor:_depsContainer.topAnchor],
        [_depsHeader.leadingAnchor constraintEqualToAnchor:_depsContainer.leadingAnchor],

        [_depsContainer.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-30],
    ]];

    if (_isModpack && _mcVersionBtn) {
        [NSLayoutConstraint activateConstraints:@[
            [_mcVersionBtn.topAnchor constraintEqualToAnchor:verHeader.bottomAnchor constant:8],
            [_mcVersionBtn.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
            [_mcVersionBtn.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
            [_mcVersionBtn.heightAnchor constraintEqualToConstant:40],
            [_versionTable.topAnchor constraintEqualToAnchor:_mcVersionBtn.bottomAnchor constant:8],
        ]];
    } else {
        [_versionTable.topAnchor constraintEqualToAnchor:verHeader.bottomAnchor constant:8].active = YES;
    }
    _versionTableHeight = [_versionTable.heightAnchor constraintEqualToConstant:0];
    _versionTableHeight.active = YES;

    NSString *iconURL = _mod[@"icon_url"];
    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:iconURL]];
        [request setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
        [_iconView setImageWithURLRequest:request placeholderImage:[UIImage systemImageNamed:@"wrench.and.screwdriver"] success:^(NSURLRequest *req, NSHTTPURLResponse *resp, UIImage *img) {
            weakSelf.iconView.image = img;
            weakSelf.iconView.tintColor = [UIColor clearColor];
        } failure:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSError *err) {
            NSLog(@"[ModDetail] Icon load failed: %@, error: %@", iconURL, err);
        }];
    }
}

- (void)updateColors {
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;
    _scrollView.backgroundColor = ThemeManager.shared.backgroundColor;
    _versionTable.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
    _downloadBtn.backgroundColor = ThemeManager.shared.accentColor;
    _profileBtn.backgroundColor = ThemeManager.shared.successColor;
}

#pragma mark - Version Loading

- (void)loadVersions {
    [ModrinthService.shared loadProjectVersions:_mod[@"project_id"] completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error || versions.count == 0) return;

        if (_isModpack) {
            NSMutableOrderedSet *mcVersions = [NSMutableOrderedSet orderedSet];
            for (NSDictionary *ver in versions) {
                for (NSString *gv in ver[@"game_versions"]) {
                    [mcVersions addObject:gv];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.versions = versions;
                self.availableMcVersions = [mcVersions array];
                self.hasLoadedVersions = YES;
                self.selectedMcVersion = nil;
                [self.mcVersionBtn setTitle:@"  Select MC Version" forState:UIControlStateNormal];
                self.versionTable.hidden = YES;
                [self updateVersionTableHeight];
                [self.versionTable reloadData];
            });
            return;
        }

        VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
        NSString *targetVersion = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
        NSString *targetLoader = [profile.modLoader lowercaseString] ?: @"";

        if (targetLoader.length == 0 || [targetLoader isEqualToString:@"vanilla"]) {
            targetLoader = [getPrefObject(@"internal.mod_loader") lowercaseString] ?: @"";
        }

        if (targetLoader.length > 0 && ![targetLoader isEqualToString:@"vanilla"]) {
            _selectedLoader = targetLoader;
        }

        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *ver in versions) {
            BOOL versionMatch = targetVersion.length == 0 || [ver[@"game_versions"] containsObject:targetVersion];
            BOOL loaderMatch = targetLoader.length == 0 || [targetLoader isEqualToString:@"vanilla"] || [ver[@"loaders"] containsObject:targetLoader];
            if (versionMatch && loaderMatch) {
                [filtered addObject:ver];
            }
        }

        if (filtered.count > 0) {
            self.versions = filtered;
        } else {
            self.versions = versions;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.hasLoadedVersions = YES;
            [self updateVersionTableHeight];
            [self.versionTable reloadData];
        });
    }];
}

- (void)pickMcVersion {
    if (_availableMcVersions.count == 0) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Select Minecraft Version" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *mcVer in _availableMcVersions) {
        NSString *label = mcVer;
        if ([mcVer isEqualToString:_selectedMcVersion]) {
            label = [@"✓ " stringByAppendingString:mcVer];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            _selectedMcVersion = mcVer;
            [_mcVersionBtn setTitle:[@"  " stringByAppendingString:mcVer] forState:UIControlStateNormal];

            NSMutableArray *filtered = [NSMutableArray array];
            for (NSDictionary *ver in _versions) {
                if ([ver[@"game_versions"] containsObject:mcVer]) {
                    [filtered addObject:ver];
                }
            }
            self.versions = filtered;
            _selectedVersionIndex = -1;
            _actionsContainer.hidden = YES;
            _depsContainer.hidden = YES;
            self.versionTable.hidden = NO;
            [self updateVersionTableHeight];
            [self.versionTable reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleVersions {
    _versionsExpanded = !_versionsExpanded;
    if (_versionsExpanded) {
        _versionTable.hidden = NO;
        _actionsContainer.hidden = _selectedVersionIndex < 0;
        if (_dependencyMods.count > 0) _depsContainer.hidden = NO;
    } else {
        _versionTable.hidden = YES;
        _actionsContainer.hidden = YES;
        _depsContainer.hidden = YES;
    }
    [self updateVersionTableHeight];
}

- (void)updateVersionTableHeight {
    if (!_versionsExpanded) {
        if (_versionTableHeight) {
            _versionTableHeight.constant = 0;
        } else {
            _versionTableHeight = [_versionTable.heightAnchor constraintEqualToConstant:0];
            _versionTableHeight.active = YES;
        }
        _versionTable.hidden = YES;
        [self.view layoutIfNeeded];
        return;
    }
    _versionTable.hidden = NO;
    CGFloat rowHeight = 44;
    CGFloat maxHeight = 220;
    CGFloat tableHeight = MIN(self.versions.count * rowHeight, maxHeight);
    if (_versionTableHeight) {
        _versionTableHeight.constant = tableHeight;
    } else {
        _versionTableHeight = [_versionTable.heightAnchor constraintEqualToConstant:tableHeight];
        _versionTableHeight.active = YES;
    }
    [self.view layoutIfNeeded];
}

#pragma mark - TableView (Versions)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _versions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kVerCell forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;

    NSDictionary *ver = _versions[indexPath.row];
    cell.textLabel.text = ver[@"version_number"];
    cell.detailTextLabel.text = [ver[@"game_versions"] componentsJoinedByString:@", "];

    if (indexPath.row == _selectedVersionIndex) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = ThemeManager.shared.accentColor;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [HapticManager.shared play:HapticTypeLight];
    _selectedVersionIndex = indexPath.row;
    [_versionTable reloadData];
    _actionsContainer.hidden = NO;
    [self loadDependenciesForSelectedVersion];
}

#pragma mark - Actions

- (NSDictionary *)selectedVersionDict {
    if (_selectedVersionIndex < 0 || _selectedVersionIndex >= (NSInteger)_versions.count) return nil;
    return _versions[_selectedVersionIndex];
}

- (void)downloadMod {
    [HapticManager.shared play:HapticTypeMedium];
    NSDictionary *ver = [self selectedVersionDict];
    if (!ver) return;

    NSString *url = ver[@"url"];
    NSString *filename = ver[@"filename"] ?: @"mod.jar";

    NSString *downloadsPath = VersionDirectoryManager.shared.downloadsPath;
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadsPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *targetPath = [downloadsPath stringByAppendingPathComponent:filename];

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Downloading Mod"];
    [overlay updateProgress:0 message:@"Downloading..."];

    __weak typeof(self) weakSelf = self;
    [overlay setCancelBlock:^{
        [weakSelf.currentDownloadTask cancel];
        weakSelf.currentDownloadTask = nil;
    }];
    weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [overlay updateProgress:p message:[NSString stringWithFormat:@"Downloading %@", filename]];
    } completion:^(NSString *dlPath, NSError *error) {
        if (dlPath) {
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:dlPath toPath:targetPath error:nil];
            [overlay finishWithMessage:@"Downloaded!"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [overlay dismiss];
                showDialog(@"Downloaded", [NSString stringWithFormat:@"%@ saved to Downloads.", filename]);
            });
        } else {
            [overlay finishWithMessage:@"Failed"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [overlay dismiss];
            });
        }
    }];
}

- (void)installToProfile {
    [HapticManager.shared play:HapticTypeMedium];
    NSDictionary *ver = [self selectedVersionDict];
    if (!ver) return;

    VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
    NSString *currentVersion = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
    NSString *currentLoader = [profile.modLoader lowercaseString] ?: [getPrefObject(@"internal.mod_loader") lowercaseString] ?: @"";

    BOOL versionCompatible = currentVersion.length == 0 || [ver[@"game_versions"] containsObject:currentVersion];
    BOOL loaderCompatible = currentLoader.length == 0 || [currentLoader isEqualToString:@"vanilla"] || [ver[@"loaders"] containsObject:currentLoader];

    if (!versionCompatible || !loaderCompatible) {
        NSMutableArray *issues = [NSMutableArray array];
        if (!versionCompatible)
            [issues addObject:[NSString stringWithFormat:@"Version %@ not compatible with Minecraft %@", ver[@"version_number"], currentVersion]];
        if (!loaderCompatible)
            [issues addObject:[NSString stringWithFormat:@"Mod doesn't support %@ loader", currentLoader]];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Compatibility Warning" message:[issues componentsJoinedByString:@"\n"] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Download Anyway" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self doInstallToProfile:ver];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [self doInstallToProfile:ver];
}

- (void)doInstallToProfile:(NSDictionary *)ver {
    NSString *url = ver[@"url"];
    NSString *filename = ver[@"filename"] ?: @"mod.jar";
    NSString *mcVersion = VersionDirectoryManager.shared.currentVersion;
    if (mcVersion.length == 0) {
        mcVersion = VersionDirectoryManager.shared.currentProfile.mcVersion ?: @"1.21.4";
    }

    if (_isModpack) {
        [self installModpack:ver mcVersion:mcVersion];
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Installing"];
    [overlay updateProgress:0 message:@"Downloading..."];

    __weak typeof(self) weakSelf = self;
    [overlay setCancelBlock:^{
        [weakSelf.currentDownloadTask cancel];
        weakSelf.currentDownloadTask = nil;
    }];
    weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [overlay updateProgress:p message:@"Downloading..."];
    } completion:^(NSString *path, NSError *dlError) {
        if (path) {
            [overlay updateProgress:1.0 message:@"Copying to profile..."];
            NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:mcVersion];
            NSString *targetPath = [modsDir stringByAppendingPathComponent:filename];
            if (![targetPath hasSuffix:@".jar"]) targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
            [[NSFileManager defaultManager] createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:targetPath error:&moveError];
            if (moveError == nil) {
                [overlay finishWithMessage:@"Installed!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    showDialog(@"Installed", [NSString stringWithFormat:@"%@ installed to profile.", _mod[@"title"]]);
                });
            } else {
                [overlay finishWithMessage:@"Install failed"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                });
            }
        }
    }];
}

- (void)installModpack:(NSDictionary *)ver mcVersion:(NSString *)mcVersion {
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Installing Modpack"];
    [overlay updateProgress:0 message:@"Downloading modpack..."];

    NSString *url = ver[@"url"];
    NSString *filename = ver[@"filename"] ?: @"modpack.mrpack";

    __weak typeof(self) weakSelf = self;
    [overlay setCancelBlock:^{
        [weakSelf.currentDownloadTask cancel];
        weakSelf.currentDownloadTask = nil;
    }];
    weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [overlay updateProgress:p message:@"Downloading modpack..."];
    } completion:^(NSString *dlPath, NSError *dlError) {
        if (!dlPath) {
            [overlay finishWithMessage:@"Download failed"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [overlay dismiss]; });
            return;
        }

        [MrpackInstaller installMrpackAtPath:dlPath title:_mod[@"title"] hostVC:self removeOnCompletion:YES];
    }];
}

#pragma mark - Dependencies

- (void)loadDependenciesForSelectedVersion {
    NSDictionary *ver = [self selectedVersionDict];
    if (!ver) return;
    NSArray *deps = ver[@"dependencies"];
    if (![deps isKindOfClass:[NSArray class]] || deps.count == 0) {
        _depsContainer.hidden = YES;
        return;
    }

    NSArray *requiredDeps = [deps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"dependency_type == %@", @"required"]];
    if (requiredDeps.count == 0) {
        _depsContainer.hidden = YES;
        return;
    }

    [_dependencyMods removeAllObjects];
    _depsContainer.hidden = NO;

    for (NSDictionary *dep in requiredDeps) {
        NSString *depProjectId = dep[@"project_id"];
        if (!depProjectId) continue;

        [ModrinthService.shared loadProjectDetails:depProjectId completion:^(NSDictionary *project, NSError *error) {
            if (error || !project) return;
            [ModrinthService.shared loadProjectVersions:depProjectId completion:^(NSArray<NSDictionary *> *depVersions, NSError *vError) {
                if (vError || depVersions.count == 0) return;

                VersionProfile *profile = VersionDirectoryManager.shared.currentProfile;
                NSString *targetVersion = profile.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
                NSString *targetLoader = [profile.modLoader lowercaseString] ?: @"";

                NSDictionary *bestVer = nil;
                for (NSDictionary *dv in depVersions) {
                    BOOL vm = targetVersion.length == 0 || [dv[@"game_versions"] containsObject:targetVersion];
                    BOOL lm = targetLoader.length == 0 || [targetLoader isEqualToString:@"vanilla"] || [dv[@"loaders"] containsObject:targetLoader];
                    if (vm && lm) {
                        bestVer = dv;
                        break;
                    }
                }
                if (!bestVer) bestVer = depVersions.firstObject;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.dependencyMods addObject:@{
                        @"project_id": depProjectId,
                        @"title": project[@"title"] ?: @"Unknown",
                        @"icon_url": project[@"icon_url"] ?: @"",
                        @"version": bestVer[@"version_number"] ?: @"",
                        @"url": bestVer[@"url"] ?: @"",
                        @"filename": bestVer[@"filename"] ?: @"mod.jar",
                        @"game_versions": bestVer[@"game_versions"] ?: @[],
                        @"loaders": bestVer[@"loaders"] ?: @[],
                    }];
                    [self rebuildDependencyViews];
                });
            }];
        }];
    }
}

- (void)rebuildDependencyViews {
    for (UIView *v in _depsContainer.subviews) {
        if (v != _depsHeader) {
            [v removeFromSuperview];
        }
    }

    UIView *prevView = _depsHeader;
    CGFloat yOffset = 30;

    for (NSDictionary *dep in _dependencyMods) {
        UIView *card = [[UIView alloc] init];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        card.layer.cornerRadius = 8;
        [_depsContainer addSubview:card];

        UIImageView *depIcon = [[UIImageView alloc] init];
        depIcon.translatesAutoresizingMaskIntoConstraints = NO;
        depIcon.contentMode = UIViewContentModeScaleAspectFill;
        depIcon.clipsToBounds = YES;
        depIcon.layer.cornerRadius = 6;
        depIcon.image = [UIImage systemImageNamed:@" puzzlepiece.extension"];
        depIcon.tintColor = ThemeManager.shared.secondaryTextColor;
        [card addSubview:depIcon];

        UILabel *depTitle = [[UILabel alloc] init];
        depTitle.translatesAutoresizingMaskIntoConstraints = NO;
        depTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        depTitle.textColor = ThemeManager.shared.primaryTextColor;
        depTitle.text = dep[@"title"];
        depTitle.numberOfLines = 1;
        [card addSubview:depTitle];

        NSString *verStr = dep[@"version"];
        NSString *mcVers = [dep[@"game_versions"] componentsJoinedByString:@", "];
        UILabel *depVer = [[UILabel alloc] init];
        depVer.translatesAutoresizingMaskIntoConstraints = NO;
        depVer.font = [UIFont systemFontOfSize:11];
        depVer.textColor = ThemeManager.shared.secondaryTextColor;
        depVer.text = [NSString stringWithFormat:@"%@ — %@", verStr, mcVers];
        depVer.numberOfLines = 1;
        [card addSubview:depVer];

        UIButton *dlBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        dlBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [dlBtn setTitle:@"Download" forState:UIControlStateNormal];
        [dlBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        dlBtn.backgroundColor = ThemeManager.shared.accentColor;
        dlBtn.layer.cornerRadius = 6;
        dlBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        dlBtn.tag = [_dependencyMods indexOfObject:dep];
        [dlBtn addTarget:self action:@selector(downloadDependency:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:dlBtn];

        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:prevView.bottomAnchor constant:8],
            [card.leadingAnchor constraintEqualToAnchor:_depsContainer.leadingAnchor],
            [card.trailingAnchor constraintEqualToAnchor:_depsContainer.trailingAnchor],
            [card.heightAnchor constraintEqualToConstant:64],

            [depIcon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:10],
            [depIcon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [depIcon.widthAnchor constraintEqualToConstant:36],
            [depIcon.heightAnchor constraintEqualToConstant:36],

            [depTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
            [depTitle.leadingAnchor constraintEqualToAnchor:depIcon.trailingAnchor constant:10],
            [depTitle.trailingAnchor constraintEqualToAnchor:dlBtn.leadingAnchor constant:-8],

            [depVer.topAnchor constraintEqualToAnchor:depTitle.bottomAnchor constant:2],
            [depVer.leadingAnchor constraintEqualToAnchor:depTitle.leadingAnchor],
            [depVer.trailingAnchor constraintEqualToAnchor:dlBtn.leadingAnchor constant:-8],

            [dlBtn.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [dlBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-10],
            [dlBtn.widthAnchor constraintEqualToConstant:80],
            [dlBtn.heightAnchor constraintEqualToConstant:30],
        ]];

        prevView = card;

        NSString *iconURL = dep[@"icon_url"];
        if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
            __weak typeof(self) weakSelf = self;
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:iconURL]];
            [req setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
            [depIcon setImageWithURLRequest:req placeholderImage:[UIImage systemImageNamed:@"puzzlepiece.extension"] success:^(NSURLRequest *r, NSHTTPURLResponse *resp, UIImage *img) {
                depIcon.image = img;
                depIcon.tintColor = [UIColor clearColor];
            } failure:nil];
        }
    }

    if (_depsBottom) {
        _depsBottom.constant = -30;
        _depsBottom.active = NO;
    }
    _depsBottom = [_depsContainer.bottomAnchor constraintEqualToAnchor:prevView.bottomAnchor constant:12];
    _depsBottom.active = YES;
}

- (void)downloadDependency:(UIButton *)sender {
    NSDictionary *dep = _dependencyMods[sender.tag];
    if (!dep) return;

    [HapticManager.shared play:HapticTypeMedium];
    NSString *url = dep[@"url"];
    NSString *filename = dep[@"filename"] ?: @"mod.jar";
    NSString *mcVersion = VersionDirectoryManager.shared.currentVersion;
    if (mcVersion.length == 0) {
        mcVersion = VersionDirectoryManager.shared.currentProfile.mcVersion ?: @"1.21.4";
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.view title:@"Downloading Dependency"];
    [overlay updateProgress:0 message:[NSString stringWithFormat:@"Downloading %@...", dep[@"title"]]];

    __weak typeof(self) weakSelf = self;
    [overlay setCancelBlock:^{
        [weakSelf.currentDownloadTask cancel];
        weakSelf.currentDownloadTask = nil;
    }];
    weakSelf.currentDownloadTask = [ModrinthService.shared downloadFile:url name:filename progressBlock:^(float p) {
        [overlay updateProgress:p message:@"Downloading..."];
    } completion:^(NSString *path, NSError *dlError) {
        if (path) {
            [overlay updateProgress:1.0 message:@"Copying to profile..."];
            NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:mcVersion];
            NSString *targetPath = [modsDir stringByAppendingPathComponent:filename];
            if (![targetPath hasSuffix:@".jar"]) targetPath = [targetPath stringByAppendingPathExtension:@"jar"];
            [[NSFileManager defaultManager] createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:targetPath error:&moveError];
            if (moveError == nil) {
                [overlay finishWithMessage:@"Installed!"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    showDialog(@"Installed", [NSString stringWithFormat:@"%@ installed to profile.", dep[@"title"]]);
                });
            } else {
                [overlay finishWithMessage:@"Failed"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                });
            }
        }
    }];
}

#pragma mark - Client JAR download

- (void)downloadClientJarForModpack:(NSString *)versionName {
    NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionName];
    NSString *jarPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jar", versionName]];
    if ([NSFileManager.defaultManager fileExistsAtPath:jarPath]) return;

    NSString *jsonPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", versionName]];
    NSMutableDictionary *json = parseJSONFromFile(jsonPath);
    if (json[@"NSErrorObject"]) return;

    NSString *mcVersion = json[@"minecraftVersion"];
    if (!mcVersion) return;

    // Fetch Mojang version manifest
    NSURL *manifestURL = [NSURL URLWithString:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"];
    NSData *manifestData = [NSData dataWithContentsOfURL:manifestURL];
    if (!manifestData) return;

    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
    if (![manifest[@"versions"] isKindOfClass:[NSArray class]]) return;

    // Find the MC version entry
    NSString *versionJsonUrl = nil;
    for (NSDictionary *v in manifest[@"versions"]) {
        if ([v[@"id"] isEqualToString:mcVersion]) {
            versionJsonUrl = v[@"url"];
            break;
        }
    }
    if (!versionJsonUrl) return;

    // Download the version JSON
    NSData *versionData = [NSData dataWithContentsOfURL:[NSURL URLWithString:versionJsonUrl]];
    if (!versionData) return;

    NSDictionary *versionJson = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
    NSString *jarUrl = versionJson[@"downloads"][@"client"][@"url"];
    if (!jarUrl) return;

    NSLog(@"[Modpack] Downloading client jar for %@ from %@", versionName, jarUrl);
    NSData *jarData = [NSData dataWithContentsOfURL:[NSURL URLWithString:jarUrl]];
    if (jarData) {
        [jarData writeToFile:jarPath atomically:YES];
        NSLog(@"[Modpack] Saved client jar to %@", jarPath);
    }
}

#pragma mark - Helpers

- (NSString *)formatNumber:(NSNumber *)num {
    long long n = num.longLongValue;
    if (n >= 1000000) return [NSString stringWithFormat:@"%.1fM", n / 1000000.0];
    if (n >= 1000) return [NSString stringWithFormat:@"%.1fK", n / 1000.0];
    return [NSString stringWithFormat:@"%lld", n];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end