#import <SafariServices/SafariServices.h>

#include "jni.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/sysctl.h>

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

BOOL isJITEnabled(BOOL checkCSFlags) {
    if (!checkCSFlags && (getEntitlementValue(@"dynamic-codesigning") || isJailbroken)) {
        return YES;
    }

    int flags;
    csops(getpid(), 0, &flags, sizeof(flags));
    if ((flags & CS_DEBUGGED) == 0) {
        return NO;
    }
    if (!DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM)) {
        // Device below iOS 26 or without TXM is sufficient at this point
        return YES;
    }
    // Device with iOS 26+ and TXM requires a debugger attached for JIT script to bypass TXM restrictions
    return JIT26IsLikelyDebuggerKeepAttached();
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

NSString* localize(NSString* key, NSString* comment) {
    if (!key) return @"";
    NSString *value = [[NSBundle mainBundle] localizedStringForKey:key value:key table:nil];
    if (![NSLocale.preferredLanguages[0] isEqualToString:@"en"] && [value isEqualToString:key]) {
        NSString* path = [NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"];
        NSBundle* languageBundle = [NSBundle bundleWithPath:path];
        value = [languageBundle localizedStringForKey:key value:key table:nil];
        if (!value || [value isEqualToString:key]) {
            value = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:key table:nil];
        }
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

    NSString *machine = hardwareMachineIdentifier();
    double version = hardwareDeviceVersion(machine);
    NSLog(@"[JIT] hw.machine=%@ (version %.2f)", machine ?: @"unknown", version);

    if (@available(iOS 27.0, *)) {
        // iOS 27: every device is TXM except iPad Pro 11"/12.9" (M1),
        // hardware identifiers iPad8,11 / iPad8,12
        BOOL txm = (!machine || (![machine isEqualToString:@"iPad8,11"] && ![machine isEqualToString:@"iPad8,12"]));
        NSLog(@"[JIT] iOS 27 blanket TXM rule: %@", txm ? @"TXM" : @"non-TXM (iPad8,11/8,12)");
        return txm;
    }
    if (@available(iOS 26.0, *)) {
        // iOS 26.x: TXM = iPhone hardware version >= 14.2 (iPhone 13/A15+)
        // or iPad hardware version >= 14.5; A12/A13/A14/M1 stay non-TXM
        if (!machine) return NO;
        if ([machine hasPrefix:@"iPad"]) {
            return version >= 14.5;
        }
        return version >= 14.2;
    }
    return NO;
}
// Thin wrapper of DeviceHasJITFlags to respect overriden flag
__exported BOOL DeviceHasTXM(void) {
    return DeviceHasJITFlags(JIT_FLAG_HAS_TXM);
}

JITFlags DeviceGetJITFlags(BOOL refresh) {
    static JITFlags cachedFlags = 0;
    static dispatch_once_t onceToken;
    if (refresh) onceToken = 0;
    dispatch_once(&onceToken, ^{
        const char *s = getenv("JIT_FLAGS");
        if (s) {
            if (s[0] == '0' && tolower(s[1]) == 'b') {
                cachedFlags = strtoul(s + 2, NULL, 2);
            } else {
                cachedFlags = strtoul(s, NULL, 0);
            }
            NSLog(@"[JIT] Using overridden JIT flags: 0x%X", cachedFlags);
            return;
        }
        
        if (@available(iOS 26.0, *)) {
            cachedFlags |= JIT_FLAG_IS_IOS_26;
            if (!DeviceCanCreateRXMap()) {
                cachedFlags |= JIT_FLAG_FORCE_MIRRORED;
            }
        }
        if (DeviceHasTXMReal()) {
            cachedFlags |= JIT_FLAG_HAS_TXM;
        }
        
        if (refresh) NSLog(@"[JIT] Using computed JIT flags: 0x%X", cachedFlags);
    });
    return cachedFlags;
}
BOOL DeviceHasJITFlags(JITFlags flags) {
    return (DeviceGetJITFlags(NO) & flags) == flags;
}

BOOL DeviceNeedsDebugJITMapping(void) {
    // This is a capability decision, not a TXM firmware-detection decision.
    // MirrorMappedCodeCache now means that the Universal JIT script has been
    // installed and HotSpot may request its RX mapping from the debugger.
    return DeviceHasJITFlags(JIT_FLAG_IS_IOS_26 | JIT_FLAG_FORCE_MIRRORED);
}

BOOL JIT26IsLikelyDebuggerKeepAttached(void) {
    // getppid() always returns launchd PID (1) unless debugger is actively attached
    return getppid() != 1;
}
