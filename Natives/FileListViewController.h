#import <UIKit/UIKit.h>

@interface FileListViewController : UITableViewController

@property NSString* listPath;
@property(nonatomic) BOOL confirmDeleteBeforeRemoving;
@property (nonatomic, copy) void (^whenDelete)(NSString* name);
@property(nonatomic, copy) void (^whenItemSelected)(NSString* name);

@end
