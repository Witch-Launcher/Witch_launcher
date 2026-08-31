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
    CGFloat baseSize = 32.0;
    CGFloat size = baseSize * scale;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0 * scale);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    CGFloat center = size / 2.0;
    CGFloat radius = size * 0.35;
    
    if ([typeId isEqualToString:@"normal"] || [typeId isEqualToString:@"working"]) {
        // Arrow cursor - standard pointer shape
        CGFloat tipX = center - radius * 0.8;
        CGFloat tipY = center - radius;
        CGFloat leftY = center + radius * 0.7;
        CGFloat rightX = center + radius * 0.3;
        CGFloat rightY = center + radius * 0.7;
        CGFloat topRightX = center + radius * 0.5;
        CGFloat topRightY = center - radius * 0.1;
        CGFloat notchX = center - radius * 0.1;
        CGFloat notchY = center - radius * 0.1;

        // Main arrow body
        CGContextMoveToPoint(ctx, tipX, tipY);
        CGContextAddLineToPoint(ctx, tipX, leftY);
        CGContextAddLineToPoint(ctx, rightX, rightY);
        CGContextAddLineToPoint(ctx, topRightX, topRightY);
        CGContextAddLineToPoint(ctx, notchX, notchY);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);

        // White outline highlight
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.8].CGColor);
        CGContextSetLineWidth(ctx, 1.0 * scale);
        CGContextMoveToPoint(ctx, tipX, tipY);
        CGContextAddLineToPoint(ctx, tipX, leftY);
        CGContextAddLineToPoint(ctx, rightX, rightY);
        CGContextAddLineToPoint(ctx, topRightX, topRightY);
        CGContextAddLineToPoint(ctx, notchX, notchY);
        CGContextClosePath(ctx);
        CGContextStrokePath(ctx);
        
    } else if ([typeId isEqualToString:@"link"]) {
        // Pointing hand cursor
        CGFloat fingerRadius = radius * 0.4;
        CGFloat palmRadius = radius * 0.5;
        
        // Palm
        CGContextAddArc(ctx, center, center + palmRadius * 0.3, palmRadius, M_PI, 0, NO);
        // Fingers
        for (int i = 0; i < 4; i++) {
            CGFloat x = center - radius * 0.6 + i * radius * 0.4;
            CGContextMoveToPoint(ctx, x, center + palmRadius * 0.3);
            CGContextAddLineToPoint(ctx, x, center - fingerRadius);
        }
        // Thumb
        CGContextMoveToPoint(ctx, center - radius * 0.7, center + palmRadius * 0.1);
        CGContextAddLineToPoint(ctx, center - radius * 0.9, center - fingerRadius * 0.3);
        CGContextMoveToPoint(ctx, center - radius * 0.9, center - fingerRadius * 0.3);
        CGContextAddLineToPoint(ctx, center - radius * 0.7, center + palmRadius * 0.1);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
    } else if ([typeId isEqualToString:@"text"]) {
        // I-beam cursor (text selection)
        CGFloat beamHeight = radius * 2.0;
        CGFloat beamWidth = radius * 0.15;
        CGFloat crossbarWidth = radius * 1.2;
        CGFloat crossbarHeight = radius * 0.15;
        
        // Vertical beam
        CGContextMoveToPoint(ctx, center - beamWidth/2, center - beamHeight/2);
        CGContextAddLineToPoint(ctx, center + beamWidth/2, center - beamHeight/2);
        CGContextAddLineToPoint(ctx, center + beamWidth/2, center + beamHeight/2);
        CGContextAddLineToPoint(ctx, center - beamWidth/2, center + beamHeight/2);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        // Top crossbar
        CGContextMoveToPoint(ctx, center - crossbarWidth/2, center - beamHeight/2);
        CGContextAddLineToPoint(ctx, center + crossbarWidth/2, center - beamHeight/2);
        CGContextAddLineToPoint(ctx, center + crossbarWidth/2, center - beamHeight/2 + crossbarHeight);
        CGContextAddLineToPoint(ctx, center - crossbarWidth/2, center - beamHeight/2 + crossbarHeight);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        // Bottom crossbar
        CGContextMoveToPoint(ctx, center - crossbarWidth/2, center + beamHeight/2 - crossbarHeight);
        CGContextAddLineToPoint(ctx, center + crossbarWidth/2, center + beamHeight/2 - crossbarHeight);
        CGContextAddLineToPoint(ctx, center + crossbarWidth/2, center + beamHeight/2);
        CGContextAddLineToPoint(ctx, center - crossbarWidth/2, center + beamHeight/2);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
    } else if ([typeId isEqualToString:@"precision"]) {
        // Crosshair cursor
        CGFloat crossSize = radius * 1.5;
        CGFloat thickness = radius * 0.12;
        
        // Horizontal
        CGContextMoveToPoint(ctx, center - crossSize, center - thickness/2);
        CGContextAddLineToPoint(ctx, center + crossSize, center - thickness/2);
        CGContextAddLineToPoint(ctx, center + crossSize, center + thickness/2);
        CGContextAddLineToPoint(ctx, center - crossSize, center + thickness/2);
        CGContextClosePath(ctx);
        
        // Vertical
        CGContextMoveToPoint(ctx, center - thickness/2, center - crossSize);
        CGContextAddLineToPoint(ctx, center + thickness/2, center - crossSize);
        CGContextAddLineToPoint(ctx, center + thickness/2, center + crossSize);
        CGContextAddLineToPoint(ctx, center - thickness/2, center + crossSize);
        CGContextClosePath(ctx);
        
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        // Center dot
        CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
        CGContextAddArc(ctx, center, center, thickness * 1.5, 0, 2 * M_PI, YES);
        CGContextFillPath(ctx);
        
    } else if ([typeId isEqualToString:@"busy"]) {
        // Spinning circle (wait/busy)
        CGFloat circleRadius = radius * 0.8;
        CGFloat arcStart = 0;
        CGFloat arcEnd = M_PI * 1.5; // 270 degrees
        
        CGContextAddArc(ctx, center, center, circleRadius, arcStart, arcEnd, NO);
        CGContextAddLineToPoint(ctx, center + circleRadius * cosf(arcEnd), center + circleRadius * sinf(arcEnd));
        CGContextAddLineToPoint(ctx, center + (circleRadius - radius * 0.2) * cosf(arcEnd), center + (circleRadius - radius * 0.2) * sinf(arcEnd));
        CGContextAddArc(ctx, center, center, circleRadius - radius * 0.2, arcEnd, arcStart, YES);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        // Arrow head at end
        CGFloat arrowX = center + circleRadius * cosf(arcEnd);
        CGFloat arrowY = center + circleRadius * sinf(arcEnd);
        CGContextMoveToPoint(ctx, arrowX, arrowY);
        CGContextAddLineToPoint(ctx, arrowX - radius * 0.3 * cosf(arcEnd - M_PI/6), arrowY - radius * 0.3 * sinf(arcEnd - M_PI/6));
        CGContextAddLineToPoint(ctx, arrowX - radius * 0.3 * cosf(arcEnd + M_PI/6), arrowY - radius * 0.3 * sinf(arcEnd + M_PI/6));
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
    } else if ([typeId isEqualToString:@"unavailable"]) {
        // Circle with slash (not allowed)
        CGFloat circleRadius = radius * 0.9;
        
        CGContextAddArc(ctx, center, center, circleRadius, 0, 2 * M_PI, YES);
        CGContextStrokePath(ctx);
        
        // Diagonal slash
        CGContextMoveToPoint(ctx, center - circleRadius * 0.7, center - circleRadius * 0.7);
        CGContextAddLineToPoint(ctx, center + circleRadius * 0.7, center + circleRadius * 0.7);
        CGContextStrokePath(ctx);
        
    } else if ([typeId isEqualToString:@"vresize"]) {
        // Vertical resize (double arrow up-down)
        CGFloat arrowSize = radius * 0.8;
        CGFloat spacing = radius * 0.3;
        
        // Top arrow (pointing up)
        CGContextMoveToPoint(ctx, center, center - spacing - arrowSize);
        CGContextAddLineToPoint(ctx, center - arrowSize * 0.6, center - spacing);
        CGContextAddLineToPoint(ctx, center + arrowSize * 0.6, center - spacing);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
        // Bottom arrow (pointing down)
        CGContextMoveToPoint(ctx, center, center + spacing + arrowSize);
        CGContextAddLineToPoint(ctx, center - arrowSize * 0.6, center + spacing);
        CGContextAddLineToPoint(ctx, center + arrowSize * 0.6, center + spacing);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
    } else if ([typeId isEqualToString:@"hresize"]) {
        // Horizontal resize (double arrow left-right)
        CGFloat arrowSize = radius * 0.8;
        CGFloat spacing = radius * 0.3;
        
        // Left arrow
        CGContextMoveToPoint(ctx, center - spacing - arrowSize, center);
        CGContextAddLineToPoint(ctx, center - spacing, center - arrowSize * 0.6);
        CGContextAddLineToPoint(ctx, center - spacing, center + arrowSize * 0.6);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
        // Right arrow
        CGContextMoveToPoint(ctx, center + spacing + arrowSize, center);
        CGContextAddLineToPoint(ctx, center + spacing, center - arrowSize * 0.6);
        CGContextAddLineToPoint(ctx, center + spacing, center + arrowSize * 0.6);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
    } else if ([typeId isEqualToString:@"diagonal"]) {
        // Diagonal resize (NW-SE or NE-SW)
        CGFloat arrowSize = radius * 0.7;
        
        // NW arrow
        CGContextMoveToPoint(ctx, center - radius * 0.8, center - radius * 0.8);
        CGContextAddLineToPoint(ctx, center - radius * 0.8 + arrowSize, center - radius * 0.8);
        CGContextAddLineToPoint(ctx, center - radius * 0.8, center - radius * 0.8 + arrowSize);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
        // SE arrow
        CGContextMoveToPoint(ctx, center + radius * 0.8, center + radius * 0.8);
        CGContextAddLineToPoint(ctx, center + radius * 0.8 - arrowSize, center + radius * 0.8);
        CGContextAddLineToPoint(ctx, center + radius * 0.8, center + radius * 0.8 - arrowSize);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        
    } else if ([typeId isEqualToString:@"move"]) {
        // Move cursor (four arrows)
        CGFloat arrowSize = radius * 0.5;
        CGFloat spacing = radius * 0.7;
        
        // Up
        CGContextMoveToPoint(ctx, center, center - spacing - arrowSize);
        CGContextAddLineToPoint(ctx, center - arrowSize * 0.6, center - spacing);
        CGContextAddLineToPoint(ctx, center + arrowSize * 0.6, center - spacing);
        CGContextClosePath(ctx);
        
        // Down
        CGContextMoveToPoint(ctx, center, center + spacing + arrowSize);
        CGContextAddLineToPoint(ctx, center - arrowSize * 0.6, center + spacing);
        CGContextAddLineToPoint(ctx, center + arrowSize * 0.6, center + spacing);
        CGContextClosePath(ctx);
        
        // Left
        CGContextMoveToPoint(ctx, center - spacing - arrowSize, center);
        CGContextAddLineToPoint(ctx, center - spacing, center - arrowSize * 0.6);
        CGContextAddLineToPoint(ctx, center - spacing, center + arrowSize * 0.6);
        CGContextClosePath(ctx);
        
        // Right
        CGContextMoveToPoint(ctx, center + spacing + arrowSize, center);
        CGContextAddLineToPoint(ctx, center + spacing, center - arrowSize * 0.6);
        CGContextAddLineToPoint(ctx, center + spacing, center + arrowSize * 0.6);
        CGContextClosePath(ctx);
        
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
    } else if ([typeId isEqualToString:@"help"]) {
        // Help cursor (arrow with question mark)
        CGFloat tipX = center - radius * 0.8;
        CGFloat tipY = center - radius;
        CGFloat leftY = center + radius * 0.7;
        CGFloat rightX = center + radius * 0.3;
        CGFloat rightY = center + radius * 0.7;
        CGFloat topRightX = center + radius * 0.5;
        CGFloat topRightY = center - radius * 0.1;
        CGFloat notchX = center - radius * 0.1;
        CGFloat notchY = center - radius * 0.1;

        // Arrow body
        CGContextMoveToPoint(ctx, tipX, tipY);
        CGContextAddLineToPoint(ctx, tipX, leftY);
        CGContextAddLineToPoint(ctx, rightX, rightY);
        CGContextAddLineToPoint(ctx, topRightX, topRightY);
        CGContextAddLineToPoint(ctx, notchX, notchY);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        // Question mark
        CGContextSetFontSize(ctx, radius * 1.2);
        CGContextSelectFont(ctx, "Helvetica-Bold", radius * 1.2, kCGEncodingMacRoman);
        CGContextSetTextDrawingMode(ctx, kCGTextFill);
        CGContextShowTextAtPoint(ctx, center - radius * 0.2, center + radius * 0.1, "?", 1);
        
    } else if ([typeId isEqualToString:@"hidden"]) {
        // Hidden cursor - return transparent 1x1 image
        UIGraphicsEndImageContext();
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, scale);
        CGContextRef hiddenCtx = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(hiddenCtx, [UIColor clearColor].CGColor);
        CGContextFillRect(hiddenCtx, CGRectMake(0, 0, 1, 1));
        UIImage *hiddenImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return hiddenImg;
        
    } else {
        // Fallback to arrow
        return [self generateDefaultShapeForType:@"normal"];
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

#pragma mark - Composite image (cursor decoration)

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