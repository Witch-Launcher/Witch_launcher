#import <UIKit/UIKit.h>

@interface MrpackInstaller : NSObject

/// Installs a modpack archive. Both Modrinth .mrpack (modrinth.index.json)
/// and CurseForge .zip (manifest.json) are supported: files are downloaded,
/// overrides extracted, the loader installed and a playable profile created.
+ (void)installModpackAtPath:(NSString *)dlPath title:(NSString *)title hostVC:(UIViewController *)hostVC removeOnCompletion:(BOOL)removeOnCompletion;

/// Backwards-compatible alias for installModpackAtPath:.
+ (void)installMrpackAtPath:(NSString *)dlPath title:(NSString *)title hostVC:(UIViewController *)hostVC removeOnCompletion:(BOOL)removeOnCompletion;

@end
