#import <UIKit/UIKit.h>

#import "PerfSessionStore.h"

@interface PerfChartViewController : UIViewController

- (instancetype)initWithSessions:(NSArray<PerfSession *> *)sessions;

@end
