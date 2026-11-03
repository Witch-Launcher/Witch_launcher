#import <UIKit/UIKit.h>

@interface PLLogOutputView : UIView
@property(nonatomic) UINavigationController *navController;
- (void)actionStartStopLogOutput;
- (void)actionToggleLogOutput;
+ (void)appendToLog:(NSString *)line;
+ (void)trimLogToMaxLines:(NSUInteger)maxLines;
+ (void)handleExitCode:(int)code;
@end
