#import <UIKit/UIKit.h>

@class MinecraftResourceDownloadTask;

@interface DownloadTasksViewController : UIViewController

- (instancetype)initWithHubTasks;
- (instancetype)initWithLaunchTask:(MinecraftResourceDownloadTask *)launchTask;

@end
