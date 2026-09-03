#import "ProfileListViewController.h"
#import "ThemeManager.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "VersionDirectoryManager.h"
#import "HapticManager.h"
#import "ProfileAvatarManager.h"
#import "AmethystBlurView.h"
#import "ios_uikit_bridge.h"
#import "InstalledModsManager.h"
#import "utils.h"
#import <objc/runtime.h>

static NSString * const kProfileCell = @"ProfileCell";

@interface ProfileCell : UITableViewCell
@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *versionLabel;
@property (nonatomic) UILabel *loaderLabel;
@property (nonatomic) UIView *badgeView;
@property (nonatomic) UILabel *badgeLabel;
@property (nonatomic) UIButton *editAvatarBtn;
@property (nonatomic) UIStackView *countStack;
@end

@implementation ProfileCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 16;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.3].CGColor;
        
        _avatarView = [[UIImageView alloc] init];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.layer.cornerRadius = 28;
        _avatarView.backgroundColor = ThemeManager.shared.separatorColor;
        _avatarView.image = [UIImage systemImageNamed:@"person.crop.circle"];
        _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_avatarView];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        [self.contentView addSubview:_nameLabel];
        
        _versionLabel = [[UILabel alloc] init];
        _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _versionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _versionLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_versionLabel];
        
        _loaderLabel = [[UILabel alloc] init];
        _loaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _loaderLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _loaderLabel.textColor = ThemeManager.shared.accentColor;
        [self.contentView addSubview:_loaderLabel];
        
        _badgeView = [[UIView alloc] init];
        _badgeView.translatesAutoresizingMaskIntoConstraints = NO;
        _badgeView.layer.cornerRadius = 10;
        _badgeView.clipsToBounds = YES;
        _badgeView.hidden = YES;
        [self.contentView addSubview:_badgeView];
        
        _badgeLabel = [[UILabel alloc] init];
        _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _badgeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        [_badgeView addSubview:_badgeLabel];
        
        _editAvatarBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _editAvatarBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_editAvatarBtn setImage:[UIImage systemImageNamed:@"camera.fill"] forState:UIControlStateNormal];
        _editAvatarBtn.tintColor = ThemeManager.shared.accentColor;
        _editAvatarBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        _editAvatarBtn.layer.cornerRadius = 14;
        _editAvatarBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        _editAvatarBtn.layer.shadowOpacity = 0.15;
        _editAvatarBtn.layer.shadowOffset = CGSizeMake(0, 2);
        _editAvatarBtn.layer.shadowRadius = 4;
        [self.contentView addSubview:_editAvatarBtn];
        
        // Count stack for mod/rp/sp
        _countStack = [[UIStackView alloc] init];
        _countStack.translatesAutoresizingMaskIntoConstraints = NO;
        _countStack.axis = UILayoutConstraintAxisHorizontal;
        _countStack.spacing = 8;
        _countStack.alignment = UIStackViewAlignmentCenter;
        _countStack.distribution = UIStackViewDistributionEqualSpacing;
        [self.contentView addSubview:_countStack];
        
        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:56],
            [_avatarView.heightAnchor constraintEqualToConstant:56],
            
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:16],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_editAvatarBtn.leadingAnchor constant:-8],
            
            [_versionLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_versionLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            
            [_loaderLabel.topAnchor constraintEqualToAnchor:_versionLabel.bottomAnchor constant:2],
            [_loaderLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            
            [_countStack.topAnchor constraintEqualToAnchor:_loaderLabel.bottomAnchor constant:4],
            [_countStack.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_countStack.trailingAnchor constraintLessThanOrEqualToAnchor:_editAvatarBtn.leadingAnchor constant:-8],
            [_countStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            
            [_editAvatarBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_editAvatarBtn.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_editAvatarBtn.widthAnchor constraintEqualToConstant:28],
            [_editAvatarBtn.heightAnchor constraintEqualToConstant:28],
            
            [_badgeView.trailingAnchor constraintEqualToAnchor:_editAvatarBtn.leadingAnchor constant:-8],
            [_badgeView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_badgeView.heightAnchor constraintEqualToConstant:20],
            [_badgeLabel.leadingAnchor constraintEqualToAnchor:_badgeView.leadingAnchor constant:8],
            [_badgeLabel.trailingAnchor constraintEqualToAnchor:_badgeView.trailingAnchor constant:-8],
            [_badgeLabel.centerYAnchor constraintEqualToAnchor:_badgeView.centerYAnchor],
        ]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    self.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.3].CGColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _versionLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _loaderLabel.textColor = ThemeManager.shared.accentColor;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    _avatarView.backgroundColor = ThemeManager.shared.separatorColor;
    _editAvatarBtn.tintColor = ThemeManager.shared.accentColor;
    _editAvatarBtn.backgroundColor = ThemeManager.shared.cardBackgroundColor;
}

- (void)configureWithProfile:(NSDictionary *)profile isCurrent:(BOOL)isCurrent avatar:(UIImage *)avatar loaderName:(NSString *)loaderName version:(NSString *)version modCount:(NSInteger)modCount rpCount:(NSInteger)rpCount spCount:(NSInteger)spCount {
    _nameLabel.text = profile[@"name"] ?: @"(Default)";
    _versionLabel.text = [NSString stringWithFormat:@"MC %@", version ?: @"latest"];
    _loaderLabel.text = loaderName ?: @"Vanilla";
    
    if (avatar) {
        _avatarView.image = avatar;
        _avatarView.tintColor = [UIColor clearColor];
    } else {
        _avatarView.image = [UIImage systemImageNamed:@"person.crop.circle"];
        _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    }
    
    if (isCurrent) {
        _badgeView.hidden = NO;
        _badgeView.backgroundColor = ThemeManager.shared.accentColor;
        _badgeLabel.text = localize(@"profiles.in_use", nil);
    } else {
        _badgeView.hidden = YES;
    }
    
    // Update count stack
    for (UIView *v in _countStack.arrangedSubviews) [v removeFromSuperview];
    
    if (modCount > 0) {
        UILabel *lbl = [self countLabelWithIcon:@"puzzlepiece.extension" count:modCount color:[UIColor systemPurpleColor]];
        [_countStack addArrangedSubview:lbl];
    }
    if (rpCount > 0) {
        UILabel *lbl = [self countLabelWithIcon:@"paintpalette" count:rpCount color:[UIColor systemOrangeColor]];
        [_countStack addArrangedSubview:lbl];
    }
    if (spCount > 0) {
        UILabel *lbl = [self countLabelWithIcon:@"paintbrush.pointed" count:spCount color:[UIColor systemBlueColor]];
        [_countStack addArrangedSubview:lbl];
    }
    _countStack.hidden = (_countStack.arrangedSubviews.count == 0);
}

- (UILabel *)countLabelWithIcon:(NSString *)iconName count:(NSInteger)count color:(UIColor *)color {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    lbl.textColor = color;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Use SF Symbol as text
    lbl.text = [NSString stringWithFormat:@"%@ %ld", iconName, (long)count];
    [lbl sizeToFit];
    return lbl;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _avatarView.image = nil;
    _avatarView.tintColor = ThemeManager.shared.secondaryTextColor;
    _nameLabel.text = nil;
    _versionLabel.text = nil;
    _loaderLabel.text = nil;
    _badgeView.hidden = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


#pragma mark - View Controller

@interface ProfileListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray *allProfiles;
@property (nonatomic) NSString *selectedProfileName;
@property (nonatomic) ProfileAvatarManager *avatarManager;
@end

@implementation ProfileListViewController

- (instancetype)initWithProfile:(NSMutableDictionary *)profile {
    self = [super init];
    if (self) {
        _profile = profile;
        _avatarManager = ProfileAvatarManager.shared;
        _selectedProfileName = PLProfiles.current.selectedProfileName;
        _isCurrentProfile = [_profile[@"name"] isEqualToString:_selectedProfileName];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"Profiles", nil);
    self.view.clipsToBounds = YES;
    [self setupUI];
    [self loadProfiles];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [AmethystBlurView installInView:self.view];
}

- (void)setupUI {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 96;
    _tableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
    [_tableView registerClass:[ProfileCell class] forCellReuseIdentifier:kProfileCell];
    [self.view addSubview:_tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    // Header with add profile button
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [addBtn setTitle:localize(@"Create New Profile", nil) forState:UIControlStateNormal];
    [addBtn setTitleColor:ThemeManager.shared.accentColor forState:UIControlStateNormal];
    addBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    addBtn.backgroundColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.1];
    addBtn.layer.cornerRadius = 20;
    [addBtn addTarget:self action:@selector(createNewProfile) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:addBtn];
    [NSLayoutConstraint activateConstraints:@[
        [addBtn.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [addBtn.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        [addBtn.heightAnchor constraintEqualToConstant:40],
    ]];
    _tableView.tableHeaderView = headerView;
}

- (void)loadProfiles {
    NSMutableDictionary *profilesDict = PLProfiles.current.profiles;
    _allProfiles = [profilesDict.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"]];
    }];
    [_tableView reloadData];
}

- (void)createNewProfile {
    [HapticManager.shared play:HapticTypeLight];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Create New Profile", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = localize(@"profile.list.name.placeholder", nil);
        tf.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Create", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text ?: @"";
        if (name.length == 0) return;
        
        NSMutableDictionary *profiles = PLProfiles.current.profiles;
        if (profiles[name]) {
            [self showAlert:localize(@"Profile name already exists", nil)];
            return;
        }
        
        NSMutableDictionary *newProfile = [NSMutableDictionary dictionary];
        newProfile[@"name"] = name;
        newProfile[@"lastVersionId"] = @"latest-release";
        newProfile[@"modLoader"] = @"fabric";
        newProfile[@"avatar"] = @"fabric";
        profiles[name] = newProfile;
        [PLProfiles.current save];
        
        [self loadProfiles];
        [self selectProfile:name];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectProfile:(NSString *)name {
    _selectedProfileName = name;
    PLProfiles.current.selectedProfileName = name;
    [PLProfiles.current save];
    [_tableView reloadData];
    
    // Notify delegate to update current profile
    NSDictionary *selected = _allProfiles.firstObject;
    for (NSDictionary *p in _allProfiles) {
        if ([p[@"name"] isEqualToString:name]) {
            selected = p;
            break;
        }
    }
    if (_delegate && [_delegate respondsToSelector:@selector(profileListDidUpdateProfile:)]) {
        [_delegate profileListDidUpdateProfile:[selected mutableCopy]];
    }
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Notification", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Current profile + Other profiles
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // Current profile
    return MAX(0, (NSInteger)_allProfiles.count - 1); // Others
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? localize(@"Current Profile", nil) : localize(@"Other Profiles", nil);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (!title) return nil;
    
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = ThemeManager.shared.secondaryTextColor;
    label.text = title;
    [header addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-4],
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileCell *cell = [tableView dequeueReusableCellWithIdentifier:kProfileCell forIndexPath:indexPath];
    
    NSDictionary *profileDict;
    BOOL isCurrent;
    
    if (indexPath.section == 0) {
        profileDict = _allProfiles.firstObject;
        isCurrent = YES;
    } else {
        profileDict = _allProfiles[indexPath.row + 1];
        isCurrent = NO;
    }
    
    NSString *avatarKey = profileDict[@"avatar"] ?: @"fabric";
    UIImage *avatar = [_avatarManager avatarImageForKey:avatarKey];
    NSString *loader = profileDict[@"modLoader"] ?: @"vanilla";
    NSString *loaderDisplay = [self loaderDisplayName:loader];
    NSString *version = profileDict[@"lastVersionId"] ?: @"latest-release";
    
    // Get counts for this profile
    NSString *profileName = profileDict[@"name"];
    NSInteger modCount = 0, rpCount = 0, spCount = 0;
    if (profileName) {
        NSArray *mods = [[InstalledModsManager shared] allInstalledForCategory:InstalledItemCategoryMod];
        NSArray *rps = [[InstalledModsManager shared] allInstalledForCategory:InstalledItemCategoryResourcePack];
        NSArray *sps = [[InstalledModsManager shared] allInstalledForCategory:InstalledItemCategoryShaderPack];
        // Filter by profile (installed_mods.json is per profile)
        modCount = mods.count;
        rpCount = rps.count;
        spCount = sps.count;
    }
    
    [cell configureWithProfile:profileDict isCurrent:isCurrent avatar:avatar loaderName:loaderDisplay version:version modCount:modCount rpCount:rpCount spCount:spCount];
    
    __weak typeof(self) weakSelf = self;
    cell.editAvatarBtn.tag = indexPath.section == 0 ? 0 : indexPath.row + 1;
    [cell.editAvatarBtn addTarget:self action:@selector(editAvatarTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [HapticManager.shared play:HapticTypeLight];
    
    NSDictionary *profileDict;
    if (indexPath.section == 0) {
        profileDict = _allProfiles.firstObject;
    } else {
        profileDict = _allProfiles[indexPath.row + 1];
    }
    
    [self selectProfile:profileDict[@"name"]];
}

- (void)editAvatarTapped:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    NSInteger idx = sender.tag;
    NSDictionary *profileDict = idx == 0 ? _allProfiles.firstObject : _allProfiles[idx];
    [self showAvatarPickerForProfile:[profileDict mutableCopy] fromButton:sender];
}

- (void)showAvatarPickerForProfile:(NSMutableDictionary *)profile fromButton:(UIButton *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"profiles.choose_avatar", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *avatars = @[
        @{@"key": @"fabric", @"name": @"Fabric", @"icon": @"cube.transparent"},
        @{@"key": @"forge", @"name": @"Forge", @"icon": @"hammer.fill"},
        @{@"key": @"neoforge", @"name": @"NeoForge", @"icon": @"hammer.circle.fill"},
        @{@"key": @"modpack", @"name": @"Modpack", @"icon": @"square.stack.3d.up"},
        @{@"key": @"vanilla", @"name": @"Vanilla", @"icon": @"cube.fill"},
        @{@"key": @"quilt", @"name": @"Quilt", @"icon": @"patchwork"},
        @{@"key": @"custom", @"name": localize(@"profiles.custom_avatar", nil), @"icon": @"photo.fill"},
    ];
    
    for (NSDictionary *av in avatars) {
        BOOL isSelected = [profile[@"avatar"] isEqualToString:av[@"key"]];
        NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", av[@"name"]] : av[@"name"];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([av[@"key"] isEqualToString:@"custom"]) {
                [self pickCustomAvatarForProfile:profile];
            } else {
                profile[@"avatar"] = av[@"key"];
                [self saveProfileAndReload:profile];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = sender;
        sheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pickCustomAvatarForProfile:(NSMutableDictionary *)profile {
    // Use document picker for custom image
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    objc_setAssociatedObject(picker, @"profile", profile, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;
    NSURL *url = urls.firstObject;
    NSMutableDictionary *profile = (NSMutableDictionary *)objc_getAssociatedObject(controller, @"profile");
    
    // Copy to app sandbox
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return;
    
    NSString *filename = [NSString stringWithFormat:@"avatar_%@.png", profile[@"name"]];
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:filename];
    [data writeToFile:docPath atomically:YES];
    
    profile[@"avatar"] = docPath; // Store local path
    [self saveProfileAndReload:profile];
}

- (void)saveProfileAndReload:(NSMutableDictionary *)profile {
    NSString *name = profile[@"name"];
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    profiles[name] = profile;
    [PLProfiles.current save];
    [self loadProfiles];
    [ProfileAvatarManager.shared updateAppIconForCurrentProfile];
    
    if (_delegate && [_delegate respondsToSelector:@selector(profileListDidUpdateProfile:)]) {
        [_delegate profileListDidUpdateProfile:[profile mutableCopy]];
    }
}

- (NSString *)loaderDisplayName:(NSString *)loader {
    if ([loader isEqualToString:@"fabric"]) return @"Fabric";
    if ([loader isEqualToString:@"forge"]) return @"Forge";
    if ([loader isEqualToString:@"neoforge"]) return @"NeoForge";
    if ([loader isEqualToString:@"quilt"]) return @"Quilt";
    if ([loader isEqualToString:@"modpack"]) return @"Modpack";
    return @"Vanilla";
}

#pragma mark - Theme

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _tableView.backgroundColor = [UIColor clearColor];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end