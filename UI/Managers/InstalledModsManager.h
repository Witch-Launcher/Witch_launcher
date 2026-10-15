#import <Foundation/Foundation.h>

extern NSString * const InstalledModsDidChangeNotification;

// Category identifiers for profile content (mods / shader packs / resource packs).
// Plain NSString constants so they work across managers without extra imports.
typedef NSString * InstalledItemCategory;
extern NSString * const InstalledItemCategoryMod;
extern NSString * const InstalledItemCategoryShaderPack;
extern NSString * const InstalledItemCategoryResourcePack;

// Tracks which mods/shaders/resource packs were installed through the launcher, per profile.
// Manifest lives per content directory:
//   <modsDir>/installed_mods.json
//   <shaderpacksDir>/installed_shaderpacks.json
//   <resourcepacksDir>/installed_resourcepacks.json
// keyed by project_id:
//   { "<project_id>": { title, version_number, filename, icon_url, source, category,
//                        mc_version, loader, installed_at, last_check } }
@interface InstalledModsManager : NSObject

@property (class, readonly) InstalledModsManager *shared;

// --- Directories for the current profile ---
- (NSString *)modsDirForCurrentProfile;
- (NSString *)resourcePacksDirForCurrentProfile;
- (NSString *)shaderPacksDirForCurrentProfile;
- (NSString *)savesDirForCurrentProfile;
- (NSString *)dirForCategory:(NSString *)category;

// --- Directories for an explicit profile dict (uses lastVersionId) ---
- (NSString *)versionKeyForProfile:(NSDictionary *)profile;
- (NSString *)modsDirForProfile:(NSDictionary *)profile;
- (NSString *)resourcePacksDirForProfile:(NSDictionary *)profile;
- (NSString *)shaderPacksDirForProfile:(NSDictionary *)profile;
- (NSString *)savesDirForProfile:(NSDictionary *)profile;
- (NSString *)serversDirForProfile:(NSDictionary *)profile;
- (NSString *)dirForCategory:(NSString *)category profile:(NSDictionary *)profile;

// --- Project-type routing (mod / shader / resourcepack / modpack) ---
// Maps a Modrinth/CurseForge project_type to a content category + extension.
- (NSString *)categoryForProjectType:(NSString *)projectType;
- (NSString *)dirForProjectType:(NSString *)projectType version:(NSString *)version;
- (NSString *)extensionForProjectType:(NSString *)projectType; // @"jar" or @"zip"

// --- Reads ---
- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category;
- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category profile:(NSDictionary *)profile;
- (NSDictionary *)infoForProjectId:(NSString *)projectId; // legacy: mods only
- (NSDictionary *)infoForProjectId:(NSString *)projectId category:(NSString *)category;
- (NSDictionary *)infoForFilename:(NSString *)filename category:(NSString *)category;

// --- Writes (legacy 4-arg kept for old callers, defaults to Mod category) ---
- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename;

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category;

- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category
               mcVersion:(NSString *)mcVersion
                  loader:(NSString *)loader;

// Same but stores the manifest in the given profile's directory.
- (void)recordProjectId:(NSString *)projectId
                   title:(NSString *)title
           versionNumber:(NSString *)versionNumber
                filename:(NSString *)filename
                 iconURL:(NSString *)iconURL
                  source:(NSString *)source
                category:(NSString *)category
               mcVersion:(NSString *)mcVersion
                  loader:(NSString *)loader
             projectType:(NSString *)projectType
                 profile:(NSDictionary *)profile;

- (void)removeProjectId:(NSString *)projectId category:(NSString *)category;
- (void)removeProjectId:(NSString *)projectId category:(NSString *)category profile:(NSDictionary *)profile;
- (void)removeRecordForFilename:(NSString *)filename category:(NSString *)category;
- (void)updateFilename:(NSString *)newFilename forProjectId:(NSString *)projectId category:(NSString *)category;
- (void)updateFilename:(NSString *)newFilename forProjectId:(NSString *)projectId category:(NSString *)category profile:(NSDictionary *)profile;

// --- Enable / disable (.jar <-> .jar.off, .zip <-> .zip.off) ---
- (NSString *)baseNameForFilename:(NSString *)filename; // strips one trailing .off
- (BOOL)isEnabledForFilename:(NSString *)filename category:(NSString *)category;
- (BOOL)isEnabledForFilename:(NSString *)filename category:(NSString *)category profile:(NSDictionary *)profile;
- (BOOL)setEnabled:(BOOL)enabled forFilename:(NSString *)filename category:(NSString *)category;
- (BOOL)setEnabled:(BOOL)enabled forFilename:(NSString *)filename category:(NSString *)category profile:(NSDictionary *)profile;

@end
