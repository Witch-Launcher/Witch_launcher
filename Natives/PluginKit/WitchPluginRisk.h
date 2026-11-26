#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// How much the launcher trusts a plugin's behaviour, independently from the
// cryptographic trust (signature, checksums, registry). The level is computed
// from the manifest and from the files that will actually be executed.
typedef NS_ENUM(NSInteger, WitchPluginRiskLevel) {
    WitchPluginRiskLevelSafe = 0,
    WitchPluginRiskLevelWarning = 1,
    WitchPluginRiskLevelDangerous = 2
};

@interface WitchPluginRiskFinding : NSObject

@property (nonatomic, readonly) WitchPluginRiskLevel level;
@property (nonatomic, readonly, copy) NSString *code;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *detail;

- (instancetype)initWithLevel:(WitchPluginRiskLevel)level
                          code:(NSString *)code
                         title:(NSString *)title
                        detail:(NSString *)detail;
- (NSDictionary *)dictionaryRepresentation;
+ (nullable instancetype)findingWithDictionary:(NSDictionary *)dictionary;

@end

@interface WitchPluginRiskReport : NSObject

@property (nonatomic, readonly) WitchPluginRiskLevel level;
@property (nonatomic, readonly, copy) NSArray<WitchPluginRiskFinding *> *findings;
// Human readable list of everything the launcher is going to execute.
@property (nonatomic, readonly, copy) NSArray<NSString *> *executionSummary;
// YES when the plugin must run inside the launcher sandbox.
@property (nonatomic, readonly) BOOL sandboxRequired;

+ (WitchPluginRiskReport *)analyzeManifest:(NSDictionary *)manifest
                                  directory:(nullable NSString *)directory;
// Adds findings, for example the ones the sandbox rehearsal collected, and
// re-grades the report.
- (WitchPluginRiskReport *)reportByMergingFindings:(NSArray<WitchPluginRiskFinding *> *)findings;
+ (WitchPluginRiskReport *)reportFromDictionary:(nullable NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
- (NSString *)levelLabel;

@end

NS_ASSUME_NONNULL_END
