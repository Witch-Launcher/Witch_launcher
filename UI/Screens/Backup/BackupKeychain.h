#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupKeychain : NSObject

+ (nullable NSData *)dataForKey:(NSString *)key;
+ (BOOL)setData:(nullable NSData *)data forKey:(NSString *)key;
+ (BOOL)removeKey:(NSString *)key;

+ (nullable NSString *)stringForKey:(NSString *)key;
+ (BOOL)setString:(nullable NSString *)string forKey:(NSString *)key;

+ (nullable NSDictionary *)dictionaryForKey:(NSString *)key;
+ (BOOL)setDictionary:(nullable NSDictionary *)dictionary forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
