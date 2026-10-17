#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WitchAIService : NSObject

+ (BOOL)isEnabled;

/// Returns YES if launcher should use own AI key directly instead of server proxy
+ (BOOL)shouldUseOwnKey;

+ (NSString* _Nullable)ownKey;
+ (NSString* _Nullable)ownBaseURL;
+ (NSString* _Nullable)ownModel;

+ (void)askWithPrompt:(NSString*)prompt
                 lang:(nullable NSString*)lang
           completion:(void(^)(NSString * _Nullable answer, NSError * _Nullable error))completion;

+ (void)analyzeLogWithExcerpt:(NSString* _Nullable)excerpt
                      fullLog:(NSString* _Nullable)fullLog
                         meta:(nullable NSDictionary*)meta
                   completion:(void(^)(NSString * _Nullable answer, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
