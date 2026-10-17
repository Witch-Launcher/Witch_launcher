#import <Foundation/Foundation.h>

@class DependencyResolver;

typedef void(^DependencyResolutionCompletion)(NSArray<NSDictionary *> *resolvedDependencies, NSError *error);

@interface DependencyResolver : NSObject

@property (class, readonly) DependencyResolver *shared;

// Resolve all required dependencies for a project (Modrinth or CurseForge)
// Returns flat array of dependency dicts with: project_id, title, version, url, filename, icon_url, source, game_versions, loaders
- (void)resolveDependenciesForProjectId:(NSString *)projectId
                                 source:(NSString *)source // "modrinth" or "curseforge"
                          targetVersion:(NSString *)mcVersion
                           targetLoader:(NSString *)loader
                            completion:(DependencyResolutionCompletion)completion;

// Check if a project is already installed in current profile
- (BOOL)isProjectInstalled:(NSString *)projectId category:(NSString *)category;

// Clear cache
- (void)clearCache;

@end