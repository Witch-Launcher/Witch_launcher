#import "WitchJITCoordinator.h"
#import "ios_uikit_bridge.h"
#import "LauncherPreferences.h"
#import "WitchJITHelperClient.h"
#import "utils.h"
#include <stdlib.h>

NSString * const WitchJITStatusDidChangeNotification = @"WitchJITStatusDidChangeNotification";

/// Extensions iOS and the pairing-file guides actually use. A `.plist` is only
/// a weak candidate: the plist is validated by -importPairingFileAtURL:.
static BOOL WitchIsPairingFileName(NSString *name) {
    NSString *extension = name.pathExtension.lowercaseString;
    if (extension.length == 0) return YES;
    return [extension isEqualToString:@"plist"] ||
           [extension isEqualToString:@"mobiledevicepairing"] ||
           [extension isEqualToString:@"pairing"];
}

static NSString *const kWitchJITMethodKey = @"jit.method";
static NSString *const kWitchJITForceScriptKey = @"jit.force_script";

@implementation WitchJITCoordinator

+ (WitchJITCoordinator *)shared {
    static WitchJITCoordinator *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [WitchJITCoordinator new];
    });
    return shared;
}

#pragma mark - Preferences

- (NSString *)selectedMethod {
    id value = getPrefObject(kWitchJITMethodKey);
    return [value isKindOfClass:NSString.class] && [value length] > 0 ? value : @"auto";
}

- (void)setSelectedMethod:(NSString *)selectedMethod {
    setPrefObject(kWitchJITMethodKey, selectedMethod ?: @"auto");
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
}

- (BOOL)forceScript {
    return getPrefBool(kWitchJITForceScriptKey);
}

- (BOOL)isLiveContainer {
    return getenv("LC_HOME_PATH") != NULL;
}

- (BOOL)isBuiltInAvailable {
#if TARGET_OS_IOS
    if (@available(iOS 17.4, *)) {
        if (self.isLiveContainer) return NO;
        if (!getEntitlementValue(@"get-task-allow")) return NO;
        return WitchJITHelperClient.shared.isAvailable;
    }
#endif
    return NO;
}

- (BOOL)hasPairingFile {
    NSURL *url = self.pairingFileURL;
    return url ? [NSFileManager.defaultManager fileExistsAtPath:url.path] : NO;
}

- (BOOL)isBuiltInConfigured {
    return self.isBuiltInAvailable && self.hasPairingFile;
}

- (NSString *)resolvedMethod {
    NSString *selected = self.selectedMethod;
    if (![selected isEqualToString:@"auto"]) return selected;

    if (getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) return @"trollstore";
    if (self.isBuiltInConfigured) return @"builtin";
    return @"stikdebug";
}

- (BOOL)txmPresent {
    return DeviceHasJITFlags(JIT_FLAG_HAS_TXM);
}

- (NSString *)lastPreparationMessage {
    id value = getPrefObject(@"jit.last_prepare_message");
    return [value isKindOfClass:NSString.class] ? value : nil;
}

#pragma mark - Pairing file

- (NSURL *)pairingDirectoryURL {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                            inDomains:NSUserDomainMask].firstObject;
    return [documents URLByAppendingPathComponent:@"StikJIT" isDirectory:YES];
}

- (NSURL *)pairingFileURL {
    return [self.pairingDirectoryURL URLByAppendingPathComponent:@"pairingFile.plist"];
}

- (NSString *)pairingFileName {
    return self.hasPairingFile ? self.pairingFileURL.lastPathComponent : nil;
}

- (BOOL)importPairingFileAtURL:(NSURL *)url error:(NSError **)error {
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data) return NO;

    id plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:error];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = [NSError errorWithDomain:@"WitchJIT" code:10 userInfo:@{
            NSLocalizedDescriptionKey: @"That file is not a remote pairing plist."
        }];
        return NO;
    }
    NSDictionary *dictionary = (NSDictionary *)plist;
    NSData *publicKey = dictionary[@"public_key"];
    NSData *privateKey = dictionary[@"private_key"];
    NSString *identifier = dictionary[@"identifier"];
    if (![publicKey isKindOfClass:NSData.class] || publicKey.length != 32 ||
        ![privateKey isKindOfClass:NSData.class] || privateKey.length != 32 ||
        ![identifier isKindOfClass:NSString.class] || identifier.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"WitchJIT" code:11 userInfo:@{
            NSLocalizedDescriptionKey: @"That pairing file is missing a valid public_key, private_key or identifier."
        }];
        return NO;
    }

    NSError *directoryError = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:self.pairingDirectoryURL
                           withIntermediateDirectories:YES attributes:nil error:&directoryError];
    if (directoryError) {
        if (error) *error = directoryError;
        return NO;
    }
    BOOL written = [data writeToURL:self.pairingFileURL options:NSDataWritingAtomic error:error];
    if (written) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
    }
    return written;
}

- (BOOL)removePairingFile:(NSError **)error {
    if (!self.hasPairingFile) return YES;
    BOOL removed = [NSFileManager.defaultManager removeItemAtURL:self.pairingFileURL error:error];
    if (removed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
    }
    return removed;
}

- (NSData *)pairingDataWithError:(NSError **)error {
    return [NSData dataWithContentsOfURL:self.pairingFileURL options:0 error:error];
}

- (NSURL *)inboxURL {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                            inDomains:NSUserDomainMask].firstObject;
    return [documents URLByAppendingPathComponent:@"Inbox" isDirectory:YES];
}

+ (BOOL)handleIncomingPairingURL:(NSURL *)url {
    if (!url.isFileURL || !WitchIsPairingFileName(url.lastPathComponent)) return NO;

    BOOL strongCandidate = ![url.pathExtension.lowercaseString isEqualToString:@"plist"];
    NSError *error = nil;
    if ([[self shared] importPairingFileAtURL:url error:&error]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            showDialog(localize(@"jit.imported", nil), localize(@"jit.imported.message", nil));
        });
        return YES;
    }
    // A plain plist may belong to another feature: leave it alone silently.
    if (!strongCandidate) return NO;

    NSString *message = error.localizedDescription ?: @"Unknown error";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        showDialog(localize(@"jit.import_failed", nil), message);
    });
    return YES;
}

- (BOOL)importInboxPairingFileIfNeeded {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *inbox = self.inboxURL;
    NSArray<NSURL *> *entries = [manager contentsOfDirectoryAtURL:inbox
                                       includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:nil];
    if (entries.count == 0) return NO;

    entries = [entries sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *da = [a resourceValuesForKeys:@[NSURLContentModificationDateKey] error:nil][NSURLContentModificationDateKey] ?: NSDate.distantPast;
        NSDate *db = [b resourceValuesForKeys:@[NSURLContentModificationDateKey] error:nil][NSURLContentModificationDateKey] ?: NSDate.distantPast;
        return [db compare:da];
    }];

    for (NSURL *url in entries) {
        if (!WitchIsPairingFileName(url.lastPathComponent)) continue;
        BOOL isDirectory = NO;
        if (![manager fileExistsAtPath:url.path isDirectory:&isDirectory] || isDirectory) continue;
        NSError *error = nil;
        if ([self importPairingFileAtURL:url error:&error]) {
            [manager removeItemAtURL:url error:nil];
            NSLog(@"[WitchJIT] Imported pairing file from Documents/Inbox");
            return YES;
        }
    }
    return NO;
}

#pragma mark - Script

- (NSString *)scriptBase64 {
    NSString *path = [NSBundle.mainBundle pathForResource:@"UniversalJIT26" ofType:@"js"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    return data.length > 0 ? [data base64EncodedStringWithOptions:0] : nil;
}

- (BOOL)shouldForceScript {
    return self.forceScript || DeviceNeedsDebugJITMapping() || DeviceHasJITFlags(JIT_FLAG_IS_IOS_26);
}

#pragma mark - Helper requests

- (void)prepareWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    NSError *error = nil;
    NSData *pairing = [self pairingDataWithError:&error];
    if (!pairing) {
        if (completion) completion(nil, error ?: [NSError errorWithDomain:@"WitchJIT" code:20 userInfo:@{
            NSLocalizedDescriptionKey: @"Import a pairing file before enabling Built-in StikJIT."
        }]);
        return;
    }
    [WitchJITHelperClient.shared prepareWithPairingData:pairing completion:^(NSDictionary *response, NSError *requestError) {
        NSString *message = [response[@"message"] isKindOfClass:NSString.class] ? response[@"message"] : nil;
        if (message.length > 0) setPrefObject(@"jit.last_prepare_message", message);
        [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
        if (completion) completion(response, requestError);
    }];
}

- (void)enableBuiltInJITWithCompletion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (!self.isBuiltInAvailable) {
        if (completion) completion(NO, @"Built-in StikJIT is not available on this device or installation. It needs iOS 17.4+, get-task-allow, and the embedded JIT helper.");
        return;
    }
    NSError *error = nil;
    NSData *pairing = [self pairingDataWithError:&error];
    if (!pairing) {
        NSString *message = error.localizedDescription ?: @"Import a remote pairing file first.";
        if (completion) completion(NO, message);
        return;
    }
    NSString *script = [self scriptBase64];
    if (script.length == 0) {
        if (completion) completion(NO, @"Witch's UniversalJIT26.js is missing from this installation.");
        return;
    }

    __block BOOL finished = NO;
    __weak typeof(self) weakSelf = self;
    void (^finish)(BOOL, NSString *) = ^(BOOL success, NSString *message) {
        if (finished) return;
        finished = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, message);
            [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:weakSelf];
        });
    };

    [WitchJITHelperClient.shared enableWithTargetPID:(int32_t)getpid()
                                         pairingData:pairing
                                        scriptBase64:script
                                         forceScript:[self shouldForceScript]
                                          completion:^(NSDictionary *response, NSError *requestError) {
        BOOL success = [response[@"success"] boolValue];
        NSString *message = [response[@"message"] isKindOfClass:NSString.class] ? response[@"message"] : nil;
        if (!success) {
            finish(NO, message.length > 0 ? message : (requestError.localizedDescription ?: @"Built-in StikJIT failed."));
        }
        // A successful enable response arrives only after the debugger detaches,
        // which happens when the game ends. Readiness is reported by the poll below.
    }];

    // Wait for the debugger to attach and mark the process debugged. On iOS 26+
    // isJITEnabled() also requires the debugger to stay attached (P_TRACED).
    __block NSInteger attempts = 0;
    void (^poll)(void) = ^{
        if (finished) return;
        if (isJITEnabled(NO)) {
            finish(YES, nil);
            return;
        }
        attempts++;
        if (attempts >= 1200) { // 300 seconds at 250 ms
            finish(NO, @"Built-in StikJIT did not attach within 5 minutes. Connect LocalDevVPN, check the pairing file, then try again.");
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), poll);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), poll);
}

- (void)resetDDIWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    [WitchJITHelperClient.shared resetDDIWithCompletion:^(NSDictionary *response, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
        if (completion) completion(response, error);
    }];
}

- (void)requestExternalJITEnable {
    requestExternalJITEnable();
}

@end
