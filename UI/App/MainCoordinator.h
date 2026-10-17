#import <UIKit/UIKit.h>
#import "SidebarViewController.h"
#import "DownloadManager.h"

@class AmethystRootViewController;

@interface MainCoordinator : NSObject <UIViewControllerTransitioningDelegate>

@property (nonatomic, weak) AmethystRootViewController *rootVC;
@property (nonatomic) DownloadManager *downloadManager;

- (instancetype)initWithRootVC:(AmethystRootViewController *)rootVC;
- (void)start;

- (void)switchToTab:(SidebarTab)tab;
- (void)showAccount;
- (void)showSettings;
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
