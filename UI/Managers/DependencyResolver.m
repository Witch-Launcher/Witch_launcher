#import "DependencyResolver.h"
#import "ModrinthService.h"
#import "CurseForgeService.h"
#import "InstalledModsManager.h"
#import "VersionDirectoryManager.h"
#import "LauncherPreferences.h"

@interface DependencyResolver ()
@property (nonatomic) NSMutableDictionary<NSString *, NSArray<NSDictionary *> *> *resolutionCache;
@property (nonatomic) NSMutableSet<NSString *> *currentlyResolving;
@property (nonatomic) dispatch_queue_t resolutionQueue;
@end

@implementation DependencyResolver

+ (DependencyResolver *)shared {
    static DependencyResolver *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resolutionCache = [NSMutableDictionary dictionary];
        _currentlyResolving = [NSMutableSet set];
        _resolutionQueue = dispatch_queue_create("com.angelic.dependency.resolver", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)clearCache {
    [_resolutionCache removeAllObjects];
    [_currentlyResolving removeAllObjects];
}

- (NSString *)cacheKeyForProject:(NSString *)projectId source:(NSString *)source version:(NSString *)mcVersion loader:(NSString *)loader {
    return [NSString stringWithFormat:@"%@:%@:%@:%@", source, projectId, mcVersion ?: @"any", loader ?: @"any"];
}

- (BOOL)isProjectInstalled:(NSString *)projectId category:(NSString *)category {
    if (!projectId || projectId.length == 0) return NO;
    NSDictionary *info = [[InstalledModsManager shared] infoForProjectId:projectId category:category];
    return info != nil && info.count > 0;
}

- (void)resolveDependenciesForProjectId:(NSString *)projectId
                                 source:(NSString *)source
                          targetVersion:(NSString *)mcVersion
                           targetLoader:(NSString *)loader
                            completion:(DependencyResolutionCompletion)completion {
    
    if (!projectId || projectId.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSString *cacheKey = [self cacheKeyForProject:projectId source:source version:mcVersion loader:loader];
    
    // Check cache
    NSArray<NSDictionary *> *cached = _resolutionCache[cacheKey];
    if (cached) {
        if (completion) completion(cached, nil);
        return;
    }
    
    // Prevent circular resolution
    if ([_currentlyResolving containsObject:cacheKey]) {
        if (completion) completion(@[], nil);
        return;
    }
    
    [_currentlyResolving addObject:cacheKey];
    
    __weak typeof(self) weakSelf = self;
    
    if ([source isEqualToString:@"curseforge"]) {
        [self resolveCurseForgeDependencies:projectId targetVersion:mcVersion targetLoader:loader completion:^(NSArray<NSDictionary *> *deps, NSError *error) {
            [_currentlyResolving removeObject:cacheKey];
            if (!error) {
                weakSelf.resolutionCache[cacheKey] = deps;
            }
            if (completion) completion(deps, error);
        }];
    } else {
        [self resolveModrinthDependencies:projectId targetVersion:mcVersion targetLoader:loader completion:^(NSArray<NSDictionary *> *deps, NSError *error) {
            [_currentlyResolving removeObject:cacheKey];
            if (!error) {
                weakSelf.resolutionCache[cacheKey] = deps;
            }
            if (completion) completion(deps, error);
        }];
    }
}

- (void)resolveModrinthDependencies:(NSString *)projectId
                       targetVersion:(NSString *)mcVersion
                        targetLoader:(NSString *)loader
                         completion:(DependencyResolutionCompletion)completion {
    __weak typeof(self) weakSelf = self;
    
    [ModrinthService.shared loadProjectVersions:projectId completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
        if (error || versions.count == 0) {
            if (completion) completion(@[], error);
            return;
        }
        
        // Find best version matching target
        NSDictionary *bestVersion = nil;
        for (NSDictionary *ver in versions) {
            BOOL vm = mcVersion.length == 0 || [ver[@"game_versions"] containsObject:mcVersion];
            BOOL lm = loader.length == 0 || [ver[@"loaders"] containsObject:loader];
            if (vm && lm) {
                bestVersion = ver;
                break;
            }
        }
        if (!bestVersion) bestVersion = versions.firstObject;
        
        NSArray *deps = bestVersion[@"dependencies"] ?: @[];
        NSArray *requiredDeps = [deps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"dependency_type == %@", @"required"]];
        
        if (requiredDeps.count == 0) {
            if (completion) completion(@[], nil);
            return;
        }
        
        // Resolve each dependency recursively
        NSMutableArray *allResolved = [NSMutableArray array];
        __block NSInteger completed = 0;
        __block NSError *firstError = nil;
        
        for (NSDictionary *dep in requiredDeps) {
            NSString *depProjectId = dep[@"project_id"];
            if (!depProjectId) {
                completed++;
                if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                continue;
            }
            
            // Check if already installed
            if ([self isProjectInstalled:depProjectId category:InstalledItemCategoryMod]) {
                completed++;
                if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                continue;
            }
            
            // Fetch project details
            [ModrinthService.shared loadProjectDetails:depProjectId completion:^(NSDictionary *project, NSError *pError) {
                if (pError || !project) {
                    completed++;
                    if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                    return;
                }
                
                [ModrinthService.shared loadProjectVersions:depProjectId completion:^(NSArray<NSDictionary *> *depVersions, NSError *vError) {
                    if (vError || depVersions.count == 0) {
                        completed++;
                        if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                        return;
                    }
                    
                    NSDictionary *bestDepVer = nil;
                    for (NSDictionary *dv in depVersions) {
                        BOOL vm = mcVersion.length == 0 || [dv[@"game_versions"] containsObject:mcVersion];
                        BOOL lm = loader.length == 0 || [dv[@"loaders"] containsObject:loader];
                        if (vm && lm) {
                            bestDepVer = dv;
                            break;
                        }
                    }
                    if (!bestDepVer) bestDepVer = depVersions.firstObject;
                    
                    // Recursively resolve sub-dependencies
                    [weakSelf resolveDependenciesForProjectId:depProjectId source:@"modrinth" targetVersion:mcVersion targetLoader:loader completion:^(NSArray<NSDictionary *> *subDeps, NSError *subError) {
                        if (subError && !firstError) firstError = subError;
                        [allResolved addObjectsFromArray:subDeps];
                        
                        // Add this dependency
                        [allResolved addObject:@{
                            @"project_id": depProjectId,
                            @"title": project[@"title"] ?: @"Unknown",
                            @"icon_url": project[@"icon_url"] ?: @"",
                            @"version": bestDepVer[@"version_number"] ?: @"",
                            @"url": bestDepVer[@"url"] ?: @"",
                            @"filename": bestDepVer[@"filename"] ?: [NSString stringWithFormat:@"%@.jar", depProjectId],
                            @"game_versions": bestDepVer[@"game_versions"] ?: @[],
                            @"loaders": bestDepVer[@"loaders"] ?: @[],
                            @"source": @"modrinth",
                            @"category": InstalledItemCategoryMod,
                        }];
                        
                        completed++;
                        if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                    }];
                }];
            }];
        }
    }];
}

- (void)resolveCurseForgeDependencies:(NSString *)projectId
                       targetVersion:(NSString *)mcVersion
                        targetLoader:(NSString *)loader
                         completion:(DependencyResolutionCompletion)completion {
    __weak typeof(self) weakSelf = self;
    // CurseForge doesn't have standardized dependency format like Modrinth
    // We'll fetch the project files and look for dependencies in the description or relations
    [CurseForgeService.shared loadProjectFiles:projectId completion:^(NSArray<NSDictionary *> *files, NSError *error) {
        if (error || files.count == 0) {
            if (completion) completion(@[], error);
            return;
        }
        
        // Find best file matching target
        NSDictionary *bestFile = nil;
        for (NSDictionary *file in files) {
            NSArray *gv = file[@"gameVersions"] ?: @[];
            BOOL vm = mcVersion.length == 0 || [gv containsObject:mcVersion];
            if (vm) {
                bestFile = file;
                break;
            }
        }
        if (!bestFile) bestFile = files.firstObject;
        
        // CurseForge dependencies are in "dependencies" array in file object
        NSArray *deps = bestFile[@"dependencies"] ?: @[];
        NSMutableArray *requiredDeps = [NSMutableArray array];
        for (NSDictionary *dep in deps) {
            if ([dep[@"relationType"] isEqualToNumber:@3]) { // 3 = Required
                [requiredDeps addObject:dep];
            }
        }
        
        if (requiredDeps.count == 0) {
            if (completion) completion(@[], nil);
            return;
        }
        
        // Resolve each dependency
        NSMutableArray *allResolved = [NSMutableArray array];
        __block NSInteger completed = 0;
        __block NSError *firstError = nil;
        
        for (NSDictionary *dep in requiredDeps) {
            NSNumber *depProjectIdNum = dep[@"modId"];
            if (!depProjectIdNum) {
                completed++;
                if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                continue;
            }
            NSString *depProjectId = [depProjectIdNum stringValue];
            
            if ([self isProjectInstalled:depProjectId category:InstalledItemCategoryMod]) {
                completed++;
                if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                continue;
            }
            
            [CurseForgeService.shared loadProjectDetails:depProjectId completion:^(NSDictionary *project, NSError *pError) {
                if (pError || !project) {
                    completed++;
                    if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                    return;
                }
                
                [CurseForgeService.shared loadProjectFiles:depProjectId completion:^(NSArray<NSDictionary *> *depFiles, NSError *fError) {
                    if (fError || depFiles.count == 0) {
                        completed++;
                        if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                        return;
                    }
                    
                    NSDictionary *bestDepFile = nil;
                    for (NSDictionary *df in depFiles) {
                        NSArray *gv = df[@"gameVersions"] ?: @[];
                        BOOL vm = mcVersion.length == 0 || [gv containsObject:mcVersion];
                        if (vm) {
                            bestDepFile = df;
                            break;
                        }
                    }
                    if (!bestDepFile) bestDepFile = depFiles.firstObject;
                    
                    // Recursively resolve
                    [weakSelf resolveDependenciesForProjectId:depProjectId source:@"curseforge" targetVersion:mcVersion targetLoader:loader completion:^(NSArray<NSDictionary *> *subDeps, NSError *subError) {
                        if (subError && !firstError) firstError = subError;
                        [allResolved addObjectsFromArray:subDeps];
                        
                        [allResolved addObject:@{
                            @"project_id": depProjectId,
                            @"title": project[@"name"] ?: @"Unknown",
                            @"icon_url": project[@"logo"][@"url"] ?: @"",
                            @"version": bestDepFile[@"displayName"] ?: @"",
                            @"url": bestDepFile[@"downloadUrl"] ?: @"",
                            @"filename": bestDepFile[@"fileName"] ?: [NSString stringWithFormat:@"%@.jar", depProjectId],
                            @"game_versions": bestDepFile[@"gameVersions"] ?: @[],
                            @"loaders": @[], // CurseForge doesn't expose loaders easily
                            @"source": @"curseforge",
                            @"category": InstalledItemCategoryMod,
                        }];
                        
                        completed++;
                        if (completed == requiredDeps.count && completion) completion(allResolved, firstError);
                    }];
                }];
            }];
        }
    }];
}

@end