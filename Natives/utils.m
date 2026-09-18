#import <SafariServices/SafariServices.h>

#include "jni.h"
#include <dlfcn.h>
#include <os/lock.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/sysctl.h>
#include <sys/proc.h>

#include "utils.h"
#import "LauncherPreferences.h"

CFTypeRef SecTaskCopyValueForEntitlement(void* task, NSString* entitlement, CFErrorRef  _Nullable *error);
void* SecTaskCreateFromSelf(CFAllocatorRef allocator);

BOOL getEntitlementValue(NSString *key) {
    void *secTask = SecTaskCreateFromSelf(NULL);
    CFTypeRef value = SecTaskCopyValueForEntitlement(secTask, key, nil);
    CFRelease(secTask);
    if (value == nil) {
        return NO;
    }
    CFRelease(value);
    return ![(__bridge id)value isKindOfClass:NSNumber.class] || [(__bridge id)value boolValue];
}

BOOL processIsCurrentlyDebugged(void) {
    // SideStore / StikDebug attach to an already-running process via debugserver.
    // Parent stays launchd (pid 1); P_TRACED is the reliable attached-debugger bit.
    struct kinfo_proc info = {0};
    size_t size = sizeof(info);
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return NO;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

BOOL isJITEnabled(BOOL checkCSFlags) {
    if (!checkCSFlags && (getEntitlementValue(@"dynamic-codesigning") || isJailbroken)) {
        return YES;
    }

    int flags = 0;
    csops(getpid(), 0, &flags, sizeof(flags));
    BOOL csDebugged = (flags & CS_DEBUGGED) != 0;
    BOOL traced = processIsCurrentlyDebugged();
    if (!csDebugged && !traced) {
        return NO;
    }

    // iOS 26+/27 patched JRE services RX mappings through brk #0xf00d while the
    // debugger stays attached. CS_DEBUGGED after a SideStore detach is not enough.
    if (DeviceNeedsDebugJITMapping()) {
        return traced;
    }
    // iOS 18 and other classic JIT: CS_DEBUGGED survives detach; P_TRACED covers
    // the window where StikDebug is attached but csops has not yet reported it.
    return YES;
}

void requestExternalJITEnable(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *pidString = [NSString stringWithFormat:@"%d", getpid()];

    void (^openURL)(NSURL *) = ^(NSURL *url) {
        if (!url) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        });
    };

    if (getEntitlementValue(@"com.apple.private.local.sandboxed-jit")) {
        NSString *urlString = [NSString stringWithFormat:@"apple-magnifier://enable-jit?bundle-id=%@", bundleID];
        NSLog(@"[JIT] Requesting TrollStore JIT");
        openURL([NSURL URLWithString:urlString]);
        return;
    }

    NSURLComponents *components = [NSURLComponents new];
    components.scheme = @"stikdebug";
    components.host = @"enable-jit";
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [items addObject:[NSURLQueryItem queryItemWithName:@"bundle-id" value:bundleID]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"pid" value:pidString]];

    // Custom UniversalJIT26.js (brk 0xf00d / 0x6a) must be sent as script-data on
    // iOS 26+ so StikDebug does not need a pre-installed matching file.
    if (DeviceNeedsDebugJITMapping() || DeviceHasJITFlags(JIT_FLAG_IS_IOS_26)) {
        NSString *scriptPath = [NSBundle.mainBundle pathForResource:@"UniversalJIT26" ofType:@"js"];
        NSData *scriptData = scriptPath ? [NSData dataWithContentsOfFile:scriptPath] : nil;
        if (scriptData.length > 0) {
            [items addObject:[NSURLQueryItem queryItemWithName:@"script-data"
                                                        value:[scriptData base64EncodedStringWithOptions:0]]];
        } else {
            [items addObject:[NSURLQueryItem queryItemWithName:@"script-name" value:@"universal.js"]];
        }
    }
    components.queryItems = items;
    NSURL *stikURL = components.URL;
    NSURL *sideURL = [NSURL URLWithString:
        [NSString stringWithFormat:@"sidestore://enable-jit?bundle-id=%@", bundleID]];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!stikURL) {
            NSLog(@"[JIT] Could not build StikDebug URL");
            return;
        }
        NSLog(@"[JIT] Requesting StikDebug JIT (pid %@, iOS26=%d)", pidString,
              DeviceHasJITFlags(JIT_FLAG_IS_IOS_26));
        void (^trySideStore)(void) = ^{
            if (!sideURL) {
                return;
            }
            [UIApplication.sharedApplication openURL:sideURL options:@{} completionHandler:^(BOOL sideSuccess) {
                if (!sideSuccess) {
                    NSLog(@"[JIT] SideStore URL failed; wait for manual enable");
                }
            }];
        };

        [UIApplication.sharedApplication openURL:stikURL options:@{} completionHandler:^(BOOL success) {
            if (success) {
                return;
            }
            // Long script-data URLs can fail; retry with pid/bundle-id only.
            NSURLComponents *retry = [NSURLComponents new];
            retry.scheme = @"stikdebug";
            retry.host = @"enable-jit";
            retry.queryItems = @[
                [NSURLQueryItem queryItemWithName:@"bundle-id" value:bundleID],
                [NSURLQueryItem queryItemWithName:@"pid" value:pidString]
            ];
            NSURL *retryURL = retry.URL;
            if (!retryURL || [retryURL isEqual:stikURL]) {
                NSLog(@"[JIT] StikDebug URL failed; trying SideStore");
                trySideStore();
                return;
            }
            NSLog(@"[JIT] StikDebug script-data URL failed; retrying without script");
            [UIApplication.sharedApplication openURL:retryURL options:@{} completionHandler:^(BOOL retrySuccess) {
                if (!retrySuccess) {
                    NSLog(@"[JIT] StikDebug retry failed; trying SideStore");
                    trySideStore();
                }
            }];
        }];
    });
}

void openLink(UIViewController* sender, NSURL* link) {
    if (NSClassFromString(@"SFSafariViewController") == nil) {
        NSData *data = [link.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
        CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        [filter setValue:data forKey:@"inputMessage"];
        UIImage *image = [UIImage imageWithCIImage:filter.outputImage scale:1.0 orientation:UIImageOrientationUp];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(300, 300), NO, 0.0);
        CGRect frame = CGRectMake(0, 0, 300, 300);
        [image drawInRect:frame];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:frame];
        imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
            message:link.absoluteString
            preferredStyle:UIAlertControllerStyleAlert];

        UIViewController *vc = UIViewController.new;
        vc.view = imageView;
        [alert setValue:vc forKey:@"contentViewController"];

        UIAlertAction* doneAction = [UIAlertAction actionWithTitle:localize(@"Done", nil) style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:doneAction];
        [sender presentViewController:alert animated:YES completion:nil];
    } else {
        SFSafariViewController *vc = [[SFSafariViewController alloc] initWithURL:link];
        [sender presentViewController:vc animated:YES completion:nil];
    }
}

NSMutableDictionary* parseJSONFromFile(NSString *path) {
    NSError *error;

    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (content == nil) {
        NSLog(@"[ParseJSON] Error: could not read %@: %@", path, error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }

    NSData* data = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        NSLog(@"[ParseJSON] Error: could not parse JSON: %@", error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }
    return dict;
}

NSError* saveJSONToFile(NSDictionary *dict, NSString *path) {
    // TODO: handle rename
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData == nil) {
        return error;
    }
    BOOL success = [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!success) {
        return error;
    }
    return nil;
}

/// Best-match device language against the .lproj packs shipped in the bundle.
/// Cached for the lifetime of the process (device language needs relaunch anyway).
static NSString *WitchBestMatchLanguage(void) {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *main = NSBundle.mainBundle;
        NSRegularExpression *tagExpr = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z]{2,3}(-[A-Za-z0-9]+)*$"
                                                                                 options:0 error:nil];
        NSMutableArray<NSString *> *available = [NSMutableArray array];
        for (NSString *p in [main pathsForResourcesOfType:@"lproj" inDirectory:nil]) {
            NSString *code = [[p lastPathComponent] stringByDeletingPathExtension];
            if (code.length == 0 || [code isEqualToString:@"Base"]) continue;
            // Only real language packs (same rule as the Settings language list).
            if ([tagExpr numberOfMatchesInString:code options:0 range:NSMakeRange(0, code.length)] == 0) continue;
            [available addObject:code];
        }
        if (available.count == 0) available = [@[@"en"] mutableCopy];
        NSString *best = [NSBundle preferredLocalizationsFromArray:available
                                                    forPreferences:NSLocale.preferredLanguages].firstObject;
        if (!best || ![main pathForResource:best ofType:@"lproj"]) best = @"en";
        cached = [best copy];
    });
    return cached;
}

/// One-time migration: the old default stored @"en" for launcher.language,
/// which pinned everyone to English. Move it to @"auto" (device language).
static void WitchMigrateLanguageDefaultOnce(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
            if (![ud boolForKey:@"witch.lang_migrated_auto_v1"]) {
                [ud setBool:YES forKey:@"witch.lang_migrated_auto_v1"];
                extern id getPrefObject(NSString *key);
                extern void setPrefObject(NSString *key, id value);
                id cur = getPrefObject(@"launcher.language");
                if ([cur isKindOfClass:[NSString class]] && [cur isEqualToString:@"en"]) {
                    setPrefObject(@"launcher.language", @"auto");
                }
            }
        } @catch(...) {}
    });
}

NSString* localize(NSString* key, NSString* comment) {
    if (!key) return @"";
    WitchMigrateLanguageDefaultOnce();
    // 1) Explicit choice (anything except empty/"auto"), else device language.
    NSString *forcedLang = nil;
    @try {
        extern id getPrefObject(NSString *key);
        id val = getPrefObject(@"launcher.language");
        if ([val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0
            && ![(NSString*)val isEqualToString:@"auto"]) {
            forcedLang = val;
        }
    } @catch(...) {}
    NSString *lang = forcedLang ?: WitchBestMatchLanguage();
    if (lang) {
        NSString *path = [[NSBundle mainBundle] pathForResource:lang ofType:@"lproj"];
        if (path) {
            NSBundle *bundle = [NSBundle bundleWithPath:path];
            NSString *v = [bundle localizedStringForKey:key value:nil table:nil];
            if (v && ![v isEqualToString:key]) return v;
            // Fallback to English for untranslated keys.
            NSString *enPath = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
            NSBundle *enBundle = [NSBundle bundleWithPath:enPath];
            NSString *enVal = [enBundle localizedStringForKey:key value:key table:nil];
            if (enVal && ![enVal isEqualToString:key]) return enVal;
            return key;
        }
    }
    NSString *value = [[NSBundle mainBundle] localizedStringForKey:key value:key table:nil];
    if ([value isEqualToString:key]) {
        value = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:key table:nil];
    }

    return value ?: key;
}

void customNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...)
{
    va_list ap; 
    va_start (ap, format);
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    printf("%s", [body UTF8String]);
    if (![format hasSuffix:@"\n"]) {
        printf("\n");
    }
    va_end (ap);
}

CGFloat MathUtils_dist(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) {
    const CGFloat x = (x2 - x1);
    const CGFloat y = (y2 - y1);
    return (CGFloat) hypot(x, y);
}

//Ported from https://www.arduino.cc/reference/en/language/functions/math/map/
CGFloat MathUtils_map(CGFloat x, CGFloat in_min, CGFloat in_max, CGFloat out_min, CGFloat out_max) {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

CGFloat dpToPx(CGFloat dp) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return dp * screenScale;
}

CGFloat pxToDp(CGFloat px) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return px / screenScale;
}

void setButtonPointerInteraction(UIButton *button) {
    button.pointerInteractionEnabled = YES;
    button.pointerStyleProvider = ^ UIPointerStyle* (UIButton* button, UIPointerEffect* proposedEffect, UIPointerShape* proposedShape) {
        UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:button];
        return [NSClassFromString(@"UIPointerStyle") styleWithEffect:[NSClassFromString(@"UIPointerHighlightEffect") effectWithPreview:preview] shape:proposedShape];
    };
}

__attribute__((noinline,optnone,naked))
void* JIT26CreateRegionLegacy(size_t len) {
    asm("brk #0x69 \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void* JIT26PrepareRegion(void *addr, size_t len) {
    asm("mov x16, #1 \n"
        "brk #0xf00d \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
   asm("mov x16, #2 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26SetDetachAfterFirstBr(BOOL value) {
   asm("mov x16, #3 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26PrepareRegionForPatching(void *addr, size_t size) {
   asm("mov x16, #4 \n"
       "brk #0xf00d \n"
       "ret");
}
void JIT26SendJITScript(NSString* script) {
    NSCAssert(script, @"Script must not be nil");
    BreakSendJITScript((char*)script.UTF8String, script.length);
}

BOOL DeviceCanCreateRXMap(void) {
    // This is only guaranteed to be accurate when JIT is already enabled. Obviously this is only useful for vphone and similar internal environments where JIT is always enabled.
    uint32_t *map = mmap(NULL, getpagesize(), PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_SHARED, -1, 0);
    if (map == MAP_FAILED) {
        NSLog(@"DeviceCanCreateRXMap: mmap failed: %s", strerror(errno));
        return NO;
    }
    *map = 0xFFFFFFFF;
    int ret = mprotect(map, getpagesize(), PROT_READ | PROT_EXEC);
    munmap(map, getpagesize());
    return ret == 0;
}
static NSString* hardwareMachineIdentifier(void) {
    char buffer[64];
    size_t len = sizeof(buffer);
    if (sysctlbyname("hw.machine", buffer, &len, NULL, 0) != 0) {
        return nil;
    }
    return @(buffer);
}

// "iPhone13,2" -> 13.2 ; "iPad8,11" -> 8.11 (same parsing as StikDebug)
static double hardwareDeviceVersion(NSString *identifier) {
    if (!identifier) return -1;
    NSCharacterSet *nonNumbers = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789,"] invertedSet];
    NSString *digits = [[identifier componentsSeparatedByCharactersInSet:nonNumbers] componentsJoinedByString:@""];
    digits = [digits stringByReplacingOccurrencesOfString:@"," withString:@"."];
    return digits.doubleValue;
}

static BOOL DeviceLikelyHasTXMFromChipID(void) {
    NSUInteger (*MGGetSInt64Answer)(NSString *) = dlsym(RTLD_DEFAULT, "MGGetSint64Answer");
    if (MGGetSInt64Answer == NULL) {
        // Failing closed would select the legacy mapping path on the exact
        // systems where Apple made Preboot unreadable. Prefer the TXM-safe
        // path on recent systems when MobileGestalt is unavailable.
        if (@available(iOS 19.0, *)) return YES;
        return NO;
    }

    switch (MGGetSInt64Answer(@"ChipID")) {
        case 0x8020: // A12
        case 0x8027: // A12X/Z
            return NO;
        case 0x8030: // A13
        case 0x8101: // A14
        case 0x8103: // M1
            if (@available(iOS 27.0, *)) return YES;
            return NO;
        default:
            if (@available(iOS 19.0, *)) return YES;
            return NO;
    }
}

BOOL DeviceHasTXMReal(void) {
    // The launcher's TXM classification MUST match the debugger's (StikDebug
    // 3.1.6+, ProcessInfo+TXM.swift / PR #416): StikDebug decides whether to
    // run the app's JIT26 universal script from its own TXM detection, while
    // this app decides whether to send the brk 0x69/0xf00d protocol from
    // these flags. Any mismatch leaves the handshake unanswered (hang or
    // "switch to Universal script") or grants plain JIT on a W^X-enforced
    // device (SIGBUS/SIGSEGV).
    if (getPrefBool(@"debug.force_txm")) {
        NSLog(@"[JIT] TXM forced via debug.force_txm");
        return YES;
    }

    // Try the direct active-Preboot path before falling back to legacy
    // directory enumeration.
    static const char *modernTXMPath =
        "/System/Volumes/Preboot/boot/usr/standalone/firmware/FUD/"
        "Ap,TrustedExecutionMonitor.img4";
    if (access(modernTXMPath, F_OK) == 0) return YES;

    DIR *d = opendir("/private/preboot");
    if (!d) {
        // /private/preboot is no longer readable on iOS 26.6 and iOS 27.
        // Fall back to a conservative hardware/OS heuristic.
        return DeviceLikelyHasTXMFromChipID();
    }

    struct dirent *dir;
    BOOL hasTXM = NO;
    while ((dir = readdir(d)) != NULL) {
        if(strlen(dir->d_name) == 96) {
            char txmPath[PATH_MAX] = {0};
            int length = snprintf(txmPath, sizeof(txmPath),
                "/private/preboot/%s/usr/standalone/firmware/FUD/"
                "Ap,TrustedExecutionMonitor.img4", dir->d_name);
            if (length > 0 && (size_t)length < sizeof(txmPath) &&
                    access(txmPath, F_OK) == 0) {
                hasTXM = YES;
                break;
            }
        }
    }
    closedir(d);
    return hasTXM;
}

// Thin wrapper of DeviceHasJITFlags to respect overriden flag
BOOL DeviceHasTXM(void) {
    return DeviceHasJITFlags(JIT_FLAG_HAS_TXM);
}

void init_setupUniversalJITScript(BOOL copyToClipboard) {
    NSString *inBundleScriptPath = [NSBundle.mainBundle pathForResource:@"UniversalJIT26" ofType:@"js"];
    if (!inBundleScriptPath) {
        NSLog(@"[JIT] UniversalJIT26.js not found in main bundle");
        return;
    }

    NSError *error = nil;
    NSString *scriptContent = [NSString stringWithContentsOfFile:inBundleScriptPath encoding:NSUTF8StringEncoding error:&error];
    if (!scriptContent || scriptContent.length == 0) {
        NSLog(@"[JIT] Failed to read UniversalJIT26.js: %@", error.localizedDescription);
        return;
    }

    const char *pojavHome = getenv("POJAV_HOME");
    if (pojavHome) {
        NSString *documentsScriptPath = [NSString stringWithFormat:@"%s/UniversalJIT26.js", pojavHome];
        if (![[NSFileManager defaultManager] fileExistsAtPath:documentsScriptPath] ||
            ![[NSString stringWithContentsOfFile:documentsScriptPath encoding:NSUTF8StringEncoding error:nil] isEqualToString:scriptContent]) {
            [[NSFileManager defaultManager] removeItemAtPath:documentsScriptPath error:nil];
            [scriptContent writeToFile:documentsScriptPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"[JIT] Failed to write UniversalJIT26.js to Documents: %@", error.localizedDescription);
            } else {
                NSLog(@"[JIT] Synced UniversalJIT26.js to Documents");
            }
        }
    }

    // Update LCAppInfo.plist for LiveContainer automatic JIT script loading
    NSString *lcAppInfoPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"LCAppInfo.plist"];
    NSMutableDictionary *lcAppInfo = [NSMutableDictionary dictionaryWithContentsOfFile:lcAppInfoPath];
    if (lcAppInfo) {
        NSString *base64Script = [[scriptContent dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        if (![lcAppInfo[@"jitLaunchScriptJs"] isEqualToString:base64Script]) {
            lcAppInfo[@"jitLaunchScriptJs"] = base64Script;
            if ([lcAppInfo writeToFile:lcAppInfoPath atomically:YES]) {
                NSLog(@"[JIT] Updated LCAppInfo.plist with UniversalJIT26 script");
            }
        }
    }

    // Automatically copy script to UIPasteboard so user can paste it directly into StikDebug
    if (copyToClipboard) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIPasteboard.generalPasteboard.string = scriptContent;
            NSLog(@"[JIT] UniversalJIT26.js copied to clipboard for StikDebug");
        });
    }
}

JITFlags DeviceGetJITFlags(BOOL refresh) {
    static os_unfair_lock cacheLock = OS_UNFAIR_LOCK_INIT;
    static JITFlags cachedFlags = 0;
    static BOOL cacheInitialized = NO;

    os_unfair_lock_lock(&cacheLock);
    if (refresh || !cacheInitialized) {
        JITFlags flags = 0;
        const char *s = getenv("JIT_FLAGS");
        if (s) {
            if (s[0] == '0' && tolower(s[1]) == 'b') {
                flags = strtoul(s + 2, NULL, 2);
            } else {
                flags = strtoul(s, NULL, 0);
            }
            NSLog(@"[JIT] Using overridden JIT flags: 0x%X", flags);
        } else {
            if (@available(iOS 26.0, *)) {
                flags |= JIT_FLAG_IS_IOS_26;
                // On iOS 26+ and iOS 27+, direct RX allocations for JIT code cache are blocked
                // and require debugger-backed mirror prepare regardless of single-page mprotect quirks.
                flags |= JIT_FLAG_FORCE_MIRRORED;
            }
            if (DeviceHasTXMReal()) {
                flags |= JIT_FLAG_HAS_TXM;
            }
        }

        cachedFlags = flags;
        cacheInitialized = YES;
    }
    JITFlags result = cachedFlags;
    os_unfair_lock_unlock(&cacheLock);
    return result;
}

BOOL DeviceHasJITFlags(JITFlags flags) {
    return (DeviceGetJITFlags(NO) & flags) == flags;
}

BOOL DeviceNeedsDebugJITMapping(void) {
    // This is a capability decision, not a TXM firmware-detection decision.
    // On iOS 26+ and iOS 27+, HotSpot uses MirrorMappedCodeCache and
    // requires debugger-backed JIT mapping via StikDebug / UniversalJIT26.
    return DeviceHasJITFlags(JIT_FLAG_IS_IOS_26) || DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED);
}

BOOL JIT26IsLikelyDebuggerKeepAttached(void) {
    return processIsCurrentlyDebugged();
}
