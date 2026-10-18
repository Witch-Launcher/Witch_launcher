#import "ControlLayoutConverter.h"
#import "CustomControlsUtils.h"
#import "../LauncherPreferences.h"
#import "../utils.h"

@interface ControlLayoutConverter ()
+ (NSMutableDictionary *)internalButtonFromZalith:(NSDictionary *)payload styles:(NSDictionary *)styles screen:(CGSize)screen;
+ (NSMutableDictionary *)internalJoystickFromZalith:(NSDictionary *)payload screen:(CGSize)screen;
+ (NSDictionary *)styleConfigFromProps:(NSMutableDictionary *)props;
+ (NSString *)styleKeyFromProps:(NSMutableDictionary *)props;
+ (NSDictionary *)buttonSizeFromFrames:(CGFloat)width height:(CGFloat)height screen:(CGSize)screen;
+ (NSDictionary *)positionFromFrame:(CGRect)frame screen:(CGSize)screen;
@end

static NSDictionary<NSNumber *, NSString *> *sCodeToName;
static NSDictionary<NSString *, NSNumber *> *sNameToCode;

static void BuildKeycodeTables(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *tokens = [NSMutableArray array];
        NSMutableArray *codes = [NSMutableArray array];
        initKeycodeTable(tokens, codes);

        NSMutableDictionary *codeToName = [NSMutableDictionary dictionary];
        NSMutableDictionary *nameToCode = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < tokens.count && i < codes.count; i++) {
            NSString *token = tokens[i];
            if (![token isKindOfClass:NSString.class]) continue;
            if ([token hasPrefix:@"SPECIALBTN_"]) continue;
            NSNumber *code = codes[i];
            NSString *name = [@"GLFW_KEY_" stringByAppendingString:token];
            codeToName[code] = name;
            nameToCode[name] = code;
        }

        void (^alias)(NSString *, NSString *) = ^(NSString *aliasName, NSString *tokenName) {
            NSNumber *code = nameToCode[[@"GLFW_KEY_" stringByAppendingString:tokenName]];
            if (code == nil) return;
            nameToCode[aliasName] = code;
            codeToName[code] = aliasName;
        };
        alias(@"GLFW_KEY_UP", @"DPAD_UP");
        alias(@"GLFW_KEY_DOWN", @"DPAD_DOWN");
        alias(@"GLFW_KEY_LEFT", @"DPAD_LEFT");
        alias(@"GLFW_KEY_RIGHT", @"DPAD_RIGHT");

        sCodeToName = codeToName;
        sNameToCode = nameToCode;
    });
}

static NSNumber *CodeForZalithKeyName(NSString *name) {
    BuildKeycodeTables();
    return sNameToCode[name];
}

static NSString *ZalithKeyNameForCode(NSNumber *code) {
    BuildKeycodeTables();
    return sCodeToName[code];
}

static NSString *LauncherEventForSpecialCode(int code) {
    switch (code) {
        case SPECIALBTN_KEYBOARD: return @"launcher.event.switch_ime";
        case SPECIALBTN_MOUSEPRI: return @"GLFW_MOUSE_BUTTON_LEFT";
        case SPECIALBTN_MOUSESEC: return @"GLFW_MOUSE_BUTTON_RIGHT";
        case SPECIALBTN_MOUSEMID: return @"GLFW_MOUSE_BUTTON_MIDDLE";
    }
    return nil;
}

static NSNumber *SpecialCodeForLauncherEvent(NSString *event) {
    if ([event isEqualToString:@"launcher.event.switch_ime"]) return @(SPECIALBTN_KEYBOARD);
    if ([event isEqualToString:@"GLFW_MOUSE_BUTTON_LEFT"]) return @(SPECIALBTN_MOUSEPRI);
    if ([event isEqualToString:@"GLFW_MOUSE_BUTTON_RIGHT"]) return @(SPECIALBTN_MOUSESEC);
    if ([event isEqualToString:@"GLFW_MOUSE_BUTTON_MIDDLE"]) return @(SPECIALBTN_MOUSEMID);
    return nil;
}

static NSString *PlainString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSDictionary.class]) {
        id string = value[@"default"];
        if ([string isKindOfClass:NSString.class]) return string;
    }
    return nil;
}

static NSArray *ArrayOrEmpty(id value) {
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSMutableDictionary *DeepMutableCopy(id value) {
    if (value == nil) return nil;
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
    if (data == nil) return [value mutableCopy];
    id result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    return [result isKindOfClass:NSMutableDictionary.class] ? result : [value mutableCopy];
}

static NSArray *ZalithEventsFromKeycodes(NSArray *keycodes) {
    NSMutableArray *events = [NSMutableArray array];
    for (id value in keycodes) {
        int code = [value intValue];
        if (code == 0) continue;
        if (code > 0) {
            NSString *name = ZalithKeyNameForCode(@(code));
            if (name) [events addObject:@{@"type": @"key", @"key": name}];
        } else {
            NSString *event = LauncherEventForSpecialCode(code);
            if (event) [events addObject:@{@"type": @"launcher_event", @"key": event}];
        }
    }
    return events;
}

static NSArray<NSNumber *> *KeycodesFromZalithEvents(id events) {
    NSMutableArray *codes = [NSMutableArray arrayWithObjects:@0, @0, @0, @0, nil];
    NSUInteger index = 0;
    for (id item in ArrayOrEmpty(events)) {
        if (index >= 4) break;
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *type = item[@"type"];
        id key = item[@"key"];
        if (![key isKindOfClass:NSString.class]) continue;
        if ([type isEqualToString:@"key"]) {
            NSNumber *code = CodeForZalithKeyName(key);
            if (code) codes[index++] = code;
        } else if ([type isEqualToString:@"launcher_event"]) {
            NSNumber *code = SpecialCodeForLauncherEvent(key);
            if (code) codes[index++] = code;
        }
    }
    return codes;
}

static NSString *FractionString(double fraction) {
    NSString *string = [NSString stringWithFormat:@"%.5f", fraction];
    while ([string hasSuffix:@"0"]) string = [string substringToIndex:string.length - 1];
    if ([string hasSuffix:@"."]) string = [string substringToIndex:string.length - 1];
    return string.length > 0 ? string : @"0";
}

static NSString *DynamicXFromFraction(double fraction) {
    if (fraction <= 0) return @"0";
    return [NSString stringWithFormat:@"((${screen_width} - ${width}) * %@)", FractionString(fraction)];
}

static NSString *DynamicYFromFraction(double fraction) {
    if (fraction <= 0) return @"0";
    return [NSString stringWithFormat:@"((${screen_height} - ${height}) * %@)", FractionString(fraction)];
}

static int ClampInt(int value, int minValue, int maxValue) {
    return MAX(minValue, MIN(maxValue, value));
}

static void ApplyZalithVisibilityToFlags(NSString *visibility, NSMutableDictionary *target) {
    target[@"displayInGame"] = @(![visibility isEqualToString:@"in_menu"]);
    target[@"displayInMenu"] = @(![visibility isEqualToString:@"in_game"]);
}

static NSString *ZalithVisibilityFromFlags(NSNumber *inGame, NSNumber *inMenu) {
    BOOL game = inGame ? inGame.boolValue : YES;
    BOOL menu = inMenu ? inMenu.boolValue : YES;
    if (game && menu) return @"always";
    if (game) return @"in_game";
    if (menu) return @"in_menu";
    return @"in_menu";
}

static CGFloat ResolveZalithSize(NSDictionary *size, NSString *dimension, CGSize screen) {
    if (![size isKindOfClass:NSDictionary.class]) return 50.0;
    NSString *type = size[@"type"];
    if ([type isEqualToString:@"percentage"]) {
        double percentage = [size[[dimension stringByAppendingString:@"Percentage"]] doubleValue];
        NSString *reference = size[[dimension stringByAppendingString:@"Reference"]];
        CGFloat basis = [reference isEqualToString:@"screen_height"] ? screen.height : screen.width;
        return MAX(5.0, percentage / 10000.0 * basis);
    }
    if ([type isEqualToString:@"dp"]) {
        double dp = [size[[dimension stringByAppendingString:@"Dp"]] doubleValue];
        return MAX(5.0, dp);
    }
    double fallback = [size[[dimension stringByAppendingString:@"Dp"]] doubleValue];
    return fallback > 0 ? fallback : 50.0;
}

@implementation ControlLayoutConverter

+ (ControlLayoutSyntax)syntaxOfLayout:(NSDictionary *)layout {
    if (![layout isKindOfClass:NSDictionary.class]) return ControlLayoutSyntaxUnknown;
    if (layout[@"editorVersion"] != nil && [layout[@"layers"] isKindOfClass:NSArray.class]) {
        return ControlLayoutSyntaxZalith;
    }
    if (layout[@"mControlDataList"] != nil || layout[@"version"] != nil ||
        layout[@"mDrawerDataList"] != nil || layout[@"mJoystickDataList"] != nil) {
        return ControlLayoutSyntaxLegacy;
    }
    return ControlLayoutSyntaxUnknown;
}

+ (CGSize)landscapeScreenSize {
    CGSize size = UIScreen.mainScreen.bounds.size;
    return CGSizeMake(MAX(size.width, size.height), MIN(size.width, size.height));
}

+ (NSString *)randomUUID12 {
    NSString *uuid = [NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [uuid substringToIndex:MIN(12U, uuid.length)];
}

+ (NSMutableDictionary *)internalButtonFromZalith:(NSDictionary *)payload styles:(NSDictionary *)styles screen:(CGSize)screen {
    if (![payload isKindOfClass:NSDictionary.class]) return nil;

    NSMutableDictionary *button = [NSMutableDictionary dictionary];
    NSString *text = PlainString(payload[@"text"]);
    button[@"name"] = text.length > 0 ? text : @"Button";
    button[@"keycodes"] = [KeycodesFromZalithEvents(payload[@"clickEvents"]) mutableCopy];

    NSDictionary *position = payload[@"position"];
    double fractionX = [position[@"x"] doubleValue] / 10000.0;
    double fractionY = [position[@"y"] doubleValue] / 10000.0;
    button[@"dynamicX"] = DynamicXFromFraction(fractionX);
    button[@"dynamicY"] = DynamicYFromFraction(fractionY);

    NSDictionary *size = payload[@"buttonSize"];
    CGFloat width = ResolveZalithSize(size, @"width", screen);
    CGFloat height = ResolveZalithSize(size, @"height", screen);
    button[@"width"] = @(round(width * 10) / 10.0);
    button[@"height"] = @(round(height * 10) / 10.0);

    CGFloat opacity = 1.0;
    unsigned long long background = 0x4D000000;
    unsigned long long borderColor = 0;
    double borderWidth = 0;
    CGFloat cornerRadiusPercent = 0;

    NSDictionary *style = nil;
    id styleId = payload[@"buttonStyle"];
    if ([styleId isKindOfClass:NSString.class]) {
        style = styles[styleId];
    }
    NSDictionary *config = style[@"lightStyle"];
    if (![config isKindOfClass:NSDictionary.class]) config = style[@"darkStyle"];
    if (![config isKindOfClass:NSDictionary.class]) config = style[@"commonStyle"];
    if ([config isKindOfClass:NSDictionary.class]) {
        if ([config[@"alpha"] isKindOfClass:NSNumber.class]) opacity = [config[@"alpha"] doubleValue];
        if ([config[@"backgroundColor"] isKindOfClass:NSNumber.class]) background = [config[@"backgroundColor"] unsignedLongLongValue] & 0xFFFFFFFF;
        if ([config[@"borderColor"] isKindOfClass:NSNumber.class]) borderColor = [config[@"borderColor"] unsignedLongLongValue] & 0xFFFFFFFF;
        if ([config[@"borderWidth"] isKindOfClass:NSNumber.class]) borderWidth = [config[@"borderWidth"] doubleValue];
        NSDictionary *radius = config[@"borderRadius"];
        if ([radius isKindOfClass:NSDictionary.class] && width > 0 && height > 0) {
            CGFloat maxRadius = MIN(width, height) / 2.0;
            if (maxRadius > 0) {
                cornerRadiusPercent = [radius[@"topStart"] doubleValue] / maxRadius * 100.0;
            }
        }
    }
    button[@"opacity"] = @(round(MAX(0.0, MIN(1.0, opacity)) * 100.0) / 100.0);
    button[@"bgColor"] = @(background);
    button[@"strokeColor"] = @(borderColor);
    button[@"strokeWidth"] = @(round(MAX(0.0, borderWidth)));
    button[@"cornerRadius"] = @(round(MAX(0.0, MIN(100.0, cornerRadiusPercent))));
    button[@"isToggle"] = @([payload[@"isToggleable"] boolValue]);
    button[@"passThruEnabled"] = @([payload[@"isPenetrable"] boolValue]);
    button[@"isSwipeable"] = @([payload[@"isSwipple"] boolValue]);
    ApplyZalithVisibilityToFlags(payload[@"visibilityType"], button);
    return button;
}

+ (NSMutableDictionary *)internalJoystickFromZalith:(NSDictionary *)payload screen:(CGSize)screen {
    if (![payload isKindOfClass:NSDictionary.class]) return nil;

    NSMutableDictionary *joystick = [NSMutableDictionary dictionary];
    NSDictionary *position = payload[@"position"];
    double fractionX = [position[@"x"] doubleValue] / 10000.0;
    double fractionY = [position[@"y"] doubleValue] / 10000.0;
    joystick[@"dynamicX"] = DynamicXFromFraction(fractionX);
    joystick[@"dynamicY"] = DynamicYFromFraction(fractionY);

    CGFloat size = 100.0;
    NSString *sizeType = payload[@"sizeType"];
    if ([sizeType isEqualToString:@"dp"]) {
        size = [payload[@"sizeDp"] doubleValue];
    } else {
        size = [payload[@"sizePercentage"] doubleValue] / 10000.0 * screen.height;
    }
    size = MAX(20.0, size);
    joystick[@"width"] = @(round(size * 10) / 10.0);
    joystick[@"height"] = @(round(size * 10) / 10.0);
    joystick[@"opacity"] = @(1);
    joystick[@"bgColor"] = @(0x4D000000);
    joystick[@"strokeColor"] = @(0xFFFFFFFF);
    joystick[@"forwardLock"] = @([payload[@"canLock"] boolValue]);
    ApplyZalithVisibilityToFlags(payload[@"visibilityType"] ?: @"always", joystick);
    return joystick;
}

+ (NSMutableDictionary *)internalLayoutFromZalith:(NSDictionary *)zalith {
    CGSize screen = [self landscapeScreenSize];

    NSMutableDictionary *styles = [NSMutableDictionary dictionary];
    for (NSDictionary *style in ArrayOrEmpty(zalith[@"styles"])) {
        if (![style isKindOfClass:NSDictionary.class]) continue;
        NSString *uuid = style[@"uuid"];
        if ([uuid isKindOfClass:NSString.class]) styles[uuid] = style;
    }

    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *joysticks = [NSMutableArray array];
    for (NSDictionary *layer in ArrayOrEmpty(zalith[@"layers"])) {
        if (![layer isKindOfClass:NSDictionary.class]) continue;
        for (NSDictionary *payload in ArrayOrEmpty(layer[@"normalButtons"])) {
            NSMutableDictionary *button = [self internalButtonFromZalith:payload styles:styles screen:screen];
            if (button) [buttons addObject:button];
        }
        for (NSDictionary *payload in ArrayOrEmpty(layer[@"joystickButtons"])) {
            NSMutableDictionary *joystick = [self internalJoystickFromZalith:payload screen:screen];
            if (joystick) [joysticks addObject:joystick];
        }
    }

    NSMutableDictionary *internal = [NSMutableDictionary dictionary];
    internal[@"version"] = @7;
    internal[@"scaledAt"] = @(getPrefFloat(@"control.button_scale"));
    internal[@"mControlDataList"] = buttons;
    internal[@"mDrawerDataList"] = [NSMutableArray array];
    internal[@"mJoystickDataList"] = joysticks;
    if ([zalith[@"info"] isKindOfClass:NSDictionary.class]) {
        internal[@"info"] = DeepMutableCopy(zalith[@"info"]);
    }
    return internal;
}

+ (NSDictionary *)normalizedInfoFromInternal:(NSDictionary *)internal {
    NSMutableDictionary *info = [internal[@"info"] isKindOfClass:NSDictionary.class]
        ? [internal[@"info"] mutableCopy]
        : [NSMutableDictionary dictionary];

    for (NSString *key in @[@"name", @"author", @"description"]) {
        id value = info[key];
        NSString *plain = nil;
        NSArray *queue = @[];
        if ([value isKindOfClass:NSDictionary.class]) {
            plain = [value[@"default"] isKindOfClass:NSString.class] ? value[@"default"] : nil;
            if ([value[@"matchQueue"] isKindOfClass:NSArray.class]) queue = value[@"matchQueue"];
        } else if ([value isKindOfClass:NSString.class]) {
            plain = value;
        }
        info[key] = @{@"default": plain ?: @"", @"matchQueue": queue};
    }

    info[@"versionCode"] = [info[@"versionCode"] isKindOfClass:NSNumber.class] ? info[@"versionCode"] : @0;
    info[@"versionName"] = [info[@"versionName"] isKindOfClass:NSString.class] ? info[@"versionName"] : @"";
    return info;
}

+ (NSDictionary *)styleConfigFromProps:(NSMutableDictionary *)props {
    CGFloat width = [props[@"width"] floatValue];
    CGFloat height = [props[@"height"] floatValue];
    CGFloat cornerPercent = [props[@"cornerRadius"] floatValue];
    CGFloat radius = MAX(0.0, MIN(100.0, cornerPercent)) / 100.0 * (MIN(width, height) / 2.0);

    double alpha = MAX(0.0, MIN(1.0, [props[@"opacity"] doubleValue]));
    unsigned long long background = [props[@"bgColor"] unsignedLongLongValue] & 0xFFFFFFFF;
    unsigned long long borderColor = [props[@"strokeColor"] unsignedLongLongValue] & 0xFFFFFFFF;
    int borderWidth = ClampInt((int)lround([props[@"strokeWidth"] doubleValue]), 0, 50);

    NSDictionary *shape = @{
        @"topStart": @(round(radius * 10) / 10.0),
        @"topEnd": @(round(radius * 10) / 10.0),
        @"bottomEnd": @(round(radius * 10) / 10.0),
        @"bottomStart": @(round(radius * 10) / 10.0),
    };
    return @{
        @"alpha": @(round(alpha * 1000.0) / 1000.0),
        @"pressedAlpha": @(round(alpha * 1000.0) / 1000.0),
        @"backgroundColor": @(background),
        @"pressedBackgroundColor": @(background),
        @"contentColor": @(0xFFFFFFFF),
        @"pressedContentColor": @(0xFFFFFFFF),
        @"fontSize": NSNull.null,
        @"pressedFontSize": NSNull.null,
        @"borderWidth": @(borderWidth),
        @"pressedBorderWidth": @(borderWidth),
        @"borderColor": @(borderColor),
        @"pressedBorderColor": @(borderColor),
        @"borderRadius": shape,
        @"pressedBorderRadius": shape,
    };
}

+ (NSString *)styleKeyFromProps:(NSMutableDictionary *)props {
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%fx%f",
        props[@"opacity"], props[@"bgColor"], props[@"strokeColor"], props[@"strokeWidth"],
        props[@"cornerRadius"], [props[@"width"] floatValue], [props[@"height"] floatValue]];
}

+ (NSDictionary *)buttonSizeFromFrames:(CGFloat)width height:(CGFloat)height screen:(CGSize)screen {
    int widthPercentage = ClampInt((int)lround(width / MAX(screen.width, 1.0) * 10000.0), 100, 10000);
    int heightPercentage = ClampInt((int)lround(height / MAX(screen.height, 1.0) * 10000.0), 100, 10000);
    return @{
        @"type": @"percentage",
        @"widthDp": @(round(MAX(5.0, width) * 10) / 10.0),
        @"heightDp": @(round(MAX(5.0, height) * 10) / 10.0),
        @"widthPercentage": @(widthPercentage),
        @"heightPercentage": @(heightPercentage),
        @"widthReference": @"screen_width",
        @"heightReference": @"screen_height",
    };
}

+ (NSDictionary *)positionFromFrame:(CGRect)frame screen:(CGSize)screen {
    CGFloat freeWidth = MAX(screen.width - frame.size.width, 1.0);
    CGFloat freeHeight = MAX(screen.height - frame.size.height, 1.0);
    int x = ClampInt((int)lround(frame.origin.x / freeWidth * 10000.0), 0, 10000);
    int y = ClampInt((int)lround(frame.origin.y / freeHeight * 10000.0), 0, 10000);
    return @{@"x": @(x), @"y": @(y)};
}

+ (NSDictionary *)zalithLayoutFromInternal:(NSDictionary *)internal
                              buttonFrames:(NSDictionary<NSDictionary *, NSValue *> *)buttonFrames
                            joystickFrames:(NSDictionary<NSDictionary *, NSValue *> *)joystickFrames
                                screenSize:(CGSize)screenSize {
    CGSize screen = CGSizeMake(MAX(screenSize.width, 1.0), MAX(screenSize.height, 1.0));

    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *styles = [NSMutableArray array];
    NSMutableDictionary *styleIds = [NSMutableDictionary dictionary];

    for (NSMutableDictionary *props in ArrayOrEmpty(internal[@"mControlDataList"])) {
        if (![props isKindOfClass:NSDictionary.class]) continue;
        CGRect frame = buttonFrames[props] ? [buttonFrames[props] CGRectValue] : CGRectZero;

        NSString *styleKey = [self styleKeyFromProps:props];
        NSString *styleId = styleIds[styleKey];
        if (styleId == nil) {
            styleId = [self randomUUID12];
            styleIds[styleKey] = styleId;
            [styles addObject:@{
                @"name": @"Style",
                @"uuid": styleId,
                @"animateSwap": @NO,
                @"commonStyle": @NO,
                @"lightStyle": [self styleConfigFromProps:props],
                @"darkStyle": [self styleConfigFromProps:props],
            }];
        }

        NSString *text = [props[@"name"] isKindOfClass:NSString.class] ? props[@"name"] : @"";
        [buttons addObject:@{
            @"text": @{@"default": text, @"matchQueue": @[]},
            @"uuid": [self randomUUID12],
            @"position": [self positionFromFrame:frame screen:screen],
            @"buttonSize": [self buttonSizeFromFrames:frame.size.width height:frame.size.height screen:screen],
            @"buttonStyle": styleId,
            @"visibilityType": ZalithVisibilityFromFlags(props[@"displayInGame"], props[@"displayInMenu"]),
            @"clickEvents": ZalithEventsFromKeycodes(props[@"keycodes"] ?: @[]),
            @"isSwipple": @([props[@"isSwipeable"] boolValue]),
            @"isPenetrable": @([props[@"passThruEnabled"] boolValue]),
            @"isToggleable": @([props[@"isToggle"] boolValue]),
        }];
    }

    NSMutableArray *joysticks = [NSMutableArray array];
    for (NSMutableDictionary *props in ArrayOrEmpty(internal[@"mJoystickDataList"])) {
        if (![props isKindOfClass:NSDictionary.class]) continue;
        CGRect frame = joystickFrames[props] ? [joystickFrames[props] CGRectValue] : CGRectZero;
        CGFloat size = MAX(20.0, frame.size.width);
        int sizePercentage = ClampInt((int)lround(size / screen.height * 10000.0), 2000, 10000);
        [joysticks addObject:@{
            @"uuid": [self randomUUID12],
            @"position": [self positionFromFrame:frame screen:screen],
            @"sizeType": @"percentage",
            @"sizeDp": @(round(size * 10) / 10.0),
            @"sizePercentage": @(sizePercentage),
            @"visibilityType": ZalithVisibilityFromFlags(props[@"displayInGame"], props[@"displayInMenu"]),
            @"deadZoneRatio": @(0.5),
            @"lockThreshold": @(0.3),
            @"canLock": @([props[@"forwardLock"] boolValue]),
            @"triggerMode": @"drag",
        }];
    }

    NSMutableDictionary *layer = [NSMutableDictionary dictionary];
    layer[@"name"] = @"Main";
    layer[@"uuid"] = [self randomUUID12];
    layer[@"hide"] = @NO;
    layer[@"visibilityType"] = @"always";
    layer[@"normalButtons"] = buttons;
    if (joysticks.count > 0) layer[@"joystickButtons"] = joysticks;

    return @{
        @"info": [self normalizedInfoFromInternal:internal],
        @"layers": @[layer],
        @"styles": styles,
        @"joystickStyles": @[],
        @"editorVersion": @12,
    };
}

@end
