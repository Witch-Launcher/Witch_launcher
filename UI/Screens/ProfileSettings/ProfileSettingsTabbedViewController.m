#import "ProfileSettingsTabbedViewController.h"
#import "ProfileListViewController.h"
#import "ProfileInstalledItemsViewController.h"
#import "InstalledModsManager.h"
#import "ThemeManager.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "HapticManager.h"
#import "AmethystBlurView.h"
#import "VersionDirectoryManager.h"
#import "ProfileAvatarManager.h"

@interface ProfileSettingsTabbedViewController () <UITabBarControllerDelegate, ProfileListViewControllerDelegate>
@property (nonatomic) UITabBarController *tabBarController;
@property (nonatomic) ProfileListViewController *profileListVC;
@property (nonatomic) ProfileInstalledItemsViewController *modsVC;
@property (nonatomic) ProfileInstalledItemsViewController *shaderVC;
@property (nonatomic) ProfileInstalledItemsViewController *resourcePackVC;
@property (nonatomic) NSMutableDictionary *originalProfile;
@end

@implementation ProfileSettingsTabbedViewController

- (instancetype)initWithProfile:(NSMutableDictionary *)profile isNew:(BOOL)isNew {
    self = [super init];
    if (self) {
        _profile = [profile mutableCopy];
        _isNewProfile = isNew;
        _originalProfile = [profile mutableCopy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupTabBarController];
    [self setupNavigationBar];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    [AmethystBlurView installInView:self.view];
}

- (void)setupNavigationBar {
    self.navigationItem.title = @"Cài đặt Profile";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTapped)];
}

- (void)setupTabBarController {
    _tabBarController = [[UITabBarController alloc] init];
    _tabBarController.delegate = self;
    _tabBarController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addChildViewController:_tabBarController];
    [self.view addSubview:_tabBarController.view];
    [_tabBarController didMoveToParentViewController:self];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tabBarController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tabBarController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tabBarController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tabBarController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    // Tab 1: Profile (danh sách profile, avatar, cơ bản)
    _profileListVC = [[ProfileListViewController alloc] initWithProfile:_profile];
    _profileListVC.delegate = self;
    UINavigationController *profileNav = [[UINavigationController alloc] initWithRootViewController:_profileListVC];
    profileNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Profile" image:[UIImage systemImageNamed:@"person.crop.circle"] selectedImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    
    // Tab 2: Mods
    _modsVC = [[ProfileInstalledItemsViewController alloc] init];
    _modsVC.profile = _profile;
    _modsVC.category = InstalledItemCategoryMod;
    UINavigationController *modsNav = [[UINavigationController alloc] initWithRootViewController:_modsVC];
    modsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Mods" image:[UIImage systemImageNamed:@"puzzlepiece.extension"] selectedImage:[UIImage systemImageNamed:@"puzzlepiece.extension.fill"]];
    
    // Tab 3: Shader Packs
    _shaderVC = [[ProfileInstalledItemsViewController alloc] init];
    _shaderVC.profile = _profile;
    _shaderVC.category = InstalledItemCategoryShaderPack;
    UINavigationController *shaderNav = [[UINavigationController alloc] initWithRootViewController:_shaderVC];
    shaderNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Shader" image:[UIImage systemImageNamed:@"paintbrush.pointed"] selectedImage:[UIImage systemImageNamed:@"paintbrush.pointed.fill"]];
    
    // Tab 4: Resource Packs
    _resourcePackVC = [[ProfileInstalledItemsViewController alloc] init];
    _resourcePackVC.profile = _profile;
    _resourcePackVC.category = InstalledItemCategoryResourcePack;
    UINavigationController *rpNav = [[UINavigationController alloc] initWithRootViewController:_resourcePackVC];
    rpNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Resource Pack" image:[UIImage systemImageNamed:@"paintpalette"] selectedImage:[UIImage systemImageNamed:@"paintpalette.fill"]];
    
    _tabBarController.viewControllers = @[profileNav, modsNav, shaderNav, rpNav];
    
    // Style tab bar
    _tabBarController.tabBar.tintColor = ThemeManager.shared.accentColor;
    _tabBarController.tabBar.unselectedItemTintColor = ThemeManager.shared.secondaryTextColor;
    _tabBarController.tabBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _tabBarController.tabBar.barTintColor = ThemeManager.shared.cardBackgroundColor;
}

- (void)cancelTapped {
    [HapticManager.shared play:HapticTypeLight];
    if (_delegate && [_delegate respondsToSelector:@selector(profileSettingsDidCancel:)]) {
        [_delegate profileSettingsDidCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveTapped {
    [HapticManager.shared play:HapticTypeMedium];
    
    // Validate profile name
    NSString *name = _profile[@"name"] ?: @"";
    if (name.length == 0) {
        [self showAlert:@"Tên profile không được để trống"];
        return;
    }
    
    // Check duplicate name
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    if (!_isNewProfile && ![name isEqualToString:_originalProfile[@"name"]]) {
        if (profiles[name]) {
            [self showAlert:@"Tên profile đã tồn tại"];
            return;
        }
    } else if (_isNewProfile && profiles[name]) {
        [self showAlert:@"Tên profile đã tồn tại"];
        return;
    }
    
    // Save profile
    if (!_isNewProfile && _originalProfile[@"name"] && ![name isEqualToString:_originalProfile[@"name"]]) {
        [profiles removeObjectForKey:_originalProfile[@"name"]];
    }
    profiles[name] = _profile;
    if ([PLProfiles.current.selectedProfileName isEqualToString:_originalProfile[@"name"]]) {
        PLProfiles.current.selectedProfileName = name;
    }
    [PLProfiles.current save];
    
    // Update app icon if avatar changed
    [ProfileAvatarManager.shared updateAppIconForCurrentProfile];
    
    if (_delegate && [_delegate respondsToSelector:@selector(profileSettingsDidSave:)]) {
        [_delegate profileSettingsDidSave:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thông báo" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    _tabBarController.tabBar.backgroundColor = theme.cardBackgroundColor;
    _tabBarController.tabBar.barTintColor = theme.cardBackgroundColor;
    _tabBarController.tabBar.tintColor = theme.accentColor;
    _tabBarController.tabBar.unselectedItemTintColor = theme.secondaryTextColor;
}

#pragma mark - ProfileListViewControllerDelegate

- (void)profileListDidUpdateProfile:(NSMutableDictionary *)updatedProfile {
    _profile = updatedProfile;
    // Sync to other tabs
    _modsVC.profile = updatedProfile;
    _shaderVC.profile = updatedProfile;
    _resourcePackVC.profile = updatedProfile;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end