#import "PluginRiskBadgeView.h"
#import "ThemeManager.h"

@implementation PluginRiskBadgeView

+ (UIColor *)colorForLevel:(WitchPluginRiskLevel)level {
    switch (level) {
        case WitchPluginRiskLevelDangerous:
            return ThemeManager.shared.errorColor;
        case WitchPluginRiskLevelWarning:
            return ThemeManager.shared.warningColor;
        case WitchPluginRiskLevelSafe:
        default:
            return ThemeManager.shared.successColor;
    }
}

+ (NSString *)textForLevel:(WitchPluginRiskLevel)level {
    switch (level) {
        case WitchPluginRiskLevelDangerous:
            return @"  Dangerous  ";
        case WitchPluginRiskLevelWarning:
            return @"  Warning  ";
        case WitchPluginRiskLevelSafe:
        default:
            return @"  Safe  ";
    }
}

+ (instancetype)badgeForLevel:(WitchPluginRiskLevel)level {
    PluginRiskBadgeView *badge = [[self alloc] initWithFrame:CGRectZero];
    badge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    badge.textColor = UIColor.whiteColor;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = 5;
    badge.clipsToBounds = YES;
    badge.adjustsFontSizeToFitWidth = YES;
    badge.minimumScaleFactor = 0.75;
    [badge applyLevel:level];
    return badge;
}

- (void)applyLevel:(WitchPluginRiskLevel)level {
    self.text = [PluginRiskBadgeView textForLevel:level];
    self.backgroundColor = [PluginRiskBadgeView colorForLevel:level];
}

@end
