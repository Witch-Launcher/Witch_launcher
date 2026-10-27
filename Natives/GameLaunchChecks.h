#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// One pre-launch sanity check. Each check is self-contained: `isAffected`
// decides when the notice appears, `revert` is what the "fix it for me"
// button runs. To retire a check once its problem is fixed, delete its entry
// from +checks (and its strings); to add a new notice, append an entry.
@interface GameLaunchCheck : NSObject

@property (nonatomic, copy) NSString *checkID;
@property (nonatomic, copy, nullable) NSString *iconSystemName; // default: exclamationmark.triangle.fill
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *revertButtonTitle;
@property (nonatomic, copy) NSString *continueButtonTitle;
@property (nonatomic, copy) BOOL (^isAffected)(void);
@property (nonatomic, copy) void (^revert)(void);

@end

@interface GameLaunchChecks : NSObject

// Runs the registered checks against the current renderer/preferences and
// presents the first problem as an achievement-style notice in `host`.
// Returns YES when a notice is showing: the caller MUST defer the launch;
// the "continue anyway" button (and only that path) invokes onContinue.
// Returns NO when nothing is affected and the launch may proceed.
+ (BOOL)presentFirstIssueIn:(UIView *)host onContinue:(void (^)(void))onContinue;

// THE extension point: the full list of pre-launch checks.
+ (NSArray<GameLaunchCheck *> *)checks;

@end

NS_ASSUME_NONNULL_END
