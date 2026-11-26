#import "GameLaunchChecks.h"
#import "AmethystNoticePanel.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "ZinkConfig.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@implementation GameLaunchCheck
@end

@implementation GameLaunchChecks

// THE extension point. Every entry is a self-contained pre-launch check for a
// known-broken setting combination: the notice explains the problem and the
// primary button reverts the setting and returns to the launcher, while the
// secondary button lets the user run anyway. When the underlying issue is
// fixed, delete the entry (plus its Localizable.strings keys) and this panel
// silently stops appearing — no other code changes needed.
+ (NSArray<GameLaunchCheck *> *)checks {
    NSMutableArray<GameLaunchCheck *> *checks = [NSMutableArray array];

    // Zink Mesa 26.2.2 currently fails to start the game (black screen).
    // Offer a rollback to 25.0.7; only meaningful when the Zink renderer is
    // selected.
    GameLaunchCheck *mesa2622 = [GameLaunchCheck new];
    mesa2622.checkID = @"zink.mesa_version_2622";
    mesa2622.title = localize(@"notice.zink_mesa_2622.title", nil);
    mesa2622.message = localize(@"notice.zink_mesa_2622.message", nil);
    mesa2622.revertButtonTitle = localize(@"notice.zink_mesa_2622.revert", nil);
    mesa2622.continueButtonTitle = localize(@"notice.action.continue", nil);
    mesa2622.isAffected = ^BOOL {
        BOOL zinkSelected = [ZinkConfig isZinkRenderSelected];
        BOOL version2622 = [[ZinkConfig selectedMesaVersion] isEqualToString:@"26.2.2"];
        return zinkSelected && version2622;
    };
    mesa2622.revert = ^{
        setPrefObject(@"zink.mesa_version", @"25.0.7");
        UIKit_returnToSplitView();
    };
    [checks addObject:mesa2622];

    // MobileGlues only works on its ANGLE Vulkan host right now; TGLES and
    // ANGLE Metal are still broken. Offer a rollback to ANGLE Vulkan; only
    // meaningful when the MobileGlues renderer is selected.
    GameLaunchCheck *mgBackend = [GameLaunchCheck new];
    mgBackend.checkID = @"mobileglues.angle_backend";
    mgBackend.title = localize(@"notice.mobileglues_backend.title", nil);
    mgBackend.message = localize(@"notice.mobileglues_backend.message", nil);
    mgBackend.revertButtonTitle = localize(@"notice.mobileglues_backend.revert", nil);
    mgBackend.continueButtonTitle = localize(@"notice.action.continue", nil);
    mgBackend.isAffected = ^BOOL {
        NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
        if (![renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES]) return NO;
        id backend = getPrefObject(@"mobileglues.angle_backend");
        if (![backend isKindOfClass:[NSString class]]) return NO;
        BOOL isVulkan = [(NSString *)backend isEqualToString:@"vulkan"];
        return !isVulkan;
    };
    mgBackend.revert = ^{
        setPrefObject(@"mobileglues.angle_backend", @"vulkan");
        // Keep the legacy mirrored switch consistent with the picker.
        setPrefObject(@"mobileglues.enable_angle", @YES);
        UIKit_returnToSplitView();
    };
    [checks addObject:mgBackend];

    // The profile's own `renderer` is resolved by PLProfiles BEFORE the global
    // Settings value, so a profile that carries an old renderer (e.g.
    // libMoltenVK.dylib) silently overrides whatever the user picks in
    // Settings — and the launch then always runs MoltenVK. Offer to copy the
    // global renderer into the profile so the Settings picker wins.
    GameLaunchCheck *rendererShadow = [GameLaunchCheck new];
    rendererShadow.checkID = @"profile.renderer_shadow";
    rendererShadow.title = localize(@"notice.profile_renderer_shadow.title", nil);
    rendererShadow.message = localize(@"notice.profile_renderer_shadow.message", nil);
    rendererShadow.revertButtonTitle = localize(@"notice.profile_renderer_shadow.revert", nil);
    rendererShadow.continueButtonTitle = localize(@"notice.action.continue", nil);
    rendererShadow.isAffected = ^BOOL {
        NSString *global = getPrefObject(@"video.renderer");
        if (![global isKindOfClass:NSString.class] || global.length == 0) return NO;
        PLProfiles *profiles = PLProfiles.current;
        NSMutableDictionary<NSString *, NSString *> *profile = profiles.selectedProfile;
        if (!profile) return NO;
        NSString *profileRenderer = profile[@"renderer"];
        return profileRenderer.length > 0 && ![profileRenderer isEqualToString:global];
    };
    rendererShadow.revert = ^{
        PLProfiles *profiles = PLProfiles.current;
        NSMutableDictionary<NSString *, NSString *> *profile = profiles.selectedProfile;
        if (!profile) return;
        NSString *global = getPrefObject(@"video.renderer");
        if (![global isKindOfClass:NSString.class] || global.length == 0) return;
        profile[@"renderer"] = global;
        [profiles save];
        UIKit_returnToSplitView();
    };
    [checks addObject:rendererShadow];

    return checks;
}

+ (BOOL)presentFirstIssueIn:(UIView *)host onContinue:(void (^)(void))onContinue {
    for (GameLaunchCheck *check in self.checks) {
        BOOL affected = NO;
        @try {
            if (check.isAffected) affected = check.isAffected();
        } @catch (NSException *exception) {
            NSLog(@"[GameLaunchChecks] check %@ threw: %@", check.checkID, exception);
        }
        if (!affected) continue;

        AmethystNoticePanel *notice = [AmethystNoticePanel
            noticeWithTitle:check.title
                    message:check.message
                    actions:@[
                // Left = keep the (broken) selection, right = fix & exit.
                [AmethystNoticeAction secondaryWithTitle:check.continueButtonTitle handler:onContinue],
                [AmethystNoticeAction primaryWithTitle:check.revertButtonTitle handler:check.revert],
            ]];
        notice.iconSystemName = check.iconSystemName;
        [AmethystNoticePanel presentInView:host notice:notice];
        return YES;
    }
    return NO;
}

@end
