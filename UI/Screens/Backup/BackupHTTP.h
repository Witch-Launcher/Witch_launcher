#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupHTTP : NSObject

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)url method:(NSString *)method;
+ (void)jsonRequest:(NSURLRequest *)request
         completion:(void (^)(id _Nullable json, NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))completion;
+ (void)dataRequest:(NSURLRequest *)request
         completion:(void (^)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))completion;
+ (void)downloadRequest:(NSURLRequest *)request
                 toPath:(NSString *)path
             completion:(void (^)(NSError * _Nullable error))completion;
+ (void)uploadRequest:(NSURLRequest *)request
              fromFile:(NSString *)path
            completion:(void (^)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))completion;

+ (NSError *)errorFromData:(NSData *)data response:(NSHTTPURLResponse *)response fallback:(NSString *)fallback;
+ (NSString *)urlEncode:(NSString *)value;
+ (BOOL)isSuccess:(NSHTTPURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
