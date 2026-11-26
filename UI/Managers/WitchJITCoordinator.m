#import "WitchJITCoordinator.h"
#import "ios_uikit_bridge.h"
#import "LauncherPreferences.h"
#import "WitchJITHelperClient.h"
#import "WitchVPNHelper.h"
#import "utils.h"
#include <stdlib.h>
#include <unistd.h>

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
// NSUserDefaults mirror of the JIT method. The preference file keeps the
// method in a nested section ("jit" -> "method"), which only survives a
// relaunch when the preference layer can rewrite that section; the mirror is
// the value the launcher reads back, so the choice is never lost.
static NSString *const kWitchJITMethodDefaultsKey = @"witch.jit.method";

/// Every method id the picker offers and the resolver understands. A stored
/// value that is not in this list (legacy or hand-edited) falls back to
/// "auto" instead of being handed to a flow that does not exist.
static NSArray<NSString *> *WitchJITSupportedMethods(void) {
    static NSArray<NSString *> *methods;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        methods = @[@"auto", @"builtin", @"stikdebug", @"wait", @"trollstore", @"sidestore", @"livecontainer"];
    });
    return methods;
}

static BOOL WitchJITMethodIsSupported(NSString *method) {
    if (![method isKindOfClass:NSString.class] || method.length == 0) return NO;
    return [WitchJITSupportedMethods() containsObject:method];
}

@implementation WitchJITCoordinator

+ (WitchJITCoordinator *)shared {
    static WitchJITCoordinator *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [WitchJITCoordinator new];
    });
    return shared;
}

/// Every method id the picker offers, in display order. The JIT settings
/// screen reads this list so the picker and the resolver always agree.
+ (NSArray<NSString *> *)supportedMethods {
    return WitchJITSupportedMethods();
}

#pragma mark - Preferences

- (NSString *)selectedMethod {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *stored = [defaults stringForKey:kWitchJITMethodDefaultsKey];
    if (WitchJITMethodIsSupported(stored)) return stored;

    // Legacy location: older builds kept the method in the preference file.
    id legacy = getPrefObject(kWitchJITMethodKey);
    if (WitchJITMethodIsSupported(legacy)) {
        [defaults setObject:legacy forKey:kWitchJITMethodDefaultsKey];
        [defaults synchronize];
        return legacy;
    }
    // Unknown or hand-edited value: fall back to auto instead of handing a
    // method that does not exist to the launch flow.
    return @"auto";
}

- (void)setSelectedMethod:(NSString *)selectedMethod {
    NSString *method = WitchJITMethodIsSupported(selectedMethod) ? selectedMethod : @"auto";
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:method forKey:kWitchJITMethodDefaultsKey];
    [defaults synchronize];
    // Mirror the choice into the preference file too, so a build that only
    // knows the "jit.method" key (and the launcher log) sees the same value.
    // The NSUserDefaults copy stays the primary one: it is readable before
    // the preference layer is initialized.
    setPrefObject(kWitchJITMethodKey, method);
    NSLog(@"[WitchJIT] Selected JIT method: %@", method);
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
}

- (BOOL)forceScript {
    return getPrefBool(kWitchJITForceScriptKey);
}

- (BOOL)isLiveContainer {
    if (getenv("LC_HOME_PATH") != NULL) return YES;
    // LiveContainer injects LCAppInfo.plist into the app bundle when it
    // launches it, so the file is a second marker for a LiveContainer launch.
    return [self liveContainerAppInfoPath] != nil;
}

// LiveContainer writes the app's JIT configuration (LCAppInfo.plist) into the
// bundle it launches. Its presence means LiveContainer is in charge of the
// debugger and of the JIT script.
- (NSString *)liveContainerAppInfoPath {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    if (bundlePath.length == 0) return nil;
    NSString *path = [bundlePath stringByAppendingPathComponent:@"LCAppInfo.plist"];
    return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
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
    if (![selected isEqualToString:@"auto"]) {
        // A method whose environment is missing (no TrollStore entitlement, no
        // SideStore, not inside LiveContainer) is reported through the
        // built-in flow: it is the only one whose failure ends in a dialog
        // the user can act on instead of a waiting screen with no way out.
        if ([self missingEnvironmentReasonForMethod:selected]) return @"builtin";
        return selected;
    }

    if (getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) return @"trollstore";
    if (self.isBuiltInConfigured) return @"builtin";
    return @"stikdebug";
}

// The reason the selected method cannot run on this device, or nil when the
// environment it needs is there.
- (NSString *)missingEnvironmentReasonForMethod:(NSString *)method {
    if ([method isEqualToString:@"builtin"]) {
        if (!self.isBuiltInAvailable) {
            if (self.isLiveContainer) {
                return localize(@"jit.method.builtin.unavailable.livecontainer", nil);
            }
            return localize(@"jit.method.builtin.unavailable.message", nil);
        }
        if (!self.hasPairingFile) {
            return localize(@"jit.method.builtin.unavailable.pairing", nil);
        }
        return nil;
    }
    if ([method isEqualToString:@"trollstore"]) {
        if (!getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) {
            return localize(@"jit.method.trollstore.unavailable.message", nil);
        }
        return nil;
    }
    if ([method isEqualToString:@"sidestore"]) {
        if (![self sideStoreInstalled]) {
            return localize(@"jit.method.sidestore.unavailable.message", nil);
        }
        return nil;
    }
    if ([method isEqualToString:@"livecontainer"]) {
        if (!self.isLiveContainer) {
            return localize(@"jit.method.livecontainer.unavailable.message", nil);
        }
        return nil;
    }
    return nil;
}

// SideStore registers the sidestore:// URL scheme, so the scheme being
// handled means the app is installed and can take the JIT request. The
// scheme is listed in LSApplicationQueriesSchemes, otherwise canOpenURL:
// would always answer NO.
- (BOOL)sideStoreInstalled {
    NSURL *url = [NSURL URLWithString:@"sidestore://"];
    if (!url) return NO;
    return [UIApplication.sharedApplication canOpenURL:url];
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
    // The selected method may be one whose environment is missing. Report it
    // first: the reason matters more than the method that asked for it.
    NSString *missing = [self missingEnvironmentReasonForMethod:self.selectedMethod];
    if (missing) {
        if (completion) completion(NO, missing);
        return;
    }
    // The selected method can also be "builtin" itself, whose own environment
    // (helper, pairing file) the reason above already checks.
    if (!self.isBuiltInAvailable) {
        if (completion) completion(NO, localize(@"jit.method.builtin.unavailable.message", nil));
        return;
    }
    NSError *error = nil;
    NSData *pairing = [self pairingDataWithError:&error];
    if (!pairing) {
        NSString *message = error.localizedDescription ?: localize(@"jit.method.builtin.unavailable.pairing", nil);
        if (completion) completion(NO, message);
        return;
    }
    NSString *script = [self scriptBase64];
    if (script.length == 0) {
        if (completion) completion(NO, @"Witch's UniversalJIT26.js is missing from this installation.");
        return;
    }

    // Detect a missing LocalDevVPN before the helper starts. The helper
    // reaches the device through that tunnel, so without it the debugger
    // never attaches: the launch would run on without a JIT script and the
    // runtime's first unserviced trap would kill the app. Refuse with an
    // actionable message instead.
    if (![WitchVPNHelper isInstalled]) {
        NSLog(@"[WitchJIT] Built-in StikJIT needs LocalDevVPN, which is not installed");
        if (completion) completion(NO, localize(@"jit.vpn.install.message", nil));
        return;
    }
    [WitchVPNHelper probeWithCompletion:^(BOOL reachable) {
        if (!reachable) {
            NSLog(@"[WitchJIT] Built-in StikJIT: LocalDevVPN is not reachable");
            if (completion) completion(NO, localize(@"jit.vpn.connect.message", nil));
            return;
        }
        [self startBuiltInJITWithPairing:pairing script:script completion:completion];
    }];
}

- (void)startBuiltInJITWithPairing:(NSData *)pairing
                             script:(NSString *)script
                         completion:(void (^)(BOOL, NSString * _Nullable))completion {
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
    // A repeating timer instead of a self-referencing block: the block would
    // capture itself, which is both a retain cycle and a "captured before it
    // was initialized" warning.
    __block NSInteger attempts = 0;
    __block dispatch_source_t pollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                                 dispatch_get_main_queue());
    dispatch_source_set_timer(pollTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                              (uint64_t)(0.25 * NSEC_PER_SEC),
                              (uint64_t)(0.05 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(pollTimer, ^{
        if (finished) {
            dispatch_source_cancel(pollTimer);
            pollTimer = nil;
            return;
        }
        if (isJITEnabled(NO)) {
            dispatch_source_cancel(pollTimer);
            pollTimer = nil;
            finish(YES, nil);
            return;
        }
        attempts++;
        if (attempts >= 1200) { // 300 seconds at 250 ms
            dispatch_source_cancel(pollTimer);
            pollTimer = nil;
            finish(NO, @"Built-in StikJIT did not attach within 5 minutes. Connect LocalDevVPN, check the pairing file, then try again.");
            return;
        }
    });
    dispatch_resume(pollTimer);
}

- (void)resetDDIWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    [WitchJITHelperClient.shared resetDDIWithCompletion:^(NSDictionary *response, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WitchJITStatusDidChangeNotification object:self];
        if (completion) completion(response, error);
    }];
}

- (void)requestExternalJITEnable {
    // The coordinator owns every method: each one asks its own environment for
    // JIT and reports a clear error when that environment is missing, instead
    // of leaving the launch to fail with an unserviced JIT trap.
    NSString *method = self.resolvedMethod;
    if ([method isEqualToString:@"trollstore"]) {
        [self requestTrollStoreJIT];
        return;
    }
    if ([method isEqualToString:@"sidestore"]) {
        [self requestSideStoreJIT];
        return;
    }
    if ([method isEqualToString:@"livecontainer"]) {
        [self requestLiveContainerJIT];
        return;
    }
    if ([method isEqualToString:@"builtin"]) {
        // The built-in flow failed, or the selected method's environment is
        // missing and the resolver routed the launch through it. The
        // launcher's "Use StikDebug" action ends up here, so fall through to
        // the generic external request (StikDebug, with the SideStore URL as
        // its own fallback) instead of leaving the button without any effect.
        NSString *missing = [self missingEnvironmentReasonForMethod:self.selectedMethod];
        if (missing) {
            NSLog(@"[WitchJIT] %@", missing);
        }
        requestExternalJITEnable();
        return;
    }
    requestExternalJITEnable();
}

- (void)requestTrollStoreJIT {
    if (!getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) {
        NSLog(@"[WitchJIT] TrollStore was selected but this installation has no JIT entitlement");
        showDialog(localize(@"jit.method.trollstore.unavailable.title", nil),
                   localize(@"jit.method.trollstore.unavailable.message", nil));
        return;
    }
    NSLog(@"[WitchJIT] Requesting TrollStore JIT");
    requestExternalJITEnable();
}

- (void)requestSideStoreJIT {
    if (![self sideStoreInstalled]) {
        NSLog(@"[WitchJIT] SideStore was selected but the sidestore:// scheme is not handled");
        showDialog(localize(@"jit.method.sidestore.unavailable.title", nil),
                   localize(@"jit.method.sidestore.unavailable.message", nil));
        return;
    }
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
    // Same URL the generic external request uses as its SideStore fallback:
    // sidestore://enable-jit?bundle-id=<Witch>. SideStore keeps its VPN
    // attached and enables JIT for the app out of process, so the pairing
    // happens there and not in Witch.
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = @"sidestore";
    components.host = @"enable-jit";
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"bundle-id" value:bundleID]];
    NSURL *url = components.URL;
    if (!url) {
        NSLog(@"[WitchJIT] Could not build the SideStore JIT URL");
        showDialog(localize(@"jit.method.sidestore.unavailable.title", nil),
                   localize(@"jit.method.sidestore.unavailable.message", nil));
        return;
    }
    NSLog(@"[WitchJIT] Requesting SideStore JIT (%@)", url.absoluteString);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
            if (success) return;
            NSLog(@"[WitchJIT] SideStore could not be opened");
            showDialog(localize(@"jit.method.sidestore.unavailable.title", nil),
                       localize(@"jit.method.sidestore.unavailable.message", nil));
        }];
    });
}

- (void)requestLiveContainerJIT {
    if (!self.isLiveContainer) {
        NSLog(@"[WitchJIT] LiveContainer was selected but Witch is not running inside it");
        showDialog(localize(@"jit.method.livecontainer.unavailable.title", nil),
                   localize(@"jit.method.livecontainer.unavailable.message", nil));
        return;
    }
    // LiveContainer runs the debugger and UniversalJIT26.js (LCAppInfo.plist)
    // for us: there is nothing to open, the game waits for LiveContainer's JIT.
    NSLog(@"[WitchJIT] LiveContainer provides the JIT environment");
    if (![self liveContainerAppInfoPath]) {
        // LiveContainer is in charge, but it did not inject a JIT script into
        // this launch. Say so instead of leaving the user on a waiting screen
        // that never resolves.
        NSLog(@"[WitchJIT] LiveContainer launched Witch without LCAppInfo.plist: no JIT script");
        showDialog(localize(@"jit.method.livecontainer.unavailable.title", nil),
                   localize(@"jit.method.livecontainer.no_script.message", nil));
    }
}

@end
