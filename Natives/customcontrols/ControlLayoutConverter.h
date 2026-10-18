#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ControlLayoutSyntax) {
    ControlLayoutSyntaxLegacy = 0,
    ControlLayoutSyntaxZalith = 1,
    ControlLayoutSyntaxUnknown = 2,
};

@interface ControlLayoutConverter : NSObject

+ (ControlLayoutSyntax)syntaxOfLayout:(NSDictionary *)layout;

+ (CGSize)landscapeScreenSize;

+ (NSMutableDictionary *)internalLayoutFromZalith:(NSDictionary *)zalith;

+ (NSDictionary *)zalithLayoutFromInternal:(NSDictionary *)internal
                              buttonFrames:(NSDictionary<NSDictionary *, NSValue *> *)buttonFrames
                            joystickFrames:(NSDictionary<NSDictionary *, NSValue *> *)joystickFrames
                                screenSize:(CGSize)screenSize;

+ (NSDictionary *)normalizedInfoFromInternal:(NSDictionary *)internal;

+ (NSString *)randomUUID12;

@end
