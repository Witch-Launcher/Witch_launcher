#import <UIKit/UIKit.h>

extern NSNotificationName const WitchLogLineDidAppendNotification;

@interface PLLogOutputView : UIView
@property(nonatomic) UINavigationController *navController;
- (void)actionStartStopLogOutput;
- (void)actionToggleLogOutput;
+ (void)appendToLog:(NSString *)line;
+ (void)trimLogToMaxLines:(NSUInteger)maxLines;
/// Empties the whole in-memory log buffer (splash log panel / classic panel).
+ (void)clearLog;
+ (void)handleExitCode:(int)code;
+ (NSString *)fullLogText;
/// Enables or pauses capture of game stdout/stderr into the in-memory log
/// buffer. Updates the panel's play/pause button if the panel exists.
/// (Capture is "off" by default: the game can spew GC spam, so the buffer is
/// only filled when the user actually wants the log.)
+ (void)setCaptureEnabled:(BOOL)enabled;
+ (BOOL)captureEnabled;
@end
