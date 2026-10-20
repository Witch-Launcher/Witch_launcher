#import "CursorShapeRenderer.h"

static BOOL gDiagonalUsesNESW = NO;

static UIColor *InkColor(void) {
    return [UIColor colorWithRed:17.0 / 255.0 green:17.0 / 255.0 blue:20.0 / 255.0 alpha:1.0];
}

static UIColor *BlueColor(void) {
    return [UIColor colorWithRed:10.0 / 255.0 green:132.0 / 255.0 blue:255.0 / 255.0 alpha:1.0];
}

static UIColor *RedColor(void) {
    return [UIColor colorWithRed:225.0 / 255.0 green:25.0 / 255.0 blue:25.0 / 255.0 alpha:1.0];
}

static UIBezierPath *Polygon(NSArray<NSValue *> *points) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:points.firstObject.CGPointValue];
    for (NSUInteger i = 1; i < points.count; i++) {
        [path addLineToPoint:points[i].CGPointValue];
    }
    [path closePath];
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineCapStyle = kCGLineCapRound;
    return path;
}

static UIBezierPath *RoundedRect(CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat r) {
    return [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, w, h) cornerRadius:r];
}

static void FillStroke(UIBezierPath *path, UIColor *fill, UIColor *stroke, CGFloat width) {
    [fill setFill];
    [path fill];
    [stroke setStroke];
    path.lineWidth = width;
    [path stroke];
}

static void SetShadow(CGContextRef ctx) {
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0.55), 0.55,
                                [UIColor colorWithWhite:0 alpha:0.30].CGColor);
}

static void ClearShadow(CGContextRef ctx) {
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
}

static UIBezierPath *ArrowPath(void) {
    return Polygon(@[
        [NSValue valueWithCGPoint:CGPointMake(1.5, 1.5)],
        [NSValue valueWithCGPoint:CGPointMake(1.5, 20.4)],
        [NSValue valueWithCGPoint:CGPointMake(6.8, 15.4)],
        [NSValue valueWithCGPoint:CGPointMake(10.5, 23.5)],
        [NSValue valueWithCGPoint:CGPointMake(13.4, 22.1)],
        [NSValue valueWithCGPoint:CGPointMake(9.8, 14.2)],
        [NSValue valueWithCGPoint:CGPointMake(16.5, 14.2)],
    ]);
}

static UIBezierPath *LinkPath(void) {
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(8.0, 2.2)];
    [p addCurveToPoint:CGPointMake(6.9, 3.7)
         controlPoint1:CGPointMake(7.35, 2.2)
         controlPoint2:CGPointMake(6.9, 2.8)];
    [p addLineToPoint:CGPointMake(6.9, 13.4)];
    [p addLineToPoint:CGPointMake(5.4, 12.0)];
    [p addCurveToPoint:CGPointMake(3.0, 12.2)
         controlPoint1:CGPointMake(4.7, 11.4)
         controlPoint2:CGPointMake(3.6, 11.5)];
    [p addCurveToPoint:CGPointMake(3.2, 14.5)
         controlPoint1:CGPointMake(2.4, 12.9)
         controlPoint2:CGPointMake(2.5, 13.9)];
    [p addLineToPoint:CGPointMake(7.9, 19.6)];
    [p addCurveToPoint:CGPointMake(11.0, 21.0)
         controlPoint1:CGPointMake(8.7, 20.5)
         controlPoint2:CGPointMake(9.8, 21.0)];
    [p addLineToPoint:CGPointMake(14.8, 21.0)];
    [p addCurveToPoint:CGPointMake(18.7, 17.1)
         controlPoint1:CGPointMake(17.0, 21.0)
         controlPoint2:CGPointMake(18.7, 19.3)];
    [p addLineToPoint:CGPointMake(18.7, 12.6)];
    [p addCurveToPoint:CGPointMake(17.4, 11.3)
         controlPoint1:CGPointMake(18.7, 11.9)
         controlPoint2:CGPointMake(18.1, 11.3)];
    [p addCurveToPoint:CGPointMake(16.1, 12.6)
         controlPoint1:CGPointMake(16.7, 11.3)
         controlPoint2:CGPointMake(16.1, 11.9)];
    [p addLineToPoint:CGPointMake(16.1, 11.2)];
    [p addCurveToPoint:CGPointMake(14.8, 9.9)
         controlPoint1:CGPointMake(16.1, 10.5)
         controlPoint2:CGPointMake(15.5, 9.9)];
    [p addCurveToPoint:CGPointMake(13.5, 11.2)
         controlPoint1:CGPointMake(14.1, 9.9)
         controlPoint2:CGPointMake(13.5, 10.5)];
    [p addLineToPoint:CGPointMake(13.5, 10.1)];
    [p addCurveToPoint:CGPointMake(12.2, 8.8)
         controlPoint1:CGPointMake(13.5, 9.4)
         controlPoint2:CGPointMake(12.9, 8.8)];
    [p addCurveToPoint:CGPointMake(10.9, 10.1)
         controlPoint1:CGPointMake(11.5, 8.8)
         controlPoint2:CGPointMake(10.9, 9.4)];
    [p addLineToPoint:CGPointMake(10.9, 12.4)];
    [p addLineToPoint:CGPointMake(10.9, 3.7)];
    [p addCurveToPoint:CGPointMake(9.8, 2.2)
         controlPoint1:CGPointMake(10.9, 2.8)
         controlPoint2:CGPointMake(10.45, 2.2)];
    [p closePath];
    p.lineJoinStyle = kCGLineJoinRound;
    p.lineCapStyle = kCGLineCapRound;
    return p;
}

static NSArray<UIBezierPath *> *TextPaths(void) {
    return @[
        RoundedRect(8.7, 4.6, 2.6, 18.8, 1.3),
        RoundedRect(4.8, 3.7, 10.4, 2.6, 1.3),
        RoundedRect(4.8, 21.7, 10.4, 2.6, 1.3),
    ];
}

static NSArray<UIBezierPath *> *PrecisionPaths(void) {
    return @[
        RoundedRect(2.8, 11.1, 7.4, 1.8, 0.9),
        RoundedRect(13.8, 11.1, 7.4, 1.8, 0.9),
        RoundedRect(11.1, 2.8, 1.8, 7.4, 0.9),
        RoundedRect(11.1, 13.8, 1.8, 7.4, 0.9),
    ];
}

static NSArray<UIBezierPath *> *ResizePaths(void) {
    return @[
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(12, 2.5)],
            [NSValue valueWithCGPoint:CGPointMake(16.2, 7.0)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 7.0)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 17.0)],
            [NSValue valueWithCGPoint:CGPointMake(16.2, 17.0)],
            [NSValue valueWithCGPoint:CGPointMake(12, 21.5)],
            [NSValue valueWithCGPoint:CGPointMake(7.8, 17.0)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 17.0)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 7.0)],
            [NSValue valueWithCGPoint:CGPointMake(7.8, 7.0)],
        ]),
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(2.5, 12)],
            [NSValue valueWithCGPoint:CGPointMake(7.0, 7.8)],
            [NSValue valueWithCGPoint:CGPointMake(7.0, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(17.0, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(17.0, 7.8)],
            [NSValue valueWithCGPoint:CGPointMake(21.5, 12)],
            [NSValue valueWithCGPoint:CGPointMake(17.0, 16.2)],
            [NSValue valueWithCGPoint:CGPointMake(17.0, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(7.0, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(7.0, 16.2)],
        ]),
    ];
}

static UIBezierPath *DiagonalPath(void) {
    if (gDiagonalUsesNESW) {
        return Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(21, 3)],
            [NSValue valueWithCGPoint:CGPointMake(14.6, 3.7)],
            [NSValue valueWithCGPoint:CGPointMake(16.5, 5.5)],
            [NSValue valueWithCGPoint:CGPointMake(5.5, 16.5)],
            [NSValue valueWithCGPoint:CGPointMake(3.7, 14.6)],
            [NSValue valueWithCGPoint:CGPointMake(3, 21)],
            [NSValue valueWithCGPoint:CGPointMake(9.4, 20.3)],
            [NSValue valueWithCGPoint:CGPointMake(7.5, 18.5)],
            [NSValue valueWithCGPoint:CGPointMake(18.5, 7.5)],
            [NSValue valueWithCGPoint:CGPointMake(20.3, 9.4)],
        ]);
    }
    return Polygon(@[
        [NSValue valueWithCGPoint:CGPointMake(3, 3)],
        [NSValue valueWithCGPoint:CGPointMake(9.4, 3.7)],
        [NSValue valueWithCGPoint:CGPointMake(7.5, 5.5)],
        [NSValue valueWithCGPoint:CGPointMake(18.5, 16.5)],
        [NSValue valueWithCGPoint:CGPointMake(20.3, 14.6)],
        [NSValue valueWithCGPoint:CGPointMake(21, 21)],
        [NSValue valueWithCGPoint:CGPointMake(14.6, 20.3)],
        [NSValue valueWithCGPoint:CGPointMake(16.5, 18.5)],
        [NSValue valueWithCGPoint:CGPointMake(5.5, 7.5)],
        [NSValue valueWithCGPoint:CGPointMake(3.7, 9.4)],
    ]);
}

static NSArray<UIBezierPath *> *MovePaths(void) {
    return @[
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(12, 2.5)],
            [NSValue valueWithCGPoint:CGPointMake(16, 7)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 7)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 12)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 12)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 7)],
            [NSValue valueWithCGPoint:CGPointMake(8, 7)],
        ]),
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(21.5, 12)],
            [NSValue valueWithCGPoint:CGPointMake(17, 16)],
            [NSValue valueWithCGPoint:CGPointMake(17, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(12, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(12, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(17, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(17, 8)],
        ]),
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(12, 21.5)],
            [NSValue valueWithCGPoint:CGPointMake(8, 17)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 17)],
            [NSValue valueWithCGPoint:CGPointMake(10.6, 12)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 12)],
            [NSValue valueWithCGPoint:CGPointMake(13.4, 17)],
            [NSValue valueWithCGPoint:CGPointMake(16, 17)],
        ]),
        Polygon(@[
            [NSValue valueWithCGPoint:CGPointMake(2.5, 12)],
            [NSValue valueWithCGPoint:CGPointMake(7, 8)],
            [NSValue valueWithCGPoint:CGPointMake(7, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(12, 10.6)],
            [NSValue valueWithCGPoint:CGPointMake(12, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(7, 13.4)],
            [NSValue valueWithCGPoint:CGPointMake(7, 16)],
        ]),
    ];
}

static void DrawWhiteHaloGlyph(NSArray<UIBezierPath *> *paths) {
    UIColor *white = [UIColor whiteColor];
    for (UIBezierPath *p in paths) {
        FillStroke(p, white, white, 2.4);
    }
    UIColor *ink = InkColor();
    for (UIBezierPath *p in paths) {
        [ink setFill];
        [p fill];
    }
}

static void DrawArrowGlyph(CGContextRef ctx) {
    UIBezierPath *arrow = ArrowPath();
    SetShadow(ctx);
    FillStroke(arrow, InkColor(), InkColor(), 2.2);
    ClearShadow(ctx);
    [[UIColor whiteColor] setFill];
    [arrow fill];
}

static void DrawArrowWithBadge(CGContextRef ctx, BOOL isHelp) {
    UIBezierPath *arrow = ArrowPath();
    UIBezierPath *badge = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(11.2, 16.2, 8.0, 8.0)];

    SetShadow(ctx);
    FillStroke(arrow, InkColor(), InkColor(), 2.2);
    FillStroke(badge, InkColor(), InkColor(), 2.2);
    ClearShadow(ctx);

    UIColor *white = [UIColor whiteColor];
    [white setFill];
    [arrow fill];
    [white setFill];
    [badge fill];

    if (isHelp) {
        UIBezierPath *q = [UIBezierPath bezierPath];
        [q moveToPoint:CGPointMake(13.6, 19.3)];
        [q addCurveToPoint:CGPointMake(15.4, 17.4)
             controlPoint1:CGPointMake(13.6, 18.1)
             controlPoint2:CGPointMake(14.4, 17.4)];
        [q addCurveToPoint:CGPointMake(17.0, 18.9)
             controlPoint1:CGPointMake(16.4, 17.4)
             controlPoint2:CGPointMake(17.0, 18.1)];
        [q addCurveToPoint:CGPointMake(15.8, 20.5)
             controlPoint1:CGPointMake(17.0, 19.7)
             controlPoint2:CGPointMake(16.5, 20.1)];
        [q addCurveToPoint:CGPointMake(15.1, 21.7)
             controlPoint1:CGPointMake(15.2, 20.9)
             controlPoint2:CGPointMake(15.1, 21.2)];
        q.lineWidth = 1.0;
        q.lineCapStyle = kCGLineCapRound;
        [InkColor() setStroke];
        [q stroke];

        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(14.3, 21.9, 1.6, 1.6)];
        [InkColor() setFill];
        [dot fill];
    } else {
        UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(15.2, 20.2)
                                                          radius:2.4
                                                      startAngle:-M_PI_2
                                                        endAngle:M_PI
                                                       clockwise:YES];
        arc.lineWidth = 1.3;
        arc.lineCapStyle = kCGLineCapRound;
        [BlueColor() setStroke];
        [arc stroke];
    }
}

@implementation CursorShapeRenderer

+ (void)setDiagonalUsesNESW:(BOOL)useNESW {
    gDiagonalUsesNESW = useNESW;
}

+ (BOOL)hasShapeForType:(NSString *)typeId {
    static NSSet<NSString *> *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        types = [NSSet setWithArray:@[
            @"normal", @"link", @"text", @"busy", @"working",
            @"precision", @"crosshair", @"unavailable", @"vresize",
            @"hresize", @"diagonal", @"move", @"help", @"hidden",
        ]];
    });
    return [types containsObject:typeId];
}

+ (CGSize)viewBoxSizeForType:(NSString *)typeId {
    if ([typeId isEqualToString:@"normal"] || [typeId isEqualToString:@"link"] || [typeId isEqualToString:@"text"]) {
        return CGSizeMake(20, 28);
    }
    if ([typeId isEqualToString:@"working"] || [typeId isEqualToString:@"help"]) {
        return CGSizeMake(22, 28);
    }
    if ([self hasShapeForType:typeId]) {
        return CGSizeMake(24, 24);
    }
    return CGSizeZero;
}

+ (void)drawType:(NSString *)typeId inContext:(CGContextRef)ctx {
    if ([typeId isEqualToString:@"normal"]) {
        DrawArrowGlyph(ctx);
    } else if ([typeId isEqualToString:@"link"]) {
        UIBezierPath *hand = LinkPath();
        SetShadow(ctx);
        FillStroke(hand, InkColor(), InkColor(), 2.2);
        ClearShadow(ctx);
        [[UIColor whiteColor] setFill];
        [hand fill];
    } else if ([typeId isEqualToString:@"text"]) {
        DrawWhiteHaloGlyph(TextPaths());
    } else if ([typeId isEqualToString:@"busy"]) {
        UIBezierPath *disc = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.8, 3.8, 16.4, 16.4)];
        SetShadow(ctx);
        FillStroke(disc, InkColor(), InkColor(), 2.2);
        ClearShadow(ctx);
        [[UIColor whiteColor] setFill];
        [disc fill];

        UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12, 12)
                                                          radius:7.0
                                                      startAngle:-M_PI_2
                                                        endAngle:M_PI
                                                       clockwise:YES];
        arc.lineWidth = 1.8;
        arc.lineCapStyle = kCGLineCapRound;
        [BlueColor() setStroke];
        [arc stroke];
    } else if ([typeId isEqualToString:@"working"]) {
        DrawArrowWithBadge(ctx, NO);
    } else if ([typeId isEqualToString:@"precision"] || [typeId isEqualToString:@"crosshair"]) {
        DrawWhiteHaloGlyph(PrecisionPaths());
    } else if ([typeId isEqualToString:@"unavailable"]) {
        UIBezierPath *disc = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.8, 3.8, 16.4, 16.4)];
        SetShadow(ctx);
        FillStroke(disc, InkColor(), InkColor(), 2.2);
        ClearShadow(ctx);
        [[UIColor whiteColor] setFill];
        [disc fill];

        UIBezierPath *slash = [UIBezierPath bezierPath];
        [slash moveToPoint:CGPointMake(7.5, 7.5)];
        [slash addLineToPoint:CGPointMake(16.5, 16.5)];
        slash.lineCapStyle = kCGLineCapRound;
        slash.lineWidth = 3.8;
        [InkColor() setStroke];
        [slash stroke];
        slash.lineWidth = 2.2;
        [RedColor() setStroke];
        [slash stroke];
    } else if ([typeId isEqualToString:@"vresize"] || [typeId isEqualToString:@"hresize"]) {
        NSArray<UIBezierPath *> *paths = ResizePaths();
        if ([typeId isEqualToString:@"vresize"]) {
            DrawWhiteHaloGlyph(@[paths[0]]);
        } else {
            DrawWhiteHaloGlyph(@[paths[1]]);
        }
    } else if ([typeId isEqualToString:@"diagonal"]) {
        DrawWhiteHaloGlyph(@[DiagonalPath()]);
    } else if ([typeId isEqualToString:@"move"]) {
        DrawWhiteHaloGlyph(MovePaths());
    } else if ([typeId isEqualToString:@"help"]) {
        DrawArrowWithBadge(ctx, YES);
    } else if ([typeId isEqualToString:@"hidden"]) {
        // trong suốt
    }
}

+ (nullable UIImage *)imageForType:(NSString *)typeId size:(CGSize)size scale:(CGFloat)scale {
    CGSize viewBox = [self viewBoxSizeForType:typeId];
    if (viewBox.width <= 0 || viewBox.height <= 0) return nil;
    if (size.width <= 0 || size.height <= 0) return nil;
    if (scale <= 0) scale = [UIScreen mainScreen].scale;

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        UIGraphicsEndImageContext();
        return nil;
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextConcatCTM(ctx, CGAffineTransformMakeScale(size.width / viewBox.width,
                                                       size.height / viewBox.height));
    [self drawType:typeId inContext:ctx];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
