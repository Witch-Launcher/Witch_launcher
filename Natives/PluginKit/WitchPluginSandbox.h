#import <Foundation/Foundation.h>
#import "WitchPluginRisk.h"

NS_ASSUME_NONNULL_BEGIN

// What the sandbox rehearsal found.
typedef NS_ENUM(NSInteger, WitchPluginSandboxVerdict) {
    // Nothing was executed and nothing dangerous was seen.
    WitchPluginSandboxVerdictClean = 0,
    // The plugin was rehearsed and tried to do something the sandbox refuses.
    WitchPluginSandboxVerdictBlocked = 1,
    // The plugin crashed, hung or failed while it was rehearsed.
    WitchPluginSandboxVerdictFailed = 2
};

@interface WitchPluginSandboxReport : NSObject

@property (nonatomic, readonly) WitchPluginSandboxVerdict verdict;
// YES when something was actually executed or inspected.
@property (nonatomic, readonly) BOOL executed;
// Calls the plugin made to the launcher, in order.
@property (nonatomic, readonly, copy) NSArray<NSString *> *observations;
// Things the plugin tried to do that the sandbox refuses.
@property (nonatomic, readonly, copy) NSArray<NSString *> *blocked;
// Errors the plugin raised while it was rehearsed.
@property (nonatomic, readonly, copy) NSArray<NSString *> *errors;
// Capabilities a native payload carries, read from its binary.
@property (nonatomic, readonly, copy) NSArray<NSString *> *capabilities;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, copy) NSArray<WitchPluginRiskFinding *> *findings;

+ (WitchPluginSandboxReport *)reportFromDictionary:(nullable NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
- (NSString *)verdictLabel;

@end

// Rehearses a package inside the launcher sandbox and reports what it tried
// to do. The rehearsal happens during verification, before the package is
// installed, and it never touches the real launcher state.
@interface WitchPluginSandboxProbe : NSObject

+ (WitchPluginSandboxReport *)probeManifest:(NSDictionary *)manifest
                                   directory:(NSString *)directory;
// The cache key keeps a package from being rehearsed twice, for example when
// it is inspected and then installed.
+ (WitchPluginSandboxReport *)probeManifest:(NSDictionary *)manifest
                                   directory:(NSString *)directory
                                   cacheKey:(nullable NSString *)cacheKey;

@end

NS_ASSUME_NONNULL_END
