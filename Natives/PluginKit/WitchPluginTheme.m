#import "WitchPluginTheme.h"
#import "WitchPluginManager.h"

static NSDictionary *WPActiveThemeColors;

static UIColor *WPColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *value = [hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([value hasPrefix:@"#"]) value = [value substringFromIndex:1];
    if (value.length != 6 && value.length != 8) return nil;
    unsigned long long number = 0;
    if (![[NSScanner scannerWithString:value] scanHexLongLong:&number]) return nil;
    CGFloat red, green, blue, alpha;
    if (value.length == 8) {
        red = ((number >> 24) & 0xff) / 255.0;
        green = ((number >> 16) & 0xff) / 255.0;
        blue = ((number >> 8) & 0xff) / 255.0;
        alpha = (number & 0xff) / 255.0;
    } else {
        red = ((number >> 16) & 0xff) / 255.0;
        green = ((number >> 8) & 0xff) / 255.0;
        blue = (number & 0xff) / 255.0;
        alpha = 1.0;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@implementation WitchPluginTheme

+ (void)reload {
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    for (WitchPlugin *plugin in WitchPluginManager.shared.plugins) {
        if (!plugin.enabled || plugin.verificationState == WitchPluginVerificationStateRevoked || plugin.verificationState == WitchPluginVerificationStateInvalid) continue;
        NSString *themePath = nil;
        id ui = plugin.manifest[@"ui"];
        if ([ui isKindOfClass:[NSString class]]) {
            themePath = [plugin.installPath stringByAppendingPathComponent:ui];
        } else if ([ui isKindOfClass:[NSDictionary class]] && [ui[@"theme"] isKindOfClass:[NSString class]]) {
            themePath = [plugin.installPath stringByAppendingPathComponent:ui[@"theme"]];
        } else {
            NSString *candidate = [plugin.installPath stringByAppendingPathComponent:@"theme.json"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:candidate]) themePath = candidate;
        }
        if (themePath.length > 0) {
            NSData *data = [NSData dataWithContentsOfFile:themePath];
            NSDictionary *theme = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSDictionary *colors = [theme isKindOfClass:[NSDictionary class]] ? theme[@"colors"] : nil;
            if ([colors isKindOfClass:[NSDictionary class]]) [merged addEntriesFromDictionary:colors];
        }
        NSDictionary *runtimeColors = plugin.state[@"themeColors"];
        if ([runtimeColors isKindOfClass:[NSDictionary class]]) [merged addEntriesFromDictionary:runtimeColors];
    }
    WPActiveThemeColors = merged.count > 0 ? [merged copy] : nil;
}

+ (nullable UIColor *)colorForKey:(NSString *)key dark:(BOOL)dark {
    id value = WPActiveThemeColors[key];
    if ([value isKindOfClass:[NSDictionary class]]) value = value[dark ? @"dark" : @"light"];
    if ([value isKindOfClass:[NSString class]]) return WPColorFromHex(value);
    return nil;
}

@end
