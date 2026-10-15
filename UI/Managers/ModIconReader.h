#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Reads display metadata + logo straight from a local .jar/.zip without network.
// Mod jars: fabric.mod.json (id, name, version, authors, description, icon),
//           fabric.mod.json icon path, mods.toml / mcmod.info (best-effort title),
//           icon candidates: <icon field>, assets/<id>/icon.png, icon.png, logo.png.
// Shader / resource zips: pack.mcmeta (description, pack_format), pack.png.
// Results are cached in memory + Library/Caches/ModIcons so scrolling stays smooth.
@interface ModIconReader : NSObject

@property (class, readonly) ModIconReader *shared;

// metadata keys when found: title, version, authors (string), description, mod_id, icon_path
+ (NSDictionary *)metadataForFileAtPath:(NSString *)filePath category:(NSString *)category;

// Async: metadata + icon image (nil image = use placeholder). Completion on main queue.
- (void)iconForFileAtPath:(NSString *)filePath
                 category:(NSString *)category
               completion:(void(^)(UIImage * _Nullable image, NSDictionary *metadata))completion;

// Remote icon with disk cache (User-Agent Witch/1.0). Completion on main queue.
- (void)remoteIconForURLString:(NSString *)urlString
                   completion:(void(^)(UIImage * _Nullable image))completion;

+ (NSString *)placeholderSystemImageForCategory:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
