#import <UIKit/UIKit.h>
#import "CrashLogAnalyzer.h"

NS_ASSUME_NONNULL_BEGIN

@interface WitchAIChatViewController : UIViewController

- (instancetype)initWithAnalysis:(nullable CrashLogAnalyzerResult *)analysis exitCode:(int)code;
- (instancetype)init; // empty chat

@end

NS_ASSUME_NONNULL_END
