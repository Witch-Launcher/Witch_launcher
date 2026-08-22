#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ElySkinHead : NSObject

+ (void)headForUsername:(NSString *)username
                   size:(CGFloat)size
             completion:(void (^)(UIImage *head))completion;

+ (UIImage *)cachedHeadForUsername:(NSString *)username size:(CGFloat)size;

+ (void)clearCacheForUsername:(NSString *)username;

@end