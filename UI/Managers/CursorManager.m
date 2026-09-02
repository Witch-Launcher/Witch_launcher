#import "CursorManager.h"
#import "LauncherPreferences.h"
#import <ImageIO/ImageIO.h>
#import <string.h>

static NSString *const kCursorsDirName = @"cursors";
static NSString *const kDefaultCursorName = @"default";
static NSString *const kCurrentCursorPrefKey = @"control.virtmouse_cursor";
static NSString *const kHitboxFileName = @"hitbox.json";

static NSString *const kImagePngName = @"image.png";
static NSString *const kImageGifName = @"image.gif";

@implementation CursorManager

+ (NSString *)cursorsDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [documents stringByAppendingPathComponent:kCursorsDirName];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSString *)defaultCursorName {
    return kDefaultCursorName;
}

+ (BOOL)isDefaultCursor:(NSString *)name {
    return [name isEqualToString:kDefaultCursorName];
}

+ (NSString *)cursorPathForName:(NSString *)name {
    return [self.cursorsDirectory stringByAppendingPathComponent:name];
}

+ (NSArray<NSString *> *)cursorNames {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *content = [fm contentsOfDirectoryAtPath:self.cursorsDirectory error:nil];
    NSMutableArray *names = [NSMutableArray arrayWithObject:kDefaultCursorName];
    for (NSString *item in content) {
        if ([item hasPrefix:@"."]) continue;
        if ([item isEqualToString:kDefaultCursorName]) continue;
        BOOL isDir = NO;
        NSString *full = [self.cursorsDirectory stringByAppendingPathComponent:item];
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            [names addObject:item];
        }
    }
    return names;
}

+ (NSString *)currentCursorName {
    id name = getPrefObject(kCurrentCursorPrefKey);
    if (![name isKindOfClass:NSString.class] || [name length] == 0) {
        return kDefaultCursorName;
    }
    return name;
}

+ (void)setCurrentCursorName:(NSString *)name {
    setPrefObject(kCurrentCursorPrefKey, name);
}

#pragma mark - Image

// The actual image file name stored in a cursor folder.
+ (NSString *)imageFileNameForCursor:(NSString *)name {
    NSString *dir = [self cursorPathForName:name];
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:[dir stringByAppendingPathComponent:kImageGifName]]) {
        return kImageGifName;
    }
    return kImagePngName;
}

+ (NSString *)imagePathForCursor:(NSString *)name {
    return [[self cursorPathForName:name] stringByAppendingPathComponent:[self imageFileNameForCursor:name]];
}

+ (UIImage *)imageForCursor:(NSString *)name {
    if ([self isDefaultCursor:name]) {
        return [self defaultCursorImage];
    }
    NSString *path = [self imagePathForCursor:name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    }
    return [self defaultCursorImage];
}

+ (UIImage *)defaultCursorImage {
    // Load asset catalog image at device screen scale for 1:1 native pixel rendering
    UIImage *baseImage = [UIImage imageNamed:@"MousePointer"];
    if (baseImage && baseImage.CGImage) {
        return [UIImage imageWithCGImage:baseImage.CGImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    }
    return baseImage;
}

+ (void)saveImageData:(NSData *)data isGIF:(BOOL)isGIF forCursor:(NSString *)name {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileName = isGIF ? kImageGifName : kImagePngName;
    [data writeToFile:[dir stringByAppendingPathComponent:fileName] atomically:YES];
}

#pragma mark - Hitbox

+ (NSString *)hitboxPathForCursor:(NSString *)name {
    return [[self cursorPathForName:name] stringByAppendingPathComponent:kHitboxFileName];
}

+ (CGPoint)hitboxForCursor:(NSString *)name {
    NSString *path = [self hitboxPathForCursor:name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if ([name isEqualToString:@"default"]) {
            // Default arrow cursor: hotspot at tip of arrow (MousePointer asset coordinates)
            CGFloat scale = [UIScreen mainScreen].scale;
            return CGPointMake(80.0 / scale, 120.0 / scale);
        }
        return CGPointZero;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) return CGPointZero;
    return CGPointMake([json[@"x"] floatValue], [json[@"y"] floatValue]);
}

+ (void)setHitboxForCursor:(NSString *)name hitbox:(CGPoint)hitbox {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *path = [dir stringByAppendingPathComponent:kHitboxFileName];
    NSDictionary *json = @{@"x": @(roundf(hitbox.x)), @"y": @(roundf(hitbox.y))};
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    [data writeToFile:path atomically:YES];
}

#pragma mark - Delete

+ (BOOL)deleteCursor:(NSString *)name {
    if ([self isDefaultCursor:name]) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name];
    if (![fm fileExistsAtPath:dir]) return NO;
    return [fm removeItemAtPath:dir error:nil];
}

#pragma mark - Import

+ (NSString *)sanitizedName:(NSString *)name {
    if (!name || name.length == 0) name = @"Cursor";
    NSMutableCharacterSet *illegal = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    NSString *cleaned = [[name componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@"-"];
    cleaned = [cleaned stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return cleaned.length ? cleaned : @"Cursor";
}

+ (NSString *)uniqueCursorNameFor:(NSString *)name {
    NSString *base = [self sanitizedName:name];
    NSString *candidate = base;
    NSArray *existing = [self cursorNames];
    NSInteger i = 2;
    while ([existing containsObject:candidate]) {
        candidate = [NSString stringWithFormat:@"%@-%ld", base, (long)i++];
    }
    return candidate;
}

+ (NSString *)importCursorFromURL:(NSURL *)url withName:(NSString *)name error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return nil;
    return [self importCursorFromData:data withName:name error:error];
}

+ (NSString *)importCursorFromImage:(UIImage *)image withName:(NSString *)name error:(NSError **)error {
    NSData *png = UIImagePNGRepresentation(image);
    if (!png) {
        if (error) *error = [NSError errorWithDomain:@"CursorManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert image"}];
        return nil;
    }
    return [self importCursorFromData:png withName:name error:error];
}

+ (NSString *)importCursorFromData:(NSData *)data withName:(NSString *)name error:(NSError **)error {
    NSString *cursor = [self uniqueCursorNameFor:name];
    BOOL isGIF = [self isAnimatedGIFData:data];
    if (!isGIF) {
        UIImage *img = [UIImage imageWithData:data];
        if (!img) {
            if (error) *error = [NSError errorWithDomain:@"CursorManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported image format"}];
            return nil;
        }
        NSData *png = UIImagePNGRepresentation(img);
        data = png ?: data;
    }
    [self saveImageData:data isGIF:isGIF forCursor:cursor];
    return cursor;
}

+ (BOOL)isAnimatedGIFData:(NSData *)data {
    if (data.length < 6) return NO;
    const char *bytes = (const char *)data.bytes;
    return memcmp(bytes, "GIF8", 4) == 0;
}

+ (BOOL)isAnimatedData:(NSData *)data {
    return [self isAnimatedGIFData:data];
}

#pragma mark - Display

+ (CGFloat)displayScaleForImage:(UIImage *)image mouseScale:(CGFloat)mouseScale isCustomCursor:(BOOL)isCustom {
    if (!image) return mouseScale;
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    if (w <= 0 || h <= 0) return mouseScale;
    
    if (isCustom) {
        // For custom cursors, preserve aspect ratio and scale to a reasonable size
        // Target: max dimension of 32pt * mouseScale (similar to default cursor size)
        CGFloat maxDimension = 32.0 * mouseScale;
        CGFloat scale = maxDimension / MAX(w, h);
        return scale;
    } else {
        // Default pointer rendered at 18x27 with scale=1; keep height same as default (27 * mouseScale)
        return (27.0 * mouseScale) / h;
    }
}

+ (CGRect)displayFrameForMouseFrame:(CGRect)mouseFrame {
    NSString *name = self.currentCursorName;
    UIImage *image = [self imageForCursor:name];
    CGPoint hitbox = [self hitboxForCursor:name];

    CGFloat mouseScale = getPrefFloat(@"control.mouse_scale") / 100.0;
    BOOL isCustom = ![self isDefaultCursor:name];
    CGFloat scale = [self displayScaleForImage:image mouseScale:mouseScale isCustomCursor:isCustom];
    CGSize displaySize = CGSizeMake(image.size.width * scale, image.size.height * scale);

    CGFloat imgW = MAX(image.size.width, 1);
    CGFloat imgH = MAX(image.size.height, 1);
    CGFloat dispX = (hitbox.x / imgW) * displaySize.width;
    CGFloat dispY = (hitbox.y / imgH) * displaySize.height;

    CGRect frame = mouseFrame;
    frame.origin.x -= dispX;
    frame.origin.y -= dispY;
    frame.size = displaySize;
    return frame;
}

+ (CGRect)displayFrameForMouseFrame:(CGRect)mouseFrame typeId:(NSString *)typeId {
    NSString *cursorName = [self currentCursorForType:typeId];
    UIImage *image = [self compositeImageForType:typeId];
    CGPoint hitbox = [self hitboxForCursor:cursorName inType:typeId];

    CGFloat mouseScale = getPrefFloat(@"control.mouse_scale") / 100.0;
    BOOL isCustom = ![self isDefaultCursor:cursorName];
    CGFloat scale = [self displayScaleForImage:image mouseScale:mouseScale isCustomCursor:isCustom];
    CGSize displaySize = CGSizeMake(image.size.width * scale, image.size.height * scale);

    CGFloat imgW = MAX(image.size.width, 1);
    CGFloat imgH = MAX(image.size.height, 1);
    CGFloat dispX = (hitbox.x / imgW) * displaySize.width;
    CGFloat dispY = (hitbox.y / imgH) * displaySize.height;

    CGRect frame = mouseFrame;
    frame.origin.x -= dispX;
    frame.origin.y -= dispY;
    frame.size = displaySize;
    return frame;
}

+ (CGRect)mouseFrameForDisplayFrame:(CGRect)displayFrame {
    NSString *name = self.currentCursorName;
    UIImage *image = [self imageForCursor:name];
    CGPoint hitbox = [self hitboxForCursor:name];

    CGFloat imgW = MAX(image.size.width, 1);
    CGFloat imgH = MAX(image.size.height, 1);
    CGFloat dispX = (hitbox.x / imgW) * displayFrame.size.width;
    CGFloat dispY = (hitbox.y / imgH) * displayFrame.size.height;

    CGRect frame = displayFrame;
    frame.origin.x += dispX;
    frame.origin.y += dispY;
    return frame;
}

+ (CGRect)mouseFrameForDisplayFrame:(CGRect)displayFrame typeId:(NSString *)typeId {
    NSString *cursorName = [self currentCursorForType:typeId];
    UIImage *image = [self compositeImageForType:typeId];
    CGPoint hitbox = [self hitboxForCursor:cursorName inType:typeId];

    CGFloat imgW = MAX(image.size.width, 1);
    CGFloat imgH = MAX(image.size.height, 1);
    CGFloat dispX = (hitbox.x / imgW) * displayFrame.size.width;
    CGFloat dispY = (hitbox.y / imgH) * displayFrame.size.height;

    CGRect frame = displayFrame;
    frame.origin.x += dispX;
    frame.origin.y += dispY;
    return frame;
}

#pragma mark - Per-type cursor pool

static NSString *const kCursorTypesDirName = @"cursor_types";

+ (NSString *)cursorTypesRootDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [documents stringByAppendingPathComponent:kCursorTypesDirName];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSString *)cursorsDirectoryForType:(NSString *)typeId {
    NSString *path = [[self cursorTypesRootDirectory] stringByAppendingPathComponent:typeId];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSString *)cursorPathForName:(NSString *)name inType:(NSString *)typeId {
    return [[self cursorsDirectoryForType:typeId] stringByAppendingPathComponent:name];
}

+ (NSArray<NSString *> *)cursorNamesForType:(NSString *)typeId {
    NSString *dir = [self cursorsDirectoryForType:typeId];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *content = [fm contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *names = [NSMutableArray arrayWithObject:kDefaultCursorName];
    for (NSString *item in content) {
        if ([item hasPrefix:@"."]) continue;
        if ([item isEqualToString:kDefaultCursorName]) continue;
        BOOL isDir = NO;
        NSString *full = [dir stringByAppendingPathComponent:item];
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            [names addObject:item];
        }
    }
    return names;
}

+ (NSString *)currentCursorForType:(NSString *)typeId {
    NSString *prefKey = [NSString stringWithFormat:@"control.cursortype_%@_cursor", typeId];
    id name = getPrefObject(prefKey);
    if (![name isKindOfClass:NSString.class] || [name length] == 0) {
        return kDefaultCursorName;
    }
    return name;
}

+ (void)setCurrentCursor:(NSString *)cursorName forType:(NSString *)typeId {
    NSString *prefKey = [NSString stringWithFormat:@"control.cursortype_%@_cursor", typeId];
    setPrefObject(prefKey, cursorName);
}

+ (NSString *)imageFileNameForCursor:(NSString *)name inType:(NSString *)typeId {
    NSString *dir = [self cursorPathForName:name inType:typeId];
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:[dir stringByAppendingPathComponent:kImageGifName]]) {
        return kImageGifName;
    }
    return kImagePngName;
}

+ (NSString *)imagePathForCursor:(NSString *)name inType:(NSString *)typeId {
    return [[self cursorPathForName:name inType:typeId] stringByAppendingPathComponent:[self imageFileNameForCursor:name inType:typeId]];
}

+ (UIImage *)imageForCursor:(NSString *)name inType:(NSString *)typeId {
    if ([self isDefaultCursor:name]) {
        return [self defaultCursorImage];
    }
    NSString *path = [self imagePathForCursor:name inType:typeId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    }
    return [self defaultCursorImage];
}

+ (CGPoint)hitboxForCursor:(NSString *)name inType:(NSString *)typeId {
    NSString *path = [[self cursorPathForName:name inType:typeId] stringByAppendingPathComponent:kHitboxFileName];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if ([name isEqualToString:@"default"]) {
            // Hitbox defaults for the generated shape images (32×32 points)
            // Arrow tip position matches the drawn arrow shape
            if ([typeId isEqualToString:@"normal"] || [typeId isEqualToString:@"working"]) {
                return CGPointMake(7, 5);
            }
            if ([typeId isEqualToString:@"link"]) {
                return CGPointMake(10, 12);
            }
            if ([typeId isEqualToString:@"text"]) {
                return CGPointMake(16, 16);
            }
            if ([typeId isEqualToString:@"precision"] || [typeId isEqualToString:@"crosshair"]) {
                return CGPointMake(16, 16);
            }
            if ([typeId isEqualToString:@"busy"]) {
                return CGPointMake(16, 16);
            }
            if ([typeId isEqualToString:@"help"]) {
                return CGPointMake(7, 5);
            }
            return CGPointMake(16, 16);
        }
        // Custom cursor without a hitbox: default to top-left corner
        return CGPointZero;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) return CGPointZero;
    return CGPointMake([json[@"x"] floatValue], [json[@"y"] floatValue]);
}

+ (void)setHitboxForCursor:(NSString *)name hitbox:(CGPoint)hitbox inType:(NSString *)typeId {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name inType:typeId];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *path = [dir stringByAppendingPathComponent:kHitboxFileName];
    NSDictionary *json = @{@"x": @(roundf(hitbox.x)), @"y": @(roundf(hitbox.y))};
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    [data writeToFile:path atomically:YES];
}

+ (BOOL)deleteCursor:(NSString *)name inType:(NSString *)typeId {
    if ([self isDefaultCursor:name]) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name inType:typeId];
    if (![fm fileExistsAtPath:dir]) return NO;
    return [fm removeItemAtPath:dir error:nil];
}

+ (NSString *)uniqueCursorName:(NSString *)name forType:(NSString *)typeId {
    NSString *base = [self sanitizedName:name];
    NSString *candidate = base;
    NSArray *existing = [self cursorNamesForType:typeId];
    NSInteger i = 2;
    while ([existing containsObject:candidate]) {
        candidate = [NSString stringWithFormat:@"%@-%ld", base, (long)i++];
    }
    return candidate;
}

+ (void)saveImageData:(NSData *)data isGIF:(BOOL)isGIF forCursor:(NSString *)name inType:(NSString *)typeId {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [self cursorPathForName:name inType:typeId];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileName = isGIF ? kImageGifName : kImagePngName;
    [data writeToFile:[dir stringByAppendingPathComponent:fileName] atomically:YES];
}

+ (NSString *)importCursorFromData:(NSData *)data withName:(NSString *)name forType:(NSString *)typeId error:(NSError **)error {
    NSString *cursor = [self uniqueCursorName:name forType:typeId];
    BOOL isGIF = [self isAnimatedGIFData:data];
    if (!isGIF) {
        UIImage *img = [UIImage imageWithData:data];
        if (!img) {
            if (error) *error = [NSError errorWithDomain:@"CursorManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported image format"}];
            return nil;
        }
        NSData *png = UIImagePNGRepresentation(img);
        data = png ?: data;
    }
    [self saveImageData:data isGIF:isGIF forCursor:cursor inType:typeId];
    return cursor;
}

+ (NSString *)importCursorFromURL:(NSURL *)url withName:(NSString *)name forType:(NSString *)typeId error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return nil;
    return [self importCursorFromData:data withName:name forType:typeId error:error];
}

+ (NSString *)importCursorFromImage:(UIImage *)image withName:(NSString *)name forType:(NSString *)typeId error:(NSError **)error {
    NSData *png = UIImagePNGRepresentation(image);
    if (!png) {
        if (error) *error = [NSError errorWithDomain:@"CursorManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert image"}];
        return nil;
    }
    return [self importCursorFromData:png withName:name forType:typeId error:error];
}

#pragma mark - Cursor shape images (drawn at high resolution with Core Graphics)

static NSMutableDictionary<NSString *, UIImage *> *_shapeImageCache;

+ (void)initialize {
    if (self == [CursorManager class]) {
        _shapeImageCache = [NSMutableDictionary dictionary];
    }
}

+ (UIImage *)defaultShapeImageForType:(NSString *)typeId {
    UIImage *cached = _shapeImageCache[typeId];
    if (cached) return cached;

    UIImage *img = [self generateDefaultShapeForType:typeId];
    if (img) _shapeImageCache[typeId] = img;
    return img;
}

+ (UIImage *)generateDefaultShapeForType:(NSString *)typeId {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize canvas = CGSizeMake(32, 32);
    UIGraphicsBeginImageContextWithOptions(canvas, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, CGRectMake(0, 0, 32, 32));
    // Windows Aero shadow - soft drop shadow like Windows 10
    CGContextSetShadowWithColor(ctx, CGSizeMake(1.0, 1.0), 1.5, [UIColor colorWithWhite:0 alpha:0.45].CGColor);

    UIColor *fill = [UIColor whiteColor];
    UIColor *stroke = [UIColor blackColor];
    CGFloat strokeWidth = 1.4;

    if ([typeId isEqualToString:@"normal"] || [typeId isEqualToString:@"working"]) {
        // Windows 10 Aero Arrow - exact polygon from Wikimedia Commons (public domain, 32x32-32.svg)
        // Original viewBox 36.67x56.16, points: 18.64 55.17, 11.5 38.49, .75 49.08, .75 1.81, 34.88 35.94, 18.57 36.14, 25.83 51.91
        // Scale to fit 32x32 with padding, tip at (7,5) matches hitbox (7,5) for normal
        CGFloat s = 0.48; // scale to fit 53px height -> 25.6 + 5 tip = 30.6 <32
        CGFloat tx = 7 - 0.75*s;
        CGFloat ty = 5 - 1.81*s;
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(18.64*s+tx, 55.17*s+ty)];
        [path addLineToPoint:CGPointMake(11.5*s+tx, 38.49*s+ty)];
        [path addLineToPoint:CGPointMake(0.75*s+tx, 49.08*s+ty)];
        [path addLineToPoint:CGPointMake(0.75*s+tx, 1.81*s+ty)];
        [path addLineToPoint:CGPointMake(34.88*s+tx, 35.94*s+ty)];
        [path addLineToPoint:CGPointMake(18.57*s+tx, 36.14*s+ty)];
        [path addLineToPoint:CGPointMake(25.83*s+tx, 51.91*s+ty)];
        [path closePath];
        path.lineJoinStyle = kCGLineJoinMiter;
        path.lineCapStyle = kCGLineCapButt;
        [stroke setStroke];
        path.lineWidth = strokeWidth;
        [path stroke];
        [fill setFill];
        [path fill];
        // Inner highlight subtle (Windows aero has soft highlight on left edge)
        UIBezierPath *hi = [UIBezierPath bezierPath];
        [hi moveToPoint:CGPointMake(1.5*s+tx, 3.5*s+ty)];
        [hi addLineToPoint:CGPointMake(1.5*s+tx, 46*s+ty)];
        hi.lineWidth = 0.6;
        hi.lineCapStyle = kCGLineCapRound;
        [[UIColor colorWithWhite:1 alpha:0.35] setStroke];
        [hi stroke];
        if ([typeId isEqualToString:@"working"]) {
            // Windows Working In Background: arrow + small blue spinner badge
            CGRect badge = CGRectMake(18, 18, 11, 11);
            UIBezierPath *bg = [UIBezierPath bezierPathWithOvalInRect:badge];
            [[UIColor whiteColor] setFill]; [bg fill];
            [[UIColor blackColor] setStroke]; bg.lineWidth = 1.1; [bg stroke];
            // Blue spinner (Windows busy is blue)
            UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(23.5, 23.5) radius:3.3 startAngle:-M_PI_2 endAngle:M_PI*0.85 clockwise:YES];
            arc.lineWidth = 1.4;
            arc.lineCapStyle = kCGLineCapRound;
            [[UIColor colorWithRed:0.0 green:0.47 blue:0.84 alpha:1] setStroke];
            [arc stroke];
        }
    } else if ([typeId isEqualToString:@"link"]) {
        // Windows Aero Hand - white hand with black outline, like Windows 10
        // Palm + fingers, index extended
        UIBezierPath *palm = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 13.5, 12.5, 9.5) cornerRadius:3.2];
        [fill setFill]; [palm fill]; [stroke setStroke]; palm.lineWidth = strokeWidth; [palm stroke];
        // Index finger extended up
        UIBezierPath *index = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(10.2, 4.5, 2.8, 11) cornerRadius:1.4];
        [fill setFill]; [index fill]; [stroke setStroke]; index.lineWidth = 1.1; [index stroke];
        // Middle finger
        UIBezierPath *mid = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.4, 7.2, 2.8, 8.2) cornerRadius:1.4];
        [fill setFill]; [mid fill]; [stroke setStroke]; mid.lineWidth = 1.1; [mid stroke];
        // Ring finger
        UIBezierPath *ring = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(16.6, 8.0, 2.8, 7.4) cornerRadius:1.4];
        [fill setFill]; [ring fill]; [stroke setStroke]; ring.lineWidth = 1.1; [ring stroke];
        // Pinky
        UIBezierPath *pinky = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(19.8, 9.2, 2.4, 6.2) cornerRadius:1.2];
        [fill setFill]; [pinky fill]; [stroke setStroke]; pinky.lineWidth = 1.1; [pinky stroke];
        // Thumb
        UIBezierPath *thumb = [UIBezierPath bezierPath];
        [thumb moveToPoint:CGPointMake(9, 15.5)];
        [thumb addQuadCurveToPoint:CGPointMake(5.5, 11) controlPoint:CGPointMake(5.2, 14)];
        [thumb addLineToPoint:CGPointMake(7.2, 9.5)];
        [thumb addQuadCurveToPoint:CGPointMake(9.8, 13.2) controlPoint:CGPointMake(8.2, 11.2)];
        [thumb closePath];
        [fill setFill]; [thumb fill]; [stroke setStroke]; thumb.lineWidth = 1.1; [thumb stroke];
    } else if ([typeId isEqualToString:@"text"]) {
        // Windows I-beam - thin vertical with caps, classic Windows text cursor
        CGFloat cx=16, cy=16;
        CGFloat h=16, w=1.6, capW=8, capH=1.4;
        // Vertical stem
        UIBezierPath *stem = [UIBezierPath bezierPathWithRect:CGRectMake(cx - w/2, cy - h/2, w, h)];
        [fill setFill]; [stem fill]; [stroke setStroke]; stem.lineWidth = 1.0; [stem stroke];
        // Top cap
        UIBezierPath *top = [UIBezierPath bezierPathWithRect:CGRectMake(cx - capW/2, cy - h/2, capW, capH)];
        [fill setFill]; [top fill]; [stroke setStroke]; top.lineWidth = 1.0; [top stroke];
        // Bottom cap
        UIBezierPath *bot = [UIBezierPath bezierPathWithRect:CGRectMake(cx - capW/2, cy + h/2 - capH, capW, capH)];
        [fill setFill]; [bot fill]; [stroke setStroke]; bot.lineWidth = 1.0; [bot stroke];
    } else if ([typeId isEqualToString:@"precision"] || [typeId isEqualToString:@"crosshair"]) {
        // Windows Precision - crosshair with thin lines and center dot, Windows style is simple cross
        CGFloat cx=16, cy=16;
        CGFloat len=10, thick=1.0, gap=2.8;
        UIBezierPath *cross = [UIBezierPath bezierPath];
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - len, cy - thick/2, len - gap, thick)]];
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx + gap, cy - thick/2, len - gap, thick)]];
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - thick/2, cy - len, thick, len - gap)]];
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - thick/2, cy + gap, thick, len - gap)]];
        [[UIColor blackColor] setFill]; [cross fill];
        // White inner for contrast
        // Center dot small
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx-0.9, cy-0.9, 1.8, 1.8)];
        [[UIColor whiteColor] setFill]; [dot fill];
    } else if ([typeId isEqualToString:@"busy"]) {
        // Windows Busy - blue spinning circle (Aero busy is blue)
        CGFloat cx=16, cy=16, r=8.5;
        // Outer circle thin
        UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r startAngle:-M_PI_2 endAngle:M_PI*1.4 clockwise:YES];
        circle.lineWidth = 2.6;
        circle.lineCapStyle = kCGLineCapRound;
        [[UIColor colorWithRed:0.0 green:0.47 blue:0.84 alpha:1] setStroke];
        [circle stroke];
        // Black outline for visibility
        UIBezierPath *outline = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r startAngle:-M_PI_2 endAngle:M_PI*1.4 clockwise:YES];
        outline.lineWidth = 3.6;
        [[UIColor blackColor] setStroke];
        outline.lineCapStyle = kCGLineCapRound;
        [outline stroke];
        // Blue on top again
        [circle stroke];
        // Arrow head
        CGFloat angle = M_PI*1.4;
        CGPoint p = CGPointMake(cx + r*cos(angle), cy + r*sin(angle));
        CGFloat ah = 3.4;
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:p];
        [arrow addLineToPoint:CGPointMake(p.x - ah*cos(angle - M_PI/6), p.y - ah*sin(angle - M_PI/6))];
        [arrow addLineToPoint:CGPointMake(p.x - ah*cos(angle + M_PI/6), p.y - ah*sin(angle + M_PI/6))];
        [arrow closePath];
        [[UIColor colorWithRed:0.0 green:0.47 blue:0.84 alpha:1] setFill]; [arrow fill];
        [[UIColor blackColor] setStroke]; arrow.lineWidth = 0.9; [arrow stroke];
    } else if ([typeId isEqualToString:@"unavailable"]) {
        // Windows Unavailable - red circle slash, Windows style
        CGFloat cx=16, cy=16, r=10;
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx-r, cy-r, r*2, r*2)];
        circle.lineWidth = 1.8;
        [[UIColor whiteColor] setFill]; [circle fill];
        [[UIColor blackColor] setStroke]; [circle stroke];
        UIBezierPath *slash = [UIBezierPath bezierPath];
        [slash moveToPoint:CGPointMake(cx - r*0.7, cy - r*0.7)];
        [slash addLineToPoint:CGPointMake(cx + r*0.7, cy + r*0.7)];
        slash.lineWidth = 2.4;
        slash.lineCapStyle = kCGLineCapRound;
        [[UIColor colorWithRed:0.90 green:0.12 blue:0.12 alpha:1] setStroke];
        [slash stroke];
        // Black outline for slash
        UIBezierPath *slashBack = [UIBezierPath bezierPath];
        [slashBack moveToPoint:CGPointMake(cx - r*0.7, cy - r*0.7)];
        [slashBack addLineToPoint:CGPointMake(cx + r*0.7, cy + r*0.7)];
        slashBack.lineWidth = 3.6;
        [[UIColor blackColor] setStroke];
        [slashBack stroke];
        [slash stroke];
    } else if ([typeId isEqualToString:@"vresize"]) {
        // Windows Vertical Resize - two vertical arrows, Windows style is simple thin arrows
        CGFloat cx=16, cy=16;
        // Use simple triangle arrows with stem
        UIBezierPath *up = [UIBezierPath bezierPath];
        [up moveToPoint:CGPointMake(cx, cy - 10)];
        [up addLineToPoint:CGPointMake(cx - 4, cy - 4)];
        [up addLineToPoint:CGPointMake(cx - 1.5, cy - 4)];
        [up addLineToPoint:CGPointMake(cx - 1.5, cy - 1.5)];
        [up addLineToPoint:CGPointMake(cx + 1.5, cy - 1.5)];
        [up addLineToPoint:CGPointMake(cx + 1.5, cy - 4)];
        [up addLineToPoint:CGPointMake(cx + 4, cy - 4)];
        [up closePath];
        UIBezierPath *down = [UIBezierPath bezierPath];
        [down moveToPoint:CGPointMake(cx, cy + 10)];
        [down addLineToPoint:CGPointMake(cx - 4, cy + 4)];
        [down addLineToPoint:CGPointMake(cx - 1.5, cy + 4)];
        [down addLineToPoint:CGPointMake(cx - 1.5, cy + 1.5)];
        [down addLineToPoint:CGPointMake(cx + 1.5, cy + 1.5)];
        [down addLineToPoint:CGPointMake(cx + 1.5, cy + 4)];
        [down addLineToPoint:CGPointMake(cx + 4, cy + 4)];
        [down closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:up]; [all appendPath:down];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; [all stroke];
    } else if ([typeId isEqualToString:@"hresize"]) {
        CGFloat cx=16, cy=16;
        UIBezierPath *left = [UIBezierPath bezierPath];
        [left moveToPoint:CGPointMake(cx - 10, cy)];
        [left addLineToPoint:CGPointMake(cx - 4, cy - 4)];
        [left addLineToPoint:CGPointMake(cx - 4, cy - 1.5)];
        [left addLineToPoint:CGPointMake(cx - 1.5, cy - 1.5)];
        [left addLineToPoint:CGPointMake(cx - 1.5, cy + 1.5)];
        [left addLineToPoint:CGPointMake(cx - 4, cy + 1.5)];
        [left addLineToPoint:CGPointMake(cx - 4, cy + 4)];
        [left closePath];
        UIBezierPath *right = [UIBezierPath bezierPath];
        [right moveToPoint:CGPointMake(cx + 10, cy)];
        [right addLineToPoint:CGPointMake(cx + 4, cy - 4)];
        [right addLineToPoint:CGPointMake(cx + 4, cy - 1.5)];
        [right addLineToPoint:CGPointMake(cx + 1.5, cy - 1.5)];
        [right addLineToPoint:CGPointMake(cx + 1.5, cy + 1.5)];
        [right addLineToPoint:CGPointMake(cx + 4, cy + 1.5)];
        [right addLineToPoint:CGPointMake(cx + 4, cy + 4)];
        [right closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:left]; [all appendPath:right];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; [all stroke];
    } else if ([typeId isEqualToString:@"diagonal"]) {
        // Windows Diagonal Resize - NW-SE arrows
        UIBezierPath *a1 = [UIBezierPath bezierPath];
        [a1 moveToPoint:CGPointMake(8, 8)];
        [a1 addLineToPoint:CGPointMake(14, 8)];
        [a1 addLineToPoint:CGPointMake(14, 10.2)];
        [a1 addLineToPoint:CGPointMake(11.2, 11)];
        [a1 addLineToPoint:CGPointMake(10, 14)];
        [a1 addLineToPoint:CGPointMake(8, 14)];
        [a1 closePath];
        UIBezierPath *a2 = [UIBezierPath bezierPath];
        [a2 moveToPoint:CGPointMake(24, 24)];
        [a2 addLineToPoint:CGPointMake(18, 24)];
        [a2 addLineToPoint:CGPointMake(18, 21.8)];
        [a2 addLineToPoint:CGPointMake(20.8, 21)];
        [a2 addLineToPoint:CGPointMake(22, 18)];
        [a2 addLineToPoint:CGPointMake(24, 18)];
        [a2 closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:a1]; [all appendPath:a2];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; [all stroke];
        UIBezierPath *line = [UIBezierPath bezierPath];
        [line moveToPoint:CGPointMake(10, 10)];
        [line addLineToPoint:CGPointMake(22, 22)];
        line.lineWidth = 1.2;
        [[UIColor blackColor] setStroke]; [line stroke];
        [[UIColor whiteColor] setStroke]; line.lineWidth = 0.6; [line stroke];
    } else if ([typeId isEqualToString:@"move"]) {
        // Windows Move - four arrows, Windows style is simple
        CGFloat cx=16, cy=16;
        CGFloat ah=5, aw=5;
        UIBezierPath *up = [UIBezierPath bezierPath];
        [up moveToPoint:CGPointMake(cx, cy - 9)];
        [up addLineToPoint:CGPointMake(cx - aw/2, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.2, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.2, cy - 1.2)];
        [up addLineToPoint:CGPointMake(cx + 1.2, cy - 1.2)];
        [up addLineToPoint:CGPointMake(cx + 1.2, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx + aw/2, cy - 9 + ah)];
        [up closePath];
        UIBezierPath *down = [UIBezierPath bezierPath];
        [down moveToPoint:CGPointMake(cx, cy + 9)];
        [down addLineToPoint:CGPointMake(cx - aw/2, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.2, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.2, cy + 1.2)];
        [down addLineToPoint:CGPointMake(cx + 1.2, cy + 1.2)];
        [down addLineToPoint:CGPointMake(cx + 1.2, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx + aw/2, cy + 9 - ah)];
        [down closePath];
        UIBezierPath *left = [UIBezierPath bezierPath];
        [left moveToPoint:CGPointMake(cx - 9, cy)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy - aw/2)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy - 1.2)];
        [left addLineToPoint:CGPointMake(cx - 1.2, cy - 1.2)];
        [left addLineToPoint:CGPointMake(cx - 1.2, cy + 1.2)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy + 1.2)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy + aw/2)];
        [left closePath];
        UIBezierPath *right = [UIBezierPath bezierPath];
        [right moveToPoint:CGPointMake(cx + 9, cy)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy - aw/2)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy - 1.2)];
        [right addLineToPoint:CGPointMake(cx + 1.2, cy - 1.2)];
        [right addLineToPoint:CGPointMake(cx + 1.2, cy + 1.2)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy + 1.2)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy + aw/2)];
        [right closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:up]; [all appendPath:down]; [all appendPath:left]; [all appendPath:right];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = 1.2; [all stroke];
    } else if ([typeId isEqualToString:@"help"]) {
        // Windows Help - arrow + question mark badge (blue) - same Aero arrow as normal
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        CGFloat s2=0.48; CGFloat tx2=7-0.75*s2; CGFloat ty2=5-1.81*s2;
        [arrow moveToPoint:CGPointMake(18.64*s2+tx2, 55.17*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(11.5*s2+tx2, 38.49*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(0.75*s2+tx2, 49.08*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(0.75*s2+tx2, 1.81*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(34.88*s2+tx2, 35.94*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(18.57*s2+tx2, 36.14*s2+ty2)];
        [arrow addLineToPoint:CGPointMake(25.83*s2+tx2, 51.91*s2+ty2)];
        [arrow closePath];
        [fill setFill]; [arrow fill]; [stroke setStroke]; arrow.lineWidth = strokeWidth; [arrow stroke];
        CGRect badge = CGRectMake(17, 17, 11, 11);
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:badge];
        [[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1] setFill]; [circle fill];
        [[UIColor whiteColor] setStroke]; circle.lineWidth = 1.0; [circle stroke];
        NSDictionary *attrs = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:7.5], NSForegroundColorAttributeName: UIColor.whiteColor};
        NSString *q = @"?";
        CGSize qs = [q sizeWithAttributes:attrs];
        [q drawAtPoint:CGPointMake(22.5 - qs.width/2, 18.8) withAttributes:attrs];
    } else if ([typeId isEqualToString:@"hidden"]) {
        UIGraphicsEndImageContext();
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1,1), NO, scale);
        CGContextRef c2 = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(c2, UIColor.clearColor.CGColor);
        CGContextFillRect(c2, CGRectMake(0,0,1,1));
        UIImage *hidden = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return hidden;
    } else {
        UIGraphicsEndImageContext();
        return [self generateDefaultShapeForType:@"normal"];
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)compositeImageForType:(NSString *)typeId {
    // Hidden cursor always returns transparent image
    if ([typeId isEqualToString:@"hidden"]) {
        return [self generateDefaultShapeForType:@"hidden"];
    }
    
    NSString *cursorName = [self currentCursorForType:typeId];

    if (![self isDefaultCursor:cursorName]) {
        UIImage *customImage = [self imageForCursor:cursorName inType:typeId];
        if (customImage) {
            return customImage;
        }
    }

    UIImage *shape = [self defaultShapeImageForType:typeId];
    return shape;
}

@end