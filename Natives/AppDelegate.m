#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "FontManager.h"
#import "WitchAppAttest.h"
#import "PluginsViewController.h"
#import "WitchPluginManager.h"
#import "WitchPluginRuntime.h"
#import "WitchMemoryPressure.h"
#import "WitchJITCoordinator.h"
#import "BackupScheduler.h"

// SurfaceViewController
extern dispatch_group_t fatalExitGroup;

@implementation AppDelegate

#pragma mark - UISceneSession lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Install the custom-font swizzle before any UIKit view is constructed so
    // every UIFont created by the launcher respects the user font.
    [FontManager install];
    [BackupScheduler registerTasks];
    [WitchPluginManager.shared reload];
    [WitchPluginRuntime.shared loadEnabledPlugins];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [WitchPluginManager.shared verifyInstalledPlugins];
    });
    // Home-screen icon is fixed at build time (APP_ICON / asset catalog).
    // No runtime icon switching anymore: an alternate icon chosen by an older
    // build stays memoized by SpringBoard across updates, so devices that used
    // it (e.g. the purple Amethyst-looking one) must be reset to the primary
    // icon declared in the current build.
    if (@available(iOS 10.3, *)) {
        if (UIApplication.sharedApplication.alternateIconName != nil) {
            [UIApplication.sharedApplication setAlternateIconName:nil completionHandler:^(NSError *error) {
                if (error) NSLog(@"[Icon] reset to primary failed: %@", error);
            }];
        }
    }
    // A pairing file copied into Documents/Inbox never reaches openURL on a
    // scene-based app; pick it up before the JIT settings are first read.
    [[WitchJITCoordinator shared] importInboxPairingFileIfNeeded];
    // Tạo flag file để phát hiện crash ra màn hình chính (nếu app crash, file sẽ còn lại)
    const char *home = getenv("POJAV_HOME");
    if (home) {
        NSString *flag = [@(home) stringByAppendingPathComponent:@".launcher_running"];
        [[NSFileManager defaultManager] createFileAtPath:flag contents:[@"1" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
    // Kích hoạt AppAttest (BuildKeys) — tạo key/assertion nền, Worker sẽ ưu tiên
    if ([WitchAppAttest isSupported]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [WitchAppAttest attestIfNeededWithCompletion:^(NSString *token, NSError *error){
                if (token) {
                    NSLog(@"[WitchAppAttest] ready");
                } else {
                    NSLog(@"[WitchAppAttest] not ready: %@", error.localizedDescription);
                }
            }];
        });
    }
    return YES;
}



- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if ([WitchJITCoordinator handleIncomingPairingURL:url]) return YES;
    return [PluginsViewController handleIncomingURL:url presenter:currentVC()];
}

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    // iOS sends this before Jetsam; trim caches/logs and (once per minute)
    // ask the JVM to collect so direct ByteBuffer cleaners run.
    WitchMemoryPressureHandle(YES);
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (fatalExitGroup != nil) {
        dispatch_group_leave(fatalExitGroup);
        fatalExitGroup = nil;
    }
    const char *home = getenv("POJAV_HOME");
    if (home) {
        NSString *flag = [@(home) stringByAppendingPathComponent:@".launcher_running"];
        [[NSFileManager defaultManager] removeItemAtPath:flag error:nil];
    }
}

@end
