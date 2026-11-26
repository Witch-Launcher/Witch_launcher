#import <UIKit/UIKit.h>

@interface LauncherPrefManageJREViewController : UITableViewController

+ (NSString *)extractTarXZ:(NSString *)inPath to:(NSString *)outPath progress:(NSProgress *)progress fileProgress:(NSProgress *)fileProgress fileCallback:(void(^)(NSString* name))fileCallback;

@end

