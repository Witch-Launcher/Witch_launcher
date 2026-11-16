#import "WitchPluginVersion.h"

@implementation WitchPluginVersion

+ (NSComparisonResult)compare:(NSString *)lhs to:(NSString *)rhs {
    NSString *left = [(lhs ?: @"") lowercaseString];
    NSString *right = [(rhs ?: @"") lowercaseString];
    if ([left hasPrefix:@"v"]) left = [left substringFromIndex:1];
    if ([right hasPrefix:@"v"]) right = [right substringFromIndex:1];
    NSRange plus = [left rangeOfString:@"+"];
    if (plus.location != NSNotFound) left = [left substringToIndex:plus.location];
    plus = [right rangeOfString:@"+"];
    if (plus.location != NSNotFound) right = [right substringToIndex:plus.location];

    NSString *leftCore = left;
    NSString *leftPre = @"";
    NSRange dash = [left rangeOfString:@"-"];
    if (dash.location != NSNotFound) {
        leftCore = [left substringToIndex:dash.location];
        leftPre = [left substringFromIndex:dash.location + 1];
    }
    NSString *rightCore = right;
    NSString *rightPre = @"";
    dash = [right rangeOfString:@"-"];
    if (dash.location != NSNotFound) {
        rightCore = [right substringToIndex:dash.location];
        rightPre = [right substringFromIndex:dash.location + 1];
    }

    NSArray<NSString *> *a = [leftCore componentsSeparatedByString:@"."];
    NSArray<NSString *> *b = [rightCore componentsSeparatedByString:@"."];
    NSUInteger count = MAX(a.count, b.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger x = i < a.count ? [a[i] integerValue] : 0;
        NSInteger y = i < b.count ? [b[i] integerValue] : 0;
        if (x < y) return NSOrderedAscending;
        if (x > y) return NSOrderedDescending;
    }
    if (leftPre.length == 0 && rightPre.length == 0) return NSOrderedSame;
    if (leftPre.length == 0) return NSOrderedDescending;
    if (rightPre.length == 0) return NSOrderedAscending;
    return [leftPre compare:rightPre];
}

+ (BOOL)isVersion:(NSString *)candidate newerThan:(NSString *)current {
    return [self compare:candidate to:current] == NSOrderedDescending;
}

@end
