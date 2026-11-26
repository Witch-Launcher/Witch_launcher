#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Linear indeterminate progress bar.
/// - Shows a sliding gradient segment that moves back and forth across the track.
/// - `tintColor` is used as the active segment color (defaults to theme accent).
/// - Set `animating = YES` to start the looping animation; set to NO to stop.
@interface LinearProgressView : UIView

@property (nonatomic, assign) CGFloat progress;       // 0..1 used only when animating = NO (deterministic fallback)
@property (nonatomic, assign) BOOL animating;         // start/stop the back-and-forth animation
@property (nonatomic, strong) UIColor *trackColor;    // default: theme separatorColor
@property (nonatomic, strong) UIColor *fillColor;     // default: theme accentColor

- (instancetype)initWithFrame:(CGRect)frame;
- (void)startAnimating;
- (void)stopAnimating;

@end

NS_ASSUME_NONNULL_END
