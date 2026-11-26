#import <UIKit/UIKit.h>
#import "SidebarViewController.h"
#import "WitchRootHost.h"

@class MainCoordinator;
@class RightPanelViewController;

@interface AmethystRootViewController : UIViewController <SidebarDelegate, WitchRootHost>

@property (nonatomic, strong) MainCoordinator *coordinator;
@property (nonatomic, readonly) SidebarViewController *sidebarVC;
@property (nonatomic, readonly) RightPanelViewController *rightPanelVC;
@property (nonatomic, readonly) UIViewController *currentContentVC;

- (void)switchContentTo:(UIViewController *)vc animated:(BOOL)animated;
- (void)presentContentAsSheet:(UIViewController *)vc;
- (void)pushContent:(UIViewController *)vc animated:(BOOL)animated;

@end
