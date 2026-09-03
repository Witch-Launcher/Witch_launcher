#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Decoder for Windows cursor formats (.cur/.ico containers and .ani animations).
/// All methods are thread-safe and return nil + error on malformed input.
@interface WindowsCursorParser : NSObject

/// Magic sniffing (no parsing).
+ (BOOL)isCurData:(nullable NSData *)data;   // ICONDIR with type == 2 (cursor)
+ (BOOL)isAniData:(nullable NSData *)data;   // RIFF....ACON

/// Decode a static cursor. Picks the smallest entry >= 64px (else largest).
/// Returns @{ @"image": UIImage, @"hotspot": NSValue(CGPoint in image pixels),
///            @"width": NSNumber, @"height": NSNumber }.
+ (nullable NSDictionary *)decodeStaticCursorData:(NSData *)data
                                            error:(NSError **)error;

/// Decode an animated cursor (.ani). Returns @{ @"images": @[UIImage...],
/// @"durations": @[NSNumber seconds...], @"hotspot": NSValue(CGPoint),
/// @"width": NSNumber, @"height": NSNumber }. Durations fall back to the
/// anih default rate when the file has no rate chunk.
+ (nullable NSDictionary *)decodeAnimatedCursorData:(NSData *)data
                                              error:(NSError **)error;

/// Encode frames as an animated GIF (loop forever) for storage as image.gif.
+ (nullable NSData *)gifDataFromImages:(NSArray<UIImage *> *)images
                             durations:(NSArray<NSNumber *> *)durations;

@end

NS_ASSUME_NONNULL_END
