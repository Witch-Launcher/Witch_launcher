#import "WindowsCursorParser.h"
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kParserErrorDomain = @"WindowsCursorParser";

static NSError *ParserError(NSInteger code, NSString *msg) {
    return [NSError errorWithDomain:kParserErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

static uint16_t ReadU16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static uint32_t ReadU32(const uint8_t *p) {
    return (uint32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24));
}
static int32_t ReadS32(const uint8_t *p) { return (int32_t)ReadU32(p); }

static const uint8_t kPngSig[8] = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};

@implementation WindowsCursorParser

+ (BOOL)isCurData:(NSData *)data {
    if (!data || data.length < 6) return NO;
    const uint8_t *p = (const uint8_t *)data.bytes;
    // ICONDIR: reserved(0) + type(2 = cursor)
    return p[0] == 0 && p[1] == 0 && p[2] == 2 && p[3] == 0;
}

+ (BOOL)isAniData:(NSData *)data {
    if (!data || data.length < 12) return NO;
    const uint8_t *p = (const uint8_t *)data.bytes;
    return memcmp(p, "RIFF", 4) == 0 && memcmp(p + 8, "ACON", 4) == 0;
}

#pragma mark - ICONDIR entries

/// Parse ICONDIR entries. Each entry dict: w,h,hx,hy,size,off (NSNumbers).
+ (nullable NSArray<NSDictionary *> *)entriesFromIconDir:(NSData *)data
                                                  error:(NSError **)error {
    if (!data || data.length < 6) {
        if (error) *error = ParserError(-1, @"File too small for ICONDIR");
        return nil;
    }
    const uint8_t *p = (const uint8_t *)data.bytes;
    NSUInteger len = data.length;
    uint16_t type = ReadU16(p + 2);
    uint16_t count = ReadU16(p + 4);
    if (type != 1 && type != 2) {
        if (error) *error = ParserError(-2, @"Not an icon/cursor file");
        return nil;
    }
    if (count == 0 || 6 + count * 16 > len) {
        if (error) *error = ParserError(-3, @"Corrupt ICONDIR entry count");
        return nil;
    }
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:count];
    for (uint16_t i = 0; i < count; i++) {
        const uint8_t *e = p + 6 + i * 16;
        NSUInteger w = e[0] == 0 ? 256 : e[0];
        NSUInteger h = e[1] == 0 ? 256 : e[1];
        uint16_t hx = ReadU16(e + 4);
        uint16_t hy = ReadU16(e + 6);
        uint32_t size = ReadU32(e + 8);
        uint32_t off = ReadU32(e + 12);
        if ((NSUInteger)off + size > len || size < 40) {
            // PNG-compressed entries are >= 8 bytes; tiny entries are corrupt.
            if (size < 8 || (NSUInteger)off + size > len) {
                continue;
            }
        }
        [out addObject:@{@"w": @(w), @"h": @(h), @"hx": @(hx), @"hy": @(hy),
                         @"size": @(size), @"off": @(off)}];
    }
    if (out.count == 0) {
        if (error) *error = ParserError(-4, @"No valid cursor images found");
        return nil;
    }
    return out;
}

+ (nullable NSDictionary *)bestEntry:(NSArray<NSDictionary *> *)entries
                         minWidth:(NSUInteger)minWidth {
    NSDictionary *best = nil;
    for (NSDictionary *e in entries) {
        NSUInteger w = [e[@"w"] unsignedIntegerValue];
        if (w >= minWidth && (!best || w < [best[@"w"] unsignedIntegerValue])) {
            best = e;
        }
    }
    if (!best) {
        for (NSDictionary *e in entries) {
            if (!best || [e[@"w"] unsignedIntegerValue] > [best[@"w"] unsignedIntegerValue]) {
                best = e;
            }
        }
    }
    return best;
}

#pragma mark - DIB decode

/// Decode one DIB (BITMAPINFOHEADER + XOR pixels + 1bpp AND mask) to RGBA.
/// Handles 32/24/8/4/1 bpp BI_RGB plus PNG-compressed blobs.
+ (nullable NSDictionary *)decodeImageBlob:(NSData *)blob error:(NSError **)error {
    if (!blob || blob.length < 8) {
        if (error) *error = ParserError(-10, @"Empty cursor image");
        return nil;
    }
    const uint8_t *p = (const uint8_t *)blob.bytes;
    NSUInteger len = blob.length;
    if (len >= 8 && memcmp(p, kPngSig, 8) == 0) {
        UIImage *img = [UIImage imageWithData:blob];
        if (!img || !img.CGImage) {
            if (error) *error = ParserError(-11, @"Invalid embedded PNG");
            return nil;
        }
        // Re-render through RGBA buffer so hotspot math stays consistent.
        CGImageRef cg = img.CGImage;
        size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
        NSMutableData *rgba = [NSMutableData dataWithLength:w * h * 4];
        CGContextRef ctx = CGBitmapContextCreate(rgba.mutableBytes, w, h, 8, w * 4,
            CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if (!ctx) {
            if (error) *error = ParserError(-12, @"Could not create bitmap context");
            return nil;
        }
        CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
        CGContextRelease(ctx);
        // Unpremultiply for clean PNG re-encode.
        uint8_t *px = (uint8_t *)rgba.mutableBytes;
        for (size_t i = 0; i < w * h; i++) {
            uint8_t a = px[i * 4 + 3];
            if (a != 0 && a != 255) {
                px[i * 4 + 0] = (uint8_t)(px[i * 4 + 0] * 255 / a);
                px[i * 4 + 1] = (uint8_t)(px[i * 4 + 1] * 255 / a);
                px[i * 4 + 2] = (uint8_t)(px[i * 4 + 2] * 255 / a);
            }
        }
        UIImage *out = [self imageFromRGBA:rgba width:w height:h];
        if (!out && error) *error = ParserError(-13, @"Could not rebuild PNG image");
        return out ? @{@"image": out, @"width": @(w), @"height": @(h)} : nil;
    }
    if (len < 40) {
        if (error) *error = ParserError(-14, @"DIB header too small");
        return nil;
    }
    uint32_t hs = ReadU32(p);
    int32_t w = ReadS32(p + 4);
    int32_t h2 = ReadS32(p + 8);
    uint16_t bpp = ReadU16(p + 14);
    uint32_t comp = ReadU32(p + 16);
    if (hs < 40 || w <= 0 || h2 <= 0 || comp != 0) {
        if (error) *error = ParserError(-15, @"Unsupported DIB format (compressed?)");
        return nil;
    }
    NSUInteger h = (NSUInteger)(h2 / 2); // XOR height + AND mask height
    if (h == 0 || w > 1024 || h > 1024) {
        if (error) *error = ParserError(-16, @"Bogus cursor dimensions");
        return nil;
    }
    // Palette for <= 8bpp.
    const uint8_t *pal = p + hs;
    NSUInteger palEntries = 0;
    if (bpp <= 8) {
        uint32_t clrUsed = (hs >= 40 && len >= 36) ? ReadU32(p + 32) : 0;
        palEntries = clrUsed ? clrUsed : (1u << bpp);
        if (hs + palEntries * 4 > len) {
            if (error) *error = ParserError(-17, @"Truncated palette");
            return nil;
        }
    }
    NSUInteger pxOff = hs + palEntries * 4;
    NSUInteger xorStride = ((NSUInteger)w * bpp + 31) / 32 * 4;
    NSUInteger maskStride = ((NSUInteger)w + 31) / 32 * 4;
    if (pxOff + xorStride * h + maskStride * h > len) {
        if (error) *error = ParserError(-18, @"Truncated cursor pixels");
        return nil;
    }
    NSMutableData *rgba = [NSMutableData dataWithLength:(NSUInteger)w * h * 4];
    uint8_t *dst = (uint8_t *)rgba.mutableBytes;
    const uint8_t *xorBase = p + pxOff;
    const uint8_t *maskBase = p + pxOff + xorStride * h;
    for (NSUInteger y = 0; y < h; y++) {
        NSUInteger srcY = h - 1 - y; // DIB rows are bottom-up
        const uint8_t *xorRow = xorBase + srcY * xorStride;
        const uint8_t *maskRow = maskBase + srcY * maskStride;
        for (NSInteger x = 0; x < w; x++) {
            uint8_t r = 0, g = 0, b = 0, a = 255;
            if (bpp == 32) {
                b = xorRow[x * 4 + 0]; g = xorRow[x * 4 + 1];
                r = xorRow[x * 4 + 2]; a = xorRow[x * 4 + 3];
            } else if (bpp == 24) {
                b = xorRow[x * 4 + 0]; g = xorRow[x * 4 + 1]; r = xorRow[x * 4 + 2];
            } else {
                NSUInteger idx = 0;
                if (bpp == 8) {
                    idx = xorRow[x];
                } else if (bpp == 4) {
                    idx = (x & 1) ? (xorRow[x / 2] & 0x0F) : (xorRow[x / 2] >> 4);
                } else if (bpp == 1) {
                    idx = (xorRow[x / 8] >> (7 - (x % 8))) & 1;
                } else {
                    if (error) *error = ParserError(-19, @"Unsupported bit depth");
                    return nil;
                }
                if (idx >= palEntries) idx = 0;
                b = pal[idx * 4 + 0]; g = pal[idx * 4 + 1]; r = pal[idx * 4 + 2];
            }
            // AND mask: 1 = transparent.
            if ((maskRow[x / 8] >> (7 - (x % 8))) & 1) a = 0;
            NSUInteger d = (y * (NSUInteger)w + (NSUInteger)x) * 4;
            dst[d + 0] = r; dst[d + 1] = g; dst[d + 2] = b; dst[d + 3] = a;
        }
    }
    UIImage *img = [self imageFromRGBA:rgba width:(NSUInteger)w height:h];
    if (!img) {
        if (error) *error = ParserError(-20, @"Could not build cursor image");
        return nil;
    }
    return @{@"image": img, @"width": @((NSUInteger)w), @"height": @(h)};
}

+ (nullable UIImage *)imageFromRGBA:(NSData *)rgba width:(NSUInteger)w height:(NSUInteger)h {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgba);
    if (!provider) return nil;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGImageRef cg = CGImageCreate(w, h, 8, 32, w * 4, cs,
        kCGImageAlphaLast | kCGBitmapByteOrder32Big, provider, NULL, NO,
        kCGRenderingIntentDefault);
    CGColorSpaceRelease(cs);
    CGDataProviderRelease(provider);
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return img;
}

#pragma mark - Public decode

+ (nullable NSDictionary *)decodeStaticCursorData:(NSData *)data
                                            error:(NSError **)error {
    NSArray<NSDictionary *> *entries = [self entriesFromIconDir:data error:error];
    if (!entries) return nil;
    NSDictionary *best = [self bestEntry:entries minWidth:64];
    NSUInteger off = [best[@"off"] unsignedIntegerValue];
    NSUInteger size = [best[@"size"] unsignedIntegerValue];
    if (off + size > data.length) {
        if (error) *error = ParserError(-30, @"Cursor image out of bounds");
        return nil;
    }
    NSDictionary *img = [self decodeImageBlob:[data subdataWithRange:NSMakeRange(off, size)]
                                               error:error];
    if (!img) return nil;
    NSUInteger w = [img[@"width"] unsignedIntegerValue];
    NSUInteger h = [img[@"height"] unsignedIntegerValue];
    // Scale hotspot from directory entry size to the decoded pixel size.
    CGFloat sx = (CGFloat)w / MAX([best[@"w"] unsignedIntegerValue], 1);
    CGFloat sy = (CGFloat)h / MAX([best[@"h"] unsignedIntegerValue], 1);
    CGPoint hot = CGPointMake([best[@"hx"] floatValue] * sx, [best[@"hy"] floatValue] * sy);
    return @{@"image": img[@"image"], @"hotspot": [NSValue valueWithCGPoint:hot],
             @"width": @(w), @"height": @(h)};
}

+ (nullable NSDictionary *)decodeAnimatedCursorData:(NSData *)data
                                              error:(NSError **)error {
    if (![self isAniData:data]) {
        if (error) *error = ParserError(-40, @"Not an animated cursor");
        return nil;
    }
    const uint8_t *p = (const uint8_t *)data.bytes;
    NSUInteger len = data.length;
    NSUInteger pos = 12;
    NSUInteger defaultRate = 3; // jiffies (1/60s)
    NSMutableArray<NSData *> *frames = [NSMutableArray array];
    NSMutableArray<NSNumber *> *rates = nil;
    NSMutableArray<NSNumber *> *seq = nil;
    while (pos + 8 <= len) {
        const uint8_t *c = p + pos;
        if (memcmp(c, "RIFF", 4) == 0) break;
        uint32_t sz = ReadU32(c + 4);
        if (pos + 8 + sz > len) break;
        const uint8_t *body = c + 8;
        if (memcmp(c, "anih", 4) == 0 && sz >= 36) {
            uint32_t r = ReadU32(body + 28); // iDispRate
            if (r > 0 && r < 600) defaultRate = r;
        } else if (memcmp(c, "LIST", 4) == 0 && sz >= 4 && memcmp(body, "fram", 4) == 0) {
            NSUInteger fp = 4;
            while (fp + 8 <= sz) {
                const uint8_t *fc = body + fp;
                uint32_t fs = ReadU32(fc + 4);
                if (fp + 8 + fs > sz) break;
                if (memcmp(fc, "icon", 4) == 0 && fs >= 6) {
                    [frames addObject:[NSData dataWithBytes:fc + 8 length:fs]];
                }
                fp += 8 + fs + (fs & 1);
            }
        } else if (memcmp(c, "rate", 4) == 0) {
            rates = [NSMutableArray array];
            for (NSUInteger i = 0; i + 4 <= sz; i += 4) {
                [rates addObject:@(ReadU32(body + i))];
            }
        } else if (memcmp(c, "seq ", 4) == 0) {
            seq = [NSMutableArray array];
            for (NSUInteger i = 0; i + 4 <= sz; i += 4) {
                [seq addObject:@(ReadU32(body + i))];
            }
        }
        pos += 8 + sz + (sz & 1);
    }
    if (frames.count == 0) {
        if (error) *error = ParserError(-41, @"Animated cursor has no frames");
        return nil;
    }
    // Playback order.
    NSMutableArray<NSNumber *> *order = [NSMutableArray array];
    if (seq.count == frames.count) {
        [order addObjectsFromArray:seq];
    } else {
        for (NSUInteger i = 0; i < frames.count; i++) [order addObject:@(i)];
    }
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    NSMutableArray<NSNumber *> *durations = [NSMutableArray array];
    CGPoint hotspot = CGPointZero;
    NSUInteger fw = 0, fh = 0;
    BOOL first = YES;
    for (NSNumber *n in order) {
        NSUInteger fi = [n unsignedIntegerValue];
        if (fi >= frames.count) continue;
        NSArray<NSDictionary *> *entries = [self entriesFromIconDir:frames[fi] error:nil];
        if (!entries) continue;
        // ANI frames are small; prefer >= 48px for a crisp but light import.
        NSDictionary *best = [self bestEntry:entries minWidth:48];
        NSUInteger off = [best[@"off"] unsignedIntegerValue];
        NSUInteger size = [best[@"size"] unsignedIntegerValue];
        NSData *fdata = frames[fi];
        if (off + size > fdata.length) continue;
        NSError *derr = nil;
        NSDictionary *img = [self decodeImageBlob:[fdata subdataWithRange:NSMakeRange(off, size)]
                                                   error:&derr];
        if (!img) continue;
        [images addObject:img[@"image"]];
        NSUInteger jiffies = defaultRate;
        if (rates && fi < rates.count) {
            NSUInteger r = [rates[fi] unsignedIntegerValue];
            if (r > 0 && r < 600) jiffies = r;
        }
        [durations addObject:@(MAX(jiffies, 1) / 60.0)];
        if (first) {
            first = NO;
            fw = [img[@"width"] unsignedIntegerValue];
            fh = [img[@"height"] unsignedIntegerValue];
            CGFloat sx = (CGFloat)fw / MAX([best[@"w"] unsignedIntegerValue], 1);
            CGFloat sy = (CGFloat)fh / MAX([best[@"h"] unsignedIntegerValue], 1);
            hotspot = CGPointMake([best[@"hx"] floatValue] * sx, [best[@"hy"] floatValue] * sy);
        }
    }
    if (images.count == 0) {
        if (error) *error = ParserError(-42, @"Could not decode any animation frame");
        return nil;
    }
    return @{@"images": images, @"durations": durations,
             @"hotspot": [NSValue valueWithCGPoint:hotspot],
             @"width": @(fw), @"height": @(fh)};
}

#pragma mark - GIF encode

+ (nullable NSData *)gifDataFromImages:(NSArray<UIImage *> *)images
                             durations:(NSArray<NSNumber *> *)durations {
    if (images.count == 0) return nil;
    NSMutableData *out = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)out, (CFStringRef)UTTypeGIF.identifier,
        images.count, NULL);
    if (!dest) return nil;
    NSDictionary *fileProps = @{(NSString *)kCGImagePropertyGIFDictionary:
        @{(NSString *)kCGImagePropertyGIFLoopCount: @0}};
    CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)fileProps);
    for (NSUInteger i = 0; i < images.count; i++) {
        CGImageRef cg = images[i].CGImage;
        if (!cg) continue;
        NSTimeInterval d = (i < durations.count) ? [durations[i] doubleValue] : 0.05;
        if (d < 0.02) d = 0.02; // browsers/clients clamp tiny delays
        NSDictionary *frameProps = @{(NSString *)kCGImagePropertyGIFDictionary:
            @{(NSString *)kCGImagePropertyGIFDelayTime: @(d)}};
        CGImageDestinationAddImage(dest, cg, (__bridge CFDictionaryRef)frameProps);
    }
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return ok ? out : nil;
}

@end
