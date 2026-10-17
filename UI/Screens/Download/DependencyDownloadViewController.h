#import <UIKit/UIKit.h>

@class DependencyDownloadViewController;

@protocol DependencyDownloadViewControllerDelegate <NSObject>
- (void)dependencyDownloadDidComplete:(DependencyDownloadViewController *)controller success:(BOOL)allSuccess;
@end

@interface DependencyDownloadViewController : UIViewController

@property (nonatomic, weak) id<DependencyDownloadViewControllerDelegate> delegate;
@property (nonatomic) NSString *mainModTitle;
@property (nonatomic) NSArray<NSDictionary *> *downloadItems; // Array of dicts with url, name, targetPath, identifier, type, isMain
@property (nonatomic) NSString *groupIdentifier;

- (instancetype)initWithMainModTitle:(NSString *)title items:(NSArray<NSDictionary *> *)items groupIdentifier:(NSString *)groupId;

@end