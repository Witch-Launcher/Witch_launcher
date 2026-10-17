#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString * const kCurseForgeAPIKeyPrefKey;

@interface CurseForgeService : NSObject

+ (instancetype)shared;

/// Set the CurseForge API key. Must be called before any API requests.
- (void)setAPIKey:(NSString *)apiKey;

/// Check if API key is configured
- (BOOL)isConfigured;

/// Search mods/modpacks/shaders on CurseForge
/// @param classId: 6 = Mods, 4471 = Modpacks, 6552 = Shaders, 12 = Resource Packs
- (void)searchProjectsWithClassId:(NSInteger)classId
                            query:(NSString *)query
                           offset:(NSInteger)offset
                            limit:(NSInteger)limit
                     loaderFilter:(NSString *)loaderFilter
                gameVersionFilter:(NSString *)gameVersionFilter
                       completion:(void(^)(NSArray<NSDictionary *> *results, NSError *error))completion;

/// Load project versions/files
- (void)loadProjectFiles:(NSString *)projectId
              completion:(void(^)(NSArray<NSDictionary *> *files, NSError *error))completion;

/// Load project versions mapped to the same unified shape ModrinthService uses:
/// name, version_number, game_versions[], loaders[], url, filename, size,
/// dependencies[{project_id, dependency_type}], plus _cfFileId (NSNumber) for
/// lazy download-URL resolution and _source = @"curseforge".
- (void)loadProjectVersions:(NSString *)projectId
                 completion:(void(^)(NSArray<NSDictionary *> *versions, NSError *error))completion;

/// Load project details mapped to @{title, icon_url, project_id, _source}.
- (void)loadUnifiedProjectDetails:(NSString *)projectId
                       completion:(void(^)(NSDictionary *project, NSError *error))completion;

/// Resolve the direct CDN download URL for a file (needed when the file list
/// has no downloadUrl). Completion returns the URL string or an error.
- (void)resolveDownloadURLForProject:(NSString *)projectId
                              fileId:(NSNumber *)fileId
                          completion:(void(^)(NSString * _Nullable url, NSError * _Nullable error))completion;

/// Plain file downloader (same contract as ModrinthService).
- (NSURLSessionDownloadTask *)downloadFile:(NSString *)urlString
                                      name:(NSString *)name
                             progressBlock:(void(^)(float progress))progress
                                completion:(void(^)(NSString *path, NSError *error))completion;

/// Load project details
- (void)loadProjectDetails:(NSString *)projectId
                completion:(void(^)(NSDictionary *project, NSError *error))completion;

@end
