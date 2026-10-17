#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WitchCrypto : NSObject

/// Whether build has encryption key embedded (WITCH_ENCRYPTION_ENABLED==1)
+ (BOOL)isEnabled;

/// Returns YES if string is in enc_v1:<base64> format
+ (BOOL)isEncryptedString:(nullable NSString *)str;

/// Decrypt enc_v1:<base64> -> plain. Returns nil on failure. If not encrypted, returns original.
+ (nullable NSString *)decryptIfNeeded:(nullable NSString *)str;

/// Decrypt strictly (expects enc_v1:). Returns nil if not encrypted or fail.
+ (nullable NSString *)decryptString:(nullable NSString *)encStr;

/// Encrypt plain -> enc_v1:<base64>. Returns nil on failure. If already encrypted, returns as-is. If disabled, returns plain.
+ (nullable NSString *)encryptString:(nullable NSString *)plain;

/// Helpers for pref storage (encrypt on write, decrypt on read)
+ (nullable NSString *)decryptPrefValue:(nullable id)stored;
+ (nullable NSString *)encryptPrefValue:(nullable NSString *)plain;

/// Raw key data (deobfuscated). Nil if disabled.
+ (nullable NSData *)masterKeyData;

/// Transport helpers: encrypt token for Authorization header
+ (nullable NSString *)encryptForTransport:(nullable NSString *)plain;
+ (nullable NSString *)decryptTransport:(nullable NSString *)encStr;

@end

NS_ASSUME_NONNULL_END
