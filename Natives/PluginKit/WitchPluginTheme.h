#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WitchPluginTheme : NSObject

+ (void)reload;
+ (nullable UIColor *)colorForKey:(NSString *)key dark:(BOOL)dark;

@end

NS_ASSUME_NONNULL_END
