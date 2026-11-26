#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Compares plugin versions. Numeric parts are compared first, then the
// pre-release suffix: "1.0.0-beta" is older than "1.0.0".
@interface WitchPluginVersion : NSObject

+ (NSComparisonResult)compare:(nullable NSString *)lhs to:(nullable NSString *)rhs;
+ (BOOL)isVersion:(nullable NSString *)candidate newerThan:(nullable NSString *)current;

@end

NS_ASSUME_NONNULL_END
