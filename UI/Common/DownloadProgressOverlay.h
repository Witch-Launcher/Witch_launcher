#import <UIKit/UIKit.h>

@interface DownloadProgressOverlay : UIView

+ (instancetype)showInView:(UIView *)view title:(NSString *)title;
+ (instancetype)showBlurredInView:(UIView *)view title:(NSString *)title blurred:(BOOL)blurred;
- (void)updateProgress:(float)progress message:(NSString *)message;
- (void)updateWithFraction:(float)fraction description:(NSString *)description additionalDescription:(NSString *)additional speed:(NSString *)speed eta:(NSString *)eta;
- (void)finishWithMessage:(NSString *)message;
- (void)dismiss;

@property (nonatomic, readonly) UILabel *statusLabel;
@property (nonatomic, readonly) UILabel *percentLabel;
@property (nonatomic, readonly) UILabel *speedLabel;
@property (nonatomic, readonly) UILabel *etaLabel;
@property (nonatomic, readonly) UIProgressView *progressView;
@property (nonatomic, copy) void (^cancelBlock)(void);

@end
