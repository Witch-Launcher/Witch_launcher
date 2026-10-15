#import <UIKit/UIKit.h>

@protocol TopBarDelegate <NSObject>
- (void)topBarDidTapFileManager;
- (void)topBarDidTapSettings;
- (void)topBarDidTapDownloadHub;
@end

@interface TopBarView : UIView

@property (nonatomic, weak) id<TopBarDelegate> delegate;

@property (nonatomic, readonly) UILabel *jitStatusLabel;
@property (nonatomic, readonly) UILabel *timeLabel;

- (void)updateJITStatus:(BOOL)enabled;
- (void)updateTime;

@end
