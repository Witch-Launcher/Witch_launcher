#import "PerfChartRenderer.h"

#import "PerfRecorder.h"
#import "utils.h"

#include <math.h>

static const CGFloat kPerfMaxChartPoints = 400;

#pragma mark - Style palette (strict black & white)

static CGFloat PerfStyleGray(NSUInteger index) {
    static const CGFloat grays[8] = {0.05, 0.32, 0.58, 0.15, 0.44, 0.70, 0.24, 0.50};
    return grays[index % 8];
}

static void PerfApplyStyle(CGContextRef ctx, NSUInteger index, BOOL stroke) {
    static const CGFloat dashes[8][4] = {
        {0, 0, 0, 0}, {6, 3, 0, 0}, {2, 2, 0, 0}, {9, 3, 2, 3},
        {4, 3, 0, 0}, {1, 2, 0, 0}, {12, 4, 0, 0}, {3, 3, 0, 0},
    };
    CGFloat gray = PerfStyleGray(index);
    if (stroke) {
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:gray alpha:1].CGColor);
    } else {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:gray alpha:1].CGColor);
    }
    NSUInteger count = 0;
    while (count < 4 && dashes[index % 8][count] > 0) {
        count++;
    }
    CGContextSetLineDash(ctx, 0, dashes[index % 8], count);
}

#pragma mark - Small helpers

static UIFont *PerfMono(CGFloat size, BOOL bold) {
    return [UIFont monospacedSystemFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular];
}

static void PerfDrawText(NSString *text, CGRect rect, UIFont *font, UIColor *color, NSTextAlignment align) {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = align;
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    [text drawInRect:rect withAttributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
    }];
}

#pragma mark - Witch brand watermark

// The launcher logo mark: the rhombus from the brand SVG (618 x 955 units).
static const CGFloat kPerfWitchMarkAspect = 618.0 / 955.0;

static void PerfDrawWitchMark(CGRect rect, UIColor *color) {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGContextAddLineToPoint(ctx, CGRectGetMaxX(rect), CGRectGetMidY(rect));
    CGContextAddLineToPoint(ctx, CGRectGetMidX(rect), CGRectGetMaxY(rect));
    CGContextAddLineToPoint(ctx, CGRectGetMinX(rect), CGRectGetMidY(rect));
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
}

// WITCH in brand weight, LAUNCHER at 60% opacity, exactly like the SVG lockup.
static NSAttributedString *PerfWitchWordmark(CGFloat fontSize, UIColor *color) {
    UIFont *witch = [UIFont fontWithName:@"AvenirNext-Heavy" size:fontSize]
        ?: [UIFont systemFontOfSize:fontSize weight:UIFontWeightHeavy];
    UIFont *launcher = [UIFont fontWithName:@"AvenirNext-Medium" size:fontSize]
        ?: [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"WITCH LAUNCHER" attributes:@{
        NSFontAttributeName: witch,
        NSForegroundColorAttributeName: color,
        NSKernAttributeName: @(fontSize * 0.12),
    }];
    [text addAttributes:@{
        NSFontAttributeName: launcher,
        NSForegroundColorAttributeName: [color colorWithAlphaComponent:CGColorGetAlpha(color.CGColor) * 0.6],
    } range:NSMakeRange(6, 8)];
    return text;
}

// Draws the full lockup (mark + wordmark) centered vertically in frame,
// shrinking to fit maxWidth. alpha drives everything, so the same drawing
// serves as footer branding at full opacity and as the watermark stamped
// across the chart canvas at low opacity.
static void PerfDrawWitchLogo(CGRect frame, CGFloat markHeight, CGFloat maxWidth, CGFloat alpha, BOOL leftAligned) {
    UIColor *color = [UIColor colorWithWhite:0 alpha:alpha];
    CGFloat fontSize = markHeight * 0.90;
    CGFloat gap = markHeight * 0.30;
    CGFloat markWidth = markHeight * kPerfWitchMarkAspect;
    NSAttributedString *wordmark = PerfWitchWordmark(fontSize, color);
    CGFloat totalWidth = markWidth + gap + wordmark.size.width;
    if (maxWidth > 0 && totalWidth > maxWidth) {
        CGFloat scale = maxWidth / totalWidth;
        markHeight *= scale;
        markWidth *= scale;
        gap *= scale;
        fontSize *= scale;
        wordmark = PerfWitchWordmark(fontSize, color);
        totalWidth = markWidth + gap + wordmark.size.width;
    }
    CGSize textSize = wordmark.size;
    CGFloat startX = leftAligned ? CGRectGetMinX(frame) : CGRectGetMidX(frame) - totalWidth / 2;
    CGFloat midY = CGRectGetMidY(frame);
    PerfDrawWitchMark(CGRectMake(startX, midY - markHeight / 2, markWidth, markHeight), color);
    [wordmark drawAtPoint:CGPointMake(startX + markWidth + gap, midY - textSize.height / 2)];
}

static NSString *PerfFormatDuration(NSTimeInterval seconds) {
    NSInteger total = (NSInteger)llround(seconds);
    if (total < 60) {
        return [NSString stringWithFormat:@"%lds", (long)total];
    }
    NSInteger minutes = total / 60;
    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ldm %02lds", (long)minutes, (long)(total % 60)];
    }
    return [NSString stringWithFormat:@"%ldh %02ldm", (long)(minutes / 60), (long)(minutes % 60)];
}

static NSString *PerfFormatElapsed(double seconds) {
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%.0fs", seconds];
    }
    NSInteger total = (NSInteger)llround(seconds);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

static NSString *PerfSessionLabel(PerfSession *session, NSUInteger index) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"dd/MM HH:mm";
    });
    return [NSString stringWithFormat:@"#%lu %@ · %@", (unsigned long)(index + 1),
            [formatter stringFromDate:session.startedAt], PerfFormatDuration(session.duration)];
}

static NSString *PerfMetricUnit(NSString *metric) {
    if ([metric isEqualToString:@"fps"] || [metric isEqualToString:@"thermal"]) {
        return @"";
    }
    if ([metric isEqualToString:@"ram"] || [metric isEqualToString:@"devram"]) {
        return @"MB";
    }
    if ([metric isEqualToString:@"battemp"]) {
        return @"°C";
    }
    return @"%";
}

static double PerfNiceMax(double value) {
    if (!(value > 0)) {
        return 1;
    }
    double magnitude = pow(10, floor(log10(value)));
    double normalized = value / magnitude;
    double nice;
    if (normalized <= 1.0) nice = 1.0;
    else if (normalized <= 2.0) nice = 2.0;
    else if (normalized <= 5.0) nice = 5.0;
    else nice = 10.0;
    return nice * magnitude;
}

static void PerfDrawAxes(CGContextRef ctx, CGRect plot, double yMax, NSArray<NSString *> *xLabels) {
    static const int kYTicks = 4;
    static const int kXTicks = 4;

    CGContextSetLineWidth(ctx, 0.5);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.85 alpha:1].CGColor);
    CGContextSetLineDash(ctx, 0, NULL, 0);

    for (int i = 0; i <= kYTicks; i++) {
        CGFloat y = CGRectGetMaxY(plot) - plot.size.height * i / kYTicks;
        CGContextMoveToPoint(ctx, CGRectGetMinX(plot), y);
        CGContextAddLineToPoint(ctx, CGRectGetMaxX(plot), y);
    }
    for (int i = 0; i <= kXTicks; i++) {
        CGFloat x = CGRectGetMinX(plot) + plot.size.width * i / kXTicks;
        CGContextMoveToPoint(ctx, x, CGRectGetMinY(plot));
        CGContextAddLineToPoint(ctx, x, CGRectGetMaxY(plot));
    }
    CGContextStrokePath(ctx);

    UIFont *labelFont = PerfMono(9, NO);
    UIColor *labelColor = [UIColor colorWithWhite:0.25 alpha:1];
    for (int i = 0; i <= kYTicks; i++) {
        CGFloat y = CGRectGetMaxY(plot) - plot.size.height * i / kYTicks;
        double value = yMax * i / kYTicks;
        NSString *text = (yMax >= 100) ? [NSString stringWithFormat:@"%.0f", value]
                                       : [NSString stringWithFormat:@"%.1f", value];
        PerfDrawText(text, CGRectMake(CGRectGetMinX(plot) - 42, y - 6, 36, 12), labelFont, labelColor, NSTextAlignmentRight);
    }
    for (int i = 0; i <= kXTicks; i++) {
        CGFloat x = CGRectGetMinX(plot) + plot.size.width * i / kXTicks;
        NSUInteger idx = (NSUInteger)llround((double)i / kXTicks * (xLabels.count - 1));
        if (idx >= xLabels.count) {
            continue;
        }
        PerfDrawText(xLabels[idx], CGRectMake(x - 30, CGRectGetMaxY(plot) + 4, 60, 12), labelFont, labelColor, NSTextAlignmentCenter);
    }

    CGContextSetLineWidth(ctx, 1.4);
    CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
    CGContextMoveToPoint(ctx, CGRectGetMinX(plot), CGRectGetMinY(plot) - 6);
    CGContextAddLineToPoint(ctx, CGRectGetMinX(plot), CGRectGetMaxY(plot));
    CGContextAddLineToPoint(ctx, CGRectGetMaxX(plot) + 6, CGRectGetMaxY(plot));
    CGContextStrokePath(ctx);
}

static CGFloat PerfDrawLegend(CGContextRef ctx, CGRect rect, NSArray<PerfSession *> *sessions, NSArray<NSNumber *> *values, BOOL showValues) {
    if (sessions.count == 0) {
        return 0;
    }
    UIFont *font = PerfMono(9, NO);
    BOOL twoColumns = sessions.count > 4;
    NSUInteger rows = twoColumns ? (sessions.count + 1) / 2 : sessions.count;
    CGFloat lineHeight = 15;
    CGFloat totalHeight = rows * lineHeight;

    for (NSUInteger i = 0; i < sessions.count; i++) {
        NSUInteger column = twoColumns ? i / rows : 0;
        NSUInteger row = twoColumns ? i % rows : i;
        CGFloat x = CGRectGetMinX(rect) + column * (rect.size.width / (twoColumns ? 2 : 1));
        CGFloat y = CGRectGetMinY(rect) + row * lineHeight;

        CGContextSetLineDash(ctx, 0, NULL, 0);
        PerfApplyStyle(ctx, i, NO);
        CGContextFillRect(ctx, CGRectMake(x, y + 4, 9, 9));
        CGContextSetLineWidth(ctx, 1);
        CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
        CGContextStrokeRect(ctx, CGRectMake(x, y + 4, 9, 9));

        NSMutableString *label = [PerfSessionLabel(sessions[i], i) mutableCopy];
        if (showValues && i < values.count && !isnan(values[i].doubleValue)) {
            [label appendFormat:@" · %.1f", values[i].doubleValue];
        }
        PerfDrawText(label, CGRectMake(x + 14, y, rect.size.width / (twoColumns ? 2 : 1) - 18, 13), font, [UIColor colorWithWhite:0.15 alpha:1], NSTextAlignmentLeft);
    }
    CGContextSetLineDash(ctx, 0, NULL, 0);
    return totalHeight;
}

static void PerfDrawNoData(CGRect rect) {
    PerfDrawText(localize(@"perf.chart.no_data", nil), rect, PerfMono(13, YES), [UIColor colorWithWhite:0.6 alpha:1], NSTextAlignmentCenter);
}

#pragma mark - Chart drawing

static void PerfDrawLineChart(CGContextRef ctx, CGRect plot, NSArray<PerfSession *> *sessions, NSString *metric) {
    double maxX = 0, maxY = 0;
    NSMutableArray<NSArray<NSDictionary<NSString *, NSNumber *> *> *> *series = [NSMutableArray new];
    for (PerfSession *session in sessions) {
        NSArray *points = [session pointsForMetric:metric maxPoints:kPerfMaxChartPoints];
        [series addObject:points];
        for (NSDictionary *point in points) {
            maxX = MAX(maxX, [point[@"x"] doubleValue]);
            maxY = MAX(maxY, [point[@"y"] doubleValue]);
        }
    }
    if (maxX <= 0 || maxY <= 0) {
        PerfDrawNoData(plot);
        return;
    }
    double yMax = PerfNiceMax(maxY * 1.08);

    NSMutableArray<NSString *> *xLabels = [NSMutableArray new];
    for (int i = 0; i <= 4; i++) {
        [xLabels addObject:PerfFormatElapsed(maxX * i / 4.0)];
    }
    PerfDrawAxes(ctx, plot, yMax, xLabels);

    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, plot);
    for (NSUInteger i = 0; i < series.count; i++) {
        NSArray *points = series[i];
        if (points.count == 0) {
            continue;
        }
        PerfApplyStyle(ctx, i, YES);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        for (NSUInteger p = 0; p < points.count; p++) {
            CGFloat x = CGRectGetMinX(plot) + plot.size.width * ([points[p][@"x"] doubleValue] / maxX);
            CGFloat y = CGRectGetMaxY(plot) - plot.size.height * ([points[p][@"y"] doubleValue] / yMax);
            if (p == 0) {
                CGContextMoveToPoint(ctx, x, y);
            } else {
                CGContextAddLineToPoint(ctx, x, y);
            }
        }
        CGContextStrokePath(ctx);
        if (points.count == 1) {
            PerfApplyStyle(ctx, i, NO);
            CGContextFillEllipseInRect(ctx, CGRectMake(CGRectGetMinX(plot) + plot.size.width * ([points[0][@"x"] doubleValue] / maxX) - 2.5,
                                                       CGRectGetMaxY(plot) - plot.size.height * ([points[0][@"y"] doubleValue] / yMax) - 2.5,
                                                       5, 5));
        }
    }
    CGContextRestoreGState(ctx);
}

static void PerfDrawBarChart(CGContextRef ctx, CGRect plot, NSArray<PerfSession *> *sessions, NSString *metric) {
    NSMutableArray<NSNumber *> *values = [NSMutableArray new];
    double maxValue = 0;
    for (PerfSession *session in sessions) {
        double value = [session metricValue:metric aggregate:@"avg"];
        [values addObject:@(isnan(value) ? 0 : value)];
        if (!isnan(value)) {
            maxValue = MAX(maxValue, value);
        }
    }
    if (maxValue <= 0) {
        PerfDrawNoData(plot);
        return;
    }
    double yMax = PerfNiceMax(maxValue * 1.15);

    NSMutableArray<NSString *> *xLabels = [NSMutableArray new];
    for (NSUInteger i = 0; i < sessions.count; i++) {
        [xLabels addObject:[NSString stringWithFormat:@"#%lu", (unsigned long)(i + 1)]];
    }
    PerfDrawAxes(ctx, plot, yMax, xLabels);

    CGFloat slot = plot.size.width / MAX(sessions.count, 1);
    CGFloat barWidth = MIN(slot * 0.62, 120);
    for (NSUInteger i = 0; i < sessions.count; i++) {
        CGFloat value = values[i].doubleValue;
        CGFloat height = plot.size.height * (value / yMax);
        CGRect bar = CGRectMake(CGRectGetMinX(plot) + slot * i + (slot - barWidth) / 2,
                                CGRectGetMaxY(plot) - height, barWidth, height);
        PerfApplyStyle(ctx, i, NO);
        CGContextFillRect(ctx, bar);
        CGContextSetLineDash(ctx, 0, NULL, 0);
        CGContextSetLineWidth(ctx, 1);
        CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
        CGContextStrokeRect(ctx, bar);
        if (value > 0) {
            PerfDrawText([NSString stringWithFormat:@"%.1f", value],
                         CGRectMake(bar.origin.x - 14, bar.origin.y - 15, bar.size.width + 28, 12),
                         PerfMono(9, YES), [UIColor colorWithWhite:0.1 alpha:1], NSTextAlignmentCenter);
        }
    }
}

static void PerfDrawPieChart(CGContextRef ctx, CGRect plot, NSArray<PerfSession *> *sessions, NSString *metric, NSArray<NSNumber *> *values) {
    double total = 0;
    for (NSNumber *value in values) {
        if (!isnan(value.doubleValue)) {
            total += MAX(value.doubleValue, 0);
        }
    }
    if (total <= 0) {
        PerfDrawNoData(plot);
        return;
    }

    CGPoint center = CGPointMake(CGRectGetMidX(plot), CGRectGetMidY(plot));
    CGFloat radius = MIN(plot.size.width, plot.size.height) / 2 - 6;
    CGFloat angle = -M_PI_2;

    for (NSUInteger i = 0; i < values.count; i++) {
        double value = isnan(values[i].doubleValue) ? 0 : MAX(values[i].doubleValue, 0);
        if (value <= 0) {
            continue;
        }
        CGFloat sweep = 2 * M_PI * (value / total);
        PerfApplyStyle(ctx, i, NO);
        CGContextSetLineDash(ctx, 0, NULL, 0);
        CGContextMoveToPoint(ctx, center.x, center.y);
        CGContextAddArc(ctx, center.x, center.y, radius, angle, angle + sweep, 0);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        CGContextSetLineWidth(ctx, 1.4);
        CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
        CGContextMoveToPoint(ctx, center.x, center.y);
        CGContextAddArc(ctx, center.x, center.y, radius, angle, angle + sweep, 0);
        CGContextClosePath(ctx);
        CGContextStrokePath(ctx);

        if (sweep >= 0.22) {
            CGFloat mid = angle + sweep / 2;
            NSString *percent = [NSString stringWithFormat:@"%.0f%%", 100 * value / total];
            UIColor *textColor = PerfStyleGray(i) < 0.42 ? UIColor.whiteColor : UIColor.blackColor;
            PerfDrawText(percent,
                         CGRectMake(center.x + cos(mid) * radius * 0.62 - 26, center.y + sin(mid) * radius * 0.62 - 7, 52, 14),
                         PerfMono(10, YES), textColor, NSTextAlignmentCenter);
        }
        angle += sweep;
    }
}

#pragma mark - Tile

static void PerfDrawTile(CGContextRef ctx, CGRect tile, NSArray<PerfSession *> *sessions, NSString *metric, PerfChartType type, BOOL placeholder) {
    CGFloat inset = 22;
    CGRect content = CGRectInset(tile, inset, inset);

    if (placeholder) {
        PerfDrawNoData(content);
        return;
    }

    UIFont *titleFont = PerfMono(15, YES);
    CGFloat titleHeight = 20;
    NSString *unit = PerfMetricUnit(metric);
    NSString *title = [PerfChartRenderer displayNameForMetric:metric];
    if (unit.length > 0) {
        title = [title stringByAppendingFormat:@" (%@)", unit];
    }
    PerfDrawText(title, CGRectMake(CGRectGetMinX(content), CGRectGetMinY(content), content.size.width, titleHeight),
                 titleFont, UIColor.blackColor, NSTextAlignmentLeft);

    static NSDateFormatter *dayFormatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dayFormatter = [NSDateFormatter new];
        dayFormatter.dateFormat = @"dd/MM/yyyy HH:mm";
    });
    NSString *subtitle;
    PerfSession *first = sessions.firstObject;
    NSString *device = first.meta[@"device"][@"model"] ?: @"";
    if (sessions.count == 1) {
        subtitle = [NSString stringWithFormat:@"%@ · %@ · %@", [dayFormatter stringFromDate:first.startedAt],
                    PerfFormatDuration(first.duration), device];
    } else {
        subtitle = [NSString stringWithFormat:localize(@"perf.chart.subtitle_multi", nil),
                    (unsigned long)sessions.count, device];
    }
    PerfDrawText(subtitle, CGRectMake(CGRectGetMinX(content), CGRectGetMinY(content) + titleHeight - 2, content.size.width, 14),
                 PerfMono(9, NO), [UIColor colorWithWhite:0.35 alpha:1], NSTextAlignmentLeft);

    NSMutableArray<NSNumber *> *values = [NSMutableArray new];
    for (PerfSession *session in sessions) {
        double value = [session metricValue:metric aggregate:@"avg"];
        [values addObject:@(value)];
    }

    CGFloat legendHeight = sessions.count > 0 ? (sessions.count > 4 ? 2 : sessions.count) * 15 + 6 : 0;
    CGFloat headerHeight = titleHeight + 14;
    CGRect plot = CGRectMake(CGRectGetMinX(content) + 46,
                             CGRectGetMinY(content) + headerHeight,
                             content.size.width - 46,
                             content.size.height - headerHeight - legendHeight - 18);
    plot.size.height = MIN(plot.size.height, content.size.width - 46);

    if (type == PerfChartTypePie) {
        CGRect pieRect = plot;
        pieRect.size.height = plot.size.height;
        pieRect = CGRectMake(CGRectGetMinX(plot), CGRectGetMinY(plot), plot.size.width, MIN(plot.size.width, plot.size.height));
        PerfDrawPieChart(ctx, pieRect, sessions, metric, values);
    } else if (type == PerfChartTypeBar) {
        PerfDrawBarChart(ctx, plot, sessions, metric);
    } else {
        PerfDrawLineChart(ctx, plot, sessions, metric);
    }

    CGRect legendRect = CGRectMake(CGRectGetMinX(content), CGRectGetMaxY(plot) + 16, content.size.width, legendHeight);
    PerfDrawLegend(ctx, legendRect, sessions, values, type == PerfChartTypePie);
}

#pragma mark - Public

@implementation PerfChartRenderer

+ (NSString *)displayNameForMetric:(NSString *)metric {
    return localize([@"perf.metric." stringByAppendingString:metric], nil);
}

+ (void)drawSessions:(NSArray<PerfSession *> *)sessions
             metrics:(NSArray<NSString *> *)metrics
                type:(PerfChartType)type
            combined:(BOOL)combined
                side:(CGFloat)side
              inRect:(CGRect)canvas {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return;
    }

    [[UIColor whiteColor] setFill];
    CGContextFillRect(ctx, canvas);

    CGFloat margin = 14;
    CGFloat footerHeight = 20;
    CGRect content = CGRectInset(canvas, margin, margin);
    CGRect footer = CGRectMake(CGRectGetMinX(content), CGRectGetMaxY(content) - footerHeight, content.size.width, footerHeight);
    CGRect grid = content;
    grid.size.height = content.size.height - footerHeight;

    if (combined && metrics.count > 1) {
        NSUInteger columns = metrics.count <= 4 ? 2 : 3;
        CGFloat tileSide = grid.size.width / columns;
        for (NSUInteger i = 0; i < columns * columns; i++) {
            NSUInteger column = i % columns;
            NSUInteger row = i / columns;
            CGRect tile = CGRectMake(CGRectGetMinX(grid) + column * tileSide,
                                     CGRectGetMinY(grid) + row * tileSide,
                                     tileSide, tileSide);
            if (i < metrics.count) {
                PerfDrawTile(ctx, tile, sessions, metrics[i], type, NO);
            }
            CGContextSetLineWidth(ctx, 0.5);
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.82 alpha:1].CGColor);
            CGContextSetLineDash(ctx, 0, NULL, 0);
            CGContextMoveToPoint(ctx, CGRectGetMinX(tile), CGRectGetMinY(tile));
            CGContextAddLineToPoint(ctx, CGRectGetMaxX(tile), CGRectGetMinY(tile));
            CGContextMoveToPoint(ctx, CGRectGetMinX(tile), CGRectGetMinY(tile));
            CGContextAddLineToPoint(ctx, CGRectGetMinX(tile), CGRectGetMaxY(tile));
            CGContextStrokePath(ctx);
        }
    } else {
        NSString *metric = metrics.firstObject ?: @"fps";
        PerfDrawTile(ctx, grid, sessions, metric, type, sessions.count == 0);
    }

    static NSDateFormatter *stampFormatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stampFormatter = [NSDateFormatter new];
        stampFormatter.dateFormat = @"dd/MM/yyyy HH:mm";
    });
    PerfDrawWitchLogo(footer, 13, footer.size.width * 0.45, 1.0, YES);
    PerfDrawText([NSString stringWithFormat:@"generated %@", [stampFormatter stringFromDate:NSDate.date]],
                 footer, PerfMono(9, NO), [UIColor colorWithWhite:0.45 alpha:1], NSTextAlignmentRight);

    CGContextSetLineWidth(ctx, 2);
    CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
    CGContextSetLineDash(ctx, 0, NULL, 0);
    CGContextStrokeRect(ctx, CGRectInset(canvas, 5, 5));
}

+ (UIImage *)imageForSessions:(NSArray<PerfSession *> *)sessions
                      metrics:(NSArray<NSString *> *)metrics
                         type:(PerfChartType)type
                     combined:(BOOL)combined
                         side:(CGFloat)side {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 2;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [self drawSessions:sessions metrics:metrics type:type combined:combined side:side
                    inRect:CGRectMake(0, 0, side, side)];
    }];
}

+ (NSData *)pdfDataForSessions:(NSArray<PerfSession *> *)sessions
                       metrics:(NSArray<NSString *> *)metrics
                          type:(PerfChartType)type
                      combined:(BOOL)combined
                          side:(CGFloat)side {
    UIGraphicsPDFRendererFormat *format = [UIGraphicsPDFRendererFormat new];
    UIGraphicsPDFRenderer *renderer = [[UIGraphicsPDFRenderer alloc] initWithBounds:CGRectMake(0, 0, side, side) format:format];
    return [renderer PDFDataWithActions:^(UIGraphicsPDFRendererContext *context) {
        [context beginPage];
        [self drawSessions:sessions metrics:metrics type:type combined:combined side:side
                    inRect:CGRectMake(0, 0, side, side)];
    }];
}

@end
