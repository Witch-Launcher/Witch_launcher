#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Log panel with the "AI thinking" roll. A non-scrolling wrapper view holds
/// the actual UITextView, so the top/bottom edge-fade gradient mask lives on
/// a layer that never scrolls and therefore stays glued to the viewport.
///
/// - Batches: incoming lines are grouped and flushed every ~180 ms; each new
///   batch fades in (alpha 0 -> 1) via textStorage edits that never reset the
///   scroll position.
/// - Roll: a display link chases the bottom (speed = clamp(dist * GAIN, MIN,
///   MAX)); heavy output races, the decay near the bottom is smooth, and the
///   link stops entirely when caught up with nothing pending (battery).
/// - Touch wins: dragging pauses the roll; it resumes from the reading
///   position after ~2.5 s idle (or immediately when released near the
///   bottom). Reduce Motion removes the fade and snaps to the bottom.
/// - Lines are capped (with contentOffset compensation, no jumps). A long
/// press opens the launcher sheet (copy all / share).
@interface WitchScrollingLogView : UIView

/// Ink tint for the log text and its placeholder (white by default). Owners
/// wired to a custom user palette (e.g. the splash panel) set it.
@property (nonatomic, strong) UIColor *inkColor;

/// The inner scrolling text view (exposed for callers that need frames or
/// direct scroll queries; all roll/batch logic lives inside this class).
@property (nonatomic, strong, readonly) UITextView *textView;

/// Rebuilds the visible text from the full log buffer (`PLLogOutputView fullLogText`).
- (void)reloadFromLogBuffer;

/// Drops the visible lines and shows the placeholder.
- (void)clearDisplay;

/// Starts/stops the display-link roll. Starts automatically when attached to
/// a superview; call `stopAutoScroll` when removing it for longer than a
/// session (the view also stops itself on removeFromSuperview).
- (void)startAutoScrollIfNeeded;
- (void)stopAutoScroll;

/// Full log text (whole buffer, not just the visible cap) for copy/share.
- (NSString *)fullLogTextForShare;

/// Lines currently displayed (after the cap) — overlays use it for counters.
- (NSUInteger)displayLineCount;

/// Nudge the auto roll after lines were appended externally (batch flushes
/// coming through `WitchLogLineDidAppendNotification` already call this
/// internally — call it only if you append text yourself). Restarts the
/// display link when it paused for battery, or snaps straight to the bottom
/// when Reduce Motion is on.
- (void)didAppendLines:(NSUInteger)count;

/// Insert/append raw lines (used by owners that batch themselves).
- (void)appendLines:(NSArray<NSString *> *)lines;

@end

NS_ASSUME_NONNULL_END
