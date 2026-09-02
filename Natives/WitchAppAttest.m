#import "WitchAppAttest.h"
#import <DeviceCheck/DeviceCheck.h>
#import <CommonCrypto/CommonDigest.h>

@implementation WitchAppAttest

+ (BOOL)isSupported {
    if (@available(iOS 14.0, *)) {
        return [DCAppAttestService sharedService].isSupported;
    }
    return NO;
}

+ (void)attestIfNeededWithCompletion:(void(^)(NSString *assertionToken, NSError *error))completion {
    if (![self isSupported]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchAppAttest" code:404 userInfo:@{NSLocalizedDescriptionKey: @"AppAttest not supported"}]);
        return;
    }
    if (@available(iOS 14.0, *)) {
        DCAppAttestService *service = [DCAppAttestService sharedService];
        NSString *keyId = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.keyId"];
        if (keyId) {
            // Already have key, generate assertion for a challenge
            NSString *challenge = [[NSUUID UUID] UUIDString];
            [self generateAssertionForChallenge:challenge completion:completion];
            return;
        }
        // Generate new key
        [service generateKeyWithCompletionHandler:^(NSString *keyId, NSError *error) {
            if (error || !keyId) {
                if (completion) completion(nil, error);
                return;
            }
            [[NSUserDefaults standardUserDefaults] setObject:keyId forKey:@"witch.appattest.keyId"];
            // Attest the key
            NSData *challenge = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
            NSData *hash = [self sha256:challenge];
            [service attestKey:keyId clientDataHash:hash completionHandler:^(NSData *attestation, NSError *error) {
                if (error || !attestation) {
                    if (completion) completion(nil, error);
                    return;
                }
                // Send attestation to Worker for verification (worker will verify with Apple)
                // For now, just store attestation and generate an assertion
                [[NSUserDefaults standardUserDefaults] setObject:[attestation base64EncodedStringWithOptions:0] forKey:@"witch.appattest.attestation"];
                NSString *challenge2 = [[NSUUID UUID] UUIDString];
                [self generateAssertionForChallenge:challenge2 completion:completion];
            }];
        }];
    }
}

+ (void)generateAssertionForChallenge:(NSString *)challenge completion:(void(^)(NSString *assertion, NSError *error))completion {
    if (![self isSupported]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"WitchAppAttest" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Not supported"}]);
        return;
    }
    if (@available(iOS 14.0, *)) {
        NSString *keyId = [[NSUserDefaults standardUserDefaults] stringForKey:@"witch.appattest.keyId"];
        if (!keyId) {
            [self attestIfNeededWithCompletion:completion];
            return;
        }
        NSData *challengeData = [challenge dataUsingEncoding:NSUTF8StringEncoding];
        NSData *hash = [self sha256:challengeData];
        [[DCAppAttestService sharedService] generateAssertion:keyId clientDataHash:hash completionHandler:^(NSData *assertion, NSError *error) {
            if (error || !assertion) {
                if (completion) completion(nil, error);
                return;
            }
            NSString *token = [assertion base64EncodedStringWithOptions:0];
            // Also include keyId and challenge for server verification
            NSString *combined = [NSString stringWithFormat:@"%@.%@.%@", keyId, challenge, token];
            if (completion) completion(combined, nil);
        }];
    }
}

+ (NSData *)sha256:(NSData *)data {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    return [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
}

@end
