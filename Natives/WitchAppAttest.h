#import <Foundation/Foundation.h>

@interface WitchAppAttest : NSObject
+ (BOOL)isSupported;
+ (void)attestIfNeededWithCompletion:(void(^)(NSString *assertionToken, NSError *error))completion;
+ (void)generateAssertionForChallenge:(NSString *)challenge completion:(void(^)(NSString *assertion, NSError *error))completion;
@end
