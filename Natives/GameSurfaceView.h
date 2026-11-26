#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

@interface GameSurfaceView : UIView

// Re-apply the CAMetalLayer drawable size and notify the size-tracking
// backends (TGLMT / TGLES). Runs from layoutSubviews (bounds changes) and
// from updateSavedResolution (contentsScale changes with no layout pass).
- (void)syncLayerSize;

@end
