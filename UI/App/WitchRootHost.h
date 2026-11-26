#import <UIKit/UIKit.h>

@class MainCoordinator;
@class RightPanelViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol WitchRootHost <NSObject>

@property (nonatomic, strong, nullable) MainCoordinator *coordinator;
@property (nonatomic, readonly, nullable) RightPanelViewController *rightPanelVC;
@property (nonatomic, readonly, nullable) UIViewController *currentContentVC;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly, nullable) UIViewController *presentedViewController;

- (void)switchContentTo:(UIViewController *)vc animated:(BOOL)animated;
- (void)presentContentAsSheet:(UIViewController *)vc;
- (void)pushContent:(UIViewController *)vc animated:(BOOL)animated;
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(nullable void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
