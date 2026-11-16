#import <UIKit/UIKit.h>
#import "WitchPluginRisk.h"

NS_ASSUME_NONNULL_BEGIN

// Small coloured pill that shows the behavioural risk of a plugin.
// Red for a dangerous plugin, yellow for a plugin that needs attention.
@interface PluginRiskBadgeView : UILabel

+ (UIColor *)colorForLevel:(WitchPluginRiskLevel)level;
+ (NSString *)textForLevel:(WitchPluginRiskLevel)level;
+ (instancetype)badgeForLevel:(WitchPluginRiskLevel)level;
- (void)applyLevel:(WitchPluginRiskLevel)level;

@end

NS_ASSUME_NONNULL_END
