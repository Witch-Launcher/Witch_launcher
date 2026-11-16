#import "PluginInstallFlow.h"
#import "WitchPluginManager.h"
#import "WitchPluginRisk.h"
#import "WitchPluginSandbox.h"
#import "WitchPluginTheme.h"
#import "WitchPluginUpdateService.h"
#import "ThemeManager.h"
#import "DownloadProgressOverlay.h"
#import "AppSheet.h"
#import "utils.h"
#import "ios_uikit_bridge.h"

@implementation PluginInstallFlow

+ (PluginInstallFlow *)shared {
    static PluginInstallFlow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)installCatalogEntry:(WitchPluginCatalogEntry *)entry
        fromViewController:(UIViewController *)viewController {
    if (!entry || !viewController) return;
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:viewController.view title:localize(@"Verifying Plugin", nil)];
    [overlay updateProgress:0.5f message:localize(@"Checking the Witch registry", nil)];
    __weak typeof(self) weakSelf = self;
    [WitchPluginUpdateService.shared fetchAndVerifyEntry:entry completion:^(NSURL *packageURL, NSDictionary *info, WitchPluginRiskReport *risk, NSError *error) {
        PluginInstallFlow *strongSelf = weakSelf;
        [overlay dismiss];
        if (!strongSelf) return;
        if (!packageURL || !info) {
            showDialog(localize(@"Verification Failed", nil), error.localizedDescription ?: localize(@"Registry verification failed.", nil));
            return;
        }
        BOOL isUpdate = [WitchPluginManager.shared pluginWithID:entry.pluginID] != nil;
        WitchPluginInstallOptions *options = [WitchPluginInstallOptions defaultOptions];
        options.allowReplace = isUpdate;
        // The download matched the hash the catalog publishes, so this build is
        // the published one even when the registry never heard of the publisher.
        options.trust = WitchPluginTrustPublisher;
        WitchPluginTrust registryTrust = (WitchPluginTrust)[info[@"registryTrust"] integerValue];
        NSString *registryMessage = [info[@"registryTrustMessage"] isKindOfClass:[NSString class]] ? info[@"registryTrustMessage"] : nil;
        options.trustMessage = (registryTrust == WitchPluginTrustPublisher && registryMessage.length > 0)
            ? registryMessage
            : localize(@"Pinned by the plugin catalog", nil);
        options.publishedSha256 = entry.sha256;
        [strongSelf presentInstallForPackageURL:packageURL
                                           info:info
                                           risk:risk
                                        options:options
                              fromViewController:viewController];
    }];
}

- (void)presentInstallForPackageURL:(NSURL *)packageURL
                                info:(NSDictionary *)info
                                risk:(WitchPluginRiskReport *)risk
                             options:(WitchPluginInstallOptions *)options
                   fromViewController:(UIViewController *)viewController {
    WitchPluginInstallOptions *installOptions = options ?: [WitchPluginInstallOptions defaultOptions];
    BOOL isUpdate = installOptions.allowReplace;
    NSDictionary *manifest = [info[@"manifest"] isKindOfClass:[NSDictionary class]] ? info[@"manifest"] : @{};
    NSString *name = [manifest[@"name"] isKindOfClass:[NSString class]] ? manifest[@"name"] : @"Plugin";
    NSString *version = [manifest[@"version"] isKindOfClass:[NSString class]] ? manifest[@"version"] : @"";
    NSString *author = [manifest[@"author"] isKindOfClass:[NSString class]] ? manifest[@"author"] : nil;
    NSString *license = [manifest[@"license"] isKindOfClass:[NSString class]] ? manifest[@"license"] : nil;
    NSString *source = [manifest[@"source"] isKindOfClass:[NSString class]] ? manifest[@"source"] : nil;

    // Nothing to report: the package passed every check, install it right away.
    if (risk && risk.level == WitchPluginRiskLevelSafe) {
        [self installPackage:packageURL info:info name:name isUpdate:isUpdate options:installOptions fromViewController:viewController];
        return;
    }
    if (!risk) {
        // The analysis always runs during the inspection, but an unknown
        // result is treated as a warning instead of a silent approval.
        risk = [WitchPluginRiskReport reportFromDictionary:@{
            @"level": @(WitchPluginRiskLevelWarning),
            @"findings": @[@{@"level": @(WitchPluginRiskLevelWarning),
                             @"code": @"unknown-risk",
                             @"title": localize(@"The behaviour of this plugin could not be analysed", nil),
                             @"detail": localize(@"Review the package before you install it.", nil)}],
            @"executionSummary": @[]
        }];
    }

    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"%@ %@\n", name, version];
    if (author.length > 0) [message appendFormat:@"%@\n", author];
    if (license.length > 0) [message appendFormat:@"%@\n", license];
    if (source.length > 0) [message appendFormat:@"%@\n", source];
    if (risk.level == WitchPluginRiskLevelDangerous) {
        [message appendFormat:@"\n%@\n", localize(@"This plugin is dangerous. It asks for access the launcher sandbox cannot protect.", nil)];
    } else {
        [message appendFormat:@"\n%@\n", localize(@"This plugin needs attention before you trust it.", nil)];
    }
    if (installOptions.trust == WitchPluginTrustPublisher) {
        [message appendFormat:@"\n%@: %@\n", localize(@"Publisher", nil), installOptions.trustMessage.length > 0 ? installOptions.trustMessage : localize(@"Trusted publisher", nil)];
    } else {
        [message appendFormat:@"\n%@: %@\n", localize(@"Publisher", nil), localize(@"Unknown. The registry does not know it. Install only if you trust the author.", nil)];
    }
    if (risk.executionSummary.count > 0) {
        [message appendFormat:@"\n%@\n", localize(@"What the launcher will run:", nil)];
        for (NSString *line in risk.executionSummary) {
            [message appendFormat:@"• %@\n", line];
        }
    }
    NSString *rehearsal = [self rehearsalSummaryForInfo:info];
    if (rehearsal.length > 0) {
        [message appendFormat:@"\n%@\n%@", localize(@"Sandbox rehearsal:", nil), rehearsal];
    }
    for (WitchPluginRiskFinding *finding in risk.findings) {
        [message appendFormat:@"\n• %@\n%@\n", finding.title, finding.detail];
    }
    [message appendFormat:@"\n%@", localize(@"The plugin runs inside the launcher sandbox. Native code stays blocked until you turn the sandbox off on the plugin screen.", nil)];

    NSString *confirmTitle = risk.level == WitchPluginRiskLevelDangerous ? localize(@"Force Install", nil) : localize(@"Install", nil);
    NSString *title = isUpdate ? localize(@"Update Plugin", nil) : localize(@"Install Plugin", nil);
    __weak typeof(self) weakSelf = self;

    if (risk.level == WitchPluginRiskLevelDangerous) {
        // A dangerous plugin needs the user to pick how much access it gets.
        // The sandbox is the safe answer, but a native plugin does nothing
        // without it, so the choice has to be explicit.
        NSArray *options = @[
            @{@"title": localize(@"Install inside the sandbox", nil),
              @"subtitle": localize(@"Native code stays blocked. The plugin can only use its settings and theme.", nil),
              @"icon": @"lock.shield"},
            @{@"title": localize(@"Install and allow native code", nil),
              @"subtitle": localize(@"The plugin runs its binary inside the launcher process.", nil),
              @"icon": @"bolt.trianglebadge.exclamationmark",
              @"destructive": @YES}
        ];
        [AppSheet showOptionsWithTitle:title
                                message:message
                                options:options
                          selectedIndex:NSNotFound
                              selection:^(NSInteger index) {
            PluginInstallFlow *strongSelf = weakSelf;
            if (!strongSelf) return;
            installOptions.sandboxPolicy = (index == 1) ? WitchPluginSandboxPolicyNever : WitchPluginSandboxPolicyAlways;
            [strongSelf installPackage:packageURL info:info name:name isUpdate:isUpdate options:installOptions fromViewController:viewController];
        } cancel:^{
            [[NSFileManager defaultManager] removeItemAtPath:packageURL.path error:nil];
        }];
        return;
    }

    [AppSheet showConfirmWithTitle:title
                           message:message
                      confirmTitle:confirmTitle
                       destructive:NO
                         onConfirm:^{
        PluginInstallFlow *strongSelf = weakSelf;
        if (!strongSelf) return;
        installOptions.sandboxPolicy = WitchPluginSandboxPolicyAlways;
        [strongSelf installPackage:packageURL info:info name:name isUpdate:isUpdate options:installOptions fromViewController:viewController];
    } onCancel:^{
        [[NSFileManager defaultManager] removeItemAtPath:packageURL.path error:nil];
    }];
}

// What the sandbox rehearsal saw while the package was verified.
- (NSString *)rehearsalSummaryForInfo:(NSDictionary *)info {
    WitchPluginSandboxReport *report = [info[@"sandbox"] isKindOfClass:[WitchPluginSandboxReport class]] ? info[@"sandbox"] : nil;
    if (!report) return @"";
    NSMutableArray *parts = [NSMutableArray array];
    if (report.observations.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu calls recorded", nil), (unsigned long)report.observations.count]];
    }
    if (report.blocked.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu blocked attempts", nil), (unsigned long)report.blocked.count]];
    }
    if (report.errors.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu errors", nil), (unsigned long)report.errors.count]];
    }
    if (report.capabilities.count > 0) {
        [parts addObject:[NSString stringWithFormat:localize(@"%lu capabilities", nil), (unsigned long)report.capabilities.count]];
    }
    if (parts.count == 0) return @"";
    NSMutableString *summary = [NSMutableString stringWithString:[report verdictLabel]];
    [summary appendFormat:@" — %@", [parts componentsJoinedByString:@", "]];
    for (NSString *blocked in report.blocked) {
        [summary appendFormat:@"\n• %@", [NSString stringWithFormat:localize(@"blocked: %@", nil), blocked]];
    }
    for (NSString *error in report.errors) {
        [summary appendFormat:@"\n• %@", error];
    }
    for (NSString *capability in report.capabilities) {
        [summary appendFormat:@"\n• %@", capability];
    }
    return summary;
}

- (void)installPackage:(NSURL *)packageURL
                   info:(NSDictionary *)info
                   name:(NSString *)name
                isUpdate:(BOOL)isUpdate
                options:(WitchPluginInstallOptions *)options
      fromViewController:(UIViewController *)viewController {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL installed = [WitchPluginManager.shared installPackageAtURL:packageURL
                                                          expectedInfo:info
                                                               options:options
                                                                 error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtPath:packageURL.path error:nil];
            if (!installed) {
                showDialog(localize(@"Install Failed", nil), error.localizedDescription ?: @"Cannot install plugin");
                return;
            }
            NSLog(@"[Plugins] Installed %@ after verification (sandbox=%@, trust=%ld)",
                  name, options.sandboxPolicy == WitchPluginSandboxPolicyNever ? @"off" : @"on", (long)options.trust);
            [WitchPluginTheme reload];
            [ThemeManager.shared broadcastThemeChange];
            NSString *message = isUpdate
                ? [NSString stringWithFormat:localize(@"%@ was updated. Restart the launcher to load it.", nil), name]
                : [NSString stringWithFormat:localize(@"%@ was installed. Restart the launcher to load it.", nil), name];
            showDialog(isUpdate ? localize(@"Plugin Updated", nil) : localize(@"Plugin Installed", nil), message);
        });
    });
}

@end
