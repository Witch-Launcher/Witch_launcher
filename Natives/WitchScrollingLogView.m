#import "WitchScrollingLogView.h"
#import "PLLogOutputView.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "HapticManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

NS_ASSUME_NONNULL_BEGIN

// ===================== Tuning constants (edit here) =====================

// Lines kept in the view; older lines are trimmed from the top (with
// contentOffset compensation so the screen never jumps).
static const NSUInteger kDisplayLines = 300;

// New lines are grouped into batches and flushed once per this interval
// (100-300 ms window) instead of one-by-one.
static const NSTimeInterval kFlushDelay = 0.18;

// After the user drags away to read and leaves the log alone, the auto roll
// resumes from the current reading position after this idle delay (2-3 s).
static const NSTimeInterval kResumeDelay = 2.5;
// ...or immediately, if the user released this close to the bottom.
static const CGFloat kBottomResumeDistance = 80.0;

// "AI thinking" chase roll. target = bottom, dist = target - offset.
// speed = clamp(dist * kChaseGain * speedPref, kMinChaseSpeed, kMaxChaseSpeed)
// (px/s). Heavy output -> large dist -> fast, smooth race to the bottom;
// near the bottom the speed decays gently to a smooth stop.
static const CGFloat kChaseGain = 3.2;
static const CGFloat kMinChaseSpeed = 14.0;
static const CGFloat kMaxChaseSpeed = 900.0;
// dt comes from the real frame timestamp, capped so a stalled frame cannot
// jump the viewport.
static const CGFloat kMaxFrameDt = 0.05;
// Distance to the bottom below which the roll is considered settled.
static const CGFloat kArriveThreshold = 0.75;

// Per-batch fade-in of freshly appended lines (alpha 0 -> 1).
static const NSTimeInterval kLineFadeDuration = 0.35;
// Master switches
static const BOOL kLineFadeEnabled = YES;
static const BOOL kEdgeFadeMaskEnabled = YES;
// Gradient stops of the top/bottom edge fade mask.
static const CGFloat kEdgeFadeTop = 0.18;
static const CGFloat kEdgeFadeBottom = 0.82;

// ========================================================================

// The inner scrolling surface. Never touched directly by owners.
@interface WitchLogInnerTextView : UITextView
@end

@implementation WitchLogInnerTextView
- (BOOL)isAccessibilityElement {
    return NO;
}
@end

@interface WitchScrollingLogView () <UITextViewDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *displayLines;
@property (nonatomic, strong) NSMutableArray<NSString *> *pendingLines;
@property (nonatomic, assign) BOOL flushScheduled;
@property (nonatomic, strong, nullable) CADisplayLink *rollLink;
@property (nonatomic, assign) CFTimeInterval lastRollTimestamp;
@property (nonatomic, assign) BOOL userHolding;
@property (nonatomic, strong, nullable) NSTimer *resumeTimer;
@property (nonatomic, strong, nullable) UILongPressGestureRecognizer *longPress;
@property (nonatomic, strong, nullable) CAGradientLayer *edgeFadeMask;
@property (nonatomic, assign) BOOL placeholderVisible;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *fadeBatches;
@property (nonatomic, strong, nullable) CADisplayLink *fadeLink;
@end

@implementation WitchScrollingLogView
@synthesize textView = _textView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _displayLines = [NSMutableArray new];
    _pendingLines = [NSMutableArray new];
    _fadeBatches = [NSMutableArray new];
    _inkColor = [UIColor colorWithWhite:1 alpha:1.0];

    self.backgroundColor = UIColor.clearColor;

    WitchLogInnerTextView *inner = [[WitchLogInnerTextView alloc] initWithFrame:self.bounds];
    inner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    inner.backgroundColor = UIColor.clearColor;
    inner.textColor = [self.inkColor colorWithAlphaComponent:0.96];
    inner.font = [UIFont fontWithName:@"Menlo-Regular" size:11.0]
                    ?: [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    inner.editable = NO;
    inner.selectable = NO;
    inner.scrollEnabled = YES;
    inner.showsVerticalScrollIndicator = NO;
    inner.textContainerInset = UIEdgeInsetsMake(6, 12, 10, 12);
    inner.textContainer.lineFragmentPadding = 0;
    inner.layer.shadowColor = UIColor.blackColor.CGColor;
    inner.layer.shadowOpacity = 0.55;
    inner.layer.shadowRadius = 2.5;
    inner.layer.shadowOffset = CGSizeMake(0, 1);
    inner.delegate = self;
    _textView = inner;
    [self addSubview:inner];

    // The edge-fade mask lives on THIS wrapper layer. The wrapper never
    // scrolls (scrolling happens inside the inner text view), so the gradient
    // band stays pinned to the viewport no matter how fast the log moves.
    if (kEdgeFadeMaskEnabled) {
        CAGradientLayer *mask = [CAGradientLayer layer];
        mask.colors = @[
            (id)[UIColor.blackColor colorWithAlphaComponent:0.0].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:1.0].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:1.0].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.0].CGColor,
        ];
        mask.locations = @[@0.0, @(kEdgeFadeTop), @(kEdgeFadeBottom), @1.0];
        mask.startPoint = CGPointMake(0.5, 0.0);
        mask.endPoint = CGPointMake(0.5, 1.0);
        self.layer.mask = mask;
        self.edgeFadeMask = mask;
    }

    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPress.minimumPressDuration = 0.4;
    _longPress.numberOfTouchesRequired = 1;
    [inner addGestureRecognizer:_longPress];
    return self;
}

- (void)dealloc {
    [self stopAutoScroll];
    [self.fadeLink invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Wrapper geometry only — no scroll offset is ever involved here.
    self.edgeFadeMask.frame = self.bounds;
}

#pragma mark - Attach / detach

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview) {
        [self reloadFromLogBuffer];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(logLineDidAppend:)
                                                     name:WitchLogLineDidAppendNotification
                                                   object:nil];
        [self startAutoScrollIfNeeded];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:WitchLogLineDidAppendNotification
                                                      object:nil];
        [self stopAutoScroll];
    }
}

- (void)startAutoScrollIfNeeded {
    if (self.rollLink || !self.superview) return;
    if (self.hidden || self.alpha < 0.01) return;
    if (!getPrefBool(@"general.log_auto_scroll")) return;
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(rollTick:)];
    // Respect ProMotion: cap the tick rate so the roll stays cheap behind a
    // running game (30 Hz is plenty for px/s motion).
    link.preferredFramesPerSecond = 30;
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.rollLink = link;
    self.lastRollTimestamp = CACurrentMediaTime();
}

#pragma mark - Public appends (callers may use this instead of the notification)

- (void)didAppendLines:(NSUInteger)count {
    if (count == 0) return;
    if (!UIAccessibilityIsReduceMotionEnabled()) [self startAutoScrollIfNeeded];
    [self snapToBottomIfReduceMotion];
}

#pragma mark - Buffer

- (NSString *)fullLogTextForShare {
    return [PLLogOutputView fullLogText];
}

- (NSUInteger)displayLineCount {
    return self.displayLines.count;
}

- (void)reloadFromLogBuffer {
    NSString *full = [PLLogOutputView fullLogText];
    self.displayLines = full.length
        ? [[full componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] mutableCopy]
        : [NSMutableArray new];
    [self trimDisplayLines];
    [self applyDisplayTextWithPlaceholder:YES];
    // Opening the panel reads the newest lines first; the roll continues
    // pushing later output into view from here.
    NSUInteger len = self.textView.text.length;
    if (len > 0) [self.textView scrollRangeToVisible:NSMakeRange(len - 1, 1)];
    [self startAutoScrollIfNeeded];
}

- (void)clearDisplay {
    [self.displayLines removeAllObjects];
    [self.pendingLines removeAllObjects];
    [self.fadeBatches removeAllObjects];
    [self stopFadeLink];
    [self applyDisplayTextWithPlaceholder:NO];
}

- (void)trimDisplayLines {
    if (self.displayLines.count > kDisplayLines) {
        [self.displayLines removeObjectsInRange:NSMakeRange(0, self.displayLines.count - kDisplayLines)];
    }
}

- (void)appendLines:(NSArray<NSString *> *)lines {
    if (lines.count == 0) return;
    // Placeholder (or empty) text: a storage append would mix into the
    // waiting line, so rebuild once instead.
    if (self.placeholderVisible || self.textView.text.length == 0) {
        [self.displayLines removeAllObjects];
        [self.displayLines addObjectsFromArray:lines];
        [self trimDisplayLines];
        [self applyDisplayTextWithPlaceholder:YES];
        [self didAppendLines:lines.count];
        return;
    }

    [self.displayLines addObjectsFromArray:lines];
    NSUInteger excess = self.displayLines.count > kDisplayLines
        ? self.displayLines.count - kDisplayLines : 0;
    if (excess > 0) [self trimLeadingLines:excess];
    [self insertLinesIntoStorage:lines];
    [self didAppendLines:lines.count];
}

// Replaces the whole visible string; used for reload / clear / the very
// first lines, when there is nothing live to fade yet.
- (void)applyDisplayTextWithPlaceholder:(BOOL)placeholderWhenEmpty {
    [self.fadeBatches removeAllObjects];
    [self stopFadeLink];
    BOOL isPlaceholder = (self.displayLines.count == 0) && placeholderWhenEmpty;
    self.placeholderVisible = isPlaceholder;
    UITextView *inner = self.textView;
    NSString *text = isPlaceholder
        ? localize(@"witch.log_waiting", nil)
        : [self.displayLines componentsJoinedByString:@"\n"];
    inner.textColor = isPlaceholder
        ? [self.inkColor colorWithAlphaComponent:0.45]
        : [self.inkColor colorWithAlphaComponent:0.96];
    inner.text = text;
    if (isPlaceholder) return;

    // With the roll off the old rule applies: the newest line must be visible,
    // unless the user is scrolling back through history.
    if (self.rollLink == nil && !self.userHolding) {
        NSUInteger len = inner.text.length;
        if (len > 0) [inner scrollRangeToVisible:NSMakeRange(len - 1, 1)];
    }
}

#pragma mark - Live append via text storage (keeps scroll position)

- (NSDictionary *)lineAttributesWithAlpha:(CGFloat)alpha {
    return @{NSForegroundColorAttributeName: [(self.inkColor ?: UIColor.whiteColor)
              colorWithAlphaComponent:alpha]};
}

// Appends a batch into the text storage. The existing glyphs are untouched,
// so the viewport never jumps. Fresh lines start at alpha 0 and fade in over
// kLineFadeDuration via the fade display link.
- (void)insertLinesIntoStorage:(NSArray<NSString *> *)lines {
    NSTextStorage *storage = self.textView.textStorage;
    NSString *block = (storage.length > 0 ? @"\n" : @"");
    block = [block stringByAppendingString:[lines componentsJoinedByString:@"\n"]];
    NSUInteger start = storage.length;

    if (kLineFadeEnabled && !UIAccessibilityIsReduceMotionEnabled()) {
        [storage beginEditing];
        [storage replaceCharactersInRange:NSMakeRange(start, 0) withString:block];
        [storage setAttributes:[self lineAttributesWithAlpha:0.0] range:NSMakeRange(start, block.length)];
        [storage endEditing];
        NSMutableDictionary *batch = [NSMutableDictionary new];
        batch[@"start"] = @(start);
        batch[@"len"] = @(block.length);
        batch[@"t0"] = @(CACurrentMediaTime());
        [self.fadeBatches addObject:batch];
        [self startFadeLinkIfNeeded];
    } else {
        NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:block
                                                                        attributes:[self lineAttributesWithAlpha:0.96]];
        [storage replaceCharactersInRange:NSMakeRange(start, 0) withAttributedString:attributed];
    }
}

// Removes `count` oldest lines from the storage and compensates the content
// offset by their height so the user never sees a jump.
- (void)trimLeadingLines:(NSUInteger)count {
    NSUInteger removeLen = 0;
    for (NSUInteger i = 0; i < count; i++) {
        removeLen += [self.displayLines[i] length] + 1; // + the join newline
    }
    if (removeLen == 0 || removeLen > self.textView.textStorage.length) return;

    // Shift the active fade ranges (they live near the tail; top removal
    // only moves them).
    NSMutableArray<NSMutableDictionary *> *keep = [NSMutableArray new];
    for (NSMutableDictionary *batch in self.fadeBatches) {
        NSUInteger start = [batch[@"start"] unsignedIntegerValue];
        NSUInteger len = [batch[@"len"] unsignedIntegerValue];
        if (start >= removeLen) {
            batch[@"start"] = @(start - removeLen);
            [keep addObject:batch];
        } else if (start + len <= removeLen) {
            // Fully trimmed away; drop its fade silently.
        } else {
            batch[@"len"] = @(start + len - removeLen);
            batch[@"start"] = @(0);
            [keep addObject:batch];
        }
    }
    self.fadeBatches = keep;

    UITextView *inner = self.textView;
    CGFloat oldHeight = inner.contentSize.height;
    CGFloat oldOffsetY = inner.contentOffset.y;
    [inner.textStorage replaceCharactersInRange:NSMakeRange(0, removeLen) withString:@""];
    [inner.layoutManager ensureLayoutForTextContainer:inner.textContainer];
    CGFloat delta = oldHeight - inner.contentSize.height;
    if (delta > 0 && oldOffsetY > 0) {
        inner.contentOffset = CGPointMake(inner.contentOffset.x, MAX(0.0, oldOffsetY - delta));
    }
    [self.displayLines removeObjectsInRange:NSMakeRange(0, count)];
}

#pragma mark - Live lines (notification)

- (void)logLineDidAppend:(NSNotification *)note {
    NSString *line = note.userInfo[@"line"];
    if (![line isKindOfClass:[NSString class]] || line.length == 0) return;
    [self.pendingLines addObject:line];
    if (self.flushScheduled) return;
    self.flushScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kFlushDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self flushPendingLines];
    });
}

- (void)flushPendingLines {
    self.flushScheduled = NO;
    if (self.pendingLines.count == 0) return;
    NSArray<NSString *> *batch = self.pendingLines.copy;
    [self.pendingLines removeAllObjects];
    [self appendLines:batch];
}

#pragma mark - Batch fade-in

- (void)startFadeLinkIfNeeded {
    if (self.fadeLink || !self.superview) return;
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(fadeTick:)];
    link.preferredFramesPerSecond = 30;
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.fadeLink = link;
}

- (void)stopFadeLink {
    [self.fadeLink invalidate];
    self.fadeLink = nil;
}

- (void)fadeTick:(CADisplayLink *)link {
    if (self.fadeBatches.count == 0) {
        [self stopFadeLink];
        return;
    }
    BOOL allDone = YES;
    CFTimeInterval now = CACurrentMediaTime();

    NSTextStorage *storage = self.textView.textStorage;
    [storage beginEditing];
    for (NSMutableDictionary *batch in self.fadeBatches) {
        // Each batch fades on its own clock so a burst of log arriving as
        // several flush groups still eases line-group by line-group.
        CGFloat progress = (CGFloat)((now - [batch[@"t0"] doubleValue]) / kLineFadeDuration);
        if (progress < 0) progress = 0;
        if (progress >= 1.0) {
            progress = 1.0;
        } else {
            allDone = NO;
        }
        // Cosine easing: soft in, soft tail.
        CGFloat alpha = 0.96 * (0.5 * (1.0 - cos(M_PI * progress)));
        [storage setAttributes:[self lineAttributesWithAlpha:alpha]
                         range:NSMakeRange([batch[@"start"] unsignedIntegerValue],
                                           [batch[@"len"] unsignedIntegerValue])];
    }
    [storage endEditing];

    if (allDone) {
        [self.fadeBatches removeAllObjects];
        [self stopFadeLink];
    }
}

#pragma mark - Auto roll (chase to bottom)

- (void)stopAutoScroll {
    [self.rollLink invalidate];
    self.rollLink = nil;
    [self.resumeTimer invalidate];
    self.resumeTimer = nil;
}

- (CGFloat)bottomTarget {
    UITextView *inner = self.textView;
    return MAX(0.0, inner.contentSize.height - inner.bounds.size.height + inner.textContainerInset.bottom);
}

- (CGFloat)chaseSpeedForDistance:(CGFloat)distance {
    // Preference is stored as a percent (25..300, default 100).
    float pref = getPrefFloat(@"general.log_scroll_speed");
    if (pref <= 0.0f) pref = 100.0f;
    pref = MAX(25.0f, MIN(pref, 300.0f)) / 100.0f;
    CGFloat speed = distance * kChaseGain * (CGFloat)pref;
    return MAX(kMinChaseSpeed, MIN(kMaxChaseSpeed, speed));
}

- (void)rollTick:(CADisplayLink *)link {
    // A mid-session settings change must stop the roll immediately.
    if (!getPrefBool(@"general.log_auto_scroll")) {
        [self stopAutoScroll];
        return;
    }
    if (self.userHolding || self.textView.isTracking || self.textView.isDragging || self.textView.isDecelerating) {
        self.lastRollTimestamp = link.timestamp;
        return;
    }
    CGFloat dt = MIN((CGFloat)(link.timestamp - self.lastRollTimestamp), kMaxFrameDt);
    self.lastRollTimestamp = link.timestamp;
    if (dt <= 0) return;

    CGFloat target = self.bottomTarget;
    CGFloat distance = target - self.textView.contentOffset.y;
    if (distance < kArriveThreshold) {
        // Caught up with nothing pending: stop the display link to save
        // battery; the next batch restarts it (didAppendLines /
        // flushPendingLines call startAutoScrollIfNeeded).
        if (self.pendingLines.count == 0) [self stopAutoScroll];
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        // Reduce Motion: no easing — land straight at the bottom.
        self.textView.contentOffset = CGPointMake(self.textView.contentOffset.x, target);
        [self snapToBottomIfReduceMotion];
        return;
    }

    CGFloat step = MIN(distance, [self chaseSpeedForDistance:distance] * dt);
    self.textView.contentOffset = CGPointMake(self.textView.contentOffset.x, self.textView.contentOffset.y + step);
}

// Reduce Motion lands the view at the newest line immediately and stops the
// tick; there is no fade or chase to respect.
- (void)snapToBottomIfReduceMotion {
    if (!UIAccessibilityIsReduceMotionEnabled()) return;
    if (self.textView.isTracking || self.textView.isDragging || self.textView.isDecelerating || self.userHolding) return;
    if (self.pendingLines.count > 0) return;
    self.textView.contentOffset = CGPointMake(self.textView.contentOffset.x, self.bottomTarget);
    [self stopAutoScroll];
}

#pragma mark - User interaction (touch wins over the roll)

- (void)scheduleResumeIfIdle {
    BOOL nearBottom = (self.bottomTarget - self.textView.contentOffset.y) < kBottomResumeDistance;
    if (nearBottom) {
        [self refreshRollPref];
        return;
    }
    [self.resumeTimer invalidate];
    WitchScrollingLogView * __block weakSelf = self;
    self.resumeTimer = [NSTimer timerWithTimeInterval:kResumeDelay
                                              repeats:NO
                                                block:^(NSTimer *timer) {
        [weakSelf refreshRollPref];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.resumeTimer forMode:NSRunLoopCommonModes];
}

// Releases the reading hold after the idle window elapsed, and re-checks the
// preferences in case the user toggled autoscroll or speed mid-session.
- (void)refreshRollPref {
    self.userHolding = NO;
    self.lastRollTimestamp = CACurrentMediaTime();
    if (!getPrefBool(@"general.log_auto_scroll")) {
        [self stopAutoScroll];
        return;
    }
    [self startAutoScrollIfNeeded];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.userHolding = YES;
    [self.resumeTimer invalidate];
    self.resumeTimer = nil;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
    // The user deliberately scrolled somewhere — honor that position for the
    // idle window instead of fighting the deceleration target.
    self.userHolding = YES;
    [self scheduleResumeIfIdle];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self scheduleResumeIfIdle];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self scheduleResumeIfIdle];
}

#pragma mark - Long press menu

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    [HapticManager.shared play:HapticTypeSelection];
    NSString *full = [self fullLogTextForShare];
    if (full.length == 0) {
        [HapticManager.shared play:HapticTypeError];
        [ErrorPresenter showToast:localize(@"witch.log_empty", nil) success:NO];
        return;
    }
    UIViewController *host = [self firstAttachedViewController];
    if (!host) return;
    NSString *summary = [NSString stringWithFormat:@"%lu %@",
                         (unsigned long)self.displayLineCount, localize(@"witch.log_lines", nil)];
    [AppSheet showOptionsWithTitle:nil
                           message:nil
                           options:@[
        @{
            @"title": localize(@"witch.log_copy_all", nil),
            @"subtitle": summary,
            @"icon": @"doc.on.doc",
        },
        @{
            @"title": localize(@"witch.log_share", nil),
            @"icon": @"square.and.arrow.up",
        },
    ] selectedIndex:NSNotFound selection:^(NSInteger idx) {
        if (idx == 0) {
            UIPasteboard.generalPasteboard.string = full;
            [ErrorPresenter showToast:localize(@"witch.log_copied", nil) success:YES];
        } else if (idx == 1) {
            UIActivityViewController *activity =
                [[UIActivityViewController alloc] initWithActivityItems:@[full]
                                                        applicationActivities:nil];
            [host presentViewController:activity animated:YES completion:nil];
        }
    }];
}

- (nullable UIViewController *)firstAttachedViewController {
    UIResponder *responder = self.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

@end

NS_ASSUME_NONNULL_END
