#import "WitchPluginSandbox.h"
#import <JavaScriptCore/JavaScriptCore.h>

static const NSTimeInterval PSSandboxBudget = 3.0;
static const NSUInteger PSSandboxMaxCalls = 512;

static NSString *PSSandboxString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

#pragma mark - Report

@interface WitchPluginSandboxReport ()
@property (nonatomic, readwrite) WitchPluginSandboxVerdict verdict;
@property (nonatomic, readwrite) BOOL executed;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *observations;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *blocked;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *errors;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *capabilities;
@property (nonatomic, readwrite) NSTimeInterval duration;
@property (nonatomic, readwrite, copy) NSArray<WitchPluginRiskFinding *> *findings;
@end

@implementation WitchPluginSandboxReport

+ (WitchPluginSandboxReport *)reportFromDictionary:(NSDictionary *)dictionary {
    WitchPluginSandboxReport *report = [[WitchPluginSandboxReport alloc] init];
    if (![dictionary isKindOfClass:[NSDictionary class]]) return report;
    report.verdict = (WitchPluginSandboxVerdict)[dictionary[@"verdict"] integerValue];
    report.executed = [dictionary[@"executed"] boolValue];
    report.duration = [dictionary[@"duration"] doubleValue];
    report.observations = [dictionary[@"observations"] isKindOfClass:[NSArray class]] ? dictionary[@"observations"] : @[];
    report.blocked = [dictionary[@"blocked"] isKindOfClass:[NSArray class]] ? dictionary[@"blocked"] : @[];
    report.errors = [dictionary[@"errors"] isKindOfClass:[NSArray class]] ? dictionary[@"errors"] : @[];
    report.capabilities = [dictionary[@"capabilities"] isKindOfClass:[NSArray class]] ? dictionary[@"capabilities"] : @[];
    NSMutableArray *findings = [NSMutableArray array];
    NSArray *raw = [dictionary[@"findings"] isKindOfClass:[NSArray class]] ? dictionary[@"findings"] : @[];
    for (id item in raw) {
        WitchPluginRiskFinding *finding = [WitchPluginRiskFinding findingWithDictionary:item];
        if (finding) [findings addObject:finding];
    }
    report.findings = findings;
    return report;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *findings = [NSMutableArray array];
    for (WitchPluginRiskFinding *finding in self.findings) {
        [findings addObject:[finding dictionaryRepresentation]];
    }
    return @{
        @"verdict": @(self.verdict),
        @"executed": @(self.executed),
        @"duration": @(self.duration),
        @"observations": self.observations ?: @[],
        @"blocked": self.blocked ?: @[],
        @"errors": self.errors ?: @[],
        @"capabilities": self.capabilities ?: @[],
        @"findings": findings
    };
}

- (NSString *)verdictLabel {
    switch (self.verdict) {
        case WitchPluginSandboxVerdictFailed: return @"Failed";
        case WitchPluginSandboxVerdictBlocked: return @"Blocked";
        case WitchPluginSandboxVerdictClean:
        default: return @"Clean";
    }
}

@end

#pragma mark - Recorder

// The rehearsal uses the exact names the plugin will use at runtime, so a
// script is measured the way it will really behave.
@protocol PSSandboxBridgeExport <JSExport>

@property (nonatomic, readonly, copy) NSString *pluginID;
@property (nonatomic, readonly, copy) NSString *version;

JSExportAs(log, - (void)logMessage:(NSString *)message);
JSExportAs(getSetting, - (id)getSetting:(NSString *)key fallback:(id)fallback);
JSExportAs(setSetting, - (void)setSetting:(NSString *)key value:(id)value);
JSExportAs(setThemeColor, - (void)setThemeColor:(NSString *)key hex:(NSString *)hex);
- (void)reloadTheme;

@end

// Records everything the script asks of the launcher. It never touches the
// real state, the theme or the settings of the launcher.
@interface PSSandboxRecorder : NSObject <PSSandboxBridgeExport>
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, strong) NSMutableArray<NSString *> *observations;
@property (nonatomic, strong) NSMutableArray<NSString *> *blocked;
@property (nonatomic, strong) NSMutableArray<NSString *> *errors;
@property (nonatomic) NSInteger callCount;
- (void)recordBlocked:(NSString *)name;
- (void)recordError:(NSString *)message;
@end

@implementation PSSandboxRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _observations = [NSMutableArray array];
        _blocked = [NSMutableArray array];
        _errors = [NSMutableArray array];
    }
    return self;
}

- (void)note:(NSString *)entry {
    self.callCount++;
    if (self.observations.count >= PSSandboxMaxCalls) return;
    [self.observations addObject:entry];
}

- (void)logMessage:(NSString *)message {
    [self note:[NSString stringWithFormat:@"Witch.log(%@)", PSSandboxString(message)]];
}

- (id)getSetting:(NSString *)key fallback:(id)fallback {
    [self note:[NSString stringWithFormat:@"Witch.getSetting(%@)", PSSandboxString(key)]];
    return fallback;
}

- (void)setSetting:(NSString *)key value:(id)value {
    [self note:[NSString stringWithFormat:@"Witch.setSetting(%@)", PSSandboxString(key)]];
}

- (void)setThemeColor:(NSString *)key hex:(NSString *)hex {
    [self note:[NSString stringWithFormat:@"Witch.setThemeColor(%@)", PSSandboxString(key)]];
}

- (void)reloadTheme {
    [self note:@"Witch.reloadTheme()"];
}

- (void)recordBlocked:(NSString *)name {
    if (self.blocked.count >= PSSandboxMaxCalls) return;
    [self.blocked addObject:name];
}

- (void)recordError:(NSString *)message {
    if (self.errors.count >= PSSandboxMaxCalls) return;
    [self.errors addObject:message];
}

@end

#pragma mark - Probe

@implementation WitchPluginSandboxProbe

+ (WitchPluginSandboxReport *)probeManifest:(NSDictionary *)manifest directory:(NSString *)directory {
    return [self probeManifest:manifest directory:directory cacheKey:nil];
}

+ (WitchPluginSandboxReport *)probeManifest:(NSDictionary *)manifest
                                   directory:(NSString *)directory
                                   cacheKey:(NSString *)cacheKey {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
    if (cacheKey.length > 0) {
        WitchPluginSandboxReport *cached = [cache objectForKey:cacheKey];
        if (cached) return cached;
    }

    WitchPluginSandboxReport *report = [[WitchPluginSandboxReport alloc] init];
    report.observations = @[];
    report.blocked = @[];
    report.errors = @[];
    report.capabilities = @[];
    report.findings = @[];

    NSDictionary *safeManifest = [manifest isKindOfClass:[NSDictionary class]] ? manifest : @{};
    NSDictionary *entrypoints = [safeManifest[@"entrypoints"] isKindOfClass:[NSDictionary class]] ? safeManifest[@"entrypoints"] : @{};
    NSString *jsEntry = PSSandboxString(entrypoints[@"js"]);
    NSString *nativeEntry = PSSandboxString(entrypoints[@"native"]);

    PSSandboxRecorder *recorder = [[PSSandboxRecorder alloc] init];
    recorder.pluginID = PSSandboxString(safeManifest[@"id"]);
    recorder.version = PSSandboxString(safeManifest[@"version"]);
    if (jsEntry.length > 0 && directory.length > 0) {
        [self rehearseScript:[directory stringByAppendingPathComponent:jsEntry] recorder:recorder report:report];
    }
    if (nativeEntry.length > 0 && directory.length > 0) {
        [self scanNativePayload:[directory stringByAppendingPathComponent:nativeEntry] report:report];
    }

    report.observations = [recorder.observations copy];
    report.blocked = [recorder.blocked copy];
    report.errors = [recorder.errors copy];
    report.verdict = [self verdictForReport:report];
    report.findings = [self findingsForReport:report manifest:safeManifest];

    if (cacheKey.length > 0) [cache setObject:report forKey:cacheKey];
    return report;
}

#pragma mark - JavaScript rehearsal

// The rehearsal runs the script the way the sandboxed runtime would run it,
// except that the dangerous globals answer with a recorder instead of
// disappearing. That is what makes an attempt visible.
+ (NSString *)bootstrapScript {
    return @"var __psg = (typeof globalThis !== 'undefined') ? globalThis : this;"
    @"var __psb = function(name){ __ps_probe_blocked(name); };"
    @"var __psstub = function(name){ return function(){ __psb(name); }; };"
    @"var __psproxy = function(name){ return new Proxy({}, { get: function(t, p){ __psb(name + '.' + String(p)); return function(){ __psb(name + '.' + String(p)); }; } }); };"
    @"try { __psg.eval = __psstub('eval'); } catch (e) {}"
    @"try { __psg.Function = __psstub('Function'); } catch (e) {}"
    @"try { __psg.importScripts = __psstub('importScripts'); } catch (e) {}"
    @"try { __psg.WebKit = __psproxy('WebKit'); } catch (e) {}"
    @"try { __psg.ObjC = __psproxy('ObjC'); } catch (e) {}"
    @"try { __psg.PHP = __psproxy('PHP'); } catch (e) {}"
    @"try { __psg.fetch = __psstub('fetch'); } catch (e) {}"
    @"try { __psg.XMLHttpRequest = function(){ __psb('XMLHttpRequest'); }; } catch (e) {}"
    @"try { __psg.WebSocket = function(){ __psb('WebSocket'); }; } catch (e) {}"
    @"try { __psg.EventSource = function(){ __psb('EventSource'); }; } catch (e) {}"
    @"try { __psg.sendBeacon = __psstub('sendBeacon'); } catch (e) {}"
    @"try { __psg.localStorage = __psproxy('localStorage'); } catch (e) {}"
    @"try { __psg.sessionStorage = __psproxy('sessionStorage'); } catch (e) {}"
    @"try { __psg.indexedDB = __psproxy('indexedDB'); } catch (e) {}";
}

+ (void)rehearseScript:(NSString *)path recorder:(PSSandboxRecorder *)recorder report:(WitchPluginSandboxReport *)report {
    NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!script) {
        [recorder recordError:@"The script could not be read"];
        return;
    }
    report.executed = YES;

    // A dedicated queue: a script that never returns must not hold up the
    // launcher. The queue is abandoned when the budget runs out.
    dispatch_queue_t queue = dispatch_queue_create("witch.plugin.probe", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block NSTimeInterval elapsed = 0;

    dispatch_async(queue, ^{
        NSDate *start = [NSDate date];
        JSVirtualMachine *machine = [[JSVirtualMachine alloc] init];
        JSContext *context = [[JSContext alloc] initWithVirtualMachine:machine];
        context[@"__ps_probe_blocked"] = ^(NSString *name) {
            [recorder recordBlocked:PSSandboxString(name)];
        };
        context[@"Witch"] = recorder;
        context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
            [recorder recordError:[NSString stringWithFormat:@"%@", exception]];
        };
        [context evaluateScript:[self bootstrapScript] withSourceURL:[NSURL fileURLWithPath:path]];
        [context evaluateScript:script withSourceURL:[NSURL fileURLWithPath:path]];
        JSValue *exception = context.exception;
        if (exception) [recorder recordError:[NSString stringWithFormat:@"%@", exception]];
        elapsed = -[start timeIntervalSinceNow];
        dispatch_semaphore_signal(finished);
    });

    long wait = dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PSSandboxBudget * NSEC_PER_SEC)));
    report.duration = elapsed > 0 ? elapsed : PSSandboxBudget;
    if (wait != 0) {
        [recorder recordError:[NSString stringWithFormat:@"The script did not finish within %.0f seconds", PSSandboxBudget]];
    }
}

#pragma mark - Native capability scan

// A native payload cannot be executed safely, not even to find out what it
// does. Its capabilities are read from the binary instead: the launcher
// knows which system APIs the file carries, and that is what it would be
// able to do.
+ (void)scanNativePayload:(NSString *)path report:(WitchPluginSandboxReport *)report {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length == 0) return;
    report.executed = YES;
    NSMutableArray<NSString *> *capabilities = [NSMutableArray array];
    for (NSDictionary *rule in [self capabilityRules]) {
        for (NSString *token in rule[@"tokens"]) {
            NSData *needle = [token dataUsingEncoding:NSUTF8StringEncoding];
            if (!needle || needle.length == 0) continue;
            if ([data rangeOfData:needle options:0 range:NSMakeRange(0, data.length)].location != NSNotFound) {
                [capabilities addObject:rule[@"title"]];
                break;
            }
        }
    }
    report.capabilities = [capabilities copy];
}

+ (NSArray<NSDictionary *> *)capabilityRules {
    static NSArray *rules = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        rules = @[
            @{@"code": @"native-exec",
              @"level": @(WitchPluginRiskLevelDangerous),
              @"title": @"Can start other processes",
              @"detail": @"The binary carries the system calls that start another program.",
              @"tokens": @[@"_system", @"_popen", @"_posix_spawn", @"_fork", @"_execve", @"_execv"]},
            @{@"code": @"native-dynamic",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can load other libraries",
              @"detail": @"The binary can load further code at runtime.",
              @"tokens": @[@"_dlopen", @"_dlsym", @"_NSBundleLoad"]},
            @{@"code": @"native-keychain",
              @"level": @(WitchPluginRiskLevelDangerous),
              @"title": @"Can read the keychain",
              @"detail": @"The binary carries the keychain API.",
              @"tokens": @[@"SecItemCopyMatching", @"SecItemAdd", @"SecItemUpdate", @"SecItemDelete"]},
            @{@"code": @"native-pasteboard",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can read the clipboard",
              @"detail": @"The binary carries the pasteboard API.",
              @"tokens": @[@"UIPasteboard", @"generalPasteboard"]},
            @{@"code": @"native-device",
              @"level": @(WitchPluginRiskLevelDangerous),
              @"title": @"Can reach the camera or the location",
              @"detail": @"The binary carries a capture or location API.",
              @"tokens": @[@"AVCaptureDevice", @"CLLocationManager", @"PHPhotoLibrary", @"AVAudioSession"]},
            @{@"code": @"native-network",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can open network connections",
              @"detail": @"The binary carries a network API.",
              @"tokens": @[@"NSURLSession", @"CFStreamCreatePairWithSocket", @"_socket", @"_connect"]},
            @{@"code": @"native-files-write",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can write files",
              @"detail": @"The binary carries the file writing APIs.",
              @"tokens": @[@"copyItemAtPath:", @"moveItemAtPath:", @"writeToFile:", @"createDirectoryAtPath:", @"removeItemAtPath:", @"truncateFileAtPath:"]},
            @{@"code": @"native-files-read",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can read files",
              @"detail": @"The binary carries the file reading APIs.",
              @"tokens": @[@"contentsOfDirectoryAtPath:", @"dataWithContentsOfFile:", @"attributesOfItemAtPath:", @"contentsOfFile:", @"fopen"]},
            @{@"code": @"native-process-info",
              @"level": @(WitchPluginRiskLevelWarning),
              @"title": @"Can inspect the running processes",
              @"detail": @"The binary carries the process inspection APIs.",
              @"tokens": @[@"task_info", @"_sysctl", @"ctl_getinfo", @"NSTask"]}
        ];
    });
    return rules;
}

#pragma mark - Findings

+ (WitchPluginSandboxVerdict)verdictForReport:(WitchPluginSandboxReport *)report {
    if (report.errors.count > 0) return WitchPluginSandboxVerdictFailed;
    if (report.blocked.count > 0) return WitchPluginSandboxVerdictBlocked;
    return WitchPluginSandboxVerdictClean;
}

+ (NSArray<WitchPluginRiskFinding *> *)findingsForReport:(WitchPluginSandboxReport *)report
                                               manifest:(NSDictionary *)manifest {
    NSMutableArray<WitchPluginRiskFinding *> *findings = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSString *blocked in report.blocked) {
        NSString *name = [blocked lowercaseString];
        WitchPluginRiskLevel level = WitchPluginRiskLevelWarning;
        NSString *title = [NSString stringWithFormat:@"The script tried to use %@", blocked];
        NSString *detail = @"The sandbox refused the call while the package was verified.";
        if ([name hasPrefix:@"objc"] || [name hasPrefix:@"webkit"] || [name hasPrefix:@"php"]) {
            level = WitchPluginRiskLevelDangerous;
            detail = @"The script reached for the host runtime, which the launcher only allows to native plugins.";
        } else if ([name hasPrefix:@"eval"] || [name hasPrefix:@"function"]) {
            detail = @"The script builds and runs code that is not visible in the file.";
        } else if ([name hasPrefix:@"fetch"] || [name hasPrefix:@"xmlhttp"] || [name hasPrefix:@"websocket"] || [name hasPrefix:@"eventsource"] || [name hasPrefix:@"sendbeacon"]) {
            detail = @"The script talks to the network on its own.";
        } else if ([name hasPrefix:@"localstorage"] || [name hasPrefix:@"sessionstorage"] || [name hasPrefix:@"indexeddb"]) {
            detail = @"The script uses web storage APIs that have no meaning inside the launcher.";
        }
        NSString *key = [NSString stringWithFormat:@"sandbox-blocked-%@", blocked];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [findings addObject:[[WitchPluginRiskFinding alloc] initWithLevel:level code:@"sandbox-blocked" title:title detail:detail]];
    }

    for (NSString *error in report.errors) {
        NSString *key = @"sandbox-failed";
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        WitchPluginRiskLevel level = [error containsString:@"did not finish"] ? WitchPluginRiskLevelDangerous : WitchPluginRiskLevelWarning;
        NSString *title = [error containsString:@"did not finish"] ? @"The script never finished" : @"The script failed while it was verified";
        [findings addObject:[[WitchPluginRiskFinding alloc] initWithLevel:level code:@"sandbox-failed" title:title detail:error]];
    }

    for (NSString *capability in report.capabilities) {
        NSString *key = [NSString stringWithFormat:@"sandbox-capability-%@", capability];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        WitchPluginRiskLevel level = WitchPluginRiskLevelWarning;
        for (NSDictionary *rule in [self capabilityRules]) {
            if ([rule[@"title"] isEqualToString:capability]) {
                level = (WitchPluginRiskLevel)[rule[@"level"] integerValue];
                [findings addObject:[[WitchPluginRiskFinding alloc] initWithLevel:level
                                                                              code:[@"sandbox-" stringByAppendingString:rule[@"code"]]
                                                                             title:capability
                                                                            detail:rule[@"detail"]]];
                break;
            }
        }
    }

    // A script that changes the theme while it starts is visible behaviour.
    // A plugin that declares a theme file is expected to do it, so only an
    // undeclared theme change is a finding.
    id ui = manifest[@"ui"];
    BOOL declaresTheme = [ui isKindOfClass:[NSString class]] ||
                          ([ui isKindOfClass:[NSDictionary class]] && [ui[@"theme"] isKindOfClass:[NSString class]]);
    if (!declaresTheme) {
        for (NSString *observation in report.observations) {
            if (![observation hasPrefix:@"Witch.setThemeColor"]) continue;
            NSString *key = @"sandbox-theme";
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
            [findings addObject:[[WitchPluginRiskFinding alloc] initWithLevel:WitchPluginRiskLevelWarning
                                                                            code:@"sandbox-theme"
                                                                           title:@"The script changes the theme at launch"
                                                                          detail:@"The launcher applied a theme color while the package was verified, and the plugin does not declare a theme file."]];
            break;
        }
    }

    if (report.observations.count >= PSSandboxMaxCalls) {
        [findings addObject:[[WitchPluginRiskFinding alloc] initWithLevel:WitchPluginRiskLevelWarning
                                                                        code:@"sandbox-call-volume"
                                                                       title:@"The script calls the launcher a lot"
                                                                      detail:[NSString stringWithFormat:@"%lu calls were recorded during the verification.", (unsigned long)report.observations.count]]];
    }
    return findings;
}

@end
