#import "SurfaceViewController.h"

@interface SurfaceViewController (HangDetect)

/// Starts watching a fresh game launch: if the Metal layer has not presented
/// a single frame after three minutes AND latestlog has stopped changing (or
/// only repeats the same automated lines), an achievement-style panel offers
/// to share latestlog.
- (void)startBlackScreenWatchdog;

/// Cancels the watcher (frames arrived, game closed, or panel shown).
- (void)stopBlackScreenWatchdog;

@end
