#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Extra content kinds beyond InstalledModsManager categories.
extern NSString * const ModContentKindWorld;
extern NSString * const ModContentKindDatapack;
extern NSString * const ModContentKindPlugin;

// Unified metadata reader for everything a profile holds.
// Merge strategy: try sources from highest to lowest priority, each step only
// fills fields that are still empty (never an early return).
//
// .jar mods: fabric.mod.json -> quilt.mod.json -> META-INF/neoforge.mods.toml
//   -> META-INF/mods.toml -> mods.toml -> mcmod.info (+META-INF/mcmod.info)
//   -> META-INF/MANIFEST.MF -> filename fallback.
// .zip packs: pack.mcmeta (recursive text-component) + shaders/ detection.
// world dir/zip: level.dat (gzip NBT, minimal reader) + icon.png.
// server plugin jars: plugin.yml / paper-plugin.yml.
//
// Metadata keys (when found): title, version, authors, description, mod_id,
// icon_path, pack_format, kind, mc_hint, loader_hint, level_last_played,
// level_version_name, plugin_main.
@interface ModMetadataReader : NSObject

@property (class, readonly) ModMetadataReader *shared;

// kind is one of: fabric, quilt, forge, neoforge, legacy, resource, shader,
// datapack, world, plugin, unknown.
+ (NSDictionary *)metadataForFileAtPath:(NSString *)filePath category:(NSString *)category;
+ (NSArray<NSString *> *)filenamesInArchiveAtPath:(NSString *)filePath;

// World (directory on disk): reads level.dat + icon.png next to it.
+ (NSDictionary *)worldInfoForWorldDir:(NSString *)worldDir;
// World packed as .zip: finds level.dat at depth 0..1, sibling icon.png.
+ (NSDictionary *)worldInfoForWorldZip:(NSString *)zipPath;

// Async icon: local scan first (UnzipKit listFilenames), then nothing else.
// Completion on main queue. meta is the merged metadata dict.
- (void)iconForFileAtPath:(NSString *)filePath
                 category:(NSString *)category
               completion:(void(^)(UIImage * _Nullable image, NSDictionary *meta))completion;

// Remote icon with disk cache (User-Agent Witch/1.0). Completion on main queue.
- (void)remoteIconForURLString:(NSString *)urlString
                    completion:(void(^)(UIImage * _Nullable image))completion;

+ (NSString *)placeholderSystemImageForCategory:(NSString *)category;
// pack_format (resource/datapack) -> human MC version range for display.
+ (NSString *)displayVersionForPackFormat:(NSString *)packFormat;

@end

NS_ASSUME_NONNULL_END
