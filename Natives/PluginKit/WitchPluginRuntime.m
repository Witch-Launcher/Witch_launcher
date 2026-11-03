#import "WitchPluginRuntime.h"
#import "WitchPluginManager.h"
#import "WitchPluginTheme.h"
#import "WitchPluginAPI.h"
#import "ThemeManager.h"
#import "utils.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <dlfcn.h>
#import <stdlib.h>
#import <string.h>

typedef struct WPHostContext {
    char *plugin_id;
    WitchPluginHostAPI api;
} WPHostContext;

static __thread char *WPHostSettingBuffer = NULL;

static NSString *WPHostPluginID(void *userdata) {
    WPHostContext *context = (WPHostContext *)userdata;
    return context && context->plugin_id ? @(context->plugin_id) : @"";
}

static void WPHostLogMessage(void *userdata, const char *message) {
    if (message) NSLog(@"[Plugin:%@] %s", WPHostPluginID(userdata), message);
}

static void WPHostPerformOnMain(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

static const char *WPHostGetSetting(void *userdata, const char *key) {
    if (!key) return "";
    WPHostContext *context = (WPHostContext *)userdata;
    if (!context) return "";
    NSString *settingKey = @(key);
    __block NSString *text = @"";
    WPHostPerformOnMain(^{
        NSDictionary *settings = [WitchPluginManager.shared settingsForPluginID:WPHostPluginID(userdata)];
        id value = settings[settingKey];
        text = [value isKindOfClass:[NSString class]] ? value : [value description];
        if (!text) text = @"";
    });
    free(WPHostSettingBuffer);
    WPHostSettingBuffer = strdup(text.UTF8String ?: "");
    return WPHostSettingBuffer ?: "";
}

static void WPHostSetSetting(void *userdata, const char *key, const char *value) {
    if (!key) return;
    NSString *settingKey = @(key);
    NSString *settingValue = value ? @(value) : @"";
    WPHostPerformOnMain(^{
        [WitchPluginManager.shared setSettingValue:settingValue forKey:settingKey pluginID:WPHostPluginID(userdata) error:nil];
    });
}

static void WPHostSetThemeColor(void *userdata, const char *key, const char *hex) {
    if (!key || !hex) return;
    NSString *themeKey = @(key);
    NSString *themeValue = @(hex);
    WPHostPerformOnMain(^{
        [WitchPluginManager.shared setThemeColors:@{themeKey: themeValue} pluginID:WPHostPluginID(userdata) error:nil];
    });
}

static void WPHostRequestReload(void *userdata) {
    (void)userdata;
    dispatch_async(dispatch_get_main_queue(), ^{
        [WitchPluginTheme reload];
        [ThemeManager.shared broadcastThemeChange];
    });
}

static void WPHostSetRootViewFactory(void *userdata, WitchPluginRootViewFactory factory);

@protocol WitchJSBridgeExport <JSExport>

@property (nonatomic, readonly) NSString *pluginID;
@property (nonatomic, readonly) NSString *version;

JSExportAs(log, - (void)logMessage:(NSString *)message);
JSExportAs(getSetting, - (id)getSetting:(NSString *)key fallback:(id)fallback);
JSExportAs(setSetting, - (void)setSetting:(NSString *)key value:(id)value);
JSExportAs(setThemeColor, - (void)setThemeColor:(NSString *)key hex:(NSString *)hex);
- (void)reloadTheme;

@end

@interface WitchJSBridge : NSObject <WitchJSBridgeExport>
@property (nonatomic) NSString *pluginID;
@property (nonatomic) NSString *version;
@end

@implementation WitchJSBridge

- (void)logMessage:(NSString *)message {
    NSLog(@"[Plugin:%@] %@", self.pluginID, message);
}

- (id)getSetting:(NSString *)key fallback:(id)fallback {
    id value = [WitchPluginManager.shared settingsForPluginID:self.pluginID][key];
    return value ?: fallback;
}

- (void)setSetting:(NSString *)key value:(id)value {
    if (!key) return;
    [WitchPluginManager.shared setSettingValue:value forKey:key pluginID:self.pluginID error:nil];
}

- (void)setThemeColor:(NSString *)key hex:(NSString *)hex {
    if (!key || !hex) return;
    [WitchPluginManager.shared setThemeColors:@{key: hex} pluginID:self.pluginID error:nil];
    [WitchPluginTheme reload];
    [ThemeManager.shared broadcastThemeChange];
}

- (void)reloadTheme {
    [WitchPluginTheme reload];
    [ThemeManager.shared broadcastThemeChange];
}

@end

@interface WitchPluginRuntime ()
@property (nonatomic) NSMutableDictionary<NSString *, JSContext *> *contexts;
@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *nativeHandles;
@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *hostContexts;
@property (nonatomic) WitchPluginRootViewFactory rootViewFactory;
@property (nonatomic) void *rootViewFactoryUserdata;
@property (nonatomic) NSString *rootViewFactoryPluginID;
- (void)registerRootViewFactory:(WitchPluginRootViewFactory)factory userdata:(void *)userdata pluginID:(NSString *)pluginID;
@end

static void WPHostSetRootViewFactory(void *userdata, WitchPluginRootViewFactory factory) {
    if (!factory) return;
    WPHostPerformOnMain(^{
        [WitchPluginRuntime.shared registerRootViewFactory:factory userdata:userdata pluginID:WPHostPluginID(userdata)];
    });
}

static NSString *WPVerificationLabel(WitchPluginVerificationState state) {
    switch (state) {
        case WitchPluginVerificationStateVerified: return @"verified";
        case WitchPluginVerificationStateRevoked: return @"revoked";
        case WitchPluginVerificationStateInvalid: return @"invalid";
        case WitchPluginVerificationStateUnverified:
        default: return @"unverified";
    }
}

@implementation WitchPluginRuntime

+ (WitchPluginRuntime *)shared {
    static WitchPluginRuntime *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _contexts = [NSMutableDictionary dictionary];
        _nativeHandles = [NSMutableDictionary dictionary];
        _hostContexts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadEnabledPlugins {
    WitchPluginManager *manager = WitchPluginManager.shared;
    [manager recoverFromCrashMarkers];
    [manager reload];
    NSLog(@"[Plugins] Configuration: %@", manager.configurationPath ?: @"unavailable");
    NSLog(@"[Plugins] Installed plugins: %lu", (unsigned long)manager.plugins.count);
    for (WitchPlugin *plugin in manager.plugins) {
        NSLog(@"[Plugins] - %@ v%@ enabled=%@ verification=%@ path=%@",
              plugin.pluginID, plugin.version, plugin.enabled ? @"yes" : @"no",
              WPVerificationLabel(plugin.verificationState), plugin.installPath);
    }
    if (manager.safeMode) {
        NSLog(@"[Plugins] Safe mode active; no plugins loaded");
        return;
    }
    NSMutableArray<NSString *> *active = [NSMutableArray array];
    for (WitchPlugin *plugin in manager.plugins) {
        if (!plugin.enabled) continue;
        if (plugin.verificationState == WitchPluginVerificationStateRevoked || plugin.verificationState == WitchPluginVerificationStateInvalid) continue;
        NSError *integrityError = nil;
        if (![manager verifyIntegrityForPlugin:plugin error:&integrityError]) {
            NSLog(@"[Plugin:%@] Integrity check failed: %@", plugin.pluginID, integrityError.localizedDescription);
            [manager markPluginIDInvalid:plugin.pluginID message:integrityError.localizedDescription];
            continue;
        }
        if ([self loadPlugin:plugin]) [active addObject:plugin.pluginID];
    }
    NSLog(@"[Plugins] Active plugins: %@", active.count > 0 ? [active componentsJoinedByString:@", "] : @"none");
}

- (void)releaseNativePluginID:(NSString *)pluginID {
    if ([self.rootViewFactoryPluginID isEqualToString:pluginID]) {
        self.rootViewFactory = NULL;
        self.rootViewFactoryUserdata = NULL;
        self.rootViewFactoryPluginID = nil;
    }
    [self.nativeHandles removeObjectForKey:pluginID];
    NSValue *contextValue = self.hostContexts[pluginID];
    if (contextValue) {
        WPHostContext *context = contextValue.pointerValue;
        free(context->plugin_id);
        free(context);
        [self.hostContexts removeObjectForKey:pluginID];
    }
}

- (void)registerRootViewFactory:(WitchPluginRootViewFactory)factory
                       userdata:(void *)userdata
                       pluginID:(NSString *)pluginID {
    if (self.rootViewFactory && ![self.rootViewFactoryPluginID isEqualToString:pluginID]) {
        NSLog(@"[Plugins] Ignoring second UI root factory from %@; %@ is already active", pluginID, self.rootViewFactoryPluginID);
        return;
    }
    self.rootViewFactory = factory;
    self.rootViewFactoryUserdata = userdata;
    self.rootViewFactoryPluginID = pluginID;
}

- (UIViewController *)createCustomRootViewController {
    if (!self.rootViewFactory) return nil;
    void *value = self.rootViewFactory(self.rootViewFactoryUserdata);
    if (!value) return nil;
    return (__bridge_transfer UIViewController *)value;
}

- (NSString *)fullPathForEntrypoint:(NSString *)relative plugin:(WitchPlugin *)plugin {
    if (relative.length == 0) return nil;
    return [plugin.installPath stringByAppendingPathComponent:relative];
}

- (BOOL)loadPlugin:(WitchPlugin *)plugin {
    NSString *marker = [WitchPluginManager.shared markerPathForPluginID:plugin.pluginID];
    [[NSFileManager defaultManager] createFileAtPath:marker contents:[NSData data] attributes:nil];
    BOOL loadedSomething = NO;
    NSString *failure = nil;

    NSDictionary *entrypoints = plugin.entrypoints;
    NSString *jsEntry = entrypoints[@"js"];
    if ([jsEntry isKindOfClass:[NSString class]] && jsEntry.length > 0) {
        NSString *path = [self fullPathForEntrypoint:jsEntry plugin:plugin];
        NSString *script = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
        if (!script) {
            failure = [NSString stringWithFormat:@"JavaScript entrypoint not found: %@", jsEntry];
        } else {
            JSContext *context = [[JSContext alloc] init];
            __weak typeof(self) weakSelf = self;
            context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
                NSLog(@"[Plugin:%@] JavaScript error: %@", plugin.pluginID, exception);
                weakSelf.contexts[plugin.pluginID] = nil;
            };
            WitchJSBridge *bridge = [[WitchJSBridge alloc] init];
            bridge.pluginID = plugin.pluginID;
            bridge.version = plugin.version;
            context[@"Witch"] = bridge;
            [context evaluateScript:script withSourceURL:[NSURL fileURLWithPath:path]];
            if (context.exception) {
                failure = [NSString stringWithFormat:@"JavaScript error: %@", context.exception];
            } else {
                self.contexts[plugin.pluginID] = context;
                loadedSomething = YES;
            }
        }
    }

    NSString *nativeEntry = entrypoints[@"native"];
    if (failure.length == 0 && [nativeEntry isKindOfClass:[NSString class]] && nativeEntry.length > 0) {
        NSString *path = [self fullPathForEntrypoint:nativeEntry plugin:plugin];
        void *handle = path ? dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL) : NULL;
        if (!handle) {
            const char *errorText = dlerror();
            NSString *detail = errorText ? @(errorText) : @"unknown dlopen error";
            failure = [NSString stringWithFormat:@"Cannot load native plugin: %@", detail];
        } else {
            WitchPluginInitFn init = (WitchPluginInitFn)dlsym(handle, "witch_plugin_init");
            if (!init) {
                failure = @"Native plugin does not export witch_plugin_init";
            } else {
                WPHostContext *context = calloc(1, sizeof(WPHostContext));
                context->plugin_id = strdup(plugin.pluginID.UTF8String ?: "");
                context->api.abi_version = WITCH_PLUGIN_ABI_VERSION;
                context->api.userdata = context;
                context->api.log = WPHostLogMessage;
                context->api.get_setting = WPHostGetSetting;
                context->api.set_setting = WPHostSetSetting;
                context->api.set_theme_color = WPHostSetThemeColor;
                context->api.request_ui_reload = WPHostRequestReload;
                context->api.set_root_view_factory = WPHostSetRootViewFactory;
                int result = init(&context->api);
                if (result != 0) {
                    failure = [NSString stringWithFormat:@"witch_plugin_init returned %d", result];
                } else {
                    self.nativeHandles[plugin.pluginID] = [NSValue valueWithPointer:handle];
                    self.hostContexts[plugin.pluginID] = [NSValue valueWithPointer:context];
                    loadedSomething = YES;
                }
            }
        }
    }

    NSString *javaEntry = entrypoints[@"java"];
    if (failure.length == 0 && [javaEntry isKindOfClass:[NSString class]] && javaEntry.length > 0) {
        NSLog(@"[Plugin:%@] Java entrypoint %@ is registered; the Java agent is not loaded in this build", plugin.pluginID, javaEntry);
    }

    if (!loadedSomething && failure.length == 0) {
        id ui = plugin.manifest[@"ui"];
        NSString *themeRelative = [ui isKindOfClass:[NSString class]] ? ui : ([ui isKindOfClass:[NSDictionary class]] ? ui[@"theme"] : nil);
        NSString *themePath = [themeRelative isKindOfClass:[NSString class]] ? [plugin.installPath stringByAppendingPathComponent:themeRelative] : [plugin.installPath stringByAppendingPathComponent:@"theme.json"];
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:themePath isDirectory:&isDirectory] && !isDirectory) loadedSomething = YES;
    }

    if (failure.length > 0) {
        NSLog(@"[Plugin:%@] %@", plugin.pluginID, failure);
        self.contexts[plugin.pluginID] = nil;
        [self releaseNativePluginID:plugin.pluginID];
        [WitchPluginManager.shared noteRuntimeFailureForPluginID:plugin.pluginID];
        return NO;
    }
    if (!loadedSomething) {
        NSLog(@"[Plugin:%@] No supported entrypoint; marking inactive", plugin.pluginID);
        [WitchPluginManager.shared setPluginID:plugin.pluginID enabled:NO error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:marker error:nil];
        return NO;
    }
    [WitchPluginManager.shared noteRuntimeSuccessForPluginID:plugin.pluginID];
    NSLog(@"[Plugin:%@] Loaded %@ v%@", plugin.pluginID, plugin.name, plugin.version);
    [WitchPluginTheme reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:WitchPluginsDidChangeNotification object:self];
    return YES;
}

@end
