#import "BackupKeychain.h"
#import <Security/Security.h>

@implementation BackupKeychain

+ (NSString *)service {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"com.witch.zad626";
    return [bundle stringByAppendingString:@".backup"];
}

+ (NSMutableDictionary *)queryForKey:(NSString *)key {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: [self service],
        (__bridge id)kSecAttrAccount: key ?: @"",
    } mutableCopy];
}

+ (nullable NSData *)dataForKey:(NSString *)key {
    NSMutableDictionary *query = [self queryForKey:key];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) return nil;
    return CFBridgingRelease(result);
}

+ (BOOL)setData:(NSData *)data forKey:(NSString *)key {
    if (data.length == 0) return [self removeKey:key];
    NSMutableDictionary *query = [self queryForKey:key];
    NSDictionary *update = @{(__bridge id)kSecValueData: data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
    if (status == errSecSuccess) return YES;
    if (status != errSecItemNotFound) return NO;
    query[(__bridge id)kSecValueData] = data;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

+ (BOOL)removeKey:(NSString *)key {
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)[self queryForKey:key]);
    return status == errSecSuccess || status == errSecItemNotFound;
}

+ (NSString *)stringForKey:(NSString *)key {
    NSData *data = [self dataForKey:key];
    if (data.length == 0) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (BOOL)setString:(NSString *)string forKey:(NSString *)key {
    if (string.length == 0) return [self removeKey:key];
    return [self setData:[string dataUsingEncoding:NSUTF8StringEncoding] forKey:key];
}

+ (NSDictionary *)dictionaryForKey:(NSString *)key {
    NSData *data = [self dataForKey:key];
    if (data.length == 0) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

+ (BOOL)setDictionary:(NSDictionary *)dictionary forKey:(NSString *)key {
    if (dictionary.count == 0) return [self removeKey:key];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    return [self setData:data forKey:key];
}

@end
