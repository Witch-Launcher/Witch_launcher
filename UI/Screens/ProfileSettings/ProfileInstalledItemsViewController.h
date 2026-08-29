#import <UIKit/UIKit.h>
#import "InstalledModsManager.h"
#import "DependencyDownloadViewController.h"

@interface ProfileInstalledItemsViewController : UIViewController <DependencyDownloadViewControllerDelegate>
@property (nonatomic) NSMutableDictionary *profile;
@property (nonatomic) InstalledItemCategory category;
@end
