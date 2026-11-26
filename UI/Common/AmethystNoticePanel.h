#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// One button of a notice card. Primary = filled accent, secondary = outlined.
// A nil/absent handler still dismisses the card (tap-to-dismiss).
@interface AmethystNoticeAction : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) BOOL isPrimary;
@property (nonatomic, copy, readonly, nullable) void (^handler)(void);

+ (instancetype)primaryWithTitle:(NSString *)title handler:(nullable void (^)(void))handler;
+ (instancetype)secondaryWithTitle:(NSString *)title handler:(nullable void (^)(void))handler;

@end

// Achievement-style notice card: frosted card that slides in from the top of
// a host view with a spring icon pop, holding an SF Symbol icon, a bold
// title, a message and up to two action buttons. Pure UI — callers pass
// final (already localized) strings and handlers; tapping any button
// dismisses the card, then runs the action's handler.
// Current users: the black-screen hang watchdog (SurfaceViewController+HangDetect)
// and the pre-launch setting checks (GameLaunchChecks). Reuse it for any new
// in-game notice.
@interface AmethystNoticePanel : NSObject

@property (nonatomic, copy, nullable) NSString *iconSystemName; // default: exclamationmark.triangle.fill
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSArray<AmethystNoticeAction *> *actions; // 1..2, first = left

+ (instancetype)noticeWithTitle:(NSString *)title
                        message:(NSString *)message
                        actions:(NSArray<AmethystNoticeAction *> *)actions;

// Shows the card in `host` (replacing any card already visible). Plays the
// warning haptic and runs the entry animation; safe to call before the host
// is on screen.
+ (void)presentInView:(UIView *)host notice:(AmethystNoticePanel *)notice;

+ (void)dismiss;
+ (BOOL)isPresented;

@end

NS_ASSUME_NONNULL_END
