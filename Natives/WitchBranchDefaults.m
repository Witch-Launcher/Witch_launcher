#import "WitchBranchDefaults.h"
#import "config.h"

static NSDictionary<NSString *, NSArray<NSString *> *> *WitchFeatureBranchDefaults(void) {
    static NSDictionary *defaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaults = @{
            // Log options: general.debug_logging, debug.debug_render_log and
            // debug.mem_sample_log default ON for local development builds
            // and beta builds, OFF on main (and every other branch).
            @"logs": @[@"beta"],
        };
    });
    return defaults;
}

NSString *WitchBuildBranch(void) {
    return @(CONFIG_BRANCH);
}

BOOL WitchFeatureDefaultEnabled(NSString *feature) {
    if (feature.length == 0) return NO;
    NSArray<NSString *> *branches = WitchFeatureBranchDefaults()[feature];
    if (![branches isKindOfClass:NSArray.class]) return NO;
    if (!CONFIG_RELEASE) return YES;
    return [branches containsObject:WitchBuildBranch()];
}
