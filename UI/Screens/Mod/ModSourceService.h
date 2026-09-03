#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Single entry point for mod-source operations (Modrinth vs CurseForge).
/// The search lists tag every CurseForge hit with _source = @"curseforge";
/// Modrinth hits have no _source key. All version dicts handled here use the
/// unified shape: name, version_number, game_versions[], loaders[], url,
/// filename, size, dependencies[{project_id, dependency_type}].
@interface ModSourceService : NSObject

/// YES when the mod dict came from a CurseForge search.
+ (BOOL)isCurseForgeMod:(nullable NSDictionary *)mod;

/// Load unified versions for a mod dict (routes to the right backend).
+ (void)loadVersionsForMod:(NSDictionary *)mod
                completion:(void(^)(NSArray<NSDictionary *> * _Nullable versions,
                                    NSError * _Nullable error))completion;

/// Load unified project details: @{title, icon_url, project_id, _source}.
+ (void)loadDetailsForProjectId:(NSString *)projectId
                         source:(nullable NSString *)source
                     completion:(void(^)(NSDictionary * _Nullable project,
                                        NSError * _Nullable error))completion;

/// Download one unified version (resolves the CurseForge CDN URL first when
/// the version has no direct url). Completion runs on the main queue with a
/// temp file path, like ModrinthService. Returns the download task, or nil
/// while a CurseForge URL is being resolved (completion still fires); treat
/// a nil return as "not cancellable yet".
+ (nullable NSURLSessionDownloadTask *)downloadVersion:(NSDictionary *)version
                                                ofMod:(NSDictionary *)mod
                                             progress:(nullable void(^)(float progress))progress
                                           completion:(void(^)(NSString * _Nullable path,
                                                              NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
