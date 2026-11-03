#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
#import "WitchPluginAPI.h"
#import "glfw_keycodes.h"

enum {
    PEKeyKeyboard = -1,
    PEKeyToggleControls = -2,
    PEKeyMousePrimary = -3,
    PEKeyMouseSecondary = -4,
    PEKeyVirtualMouse = -5,
    PEKeyMouseMiddle = -6,
    PEKeyScrollUp = -7,
    PEKeyScrollDown = -8,
    PEKeyMenu = -9
};

static const void *PESkinKey = &PESkinKey;
static const void *PEOuterKey = &PEOuterKey;
static const void *PEThumbKey = &PEThumbKey;

static IMP PEOriginalButtonUpdate;
static IMP PEOriginalJoystickUpdate;
static BOOL PEHooksInstalled;

static CGPoint PEPoint(CGRect rect, CGFloat x, CGFloat y) {
    return CGPointMake(CGRectGetMinX(rect) + CGRectGetWidth(rect) * x,
                       CGRectGetMinY(rect) + CGRectGetHeight(rect) * y);
}

static void PEMove(UIBezierPath *path, CGRect rect, CGFloat x, CGFloat y) {
    [path moveToPoint:PEPoint(rect, x, y)];
}

static void PELine(UIBezierPath *path, CGRect rect, CGFloat x, CGFloat y) {
    [path addLineToPoint:PEPoint(rect, x, y)];
}

static UIColor *PEWhite(CGFloat alpha) {
    return [UIColor colorWithWhite:1.0 alpha:alpha];
}

static UIColor *PEBlack(CGFloat alpha) {
    return [UIColor colorWithWhite:0.0 alpha:alpha];
}

static BOOL PEIsSmallSquare(CGRect rect) {
    return fabs(CGRectGetWidth(rect) - CGRectGetHeight(rect)) < 3.0;
}

static BOOL PEIconIsCircular(NSString *icon) {
    return [icon isEqualToString:@"jump"] || [icon isEqualToString:@"sneak"] || [icon isEqualToString:@"sprint"] || [icon isEqualToString:@"fly"];
}

static NSInteger PEKeycode(NSDictionary *properties) {
    id keys = properties[@"keycodes"];
    if ([keys isKindOfClass:[NSArray class]]) {
        for (id value in keys) {
            if ([value isKindOfClass:[NSNumber class]] && [value integerValue] != 0) {
                return [value integerValue];
            }
        }
    }
    id key = properties[@"keycode"];
    return [key isKindOfClass:[NSNumber class]] ? [key integerValue] : 0;
}

static NSString *PEIconForButton(id button) {
    if ([button isKindOfClass:NSClassFromString(@"ControlDrawer")]) return @"drawer";
    NSDictionary *properties = [button valueForKey:@"properties"];
    if (![properties isKindOfClass:[NSDictionary class]]) return nil;
    NSString *name = [properties[@"name"] isKindOfClass:[NSString class]] ? [properties[@"name"] lowercaseString] : @"";
    NSInteger key = PEKeycode(properties);
    if ([name containsString:@"jump"] || [name containsString:@"nhảy"] || [name containsString:@"nhay"] || key == GLFW_KEY_SPACE) return @"jump";
    if ([name containsString:@"sneak"] || [name containsString:@"crouch"] || [name containsString:@"ngồi"] || [name containsString:@"ngoi"] || key == GLFW_KEY_LEFT_SHIFT) return @"sneak";
    if ([name containsString:@"sprint"] || [name containsString:@"chạy"] || [name containsString:@"chay"] || key == GLFW_KEY_LEFT_CONTROL) return @"sprint";
    if ([name containsString:@"fly"] || [name containsString:@"bay"]) return @"fly";
    if ([name containsString:@"inventory"] || [name containsString:@"inv"] || [name containsString:@"túi"] || [name containsString:@"tui"] || key == GLFW_KEY_E) return @"inventory";
    if ([name containsString:@"chat"] || key == GLFW_KEY_T) return @"chat";
    if ([name containsString:@"pause"] || [name containsString:@"menu"] || key == GLFW_KEY_ESCAPE || key == PEKeyMenu) return @"menu";
    if ([name containsString:@"keyboard"] || key == PEKeyKeyboard) return @"keyboard";
    if ([name containsString:@"mouse"] || key == PEKeyVirtualMouse || key == PEKeyMouseMiddle) return @"cursor";
    if (key == PEKeyMousePrimary) return @"attack";
    if (key == PEKeyMouseSecondary) return @"place";
    if ([name containsString:@"3rd"] || [name containsString:@"third"] || key == GLFW_KEY_F5) return @"camera";
    if ([name containsString:@"zoom"] || key == GLFW_KEY_C) return @"zoom";
    if ([name containsString:@"offhand"] || key == GLFW_KEY_F) return @"shield";
    if ([name containsString:@"debug"] || key == GLFW_KEY_F3) return @"debug";
    if ([name containsString:@"tab"] || key == GLFW_KEY_TAB) return @"list";
    if ([name containsString:@"gui"] || key == PEKeyToggleControls) return @"sliders";
    if (key == GLFW_KEY_W || key == GLFW_KEY_DPAD_UP || key == PEKeyScrollUp) return @"up";
    if (key == GLFW_KEY_S || key == GLFW_KEY_DPAD_DOWN || key == PEKeyScrollDown) return @"down";
    if (key == GLFW_KEY_A || key == GLFW_KEY_DPAD_LEFT) return @"left";
    if (key == GLFW_KEY_D || key == GLFW_KEY_DPAD_RIGHT) return @"right";
    return nil;
}

static void PEDrawIcon(NSString *icon, CGRect rect) {
    if (icon.length == 0) return;
    CGFloat side = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect));
    CGFloat glyphSide = side * 0.46;
    CGRect glyph = CGRectMake(CGRectGetMidX(rect) - glyphSide * 0.5,
                              CGRectGetMidY(rect) - glyphSide * 0.5,
                              glyphSide, glyphSide);
    UIBezierPath *stroke = [UIBezierPath bezierPath];
    stroke.lineWidth = MAX(1.4, side * 0.050);
    stroke.lineCapStyle = kCGLineCapRound;
    stroke.lineJoinStyle = kCGLineJoinRound;
    UIBezierPath *fill = [UIBezierPath bezierPath];

    if ([icon isEqualToString:@"jump"] || [icon isEqualToString:@"up"]) {
        PEMove(stroke, glyph, 0.50, 0.16);
        PELine(stroke, glyph, 0.50, 0.84);
        PEMove(stroke, glyph, 0.20, 0.45);
        PELine(stroke, glyph, 0.50, 0.16);
        PELine(stroke, glyph, 0.80, 0.45);
    } else if ([icon isEqualToString:@"sneak"] || [icon isEqualToString:@"down"]) {
        PEMove(stroke, glyph, 0.20, 0.28);
        PELine(stroke, glyph, 0.50, 0.55);
        PELine(stroke, glyph, 0.80, 0.28);
        PEMove(stroke, glyph, 0.50, 0.45);
        PELine(stroke, glyph, 0.50, 0.84);
    } else if ([icon isEqualToString:@"sprint"]) {
        PEMove(stroke, glyph, 0.16, 0.22);
        PELine(stroke, glyph, 0.42, 0.50);
        PELine(stroke, glyph, 0.16, 0.78);
        PEMove(stroke, glyph, 0.44, 0.22);
        PELine(stroke, glyph, 0.70, 0.50);
        PELine(stroke, glyph, 0.44, 0.78);
        PEMove(stroke, glyph, 0.68, 0.30);
        PELine(stroke, glyph, 0.84, 0.50);
        PELine(stroke, glyph, 0.68, 0.70);
    } else if ([icon isEqualToString:@"left"]) {
        PEMove(stroke, glyph, 0.78, 0.20);
        PELine(stroke, glyph, 0.44, 0.50);
        PELine(stroke, glyph, 0.78, 0.80);
    } else if ([icon isEqualToString:@"right"]) {
        PEMove(stroke, glyph, 0.22, 0.20);
        PELine(stroke, glyph, 0.56, 0.50);
        PELine(stroke, glyph, 0.22, 0.80);
    } else if ([icon isEqualToString:@"inventory"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectInset(glyph, glyphSide * 0.12, glyphSide * 0.12) cornerRadius:glyphSide * 0.13]];
        PEMove(stroke, glyph, 0.36, 0.20);
        PELine(stroke, glyph, 0.36, 0.80);
        PEMove(stroke, glyph, 0.64, 0.20);
        PELine(stroke, glyph, 0.64, 0.80);
        PEMove(stroke, glyph, 0.20, 0.40);
        PELine(stroke, glyph, 0.80, 0.40);
        PEMove(stroke, glyph, 0.20, 0.60);
        PELine(stroke, glyph, 0.80, 0.60);
    } else if ([icon isEqualToString:@"chat"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.10,
                                                                               CGRectGetMinY(glyph) + glyphSide * 0.14,
                                                                               glyphSide * 0.80,
                                                                               glyphSide * 0.52)
                                                            cornerRadius:glyphSide * 0.14]];
        PEMove(stroke, glyph, 0.34, 0.66);
        PELine(stroke, glyph, 0.28, 0.84);
        PELine(stroke, glyph, 0.50, 0.66);
        for (NSNumber *x in @[@0.32, @0.50, @0.68]) {
            [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * ([x doubleValue] - 0.035),
                                                                                CGRectGetMinY(glyph) + glyphSide * 0.39,
                                                                                glyphSide * 0.07,
                                                                                glyphSide * 0.07)]];
        }
    } else if ([icon isEqualToString:@"menu"]) {
        for (NSNumber *y in @[@0.30, @0.50, @0.70]) {
            PEMove(stroke, glyph, 0.20, [y doubleValue]);
            PELine(stroke, glyph, 0.80, [y doubleValue]);
        }
    } else if ([icon isEqualToString:@"keyboard"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.08,
                                                                               CGRectGetMinY(glyph) + glyphSide * 0.28,
                                                                               glyphSide * 0.84,
                                                                               glyphSide * 0.48)
                                                            cornerRadius:glyphSide * 0.10]];
        for (NSNumber *y in @[@0.40, @0.52, @0.64]) {
            for (NSNumber *x in @[@0.22, @0.38, @0.54, @0.70]) {
                [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * [x doubleValue],
                                                                                    CGRectGetMinY(glyph) + glyphSide * [y doubleValue],
                                                                                    glyphSide * 0.055,
                                                                                    glyphSide * 0.055)]];
            }
        }
    } else if ([icon isEqualToString:@"mouse"] || [icon isEqualToString:@"cursor"]) {
        if ([icon isEqualToString:@"cursor"]) {
            PEMove(fill, glyph, 0.30, 0.18);
            PELine(fill, glyph, 0.30, 0.76);
            PELine(fill, glyph, 0.44, 0.61);
            PELine(fill, glyph, 0.58, 0.84);
            PELine(fill, glyph, 0.69, 0.76);
            PELine(fill, glyph, 0.56, 0.55);
            PELine(fill, glyph, 0.76, 0.52);
            [fill closePath];
        } else {
            [stroke appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.31,
                                                                                   CGRectGetMinY(glyph) + glyphSide * 0.10,
                                                                                   glyphSide * 0.38,
                                                                                   glyphSide * 0.80)
                                                                cornerRadius:glyphSide * 0.19]];
            PEMove(stroke, glyph, 0.50, 0.12);
            PELine(stroke, glyph, 0.50, 0.50);
            PEMove(stroke, glyph, 0.33, 0.50);
            PELine(stroke, glyph, 0.67, 0.50);
            [fill appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.34,
                                                                                CGRectGetMinY(glyph) + glyphSide * 0.13,
                                                                                glyphSide * 0.15,
                                                                                glyphSide * 0.32)
                                                                cornerRadius:glyphSide * 0.07]];
        }
    } else if ([icon isEqualToString:@"attack"]) {
        PEMove(stroke, glyph, 0.22, 0.82);
        PELine(stroke, glyph, 0.72, 0.24);
        PEMove(stroke, glyph, 0.23, 0.82);
        PELine(stroke, glyph, 0.36, 0.68);
        PEMove(stroke, glyph, 0.36, 0.58);
        PELine(stroke, glyph, 0.56, 0.78);
    } else if ([icon isEqualToString:@"place"]) {
        PEMove(stroke, glyph, 0.50, 0.12);
        PELine(stroke, glyph, 0.84, 0.31);
        PELine(stroke, glyph, 0.84, 0.69);
        PELine(stroke, glyph, 0.50, 0.88);
        PELine(stroke, glyph, 0.16, 0.69);
        PELine(stroke, glyph, 0.16, 0.31);
        [stroke closePath];
        PEMove(stroke, glyph, 0.16, 0.31);
        PELine(stroke, glyph, 0.50, 0.50);
        PELine(stroke, glyph, 0.84, 0.31);
        PEMove(stroke, glyph, 0.50, 0.50);
        PELine(stroke, glyph, 0.50, 0.88);
    } else if ([icon isEqualToString:@"shield"]) {
        PEMove(stroke, glyph, 0.50, 0.10);
        PELine(stroke, glyph, 0.82, 0.24);
        PELine(stroke, glyph, 0.78, 0.58);
        PELine(stroke, glyph, 0.50, 0.88);
        PELine(stroke, glyph, 0.22, 0.58);
        PELine(stroke, glyph, 0.18, 0.24);
        [stroke closePath];
    } else if ([icon isEqualToString:@"camera"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.10,
                                                                               CGRectGetMinY(glyph) + glyphSide * 0.30,
                                                                               glyphSide * 0.80,
                                                                               glyphSide * 0.50)
                                                            cornerRadius:glyphSide * 0.10]];
        [stroke appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.35,
                                                                              CGRectGetMinY(glyph) + glyphSide * 0.40,
                                                                              glyphSide * 0.30,
                                                                              glyphSide * 0.30)]];
        PEMove(stroke, glyph, 0.36, 0.30);
        PELine(stroke, glyph, 0.40, 0.20);
        PELine(stroke, glyph, 0.60, 0.20);
        PELine(stroke, glyph, 0.64, 0.30);
    } else if ([icon isEqualToString:@"zoom"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.16,
                                                                              CGRectGetMinY(glyph) + glyphSide * 0.16,
                                                                              glyphSide * 0.50,
                                                                              glyphSide * 0.50)]];
        PEMove(stroke, glyph, 0.62, 0.62);
        PELine(stroke, glyph, 0.86, 0.86);
        PEMove(stroke, glyph, 0.28, 0.41);
        PELine(stroke, glyph, 0.54, 0.41);
        PEMove(stroke, glyph, 0.41, 0.28);
        PELine(stroke, glyph, 0.41, 0.54);
    } else if ([icon isEqualToString:@"debug"]) {
        [stroke appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.28,
                                                                              CGRectGetMinY(glyph) + glyphSide * 0.28,
                                                                              glyphSide * 0.44,
                                                                              glyphSide * 0.44)]];
        for (NSInteger i = 0; i < 8; i++) {
            CGFloat angle = (CGFloat)i * (CGFloat)M_PI / 4.0;
            CGFloat inner = 0.25;
            CGFloat outer = 0.08;
            PEMove(stroke, glyph, 0.50 + cos(angle) * inner, 0.50 + sin(angle) * inner);
            PELine(stroke, glyph, 0.50 + cos(angle) * outer, 0.50 + sin(angle) * outer);
        }
    } else if ([icon isEqualToString:@"list"]) {
        for (NSNumber *y in @[@0.28, @0.50, @0.72]) {
            NSInteger index = [@[@0.28, @0.50, @0.72] indexOfObject:y];
            CGFloat width = index == 1 ? 0.44 : 0.30;
            [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.18,
                                                                               CGRectGetMinY(glyph) + glyphSide * ([y doubleValue] - 0.045),
                                                                               glyphSide * 0.09,
                                                                               glyphSide * 0.09)]];
            PEMove(stroke, glyph, 0.34, [y doubleValue]);
            PELine(stroke, glyph, 0.34 + width, [y doubleValue]);
        }
    } else if ([icon isEqualToString:@"sliders"]) {
        for (NSNumber *y in @[@0.28, @0.50, @0.72]) {
            PEMove(stroke, glyph, 0.18, [y doubleValue]);
            PELine(stroke, glyph, 0.82, [y doubleValue]);
        }
        [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.30,
                                                                            CGRectGetMinY(glyph) + glyphSide * 0.235,
                                                                            glyphSide * 0.11,
                                                                            glyphSide * 0.11)]];
        [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.58,
                                                                            CGRectGetMinY(glyph) + glyphSide * 0.455,
                                                                            glyphSide * 0.11,
                                                                            glyphSide * 0.11)]];
        [fill appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(glyph) + glyphSide * 0.42,
                                                                            CGRectGetMinY(glyph) + glyphSide * 0.675,
                                                                            glyphSide * 0.11,
                                                                            glyphSide * 0.11)]];
    } else if ([icon isEqualToString:@"drawer"]) {
        PEMove(stroke, glyph, 0.22, 0.36);
        PELine(stroke, glyph, 0.50, 0.64);
        PELine(stroke, glyph, 0.78, 0.36);
        PEMove(stroke, glyph, 0.30, 0.76);
        PELine(stroke, glyph, 0.70, 0.76);
    } else if ([icon isEqualToString:@"fly"]) {
        PEMove(stroke, glyph, 0.50, 0.16);
        PELine(stroke, glyph, 0.50, 0.72);
        PEMove(stroke, glyph, 0.22, 0.36);
        PELine(stroke, glyph, 0.50, 0.16);
        PELine(stroke, glyph, 0.78, 0.36);
        PEMove(stroke, glyph, 0.20, 0.66);
        PELine(stroke, glyph, 0.50, 0.82);
        PELine(stroke, glyph, 0.80, 0.66);
    }

    [[UIColor colorWithWhite:0.0 alpha:0.38] setStroke];
    stroke.lineWidth += MAX(1.0, side * 0.025);
    [stroke stroke];
    [[UIColor colorWithWhite:1.0 alpha:0.96] setStroke];
    stroke.lineWidth -= MAX(1.0, side * 0.025);
    [stroke stroke];
    if (fill.bounds.size.width > 0) {
        [[UIColor colorWithWhite:1.0 alpha:0.92] setFill];
        [fill fill];
    }
}

@interface PESkinView : UIView
@property (nonatomic, copy) NSString *icon;
@property (nonatomic) BOOL pressed;
@property (nonatomic) BOOL toggled;
@end

@implementation PESkinView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setIcon:(NSString *)icon {
    _icon = [icon copy];
    [self setNeedsDisplay];
}

- (void)setPressed:(BOOL)pressed {
    _pressed = pressed;
    self.alpha = pressed ? 0.78 : 1.0;
}

- (void)setToggled:(BOOL)toggled {
    _toggled = toggled;
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;
    CGFloat minSide = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (minSide <= 0) return;
    BOOL circle = PEIconIsCircular(self.icon) && PEIsSmallSquare(bounds);
    CGRect box = CGRectInset(bounds, MAX(1.0, minSide * 0.035), MAX(1.0, minSide * 0.035));
    CGFloat radius = circle ? CGRectGetWidth(box) * 0.5 : CGRectGetHeight(box) * 0.28;
    UIBezierPath *shape = circle ? [UIBezierPath bezierPathWithOvalInRect:box]
                                 : [UIBezierPath bezierPathWithRoundedRect:box cornerRadius:radius];

    CGContextSaveGState(context);
    [shape addClip];
    [PEBlack(0.42) setFill];
    [shape fill];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {
        0.98, 0.99, 1.00, self.toggled ? 0.30 : 0.20,
        0.03, 0.04, 0.06, self.toggled ? 0.34 : 0.40,
    };
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, CGRectGetMinY(bounds)), CGPointMake(0, CGRectGetMaxY(bounds)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    UIBezierPath *shine = [UIBezierPath bezierPath];
    PEMove(shine, box, 0.22, 0.13);
    [shine addCurveToPoint:PEPoint(box, 0.78, 0.13) controlPoint1:PEPoint(box, 0.40, 0.02) controlPoint2:PEPoint(box, 0.60, 0.02)];
    shine.lineWidth = MAX(1.0, minSide * 0.035);
    shine.lineCapStyle = kCGLineCapRound;
    [PEWhite(0.34) setStroke];
    [shine stroke];
    CGContextRestoreGState(context);

    shape.lineWidth = MAX(1.0, minSide * 0.022);
    [PEWhite(self.toggled ? 0.92 : 0.62) setStroke];
    [shape stroke];
    CGRect innerBox = CGRectInset(box, shape.lineWidth * 0.75, shape.lineWidth * 0.75);
    UIBezierPath *inner = circle ? [UIBezierPath bezierPathWithOvalInRect:innerBox]
                                 : [UIBezierPath bezierPathWithRoundedRect:innerBox cornerRadius:MAX(0, radius - shape.lineWidth)];
    inner.lineWidth = MAX(0.75, minSide * 0.012);
    [PEBlack(0.28) setStroke];
    [inner stroke];
    PEDrawIcon(self.icon, bounds);
}

@end

@interface PEJoystickSkinView : UIView
@end

@implementation PEJoystickSkinView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;
    CGFloat side = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (side <= 0) return;
    CGRect box = CGRectInset(bounds, side * 0.035, side * 0.035);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:box];
    CGContextSaveGState(context);
    [ring addClip];
    [PEBlack(0.34) setFill];
    [ring fill];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {0.92, 0.98, 1.00, 0.12, 0.02, 0.03, 0.05, 0.34};
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, CGRectGetMinY(bounds)), CGPointMake(0, CGRectGetMaxY(bounds)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(context);
    ring.lineWidth = MAX(1.0, side * 0.025);
    [PEWhite(0.56) setStroke];
    [ring stroke];
    CGFloat innerInset = side * 0.16;
    UIBezierPath *innerRing = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(box, innerInset, innerInset)];
    innerRing.lineWidth = MAX(0.75, side * 0.012);
    [PEWhite(0.18) setStroke];
    [innerRing stroke];
    for (NSInteger i = 0; i < 8; i++) {
        CGFloat angle = (CGFloat)i * (CGFloat)M_PI / 4.0;
        CGFloat inner = 0.40;
        CGFloat outer = 0.47;
        UIBezierPath *tick = [UIBezierPath bezierPath];
        PEMove(tick, box, 0.5 + cos(angle) * inner, 0.5 + sin(angle) * inner);
        PELine(tick, box, 0.5 + cos(angle) * outer, 0.5 + sin(angle) * outer);
        tick.lineWidth = i % 2 == 0 ? MAX(1.0, side * 0.020) : MAX(0.75, side * 0.012);
        [PEWhite(i % 2 == 0 ? 0.42 : 0.24) setStroke];
        [tick stroke];
    }
    UIBezierPath *cross = [UIBezierPath bezierPath];
    PEMove(cross, box, 0.50, 0.45);
    PELine(cross, box, 0.50, 0.55);
    PEMove(cross, box, 0.45, 0.50);
    PELine(cross, box, 0.55, 0.50);
    cross.lineWidth = MAX(1.0, side * 0.018);
    cross.lineCapStyle = kCGLineCapRound;
    [PEWhite(0.30) setStroke];
    [cross stroke];
}

@end

@interface PEThumbSkinView : UIView
@end

@implementation PEThumbSkinView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;
    CGFloat side = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (side <= 0) return;
    CGRect box = CGRectInset(bounds, side * 0.04, side * 0.04);
    UIBezierPath *thumb = [UIBezierPath bezierPathWithOvalInRect:box];
    CGContextSaveGState(context);
    [thumb addClip];
    [PEWhite(0.30) setFill];
    [thumb fill];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {1.00, 1.00, 1.00, 0.38, 0.10, 0.12, 0.16, 0.26};
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, CGRectGetMinY(bounds)), CGPointMake(0, CGRectGetMaxY(bounds)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    UIBezierPath *shine = [UIBezierPath bezierPath];
    PEMove(shine, box, 0.30, 0.24);
    [shine addCurveToPoint:PEPoint(box, 0.66, 0.20) controlPoint1:PEPoint(box, 0.40, 0.12) controlPoint2:PEPoint(box, 0.56, 0.12)];
    shine.lineWidth = MAX(1.0, side * 0.035);
    shine.lineCapStyle = kCGLineCapRound;
    [PEWhite(0.42) setStroke];
    [shine stroke];
    CGContextRestoreGState(context);
    thumb.lineWidth = MAX(1.0, side * 0.040);
    [PEWhite(0.72) setStroke];
    [thumb stroke];
    UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(box, side * 0.36, side * 0.36)];
    [PEWhite(0.18) setFill];
    [dot fill];
}

@end

@interface PETouchFeedback : NSObject
+ (instancetype)shared;
- (void)touchDown:(UIButton *)sender;
- (void)touchUp:(UIButton *)sender;
- (void)touchCancel:(UIButton *)sender;
@end

@implementation PETouchFeedback

+ (instancetype)shared {
    static PETouchFeedback *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (PESkinView *)skinFor:(UIButton *)button {
    return objc_getAssociatedObject(button, PESkinKey);
}

- (void)touchDown:(UIButton *)sender {
    [self skinFor:sender].pressed = YES;
}

- (void)touchUp:(UIButton *)sender {
    PESkinView *skin = [self skinFor:sender];
    skin.pressed = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        id value = [sender respondsToSelector:NSSelectorFromString(@"isToggleOn")] ? [sender valueForKey:@"isToggleOn"] : nil;
        skin.toggled = [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
    });
}

- (void)touchCancel:(UIButton *)sender {
    [self skinFor:sender].pressed = NO;
}

@end

static void PEStyleButton(id button) {
    if ([button isKindOfClass:NSClassFromString(@"ControlJoystick")]) return;
    UIButton *control = (UIButton *)button;
    NSDictionary *properties = [button valueForKey:@"properties"];
    NSString *name = [properties[@"name"] isKindOfClass:[NSString class]] ? properties[@"name"] : @"";
    NSString *icon = PEIconForButton(button);
    PESkinView *skin = objc_getAssociatedObject(button, PESkinKey);
    if (!skin) {
        skin = [[PESkinView alloc] initWithFrame:control.bounds];
        skin.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [control insertSubview:skin atIndex:0];
        objc_setAssociatedObject(button, PESkinKey, skin, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [control addTarget:[PETouchFeedback shared] action:@selector(touchDown:) forControlEvents:UIControlEventTouchDown];
        [control addTarget:[PETouchFeedback shared] action:@selector(touchUp:) forControlEvents:UIControlEventTouchUpInside];
        [control addTarget:[PETouchFeedback shared] action:@selector(touchUp:) forControlEvents:UIControlEventTouchUpOutside];
        [control addTarget:[PETouchFeedback shared] action:@selector(touchCancel:) forControlEvents:UIControlEventTouchCancel];
        [control addTarget:[PETouchFeedback shared] action:@selector(touchDown:) forControlEvents:UIControlEventTouchDragEnter];
        [control addTarget:[PETouchFeedback shared] action:@selector(touchCancel:) forControlEvents:UIControlEventTouchDragExit];
    }
    skin.frame = control.bounds;
    skin.icon = icon;
    skin.toggled = [control respondsToSelector:NSSelectorFromString(@"isToggleOn")] ? [[control valueForKey:@"isToggleOn"] boolValue] : NO;
    control.backgroundColor = UIColor.clearColor;
    control.layer.borderWidth = 0;
    if (icon.length > 0) {
        control.titleLabel.hidden = YES;
        control.accessibilityLabel = name.length > 0 ? name : icon;
    } else {
        control.titleLabel.hidden = NO;
        control.titleLabel.font = [UIFont systemFontOfSize:MIN(MAX(11.0, MIN(CGRectGetWidth(control.bounds), CGRectGetHeight(control.bounds)) * 0.26), 18.0) weight:UIFontWeightSemibold];
        control.titleLabel.layer.shadowColor = UIColor.blackColor.CGColor;
        control.titleLabel.layer.shadowOffset = CGSizeMake(0, 1);
        control.titleLabel.layer.shadowOpacity = 0.55;
        control.titleLabel.layer.shadowRadius = 2;
        [control setTitleColor:PEWhite(0.96) forState:UIControlStateNormal];
        control.accessibilityLabel = name;
    }
    [skin setNeedsDisplay];
}

static void PEStyleJoystick(id joystick) {
    UIView *control = (UIView *)joystick;
    control.backgroundColor = UIColor.clearColor;
    control.layer.borderWidth = 0;
    UIView *background = [joystick valueForKey:@"background"];
    UIView *thumb = [joystick valueForKey:@"thumb"];
    UIView *forwardLock = [joystick valueForKey:@"fwdLockView"];
    if (background) {
        background.backgroundColor = UIColor.clearColor;
        background.layer.borderWidth = 0;
        PEJoystickSkinView *outer = objc_getAssociatedObject(background, PEOuterKey);
        if (!outer) {
            outer = [[PEJoystickSkinView alloc] initWithFrame:background.bounds];
            outer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [background insertSubview:outer atIndex:0];
            objc_setAssociatedObject(background, PEOuterKey, outer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        outer.frame = background.bounds;
        [outer setNeedsDisplay];
    }
    if (thumb) {
        thumb.backgroundColor = UIColor.clearColor;
        thumb.layer.borderWidth = 0;
        PEThumbSkinView *inner = objc_getAssociatedObject(thumb, PEThumbKey);
        if (!inner) {
            inner = [[PEThumbSkinView alloc] initWithFrame:thumb.bounds];
            inner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [thumb insertSubview:inner atIndex:0];
            objc_setAssociatedObject(thumb, PEThumbKey, inner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        inner.frame = thumb.bounds;
        [inner setNeedsDisplay];
    }
    if (forwardLock) {
        forwardLock.backgroundColor = PEBlack(0.54);
        forwardLock.layer.borderColor = PEWhite(0.62).CGColor;
        forwardLock.layer.borderWidth = MAX(1.0, MIN(CGRectGetWidth(forwardLock.bounds), CGRectGetHeight(forwardLock.bounds)) * 0.05);
    }
}

static void PEButtonUpdate(id self, SEL _cmd) {
    if (PEOriginalButtonUpdate) ((void (*)(id, SEL))PEOriginalButtonUpdate)(self, _cmd);
    PEStyleButton(self);
}

static void PEJoystickUpdate(id self, SEL _cmd) {
    if (PEOriginalJoystickUpdate) ((void (*)(id, SEL))PEOriginalJoystickUpdate)(self, _cmd);
    PEStyleJoystick(self);
}

static BOOL PEHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_getImplementation(method);
    class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
    return YES;
}

static BOOL PEInstallHooks(const WitchPluginHostAPI *host) {
    if (PEHooksInstalled) return YES;
    Class buttonClass = NSClassFromString(@"ControlButton");
    Class joystickClass = NSClassFromString(@"ControlJoystick");
    if (!buttonClass) {
        host->log(host->userdata, "PE Controls: ControlButton class is unavailable");
        return NO;
    }
    if (!PEHook(buttonClass, NSSelectorFromString(@"update"), (IMP)PEButtonUpdate, &PEOriginalButtonUpdate)) {
        host->log(host->userdata, "PE Controls: ControlButton update is unavailable");
        return NO;
    }
    if (joystickClass) {
        PEHook(joystickClass, NSSelectorFromString(@"update"), (IMP)PEJoystickUpdate, &PEOriginalJoystickUpdate);
    }
    PEHooksInstalled = YES;
    host->log(host->userdata, "PE Controls: control hooks installed");
    return YES;
}

__attribute__((visibility("default")))
int witch_plugin_init(const WitchPluginHostAPI *host) {
    if (!host || host->abi_version != WITCH_PLUGIN_ABI_VERSION) return 1;
    return PEInstallHooks(host) ? 0 : 1;
}
