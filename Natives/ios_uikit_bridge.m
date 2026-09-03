#import "authenticator/BaseAuthenticator.h"
#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "LauncherPreferences.h"
#import "PLLogOutputView.h"
#import "SurfaceViewController.h"
#import "AmethystRootViewController.h"
#import "MainCoordinator.h"
#import "ThemeManager.h"
#import "VersionDirectoryManager.h"
#import "PLProfiles.h"

#include <objc/runtime.h>
#include "ios_uikit_bridge.h"
#include "utils.h"
#import "BlurredDialog.h"

void internal_showDialog(NSString* title, NSString* message) {
    NSLog(@"[UI] Dialog shown: %@: %@", title, message);

    UIWindow *alertWindow = [[UIWindow alloc] initWithWindowScene:UIWindow.mainWindow.windowScene];
    alertWindow.frame = UIScreen.mainScreen.bounds;
    alertWindow.rootViewController = [UIViewController new];
    alertWindow.windowLevel = 1000;
    alertWindow.backgroundColor = UIColor.clearColor;
    [alertWindow makeKeyAndVisible];
    // Frosted realtime dialog (samples the app behind the window)
    // Localize here so every caller gets the launcher language for free;
    // dynamic messages (names, paths, versions) match no key and pass through.
    [BlurredDialog presentInWindow:alertWindow title:localize(title, nil) message:(message ? localize(message, nil) : nil) okTitle:localize(@"OK", nil)];
}

void showDialog(NSString* title, NSString* message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        internal_showDialog(title, message);
    });
}

JNIEXPORT void JNICALL Java_net_kdt_pojavlaunch_uikit_UIKit_showError(JNIEnv* env, jclass clazz, jstring title, jstring message, jboolean exitIfOk) {
    const char *title_c = (*env)->GetStringUTFChars(env, title, 0);
    const char *message_c = (*env)->GetStringUTFChars(env, message, 0);
    NSString *title_o = @(title_c);
    NSString *message_o = @(message_c);
    (*env)->ReleaseStringUTFChars(env, title, title_c);
    (*env)->ReleaseStringUTFChars(env, message, message_c);

    if (SurfaceViewController.isRunning) {
        NSLog(@"%@\n%@", title_o, message_o);
        [PLLogOutputView handleExitCode:1];
        return;
    }

dispatch_async(dispatch_get_main_queue(), ^{

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:title_o message:message_o
        preferredStyle:UIAlertControllerStyleAlert];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentLeft;

    NSMutableAttributedString *atrStr = [[NSMutableAttributedString alloc] initWithString:message_o attributes:@{NSParagraphStyleAttributeName:style,NSFontAttributeName:[UIFont systemFontOfSize:13.0]}];

    [alert setValue:atrStr forKey:@"attributedMessage"];

    UIAlertAction* okAction = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            if (exitIfOk == JNI_TRUE) {
                exit(-1);
            }
        }];
    [alert addAction:okAction];
    
    UIAlertAction* copyAction = [UIAlertAction actionWithTitle:localize(@"Copy", nil) style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            UIPasteboard.generalPasteboard.string = message_o;
            if (exitIfOk == JNI_TRUE) {
                exit(-1);
            }
        }];
    [alert addAction:copyAction];
    
    [currentVC() presentViewController:alert animated:YES completion:nil];
});
}

jstring UIKit_accessClipboard(JNIEnv* env, jint action, jbyteArray copySrc) {
    if (action == CLIPBOARD_PASTE) {
        // paste request
        if (UIPasteboard.generalPasteboard.hasStrings) {
            return (*env)->NewStringUTF(env, [UIPasteboard.generalPasteboard.string UTF8String]);
        } else {
            return (*env)->NewStringUTF(env, "");
        }
    } else if (action == CLIPBOARD_COPY) {
        // copy request
        const char* copySrcC = (*env)->GetByteArrayElements(env, copySrc, 0);
        if (copySrcC) {
            UIPasteboard.generalPasteboard.string = @(copySrcC);
            (*env)->ReleaseByteArrayElements(env, copySrc, copySrcC, 0);
        }
        return NULL;
    } else {
        // unknown request
        NSLog(@"Warning: unknown clipboard action: %x", action);
        return NULL;
    }
}

void UIKit_launchMinecraftSurfaceVC(UIWindow* window, NSDictionary* metadata) {
    // Leave this pref, might be useful later for launching with Quick Actions/Shortcuts/URL Scheme
    //setPreference(@"internal_launch_on_boot", getPreference(@"restart_before_launch"));
    setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);
    dispatch_async(dispatch_get_main_queue(), ^{
        tmpRootVC = window.rootViewController;
        [UIView animateWithDuration:0.2 animations:^{
            window.alpha = 0;
        } completion:^(BOOL b){
            [window resignKeyWindow];
            window.alpha = 1;
            window.rootViewController = [[SurfaceViewController alloc] initWithMetadata:metadata];
            [window makeKeyAndVisible];
        }];
    });
}

void UIKit_launchJarFile(UIWindow* window, NSString* jarPath) {
    UIKit_launchJarFileWithArgs(window, jarPath, nil, 8);
}

void UIKit_launchJarFileWithArgs(UIWindow* window, NSString* jarPath, NSArray<NSString *> *args, int minJavaVersion) {
    setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);

    // Set up game directory so the jar runs in the profile's Minecraft environment
    NSString *versionId = VersionDirectoryManager.shared.currentVersion;
    if (versionId.length == 0) {
        versionId = PLProfiles.current.selectedProfile[@"lastVersionId"];
    }
    if (versionId.length > 0) {
        [VersionDirectoryManager.shared prepareGameDirectoryForVersion:versionId];
        NSMutableDictionary *profile = PLProfiles.current.selectedProfile;
        if (profile && [profile isKindOfClass:NSMutableDictionary.class]) {
            profile[@"gameDir"] = [NSString stringWithFormat:@"versions/%@", versionId];
            [PLProfiles.current save];
        } else if (profile) {
            NSMutableDictionary *mutableProfile = profile.mutableCopy;
            mutableProfile[@"gameDir"] = [NSString stringWithFormat:@"versions/%@", versionId];
            PLProfiles.current.profiles[PLProfiles.current.selectedProfileName] = mutableProfile;
            [PLProfiles.current save];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        tmpRootVC = window.rootViewController;
        [UIView animateWithDuration:0.2 animations:^{
            window.alpha = 0;
        } completion:^(BOOL b){
            [window resignKeyWindow];
            window.alpha = 1;
            window.rootViewController = [[SurfaceViewController alloc] initWithJarPath:jarPath args:args minJavaVersion:minJavaVersion];
            [window makeKeyAndVisible];
        }];
    });
}

UIInterfaceOrientationMask amethyst_orientation_mask(void) {
    NSString *mode = getPrefObject(@"general.orientation_lock");
    if ([mode isEqualToString:@"portrait"]) {
        return UIInterfaceOrientationMaskPortrait;
    }
    if ([mode isEqualToString:@"landscape"]) {
        return UIInterfaceOrientationMaskLandscape;
    }
    if ([mode isEqualToString:@"off"] || !mode.length) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
    if (getPrefBool(@"general.lock_landscape")) {
        return UIInterfaceOrientationMaskLandscape;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

// Switch the home-screen app icon. "blue" reverts to the build's primary icon
// (AppIcon-Light); "purple"/"dev" use their alternate icon sets. Not supported
// on every sideload setup, so failures are only logged.
static void applyLauncherAppIconAttempt(NSString *iconName, int attempt) {
    UIApplication *app = UIApplication.sharedApplication;
    NSString *current = app.alternateIconName;
    BOOL same = (current == nil && iconName == nil) || (current != nil && [current isEqualToString:iconName]);
    if (same) {
        NSLog(@"[AppIcon] alternate icon already set to %@, skipping", iconName ?: @"primary");
        return;
    }
    [app setAlternateIconName:iconName completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[AppIcon] setAlternateIconName(%@) failed: %@", iconName ?: @"primary", error.localizedDescription);
            // FBSOpenApplicationErrorDomain "The operation was cancelled" is
            // returned when the call happens before the app is fully active
            // (e.g. at launch). Retry with a delay rather than giving up.
            if (attempt < 3) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * (attempt + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    applyLauncherAppIconAttempt(iconName, attempt + 1);
                });
            }
        } else {
            NSLog(@"[AppIcon] setAlternateIconName(%@) OK", iconName ?: @"primary");
        }
    }];
}

void applyLauncherAppIcon(void) {
    NSString *style = getPrefObject(@"launcher.logo_style");
    NSString *iconName = nil; // nil = primary AppIcon-Light
    if ([style isEqualToString:@"purple"]) {
        iconName = @"AppIcon-Purple";
    } else if ([style isEqualToString:@"dev"]) {
        iconName = @"AppIcon-Development";
    }
    applyLauncherAppIconAttempt(iconName, 0);
}

void UIKit_returnToSplitView() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIWindow.mainWindow;

        [UIView animateWithDuration:0.2 animations:^{
            window.alpha = 0;
        } completion:^(BOOL b){
            [window resignKeyWindow];
            window.alpha = 1;
            if (tmpRootVC) {
                window.rootViewController = tmpRootVC;
                tmpRootVC = nil;
            } else {
                AmethystRootViewController *rootVC = [[AmethystRootViewController alloc] init];
                MainCoordinator *coordinator = [[MainCoordinator alloc] initWithRootVC:rootVC];
                rootVC.coordinator = coordinator;
                window.rootViewController = rootVC;
            }
            [window makeKeyAndVisible];
        }];
    });
    // A headless installer run (Forge/NeoForge) writes versions/<id> while the
    // JVM was running, so rescan the versions directory when we come back.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VersionDidChangeNotification" object:nil userInfo:@{}];
}

void launchInitialViewController(UIWindow *window) {
    AmethystRootViewController *rootVC = [[AmethystRootViewController alloc] init];
    MainCoordinator *coordinator = [[MainCoordinator alloc] initWithRootVC:rootVC];
    rootVC.coordinator = coordinator;
    window.rootViewController = rootVC;
    [window makeKeyAndVisible];
    [ThemeManager.shared applyThemeToAllWindows];
}
