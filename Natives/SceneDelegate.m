#import "SceneDelegate.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "LauncherPreferences.h"
#import "debug/DebugServer.h"
#import "touchcontroller_jni_bridge.h"
#import "SurfaceViewController.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import "CrashLogAnalyzer.h"
#import "WitchLogReporter.h"
#import "WitchAIChatViewController.h"

extern UIWindow *mainWindow;

@interface SceneDelegate ()

@end

@implementation SceneDelegate

// iOS 26 introduced BGContinuedProcessingTaskRequestResourcesGPU.  Without
// its entitlement, MoltenVK loses its Metal device as soon as an active game
// is put in the background (kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted).
// The request is deliberately best-effort: ordinary App Store/sideload
// profiles cannot grant this restricted entitlement, but foreground gameplay
// must continue to work normally when it is unavailable.
static NSString *const kMinecraftGPUBackgroundTaskPrefix = @"com.witch.zad626.minecraft.gpu.";

// Compiled only against the iOS 26 SDK and newer: BGContinuedProcessingTask
// types do not exist in older SDK headers. The @available check inside still
// guards execution at runtime.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
- (void)requestVulkanBackgroundGPUAllowanceIfNeeded {
    if (@available(iOS 26.0, *)) {
        if (!SurfaceViewController.isRunning) return;
        if (!getEntitlementValue(@"com.apple.developer.background-tasks.continued-processing.gpu")) {
            NSLog(@"[VulkanBackground] GPU continued-processing entitlement unavailable; iOS will revoke Vulkan after the app backgrounds");
            return;
        }
        if (!(BGTaskScheduler.supportedResources & BGContinuedProcessingTaskRequestResourcesGPU)) {
            NSLog(@"[VulkanBackground] This device does not support background GPU continued processing");
            return;
        }

        NSString *identifier = [kMinecraftGPUBackgroundTaskPrefix stringByAppendingString:NSUUID.UUID.UUIDString];
        BGContinuedProcessingTaskRequest *request =
            [[BGContinuedProcessingTaskRequest alloc] initWithIdentifier:identifier
                                                                     title:@"Minecraft is running"
                                                                  subtitle:@"Keeping Vulkan rendering available"];
        request.strategy = BGContinuedProcessingTaskRequestSubmissionStrategyFail;
        request.requiredResources = BGContinuedProcessingTaskRequestResourcesGPU;

        NSError *error = nil;
        if ([[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error]) {
            NSLog(@"[VulkanBackground] Submitted GPU continued-processing request %@", identifier);
        } else {
            NSLog(@"[VulkanBackground] GPU continued-processing request rejected: %@", error.localizedDescription ?: @"unknown error");
        }
    }
}
#endif


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.frame = windowScene.coordinateSpace.bounds;
    // Translucent bars/panels sample the view hierarchy; without a backdrop
    // they would reveal the raw black window underneath ("đen xì").
    self.window.backgroundColor = UIColor.systemBackgroundColor;
    mainWindow = self.window;
    launchInitialViewController(self.window);
    [self.window makeKeyAndVisible];
    // Kiểm tra crash ra màn hình chính ở lần trước (flag còn lại + latestlog/.ips)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkForPreviousCrashAndPrompt];
    });

    if (getPrefBool(@"debug.debug_server_enabled")) {
        NSString *token = getPrefObject(@"debug.debug_server_token");
        if (token.length < 8) {
            token = [DebugServer generateToken];
            setPrefObject(@"debug.debug_server_token", token);
        }
        uint16_t port = (uint16_t)getPrefInt(@"debug.debug_server_port") ?: 9090;
        BOOL localhost = getPrefBool(@"debug.debug_server_localhost_only");
        if ([DebugServer.shared startWithPort:port localhostOnly:localhost token:token]) {
            NSLog(@"[DebugServer] Ready at %@ (token: %@)", [DebugServer.shared displayURL], token);
        }
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    // Every previous touch sequence is dead at this point (iOS cancels touches
    // when the app leaves the active state). Force-release any TouchController
    // pointer that a stalls-dropped touchesEnded may have left held in the mod,
    // so input never stays "stuck" after returning to the game.
    CallbackBridge_nativeSetWindowFocused(YES, NO);
    touchcontroller_onTouchCancel();
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
    // Submit while the scene is still foreground-associated. Waiting for
    // sceneDidEnterBackground is too late on iOS 27: MoltenVK has already
    // received VK_ERROR_DEVICE_LOST by then.
    // Notify GLFW synchronously before UIKit withdraws foreground GPU access.
    // Minecraft then stops rendering instead of letting MoltenVK submit a
    // command buffer that iOS rejects with VK_ERROR_DEVICE_LOST.
    CallbackBridge_nativeSetWindowFocused(NO, YES);
    CallbackBridge_pauseGameIfNeed();
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    [self requestVulkanBackgroundGPUAllowanceIfNeeded];
#endif
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
    CallbackBridge_nativeSetWindowFocused(NO, YES);
    CallbackBridge_pauseGameIfNeed();
}

- (void)checkForPreviousCrashAndPrompt {
    const char *home = getenv("POJAV_HOME");
    if (!home) return;
    NSString *flagPath = [@(home) stringByAppendingPathComponent:@".launcher_running"];
    BOOL flagExists = [[NSFileManager defaultManager] fileExistsAtPath:flagPath];
    // Tìm .ips mới nhất (nếu có) và latestlog crash
    NSString *latestLog = [@(home) stringByAppendingPathComponent:@"latestlog.txt"];
    BOOL hasLatestLog = [[NSFileManager defaultManager] fileExistsAtPath:latestLog];
    // Tìm .ips trong Library/Logs/CrashReporter và trong POJAV_HOME
    NSString *ipsPath = nil;
    NSArray *searchDirs = @[
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter"],
        @(home)
    ];
    NSDate *now = [NSDate date];
    for (NSString *dir in searchDirs) {
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *f in files) {
            if ([f.pathExtension isEqualToString:@"ips"] && [f containsString:@"Witch"]) {
                NSString *full = [dir stringByAppendingPathComponent:f];
                NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
                NSDate *mod = attr[NSFileModificationDate];
                if (mod && [now timeIntervalSinceDate:mod] < 86400) { // trong 24h
                    ipsPath = full;
                    break;
                }
            }
        }
        if (ipsPath) break;
    }
    BOOL shouldPrompt = flagExists || ipsPath;
    // Xóa flag để lần sau không hiện lại nếu user đã thấy
    if (flagExists) [[NSFileManager defaultManager] removeItemAtPath:flagPath error:nil];
    // Tạo lại flag cho lần chạy hiện tại
    [[NSFileManager defaultManager] createFileAtPath:flagPath contents:[@"1" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    if (!shouldPrompt) return;
    // Kiểm tra latestlog có chỉ crash không thì mới hiện (tránh hiện mỗi lần mở)
    if (hasLatestLog) {
        NSString *content = [NSString stringWithContentsOfFile:latestLog encoding:NSUTF8StringEncoding error:nil];
        if (content && ![content containsString:@"Game crashed!"] && !ipsPath) return;
    }
    // Hiện alert cho phép gửi log
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"crash.prev_title", nil) message:localize(@"crash.prev_message", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"crash.send_ai", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        CrashLogAnalyzerResult *analysis = [CrashLogAnalyzer analyzeWithExitCode:1];
        WitchAIChatViewController *vc = [[WitchAIChatViewController alloc] initWithAnalysis:analysis exitCode:1];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.window.rootViewController presentViewController:nav animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"crash.send_discord", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        CrashLogAnalyzerResult *analysis = [CrashLogAnalyzer analyzeWithExitCode:1];
        NSString *note = ipsPath ? [NSString stringWithFormat:@"Crash .ips: %@", ipsPath.lastPathComponent] : @"Launcher crash to home";
        [WitchLogReporter sendReportWithAnalysis:analysis exitCode:1 note:note completion:^(BOOL success, NSString *logId, NSError *error){
            NSString *title = success ? localize(@"crash.sent_title", nil) : localize(@"Error", nil);
            NSString *msg = success ? [NSString stringWithFormat:localize(@"crash.sent_discord", nil), logId ?: @""] : error.localizedDescription;
            UIAlertController *res = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
            [res addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [self.window.rootViewController presentViewController:res animated:YES completion:nil];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"crash.later", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
