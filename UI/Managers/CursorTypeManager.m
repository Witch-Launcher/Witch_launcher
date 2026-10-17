#import "CursorTypeManager.h"
#import "CursorManager.h"
#import "LauncherPreferences.h"
#import "utils.h"

NSString *const CursorTypeDidChangeNotification = @"CursorTypeDidChangeNotification";

NSString *const kCursorTypeId = @"id";
NSString *const kCursorTypeName = @"name";
NSString *const kCursorTypeDescription = @"description";
NSString *const kCursorTypeIcon = @"icon";
NSString *const kCursorTypeGLFWConstant = @"glfwConstant";
NSString *const kCursorTypeSDLConstant = @"sdlConstant";

static NSString *const kMasterTogglePrefKey = @"control.cursor_types_enabled";

// GLFW cursor shape constants — Java side masks with 0xFFFF before sending
static const int kGLFWArrowCursor        = 0x6001;
static const int kGLFWIBeamCursor        = 0x6002;
static const int kGLFWCrosshairCursor    = 0x6003;
static const int kGLFWPointingHandCursor = 0x6004;
static const int kGLFWResizeEWCursor     = 0x6005;
static const int kGLFWResizeNSCursor     = 0x6006;
static const int kGLFWResizeNWSECursor   = 0x6007;
static const int kGLFWResizeNESWCursor   = 0x6008;
static const int kGLFWResizeAllCursor    = 0x6009;
static const int kGLFWNotAllowedCursor   = 0x600A;
static const int kGLFWBusyCursor              = 0x600B;
static const int kGLFWWorkingInBackgroundCursor = 0x600C;
static const int kGLFWHelpCursor              = 0x600D;

// SDL3 system cursor constants (from SDLMouse.java)
static const int kSDLDefault     = 0;
static const int kSDLText        = 1;
static const int kSDLWait        = 2;
static const int kSDLCrosshair   = 3;
static const int kSDLProgress    = 4;
static const int kSDLNWSEResize  = 5;
static const int kSDLNESWResize  = 6;
static const int kSDLEWResize    = 7;
static const int kSDLNSResize    = 8;
static const int kSDLMove        = 9;
static const int kSDLNotAllowed  = 10;
static const int kSDLPointer     = 11;

static NSArray<NSDictionary *> *_cursorTypeDefinitions;

@interface CursorTypeManager ()
@property (nonatomic, copy) NSString *currentActiveTypeId;
@end

@implementation CursorTypeManager

+ (void)initialize {
    if (self == [CursorTypeManager class]) {
        _cursorTypeDefinitions = @[
            @{
                kCursorTypeId: @"normal",
                kCursorTypeName: @"Normal Select",
                kCursorTypeDescription: @"Default arrow cursor for general selection.",
                kCursorTypeIcon: @"\xF0\x9F\x94\xB7",
                kCursorTypeGLFWConstant: @(kGLFWArrowCursor),
                kCursorTypeSDLConstant: @(kSDLDefault),
            },
            @{
                kCursorTypeId: @"link",
                kCursorTypeName: @"Link Select",
                kCursorTypeDescription: @"Pointing hand cursor for clickable links.",
                kCursorTypeIcon: @"\xE2\x98\x9D",
                kCursorTypeGLFWConstant: @(kGLFWPointingHandCursor),
                kCursorTypeSDLConstant: @(kSDLPointer),
            },
            @{
                kCursorTypeId: @"text",
                kCursorTypeName: @"Text Select",
                kCursorTypeDescription: @"I-beam cursor for text selection.",
                kCursorTypeIcon: @"I",
                kCursorTypeGLFWConstant: @(kGLFWIBeamCursor),
                kCursorTypeSDLConstant: @(kSDLText),
            },
            @{
                kCursorTypeId: @"busy",
                kCursorTypeName: @"Busy",
                kCursorTypeDescription: @"Spinning circle indicating the system is processing.",
                kCursorTypeIcon: @"\xE2\x9C\x8C",
                kCursorTypeGLFWConstant: @(kGLFWBusyCursor),
                kCursorTypeSDLConstant: @(kSDLWait),
            },
            @{
                kCursorTypeId: @"working",
                kCursorTypeName: @"Working in Background",
                kCursorTypeDescription: @"Arrow with spinning indicator, available but processing.",
                kCursorTypeIcon: @"\xF0\x9F\x94\xB7\xE2\x9C\x8C",
                kCursorTypeGLFWConstant: @(kGLFWWorkingInBackgroundCursor),
                kCursorTypeSDLConstant: @(kSDLProgress),
            },
            @{
                kCursorTypeId: @"precision",
                kCursorTypeName: @"Precision Select",
                kCursorTypeDescription: @"Crosshair cursor for precise graphic design work.",
                kCursorTypeIcon: @"\xEF\xBC\x8B",
                kCursorTypeGLFWConstant: @(kGLFWCrosshairCursor),
                kCursorTypeSDLConstant: @(kSDLCrosshair),
            },
            @{
                kCursorTypeId: @"unavailable",
                kCursorTypeName: @"Unavailable",
                kCursorTypeDescription: @"Circle-slash cursor indicating an action is not allowed.",
                kCursorTypeIcon: @"\xE2\xA6\xB8",
                kCursorTypeGLFWConstant: @(kGLFWNotAllowedCursor),
                kCursorTypeSDLConstant: @(kSDLNotAllowed),
            },
            @{
                kCursorTypeId: @"vresize",
                kCursorTypeName: @"Vertical Resize",
                kCursorTypeDescription: @"Double-headed vertical arrow for resizing height.",
                kCursorTypeIcon: @"\xE2\x86\x95",
                kCursorTypeGLFWConstant: @(kGLFWResizeNSCursor),
                kCursorTypeSDLConstant: @(kSDLNSResize),
            },
            @{
                kCursorTypeId: @"hresize",
                kCursorTypeName: @"Horizontal Resize",
                kCursorTypeDescription: @"Double-headed horizontal arrow for resizing width.",
                kCursorTypeIcon: @"\xE2\x86\x94",
                kCursorTypeGLFWConstant: @(kGLFWResizeEWCursor),
                kCursorTypeSDLConstant: @(kSDLEWResize),
            },
            @{
                kCursorTypeId: @"diagonal",
                kCursorTypeName: @"Diagonal Resize",
                kCursorTypeDescription: @"Diagonal double-headed arrow for corner resizing.",
                kCursorTypeIcon: @"\xE2\x86\x98",
                kCursorTypeGLFWConstant: @(kGLFWResizeNWSECursor),
                kCursorTypeSDLConstant: @(kSDLNWSEResize),
            },
            @{
                kCursorTypeId: @"move",
                kCursorTypeName: @"Move",
                kCursorTypeDescription: @"Four-directional arrow for moving windows or objects.",
                kCursorTypeIcon: @"\xE2\x95\xA5",
                kCursorTypeGLFWConstant: @(kGLFWResizeAllCursor),
                kCursorTypeSDLConstant: @(kSDLMove),
            },
            @{
                kCursorTypeId: @"help",
                kCursorTypeName: @"Help Select",
                kCursorTypeDescription: @"Arrow with question mark for help/context info.",
                kCursorTypeIcon: @"?",
                kCursorTypeGLFWConstant: @(kGLFWHelpCursor),
                kCursorTypeSDLConstant: @(-1),
            },
            @{
                kCursorTypeId: @"hidden",
                kCursorTypeName: @"Hidden",
                kCursorTypeDescription: @"Invisible cursor (hidden by game).",
                kCursorTypeIcon: @"\xE2\x96\xAB",
                kCursorTypeGLFWConstant: @(-1),
                kCursorTypeSDLConstant: @(-1),
            },
        ];
    }
}

+ (instancetype)shared {
    static CursorTypeManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CursorTypeManager alloc] init];
        instance.currentActiveTypeId = @"normal";
    });
    return instance;
}

#pragma mark - Definitions

+ (NSArray<NSDictionary *> *)allCursorTypes {
    return _cursorTypeDefinitions;
}

#pragma mark - Master toggle

+ (BOOL)isMasterToggleEnabled {
    id val = getPrefObject(kMasterTogglePrefKey);
    if (val == nil) return YES; // default ON
    return [val boolValue];
}

+ (void)setMasterToggleEnabled:(BOOL)enabled {
    setPrefObject(kMasterTogglePrefKey, @(enabled));
}

#pragma mark - Preferences

+ (NSString *)enabledPrefKeyForType:(NSString *)typeId {
    return [NSString stringWithFormat:@"control.cursortype_%@_enabled", typeId];
}

+ (BOOL)isEnabledForType:(NSString *)typeId {
    if ([typeId isEqualToString:@"normal"]) return YES;
    // Master toggle OFF = only normal enabled
    if (![self isMasterToggleEnabled]) return NO;
    // Master toggle ON = check individual type preference
    return getPrefBool([self enabledPrefKeyForType:typeId]);
}

+ (void)setEnabled:(BOOL)enabled forType:(NSString *)typeId {
    if ([typeId isEqualToString:@"normal"]) return;
    setPrefObject([self enabledPrefKeyForType:typeId], @(enabled));
}

+ (NSString *)cursorForType:(NSString *)typeId {
    return [CursorManager currentCursorForType:typeId];
}

+ (void)setCursor:(NSString *)cursorName forType:(NSString *)typeId {
    [CursorManager setCurrentCursor:cursorName forType:typeId];
}

#pragma mark - Shape Mapping

+ (nullable NSString *)typeIdForGLFWShape:(int)shape {
    // GLFW has two diagonal constants but the launcher has one diagonal type;
    // both resolve here and the exact variant is picked in handleCursorShapeChange.
    if (shape == kGLFWResizeNESWCursor) return @"diagonal";
    for (NSDictionary *type in _cursorTypeDefinitions) {
        if ([type[kCursorTypeGLFWConstant] intValue] == shape) {
            return type[kCursorTypeId];
        }
    }
    return nil;
}

+ (nullable NSString *)typeIdForSDLShape:(int)shape {
    // Same as above for SDL3 (NWSEResize/NESWResize share the diagonal type).
    if (shape == kSDLNESWResize) return @"diagonal";
    for (NSDictionary *type in _cursorTypeDefinitions) {
        if ([type[kCursorTypeSDLConstant] intValue] == shape) {
            return type[kCursorTypeId];
        }
    }
    return nil;
}

#pragma mark - Cursor Shape Handling (called from JNI)

+ (void)handleCursorShapeChange:(int)shape isSDL3:(BOOL)isSDL3 {
    if (![self isMasterToggleEnabled]) {
        return;
    }

    NSString *typeId;
    if (isSDL3) {
        typeId = [self typeIdForSDLShape:shape];
    } else {
        typeId = [self typeIdForGLFWShape:shape];
    }

    // Special handling: shape 0 with GLFW might indicate hidden cursor (custom cursor set to NULL)
    // SDL3 doesn't have a hidden system cursor constant
    if (!typeId) {
        if (!isSDL3 && shape == 0) {
            typeId = @"hidden";
        } else {
            typeId = @"normal";
        }
    }

    // Windows ships distinct NW-SE and NE-SW diagonal cursors; remember which
    // variant the game asked for so the bundled asset matches.
    if ([typeId isEqualToString:@"diagonal"]) {
        BOOL nesw = (!isSDL3 && shape == kGLFWResizeNESWCursor) ||
                    (isSDL3 && shape == kSDLNESWResize);
        [CursorManager setDiagonalUsesNESW:nesw];
    }

    if (![self isEnabledForType:typeId]) {
        return;
    }

    CursorTypeManager *mgr = [self shared];
    mgr.currentActiveTypeId = typeId;

    NSString *cursorName = [self cursorForType:typeId];

    NSDictionary *userInfo = @{
        @"typeId": typeId,
        @"cursorName": cursorName,
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:CursorTypeDidChangeNotification
                                                        object:mgr
                                                      userInfo:userInfo];
    });


}

+ (void)setCursorHidden:(BOOL)hidden {
    if (![self isMasterToggleEnabled]) {
        return;
    }
    
    NSString *typeId = hidden ? @"hidden" : @"normal";
    
    if (![self isEnabledForType:typeId]) {
        return;
    }
    
    CursorTypeManager *mgr = [self shared];
    mgr.currentActiveTypeId = typeId;
    
    NSString *cursorName = [self cursorForType:typeId];
    
    NSDictionary *userInfo = @{
        @"typeId": typeId,
        @"cursorName": cursorName,
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:CursorTypeDidChangeNotification
                                                        object:mgr
                                                      userInfo:userInfo];
    });
    

}

#pragma mark - Display

+ (UIImage *)imageForType:(NSString *)typeId {
    return [CursorManager compositeImageForType:typeId];
}

+ (NSString *)localizedNameForType:(NSString *)typeId {
    NSString *key = [NSString stringWithFormat:@"cursor.type.%@", typeId];
    NSString *localized = localize(key, nil);
    if (![localized isEqualToString:key]) {
        return localized;
    }
    for (NSDictionary *type in _cursorTypeDefinitions) {
        if ([type[kCursorTypeId] isEqualToString:typeId]) {
            return type[kCursorTypeName];
        }
    }
    return typeId;
}

+ (NSString *)currentActiveTypeId {
    return [self shared].currentActiveTypeId;
}

@end
