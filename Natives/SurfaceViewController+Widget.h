#import "SurfaceViewController.h"

uint64_t pojavSwapCount(void);

@interface SurfaceViewController(Widget)

- (void)setupCategory_Widget;
- (void)widgetTick;
- (void)widgetStopTimer;
- (void)updateWidgetMode;
- (void)widgetRepositionFromDefaults;

@end