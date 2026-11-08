#include <CommonCrypto/CommonDigest.h>

#import "authenticator/BaseAuthenticator.h"
#import "LauncherPreferences.h"
#import "MinecraftResourceUtils.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "AFNetworking.h"

NSMutableArray<NSDictionary *> *localVersionList, *remoteVersionList;

@implementation MinecraftResourceUtils

// Handle inheritsFrom
+ (void)processVersion:(NSMutableDictionary *)json inheritsFrom:(NSMutableDictionary *)inheritsFrom {
    [self insertSafety:inheritsFrom from:json arr:@[
        @"assetIndex", @"assets", @"id",
        @"mainClass", @"minecraftArguments",
        @"optifineLib", @"releaseTime", @"time", @"type"
    ]];
    if (json[@"arguments"]) {
        inheritsFrom[@"arguments"] = json[@"arguments"];
    }

    for (NSMutableDictionary *lib in json[@"libraries"]) {
        NSString *libName = [lib[@"name"] substringToIndex:[lib[@"name"] rangeOfString:@":" options:NSBackwardsSearch].location];
        int i;
        for (i = 0; i < [inheritsFrom[@"libraries"] count]; i++) {
            NSMutableDictionary *libAdded = inheritsFrom[@"libraries"][i];
            NSString *libAddedName = [libAdded[@"name"] substringToIndex:[libAdded[@"name"] rangeOfString:@":" options:NSBackwardsSearch].location];

            if ([libAdded[@"name"] hasPrefix:libName]) {
                inheritsFrom[@"libraries"][i] = lib;
                i = -1;
                break;
            }
        }

        if (i != -1) {
            [inheritsFrom[@"libraries"] addObject:lib];
        }
    }

    //inheritsFrom[@"inheritsFrom"] = nil;
}

+ (void)insertSafety:(NSMutableDictionary *)targetVer from:(NSDictionary *)fromVer arr:(NSArray *)arr {
    for (NSString *key in arr) {
        if (([fromVer[key] isKindOfClass:NSString.class] && [fromVer[key] length] > 0) || targetVer[key] == nil) {
            targetVer[key] = fromVer[key];
        } else {
            NSLog(@"[MCDL] insertSafety: how to insert %@?", key);
        }
    }
}

+ (NSInteger)numberOfArgsToSkipForArg:(NSString *)arg {
    if (![arg isKindOfClass:NSString.class]) {
        // Skip non-string arg
        return 1;
    } else if ([arg hasPrefix:@"-cp"]) {
        // Skip "-cp <classpath>"
        return 2;
    } else if ([arg hasPrefix:@"-Djava.library.path="]) {
        return 1;
    } else if ([arg hasPrefix:@"-XX:HeapDumpPath"]) {
        return 1;
    } else {
        return 0;
    }
}

+ (BOOL)isLabyModVersionJson:(NSDictionary *)json {
    NSString *identifier = json[@"id"];
    if ([identifier isKindOfClass:NSString.class] &&
        [identifier rangeOfString:@"labymod" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    NSString *mainClass = json[@"mainClass"];
    if ([mainClass isKindOfClass:NSString.class] &&
        [mainClass rangeOfString:@"labymod" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    NSArray *libraries = [json[@"libraries"] isKindOfClass:NSArray.class] ? json[@"libraries"] : @[];
    for (NSDictionary *library in libraries) {
        if (![library isKindOfClass:NSDictionary.class]) continue;
        NSString *name = library[@"name"];
        if (![name isKindOfClass:NSString.class]) continue;
        if ([name hasPrefix:@"net.labymod:"] || [name hasPrefix:@"net.laby:"]) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)labyModMinecraftVersionForJson:(NSDictionary *)json {
    for (NSString *key in @[@"_minecraftVersion", @"minecraftVersion", @"inheritsFrom"]) {
        id value = json[key];
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            return value;
        }
    }
    NSArray *jvmArgs = json[@"arguments"][@"jvm"];
    if ([jvmArgs isKindOfClass:NSArray.class]) {
        NSString *prefix = @"-Dnet.labymod.running-version=";
        for (id arg in jvmArgs) {
            if ([arg isKindOfClass:NSString.class] && [arg hasPrefix:prefix]) {
                NSString *value = [arg substringFromIndex:prefix.length];
                if (value.length > 0) return value;
            }
        }
    }
    NSString *identifier = json[@"id"];
    if ([identifier isKindOfClass:NSString.class]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[0-9]+(?:\\.[0-9]+)+" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:identifier options:0 range:NSMakeRange(0, identifier.length)];
        if (match) return [identifier substringWithRange:match.range];
    }
    return nil;
}

+ (void)tweakVersionJson:(NSMutableDictionary *)json {
    // Exclude some libraries
    for (NSMutableDictionary *library in [json[@"libraries"] copy]) {
        library[@"skip"] = @(
            // Exclude platform-dependant libraries
            library[@"downloads"][@"classifiers"] != nil ||
            library[@"natives"] != nil ||
            // Exclude LWJGL libraries
            [library[@"name"] hasPrefix:@"org.lwjgl"]
        );

        NSArray *nameParts = [library[@"name"] componentsSeparatedByString:@":"];
        if (nameParts.count < 3) continue;
        NSString *versionStr = nameParts[2];
        NSArray<NSString *> *version = [versionStr componentsSeparatedByString:@"."];
        if ([library[@"name"] hasPrefix:@"net.java.dev.jna:jna:"]) {
            // Special handling for LabyMod 1.8.9 and Forge 1.12.2(?)
            // we have libjnidispatch 5.13.0 in Frameworks directory
            uint32_t bundledVer = 5 << 16 | 13 << 8 | 0;
            uint32_t requiredVer = (char)version[0].intValue << 16 | (char)version[1].intValue << 8 | (char)version[2].intValue;
            if (requiredVer > bundledVer) {
                NSLog(@"[MCDL] Warning: JNA version required by %@ is %@ > 5.13.0, skipping JNA replacement.", json[@"id"], versionStr);
                continue;
            }
            library[@"name"] = @"net.java.dev.jna:jna:5.13.0";
            library[@"downloads"][@"artifact"][@"path"] = @"net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar";
            library[@"downloads"][@"artifact"][@"url"] = @"https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar";
            library[@"downloads"][@"artifact"][@"sha1"] = @"1200e7ebeedbe0d10062093f32925a912020e747";
        } else if ([library[@"name"] hasPrefix:@"org.ow2.asm:asm-all:"]) {
            // Early versions of the ASM library get repalced with 5.0.4 because Pojav's LWJGL is compiled for
            // Java 8, which is not supported by old ASM versions. Mod loaders like Forge, which depend on this
            // library, often include lwjgl in their class transformations, which causes errors with old ASM versions.
            if(version[0].intValue >= 5) continue;
            library[@"name"] = @"org.ow2.asm:asm-all:5.0.4";
            library[@"downloads"][@"artifact"][@"path"] = @"org/ow2/asm/asm-all/5.0.4/asm-all-5.0.4.jar";
            library[@"downloads"][@"artifact"][@"sha1"] = @"e6244859997b3d4237a552669279780876228909";
            library[@"downloads"][@"artifact"][@"url"] = @"https://repo1.maven.org/maven2/org/ow2/asm/asm-all/5.0.4/asm-all-5.0.4.jar";
        } else if ([library[@"name"] hasPrefix:@"org.ow2.asm:asm:"] ||
                   [library[@"name"] hasPrefix:@"org.ow2.asm:asm-analysis:"] ||
                   [library[@"name"] hasPrefix:@"org.ow2.asm:asm-commons:"] ||
                   [library[@"name"] hasPrefix:@"org.ow2.asm:asm-tree:"] ||
                   [library[@"name"] hasPrefix:@"org.ow2.asm:asm-util:"]) {
            // Replace ASM < 9.9.1 with 9.9.1 for Java 25 class file support (major version 69).
            // 9.7.1 (used by Quilt meta and NeoForge < 26.2) cannot read Java 25 class files.
            if (version.count >= 2) {
                int major = version[0].intValue;
                int minor = version[1].intValue;
                int patch = version.count > 2 ? version[2].intValue : 0;
                if (major > 9 || (major == 9 && minor > 9) || (major == 9 && minor == 9 && patch >= 1)) {
                    continue;
                }
            }
            NSString *asmArtifact = nameParts[1];
            library[@"name"] = [NSString stringWithFormat:@"org.ow2.asm:%@:9.9.1", asmArtifact];
            library[@"url"] = @"https://repo1.maven.org/maven2/";
            library[@"downloads"] = [@{@"artifact": @{
                @"path": [NSString stringWithFormat:@"org/ow2/asm/%@/9.9.1/%@-9.9.1.jar", asmArtifact, asmArtifact],
                @"url": [NSString stringWithFormat:@"https://repo1.maven.org/maven2/org/ow2/asm/%@/9.9.1/%@-9.9.1.jar", asmArtifact, asmArtifact],
                @"sha1": @""
            }} mutableCopy];
        }
    }

    // Add the client as a library (skip if already present)
    NSString *clientName = [NSString stringWithFormat:@"%@.jar", json[@"id"]];
    BOOL clientExists = NO;
    for (NSDictionary *lib in json[@"libraries"]) {
        if ([lib[@"name"] isEqualToString:clientName]) {
            clientExists = YES;
            break;
        }
    }
    if (!clientExists) {
        NSMutableDictionary *client = [[NSMutableDictionary alloc] init];
        client[@"downloads"] = [[NSMutableDictionary alloc] init];
        client[@"name"] = clientName;
        client[@"downloads"][@"artifact"] = [[NSMutableDictionary alloc] init];
        client[@"downloads"][@"artifact"][@"path"] = [NSString stringWithFormat:@"../versions/%1$@/%1$@.jar", json[@"id"]];

        // If jar already on disk (e.g. from modpack installer), don't overwrite with base's vanilla jar
        NSString *gameDir = @(getenv("POJAV_GAME_DIR"));
        NSString *jarPath = [NSString stringWithFormat:@"%@/versions/%@/%@.jar", gameDir, json[@"id"], json[@"id"]];
        if ([NSFileManager.defaultManager fileExistsAtPath:jarPath]) {
            client[@"skip"] = @YES;
        } else if (json[@"downloads"][@"client"]) {
            client[@"downloads"][@"artifact"][@"url"] = json[@"downloads"][@"client"][@"url"];
            client[@"downloads"][@"artifact"][@"sha1"] = json[@"downloads"][@"client"][@"sha1"];
            client[@"downloads"][@"artifact"][@"size"] = json[@"downloads"][@"client"][@"size"];
        } else {
            client[@"skip"] = @YES;
        }
        [json[@"libraries"] addObject:client];
    }

    // Resolve loader-specific JVM arguments before JLI_Launch builds argv.
    // resolveFullInheritsChain merges the chain into the vanilla parent, so the
    // "inheritsFrom" key is gone by the time we get here; detect loader-style
    // module-path args by content instead (bootstraplauncher / ${...} markers).
    NSDictionary *rawArguments = [json[@"arguments"] isKindOfClass:NSDictionary.class] ? json[@"arguments"] : nil;
    NSArray *jvmArgs = [rawArguments[@"jvm"] isKindOfClass:NSArray.class] ? rawArguments[@"jvm"] : @[];
    BOOL hasLoaderJvmArgs = NO;
    for (id arg in jvmArgs) {
        // MC 26.x uses rule-based JVM args as NSDictionary entries
        // ({"rules": [...], "value": ...}) in addition to plain strings.
        if (![arg isKindOfClass:NSString.class]) {
            continue;
        }
        if ([arg containsString:@"bootstraplauncher"] ||
            [arg containsString:@"${library_directory}"] ||
            [arg containsString:@"${version_name}"]) {
            hasLoaderJvmArgs = YES;
            break;
        }
    }

    BOOL isLabyMod = [self isLabyModVersionJson:json];
    if (!hasLoaderJvmArgs && !isLabyMod) {
        return;
    }

    NSMutableDictionary *arguments;
    if ([rawArguments isKindOfClass:NSMutableDictionary.class]) {
        arguments = (NSMutableDictionary *)rawArguments;
    } else if (rawArguments != nil) {
        arguments = [rawArguments mutableCopy];
        json[@"arguments"] = arguments;
    } else {
        arguments = [NSMutableDictionary dictionary];
        json[@"arguments"] = arguments;
    }

    NSMutableArray *jvmProcessed = [NSMutableArray array];

    if (hasLoaderJvmArgs) {
        NSDictionary *varArgMap = @{
            @"${classpath_separator}": @":",
            @"${library_directory}": [NSString stringWithFormat:@"%s/libraries", getenv("POJAV_GAME_DIR")],
            @"${version_name}": json[@"id"]
        };
        int argsToSkip = 0;
        for (id arg in jvmArgs) {
            if (![arg isKindOfClass:NSString.class]) {
                continue;
            }
            if (argsToSkip == 0) {
                argsToSkip = [self numberOfArgsToSkipForArg:arg];
            }
            if (argsToSkip == 0) {
                NSString *argStr = arg;
                for (NSString *key in varArgMap.allKeys) {
                    argStr = [argStr stringByReplacingOccurrencesOfString:key withString:varArgMap[key]];
                }
                [jvmProcessed addObject:argStr];
            } else {
                argsToSkip--;
            }
        }
    }

    if (isLabyMod) {
        // LabyMod's own JVM args assume the official launcher's environment
        // (${natives_directory}, ${classpath}, ...). Only carry over flags that
        // are environment-independent and safe on iOS.
        for (id arg in jvmArgs) {
            if (![arg isKindOfClass:NSString.class]) continue;
            if ([arg containsString:@"${"]) continue;
            if ([arg hasPrefix:@"--add-opens="] ||
                [arg hasPrefix:@"--add-exports="] ||
                [arg hasPrefix:@"--enable-native-access="] ||
                [arg hasPrefix:@"-Dnet.labymod.running-version="] ||
                [arg isEqualToString:@"--sun-misc-unsafe-memory-access=allow"]) {
                if (![jvmProcessed containsObject:arg]) {
                    [jvmProcessed addObject:arg];
                }
            }
        }

        // LabyMod reads this system property from MinecraftVersions.<clinit>
        // and NPEs when it is absent, so it must reach the JVM before any
        // LabyMod class loads. 26.x manifests omit "inheritsFrom" entirely.
        NSString *mcVersion = [self labyModMinecraftVersionForJson:json];
        if (mcVersion.length > 0) {
            NSString *propertyPrefix = @"-Dnet.labymod.running-version=";
            for (NSInteger i = (NSInteger)jvmProcessed.count - 1; i >= 0; i--) {
                if ([jvmProcessed[i] hasPrefix:propertyPrefix]) {
                    [jvmProcessed removeObjectAtIndex:i];
                }
            }
            [jvmProcessed addObject:[propertyPrefix stringByAppendingString:mcVersion]];
            NSLog(@"[MCDL] LabyMod %@: injected -Dnet.labymod.running-version=%@", json[@"id"], mcVersion);
        }
    }

    arguments[@"jvm_processed"] = jvmProcessed;
}

+ (NSObject *)findVersion:(NSString *)version inList:(NSArray *)list {
    return [list filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(id == %@)", version]].firstObject;
}

+ (NSObject *)findNearestVersion:(NSObject *)version expectedType:(int)type {
    if (type != TYPE_RELEASE && type != TYPE_SNAPSHOT) {
        // Only support finding for releases and snapshot for now
        return nil;
    }

    if ([version isKindOfClass:NSString.class]){
        // Find in inheritsFrom
        NSDictionary *versionDict = parseJSONFromFile([NSString stringWithFormat:@"%1$s/versions/%2$@/%2$@.json", getenv("POJAV_GAME_DIR"), version]);
        NSAssert(versionDict != nil, @"version should not be null");
        if (versionDict[@"inheritsFrom"] == nil) {
            // How then?
            return nil; 
        }
        NSObject *inheritsFrom = [self findVersion:versionDict[@"inheritsFrom"] inList:remoteVersionList];
        if (type == TYPE_RELEASE) {
            return inheritsFrom;
        } else if (type == TYPE_SNAPSHOT) {
            return [self findNearestVersion:inheritsFrom expectedType:type];
        }
    }

    NSString *versionType = [version valueForKey:@"type"];
    int index = [remoteVersionList indexOfObject:(NSDictionary *)version];
    if ([versionType isEqualToString:@"release"] && type == TYPE_SNAPSHOT) {
        // Returns the (possible) latest snapshot for the version
        NSDictionary *result = remoteVersionList[index + 1];
        // Sometimes, a release is followed with another release (1.16->1.16.1), go lower in this case
        if ([result[@"type"] isEqualToString:@"release"]) {
            return [self findNearestVersion:result expectedType:type];
        }
        return result;
    } else if ([versionType isEqualToString:@"snapshot"] && type == TYPE_RELEASE) {
        while (remoteVersionList.count > abs(index)) {
            // In case the snapshot has yet attached to a release, perform a reverse find
            NSDictionary *result = remoteVersionList[abs(index)];
            // Returns the corresponding release for the snapshot, or latest release if none found
            if ([result[@"type"] isEqualToString:@"release"]) {
                return result;
            }
            // Continue to decrement, later abs() it
            index--;
        }
    }

    // No idea on handling everything else
    return nil;
}

+ (void)refreshLocalVersionList {
    if (!localVersionList) {
        localVersionList = [NSMutableArray new];
    }
    [localVersionList removeAllObjects];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *versionPath = [NSString stringWithFormat:@"%s/versions/", getenv("POJAV_GAME_DIR")];
    NSArray *list = [[fileManager contentsOfDirectoryAtPath:versionPath error:nil]
                     sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    for (NSString *versionId in list) {
        NSString *localPath = [versionPath stringByAppendingPathComponent:versionId];
        BOOL isDirectory;
        [fileManager fileExistsAtPath:localPath isDirectory:&isDirectory];
        if (!isDirectory) continue;
        if ([versionId hasPrefix:@"."]) continue;
        [localVersionList addObject:@{
            @"id": versionId,
            @"type": @"custom"
        }];
    }
}

+ (void)refreshRemoteVersionList {
    remoteVersionList = @[
        @{@"id": @"latest-release", @"type": @"release"},
        @{@"id": @"latest-snapshot", @"type": @"snapshot"}
    ].mutableCopy;

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager GET:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" parameters:nil headers:nil progress:nil success:^(NSURLSessionTask *task, NSDictionary *responseObject) {
        [remoteVersionList addObjectsFromArray:responseObject[@"versions"]];
        NSDebugLog(@"[VersionList] Got %d versions", remoteVersionList.count);
        setPrefObject(@"internal.latest_version", responseObject[@"latest"]);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSDebugLog(@"[VersionList] Warning: Unable to fetch version list: %@", error.localizedDescription);
    }];
}

@end
