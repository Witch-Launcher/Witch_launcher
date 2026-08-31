#import <UIKit/UIKit.h>
#import "UIKit+hook.h"

#import "customcontrols/ControlLayout.h"
#import "GameSurfaceView.h"
#import "PLLogOutputView.h"

BOOL canAppendToLog;
dispatch_group_t fatalExitGroup;

CGRect virtualMouseFrame;
CGPoint lastVirtualMousePoint;

@interface SurfaceViewController : UIViewController

@property(nonatomic) ControlLayout *ctrlView;
@property(nonatomic) GameSurfaceView* surfaceView;
@property(nonatomic) UIView *touchView;
@property UIImageView* mousePointerView;
@property(nonatomic) UIPanGestureRecognizer* scrollPanGesture;

@property(nonatomic) UIView* rootView;

// In-game widget (SurfaceViewController+Widget.m)
@property(nonatomic) UIView *widgetView;
@property(nonatomic) UILabel *widgetFpsLabel;
@property(nonatomic) UILabel *widgetFgFpsLabel;
@property(nonatomic) UILabel *widgetRamLabel;
@property(nonatomic) UILabel *widgetTempLabel;
@property(nonatomic) UILabel *widgetBattLabel;
@property(nonatomic) UILabel *widgetClockLabel;
@property(nonatomic) UILabel *widgetLowPowerLabel;
@property(nonatomic) UIView *widgetBarView;
@property(nonatomic) UIView *widgetBarSegLauncher;
@property(nonatomic) UIView *widgetBarSegDevice;
@property(nonatomic) UILabel *widgetBarSegLauncherLabel;
@property(nonatomic) UILabel *widgetBarSegDeviceLabel;
@property(nonatomic) UILabel *widgetBarSegFreeLabel;
@property(nonatomic) UILabel *widgetCpuPercentLabel;
@property(nonatomic) UILabel *widgetGpuPercentLabel;
@property(nonatomic) UILabel *widgetCpuNameLabel;
@property(nonatomic) UIView *widgetCpuBar;
@property(nonatomic) UILabel *widgetCpuBarLabel;
@property(nonatomic) UILabel *widgetGpuNameLabel;
@property(nonatomic) UIView *widgetGpuBar;
@property(nonatomic) UILabel *widgetGpuBarLabel;
@property(nonatomic) UIView *widgetCpuRing;
@property(nonatomic) UILabel *widgetCpuRingLabel;
@property(nonatomic) UILabel *widgetCpuRingPercentLabel;
@property(nonatomic) UIView *widgetGpuRing;
@property(nonatomic) UILabel *widgetGpuRingLabel;
@property(nonatomic) UILabel *widgetGpuRingPercentLabel;
@property(nonatomic) UIView *widgetPanelView;
@property(nonatomic) UIView *widgetPanelBackdrop;
@property(nonatomic) UIImageView *widgetEmptyIcon;
@property(nonatomic) BOOL savedEdgeGestureEnabled;

// Navigation swipe strip
@property(nonatomic) UIView *menuSwipeView;

- (instancetype)initWithMetadata:(NSDictionary *)metadata;
- (instancetype)initWithJarPath:(NSString *)jarPath;
- (instancetype)initWithJarPath:(NSString *)jarPath args:(NSArray<NSString *> *)args minJavaVersion:(int)minJavaVersion;
- (void)sendTouchPoint:(CGPoint)location withEvent:(int)event;
- (void)updateSavedResolution;
- (void)updateGrabState;

+ (GameSurfaceView *)surface;
+ (BOOL)isRunning;

// LogView category
@property(nonatomic) PLLogOutputView* logOutputView;

// Navigation category
@property(nonatomic) NSArray *menuArray;
@property(nonatomic) UITableView *menuView;
@property(nonatomic) UIScreenEdgePanGestureRecognizer* edgeGesture;

@end

@interface SurfaceViewController(ExternalDisplay)

- (void)switchToExternalDisplay;
- (void)switchToInternalDisplay;

@end

@interface SurfaceViewController(LogView)
@end

@interface SurfaceViewController(Navigation)<UIGestureRecognizerDelegate, UITableViewDataSource, UITableViewDelegate>

- (void)actionOpenNavigationMenu;
- (void)didSelectMenuItem:(int)item;
- (void)animateMenuScale:(CGFloat)scale duration:(CGFloat)duration;
- (void)viewWillTransitionToSize_Navigation:(CGRect)frame;
- (void)setEdgeSwipeUIHidden:(BOOL)hidden;

@end
