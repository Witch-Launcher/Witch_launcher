#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "WitchAppAttest.h"

// SurfaceViewController
extern dispatch_group_t fatalExitGroup;

@implementation AppDelegate

#pragma mark - UISceneSession lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Re-apply the chosen home-screen icon on every launch; keeps the icon in
    // sync with the launcher.logo_style preference (and flushes stale caches).
    dispatch_async(dispatch_get_main_queue(), ^{
        applyLauncherAppIcon();
    });
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
