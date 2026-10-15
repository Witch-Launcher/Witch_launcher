#import "ProfileDetailPageViewController.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "HapticManager.h"
#import "ErrorPresenter.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "ModIconReader.h"
#import "ModUpdateChecker.h"
#import "ModSourceService.h"
#import "DownloadManager.h"
#import "DependencyResolver.h"
#import "ProfileAvatarManager.h"
#import "FileBrowserViewController.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "MinecraftResourceUtils.h"
#import "utils.h"
#import <objc/runtime.h>

#pragma mark - Content cell

@interface ProfileContentCell : UITableViewCell
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UILabel *sourceBadge;
@property (nonatomic) UILabel *statusBadge;
@property (nonatomic) UISwitch *enabledSwitch;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic) UIButton *menuButton;
@property (nonatomic) NSDictionary *itemData;
@property (nonatomic, copy) void(^onToggle)(NSDictionary *item, BOOL enabled);
@property (nonatomic, copy) void(^onAction)(NSDictionary *item);
@property (nonatomic, copy) void(^onMenu)(NSDictionary *item, UIButton *sender);
@end

@implementation ProfileContentCell

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
        _iconView.layer.cornerRadius = 10;
        _iconView.backgroundColor = ThemeManager.shared.separatorColor;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        _nameLabel.numberOfLines = 1;
        [self.contentView addSubview:_nameLabel];

        _detailLabel = [[UILabel alloc] init];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _detailLabel.numberOfLines = 1;
        [self.contentView addSubview:_detailLabel];

        _sourceBadge = [[UILabel alloc] init];
        _sourceBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _sourceBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _sourceBadge.textColor = UIColor.whiteColor;
        _sourceBadge.textAlignment = NSTextAlignmentCenter;
        _sourceBadge.layer.cornerRadius = 4;
        _sourceBadge.clipsToBounds = YES;
        [self.contentView addSubview:_sourceBadge];

        _statusBadge = [[UILabel alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _statusBadge.textColor = UIColor.whiteColor;
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 4;
        _statusBadge.clipsToBounds = YES;
        [self.contentView addSubview:_statusBadge];

        _enabledSwitch = [[UISwitch alloc] init];
        _enabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
        [_enabledSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_enabledSwitch];

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _actionButton.layer.cornerRadius = 8;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        [_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];

        _menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _menuButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_menuButton setImage:[UIImage systemImageNamed:@"ellipsis.circle"] forState:UIControlStateNormal];
        _menuButton.tintColor = ThemeManager.shared.secondaryTextColor;
        [_menuButton addTarget:self action:@selector(menuTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_menuButton];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_iconView.widthAnchor constraintEqualToConstant:44],
            [_iconView.heightAnchor constraintEqualToConstant:44],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_sourceBadge.topAnchor constraintEqualToAnchor:_detailLabel.bottomAnchor constant:4],
            [_sourceBadge.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_sourceBadge.heightAnchor constraintEqualToConstant:16],
            [_sourceBadge.widthAnchor constraintGreaterThanOrEqualToConstant:52],

            [_statusBadge.centerYAnchor constraintEqualToAnchor:_sourceBadge.centerYAnchor],
            [_statusBadge.leadingAnchor constraintEqualToAnchor:_sourceBadge.trailingAnchor constant:6],
            [_statusBadge.heightAnchor constraintEqualToConstant:16],
            [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:52],

            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-12],
            [_actionButton.trailingAnchor constraintEqualToAnchor:_enabledSwitch.leadingAnchor constant:-8],
            [_actionButton.heightAnchor constraintEqualToConstant:30],

            [_menuButton.centerYAnchor constraintEqualToAnchor:_actionButton.centerYAnchor],
            [_menuButton.trailingAnchor constraintEqualToAnchor:_enabledSwitch.leadingAnchor constant:-8],
            [_menuButton.widthAnchor constraintEqualToConstant:30],
            [_menuButton.heightAnchor constraintEqualToConstant:30],

            [_enabledSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_enabledSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _menuButton.tintColor = ThemeManager.shared.secondaryTextColor;
    _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
}

- (void)switchChanged { if (_onToggle) _onToggle(_itemData, _enabledSwitch.isOn); }
- (void)actionTapped { if (_onAction) _onAction(_itemData); }
- (void)menuTapped:(UIButton *)sender { if (_onMenu) _onMenu(_itemData, sender); }

- (void)configureWithItem:(NSDictionary *)item status:(NSDictionary *)status category:(NSString *)category {
    _itemData = item;
    NSString *title = item[@"title"];
    if (![title isKindOfClass:[NSString class]] || title.length == 0) title = item[@"filename"] ?: @"Unknown";
    _nameLabel.text = title;

    NSString *ver = [item[@"version_number"] isKindOfClass:[NSString class]] ? item[@"version_number"] : @"";
    NSString *author = [item[@"author"] isKindOfClass:[NSString class]] ? item[@"author"] : @"";
    NSString *mc = [item[@"mc_version"] isKindOfClass:[NSString class]] ? item[@"mc_version"] : @"";
    NSString *loader = [item[@"loader"] isKindOfClass:[NSString class]] ? item[@"loader"] : @"";
    NSMutableArray *parts = [NSMutableArray array];
    if (ver.length > 0) [parts addObject:ver];
    if (author.length > 0) [parts addObject:author];
    if (mc.length > 0) [parts addObject:[NSString stringWithFormat:@"MC %@", mc]];
    else if ([item[@"filename"] isKindOfClass:[NSString class]]) [parts addObject:item[@"filename"]];
    if (loader.length > 0) [parts addObject:loader];
    _detailLabel.text = [parts componentsJoinedByString:@"  •  "];

    NSString *source = [item[@"source"] isKindOfClass:[NSString class]] ? item[@"source"] : @"";
    if ([source isEqualToString:@"curseforge"]) {
        _sourceBadge.text = @"  CurseForge  ";
        _sourceBadge.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.73 alpha:1.0];
    } else if (source.length > 0 && ![source isEqualToString:@"local"]) {
        _sourceBadge.text = @"  Modrinth  ";
        _sourceBadge.backgroundColor = [UIColor colorWithRed:0.20 green:0.62 blue:0.35 alpha:1.0];
    } else {
        _sourceBadge.text = @"  Local  ";
        _sourceBadge.backgroundColor = [UIColor grayColor];
    }

    NSString *st = [status[@"status"] isKindOfClass:[NSString class]] ? status[@"status"] : @"none";
    ThemeManager *theme = ThemeManager.shared;
    if ([st isEqualToString:@"update"]) {
        _statusBadge.text = @"  Outdated  ";
        _statusBadge.backgroundColor = theme.warningColor;
        [self setActionTitle:@"Update" color:theme.warningColor];
        _menuButton.hidden = YES;
        _actionButton.hidden = NO;
    } else if ([st isEqualToString:@"latest"]) {
        _statusBadge.text = @"  Up to date  ";
        _statusBadge.backgroundColor = theme.successColor;
        [self setActionTitle:@"Installed" color:theme.accentColor];
        _menuButton.hidden = YES;
        _actionButton.hidden = NO;
    } else if ([st isEqualToString:@"incompatible"]) {
        _statusBadge.text = @"  Incompatible  ";
        _statusBadge.backgroundColor = theme.errorColor;
        _actionButton.hidden = YES;
        _menuButton.hidden = NO;
    } else if ([st isEqualToString:@"checking"]) {
        _statusBadge.text = @"  Checking  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
        _menuButton.hidden = NO;
    } else if ([st isEqualToString:@"unknown"]) {
        _statusBadge.text = @"  Unknown  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
        _menuButton.hidden = NO;
    } else {
        _statusBadge.text = @"  Manual  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
        _menuButton.hidden = NO;
    }

    // Enabled switch
    NSString *filename = item[@"filename"];
    BOOL enabled = YES;
    if ([filename isKindOfClass:[NSString class]] && filename.length > 0) {
        enabled = [[InstalledModsManager shared] isEnabledForFilename:filename category:category];
    }
    [_enabledSwitch setOn:enabled animated:NO];
}

- (void)setActionTitle:(NSString *)title color:(UIColor *)color {
    [_actionButton setTitle:title forState:UIControlStateNormal];
    [_actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _actionButton.backgroundColor = color;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _iconView.image = nil;
    _nameLabel.text = nil;
    _detailLabel.text = nil;
    _itemData = nil;
    _onToggle = nil;
    _onAction = nil;
    _onMenu = nil;
    _actionButton.hidden = NO;
    _menuButton.hidden = NO;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end

#pragma mark - Page

typedef NS_ENUM(NSInteger, ProfileDetailTab) {
    ProfileDetailTabOverview = 0,
    ProfileDetailTabMods = 1,
    ProfileDetailTabShaders = 2,
    ProfileDetailTabResources = 3,
};

typedef NS_ENUM(NSInteger, ProfileContentFilter) {
    ProfileContentFilterAll = 0,
    ProfileContentFilterOn = 1,
    ProfileContentFilterOff = 2,
    ProfileContentFilterOutdated = 3,
};

@interface ProfileDetailPageViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIDocumentPickerDelegate>
@property (nonatomic) UIScrollView *scrollRoot;
@property (nonatomic) UIView *headerCard;
@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *profileNameLabel;
@property (nonatomic) UILabel *profileSubLabel;
@property (nonatomic) UIButton *avatarButton;
@property (nonatomic) UISegmentedControl *tabControl;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UISegmentedControl *filterControl;
@property (nonatomic) UITableView *overviewTable;
@property (nonatomic) UITableView *contentTable;
@property (nonatomic) UILabel *emptyLabel;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UIToolbar *bottomBar;

// overview settings form
@property (nonatomic) NSArray *sections;
@property (nonatomic) NSString *pendingVersion;
@property (nonatomic) NSArray *rendererKeys;
@property (nonatomic) NSArray *rendererNames;
@property (nonatomic) NSArray *lwjglList;
@property (nonatomic) NSArray *touchControlList;
@property (nonatomic) NSArray *gamepadControlList;
@property (nonatomic) NSArray *javaList;

// content
@property (nonatomic) ProfileDetailTab currentTab;
@property (nonatomic) ProfileContentFilter currentFilter;
@property (nonatomic) NSString *searchText;
@property (nonatomic) NSArray<NSDictionary *> *manifestItems;
@property (nonatomic) NSArray<NSDictionary *> *orphanItems;
@property (nonatomic) NSArray<NSDictionary *> *visibleItems;
@property (nonatomic) NSArray<NSDictionary *> *checkResults;
@property (nonatomic) NSInteger modCount;
@property (nonatomic) NSInteger shaderCount;
@property (nonatomic) NSInteger resourceCount;
@property (nonatomic) BOOL isChecking;
@property (nonatomic) BOOL pickingAvatar;
@end

@implementation ProfileDetailPageViewController

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew {
    self = [super init];
    if (self) {
        _profile = profile ?: [NSMutableDictionary dictionary];
        _isNewProfile = isNew;
        _originalName = [profile[@"name"] copy];
        _currentTab = ProfileDetailTabOverview;
        _currentFilter = ProfileContentFilterAll;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadSettingLists];
    [self buildSettingSections];
    self.pendingVersion = self.profile[@"lastVersionId"];
    [self setupUI];
    [self refreshHeader];
    [self updateTabCounts];
    [self showTab:ProfileDetailTabOverview];
    [self loadItemsIfNeeded];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onModsChanged) name:InstalledModsDidChangeNotification object:nil];
    [self onTheme];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (NSString *)currentCategory {
    if (_currentTab == ProfileDetailTabShaders) return InstalledItemCategoryShaderPack;
    if (_currentTab == ProfileDetailTabResources) return InstalledItemCategoryResourcePack;
    return InstalledItemCategoryMod;
}

- (NSString *)profileMcVersion {
    NSString *v = self.profile[@"lastVersionId"];
    if ([v isKindOfClass:[NSString class]] && v.length > 0) {
        // lastVersionId may be a full version id; VersionProfile cleans it
        return [VersionProfile cleanMinecraftVersion:v] ?: v;
    }
    VersionProfile *p = VersionDirectoryManager.shared.currentProfile;
    return p.mcVersion ?: VersionDirectoryManager.shared.currentVersion ?: @"";
}

- (NSString *)profileLoader {
    NSString *loader = self.profile[@"modLoader"];
    if ([loader isKindOfClass:[NSString class]] && loader.length > 0) return loader.lowercaseString;
    VersionProfile *p = VersionDirectoryManager.shared.currentProfile;
    if ([p.modLoader isKindOfClass:[NSString class]] && p.modLoader.length > 0) return p.modLoader.lowercaseString;
    NSString *pref = getPrefObject(@"internal.mod_loader");
    if ([pref isKindOfClass:[NSString class]] && pref.length > 0) return pref.lowercaseString;
    return @"fabric";
}

#pragma mark - UI setup

- (void)setupUI {
    self.navigationItem.title = self.profile[@"name"] ?: @"Profile";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTapped)];
    [AmethystBlurView installInView:self.view];

    _scrollRoot = [[UIScrollView alloc] init];
    _scrollRoot.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollRoot.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollRoot];

    _headerCard = [[UIView alloc] init];
    _headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    _headerCard.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _headerCard.layer.cornerRadius = 14;
    _headerCard.clipsToBounds = YES;
    [_scrollRoot addSubview:_headerCard];

    _avatarView = [[UIImageView alloc] init];
    _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = 28;
    _avatarView.tintColor = ThemeManager.shared.accentColor;
    [_headerCard addSubview:_avatarView];

    _profileNameLabel = [[UILabel alloc] init];
    _profileNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _profileNameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    _profileNameLabel.textColor = ThemeManager.shared.primaryTextColor;
    [_headerCard addSubview:_profileNameLabel];

    _profileSubLabel = [[UILabel alloc] init];
    _profileSubLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _profileSubLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _profileSubLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _profileSubLabel.numberOfLines = 2;
    [_headerCard addSubview:_profileSubLabel];

    _avatarButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_avatarButton setImage:[UIImage systemImageNamed:@"camera.fill"] forState:UIControlStateNormal];
    _avatarButton.tintColor = ThemeManager.shared.accentColor;
    [_avatarButton addTarget:self action:@selector(changeAvatarTapped) forControlEvents:UIControlEventTouchUpInside];
    [_headerCard addSubview:_avatarButton];

    _tabControl = [[UISegmentedControl alloc] initWithItems:@[@"Overview", @"Mods", @"Shaders", @"Resources"]];
    _tabControl.translatesAutoresizingMaskIntoConstraints = NO;
    _tabControl.selectedSegmentIndex = 0;
    [_tabControl addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];
    [_scrollRoot addSubview:_tabControl];

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Search name or file";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [_scrollRoot addSubview:_searchBar];

    _filterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"On", @"Off", @"Outdated"]];
    _filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    _filterControl.selectedSegmentIndex = 0;
    [_filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [_scrollRoot addSubview:_filterControl];

    _overviewTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _overviewTable.translatesAutoresizingMaskIntoConstraints = NO;
    _overviewTable.delegate = self;
    _overviewTable.dataSource = self;
    _overviewTable.backgroundColor = [UIColor clearColor];
    _overviewTable.scrollEnabled = NO;
    _overviewTable.rowHeight = 48;
    [_scrollRoot addSubview:_overviewTable];

    _contentTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _contentTable.translatesAutoresizingMaskIntoConstraints = NO;
    _contentTable.delegate = self;
    _contentTable.dataSource = self;
    _contentTable.backgroundColor = [UIColor clearColor];
    _contentTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    _contentTable.rowHeight = 78;
    [_contentTable registerClass:[ProfileContentCell class] forCellReuseIdentifier:@"ProfileContentCell"];
    [_scrollRoot addSubview:_contentTable];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(pullToRefresh) forControlEvents:UIControlEventValueChanged];
    [_contentTable addSubview:_refreshControl];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.font = [UIFont systemFontOfSize:14];
    _emptyLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.hidden = YES;
    [_scrollRoot addSubview:_emptyLabel];

    _bottomBar = [[UIToolbar alloc] init];
    _bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollRoot addSubview:_bottomBar];
    [self rebuildBottomBar];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollRoot.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollRoot.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollRoot.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollRoot.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        [_headerCard.topAnchor constraintEqualToAnchor:_scrollRoot.topAnchor constant:12],
        [_headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [_avatarView.leadingAnchor constraintEqualToAnchor:_headerCard.leadingAnchor constant:14],
        [_avatarView.centerYAnchor constraintEqualToAnchor:_headerCard.centerYAnchor],
        [_avatarView.widthAnchor constraintEqualToConstant:56],
        [_avatarView.heightAnchor constraintEqualToConstant:56],

        [_profileNameLabel.topAnchor constraintEqualToAnchor:_headerCard.topAnchor constant:14],
        [_profileNameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12],
        [_profileNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_avatarButton.leadingAnchor constant:-8],

        [_profileSubLabel.topAnchor constraintEqualToAnchor:_profileNameLabel.bottomAnchor constant:4],
        [_profileSubLabel.leadingAnchor constraintEqualToAnchor:_profileNameLabel.leadingAnchor],
        [_profileSubLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_avatarButton.leadingAnchor constant:-8],
        [_profileSubLabel.bottomAnchor constraintEqualToAnchor:_headerCard.bottomAnchor constant:-14],

        [_avatarButton.trailingAnchor constraintEqualToAnchor:_headerCard.trailingAnchor constant:-12],
        [_avatarButton.centerYAnchor constraintEqualToAnchor:_headerCard.centerYAnchor],
        [_avatarButton.widthAnchor constraintEqualToConstant:36],
        [_avatarButton.heightAnchor constraintEqualToConstant:36],

        [_tabControl.topAnchor constraintEqualToAnchor:_headerCard.bottomAnchor constant:12],
        [_tabControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_tabControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [_searchBar.topAnchor constraintEqualToAnchor:_tabControl.bottomAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:4],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-4],

        [_filterControl.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_filterControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_filterControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [_overviewTable.topAnchor constraintEqualToAnchor:_tabControl.bottomAnchor constant:8],
        [_overviewTable.leadingAnchor constraintEqualToAnchor:_scrollRoot.leadingAnchor],
        [_overviewTable.trailingAnchor constraintEqualToAnchor:_scrollRoot.trailingAnchor],
        [_overviewTable.widthAnchor constraintEqualToAnchor:_scrollRoot.widthAnchor],
        [_overviewTable.heightAnchor constraintEqualToConstant:600],

        [_contentTable.topAnchor constraintEqualToAnchor:_filterControl.bottomAnchor constant:8],
        [_contentTable.leadingAnchor constraintEqualToAnchor:_scrollRoot.leadingAnchor],
        [_contentTable.trailingAnchor constraintEqualToAnchor:_scrollRoot.trailingAnchor],
        [_contentTable.widthAnchor constraintEqualToAnchor:_scrollRoot.widthAnchor],
        [_contentTable.heightAnchor constraintEqualToConstant:420],

        [_emptyLabel.topAnchor constraintEqualToAnchor:_filterControl.bottomAnchor constant:40],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],

        [_bottomBar.topAnchor constraintEqualToAnchor:_contentTable.bottomAnchor constant:8],
        [_bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_bottomBar.bottomAnchor constraintEqualToAnchor:_scrollRoot.bottomAnchor constant:-16],
    ]];
}

- (void)rebuildBottomBar {
    UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:@"Import" style:UIBarButtonItemStylePlain target:self action:@selector(importTapped)];
    importItem.image = [UIImage systemImageNamed:@"tray.and.arrow.down"];
    UIBarButtonItem *browseItem = [[UIBarButtonItem alloc] initWithTitle:@"Files" style:UIBarButtonItemStylePlain target:self action:@selector(browseTapped)];
    browseItem.image = [UIImage systemImageNamed:@"folder"];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *updateAll = [[UIBarButtonItem alloc] initWithTitle:@"Update all" style:UIBarButtonItemStylePlain target:self action:@selector(updateAllTapped)];
    updateAll.image = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"];
    _bottomBar.items = @[importItem, flex, browseItem, flex, updateAll];
}

- (void)onTheme {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _headerCard.backgroundColor = theme.cardBackgroundColor;
    _profileNameLabel.textColor = theme.primaryTextColor;
    _profileSubLabel.textColor = theme.secondaryTextColor;
    _avatarView.tintColor = theme.accentColor;
    _avatarButton.tintColor = theme.accentColor;
    _emptyLabel.textColor = theme.secondaryTextColor;
    [_overviewTable reloadData];
    [_contentTable reloadData];
}

- (void)onModsChanged {
    [self updateTabCounts];
    if (_currentTab != ProfileDetailTabOverview) [self loadItemsIfNeeded];
    [self refreshHeader];
}

#pragma mark - Header / tabs

- (void)refreshHeader {
    _avatarView.image = [ProfileAvatarManager.shared avatarImageForProfile:self.profile];
    NSString *name = self.profile[@"name"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) name = @"New Profile";
    _profileNameLabel.text = name;
    self.navigationItem.title = name;
    NSString *mc = self.profile[@"lastVersionId"];
    if (![mc isKindOfClass:[NSString class]] || mc.length == 0) mc = [self profileMcVersion];
    NSString *loader = self.profile[@"modLoader"];
    if (![loader isKindOfClass:[NSString class]] || loader.length == 0) loader = [self profileLoader];
    _profileSubLabel.text = [NSString stringWithFormat:@"MC %@  •  %@  •  %ld mods / %ld shaders / %ld resources",
                             mc ?: @"?", [loader capitalizedString] ?: @"?",
                             (long)_modCount, (long)_shaderCount, (long)_resourceCount];
}

- (void)updateTabCounts {
    _modCount = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryMod].count;
    _shaderCount = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryShaderPack].count;
    _resourceCount = [InstalledModsManager.shared allInstalledForCategory:InstalledItemCategoryResourcePack].count;
    [_tabControl setTitle:[NSString stringWithFormat:@"Mods (%ld)", (long)_modCount] forSegmentAtIndex:1];
    [_tabControl setTitle:[NSString stringWithFormat:@"Shaders (%ld)", (long)_shaderCount] forSegmentAtIndex:2];
    [_tabControl setTitle:[NSString stringWithFormat:@"Res (%ld)", (long)_resourceCount] forSegmentAtIndex:3];
    [self refreshHeader];
}

- (void)tabChanged {
    [HapticManager.shared play:HapticTypeSelection];
    [self showTab:(ProfileDetailTab)_tabControl.selectedSegmentIndex];
}

- (void)filterChanged {
    _currentFilter = (ProfileContentFilter)_filterControl.selectedSegmentIndex;
    [self applyFilter];
}

- (void)showTab:(ProfileDetailTab)tab {
    _currentTab = tab;
    _tabControl.selectedSegmentIndex = tab;
    BOOL overview = (tab == ProfileDetailTabOverview);
    _overviewTable.hidden = !overview;
    _searchBar.hidden = overview;
    _filterControl.hidden = overview;
    _contentTable.hidden = overview;
    _bottomBar.hidden = overview;
    _emptyLabel.hidden = YES;
    if (!overview) [self loadItemsIfNeeded];
    [self layoutTables];
}

- (void)layoutTables {
    // Resize embedded tables to content so the outer scroll works
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.overviewTable.hidden) {
            CGSize s = self.overviewTable.contentSize;
            for (NSLayoutConstraint *c in self.overviewTable.constraints) {
                if (c.firstAttribute == NSLayoutAttributeHeight) c.constant = MAX(300, s.height);
            }
        }
        if (!self.contentTable.hidden) {
            NSUInteger rows = self.visibleItems.count;
            CGFloat h = MAX(200, rows * 86);
            for (NSLayoutConstraint *c in self.contentTable.constraints) {
                if (c.firstAttribute == NSLayoutAttributeHeight) c.constant = MIN(h, 1200);
            }
        }
    });
}

#pragma mark - Settings form (overview)

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
    NSString *gameDirPlaceholder = [NSString stringWithFormat:@". -> /Documents/instances/%@", getPrefObject(@"general.game_directory")];
    _sections = @[
        @{@"title": @"General", @"items": @[
            @{@"type": @"text", @"label": localize(@"preference.profile.title.name", nil), @"key": @"name", @"placeholder": @"(Default)"},
            @{@"type": @"version", @"label": localize(@"preference.profile.title.version", nil), @"key": @"lastVersionId"},
            @{@"type": @"text", @"label": localize(@"preference.title.game_directory", nil), @"key": @"gameDir", @"placeholder": gameDirPlaceholder},
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
    if ([key isEqualToString:@"name"] || [key isEqualToString:@"lastVersionId"] || [key isEqualToString:@"modLoader"]) {
        [self refreshHeader];
    }
}

#pragma mark - Content items

- (void)pullToRefresh {
    [self checkForUpdatesForce:YES];
}

- (void)loadItemsIfNeeded {
    NSString *category = [self currentCategory];
    NSString *dir = [[InstalledModsManager shared] dirForCategory:category];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray *manifest = [[InstalledModsManager shared] allInstalledForCategory:category];
    // Enrich manifest entries with mc/loader fallback for display
    NSMutableArray *enriched = [NSMutableArray arrayWithCapacity:manifest.count];
    for (NSDictionary *m in manifest) {
        NSMutableDictionary *e = [m mutableCopy];
        if (![e[@"mc_version"] isKindOfClass:[NSString class]] || [(NSString *)e[@"mc_version"] length] == 0) {
            e[@"mc_version"] = [self profileMcVersion];
        }
        if (![e[@"loader"] isKindOfClass:[NSString class]] || [(NSString *)e[@"loader"] length] == 0) {
            if ([category isEqualToString:InstalledItemCategoryMod]) e[@"loader"] = [self profileLoader];
        }
        [enriched addObject:e];
    }
    _manifestItems = enriched;

    // Orphan scan: files on disk not in manifest
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSSet *known = [NSSet setWithArray:[_manifestItems valueForKey:@"filename"]];
    NSMutableArray *orphans = [NSMutableArray array];
    for (NSString *f in files) {
        if ([f isEqualToString:@"installed_mods.json"] || [f isEqualToString:@"installed_shaderpacks.json"] ||
            [f isEqualToString:@"installed_resourcepacks.json"]) continue;
        if ([f hasSuffix:@".off"]) continue;
        BOOL isMod = [category isEqualToString:InstalledItemCategoryMod];
        BOOL match = isMod ? ([f hasSuffix:@".jar"] || [f hasSuffix:@".jar.off"]) : [f hasSuffix:@".zip"];
        if (!match) continue;
        if ([known containsObject:f]) continue;
        NSString *full = [dir stringByAppendingPathComponent:f];
        NSDictionary *meta = [ModIconReader metadataForFileAtPath:full category:category];
        NSString *title = meta[@"title"];
        if (![title isKindOfClass:[NSString class]] || title.length == 0) title = [f stringByDeletingPathExtension];
        NSString *ver = meta[@"version"];
        if (![ver isKindOfClass:[NSString class]]) ver = @"";
        [orphans addObject:@{
            @"title": title,
            @"filename": f,
            @"version_number": ver,
            @"author": (meta[@"authors"] ?: @""),
            @"description": (meta[@"description"] ?: @""),
            @"icon_url": @"",
            @"source": @"local",
            @"category": category,
            @"mc_version": [self profileMcVersion] ?: @"",
            @"loader": ([category isEqualToString:InstalledItemCategoryMod] ? [self profileLoader] : @""),
            @"isOrphan": @YES,
        }];
    }
    _orphanItems = orphans;
    _checkResults = nil;
    [self applyFilter];
    [self checkForUpdatesForce:NO];
}

- (void)applyFilter {
    NSMutableArray *all = [NSMutableArray array];
    if (_manifestItems) [all addObjectsFromArray:_manifestItems];
    if (_orphanItems) [all addObjectsFromArray:_orphanItems];

    NSString *q = [_searchText isKindOfClass:[NSString class]] ? _searchText.lowercaseString : @"";
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *item in all) {
        if (q.length > 0) {
            NSString *hay = [NSString stringWithFormat:@"%@ %@ %@",
                             item[@"title"] ?: @"", item[@"filename"] ?: @"", item[@"author"] ?: @""].lowercaseString;
            if ([hay rangeOfString:q].location == NSNotFound) continue;
        }
        if (_currentFilter == ProfileContentFilterOn || _currentFilter == ProfileContentFilterOff) {
            NSString *fn = item[@"filename"];
            BOOL enabled = YES;
            if ([fn isKindOfClass:[NSString class]]) {
                enabled = [[InstalledModsManager shared] isEnabledForFilename:fn category:[self currentCategory]];
            }
            if (_currentFilter == ProfileContentFilterOn && !enabled) continue;
            if (_currentFilter == ProfileContentFilterOff && enabled) continue;
        }
        if (_currentFilter == ProfileContentFilterOutdated) {
            NSUInteger idx = [_manifestItems indexOfObject:item];
            if (idx == NSNotFound || !_checkResults || idx >= _checkResults.count) continue;
            NSString *st = _checkResults[idx][@"status"];
            if (![st isEqualToString:@"update"]) continue;
        }
        [out addObject:item];
    }
    _visibleItems = out;
    _emptyLabel.hidden = (out.count > 0);
    if (out.count == 0) {
        NSString *cat = @"items";
        if (_currentTab == ProfileDetailTabMods) cat = @"mods";
        else if (_currentTab == ProfileDetailTabShaders) cat = @"shaders";
        else if (_currentTab == ProfileDetailTabResources) cat = @"resource packs";
        _emptyLabel.text = [NSString stringWithFormat:@"No %@ here yet.\nUse Import to add files.", cat];
    }
    [_contentTable reloadData];
    [self layoutTables];
}

- (void)checkForUpdatesForce:(BOOL)force {
    if (_currentTab == ProfileDetailTabOverview) {
        [_refreshControl endRefreshing];
        return;
    }
    if (_manifestItems.count == 0) {
        _checkResults = @[];
        [_refreshControl endRefreshing];
        [self applyFilter];
        return;
    }
    if (_isChecking && !force) return;
    _isChecking = YES;
    NSMutableArray *checking = [NSMutableArray arrayWithCapacity:_manifestItems.count];
    for (NSUInteger i = 0; i < _manifestItems.count; i++) [checking addObject:@{@"status": @"checking"}];
    _checkResults = checking;
    [_contentTable reloadData];

    __weak typeof(self) weakSelf = self;
    [[ModUpdateChecker shared] checkItems:_manifestItems mcVersion:[self profileMcVersion] loader:[self profileLoader] forceRefresh:force completion:^(NSArray *results) {
        weakSelf.isChecking = NO;
        [weakSelf.refreshControl endRefreshing];
        weakSelf.checkResults = results ?: @[];
        [weakSelf applyFilter];
    }];
}

- (NSDictionary *)checkStatusForItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue]) return @{@"status": @"local"};
    NSUInteger idx = [_manifestItems indexOfObject:item];
    if (idx != NSNotFound && _checkResults && idx < _checkResults.count) return _checkResults[idx];
    return @{@"status": @"none"};
}

#pragma mark - Tables

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == _overviewTable) return _sections.count;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == _overviewTable) return [_sections[section][@"items"] count];
    return _visibleItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == _overviewTable) return _sections[section][@"title"];
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _overviewTable) {
        return [self settingCellForIndexPath:indexPath];
    }
    ProfileContentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProfileContentCell" forIndexPath:indexPath];
    NSDictionary *item = _visibleItems[indexPath.row];
    NSString *category = [self currentCategory];
    NSDictionary *status = [self checkStatusForItem:item];
    [cell configureWithItem:item status:status category:category];
    cell.iconView.image = [UIImage systemImageNamed:[ModIconReader placeholderSystemImageForCategory:category]];
    cell.iconView.tintColor = ThemeManager.shared.secondaryTextColor;

    // Local icon first (jar/zip), then remote icon_url
    NSString *dir = [[InstalledModsManager shared] dirForCategory:category];
    NSString *fn = item[@"filename"];
    if ([fn isKindOfClass:[NSString class]] && fn.length > 0) {
        NSString *full = [dir stringByAppendingPathComponent:fn];
        if (![[NSFileManager defaultManager] fileExistsAtPath:full]) {
            full = [dir stringByAppendingPathComponent:[fn stringByAppendingString:@".off"]];
        }
        __weak ProfileContentCell *weakCell = cell;
        [[ModIconReader shared] iconForFileAtPath:full category:category completion:^(UIImage *image, NSDictionary *meta) {
            if (image) {
                weakCell.iconView.image = image;
                weakCell.iconView.tintColor = [UIColor clearColor];
            } else {
                NSString *remote = item[@"icon_url"];
                if ([remote isKindOfClass:[NSString class]] && remote.length > 0) {
                    [[ModIconReader shared] remoteIconForURLString:remote completion:^(UIImage *rimg) {
                        if (rimg) {
                            weakCell.iconView.image = rimg;
                            weakCell.iconView.tintColor = [UIColor clearColor];
                        }
                    }];
                }
            }
        }];
    } else {
        NSString *remote = item[@"icon_url"];
        if ([remote isKindOfClass:[NSString class]] && remote.length > 0) {
            __weak ProfileContentCell *weakCell = cell;
            [[ModIconReader shared] remoteIconForURLString:remote completion:^(UIImage *rimg) {
                if (rimg) {
                    weakCell.iconView.image = rimg;
                    weakCell.iconView.tintColor = [UIColor clearColor];
                }
            }];
        }
    }

    __weak typeof(self) weakSelf = self;
    cell.onToggle = ^(NSDictionary *it, BOOL enabled) {
        [weakSelf setEnabled:enabled forItem:it];
    };
    cell.onAction = ^(NSDictionary *it) {
        [weakSelf primaryActionForItem:it status:[weakSelf checkStatusForItem:it]];
    };
    cell.onMenu = ^(NSDictionary *it, UIButton *sender) {
        [weakSelf menuForItem:it sender:sender];
    };
    return cell;
}

- (UITableViewCell *)settingCellForIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    UITableViewCell *cell = [_overviewTable dequeueReusableCellWithIdentifier:type];
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
                [tf.widthAnchor constraintEqualToConstant:190],
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
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == _overviewTable) {
        NSDictionary *item = _sections[indexPath.section][@"items"][indexPath.row];
        if ([item[@"type"] isEqualToString:@"picker"]) [self showPickerForSetting:item];
        else if ([item[@"type"] isEqualToString:@"version"]) [self showVersionPicker];
    } else {
        NSDictionary *item = _visibleItems[indexPath.row];
        [self detailForItem:item];
    }
}

- (void)setEnabled:(BOOL)enabled forItem:(NSDictionary *)item {
    [HapticManager.shared play:HapticTypeLight];
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Missing file name."];
        return;
    }
    BOOL ok = [[InstalledModsManager shared] setEnabled:enabled forFilename:fn category:[self currentCategory]];
    if (!ok) {
        [ErrorPresenter showFileError:enabled ? @"Enable" : @"Disable" path:fn error:nil];
    }
    [_contentTable reloadData];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _searchText = searchText;
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Settings actions

- (void)settingTextChanged:(UITextField *)sender {
    UIView *v = sender.superview;
    while (v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
    UITableViewCell *cell = (UITableViewCell *)v;
    NSIndexPath *ip = [_overviewTable indexPathForCell:cell];
    if (!ip) return;
    NSDictionary *item = _sections[ip.section][@"items"][ip.row];
    [self setProfileValue:sender.text ?: @"" forKey:item[@"key"]];
}

- (void)showPickerForSetting:(NSDictionary *)item {
    NSArray *options = item[@"options"];
    NSString *current = [self profileValueForKey:item[@"key"]];
    if (![options isKindOfClass:[NSArray class]] || options.count == 0) {
        [ErrorPresenter showInfo:@"No Options" message:@"No options available for this setting."];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item[@"label"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL isRenderer = [item[@"key"] isEqualToString:@"renderer"];
    if (isRenderer && [options.firstObject isKindOfClass:[NSDictionary class]]) {
        for (NSDictionary *opt in options) {
            NSString *key = opt[@"key"];
            NSString *name = opt[@"name"];
            [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [self setProfileValue:key forKey:item[@"key"]];
                [self.overviewTable reloadData];
            }]];
        }
    } else {
        for (id opt in options) {
            if (![opt isKindOfClass:[NSString class]]) continue;
            [sheet addAction:[UIAlertAction actionWithTitle:opt style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [self setProfileValue:opt forKey:item[@"key"]];
                [self.overviewTable reloadData];
            }]];
        }
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:sheet animated:YES completion:nil];
    (void)current;
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
            [self.overviewTable reloadData];
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

#pragma mark - Avatar

- (void)changeAvatarTapped {
    [HapticManager.shared play:HapticTypeLight];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Profile Icon" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *key in @[@"fabric", @"forge", @"neoforge", @"quilt", @"modpack", @"vanilla", @"custom"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[key capitalizedString] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if ([key isEqualToString:@"custom"]) [self pickCustomAvatar];
            else {
                self.profile[@"avatar"] = key;
                [self refreshHeader];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = _avatarButton;
        sheet.popoverPresentationController.sourceRect = _avatarButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pickCustomAvatar {
    _pickingAvatar = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - Import / share / rename / delete / browse

- (void)importTapped {
    [HapticManager.shared play:HapticTypeLight];
    _pickingAvatar = NO;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self handlePickedURLs:urls];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    // Custom avatar path
    if (_pickingAvatar) {
        _pickingAvatar = NO;
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data) {
            [ErrorPresenter showFileError:@"Read image" path:url.lastPathComponent error:nil];
            return;
        }
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *dest = [[docs stringByAppendingPathComponent:@"profile_avatars"] stringByAppendingPathComponent:url.lastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dest.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        NSError *err = nil;
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        BOOL ok = [data writeToFile:dest options:NSDataWritingAtomic error:&err];
        if (!ok) {
            [ErrorPresenter showFileError:@"Save avatar" path:url.lastPathComponent error:err];
            return;
        }
        self.profile[@"avatar"] = dest;
        [self refreshHeader];
        return;
    }
    [self handlePickedURLs:@[url]];
}

- (void)handlePickedURLs:(NSArray<NSURL *> *)urls {
    NSString *category = [self currentCategory];
    BOOL isMod = [category isEqualToString:InstalledItemCategoryMod];
    NSString *dir = [[InstalledModsManager shared] dirForCategory:category];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSUInteger imported = 0;
    for (NSURL *url in urls) {
        BOOL accessing = [url startAccessingSecurityScopedResource];
        NSString *name = url.lastPathComponent;
        BOOL valid = isMod ? ([name hasSuffix:@".jar"]) : ([name hasSuffix:@".zip"]);
        if (!valid) continue;
        NSString *dest = [dir stringByAppendingPathComponent:name];
        NSError *err = nil;
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        BOOL ok = [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&err];
        if (accessing) [url stopAccessingSecurityScopedResource];
        if (!ok) {
            [ErrorPresenter showFileError:@"Import" path:name error:err];
            continue;
        }
        imported++;
    }
    if (imported == 0) {
        [ErrorPresenter showValidation:@"file" message:isMod ? @"Pick .jar mod files." : @"Pick .zip files."];
        return;
    }
    [HapticManager.shared play:HapticTypeSuccess];
    [self loadItemsIfNeeded];
    [self updateTabCounts];
}

- (void)shareItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Missing file name."];
        return;
    }
    NSString *dir = [[InstalledModsManager shared] dirForCategory:[self currentCategory]];
    NSString *path = [dir stringByAppendingPathComponent:fn];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [dir stringByAppendingPathComponent:[fn stringByAppendingString:@".off"]];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [ErrorPresenter showFileError:@"Share" path:fn error:nil];
        return;
    }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:av animated:YES completion:nil];
}

- (void)renameItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Missing file name."];
        return;
    }
    NSString *category = [self currentCategory];
    NSString *dir = [[InstalledModsManager shared] dirForCategory:category];
    NSString *ext = fn.pathExtension.length > 0 ? [@"." stringByAppendingString:fn.pathExtension] : @"";
    NSString *base = [fn stringByDeletingPathExtension];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename file" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = base;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newBase = alert.textFields.firstObject.text;
        if (![newBase isKindOfClass:[NSString class]] || newBase.length == 0) {
            [ErrorPresenter showValidation:@"name" message:@"Enter a file name."];
            return;
        }
        NSString *newName = [newBase stringByAppendingString:ext];
        NSString *src = [dir stringByAppendingPathComponent:fn];
        NSString *dst = [dir stringByAppendingPathComponent:newName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:dst]) {
            [ErrorPresenter showError:@"Name exists" message:@"A file with that name already exists."];
            return;
        }
        NSError *err = nil;
        BOOL ok = [[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&err];
        if (!ok) {
            [ErrorPresenter showFileError:@"Rename" path:fn error:err];
            return;
        }
        NSString *pid = item[@"project_id"];
        if ([pid isKindOfClass:[NSString class]] && pid.length > 0 && ![item[@"isOrphan"] boolValue]) {
            [[InstalledModsManager shared] updateFilename:newName forProjectId:pid category:category];
        }
        [weakSelf loadItemsIfNeeded];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"];
    if (![fn isKindOfClass:[NSString class]] || fn.length == 0) {
        [ErrorPresenter showValidation:@"file" message:@"Missing file name."];
        return;
    }
    NSString *category = [self currentCategory];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete file?" message:fn preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *dir = [[InstalledModsManager shared] dirForCategory:category];
        NSError *err = nil;
        NSString *path = [dir stringByAppendingPathComponent:fn];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            path = [dir stringByAppendingPathComponent:[fn stringByAppendingString:@".off"]];
        }
        BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
        if (!ok) {
            [ErrorPresenter showFileError:@"Delete" path:fn error:err];
            return;
        }
        NSString *pid = item[@"project_id"];
        if ([pid isKindOfClass:[NSString class]] && pid.length > 0) {
            [[InstalledModsManager shared] removeProjectId:pid category:category];
        }
        [HapticManager.shared play:HapticTypeSuccess];
        [weakSelf loadItemsIfNeeded];
        [weakSelf updateTabCounts];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)browseTapped {
    NSString *dir = [[InstalledModsManager shared] dirForCategory:[self currentCategory]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
    vc.rootPath = dir;
    vc.title = dir.lastPathComponent;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)menuForItem:(NSDictionary *)item sender:(UIButton *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item[@"title"] ?: item[@"filename"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Details" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf detailForItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Share file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf shareItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf renameItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf deleteItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = sender ?: self.view;
        sheet.popoverPresentationController.sourceRect = sender ? sender.bounds : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)detailForItem:(NSDictionary *)item {
    NSString *fn = item[@"filename"] ?: @"";
    NSString *desc = item[@"description"];
    if (![desc isKindOfClass:[NSString class]] || desc.length == 0) {
        NSString *dir = [[InstalledModsManager shared] dirForCategory:[self currentCategory]];
        NSString *full = [dir stringByAppendingPathComponent:fn];
        NSDictionary *meta = [ModIconReader metadataForFileAtPath:full category:[self currentCategory]];
        desc = meta[@"description"];
        if (![desc isKindOfClass:[NSString class]]) desc = @"";
    }
    NSDictionary *status = [self checkStatusForItem:item];
    NSString *state = status[@"status"] ?: @"";
    NSString *latest = status[@"latest_version"] ?: @"";
    NSString *msg = [NSString stringWithFormat:@"File: %@\nVersion: %@\nAuthor: %@\nMC: %@\nLoader: %@\nSource: %@\nState: %@%@\n\n%@",
                     fn, item[@"version_number"] ?: @"?",
                     item[@"author"] ?: @"?", item[@"mc_version"] ?: @"?",
                     item[@"loader"] ?: @"?", item[@"source"] ?: @"local",
                     state, (latest.length > 0 ? [NSString stringWithFormat:@" (latest %@)", latest] : @""),
                     (desc.length > 0 ? desc : @"No description available.")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item[@"title"] ?: fn message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Share file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf shareItem:item];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Update / reinstall

- (void)primaryActionForItem:(NSDictionary *)item status:(NSDictionary *)status {
    NSString *st = status[@"status"];
    if ([st isEqualToString:@"update"]) [self updateItem:item];
    else if ([st isEqualToString:@"latest"]) [self reinstallItem:item];
    else [self detailForItem:item];
}

- (void)updateItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue] || ![item[@"project_id"] isKindOfClass:[NSString class]]) {
        [ErrorPresenter showInfo:@"Manual file" message:@"This file was added manually. Import it through the launcher to get updates."];
        return;
    }
    [HapticManager.shared play:HapticTypeMedium];
    [self installWithDependenciesForItem:item isUpdate:YES];
}

- (void)reinstallItem:(NSDictionary *)item {
    if ([item[@"isOrphan"] boolValue] || ![item[@"project_id"] isKindOfClass:[NSString class]]) {
        [ErrorPresenter showInfo:@"Manual file" message:@"This file was added manually. Import it through the launcher to reinstall."];
        return;
    }
    [HapticManager.shared play:HapticTypeMedium];
    __weak typeof(self) weakSelf = self;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Reinstall?" message:item[@"title"] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Reinstall" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf installWithDependenciesForItem:item isUpdate:NO];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)updateAllTapped {
    if (_currentTab == ProfileDetailTabOverview || _manifestItems.count == 0) {
        [ErrorPresenter showInfo:@"Nothing to update" message:@"No managed files in this tab."];
        return;
    }
    NSMutableArray *pending = [NSMutableArray array];
    for (NSUInteger i = 0; i < _manifestItems.count; i++) {
        if (i < _checkResults.count && [_checkResults[i][@"status"] isEqualToString:@"update"]) {
            NSMutableDictionary *m = [_manifestItems[i] mutableCopy];
            m[@"latest_url"] = _checkResults[i][@"latest_url"] ?: @"";
            m[@"latest_filename"] = _checkResults[i][@"latest_filename"] ?: m[@"filename"];
            m[@"latest_version"] = _checkResults[i][@"latest_version"] ?: @"";
            [pending addObject:m];
        }
    }
    if (pending.count == 0) {
        [ErrorPresenter showSuccess:@"Up to date" message:@"Everything is already on the latest version."];
        return;
    }
    __weak typeof(self) weakSelf = self;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Update all?" message:[NSString stringWithFormat:@"%lu files", (unsigned long)pending.count] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Update" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf updateQueue:[pending copy]];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)updateQueue:(NSArray *)queue {
    if (queue.count == 0) {
        [self loadItemsIfNeeded];
        return;
    }
    NSMutableArray *rest = [queue mutableCopy];
    NSDictionary *first = rest[0];
    [rest removeObjectAtIndex:0];
    __weak typeof(self) weakSelf = self;
    [self installWithDependenciesForItem:first isUpdate:YES done:^{
        [weakSelf updateQueue:[rest copy]];
    }];
}

- (void)installWithDependenciesForItem:(NSDictionary *)item isUpdate:(BOOL)isUpdate {
    [self installWithDependenciesForItem:item isUpdate:isUpdate done:nil];
}

- (void)installWithDependenciesForItem:(NSDictionary *)item isUpdate:(BOOL)isUpdate done:(void(^)(void))done {
    NSString *projectId = item[@"project_id"];
    NSString *category = item[@"category"] ?: [self currentCategory];
    if (![projectId isKindOfClass:[NSString class]] || projectId.length == 0) {
        if (done) done();
        return;
    }
    NSString *mc = [self profileMcVersion];
    NSString *loader = [self profileLoader];

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Resolving dependencies" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [loading.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:loading.view.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:loading.view.topAnchor constant:56],
        [spinner.widthAnchor constraintEqualToConstant:40],
        [spinner.heightAnchor constraintEqualToConstant:40],
        [loading.view.heightAnchor constraintGreaterThanOrEqualToConstant:110],
    ]];
    [self presentViewController:loading animated:YES completion:nil];

    __weak typeof(self) weakSelf = self;
    NSString *source = [item[@"source"] isKindOfClass:[NSString class]] && [(NSString *)item[@"source"] length] > 0 ? item[@"source"] : @"modrinth";
    [[DependencyResolver shared] resolveDependenciesForProjectId:projectId source:source targetVersion:mc targetLoader:loader completion:^(NSArray *deps, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    [ErrorPresenter showError:@"Error" message:[NSString stringWithFormat:@"Could not resolve dependencies: %@", error.localizedDescription]];
                    if (done) done();
                    return;
                }
                [weakSelf continueInstall:item deps:deps isUpdate:isUpdate category:category done:done];
            }];
        });
    }];
}

- (void)continueInstall:(NSDictionary *)item deps:(NSArray *)deps isUpdate:(BOOL)isUpdate category:(NSString *)category done:(void(^)(void))done {
    // Build one sequential job queue: main file first, then missing dependencies.
    // Each job: @{versionDict, modRef, filename, versionNumber, title, projectId, iconURL, source, recordCategory}
    NSMutableArray *jobs = [NSMutableArray array];

    NSDictionary *status = [self checkStatusForItem:item];
    NSString *filename = isUpdate ? (status[@"latest_filename"] ?: item[@"filename"]) : item[@"filename"];
    NSString *versionNumber = isUpdate ? (status[@"latest_version"] ?: item[@"version_number"]) : item[@"version_number"];
    NSDictionary *versionDict = nil;
    if (isUpdate && [status[@"latest_version_dict"] isKindOfClass:[NSDictionary class]]) {
        versionDict = status[@"latest_version_dict"];
    } else {
        versionDict = @{@"url": item[@"url"] ?: @"", @"filename": filename ?: @""};
    }
    NSString *itemSource = ([item[@"source"] isKindOfClass:[NSString class]] && [(NSString *)item[@"source"] length] > 0)
        ? item[@"source"] : @"modrinth";
    NSMutableDictionary *mainMod = [@{@"project_id": item[@"project_id"] ?: @""} mutableCopy];
    if ([itemSource isEqualToString:@"curseforge"]) mainMod[@"_source"] = @"curseforge";
    [jobs addObject:@{
        @"versionDict": versionDict ?: @{},
        @"modRef": [mainMod copy],
        @"filename": filename ?: @"file.jar",
        @"versionNumber": versionNumber ?: @"",
        @"title": item[@"title"] ?: @"",
        @"projectId": item[@"project_id"] ?: @"",
        @"iconURL": ([item[@"icon_url"] isKindOfClass:[NSString class]] ? item[@"icon_url"] : @""),
        @"source": itemSource,
        @"recordCategory": category ?: InstalledItemCategoryMod,
    }];

    NSString *modsVer = VersionDirectoryManager.shared.currentVersion;
    for (NSDictionary *dep in deps) {
        if (![dep isKindOfClass:[NSDictionary class]]) continue;
        NSString *depPid = dep[@"project_id"];
        if (![depPid isKindOfClass:[NSString class]] || depPid.length == 0) continue;
        if ([[DependencyResolver shared] isProjectInstalled:depPid category:InstalledItemCategoryMod]) continue;
        NSString *depSource = ([dep[@"source"] isKindOfClass:[NSString class]] && [(NSString *)dep[@"source"] length] > 0)
            ? dep[@"source"] : @"modrinth";
        NSMutableDictionary *depMod = [@{@"project_id": depPid} mutableCopy];
        if ([depSource isEqualToString:@"curseforge"]) depMod[@"_source"] = @"curseforge";
        NSMutableDictionary *depVer = [NSMutableDictionary dictionary];
        if ([dep[@"url"] isKindOfClass:[NSString class]]) depVer[@"url"] = dep[@"url"];
        if ([dep[@"filename"] isKindOfClass:[NSString class]]) depVer[@"filename"] = dep[@"filename"];
        if (dep[@"_cfFileId"]) depVer[@"_cfFileId"] = dep[@"_cfFileId"];
        NSString *depFile = ([dep[@"filename"] isKindOfClass:[NSString class]] && [(NSString *)dep[@"filename"] length] > 0)
            ? dep[@"filename"] : [NSString stringWithFormat:@"%@.jar", depPid];
        (void)modsVer;
        [jobs addObject:@{
            @"versionDict": [depVer copy],
            @"modRef": [depMod copy],
            @"filename": depFile,
            @"versionNumber": ([dep[@"version"] isKindOfClass:[NSString class]] ? dep[@"version"] : @""),
            @"title": ([dep[@"title"] isKindOfClass:[NSString class]] ? dep[@"title"] : depPid),
            @"projectId": depPid,
            @"iconURL": ([dep[@"icon_url"] isKindOfClass:[NSString class]] ? dep[@"icon_url"] : @""),
            @"source": depSource,
            @"recordCategory": InstalledItemCategoryMod,
        }];
    }
    [self downloadJobQueue:[jobs copy] index:0 category:category done:done];
}

- (void)downloadJobQueue:(NSArray *)jobs index:(NSUInteger)index category:(NSString *)category done:(void(^)(void))done {
    if (index >= jobs.count) {
        [HapticManager.shared play:HapticTypeSuccess];
        [self loadItemsIfNeeded];
        if (done) done();
        return;
    }
    NSDictionary *job = jobs[index];
    __weak typeof(self) weakSelf = self;
    [self downloadSingleJob:job category:category completion:^(BOOL ok) {
        if (!ok && index == 0) {
            // Main file failed: stop, keep deps untouched
            if (done) done();
            return;
        }
        [weakSelf downloadJobQueue:jobs index:index + 1 category:category done:done];
    }];
}

- (void)downloadSingleJob:(NSDictionary *)job category:(NSString *)category completion:(void(^)(BOOL ok))completion {
    NSDictionary *versionDict = job[@"versionDict"];
    NSDictionary *modRef = job[@"modRef"];
    NSString *filename = job[@"filename"];
    NSString *recordCategory = job[@"recordCategory"] ?: category;
    NSString *dir = [[InstalledModsManager shared] dirForCategory:recordCategory];
    NSString *targetPath = [dir stringByAppendingPathComponent:filename];
    DownloadType dtype = DownloadTypeMod;
    if ([recordCategory isEqualToString:InstalledItemCategoryShaderPack]) dtype = DownloadTypeShader;
    else if ([recordCategory isEqualToString:InstalledItemCategoryResourcePack]) dtype = DownloadTypeResourcePack;
    DownloadTask *hubTask = [[DownloadManager shared] beginTaskWithName:job[@"title"] ?: filename type:dtype];
    [hubTask setCancelBlock:^{}];
    __weak typeof(self) weakSelf = self;
    [ModSourceService downloadVersion:versionDict ofMod:modRef progress:^(float p) {
        [[DownloadManager shared] updateProgress:p forTask:hubTask];
    } completion:^(NSString *dlPath, NSError *dlError) {
        [[DownloadManager shared] completeTask:hubTask error:dlError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!dlPath || dlError) {
                [ErrorPresenter showNetworkError:dlError message:@"Download failed."];
                if (completion) completion(NO);
                return;
            }
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
            NSError *moveErr = nil;
            [[NSFileManager defaultManager] moveItemAtPath:dlPath toPath:targetPath error:&moveErr];
            if (moveErr) {
                [ErrorPresenter showFileError:@"Install" path:filename error:moveErr];
                if (completion) completion(NO);
                return;
            }
            [[InstalledModsManager shared] recordProjectId:job[@"projectId"]
                                                     title:job[@"title"]
                                             versionNumber:job[@"versionNumber"]
                                                  filename:filename
                                                   iconURL:job[@"iconURL"]
                                                    source:job[@"source"]
                                                  category:recordCategory
                                                 mcVersion:[weakSelf profileMcVersion]
                                                    loader:[weakSelf profileLoader]];
            if (completion) completion(YES);
        });
    }];
}

- (void)downloadAndReplaceItem:(NSDictionary *)item versionDict:(NSDictionary *)versionDict filename:(NSString *)filename versionNumber:(NSString *)versionNumber category:(NSString *)category done:(void(^)(void))done {
    NSString *itemSource = ([item[@"source"] isKindOfClass:[NSString class]] && [(NSString *)item[@"source"] length] > 0)
        ? item[@"source"] : @"modrinth";
    NSMutableDictionary *modRef = [@{@"project_id": item[@"project_id"] ?: @""} mutableCopy];
    if ([itemSource isEqualToString:@"curseforge"]) modRef[@"_source"] = @"curseforge";
    NSDictionary *job = @{
        @"versionDict": versionDict ?: @{},
        @"modRef": [modRef copy],
        @"filename": filename ?: @"file.jar",
        @"versionNumber": versionNumber ?: @"",
        @"title": item[@"title"] ?: @"",
        @"projectId": item[@"project_id"] ?: @"",
        @"iconURL": ([item[@"icon_url"] isKindOfClass:[NSString class]] ? item[@"icon_url"] : @""),
        @"source": itemSource,
        @"recordCategory": category ?: InstalledItemCategoryMod,
    };
    [self downloadJobQueue:@[job] index:0 category:category done:done];
}

#pragma mark - Save

- (void)saveTapped {
    [HapticManager.shared play:HapticTypeMedium];
    NSString *name = _profile[@"name"];
    if (![name isKindOfClass:[NSString class]] || name.length == 0) {
        // Fall back to old name or version id before erroring
        if ([_originalName isKindOfClass:[NSString class]] && _originalName.length > 0) {
            _profile[@"name"] = _originalName;
            name = _originalName;
        } else {
            [ErrorPresenter showValidation:@"profile name" message:@"Enter a profile name."];
            return;
        }
    }
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    BOOL isRename = _originalName && ![name isEqualToString:_originalName];
    if ((isRename && profiles[name]) || (_isNewProfile && profiles[name])) {
        [ErrorPresenter showError:@"Error" message:@"A profile with this name already exists."];
        return;
    }
    if (isRename && _originalName.length > 0) [profiles removeObjectForKey:_originalName];
    profiles[name] = _profile;
    if (!_originalName || [PLProfiles.current.selectedProfileName isEqualToString:_originalName]) {
        PLProfiles.current.selectedProfileName = name;
    }
    if (!self.pendingVersion && _profile[@"lastVersionId"]) self.pendingVersion = _profile[@"lastVersionId"];
    if (self.pendingVersion) _profile[@"lastVersionId"] = self.pendingVersion;
    [PLProfiles.current save];
    [ProfileAvatarManager.shared updateAppIconForCurrentProfile];
    _originalName = [name copy];
    _isNewProfile = NO;
    [ErrorPresenter showSuccess:@"Saved" message:@"Profile saved."];
    [self refreshHeader];
}

@end
