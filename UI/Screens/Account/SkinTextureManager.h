#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves the real 64x64 Minecraft skin texture for any account type.
/// - Local (offline): bundled Steve / Alex defaults (user pick per account).
/// - Ely.by: https://skinsystem.ely.by/skins/<name>.png (raw texture).
/// - Microsoft: sessionserver profile lookup -> textures.SKIN.url.
/// Downloaded textures are cached on disk (<Caches>/SkinTextures/<id>.png).
@interface SkinTextureManager : NSObject

+ (instancetype)shared;

/// Whether a local (offline) account prefers the Alex (slim) default skin.
+ (BOOL)localPrefersSlimForUsername:(NSString *)username;

/// Bundled default skin (slim = Alex, otherwise Steve). Local accounts only.
+ (UIImage *)bundledDefaultSkinSlim:(BOOL)slim;

/// Head crop (face region) of a bundled default skin, scaled to `size` px.
+ (UIImage *)bundledDefaultHeadSlim:(BOOL)slim size:(CGFloat)size;

/// Bundled head for a local account honoring its per-account preference.
+ (UIImage *)localHeadForUsername:(NSString *)username size:(CGFloat)size;

/// Raw skin for any account. Always calls completion on the main queue.
/// Falls back to the cached file, then to the bundled Steve skin.
- (void)skinImageForAccount:(NSDictionary *)account completion:(void (^)(UIImage *))completion;

/// Face crop (base + hat layer) rendered from a raw 64x64 skin texture.
/// Returns a square image of `size` points, or nil when the texture is invalid.
+ (nullable UIImage *)headImageFromSkinImage:(UIImage *)skin size:(CGFloat)size;

/// Resolves the account's real skin head. Always calls completion on the main
/// queue. Uses the same disk cache as skinImageForAccount, so premium heads
/// survive offline launches and refresh after a skin change.
- (void)headImageForAccount:(NSDictionary *)account
                       size:(CGFloat)size
                 completion:(void (^)(UIImage * _Nullable head))completion;

/// Removes the cached skin for the account (e.g. after deletion).
- (void)evictCachedSkinForAccount:(NSDictionary *)account;

@end

NS_ASSUME_NONNULL_END
