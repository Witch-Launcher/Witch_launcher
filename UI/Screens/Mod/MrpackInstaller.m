#import "MrpackInstaller.h"
#import "DownloadProgressOverlay.h"
#import "DownloadManager.h"
#import "InstallerProgressViewController.h"
#import "VersionDirectoryManager.h"
#import "JavaGUIViewController.h"
#import "ModpackUtils.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "UnzipKit.h"
#import "CurseForgeService.h"

@interface MrpackInstaller ()
+ (void)installModrinthPackAtPath:(NSString *)dlPath
                            title:(NSString *)title
                           hostVC:(UIViewController *)hostVC
               removeOnCompletion:(BOOL)removeOnCompletion
                            index:(NSDictionary *)indexDict
                          archive:(UZKArchive *)archive
                          overlay:(DownloadProgressOverlay *)overlay;
+ (void)installCurseForgePackAtPath:(NSString *)dlPath
                              title:(NSString *)title
                             hostVC:(UIViewController *)hostVC
                 removeOnCompletion:(BOOL)removeOnCompletion
                           manifest:(NSDictionary *)manifest
                            archive:(UZKArchive *)archive
                            overlay:(DownloadProgressOverlay *)overlay;
+ (void)resolveCurseForgeFileWithProject:(NSNumber *)projectID
                                    file:(NSNumber *)fileID
                              completion:(void(^)(NSString *url, NSString *fileName, NSError *error))completion;
+ (void)curseForgeDirectoryForProject:(NSNumber *)projectID
                             fileName:(NSString *)fileName
                                cache:(NSMutableDictionary<NSNumber *, NSNumber *> *)cache
                           completion:(void(^)(NSString *directory))completion;
+ (void)finishInstallForVersion:(NSString *)versionName
                          title:(NSString *)displayTitle
                      mcVersion:(NSString *)packMcVersion
                     loaderType:(NSString *)loaderType
                      loaderVer:(NSString *)loaderVer
                        warning:(NSString *)warning
                        overlay:(DownloadProgressOverlay *)overlay
                         hostVC:(UIViewController *)hostVC;
+ (void)downloadClientJarForModpack:(NSString *)versionName;
@end

static NSString *readInstallerVersionId(NSString *jarPath) {
    NSError *uzError;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:jarPath error:&uzError];
    if (uzError) return nil;
    NSData *profileData = [archive extractDataFromFile:@"install_profile.json" error:&uzError];
    if (uzError || !profileData) return nil;
    NSDictionary *profileJson = [NSJSONSerialization JSONObjectWithData:profileData options:0 error:nil];
    if (![profileJson isKindOfClass:[NSDictionary class]]) return nil;

    NSData *verData = nil;
    NSDictionary *versionInfo = profileJson[@"versionInfo"];
    if ([versionInfo isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:versionInfo options:0 error:nil];
    } else if ([profileJson[@"json"] isKindOfClass:[NSString class]]) {
        NSString *jsonStr = profileJson[@"json"];
        if ([jsonStr hasPrefix:@"/"]) {
            verData = [archive extractDataFromFile:[jsonStr substringFromIndex:1] error:&uzError];
        } else {
            verData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
        }
    } else if ([profileJson[@"json"] isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:profileJson[@"json"] options:0 error:nil];
    } else if ([profileJson[@"install"] isKindOfClass:[NSDictionary class]] &&
               [profileJson[@"install"][@"versionInfo"] isKindOfClass:[NSDictionary class]]) {
        verData = [NSJSONSerialization dataWithJSONObject:profileJson[@"install"][@"versionInfo"] options:0 error:nil];
    }
    NSDictionary *parsed = verData ? [NSJSONSerialization JSONObjectWithData:verData options:0 error:nil] : nil;
    if ([parsed isKindOfClass:[NSDictionary class]]) {
        id vId = parsed[@"id"];
        if ([vId isKindOfClass:[NSString class]] && [vId length] > 0) return vId;
    }
    return nil;
}

// A version id becomes a folder name and a JSON filename, so strip path
// separators and other characters that break file paths. Keep Unicode so
// non-English pack names stay readable.
static NSString *ModpackVersionNameForTitle(NSString *title) {
    NSString *source = [title isKindOfClass:[NSString class]] ? title : @"modpack";
    source = [source stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableString *name = [NSMutableString stringWithCapacity:source.length];
    NSCharacterSet *forbidden = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSCharacterSet *control = NSCharacterSet.controlCharacterSet;
    for (NSUInteger i = 0; i < source.length; i++) {
        unichar c = [source characterAtIndex:i];
        if ([whitespace characterIsMember:c] || [control characterIsMember:c] || [forbidden characterIsMember:c]) {
            if (![name hasSuffix:@"_"]) [name appendString:@"_"];
        } else {
            [name appendFormat:@"%C", c];
        }
    }
    NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_. "]];
    if (trimmed.length == 0) return @"modpack";
    return [trimmed lowercaseString];
}

static BOOL ModpackRelativePathIsSafe(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
    if ([path hasPrefix:@"/"] || [path hasPrefix:@"~"]) return NO;
    for (NSString *component in [path componentsSeparatedByString:@"/"]) {
        if ([component isEqualToString:@".."]) return NO;
    }
    return YES;
}

static NSString *ModpackSafeFileName(NSString *name, NSString *fallback) {
    NSString *base = [name isKindOfClass:[NSString class]] ? name.lastPathComponent : nil;
    if (base.length == 0 || [base isEqualToString:@"."] || [base isEqualToString:@".."]) return fallback;
    return base;
}

// CurseForge project class ids: 6 mods, 12 resource packs, 6552 shaders.
// The pack manifest only stores project/file ids, so files have to be routed
// to the folder Minecraft expects instead of dumping every entry in mods/.
static NSString *ModpackDirectoryForCurseForgeClass(id classId) {
    NSInteger cid = [classId respondsToSelector:@selector(integerValue)] ? [classId integerValue] : 6;
    switch (cid) {
        case 12: return @"resourcepacks";
        case 6552: return @"shaderpacks";
        case 17: return @"saves";
        default: return @"mods";
    }
}

// The CurseForge spec stores numeric ids, but some third-party exporters write
// them as strings. Accept both instead of silently skipping the file.
static NSNumber *ModpackNumberValue(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:value];
        long long number = 0;
        if ([scanner scanLongLong:&number] && scanner.isAtEnd && number > 0) return @(number);
    }
    return nil;
}

static void ModpackParseLoaders(NSDictionary *minecraft, NSString *mcVersion,
                                NSString **loaderType, NSString **loaderVer) {
    *loaderType = nil;
    *loaderVer = nil;
    if (![minecraft isKindOfClass:[NSDictionary class]]) return;
    NSArray *modLoaders = minecraft[@"modLoaders"];
    if (![modLoaders isKindOfClass:[NSArray class]] || modLoaders.count == 0) return;

    NSDictionary *selected = nil;
    for (NSDictionary *entry in modLoaders) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        if ([entry[@"primary"] boolValue]) {
            selected = entry;
            break;
        }
        if (!selected) selected = entry;
    }
    NSString *identifier = selected[@"id"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) return;

    NSRange dash = [identifier rangeOfString:@"-"];
    if (dash.location == NSNotFound) return;
    NSString *type = [[identifier substringToIndex:dash.location] lowercaseString];
    NSString *ver = [identifier substringFromIndex:dash.location + 1];
    if ([ver hasPrefix:@"loader-"]) ver = [ver substringFromIndex:7];
    NSString *mcPrefix = [mcVersion stringByAppendingString:@"-"];
    if (mcVersion.length > 0 && [ver hasPrefix:mcPrefix]) {
        ver = [ver substringFromIndex:mcPrefix.length];
    }
    if (![type isEqualToString:@"forge"] &&
        ![type isEqualToString:@"neoforge"] &&
        ![type isEqualToString:@"fabric"] &&
        ![type isEqualToString:@"quilt"]) {
        return;
    }
    *loaderType = type;
    *loaderVer = ver;
}

static NSString *CurseForgeFileNameFromURL(NSString *urlString) {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    NSString *name = url.lastPathComponent;
    if (name.length == 0) return nil;
    return [name stringByRemovingPercentEncoding] ?: name;
}

// Downloaded mods are jars (zip containers). A CDN error page saved as .jar
// would otherwise be installed silently, so verify the zip signature.
static BOOL ModpackDataLooksLikeArchive(NSData *data) {
    if (data.length < 4) return NO;
    const uint8_t *bytes = data.bytes;
    if (bytes[0] != 'P' || bytes[1] != 'K') return NO;
    return (bytes[2] == 3 && bytes[3] == 4) ||
           (bytes[2] == 5 && bytes[3] == 6) ||
           (bytes[2] == 7 && bytes[3] == 8);
}

static BOOL ModpackFileLooksLikeArchive(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return NO;
    NSData *magic = nil;
    @try {
        magic = [handle readDataOfLength:4];
    } @catch (...) {
        magic = nil;
    }
    [handle closeFile];
    return ModpackDataLooksLikeArchive(magic);
}

static void ModpackFinishWithError(DownloadProgressOverlay *overlay, NSString *archivePath,
                                   BOOL removeArchive, NSString *message) {
    if (removeArchive && archivePath.length > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
    }
    [overlay finishWithMessage:message];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [overlay dismiss];
    });
}

@implementation MrpackInstaller

+ (void)installMrpackAtPath:(NSString *)dlPath title:(NSString *)title hostVC:(UIViewController *)hostVC removeOnCompletion:(BOOL)removeOnCompletion {
    [self installModpackAtPath:dlPath title:title hostVC:hostVC removeOnCompletion:removeOnCompletion];
}

+ (void)installModpackAtPath:(NSString *)dlPath title:(NSString *)title hostVC:(UIViewController *)hostVC removeOnCompletion:(BOOL)removeOnCompletion {
    DownloadProgressOverlay *overlay = [DownloadProgressOverlay showInView:hostVC.view title:localize(@"progress.installing_modpack", nil)];
    [overlay updateProgress:0.1 message:localize(@"progress.msg.parsing", nil)];

    NSError *uzError = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:dlPath error:&uzError];
    if (uzError || !archive) {
        ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.invalid", nil));
        return;
    }

    uzError = nil;
    NSData *indexData = [archive extractDataFromFile:@"modrinth.index.json" error:&uzError];
    if (indexData.length > 0) {
        NSDictionary *indexDict = [NSJSONSerialization JSONObjectWithData:indexData options:0 error:&uzError];
        if (uzError || ![indexDict isKindOfClass:[NSDictionary class]]) {
            ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.corrupt_index", nil));
            return;
        }
        [self installModrinthPackAtPath:dlPath title:title hostVC:hostVC removeOnCompletion:removeOnCompletion
                                  index:indexDict archive:archive overlay:overlay];
        return;
    }

    uzError = nil;
    NSData *manifestData = [archive extractDataFromFile:@"manifest.json" error:&uzError];
    if (manifestData.length == 0) {
        ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.missing_index", nil));
        return;
    }
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&uzError];
    if (uzError || ![manifest isKindOfClass:[NSDictionary class]]) {
        ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.corrupt_index", nil));
        return;
    }
    [self installCurseForgePackAtPath:dlPath title:title hostVC:hostVC removeOnCompletion:removeOnCompletion
                             manifest:manifest archive:archive overlay:overlay];
}

#pragma mark - Modrinth (.mrpack)

+ (void)installModrinthPackAtPath:(NSString *)dlPath
                            title:(NSString *)title
                           hostVC:(UIViewController *)hostVC
               removeOnCompletion:(BOOL)removeOnCompletion
                            index:(NSDictionary *)indexDict
                          archive:(UZKArchive *)archive
                          overlay:(DownloadProgressOverlay *)overlay {
    NSString *rawName = indexDict[@"name"] ?: [dlPath.lastPathComponent stringByDeletingPathExtension];
    NSString *displayTitle = title.length > 0 ? title : ([rawName isKindOfClass:[NSString class]] ? rawName : @"modpack");
    NSString *versionName = ModpackVersionNameForTitle(displayTitle);

    NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionName];
    [[NSFileManager defaultManager] createDirectoryAtPath:versionDir withIntermediateDirectories:YES attributes:nil error:nil];
    [VersionDirectoryManager.shared ensureVersionDirectoriesForVersion:versionName];

    NSArray *indexFiles = indexDict[@"files"];
    NSUInteger totalFiles = [indexFiles isKindOfClass:[NSArray class]] ? indexFiles.count : 0;
    [overlay updateProgress:0.4 message:[NSString stringWithFormat:localize(@"progress.msg.dl_nfiles", nil), (unsigned long)totalFiles]];
    __block NSUInteger completedFiles = 0;
    __block BOOL installFailed = NO;
    dispatch_group_t modGroup = dispatch_group_create();

    for (NSDictionary *indexFile in indexFiles) {
        if (![indexFile isKindOfClass:[NSDictionary class]]) continue;
        dispatch_group_enter(modGroup);
        NSString *modUrl = [indexFile[@"downloads"] firstObject];
        if (![modUrl isKindOfClass:[NSString class]]) modUrl = nil;
        NSString *modPath = indexFile[@"path"];
        if (!ModpackRelativePathIsSafe(modPath)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                installFailed = YES;
                completedFiles++;
                dispatch_group_leave(modGroup);
            });
            continue;
        }
        NSString *targetPath = [versionDir stringByAppendingPathComponent:modPath];
        if (modUrl.length > 0) {
            [DownloadManager.shared downloadToPath:modUrl targetPath:targetPath completion:^(BOOL success, NSError *e) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!success) installFailed = YES;
                    completedFiles++;
                    [overlay updateProgress:0.4 + (0.3 * completedFiles / MAX(totalFiles, 1))
                                    message:[NSString stringWithFormat:localize(@"progress.msg.dl_files", nil), (unsigned long)completedFiles, (unsigned long)totalFiles]];
                    dispatch_group_leave(modGroup);
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completedFiles++;
                dispatch_group_leave(modGroup);
            });
        }
    }

    dispatch_group_notify(modGroup, dispatch_get_main_queue(), ^{
        if (installFailed) {
            ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.files_failed", nil));
            return;
        }

        [overlay updateProgress:0.7 message:localize(@"progress.msg.extracting", nil)];
        NSError *overrideError = nil;
        [ModpackUtils archive:archive extractDirectory:@"overrides" toPath:versionDir error:&overrideError];
        if (overrideError) NSLog(@"[Mrpack] Overrides extraction failed: %@", overrideError);
        overrideError = nil;
        [ModpackUtils archive:archive extractDirectory:@"client-overrides" toPath:versionDir error:&overrideError];
        if (overrideError) NSLog(@"[Mrpack] Client overrides extraction failed: %@", overrideError);
        if (removeOnCompletion) [[NSFileManager defaultManager] removeItemAtPath:dlPath error:nil];

        [overlay updateProgress:0.8 message:localize(@"progress.msg.setup_version", nil)];
        NSDictionary *deps = [indexDict[@"dependencies"] isKindOfClass:[NSDictionary class]] ? indexDict[@"dependencies"] : @{};
        NSString *currentMC = VersionDirectoryManager.shared.currentVersion.length > 0
            ? VersionDirectoryManager.shared.currentVersion : @"1.21.4";
        NSString *packMcVersion = [deps[@"minecraft"] isKindOfClass:[NSString class]] && [deps[@"minecraft"] length] > 0
            ? deps[@"minecraft"] : currentMC;

        NSString *loaderType = nil, *loaderVer = nil;
        if ([deps[@"fabric-loader"] isKindOfClass:[NSString class]]) {
            loaderType = @"fabric"; loaderVer = deps[@"fabric-loader"];
        } else if ([deps[@"quilt-loader"] isKindOfClass:[NSString class]]) {
            loaderType = @"quilt"; loaderVer = deps[@"quilt-loader"];
        } else if ([deps[@"forge"] isKindOfClass:[NSString class]]) {
            loaderType = @"forge"; loaderVer = deps[@"forge"];
        } else if ([deps[@"neoforge"] isKindOfClass:[NSString class]]) {
            loaderType = @"neoforge"; loaderVer = deps[@"neoforge"];
        }

        [self finishInstallForVersion:versionName
                                title:displayTitle
                            mcVersion:packMcVersion
                           loaderType:loaderType
                            loaderVer:loaderVer
                              warning:nil
                              overlay:overlay
                               hostVC:hostVC];
    });
}

#pragma mark - CurseForge (manifest.json)

+ (void)installCurseForgePackAtPath:(NSString *)dlPath
                              title:(NSString *)title
                             hostVC:(UIViewController *)hostVC
                 removeOnCompletion:(BOOL)removeOnCompletion
                           manifest:(NSDictionary *)manifest
                            archive:(UZKArchive *)archive
                            overlay:(DownloadProgressOverlay *)overlay {
    NSDictionary *mcSection = [manifest[@"minecraft"] isKindOfClass:[NSDictionary class]] ? manifest[@"minecraft"] : nil;
    NSString *manifestMc = mcSection[@"version"];
    if (![manifestMc isKindOfClass:[NSString class]] || manifestMc.length == 0) {
        ModpackFinishWithError(overlay, dlPath, removeOnCompletion, localize(@"modpack.corrupt_index", nil));
        return;
    }

    NSString *rawName = [manifest[@"name"] isKindOfClass:[NSString class]] ? manifest[@"name"] : nil;
    if (rawName.length == 0) rawName = [dlPath.lastPathComponent stringByDeletingPathExtension];
    NSString *displayTitle = title.length > 0 ? title : rawName;
    NSString *versionName = ModpackVersionNameForTitle(displayTitle);

    NSString *loaderType = nil, *loaderVer = nil;
    ModpackParseLoaders(mcSection, manifestMc, &loaderType, &loaderVer);
    NSLog(@"[Mrpack] CurseForge pack \"%@\": MC %@, loader %@ %@, %lu files",
          displayTitle, manifestMc, loaderType ?: @"(none)", loaderVer ?: @"", (unsigned long)[manifest[@"files"] count]);

    NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionName];
    [[NSFileManager defaultManager] createDirectoryAtPath:versionDir withIntermediateDirectories:YES attributes:nil error:nil];
    [VersionDirectoryManager.shared ensureVersionDirectoriesForVersion:versionName];

    NSArray *rawFiles = [manifest[@"files"] isKindOfClass:[NSArray class]] ? manifest[@"files"] : @[];
    NSUInteger totalFiles = rawFiles.count;
    [overlay updateProgress:totalFiles > 0 ? 0.15 : 0.5
                    message:[NSString stringWithFormat:localize(@"progress.msg.dl_nfiles", nil), (unsigned long)totalFiles]];

    if (totalFiles > 0 && !CurseForgeService.shared.isConfigured) {
        ModpackFinishWithError(overlay, dlPath, removeOnCompletion,
                               @"CurseForge API key is not configured. Add a key in Settings to install CurseForge modpacks.");
        return;
    }

    __block NSUInteger completedFiles = 0;
    __block NSUInteger failedFiles = 0;
    NSMutableArray<NSString *> *failedNames = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *pending = [NSMutableArray array];
    for (id entry in rawFiles) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSNumber *projectID = ModpackNumberValue(entry[@"projectID"]);
        NSNumber *fileID = ModpackNumberValue(entry[@"fileID"]);
        if (!projectID || !fileID) {
            failedFiles++;
            completedFiles++;
            continue;
        }
        [pending addObject:@{@"project": projectID, @"file": fileID}];
    }

    NSMutableDictionary<NSNumber *, NSNumber *> *projectClasses = [NSMutableDictionary dictionary];
    NSString *modsDir = [VersionDirectoryManager.shared modsPathForVersion:versionName];
    dispatch_group_t fileGroup = dispatch_group_create();
    // A fixed set of worker chains pulls files from the queue, so a pack with
    // hundreds of mods never opens hundreds of connections or threads at once.
    const NSUInteger workerCount = 6;
    NSUInteger workers = MIN(workerCount, pending.count);
    if (workers == 0) workers = 1;
    for (NSUInteger i = 0; i < workers; i++) dispatch_group_enter(fileGroup);
    __block NSUInteger nextIndex = 0;
    __block void (^startNext)(void);

    startNext = ^{
        if (nextIndex >= pending.count) {
            dispatch_group_leave(fileGroup);
            return;
        }
        NSDictionary *item = pending[nextIndex++];
        NSNumber *projectID = item[@"project"];
        NSNumber *fileID = item[@"file"];
        [self resolveCurseForgeFileWithProject:projectID file:fileID completion:^(NSString *url, NSString *fileName, NSError *error) {
            if (url.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failedFiles++;
                    completedFiles++;
                    NSString *label = fileName.length > 0 ? fileName : [NSString stringWithFormat:@"%@/%@", projectID, fileID];
                    [failedNames addObject:label];
                    [overlay updateProgress:0.15f + (0.55f * completedFiles / MAX(totalFiles, 1))
                                    message:[NSString stringWithFormat:localize(@"progress.msg.dl_files", nil), (unsigned long)completedFiles, (unsigned long)totalFiles]];
                    startNext();
                });
                return;
            }

            [self curseForgeDirectoryForProject:projectID fileName:fileName cache:projectClasses completion:^(NSString *directory) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *targetDir = [directory isEqualToString:@"mods"]
                        ? modsDir : [versionDir stringByAppendingPathComponent:directory];
                    [[NSFileManager defaultManager] createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:nil error:nil];
                    NSString *fallback = [NSString stringWithFormat:@"%@-%@.jar", projectID, fileID];
                    NSString *safeName = ModpackSafeFileName(fileName, fallback);
                    NSString *targetPath = [targetDir stringByAppendingPathComponent:safeName];
                    [DownloadManager.shared downloadToPath:url targetPath:targetPath completion:^(BOOL success, NSError *downloadError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            BOOL valid = success && ModpackFileLooksLikeArchive(targetPath);
                            if (success && !valid) {
                                [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
                            }
                            if (!valid) {
                                failedFiles++;
                                [failedNames addObject:safeName];
                            }
                            completedFiles++;
                            [overlay updateProgress:0.15f + (0.55f * completedFiles / MAX(totalFiles, 1))
                                            message:[NSString stringWithFormat:localize(@"progress.msg.dl_files", nil), (unsigned long)completedFiles, (unsigned long)totalFiles]];
                            startNext();
                        });
                    }];
                });
            }];
        }];
    };
    for (NSUInteger i = 0; i < workers; i++) startNext();

    dispatch_group_notify(fileGroup, dispatch_get_main_queue(), ^{
        // Break the block's self-reference once every worker has drained.
        startNext = nil;
        [overlay updateProgress:0.72 message:localize(@"progress.msg.extracting", nil)];

        NSString *overridesDir = [manifest[@"overrides"] isKindOfClass:[NSString class]] ? manifest[@"overrides"] : @"overrides";
        overridesDir = [overridesDir stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        while ([overridesDir hasPrefix:@"./"]) overridesDir = [overridesDir substringFromIndex:2];
        while ([overridesDir hasSuffix:@"/"]) overridesDir = [overridesDir substringToIndex:overridesDir.length - 1];
        if (!ModpackRelativePathIsSafe(overridesDir)) overridesDir = @"overrides";
        NSError *overrideError = nil;
        [ModpackUtils archive:archive extractDirectory:overridesDir toPath:versionDir error:&overrideError];
        if (overrideError) NSLog(@"[Mrpack] Overrides extraction failed: %@", overrideError);
        if (removeOnCompletion) [[NSFileManager defaultManager] removeItemAtPath:dlPath error:nil];

        [overlay updateProgress:0.8 message:localize(@"progress.msg.setup_version", nil)];
        NSString *warning = nil;
        if (failedFiles > 0) {
            NSLog(@"[Mrpack] CurseForge pack %@: %lu file(s) could not be downloaded: %@",
                  displayTitle, (unsigned long)failedFiles, [failedNames componentsJoinedByString:@", "]);
            warning = [NSString stringWithFormat:localize(@"modpack.partial_failed", nil),
                       (unsigned long)failedFiles];
        }
        [self finishInstallForVersion:versionName
                                title:displayTitle
                            mcVersion:manifestMc
                           loaderType:loaderType
                            loaderVer:loaderVer
                              warning:warning
                              overlay:overlay
                               hostVC:hostVC];
    });
}

+ (void)resolveCurseForgeFileWithProject:(NSNumber *)projectID
                                    file:(NSNumber *)fileID
                              completion:(void(^)(NSString *url, NSString *fileName, NSError *error))completion {
    NSString *projectId = [projectID stringValue];
    [CurseForgeService.shared loadFileMetadataForProject:projectId fileId:fileID completion:^(NSDictionary *file, NSError *metadataError) {
        NSString *fileName = [file[@"fileName"] isKindOfClass:[NSString class]] ? file[@"fileName"] : nil;
        NSString *directURL = [file[@"downloadUrl"] isKindOfClass:[NSString class]] ? file[@"downloadUrl"] : nil;
        if (directURL.length > 0) {
            completion(directURL, fileName, nil);
            return;
        }

        [CurseForgeService.shared resolveDownloadURLForProject:projectId fileId:fileID completion:^(NSString *resolved, NSError *resolveError) {
            if (resolved.length > 0) {
                NSString *name = fileName.length > 0 ? fileName : CurseForgeFileNameFromURL(resolved);
                if (name.length == 0) name = [NSString stringWithFormat:@"%@-%@.jar", projectID, fileID];
                completion(resolved, name, nil);
                return;
            }

            // Last resort: CurseForge's public CDN layout. It still works for
            // a few files whose API downloadUrl is intentionally hidden.
            NSString *edgeURL = [CurseForgeService cdnURLForFileId:fileID fileName:fileName];
            if (edgeURL.length > 0) {
                completion(edgeURL, fileName, nil);
                return;
            }
            completion(nil, fileName, resolveError ?: metadataError);
        }];
    }];
}

#pragma mark - Loader + profile setup

+ (void)curseForgeDirectoryForProject:(NSNumber *)projectID
                             fileName:(NSString *)fileName
                                cache:(NSMutableDictionary<NSNumber *, NSNumber *> *)cache
                           completion:(void(^)(NSString *directory))completion {
    // Jars are mods; only zip entries need the project class lookup.
    NSString *extension = [fileName isKindOfClass:[NSString class]] ? fileName.pathExtension.lowercaseString : nil;
    if (![extension isEqualToString:@"zip"]) {
        completion(@"mods");
        return;
    }
    NSNumber *cached = cache[projectID];
    if (cached) {
        completion(ModpackDirectoryForCurseForgeClass(cached));
        return;
    }
    [CurseForgeService.shared loadProjectDetails:projectID.stringValue completion:^(NSDictionary *project, NSError *error) {
        id rawClassId = [project isKindOfClass:[NSDictionary class]] ? project[@"classId"] : nil;
        NSNumber *classId = nil;
        if ([rawClassId isKindOfClass:[NSNumber class]]) classId = rawClassId;
        else if ([rawClassId isKindOfClass:[NSString class]]) classId = @([rawClassId integerValue]);
        if (classId) {
            cache[projectID] = classId;
        } else {
            NSLog(@"[Mrpack] Could not determine CurseForge project class for %@ (%@); using mods", projectID, fileName);
        }
        completion(ModpackDirectoryForCurseForgeClass(classId));
    }];
}

+ (void)finishInstallForVersion:(NSString *)versionName
                          title:(NSString *)displayTitle
                      mcVersion:(NSString *)packMcVersion
                     loaderType:(NSString *)loaderType
                      loaderVer:(NSString *)loaderVer
                        warning:(NSString *)warning
                        overlay:(DownloadProgressOverlay *)overlay
                         hostVC:(UIViewController *)hostVC {
    NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionName];
    if (packMcVersion.length == 0) packMcVersion = @"1.21.4";
    BOOL hasLoader = loaderType.length > 0 && loaderVer.length > 0;
    NSString *loaderLabel = @"Vanilla";
    if ([loaderType isEqualToString:@"fabric"]) loaderLabel = @"Fabric";
    else if ([loaderType isEqualToString:@"quilt"]) loaderLabel = @"Quilt";
    else if ([loaderType isEqualToString:@"forge"]) loaderLabel = @"Forge";
    else if ([loaderType isEqualToString:@"neoforge"]) loaderLabel = @"NeoForge";
    __block NSString *loaderInheritsFrom = nil;

    void (^finalizeInstall)(BOOL) = ^(BOOL showAlert) {
        NSString *versionJsonPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", versionName]];
        NSMutableDictionary *modpackJson = [NSMutableDictionary dictionary];
        modpackJson[@"id"] = versionName;
        modpackJson[@"type"] = @"release";
        modpackJson[@"modLoader"] = loaderLabel;
        modpackJson[@"libraries"] = @[];
        modpackJson[@"minecraftVersion"] = packMcVersion;
        if (hasLoader) {
            if ([loaderType isEqualToString:@"fabric"] || [loaderType isEqualToString:@"quilt"]) {
                modpackJson[@"inheritsFrom"] = [NSString stringWithFormat:@"%@-loader-%@-%@", loaderType, loaderVer, packMcVersion];
            } else {
                modpackJson[@"inheritsFrom"] = loaderInheritsFrom ?: packMcVersion;
            }
        } else {
            modpackJson[@"inheritsFrom"] = packMcVersion;
        }
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:modpackJson options:NSJSONWritingPrettyPrinted error:nil];
        if (jsonData) [jsonData writeToFile:versionJsonPath atomically:YES];

        [MrpackInstaller downloadClientJarForModpack:versionName];

        NSString *profileName = displayTitle;
        NSMutableDictionary *existing = PLProfiles.current.profiles[profileName];
        if (existing) {
            existing = [existing mutableCopy];
            existing[@"lastVersionId"] = versionName;
            existing[@"gameDir"] = [NSString stringWithFormat:@"./versions/%@", versionName];
            PLProfiles.current.profiles[profileName] = existing;
        } else {
            PLProfiles.current.profiles[profileName] = @{
                @"name": profileName,
                @"lastVersionId": versionName,
                @"gameDir": [NSString stringWithFormat:@"./versions/%@", versionName]
            }.mutableCopy;
        }
        PLProfiles.current.selectedProfileName = profileName;
        [PLProfiles.current save];
        VersionDirectoryManager.shared.currentVersion = versionName;

        if (showAlert) {
            [overlay finishWithMessage:localize(@"common.installed_done", nil)];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [overlay dismiss];
                NSString *message = [NSString stringWithFormat:@"%@ installed as profile.", profileName];
                if (warning.length > 0) message = [message stringByAppendingFormat:@"\n\n%@", warning];
                showDialog(@"Modpack Installed", message);
            });
        }
    };

    if ([loaderType isEqualToString:@"fabric"] || [loaderType isEqualToString:@"quilt"]) {
        NSString *profileId = [NSString stringWithFormat:@"%@-loader-%@-%@", loaderType, loaderVer, packMcVersion];
        NSString *loaderDir = [VersionDirectoryManager.shared versionPathForVersion:profileId];
        NSString *loaderJsonPath = [loaderDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", profileId]];

        if (![[NSFileManager defaultManager] fileExistsAtPath:loaderJsonPath]) {
            NSString *profileUrl;
            if ([loaderType isEqualToString:@"fabric"]) {
                profileUrl = [NSString stringWithFormat:@"https://meta.fabricmc.net/v2/versions/loader/%@/%@/profile/json", packMcVersion, loaderVer];
            } else {
                profileUrl = [NSString stringWithFormat:@"https://meta.quiltmc.org/v3/versions/loader/%@/%@/profile/json", packMcVersion, loaderVer];
            }
            [overlay updateProgress:0.82 message:localize(@"progress.msg.dl_loader", nil)];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *profileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:profileUrl]];
                if (profileData && [loaderType isEqualToString:@"quilt"]) {
                    // Quilt meta pins an old org.ow2.asm (9.5/9.7.1) that can't
                    // read Java 25 (class major 69) class files, crashing the
                    // loader with "Unsupported class file major version 69" while
                    // discovering entrypoints. Bump all ASM artifacts to 9.9.1
                    // (the version Forge/NeoForge 26.2 already use successfully).
                    NSMutableDictionary *profileJson = [NSJSONSerialization JSONObjectWithData:profileData options:NSJSONReadingMutableContainers error:nil];
                    if ([profileJson isKindOfClass:[NSDictionary class]]) {
                        for (NSMutableDictionary *lib in profileJson[@"libraries"]) {
                            NSString *name = lib[@"name"];
                            if ([name hasPrefix:@"org.ow2.asm:"]) {
                                NSArray *parts = [name componentsSeparatedByString:@":"];
                                if (parts.count == 3) {
                                    lib[@"name"] = [NSString stringWithFormat:@"%@:%@:9.9.1", parts[0], parts[1]];
                                }
                            }
                        }
                        profileData = [NSJSONSerialization dataWithJSONObject:profileJson options:0 error:nil];
                    }
                }
                if (profileData.length > 0) {
                    id parsedProfile = [NSJSONSerialization JSONObjectWithData:profileData options:0 error:nil];
                    NSString *profileId = [parsedProfile isKindOfClass:[NSDictionary class]] ? parsedProfile[@"id"] : nil;
                    if (![profileId isKindOfClass:[NSString class]] || profileId.length == 0) {
                        profileData = nil;
                    }
                }
                if (profileData.length == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [overlay finishWithMessage:localize(@"common.failed", nil)];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            [overlay dismiss];
                            showDialog(@"Loader Install Failed",
                                       [NSString stringWithFormat:@"Could not download the %@ %@ profile. The modpack files are installed, so retry after checking your connection.",
                                        loaderType, loaderVer]);
                        });
                    });
                    return;
                }
                [[NSFileManager defaultManager] createDirectoryAtPath:loaderDir withIntermediateDirectories:YES attributes:nil error:nil];
                [profileData writeToFile:loaderJsonPath atomically:YES];
                dispatch_async(dispatch_get_main_queue(), ^{ finalizeInstall(YES); });
            });
            return;
        }
    } else if ([loaderType isEqualToString:@"forge"] || [loaderType isEqualToString:@"neoforge"]) {
        BOOL isNeo = [loaderType isEqualToString:@"neoforge"];
        BOOL isLegacyNeo = isNeo && [packMcVersion hasPrefix:@"1.20.1"];
        NSString *profileId;
        if (isNeo) {
            profileId = isLegacyNeo
                ? [NSString stringWithFormat:@"%@-forge-%@", packMcVersion, loaderVer]
                : [NSString stringWithFormat:@"neoforge-%@", loaderVer];
        } else {
            profileId = [NSString stringWithFormat:@"%@-forge-%@", packMcVersion, loaderVer];
        }
        NSString *loaderJsonPath = [[VersionDirectoryManager.shared versionPathForVersion:profileId]
            stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", profileId]];

        if ([[NSFileManager defaultManager] fileExistsAtPath:loaderJsonPath]) {
            loaderInheritsFrom = profileId;
            finalizeInstall(YES);
            return;
        }

        NSString *installerUrl;
        if (isNeo) {
            installerUrl = isLegacyNeo
                ? [NSString stringWithFormat:@"https://maven.neoforged.net/releases/net/neoforged/forge/%@-%@/forge-%@-%@-installer.jar", packMcVersion, loaderVer, packMcVersion, loaderVer]
                : [NSString stringWithFormat:@"https://maven.neoforged.net/releases/net/neoforged/neoforge/%@/neoforge-%@-installer.jar", loaderVer, loaderVer];
        } else {
            installerUrl = [NSString stringWithFormat:@"https://maven.minecraftforge.net/net/minecraftforge/forge/%@-%@/forge-%@-%@-installer.jar", packMcVersion, loaderVer, packMcVersion, loaderVer];
        }
        [overlay updateProgress:0.82 message:[NSString stringWithFormat:localize(@"progress.msg.dl_installer", nil), isNeo ? @"NeoForge" : @"Forge"]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *jarData = [NSData dataWithContentsOfURL:[NSURL URLWithString:installerUrl]];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *installerPath = nil;
                if (jarData && jarData.length > 4 && ModpackDataLooksLikeArchive(jarData)) {
                    NSString *installersDir = [NSString stringWithFormat:@"%s/installers", getenv("POJAV_HOME") ?: ""];
                    if ([installersDir length] > [@"/installers" length]) {
                        [[NSFileManager defaultManager] createDirectoryAtPath:installersDir withIntermediateDirectories:YES attributes:nil error:nil];
                        installerPath = [installersDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-installer.jar", isNeo ? @"neoforge" : @"forge", loaderVer]];
                        [[NSFileManager defaultManager] removeItemAtPath:installerPath error:nil];
                        [jarData writeToFile:installerPath atomically:YES];
                    }
                }
                if (!installerPath) {
                    [overlay updateProgress:0.9 message:localize(@"progress.msg.installer_fail", nil)];
                    [overlay finishWithMessage:localize(@"common.failed", nil)];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [overlay dismiss];
                        showDialog(@"Loader Install Failed",
                                   [NSString stringWithFormat:@"Could not download the %@ %@ installer. The modpack files are installed, but the profile is not playable until the loader is installed.",
                                    isNeo ? @"NeoForge" : @"Forge", loaderVer]);
                    });
                    return;
                }

                NSString *realId = readInstallerVersionId(installerPath);
                if (realId.length > 0) {
                    loaderInheritsFrom = realId;
                    NSString *realJsonPath = [[VersionDirectoryManager.shared versionPathForVersion:realId]
                        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", realId]];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:realJsonPath]) {
                        finalizeInstall(YES);
                        return;
                    }
                } else {
                    loaderInheritsFrom = profileId;
                }

                finalizeInstall(NO);
                [overlay updateProgress:0.9 message:[NSString stringWithFormat:localize(@"progress.msg.run_installer", nil), isNeo ? @"NeoForge" : @"Forge"]];
                NSString *installDir = [NSString stringWithFormat:@"%s/instances/%@",
                    getenv("POJAV_HOME") ?: "", VersionDirectoryManager.shared.currentInstance ?: @"default"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [overlay dismiss];
                    [InstallerProgressViewController presentInstallerFrom:hostVC
                        jarPath:installerPath
                        title:[NSString stringWithFormat:@"Installing %@ %@", isNeo ? @"NeoForge" : @"Forge", loaderVer]
                        jvmArgs:@[@"--installClient", installDir]
                        completion:^(BOOL success, BOOL cancelled, int exitCode) {
                            if (!success && !cancelled) {
                                showDialog(@"Installer Failed", [NSString stringWithFormat:@"The %@ installer exited with code %d. Check the log for details.", isNeo ? @"NeoForge" : @"Forge", exitCode]);
                            }
                            UIKit_returnToSplitView();
                        }];
                });
            });
        });
        return;
    }

    finalizeInstall(YES);
}

+ (void)downloadClientJarForModpack:(NSString *)versionName {
    NSString *versionDir = [VersionDirectoryManager.shared versionPathForVersion:versionName];
    NSString *jarPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jar", versionName]];
    if ([NSFileManager.defaultManager fileExistsAtPath:jarPath]) return;

    NSString *jsonPath = [versionDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", versionName]];
    NSMutableDictionary *json = parseJSONFromFile(jsonPath);
    if (json[@"NSErrorObject"]) return;

    NSString *mcVersion = json[@"minecraftVersion"];
    if (!mcVersion) return;

    NSURL *manifestURL = [NSURL URLWithString:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"];
    NSData *manifestData = [NSData dataWithContentsOfURL:manifestURL];
    if (!manifestData) return;

    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
    if (![manifest[@"versions"] isKindOfClass:[NSArray class]]) return;

    NSString *versionJsonUrl = nil;
    for (NSDictionary *v in manifest[@"versions"]) {
        if ([v[@"id"] isEqualToString:mcVersion]) {
            versionJsonUrl = v[@"url"];
            break;
        }
    }
    if (!versionJsonUrl) return;

    NSData *versionData = [NSData dataWithContentsOfURL:[NSURL URLWithString:versionJsonUrl]];
    if (!versionData) return;

    NSDictionary *versionJson = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
    NSString *jarUrl = versionJson[@"downloads"][@"client"][@"url"];
    if (!jarUrl) return;

    NSLog(@"[Mrpack] Downloading client jar for %@ from %@", versionName, jarUrl);
    NSData *jarData = [NSData dataWithContentsOfURL:[NSURL URLWithString:jarUrl]];
    if (jarData) {
        [jarData writeToFile:jarPath atomically:YES];
        NSLog(@"[Mrpack] Saved client jar to %@", jarPath);
    }
}

@end
