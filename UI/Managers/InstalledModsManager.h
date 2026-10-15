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
- (NSString *)dirForCategory:(NSString *)category;

// --- Reads ---
- (NSArray<NSDictionary *> *)allInstalledForCategory:(NSString *)category;
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

- (void)removeProjectId:(NSString *)projectId category:(NSString *)category;
- (void)removeRecordForFilename:(NSString *)filename category:(NSString *)category;
- (void)updateFilename:(NSString *)newFilename forProjectId:(NSString *)projectId category:(NSString *)category;

// --- Enable / disable (.jar <-> .jar.off, .zip <-> .zip.off) ---
- (BOOL)isEnabledForFilename:(NSString *)filename category:(NSString *)category;
- (BOOL)setEnabled:(BOOL)enabled forFilename:(NSString *)filename category:(NSString *)category;

@end
