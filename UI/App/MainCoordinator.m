#import "MainCoordinator.h"
#import <sys/time.h>
#import "AmethystRootViewController.h"
#import "RightPanelViewController.h"
#import "FileListViewController.h"

#import "MainMenuViewController.h"
#import "GameListViewController.h"
#import "ModListViewController.h"
#import "ModpackListViewController.h"
#import "ShaderListViewController.h"
#import "SettingsViewController.h"
#import "AccountViewController.h"
#import "DownloadHubViewController.h"
#import "VersionBrowserViewController.h"
#import "ResourcePackListViewController.h"
#import "MapListViewController.h"
#import "ModDetailViewController.h"
#import "FileBrowserViewController.h"
#import "ProfileSettingsViewController.h"

#import "PLProfiles.h"
#import "MinecraftResourceDownloadTask.h"
#import "DownloadProgressOverlay.h"
#import "AmethystBlurView.h"
#import "authenticator/BaseAuthenticator.h"
#import "SurfaceViewController.h"
#import "ios_uikit_bridge.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import "VersionDirectoryManager.h"
#import "PLProfiles.h"
#import "MinecraftResourceUtils.h"
#import "ElySkinHead.h"

@interface MainCoordinator () <UIAlertViewDelegate> {
    CGFloat _lastMsTime;
    NSUInteger _lastCompletedUnitCount;
    NSTimeInterval _lastSpeedUpdateTime;
    NSString *_cachedSpeed;
    NSString *_cachedEta;
    BOOL _isObservingProgress;
}
@property (nonatomic) NSMutableDictionary<NSNumber *, UIViewController *> *tabViewControllers;
@property (nonatomic) MainMenuViewController *mainMenuVC;
@property (nonatomic) MinecraftResourceDownloadTask *downloadTask;
@property (nonatomic, strong) DownloadProgressOverlay *progressOverlay;
@property (nonatomic) UIAlertController *jitAlert;

@property (nonatomic) ModListViewController *modListVC;
@property (nonatomic) ShaderListViewController *shaderListVC;
@property (nonatomic) ModpackListViewController *modpackListVC;
@property (nonatomic) ResourcePackListViewController *resourcePackListVC;
@property (nonatomic) MapListViewController *mapListVC;
@end

@implementation MainCoordinator

- (instancetype)initWithRootVC:(AmethystRootViewController *)rootVC {
    self = [super init];
    if (self) {
        _rootVC = rootVC;
        _tabViewControllers = [NSMutableDictionary dictionary];
        _downloadManager = [DownloadManager shared];
    }
    return self;
}

- (void)start {
    _mainMenuVC = [[MainMenuViewController alloc] init];
    _mainMenuVC.coordinator = self;
    [self.rootVC switchContentTo:_mainMenuVC animated:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountDidChange) name:@"AccountDidChangeNotification" object:nil];
    [self accountDidChange];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [MinecraftResourceUtils refreshLocalVersionList];
    });
    [MinecraftResourceUtils refreshRemoteVersionList];
}

- (void)accountDidChange {
    NSString *name = BaseAuthenticator.current.authData[@"username"] ?: nil;
    UIImage *skin = nil;
    NSString *profileId = BaseAuthenticator.current.authData[@"profileId"];
    BOOL isEly = [BaseAuthenticator.current.authData[@"accountType"] isEqualToString:@"elyby"];
    if (isEly && name.length > 0) {
        __weak typeof(self) weakSelf = self;
        [ElySkinHead headForUsername:name size:60 completion:^(UIImage *head) {
            if (!head) return;
            MainCoordinator *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.rootVC.rightPanelVC updateAccountWithName:name skin:head];
        }];
    } else if (profileId && [profileId length] > 0 && ![profileId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        NSString *skinURL = [NSString stringWithFormat:@"https://mc-heads.net/head/%@/60", profileId];
        NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:skinURL]];
        if (imgData) skin = [UIImage imageWithData:imgData];
    }
    [self.rootVC.rightPanelVC updateAccountWithName:name skin:skin];
}

- (void)switchToTab:(SidebarTab)tab {
    UIViewController *vc = self.tabViewControllers[@(tab)];
    if (!vc) {
        switch (tab) {
            case SidebarTabGame:
                vc = self.mainMenuVC;
                break;
            case SidebarTabMod:
                if (!_modListVC) {
                    _modListVC = [[ModListViewController alloc] init];
                    _modListVC.coordinator = self;
                }
                if (!_modListVC.navigationController) {
                    vc = [[UINavigationController alloc] initWithRootViewController:_modListVC];
                } else {
                    vc = _modListVC.navigationController;
                }
                break;
            case SidebarTabModpack:
                if (!_modpackListVC) {
                    _modpackListVC = [[ModpackListViewController alloc] init];
                    _modpackListVC.coordinator = self;
                }
                vc = _modpackListVC;
                break;
            case SidebarTabShader:
                if (!_shaderListVC) {
                    _shaderListVC = [[ShaderListViewController alloc] init];
                    _shaderListVC.coordinator = self;
                }
                vc = _shaderListVC;
                break;
            case SidebarTabResourcePack:
                if (!_resourcePackListVC) {
                    _resourcePackListVC = [[ResourcePackListViewController alloc] init];
                    _resourcePackListVC.coordinator = self;
                }
                vc = _resourcePackListVC;
                break;
            case SidebarTabMap:
                if (!_mapListVC) {
                    _mapListVC = [[MapListViewController alloc] init];
                    _mapListVC.coordinator = self;
                }
                vc = _mapListVC;
                break;
        }
        if (vc && tab != SidebarTabGame) {
            self.tabViewControllers[@(tab)] = vc;
        }
    }
    if (vc) {
        [self.rootVC switchContentTo:vc animated:YES];
    }
}

- (void)showAccount {
    AccountViewController *vc = [[AccountViewController alloc] init];
    vc.coordinator = self;
    [self.rootVC presentContentAsSheet:vc];
}

- (void)showSettings {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    vc.coordinator = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.rootVC presentContentAsSheet:nav];
}

- (void)showFileManager {
    FileBrowserViewController *vc = [[FileBrowserViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.rootVC presentViewController:nav animated:YES completion:nil];
}

- (void)showVersionPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Select Version", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"e.g. 1.21.4";
        field.text = VersionDirectoryManager.shared.currentVersion;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Set", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *ver = alert.textFields[0].text;
        if (ver.length > 0) {
            VersionDirectoryManager.shared.currentVersion = ver;
            [self.rootVC.rightPanelVC refreshVersions];
        }
    }]];
    [self.rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)showModLoaderPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"Mod Loader", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *loaders = @[@"Vanilla", @"Fabric", @"Forge", @"Quilt", @"NeoForge"];
    for (NSString *loader in loaders) {
        [sheet addAction:[UIAlertAction actionWithTitle:loader style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            setPrefObject(@"internal.mod_loader", loader);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self.rootVC presentViewController:sheet animated:YES completion:nil];
}

- (void)showDownloadHub {
    DownloadHubViewController *vc = [[DownloadHubViewController alloc] init];
    vc.coordinator = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.rootVC presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Version Management

- (void)showAddVersion {
    VersionBrowserViewController *vc = [[VersionBrowserViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.rootVC presentViewController:nav animated:YES completion:nil];
}

- (void)removeVersion:(NSString *)versionName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:localize(@"Delete %@?", nil), versionName]
                                                                    message:localize(@"This will permanently delete this profile and version. This action cannot be undone.", nil)
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *path = [VersionDirectoryManager.shared versionPathForVersion:versionName];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [self.rootVC.rightPanelVC refreshVersions];
    }]];
    [self.rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)selectVersion:(NSString *)versionName {
    VersionDirectoryManager.shared.currentVersion = versionName;
    [self.rootVC.rightPanelVC refreshVersions];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{@"version": versionName}];
}

- (void)editVersion:(NSString *)versionName {
    NSMutableDictionary *targetProfile = nil;
    for (NSString *key in PLProfiles.current.profiles) {
        NSMutableDictionary *profile = PLProfiles.current.profiles[key];
        if ([profile[@"lastVersionId"] isEqualToString:versionName]) {
            targetProfile = profile;
            break;
        }
    }
    if (!targetProfile) {
        targetProfile = @{
            @"name": versionName,
            @"lastVersionId": versionName,
        }.mutableCopy;
        PLProfiles.current.profiles[versionName] = targetProfile;
    }
    [PLProfiles.current save];

    PLProfiles.current.selectedProfileName = targetProfile[@"name"];

    ProfileSettingsViewController *vc = [ProfileSettingsViewController new];
    vc.profile = targetProfile;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.rootVC presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Launch

- (void)launchGame {
    NSString *accountName = BaseAuthenticator.current.authData[@"username"];
    if (!accountName) {
        showDialog(localize(@"Account Required", nil), localize(@"Please add and select an account first.", nil));
        return;
    }

    if ([accountName hasPrefix:@"Demo."]) {
        showDialog(localize(@"Minecraft Not Purchased", nil), localize(@"Your Microsoft account has not purchased Minecraft. Please purchase the game from minecraft.net to play.", nil));
        return;
    }

    NSString *versionStr = VersionDirectoryManager.shared.currentVersion;
    if (versionStr.length == 0) {
        showDialog(localize(@"No Version", nil), localize(@"Please select a version from the sidebar first.", nil));
        return;
    }

    [self refreshCurrentAccountIfNeeded:^{
        [self showProgressAlert:localize(@"launcher.checking", nil)];
        [self downloadAndLaunchVersion:versionStr];
    }];
}

- (void)launchWithServer:(NSDictionary *)server {
    NSString *accountName = BaseAuthenticator.current.authData[@"username"];
    if (!accountName) {
        showDialog(localize(@"Account Required", nil), localize(@"Please add and select an account first.", nil));
        return;
    }

    if ([accountName hasPrefix:@"Demo."]) {
        showDialog(localize(@"Minecraft Not Purchased", nil), localize(@"Your Microsoft account has not purchased Minecraft. Please purchase the game from minecraft.net to play.", nil));
        return;
    }

    NSString *versionStr = VersionDirectoryManager.shared.currentVersion;
    if (versionStr.length == 0) {
        showDialog(localize(@"No Version", nil), localize(@"Please select a version from the sidebar first.", nil));
        return;
    }
    [self showProgressAlert:localize(@"launcher.checking", nil)];

    setPrefObject(@"internal.last_server", server);

    [self downloadAndLaunchVersion:versionStr];
}

- (void)refreshCurrentAccountIfNeeded:(void (^)(void))completion {
    BaseAuthenticator *auth = BaseAuthenticator.current;
    if (![auth isKindOfClass:[ElyAuthenticator class]]) {
        completion();
        return;
    }

    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:self.rootVC.view title:@"Ely.by Session"];
    __weak typeof(self) weakSelf = self;
    [auth refreshTokenWithCallback:^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && status != nil) {
                [overlay updateProgress:0.5 message:[status isKindOfClass:NSString.class] ? status : @"Refreshing session..."];
                return;
            }
            [overlay dismiss];
            if (!success) {
                NSString *errMsg = [status isKindOfClass:NSError.class] ? [(NSError *)status localizedDescription] : ([status isKindOfClass:NSString.class] ? status : @"Failed to refresh session.");
                showDialog(localize(@"Error", nil), errMsg);
                return;
            }
            if (weakSelf) completion();
        });
    }];
}

- (void)downloadAndLaunchVersion:(NSString *)versionStr {
    NSURL *manifestURL = [NSURL URLWithString:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"];
    [[NSURLSession.sharedSession dataTaskWithURL:manifestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissProgressAlert];
                showDialog(@"Network Error", error.localizedDescription ?: @"Failed to fetch version manifest");
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json[@"versions"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissProgressAlert];
                showDialog(@"Error", @"Invalid version manifest.");
            });
            return;
        }

        remoteVersionList = [NSMutableArray arrayWithArray:json[@"versions"]];

        NSString *lookupId = versionStr;
        NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:lookupId];
        BOOL isLocal = [[NSFileManager defaultManager] fileExistsAtPath:versionDir];
        NSLog(@"[Launch] Checking for version at: %@, isLocal=%d", versionDir, isLocal);

        NSDictionary *versionObj = nil;
        if (isLocal) {
            versionObj = @{@"id": lookupId, @"type": @"custom"};
        } else {
            NSString *targetId = versionStr;
            for (NSDictionary *v in remoteVersionList) {
                if ([v[@"id"] isEqualToString:targetId]) {
                    versionObj = v;
                    break;
                }
            }
            if (!versionObj && remoteVersionList.count > 0) {
                versionObj = remoteVersionList.firstObject;
            }
        }
        if (!versionObj) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissProgressAlert];
                showDialog(@"Error", @"Cannot find version data.");
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadTask = [[MinecraftResourceDownloadTask alloc] init];
            __weak typeof(self) weakSelf = self;
            self.downloadTask.handleError = ^{
                MainCoordinator *strongSelf = weakSelf;
                if (!strongSelf) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf safeRemoveProgressObserver];
                    strongSelf.downloadTask = nil;
                    [strongSelf dismissProgressAlert];
                    showDialog(@"Download Error", @"Failed to download Minecraft resources.");
                });
            };

            [self.downloadTask.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(self.downloadTask)];
            _isObservingProgress = YES;

            [self updateProgressAlert:localize(@"launcher.download", nil)];

            [weakSelf.downloadTask downloadVersion:versionObj];
        });
    }] resume];
}

- (void)safeRemoveProgressObserver {
    if (_isObservingProgress && self.downloadTask.progress) {
        @try {
            [self.downloadTask.progress removeObserver:self forKeyPath:@"fractionCompleted"];
        } @catch (NSException *e) {
            NSLog(@"[MainCoordinator] KVO remove exception (safe): %@", e);
        }
        _isObservingProgress = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {
        NSProgress *progress = (NSProgress *)object;

        if (progress.finished) {
            [self safeRemoveProgressObserver];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressOverlay finishWithMessage:@"Verifying..."];
                [self performJITCheckAndLaunch];
            });
            return;
        }

        NSString *description = self.downloadTask.textProgress.localizedDescription;
        if (!description || [description isEqualToString:@"launcher.download"]) {
            NSProgress *fileProgress = nil;
            for (NSProgress *p in self.downloadTask.progressList) {
                if (p.completedUnitCount > 0 && p.completedUnitCount < p.totalUnitCount) {
                    fileProgress = p;
                    break;
                }
            }
            description = fileProgress.localizedDescription ?: @"Downloading...";
        }

        NSProgress *fileProgress = nil;
        for (NSProgress *p in self.downloadTask.progressList) {
            if (p.completedUnitCount > 0 && p.completedUnitCount < p.totalUnitCount) {
                fileProgress = p;
                break;
            }
        }
        NSString *additional = fileProgress.localizedAdditionalDescription;

        NSUInteger completed = progress.totalUnitCount * progress.fractionCompleted;
        struct timeval tv;
        gettimeofday(&tv, NULL);
        CGFloat now = tv.tv_sec + tv.tv_usec / 1000000.0;

        if (!_cachedSpeed) _cachedSpeed = @"--";
        if (!_cachedEta) _cachedEta = @"--";

        if (now - _lastSpeedUpdateTime >= 1.0) {
            CGFloat dt = now - _lastMsTime;
            CGFloat throughput = dt > 0 ? (completed - _lastCompletedUnitCount) / dt : 0;
            if (throughput > 0) {
                _cachedSpeed = [self formatBytes:(NSUInteger)throughput];
                NSUInteger remaining = progress.totalUnitCount - completed;
                NSTimeInterval eta = remaining / throughput;
                _cachedEta = [self formatTimeRemaining:eta];
            }
            _lastCompletedUnitCount = completed;
            _lastMsTime = now;
            _lastSpeedUpdateTime = now;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressOverlay updateWithFraction:progress.fractionCompleted
                                         description:description
                              additionalDescription:additional
                                               speed:_cachedSpeed ?: @"--"
                                                 eta:_cachedEta ?: @"--"];
        });
    }
}

- (void)performJITCheckAndLaunch {
    BOOL hasTrollStoreJIT = getEntitlementValue(@"com.apple.private.local.sandboxed-jit");

    if (isJITEnabled(false)) {
        [self finishLaunch];
        return;
    }
    if (getPrefBool(@"debug.debug_skip_wait_jit")) {
        NSLog(@"Debug option skipped waiting for JIT.");
        [self finishLaunch];
        return;
    }
    if (hasTrollStoreJIT) {
        NSURL *jitURL = [NSURL URLWithString:[NSString stringWithFormat:@"apple-magnifier://enable-jit?bundle-id=%@", NSBundle.mainBundle.bundleIdentifier]];
        [UIApplication.sharedApplication openURL:jitURL options:@{} completionHandler:nil];
    }

    self.jitAlert = [UIAlertController alertControllerWithTitle:localize(@"launcher.wait_jit.title", nil)
        message:hasTrollStoreJIT ? localize(@"launcher.wait_jit_trollstore.message", nil) : localize(@"launcher.wait_jit.message", nil)
        preferredStyle:UIAlertControllerStyleAlert];
    [self.rootVC presentViewController:self.jitAlert animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!isJITEnabled(false)) {
            usleep(200 * 1000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.jitAlert dismissViewControllerAnimated:YES completion:^{
                [self finishLaunch];
            }];
        });
    });
}

- (void)finishLaunch {
    [self dismissProgressAlert];
    if (self.downloadTask.metadata) {
        // Prepare version directory: set POJAV_GAME_DIR to instance root + symlink → version dir
        [VersionDirectoryManager.shared prepareGameDirectoryForVersion:VersionDirectoryManager.shared.currentVersion];

        // Set up PLProfiles gameDir so JavaLauncher computes the correct gameDir
        NSString *versionId = VersionDirectoryManager.shared.currentVersion;
        NSMutableDictionary *profile = PLProfiles.current.selectedProfile;
        if (profile && [profile isKindOfClass:NSMutableDictionary.class]) {
            profile[@"gameDir"] = [NSString stringWithFormat:@"versions/%@", versionId];
            [PLProfiles.current save];
        } else if (profile) {
            NSMutableDictionary *mutableProfile = profile.mutableCopy;
            mutableProfile[@"gameDir"] = [NSString stringWithFormat:@"versions/%@", versionId];
            PLProfiles.current.profiles[PLProfiles.current.selectedProfileName] = mutableProfile;
            [PLProfiles.current save];
        }

        UIKit_launchMinecraftSurfaceVC(self.rootVC.view.window, self.downloadTask.metadata);
    } else {
        showDialog(@"Error", @"No version metadata available.");
    }
}

#pragma mark - Progress Alert helpers

- (void)showProgressAlert:(NSString *)message {
    self.progressOverlay = [DownloadProgressOverlay showBlurredInView:self.rootVC.view title:@"Launching" blurred:YES];
    self.progressOverlay.statusLabel.text = message;
    __weak typeof(self) weakSelf = self;
    self.progressOverlay.cancelBlock = ^{
        MainCoordinator *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf safeRemoveProgressObserver];
        if (strongSelf.downloadTask) {
            @try {
                [strongSelf.downloadTask cancelAll];
            } @catch (NSException *e) {
                NSLog(@"[MainCoordinator] cancelAll exception: %@", e);
            }
            strongSelf.downloadTask = nil;
        }
        [strongSelf dismissProgressAlert];
    };
    struct timeval tv;
    gettimeofday(&tv, NULL);
    CGFloat startTime = tv.tv_sec + tv.tv_usec / 1000000.0;
    _lastMsTime = startTime;
    _lastSpeedUpdateTime = startTime;
    _lastCompletedUnitCount = 0;
    _cachedSpeed = @"--";
    _cachedEta = @"--";
}

- (void)updateProgressAlert:(NSString *)message {
    if (self.progressOverlay) {
        [self.progressOverlay updateProgress:self.downloadTask.progress.fractionCompleted message:message];
    }
}

- (void)dismissProgressAlert {
    if (self.progressOverlay) {
        [self.progressOverlay dismiss];
        self.progressOverlay = nil;
    }
}

- (NSString *)formatBytes:(NSUInteger)bytes {
    if (bytes >= 1048576) return [NSString stringWithFormat:@"%.1f MB/s", bytes / 1048576.0];
    if (bytes >= 1024) return [NSString stringWithFormat:@"%.1f KB/s", bytes / 1024.0];
    return [NSString stringWithFormat:@"%lu B/s", (unsigned long)bytes];
}

- (NSString *)formatTimeRemaining:(NSTimeInterval)seconds {
    if (seconds <= 0 || seconds >= 86400) return @"--";
    if (seconds >= 3600) return [NSString stringWithFormat:@"%dh %dm", (int)(seconds / 3600), (int)((int)seconds % 3600 / 60)];
    if (seconds >= 60) return [NSString stringWithFormat:@"%dm %ds", (int)(seconds / 60), (int)((int)seconds % 60)];
    return [NSString stringWithFormat:@"%ds", (int)seconds];
}

#pragma mark - Modal helpers

- (void)showModDetail:(NSDictionary *)modData {
    ModDetailViewController *vc = [[ModDetailViewController alloc] initWithMod:modData];
    vc.coordinator = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.rootVC presentViewController:nav animated:YES completion:nil];
}

- (void)showDownload {
    [self showDownloadHub];
}

- (void)showServerDetail:(NSDictionary *)serverData {
    NSString *name = serverData[@"name"] ?: @"Server";
    NSString *desc = serverData[@"description"] ?: @"";
    NSDictionary *players = serverData[@"players"];
    NSString *info = desc;
    if (players) {
        info = [NSString stringWithFormat:@"%@\n\nPlayers: %@/%@", desc, players[@"online"] ?: @"?", players[@"max"] ?: @"?"];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name message:info preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Connect" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self launchWithServer:serverData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self.rootVC presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    return nil;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
