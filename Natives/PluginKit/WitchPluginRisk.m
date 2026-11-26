#import "WitchPluginRisk.h"

static NSSet *WPRiskSafePermissions(void);
static NSSet *WPRiskWarningPermissions(void);
static NSSet *WPRiskDangerousPermissions(void);
static NSSet *WPRiskBinaryExtensions(void);
static NSSet *WPRiskScriptExtensions(void);
static NSArray<NSDictionary *> *WPRiskJavaScriptPatterns(void);

static NSString *WPRiskString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *WPRiskFileSize(unsigned long long bytes) {
    if (bytes < 1024ULL) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024ULL * 1024ULL) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
}

#pragma mark - Finding

@implementation WitchPluginRiskFinding

- (instancetype)initWithLevel:(WitchPluginRiskLevel)level
                          code:(NSString *)code
                         title:(NSString *)title
                        detail:(NSString *)detail {
    self = [super init];
    if (self) {
        _level = level;
        _code = [code copy] ?: @"";
        _title = [title copy] ?: @"";
        _detail = [detail copy] ?: @"";
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"level": @(self.level),
        @"code": self.code ?: @"",
        @"title": self.title ?: @"",
        @"detail": self.detail ?: @""
    };
}

+ (nullable instancetype)findingWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    return [[self alloc] initWithLevel:(WitchPluginRiskLevel)[dictionary[@"level"] integerValue]
                                  code:WPRiskString(dictionary[@"code"])
                                 title:WPRiskString(dictionary[@"title"])
                                detail:WPRiskString(dictionary[@"detail"])];
}

@end

#pragma mark - Report

@implementation WitchPluginRiskReport

+ (WitchPluginRiskReport *)analyzeManifest:(NSDictionary *)manifest directory:(NSString *)directory {
    NSDictionary *safeManifest = [manifest isKindOfClass:[NSDictionary class]] ? manifest : @{};
    NSMutableArray<WitchPluginRiskFinding *> *findings = [NSMutableArray array];
    NSMutableArray<NSString *> *summary = [NSMutableArray array];

    NSDictionary *entrypoints = [safeManifest[@"entrypoints"] isKindOfClass:[NSDictionary class]] ? safeManifest[@"entrypoints"] : @{};
    NSString *jsEntry = WPRiskString(entrypoints[@"js"]);
    NSString *nativeEntry = WPRiskString(entrypoints[@"native"]);
    NSString *javaEntry = WPRiskString(entrypoints[@"java"]);
    id ui = safeManifest[@"ui"];
    NSString *themePath = [ui isKindOfClass:[NSString class]] ? ui : nil;
    if ([ui isKindOfClass:[NSDictionary class]]) themePath = WPRiskString(ui[@"theme"]);

    // ---- Declared permissions -------------------------------------------------
    NSArray *permissions = [safeManifest[@"permissions"] isKindOfClass:[NSArray class]] ? safeManifest[@"permissions"] : @[];
    for (id item in permissions) {
        NSString *permission = WPRiskString(item).lowercaseString;
        if (permission.length == 0) continue;
        if ([WPRiskDangerousPermissions() containsObject:permission]) {
            [findings addObject:[[WitchPluginRiskFinding alloc]
                initWithLevel:WitchPluginRiskLevelDangerous
                        code:@"dangerous-permission"
                       title:[NSString stringWithFormat:@"Sensitive permission: %@", permission]
                      detail:@"This permission reaches outside the plugin sandbox."]];
        } else if ([WPRiskWarningPermissions() containsObject:permission]) {
            [findings addObject:[[WitchPluginRiskFinding alloc]
                initWithLevel:WitchPluginRiskLevelWarning
                        code:@"permission"
                       title:[NSString stringWithFormat:@"Permission: %@", permission]
                      detail:@"The plugin asks for access beyond plain settings and theme data."]];
        } else if (![WPRiskSafePermissions() containsObject:permission]) {
            [findings addObject:[[WitchPluginRiskFinding alloc]
                initWithLevel:WitchPluginRiskLevelWarning
                        code:@"unknown-permission"
                       title:[NSString stringWithFormat:@"Unrecognized permission: %@", permission]
                      detail:@"The launcher does not know what this permission allows."]];
        }
    }

    // ---- Entrypoints the launcher will execute --------------------------------
    if (nativeEntry.length > 0) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelDangerous
                    code:@"native-entrypoint"
                   title:@"Runs native code inside the launcher"
                  detail:[NSString stringWithFormat:@"%@ is loaded into the launcher process and cannot be sandboxed.", nativeEntry.lastPathComponent]]];
        [summary addObject:[NSString stringWithFormat:@"Native code: %@ (runs in the launcher process)", nativeEntry.lastPathComponent]];
    }
    if (jsEntry.length > 0) {
        [summary addObject:[NSString stringWithFormat:@"JavaScript: %@", jsEntry.lastPathComponent]];
    }
    if (javaEntry.length > 0) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelWarning
                    code:@"java-entrypoint"
                   title:@"Declares a Java agent"
                  detail:[NSString stringWithFormat:@"%@ is registered but not executed in this build.", javaEntry.lastPathComponent]]];
        [summary addObject:[NSString stringWithFormat:@"Java agent: %@ (registered, not executed)", javaEntry.lastPathComponent]];
    }
    if (themePath.length > 0) {
        [summary addObject:[NSString stringWithFormat:@"Theme file: %@", themePath.lastPathComponent]];
    } else {
        [summary addObject:@"Theme file: none"];
    }
    NSArray *settingsSchema = [safeManifest[@"settings"] isKindOfClass:[NSArray class]] ? safeManifest[@"settings"] : @[];
    [summary addObject:[NSString stringWithFormat:@"Declarative settings: %lu", (unsigned long)settingsSchema.count]];

    // ---- Payload inspection ---------------------------------------------------
    if (directory.length > 0) {
        [self inspectDirectory:directory
                       jsEntry:jsEntry
                      findings:findings
                       summary:summary];
    }

    WitchPluginRiskLevel level = WitchPluginRiskLevelSafe;
    for (WitchPluginRiskFinding *finding in findings) {
        if (finding.level > level) level = finding.level;
    }
    WitchPluginRiskReport *report = [[WitchPluginRiskReport alloc] init];
    report->_level = level;
    report->_findings = [findings copy];
    report->_executionSummary = [summary copy];
    report->_sandboxRequired = (level != WitchPluginRiskLevelSafe);
    return report;
}

+ (void)inspectDirectory:(NSString *)directory
                  jsEntry:(NSString *)jsEntry
                 findings:(NSMutableArray<WitchPluginRiskFinding *> *)findings
                  summary:(NSMutableArray<NSString *> *)summary {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath:directory];
    NSUInteger fileCount = 0;
    unsigned long long totalBytes = 0;
    NSMutableArray<NSString *> *binaryPayloads = [NSMutableArray array];
    NSMutableArray<NSString *> *scriptPayloads = [NSMutableArray array];
    NSString *jsPath = jsEntry.length > 0 ? [directory stringByAppendingPathComponent:jsEntry] : nil;

    for (NSString *relative in enumerator) {
        NSString *full = [directory stringByAppendingPathComponent:relative];
        NSDictionary *attributes = [manager attributesOfItemAtPath:full error:nil];
        if ([attributes[NSFileType] isEqualToString:NSFileTypeDirectory]) continue;
        fileCount++;
        unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
        totalBytes += size;
        NSString *extension = relative.pathExtension.lowercaseString;
        if ([WPRiskBinaryExtensions() containsObject:extension]) {
            [binaryPayloads addObject:relative];
        } else if ([WPRiskScriptExtensions() containsObject:extension]) {
            [scriptPayloads addObject:relative];
        }
    }

    if (binaryPayloads.count > 0) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelDangerous
                    code:@"binary-payload"
                   title:@"Ships a native binary"
                  detail:[NSString stringWithFormat:@"%@ is a compiled payload that the launcher cannot inspect safely.", binaryPayloads.firstObject]]];
    }
    if (scriptPayloads.count > 0) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelWarning
                    code:@"script-payload"
                   title:@"Ships an executable script"
                  detail:[NSString stringWithFormat:@"%@ is an extra executable payload that is not executed by the launcher.", scriptPayloads.firstObject]]];
    }
    if (fileCount > 1024) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelDangerous
                    code:@"file-count"
                   title:@"Unusually large package"
                  detail:[NSString stringWithFormat:@"The package holds %lu files.", (unsigned long)fileCount]]];
    } else if (fileCount > 512) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelWarning
                    code:@"file-count"
                   title:@"Large package"
                  detail:[NSString stringWithFormat:@"The package holds %lu files.", (unsigned long)fileCount]]];
    }
    if (totalBytes > 16ULL * 1024 * 1024) {
        [findings addObject:[[WitchPluginRiskFinding alloc]
            initWithLevel:WitchPluginRiskLevelWarning
                    code:@"package-size"
                   title:@"Large payload"
                  detail:[NSString stringWithFormat:@"The package expands to %@.", WPRiskFileSize(totalBytes)]]];
    }

    if (jsPath.length > 0) {
        NSData *data = [NSData dataWithContentsOfFile:jsPath options:NSDataReadingMappedIfSafe error:nil];
        NSString *source = data.length > 0 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        if (source.length > 0) {
            for (NSDictionary *pattern in WPRiskJavaScriptPatterns()) {
                NSString *needle = pattern[@"pattern"];
                if (needle.length == 0) continue;
                NSRange range = [source rangeOfString:needle options:NSRegularExpressionSearch];
                if (range.location == NSNotFound) continue;
                [findings addObject:[[WitchPluginRiskFinding alloc]
                    initWithLevel:(WitchPluginRiskLevel)[pattern[@"level"] integerValue]
                            code:pattern[@"code"]
                           title:pattern[@"title"]
                          detail:pattern[@"detail"]]];
            }
        }
    }
}

- (WitchPluginRiskReport *)reportByMergingFindings:(NSArray<WitchPluginRiskFinding *> *)findings {
    if (findings.count == 0) return self;
    NSMutableArray<WitchPluginRiskFinding *> *merged = [self.findings mutableCopy];
    for (WitchPluginRiskFinding *finding in findings) {
        if (!finding) continue;
        BOOL duplicate = NO;
        for (WitchPluginRiskFinding *existing in merged) {
            if ([existing.code isEqualToString:finding.code] && [existing.title isEqualToString:finding.title]) {
                duplicate = YES;
                break;
            }
        }
        if (!duplicate) [merged addObject:finding];
    }
    WitchPluginRiskLevel level = WitchPluginRiskLevelSafe;
    for (WitchPluginRiskFinding *finding in merged) {
        if (finding.level > level) level = finding.level;
    }
    WitchPluginRiskReport *report = [[WitchPluginRiskReport alloc] init];
    report->_level = level;
    report->_findings = [merged copy];
    report->_executionSummary = self.executionSummary;
    report->_sandboxRequired = (level != WitchPluginRiskLevelSafe);
    return report;
}

+ (WitchPluginRiskReport *)reportFromDictionary:(NSDictionary *)dictionary {
    NSMutableArray<WitchPluginRiskFinding *> *findings = [NSMutableArray array];
    NSArray *rawFindings = [dictionary[@"findings"] isKindOfClass:[NSArray class]] ? dictionary[@"findings"] : @[];
    for (id item in rawFindings) {
        WitchPluginRiskFinding *finding = [WitchPluginRiskFinding findingWithDictionary:item];
        if (finding) [findings addObject:finding];
    }
    NSMutableArray<NSString *> *summary = [NSMutableArray array];
    NSArray *rawSummary = [dictionary[@"executionSummary"] isKindOfClass:[NSArray class]] ? dictionary[@"executionSummary"] : @[];
    for (id item in rawSummary) {
        NSString *text = WPRiskString(item);
        if (text.length > 0) [summary addObject:text];
    }
    WitchPluginRiskLevel level = (WitchPluginRiskLevel)[dictionary[@"level"] integerValue];
    for (WitchPluginRiskFinding *finding in findings) {
        if (finding.level > level) level = finding.level;
    }
    WitchPluginRiskReport *report = [[WitchPluginRiskReport alloc] init];
    report->_level = level;
    report->_findings = [findings copy];
    report->_executionSummary = [summary copy];
    report->_sandboxRequired = [dictionary[@"sandboxRequired"] boolValue] || level != WitchPluginRiskLevelSafe;
    return report;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *findings = [NSMutableArray array];
    for (WitchPluginRiskFinding *finding in self.findings) {
        [findings addObject:[finding dictionaryRepresentation]];
    }
    return @{
        @"level": @(self.level),
        @"findings": findings,
        @"executionSummary": self.executionSummary ?: @[],
        @"sandboxRequired": @(self.sandboxRequired)
    };
}

- (NSString *)levelLabel {
    switch (self.level) {
        case WitchPluginRiskLevelDangerous: return @"Dangerous";
        case WitchPluginRiskLevelWarning: return @"Warning";
        case WitchPluginRiskLevelSafe:
        default: return @"Safe";
    }
}

@end

#pragma mark - Rule tables

static NSSet *WPRiskSafePermissions(void) {
    static NSSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"settings", @"theme", @"storage", @"logs", @"none", @"read-only"]];
    });
    return set;
}

static NSSet *WPRiskWarningPermissions(void) {
    static NSSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"network", @"http", @"https", @"socket", @"download", @"clipboard",
                                     @"notification", @"ui", @"feature", @"storage-write", @"webview"]];
    });
    return set;
}

static NSSet *WPRiskDangerousPermissions(void) {
    static NSSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"filesystem", @"file-system", @"file", @"shell", @"exec", @"execute",
                                     @"process", @"spawn", @"keychain", @"camera", @"microphone",
                                     @"location", @"gps", @"install", @"native", @"root", @"sandbox-escape",
                                     @"contacts", @"photos", @"screen-capture"]];
    });
    return set;
}

static NSSet *WPRiskBinaryExtensions(void) {
    static NSSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"dylib", @"so", @"a", @"framework", @"bundle", @"dll", @"exe", @"bin"]];
    });
    return set;
}

static NSSet *WPRiskScriptExtensions(void) {
    static NSSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"sh", @"bash", @"py", @"rb", @"pl", @"command", @"bat", @"ps1", @"jar"]];
    });
    return set;
}

static NSArray<NSDictionary *> *WPRiskJavaScriptPatterns(void) {
    static NSArray *patterns = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        patterns = @[
            @{@"code": @"js-host-bridge",
              @"level": @(WitchPluginRiskLevelDangerous),
              @"pattern": @"\\b(ObjC|WebKit|PHP|importScripts|import\\s*\\()",
              @"title": @"Bridges into the host runtime",
              @"detail": @"The script reaches for native bridge objects that are not part of the plugin API."},
            @{@"code": @"js-eval",
              @"level": @(WitchPluginRiskLevelWarning),
              @"pattern": @"(^|[^\\w.])eval\\s*\\(",
              @"title": @"Dynamic code evaluation",
              @"detail": @"The script builds and runs new code at runtime, so its real behaviour is not visible in the file."},
            @{@"code": @"js-function-constructor",
              @"level": @(WitchPluginRiskLevelWarning),
              @"pattern": @"new\\s+Function\\s*\\(",
              @"title": @"Dynamic function construction",
              @"detail": @"The script compiles functions from strings, which hides what actually runs."},
            @{@"code": @"js-network",
              @"level": @(WitchPluginRiskLevelWarning),
              @"pattern": @"\\b(XMLHttpRequest|WebSocket|EventSource|sendBeacon)\\b|\\bfetch\\s*\\(",
              @"title": @"Network access from JavaScript",
              @"detail": @"The script talks to the network, so it can send or receive data on its own."},
            @{@"code": @"js-storage",
              @"level": @(WitchPluginRiskLevelWarning),
              @"pattern": @"\\b(localStorage|sessionStorage|indexedDB)\\b",
              @"title": @"Browser storage APIs",
              @"detail": @"The script uses web storage APIs that have no meaning inside the launcher."},
        ];
    });
    return patterns;
}
