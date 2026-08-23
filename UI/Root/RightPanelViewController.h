#import <UIKit/UIKit.h>

@protocol RightPanelDelegate <NSObject>
- (void)rightPanelDidTapAccount;
- (void)rightPanelDidTapLaunch;
- (void)rightPanelDidTapDownloadHub;
- (void)rightPanelDidTapFileManager;
- (void)rightPanelDidTapSettings;
- (void)rightPanelDidAddVersion;
- (void)rightPanelDidRemoveVersion:(NSString *)versionName;
- (void)rightPanelDidSelectVersion:(NSString *)versionName;
- (void)rightPanelDidEditVersion:(NSString *)versionName;
@end

@interface RightPanelViewController : UIViewController

@property (nonatomic, weak) id<RightPanelDelegate> delegate;

@property (nonatomic, readonly) UIButton *accountButton;
@property (nonatomic, readonly) UILabel *accountNameLabel;
@property (nonatomic, readonly) UIImageView *skinPreviewView;
@property (nonatomic, readonly) UIButton *launchButton;

- (void)updateAccountWithName:(NSString *)name skin:(UIImage *)skin;
- (void)setLaunchEnabled:(BOOL)enabled;
- (void)refreshVersions;

// YES while downloads are running and the launch button acts as Cancel.
@property (nonatomic, readonly) BOOL launchIsCancel;

@end
