#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "utils.h"

@implementation VersionProfile

+ (NSString *)cleanMinecraftVersion:(NSString *)rawVersion {
    if (!rawVersion) return nil;

    if ([rawVersion hasPrefix:@"fabric-loader-"]) {
        NSString *stripped = [rawVersion substringFromIndex:@"fabric-loader-".length];
        NSRange hyphen = [stripped rangeOfString:@"-"];
        if (hyphen.location != NSNotFound) {
            return [stripped substringFromIndex:hyphen.location + 1];
        }
        return stripped;
    }
    if ([rawVersion hasPrefix:@"quilt-loader-"]) {
        NSString *stripped = [rawVersion substringFromIndex:@"quilt-loader-".length];
        NSRange hyphen = [stripped rangeOfString:@"-"];
        if (hyphen.location != NSNotFound) {
            return [stripped substringFromIndex:hyphen.location + 1];
        }
        return stripped;
    }

    if ([rawVersion hasPrefix:@"forge-"]) {
        NSString *stripped = [rawVersion substringFromIndex:@"forge-".length];
        NSRange hyphen = [stripped rangeOfString:@"-"];
        if (hyphen.location != NSNotFound) {
            return [stripped substringToIndex:hyphen.location];
        }
        return stripped;
    }

    if ([rawVersion hasPrefix:@"neoforge-"]) {
        NSString *stripped = [rawVersion substringFromIndex:@"neoforge-".length];
        NSRange hyphen = [stripped rangeOfString:@"-"];
        if (hyphen.location != NSNotFound) {
            return [stripped substringToIndex:hyphen.location];
        }
        return stripped;
    }

    // LabyMod ids look like "LabyMod-4-1.21.4-production"; the real Minecraft
    // version is the first dotted numeric token.
    if ([rawVersion rangeOfString:@"labymod" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[0-9]+(?:\\.[0-9]+)+" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:rawVersion options:0 range:NSMakeRange(0, rawVersion.length)];
        if (match) {
            return [rawVersion substringWithRange:match.range];
        }
    }

    return rawVersion;
}

+ (instancetype)profileWithVersionId:(NSString *)versionId {
    VersionProfile *profile = [[self alloc] init];
    profile.versionId = versionId;

    VersionDirectoryManager *mgr = VersionDirectoryManager.shared;
    NSString *jsonPath = [[mgr versionPathForVersion:versionId] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", versionId]];
    NSMutableDictionary *json = parseJSONFromFile(jsonPath);
    if (json == nil || json[@"NSErrorObject"] != nil) {
        profile.mcVersion = [self cleanMinecraftVersion:versionId];
        profile.modLoader = @"Vanilla";
        return profile;
    }

    if (json[@"_minecraftVersion"]) {
        // LabyMod manifests keep the real game version here and have no
        // "inheritsFrom" entry.
        profile.mcVersion = json[@"_minecraftVersion"];
    } else if (json[@"minecraftVersion"]) {
        profile.mcVersion = json[@"minecraftVersion"];
    } else if (json[@"inheritsFrom"]) {
        profile.mcVersion = json[@"inheritsFrom"];
    } else if (json[@"id"]) {
        profile.mcVersion = [self cleanMinecraftVersion:json[@"id"]];
    } else {
        profile.mcVersion = [self cleanMinecraftVersion:versionId];
    }

    if (!profile.mcVersion || [profile.mcVersion hasPrefix:@"forge-"] || [profile.mcVersion hasPrefix:@"neoforge-"]) {
        NSString *jsonMcVer = json[@"minecraftVersion"];
        if (jsonMcVer) {
            profile.mcVersion = jsonMcVer;
        }
    }

    NSString *declaredLoader = [json[@"modLoader"] isKindOfClass:[NSString class]] ? json[@"modLoader"] : nil;
    if (declaredLoader.length > 0) {
        // Modpack profiles written by MrpackInstaller carry an explicit loader.
        profile.modLoader = declaredLoader;
    } else if ([versionId.lowercaseString containsString:@"labymod"]) {
        profile.modLoader = @"LabyMod";
    } else if ([versionId.lowercaseString containsString:@"neoforge"]) {
        profile.modLoader = @"NeoForge";
    } else if ([versionId.lowercaseString containsString:@"fabric"]) {
        profile.modLoader = @"Fabric";
    } else if ([versionId.lowercaseString containsString:@"forge"]) {
        profile.modLoader = @"Forge";
    } else if ([versionId.lowercaseString containsString:@"quilt"]) {
        profile.modLoader = @"Quilt";
    } else if ([versionId.lowercaseString containsString:@"optifine"]) {
        profile.modLoader = @"OptiFine";
    } else if (json[@"inheritsFrom"] != nil) {
        NSString *mainClass = [json[@"mainClass"] isKindOfClass:[NSString class]] ? json[@"mainClass"] : @"";
        NSString *loaderHint = mainClass.lowercaseString;
        if ([loaderHint containsString:@"fabric"]) {
            profile.modLoader = @"Fabric";
        } else if ([loaderHint containsString:@"neoforged"] || [loaderHint containsString:@"neoforge"]) {
            profile.modLoader = @"NeoForge";
        } else if ([loaderHint containsString:@"forge"]) {
            profile.modLoader = @"Forge";
        } else if ([loaderHint containsString:@"quilt"]) {
            profile.modLoader = @"Quilt";
        } else if ([loaderHint containsString:@"optifine"]) {
            profile.modLoader = @"OptiFine";
        } else {
            profile.modLoader = @"Vanilla";
        }
    } else {
        profile.modLoader = @"Vanilla";
    }

    return profile;
}

- (NSString *)iconName {
    if ([self.modLoader isEqualToString:@"Fabric"]) return @"link.circle.fill";
    if ([self.modLoader isEqualToString:@"Forge"]) return @"hammer.circle.fill";
    if ([self.modLoader isEqualToString:@"Quilt"]) return @"square.grid.3x3.fill";
    if ([self.modLoader isEqualToString:@"NeoForge"]) return @"bolt.circle.fill";
    if ([self.modLoader isEqualToString:@"OptiFine"]) return @"sparkles.circle.fill";
    if ([self.modLoader isEqualToString:@"LabyMod"]) return @"paintpalette.fill";
    return @"cube.box.fill";
}

@end

@implementation VersionDirectoryManager

+ (VersionDirectoryManager *)shared {
    static VersionDirectoryManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentInstance = @"default";
        _currentVersion = @"";
    }
    return self;
}

- (void)setCurrentVersion:(NSString *)currentVersion {
    _currentVersion = currentVersion;
    [self refreshCurrentProfile];
}

+ (NSString *)autoDetectLwjglVersionForMcVersion:(NSString *)mcVersion {
    if (!mcVersion) return @"3.3.3";
    NSArray *parts = [mcVersion componentsSeparatedByString:@"."];
    if (parts.count < 2) return @"3.3.3";

    int major = [parts[0] intValue];

    // Mojang version manifests (piston-meta): 26.1+ use LWJGL 3.4.1 (SDL3 backend);
    // everything from 1.13 to 1.21.x uses LWJGL 3.x <= 3.3.3, and 1.8-1.12.x use
    // LWJGL 2 which is bridged by lwjglx inside our 3.3.3 build.
    if (major >= 26) return @"3.4.1";

    return @"3.3.3";
}

+ (NSString *)resolveEffectiveLwjglVersion {
    NSString *profileVersion = [PLProfiles resolveKeyForCurrentProfile:@"lwjglVersion"];
    if (profileVersion && ![profileVersion isEqualToString:@"(default)"] && ![profileVersion isEqualToString:@"(auto)"]) {
        return profileVersion;
    }

    NSString *mainVersion = getPrefObject(@"java.lwjgl_version");
    if (mainVersion && ![mainVersion isEqualToString:@"(auto)"]) {
        return mainVersion;
    }

    NSString *mcVersion = [VersionDirectoryManager.shared currentProfile] ? VersionDirectoryManager.shared.currentProfile.mcVersion : nil;
    NSString *detected = [self autoDetectLwjglVersionForMcVersion:mcVersion];
    return detected ?: @"3.3.3";
}

- (void)refreshCurrentProfile {
    if (_currentVersion.length > 0) {
        _currentProfile = [VersionProfile profileWithVersionId:_currentVersion];
    } else {
        _currentProfile = nil;
    }
}

- (NSString *)pojavHome {
    const char *home = getenv("POJAV_HOME");
    if (!home) home = getenv("HOME");
    return [NSString stringWithUTF8String:home ?: "/var/mobile"];
}

- (NSString *)instancePath {
    return [[self pojavHome] stringByAppendingPathComponent:[NSString stringWithFormat:@"instances/%@", self.currentInstance]];
}

- (NSString *)versionsRootPath {
    return [[self instancePath] stringByAppendingPathComponent:@"versions"];
}

- (NSString *)versionPathForVersion:(NSString *)version {
    return [[self versionsRootPath] stringByAppendingPathComponent:version];
}

- (NSString *)downloadsPath {
    return [[self pojavHome] stringByAppendingPathComponent:@"Downloads"];
}

- (NSString *)modsPathForVersion:(NSString *)version {
    if (version.length == 0) return [[self downloadsPath] stringByAppendingPathComponent:@"mods"];
    return [[self versionPathForVersion:version] stringByAppendingPathComponent:@"mods"];
}

- (NSString *)savesPathForVersion:(NSString *)version {
    if (version.length == 0) return [[self downloadsPath] stringByAppendingPathComponent:@"saves"];
    return [[self versionPathForVersion:version] stringByAppendingPathComponent:@"saves"];
}

- (NSString *)resourcePacksPathForVersion:(NSString *)version {
    if (version.length == 0) return [[self downloadsPath] stringByAppendingPathComponent:@"resourcepacks"];
    return [[self versionPathForVersion:version] stringByAppendingPathComponent:@"resourcepacks"];
}

- (NSString *)shaderPacksPathForVersion:(NSString *)version {
    if (version.length == 0) return [[self downloadsPath] stringByAppendingPathComponent:@"shaderpacks"];
    return [[self versionPathForVersion:version] stringByAppendingPathComponent:@"shaderpacks"];
}

- (NSString *)serversPathForVersion:(NSString *)version {
    if (version.length == 0) return [[self downloadsPath] stringByAppendingPathComponent:@"servers"];
    return [[self versionPathForVersion:version] stringByAppendingPathComponent:@"servers"];
}

- (void)ensureVersionDirectoriesForVersion:(NSString *)version {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[
        [self modsPathForVersion:version],
        [self savesPathForVersion:version],
        [self resourcePacksPathForVersion:version],
        [self shaderPacksPathForVersion:version],
        [self serversPathForVersion:version],
    ];
    for (NSString *dir in dirs) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (void)prepareGameDirectoryForVersion:(NSString *)version {
    self.currentVersion = version;

    NSString *instancePath = [self instancePath];
    // POJAV_GAME_DIR luôn là instance root để download tìm đúng path
    // (versions/, libraries/, assets/ là thư mục con của instance)
    setenv("POJAV_GAME_DIR", instancePath.UTF8String, 1);

    // Cập nhật symlink → version dir để game data (saves, options...)
    // ghi vào đúng thư mục của phiên bản
    NSString *versionDir = [self versionPathForVersion:version];
    NSString *lasmRoot = [NSString stringWithUTF8String:getenv("POJAV_HOME") ?: "/var/mobile"];
    NSString *lasmPath = [lasmRoot stringByAppendingPathComponent:@"Library/Application Support/minecraft"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:lasmPath error:nil];
    [fm createSymbolicLinkAtPath:lasmPath withDestinationPath:versionDir error:nil];
}

@end
