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
    // Subtle drop shadow for visibility on any game background
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.2), 2.0, [UIColor colorWithWhite:0 alpha:0.35].CGColor);

    UIColor *fill = [UIColor whiteColor];
    UIColor *stroke = [UIColor blackColor];
    CGFloat strokeWidth = 1.5;

    if ([typeId isEqualToString:@"normal"] || [typeId isEqualToString:@"working"]) {
        // Modern macOS-style arrow - crisp, with highlight and shadow
        UIBezierPath *path = [UIBezierPath bezierPath];
        // Tip at (7,5) matches hitbox (7,5) for 32x32
        [path moveToPoint:CGPointMake(7, 5)];
        [path addLineToPoint:CGPointMake(7, 22)];
        [path addLineToPoint:CGPointMake(11.2, 17.8)];
        [path addLineToPoint:CGPointMake(14.8, 21.4)];
        [path addLineToPoint:CGPointMake(20.8, 15.2)];
        [path addLineToPoint:CGPointMake(15.2, 11.8)];
        [path addLineToPoint:CGPointMake(11.5, 15.2)];
        [path closePath];
        path.lineJoinStyle = kCGLineJoinRound;
        path.lineCapStyle = kCGLineCapRound;
        // Outer stroke
        [stroke setStroke];
        path.lineWidth = strokeWidth + 0.9;
        [path stroke];
        // Fill
        [fill setFill];
        [path fill];
        // Inner highlight for 3D feel
        UIBezierPath *hi = [UIBezierPath bezierPath];
        [hi moveToPoint:CGPointMake(7.8, 6.2)];
        [hi addLineToPoint:CGPointMake(7.8, 20.5)];
        [hi addLineToPoint:CGPointMake(11.0, 17.0)];
        hi.lineWidth = 0.7;
        hi.lineCapStyle = kCGLineCapRound;
        hi.lineJoinStyle = kCGLineJoinRound;
        [[UIColor colorWithWhite:1 alpha:0.55] setStroke];
        [hi stroke];
        if ([typeId isEqualToString:@"working"]) {
            // Small spinner badge at bottom-right
            CGRect badge = CGRectMake(19.5, 19.5, 10, 10);
            UIBezierPath *bg = [UIBezierPath bezierPathWithOvalInRect:badge];
            [[UIColor whiteColor] setFill];
            [bg fill];
            [[UIColor blackColor] setStroke];
            bg.lineWidth = 1.2;
            [bg stroke];
            UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(24.5, 24.5) radius:3.2 startAngle:-M_PI_2 endAngle:M_PI*0.85 clockwise:YES];
            arc.lineWidth = 1.3;
            arc.lineCapStyle = kCGLineCapRound;
            [[UIColor blackColor] setStroke];
            [arc stroke];
        }
    } else if ([typeId isEqualToString:@"link"]) {
        // Hand pointer - modern with rounded fingers, smooth palm
        // Palm
        UIBezierPath *palm = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.5, 14.5, 13, 9) cornerRadius:3];
        [fill setFill]; [palm fill]; [stroke setStroke]; palm.lineWidth = strokeWidth; [palm stroke];
        // 4 fingers
        for (int i=0;i<4;i++) {
            CGFloat x = 9.2 + i*3.1;
            CGFloat y = (i==1 ? 5.8 : 7.2);
            CGFloat h = (i==1 ? 9.8 : 8.4);
            UIBezierPath *finger = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, 2.5, h) cornerRadius:1.25];
            [fill setFill]; [finger fill]; [stroke setStroke]; finger.lineWidth = 1.1; [finger stroke];
        }
        // Thumb
        UIBezierPath *thumb = [UIBezierPath bezierPath];
        [thumb moveToPoint:CGPointMake(8.5, 16.5)];
        [thumb addQuadCurveToPoint:CGPointMake(5.2, 11.5) controlPoint:CGPointMake(5, 15)];
        [thumb addLineToPoint:CGPointMake(6.8, 10.2)];
        [thumb addQuadCurveToPoint:CGPointMake(9, 14) controlPoint:CGPointMake(7.8, 12)];
        [thumb closePath];
        [fill setFill]; [thumb fill]; [stroke setStroke]; thumb.lineWidth = 1.1; [thumb stroke];
    } else if ([typeId isEqualToString:@"text"]) {
        // I-beam - crisp with caps, like macOS text cursor
        CGFloat cx=16, cy=16;
        CGFloat h=15, w=1.8, capW=9, capH=1.6;
        UIBezierPath *stem = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx - w/2, cy - h/2, w, h) cornerRadius:0.9];
        [fill setFill]; [stem fill]; [stroke setStroke]; stem.lineWidth = 1.3; [stem stroke];
        UIBezierPath *top = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx - capW/2, cy - h/2 - 0.6, capW, capH) cornerRadius:0.8];
        [fill setFill]; [top fill]; [stroke setStroke]; top.lineWidth = 1.1; [top stroke];
        UIBezierPath *bot = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx - capW/2, cy + h/2 - 1.0, capW, capH) cornerRadius:0.8];
        [fill setFill]; [bot fill]; [stroke setStroke]; bot.lineWidth = 1.1; [bot stroke];
        // Inner bright line
        UIBezierPath *inner = [UIBezierPath bezierPath];
        [inner moveToPoint:CGPointMake(cx, cy - h/2 + 1)];
        [inner addLineToPoint:CGPointMake(cx, cy + h/2 -1)];
        inner.lineWidth = 0.5;
        [[UIColor colorWithWhite:1 alpha:0.7] setStroke];
        [inner stroke];
    } else if ([typeId isEqualToString:@"precision"] || [typeId isEqualToString:@"crosshair"]) {
        // Precision crosshair - thin, with gap, center dot
        CGFloat cx=16, cy=16;
        CGFloat len=11, thick=1.3, gap=3.2;
        UIBezierPath *cross = [UIBezierPath bezierPath];
        // Horizontal left
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - len, cy - thick/2, len - gap, thick)]];
        // Horizontal right
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx + gap, cy - thick/2, len - gap, thick)]];
        // Vertical top
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - thick/2, cy - len, thick, len - gap)]];
        // Vertical bottom
        [cross appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx - thick/2, cy + gap, thick, len - gap)]];
        [fill setFill]; [cross fill]; [stroke setStroke]; cross.lineWidth = 0.7; [cross stroke];
        // Center dot
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx-1.7, cy-1.7, 3.4, 3.4)];
        [[UIColor blackColor] setFill]; [dot fill];
        UIBezierPath *dotInner = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx-0.7, cy-0.7, 1.4, 1.4)];
        [[UIColor whiteColor] setFill]; [dotInner fill];
    } else if ([typeId isEqualToString:@"busy"]) {
        // Busy - circular spinner 300°
        CGFloat cx=16, cy=16, r=9;
        UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r startAngle:-M_PI_2 endAngle:M_PI*1.33 clockwise:YES];
        circle.lineWidth = 2.4;
        circle.lineCapStyle = kCGLineCapRound;
        [stroke setStroke]; [circle stroke];
        UIBezierPath *inner = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r startAngle:-M_PI_2 endAngle:M_PI*1.33 clockwise:YES];
        inner.lineWidth = 1.0;
        inner.lineCapStyle = kCGLineCapRound;
        [[UIColor colorWithWhite:1 alpha:0.92] setStroke];
        [inner stroke];
        CGFloat angle = M_PI*1.33;
        CGPoint p = CGPointMake(cx + r*cos(angle), cy + r*sin(angle));
        CGFloat ah = 3.6;
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:p];
        [arrow addLineToPoint:CGPointMake(p.x - ah*cos(angle - M_PI/6), p.y - ah*sin(angle - M_PI/6))];
        [arrow addLineToPoint:CGPointMake(p.x - ah*cos(angle + M_PI/6), p.y - ah*sin(angle + M_PI/6))];
        [arrow closePath];
        [fill setFill]; [arrow fill]; [stroke setStroke]; arrow.lineWidth = 1.0; [arrow stroke];
    } else if ([typeId isEqualToString:@"unavailable"]) {
        // Circle slash - red slash for visibility
        CGFloat cx=16, cy=16, r=10;
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx-r, cy-r, r*2, r*2)];
        circle.lineWidth = 2.0;
        [[UIColor colorWithWhite:1 alpha:0.94] setFill]; [circle fill];
        [stroke setStroke]; [circle stroke];
        // Slash - outer black then inner red
        UIBezierPath *slashBack = [UIBezierPath bezierPath];
        [slashBack moveToPoint:CGPointMake(cx - r*0.68, cy - r*0.68)];
        [slashBack addLineToPoint:CGPointMake(cx + r*0.68, cy + r*0.68)];
        slashBack.lineWidth = 3.4;
        slashBack.lineCapStyle = kCGLineCapRound;
        [[UIColor blackColor] setStroke];
        [slashBack stroke];
        UIBezierPath *slash = [UIBezierPath bezierPath];
        [slash moveToPoint:CGPointMake(cx - r*0.68, cy - r*0.68)];
        [slash addLineToPoint:CGPointMake(cx + r*0.68, cy + r*0.68)];
        slash.lineWidth = 2.0;
        slash.lineCapStyle = kCGLineCapRound;
        [[UIColor colorWithRed:0.96 green:0.22 blue:0.22 alpha:1] setStroke];
        [slash stroke];
    } else if ([typeId isEqualToString:@"vresize"]) {
        CGFloat cx=16, cy=16, ah=6, aw=7;
        UIBezierPath *up = [UIBezierPath bezierPath];
        [up moveToPoint:CGPointMake(cx, cy - 9)];
        [up addLineToPoint:CGPointMake(cx - aw/2, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.8, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.8, cy - 1.8)];
        [up addLineToPoint:CGPointMake(cx + 1.8, cy - 1.8)];
        [up addLineToPoint:CGPointMake(cx + 1.8, cy - 9 + ah)];
        [up addLineToPoint:CGPointMake(cx + aw/2, cy - 9 + ah)];
        [up closePath];
        UIBezierPath *down = [UIBezierPath bezierPath];
        [down moveToPoint:CGPointMake(cx, cy + 9)];
        [down addLineToPoint:CGPointMake(cx - aw/2, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.8, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.8, cy + 1.8)];
        [down addLineToPoint:CGPointMake(cx + 1.8, cy + 1.8)];
        [down addLineToPoint:CGPointMake(cx + 1.8, cy + 9 - ah)];
        [down addLineToPoint:CGPointMake(cx + aw/2, cy + 9 - ah)];
        [down closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:up]; [all appendPath:down];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; all.lineJoinStyle = kCGLineJoinRound; [all stroke];
    } else if ([typeId isEqualToString:@"hresize"]) {
        CGFloat cx=16, cy=16, ah=6, aw=7;
        UIBezierPath *left = [UIBezierPath bezierPath];
        [left moveToPoint:CGPointMake(cx - 9, cy)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy - aw/2)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy - 1.8)];
        [left addLineToPoint:CGPointMake(cx - 1.8, cy - 1.8)];
        [left addLineToPoint:CGPointMake(cx - 1.8, cy + 1.8)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy + 1.8)];
        [left addLineToPoint:CGPointMake(cx - 9 + ah, cy + aw/2)];
        [left closePath];
        UIBezierPath *right = [UIBezierPath bezierPath];
        [right moveToPoint:CGPointMake(cx + 9, cy)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy - aw/2)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy - 1.8)];
        [right addLineToPoint:CGPointMake(cx + 1.8, cy - 1.8)];
        [right addLineToPoint:CGPointMake(cx + 1.8, cy + 1.8)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy + 1.8)];
        [right addLineToPoint:CGPointMake(cx + 9 - ah, cy + aw/2)];
        [right closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:left]; [all appendPath:right];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; [all stroke];
    } else if ([typeId isEqualToString:@"diagonal"]) {
        // Diagonal NW-SE
        UIBezierPath *a1 = [UIBezierPath bezierPath];
        [a1 moveToPoint:CGPointMake(8, 8)];
        [a1 addLineToPoint:CGPointMake(14, 8)];
        [a1 addLineToPoint:CGPointMake(14, 10)];
        [a1 addLineToPoint:CGPointMake(11, 11)];
        [a1 addLineToPoint:CGPointMake(10, 14)];
        [a1 addLineToPoint:CGPointMake(8, 14)];
        [a1 closePath];
        UIBezierPath *a2 = [UIBezierPath bezierPath];
        [a2 moveToPoint:CGPointMake(24, 24)];
        [a2 addLineToPoint:CGPointMake(18, 24)];
        [a2 addLineToPoint:CGPointMake(18, 22)];
        [a2 addLineToPoint:CGPointMake(21, 21)];
        [a2 addLineToPoint:CGPointMake(22, 18)];
        [a2 addLineToPoint:CGPointMake(24, 18)];
        [a2 closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:a1]; [all appendPath:a2];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = strokeWidth; [all stroke];
        // Center line with highlight
        UIBezierPath *line = [UIBezierPath bezierPath];
        [line moveToPoint:CGPointMake(10, 10)];
        [line addLineToPoint:CGPointMake(22, 22)];
        line.lineWidth = 1.7;
        line.lineCapStyle = kCGLineCapRound;
        [stroke setStroke]; [line stroke];
        [[UIColor whiteColor] setStroke]; line.lineWidth = 0.8; [line stroke];
    } else if ([typeId isEqualToString:@"move"]) {
        CGFloat cx=16, cy=16;
        CGFloat ah=5, aw=6;
        UIBezierPath *up = [UIBezierPath bezierPath];
        [up moveToPoint:CGPointMake(cx, cy - 9.5)];
        [up addLineToPoint:CGPointMake(cx - aw/2, cy - 9.5 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.4, cy - 9.5 + ah)];
        [up addLineToPoint:CGPointMake(cx - 1.4, cy - 1.6)];
        [up addLineToPoint:CGPointMake(cx + 1.4, cy - 1.6)];
        [up addLineToPoint:CGPointMake(cx + 1.4, cy - 9.5 + ah)];
        [up addLineToPoint:CGPointMake(cx + aw/2, cy - 9.5 + ah)];
        [up closePath];
        UIBezierPath *down = [UIBezierPath bezierPath];
        [down moveToPoint:CGPointMake(cx, cy + 9.5)];
        [down addLineToPoint:CGPointMake(cx - aw/2, cy + 9.5 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.4, cy + 9.5 - ah)];
        [down addLineToPoint:CGPointMake(cx - 1.4, cy + 1.6)];
        [down addLineToPoint:CGPointMake(cx + 1.4, cy + 1.6)];
        [down addLineToPoint:CGPointMake(cx + 1.4, cy + 9.5 - ah)];
        [down addLineToPoint:CGPointMake(cx + aw/2, cy + 9.5 - ah)];
        [down closePath];
        UIBezierPath *left = [UIBezierPath bezierPath];
        [left moveToPoint:CGPointMake(cx - 9.5, cy)];
        [left addLineToPoint:CGPointMake(cx - 9.5 + ah, cy - aw/2)];
        [left addLineToPoint:CGPointMake(cx - 9.5 + ah, cy - 1.4)];
        [left addLineToPoint:CGPointMake(cx - 1.6, cy - 1.4)];
        [left addLineToPoint:CGPointMake(cx - 1.6, cy + 1.4)];
        [left addLineToPoint:CGPointMake(cx - 9.5 + ah, cy + 1.4)];
        [left addLineToPoint:CGPointMake(cx - 9.5 + ah, cy + aw/2)];
        [left closePath];
        UIBezierPath *right = [UIBezierPath bezierPath];
        [right moveToPoint:CGPointMake(cx + 9.5, cy)];
        [right addLineToPoint:CGPointMake(cx + 9.5 - ah, cy - aw/2)];
        [right addLineToPoint:CGPointMake(cx + 9.5 - ah, cy - 1.4)];
        [right addLineToPoint:CGPointMake(cx + 1.6, cy - 1.4)];
        [right addLineToPoint:CGPointMake(cx + 1.6, cy + 1.4)];
        [right addLineToPoint:CGPointMake(cx + 9.5 - ah, cy + 1.4)];
        [right addLineToPoint:CGPointMake(cx + 9.5 - ah, cy + aw/2)];
        [right closePath];
        UIBezierPath *all = [UIBezierPath bezierPath];
        [all appendPath:up]; [all appendPath:down]; [all appendPath:left]; [all appendPath:right];
        [fill setFill]; [all fill]; [stroke setStroke]; all.lineWidth = 1.3; all.lineJoinStyle = kCGLineJoinRound; [all stroke];
    } else if ([typeId isEqualToString:@"help"]) {
        // Arrow + question badge
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(7, 5)];
        [arrow addLineToPoint:CGPointMake(7, 19)];
        [arrow addLineToPoint:CGPointMake(11, 15)];
        [arrow addLineToPoint:CGPointMake(14.5, 18.5)];
        [arrow addLineToPoint:CGPointMake(19, 13.5)];
        [arrow addLineToPoint:CGPointMake(14.5, 11)];
        [arrow addLineToPoint:CGPointMake(11, 14.5)];
        [arrow closePath];
        [fill setFill]; [arrow fill]; [stroke setStroke]; arrow.lineWidth = strokeWidth; [arrow stroke];
        CGRect badge = CGRectMake(17.5, 17.5, 11, 11);
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:badge];
        [[UIColor colorWithRed:0.22 green:0.55 blue:0.98 alpha:1] setFill]; [circle fill];
        [[UIColor whiteColor] setStroke]; circle.lineWidth = 1.1; [circle stroke];
        // ?
        NSDictionary *attrs = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:7.5], NSForegroundColorAttributeName: UIColor.whiteColor};
        NSString *q = @"?";
        CGSize qs = [q sizeWithAttributes:attrs];
        [q drawAtPoint:CGPointMake(23 - qs.width/2, 19.2) withAttributes:attrs];
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