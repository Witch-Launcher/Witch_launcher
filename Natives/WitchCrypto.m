#import "WitchCrypto.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#if __has_include("Config/WitchConfig.h")
#import "Config/WitchConfig.h"
#endif

#ifndef WITCH_ENCRYPTION_ENABLED
#define WITCH_ENCRYPTION_ENABLED 0
#endif

@implementation WitchCrypto

#pragma mark - Key

+ (BOOL)isEnabled {
#if WITCH_ENCRYPTION_ENABLED
    NSData *k = [self masterKeyData];
    return k.length == 32;
#else
    return NO;
#endif
}

+ (nullable NSData *)masterKeyData {
#if WITCH_ENCRYPTION_ENABLED
#ifdef WITCH_ENCRYPTION_KEY_OBF_B64
#ifdef WITCH_ENCRYPTION_KEY_SALT
    {
        NSString *b64 = WITCH_ENCRYPTION_KEY_OBF_B64;
        if (![b64 isKindOfClass:[NSString class]] || b64.length == 0) return nil;
        NSData *obf = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
        if (!obf || obf.length != 32) return nil;
        uint8_t salt = (uint8_t)WITCH_ENCRYPTION_KEY_SALT;
        NSMutableData *key = [NSMutableData dataWithLength:obf.length];
        const uint8_t *obfBytes = obf.bytes;
        uint8_t *keyBytes = key.mutableBytes;
        for (NSUInteger i = 0; i < obf.length; i++) {
            keyBytes[i] = obfBytes[i] ^ salt ^ (uint8_t)(i & 0xFF);
        }
        return [key copy];
    }
#endif
#endif
    return nil;
#else
    return nil;
#endif
}

+ (nullable NSData *)masterKeyDataFromStaticArrayIfAvailable { return nil; }

#pragma mark - Helpers

+ (BOOL)isEncryptedString:(nullable NSString *)str {
    if (![str isKindOfClass:[NSString class]]) return NO;
    return [str hasPrefix:@"enc_v1:"];
}

+ (nullable NSString *)decryptIfNeeded:(nullable NSString *)str {
    if (!str) return nil;
    if (![self isEncryptedString:str]) return str;
    return [self decryptString:str];
}

+ (nullable NSString *)decryptString:(nullable NSString *)encStr {
    if (!encStr || ![encStr isKindOfClass:[NSString class]]) return nil;
    if (![encStr hasPrefix:@"enc_v1:"]) return nil;
    if (![self isEnabled]) return nil;
    NSString *b64 = [encStr substringFromIndex:7];
    if (b64.length == 0) return nil;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    if (!data || data.length < 16 + 16 + 1) return nil;
    NSData *key = [self masterKeyData];
    if (!key || key.length != 32) return nil;
    // Try CBC with iv 16 first (current), then try GCM iv12 / CBC iv12 padded for backward compat
    NSData *plain = nil;
    // CBC iv16
    if (data.length >= 32) {
        NSData *iv16 = [data subdataWithRange:NSMakeRange(0, 16)];
        NSData *tag = [data subdataWithRange:NSMakeRange(data.length - 16, 16)];
        NSData *cipher = [data subdataWithRange:NSMakeRange(16, data.length - 16 - 16)];
        plain = [self aesCBCDecrypt:cipher iv:iv16 tag:tag key:key];
        if (plain) {
            NSString *str = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
            if (str) return str;
        }
    }
    // Fallback: GCM iv12 (legacy) — also try CBC with iv12 padded
    if (data.length >= 12 + 16 + 1) {
        NSData *iv12 = [data subdataWithRange:NSMakeRange(0, 12)];
        NSData *tag = [data subdataWithRange:NSMakeRange(data.length - 16, 16)];
        NSData *cipher = [data subdataWithRange:NSMakeRange(12, data.length - 12 - 16)];
        // Try CBC with iv12 padded to 16 (old fallback)
        plain = [self aesCBCDecryptWithIV12:cipher iv12:iv12 tag:tag key:key];
        if (plain) {
            NSString *str = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
            if (str) return str;
        }
        // Try GCM via fallback (if ever generated with GCM, we try to handle via CBC? not possible)
        // We keep GCM decrypt attempt via CBC fallback already, so if it was GCM it will fail and return nil
    }
    return nil;
}

+ (nullable NSString *)encryptString:(nullable NSString *)plain {
    if (!plain) return nil;
    if (![plain isKindOfClass:[NSString class]]) return nil;
    if (plain.length == 0) return plain;
    if ([self isEncryptedString:plain]) return plain;
    if (![self isEnabled]) return plain;
    NSData *key = [self masterKeyData];
    if (!key || key.length != 32) return plain;
    NSData *plainData = [plain dataUsingEncoding:NSUTF8StringEncoding];
    if (!plainData) return nil;
    // Use AES-256-CBC with random iv 16 + HMAC-SHA256 (Encrypt-then-MAC) — works with public CommonCrypto
    uint8_t ivBytes[16];
    int status = SecRandomCopyBytes(kSecRandomDefault, 16, ivBytes);
    if (status != errSecSuccess) {
        for (int i=0;i<16;i++) ivBytes[i] = arc4random() & 0xFF;
    }
    NSData *iv = [NSData dataWithBytes:ivBytes length:16];
    NSData *cipher = nil;
    NSData *tag = nil;
    if (![self aesCBCEncrypt:plainData iv:iv key:key cipherOut:&cipher tagOut:&tag]) return nil;
    if (!cipher || !tag) return nil;
    NSMutableData *combined = [NSMutableData data];
    [combined appendData:iv];
    [combined appendData:cipher];
    [combined appendData:tag];
    NSString *b64 = [combined base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"enc_v1:%@", b64];
}

+ (nullable NSString *)decryptPrefValue:(nullable id)stored {
    if (!stored) return nil;
    if (![stored isKindOfClass:[NSString class]]) return nil;
    NSString *s = (NSString *)stored;
    if (s.length == 0) return s;
    if ([self isEncryptedString:s]) {
        NSString *dec = [self decryptString:s];
        return dec ?: s;
    }
    return s;
}

+ (nullable NSString *)encryptPrefValue:(nullable NSString *)plain {
    if (!plain) return nil;
    if (plain.length == 0) return plain;
    if ([self isEncryptedString:plain]) return plain;
    if (![self isEnabled]) return plain;
    return [self encryptString:plain] ?: plain;
}

+ (nullable NSString *)encryptForTransport:(nullable NSString *)plain { return [self encryptString:plain]; }
+ (nullable NSString *)decryptTransport:(nullable NSString *)encStr { return [self decryptIfNeeded:encStr]; }

#pragma mark - AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC)

+ (BOOL)aesCBCEncrypt:(NSData *)plain iv:(NSData *)iv key:(NSData *)key cipherOut:(NSData **)cipherOut tagOut:(NSData **)tagOut {
    if (!plain || !iv || !key || !cipherOut || !tagOut) return NO;
    if (key.length != 32 || iv.length != 16) return NO;
    size_t outLen = plain.length + kCCBlockSizeAES128;
    NSMutableData *cipher = [NSMutableData dataWithLength:outLen];
    size_t moved = 0;
    CCCryptorStatus s = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes, plain.bytes, plain.length, cipher.mutableBytes, cipher.length, &moved);
    if (s != kCCSuccess) return NO;
    cipher.length = moved;
    // tag = HMAC-SHA256(key, iv || cipher) truncated to 16 bytes
    NSMutableData *toMac = [NSMutableData data];
    [toMac appendData:iv];
    [toMac appendData:cipher];
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, toMac.bytes, toMac.length, hmac);
    NSData *tag = [NSData dataWithBytes:hmac length:16];
    *cipherOut = cipher;
    *tagOut = tag;
    return YES;
}

+ (nullable NSData *)aesCBCDecrypt:(NSData *)cipher iv:(NSData *)iv tag:(NSData *)tag key:(NSData *)key {
    if (!cipher || !iv || !tag || !key) return nil;
    if (key.length != 32 || iv.length != 16 || tag.length != 16) return nil;
    // Verify tag first (Encrypt-then-MAC)
    NSMutableData *toMac = [NSMutableData data];
    [toMac appendData:iv];
    [toMac appendData:cipher];
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, toMac.bytes, toMac.length, hmac);
    NSData *expected = [NSData dataWithBytes:hmac length:16];
    // timingSafe compare
    if (expected.length != tag.length) return nil;
    const uint8_t *a = expected.bytes;
    const uint8_t *b = tag.bytes;
    uint8_t diff = 0;
    for (NSUInteger i=0;i<expected.length;i++) diff |= a[i] ^ b[i];
    if (diff != 0) return nil;
    size_t outLen = cipher.length + kCCBlockSizeAES128;
    NSMutableData *plain = [NSMutableData dataWithLength:outLen];
    size_t moved = 0;
    CCCryptorStatus s = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes, cipher.bytes, cipher.length, plain.mutableBytes, plain.length, &moved);
    if (s != kCCSuccess) return nil;
    plain.length = moved;
    return plain;
}

// Legacy fallback: iv was 12 bytes padded to 16 with zeros (old GCM iv12 fallback path)
+ (nullable NSData *)aesCBCDecryptWithIV12:(NSData *)cipher iv12:(NSData *)iv12 tag:(NSData *)tag key:(NSData *)key {
    if (!cipher || !iv12 || !tag || !key) return nil;
    if (iv12.length != 12) return nil;
    NSMutableData *iv16 = [NSMutableData dataWithLength:16];
    memcpy(iv16.mutableBytes, iv12.bytes, 12);
    // remaining 4 bytes already zero
    return [self aesCBCDecrypt:cipher iv:iv16 tag:tag key:key];
}

@end
