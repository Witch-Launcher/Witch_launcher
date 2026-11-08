#import <UIKit/UIKit.h>
#import "SidebarViewController.h"
#import "DownloadManager.h"
#import "WitchRootHost.h"

@interface MainCoordinator : NSObject <UIViewControllerTransitioningDelegate>

@property (nonatomic, weak) id<WitchRootHost> rootVC;
@property (nonatomic) DownloadManager *downloadManager;

- (instancetype)initWithRootVC:(id<WitchRootHost>)rootVC;
- (void)start;

- (void)switchToTab:(SidebarTab)tab;
- (void)showAccount;
- (void)showSettings;
- (void)showBackupHistory;
- (void)showFileManager;
- (void)showVersionPicker;
- (void)showModLoaderPicker;
- (void)showDownloadHub;
- (void)showDownloadTasks;
- (void)showAddVersion;
- (void)removeVersion:(NSString *)versionName;
- (void)selectVersion:(NSString *)versionName;
- (void)editVersion:(NSString *)versionName;
- (void)launchGame;
- (void)launchWithServer:(NSDictionary *)server;
- (void)showModDetail:(NSDictionary *)modData;
- (void)showDownload;
- (void)showServerDetail:(NSDictionary *)serverData;

@end
