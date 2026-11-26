#import <Foundation/Foundation.h>

/// Branch the binary was built from, as recorded by CMake (config.h).
FOUNDATION_EXPORT NSString *WitchBuildBranch(void);

/// Branch-scoped default for a feature. Features are declared in
/// WitchBranchDefaults.m with the list of branches that enable them by
/// default; every other branch defaults to NO. Unknown features return NO.
FOUNDATION_EXPORT BOOL WitchFeatureDefaultEnabled(NSString *feature);
