#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "PerfSessionStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PerfChartType) {
    PerfChartTypeLine = 0,
    PerfChartTypeBar,
    PerfChartTypePie,
};

// Renders monochrome, square, print-style performance charts. Multiple
// sessions become multiple series; when combined is YES each metric gets its
// own tile inside one square grid image.
@interface PerfChartRenderer : NSObject

+ (NSString *)displayNameForMetric:(NSString *)metric;

+ (UIImage *)imageForSessions:(NSArray<PerfSession *> *)sessions
                      metrics:(NSArray<NSString *> *)metrics
                         type:(PerfChartType)type
                     combined:(BOOL)combined
                         side:(CGFloat)side;

+ (NSData *)pdfDataForSessions:(NSArray<PerfSession *> *)sessions
                       metrics:(NSArray<NSString *> *)metrics
                          type:(PerfChartType)type
                      combined:(BOOL)combined
                          side:(CGFloat)side;

@end

NS_ASSUME_NONNULL_END
