#import "ProfileAvatarManager.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"

@interface ProfileAvatarManager ()
@property (nonatomic) NSCache<NSString *, UIImage *> *avatarCache;
@end

@implementation ProfileAvatarManager

+ (ProfileAvatarManager *)shared {
    static ProfileAvatarManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _avatarCache = [[NSCache alloc] init];
        _avatarCache.countLimit = 50;
    }
    return self;
}

- (UIImage *)avatarImageForKey:(NSString *)key {
    if (!key || key.length == 0) key = @"fabric";
    
    // Check cache first
    UIImage *cached = [_avatarCache objectForKey:key];
    if (cached) return cached;
    
    UIImage *image = nil;
    
    // Check if it's a local file path
    if ([key hasPrefix:@"/"] || [key hasPrefix:@"file://"]) {
        image = [UIImage imageWithContentsOfFile:key];
        if (image) {
            [_avatarCache setObject:image forKey:key];
            return image;
        }
    }
    
    // Built-in avatars using SF Symbols
    if ([key isEqualToString:@"fabric"]) {
        image = [UIImage systemImageNamed:@"cube.transparent"];
    } else if ([key isEqualToString:@"forge"]) {
        image = [UIImage systemImageNamed:@"hammer.fill"];
    } else if ([key isEqualToString:@"neoforge"]) {
        image = [UIImage systemImageNamed:@"hammer.circle.fill"];
    } else if ([key isEqualToString:@"quilt"]) {
        image = [UIImage systemImageNamed:@"patchwork"];
    } else if ([key isEqualToString:@"modpack"]) {
        image = [UIImage systemImageNamed:@"square.stack.3d.up"];
    } else if ([key isEqualToString:@"vanilla"]) {
        image = [UIImage systemImageNamed:@"cube.fill"];
    } else if ([key isEqualToString:@"optifine"]) {
        image = [UIImage systemImageNamed:@"eye.fill"];
    } else if ([key isEqualToString:@"iris"]) {
        image = [UIImage systemImageNamed:@"sparkles"];
    } else {
        image = [UIImage systemImageNamed:@"person.crop.circle"];
    }
    
    // Render with template mode for tint color support
    if (image) {
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_avatarCache setObject:image forKey:key];
    }
    
    return image ?: [UIImage systemImageNamed:@"person.crop.circle"];
}

- (UIImage *)avatarImageForProfile:(NSDictionary *)profile {
    NSString *avatarKey = profile[@"avatar"] ?: @"fabric";
    return [self avatarImageForKey:avatarKey];
}

- (NSString *)alternateIconNameForKey:(NSString *)key {
    if ([key isEqualToString:@"fabric"]) return @"AppIcon-Fabric";
    if ([key isEqualToString:@"forge"]) return @"AppIcon-Forge";
    if ([key isEqualToString:@"neoforge"]) return @"AppIcon-NeoForge";
    if ([key isEqualToString:@"quilt"]) return @"AppIcon-Quilt";
    if ([key isEqualToString:@"modpack"]) return @"AppIcon-Modpack";
    if ([key isEqualToString:@"vanilla"]) return @"AppIcon-Vanilla";
    if ([key isEqualToString:@"optifine"]) return @"AppIcon-Dark";
    if ([key isEqualToString:@"iris"]) return @"AppIcon-Iris";
    return nil; // Use primary icon
}

- (void)updateAppIconForCurrentProfile {
    NSDictionary *currentProfile = PLProfiles.current.selectedProfile;
    if (!currentProfile) return;
    
    NSString *avatarKey = currentProfile[@"avatar"] ?: @"fabric";
    NSString *alternateIconName = [self alternateIconNameForKey:avatarKey];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.3, *)) {
            if ([UIApplication sharedApplication].supportsAlternateIcons) {
                NSError *error = nil;
                [[UIApplication sharedApplication] setAlternateIconName:alternateIconName completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"[ProfileAvatarManager] Failed to change app icon: %@", error);
                    } else {
                        NSLog(@"[ProfileAvatarManager] App icon changed to: %@", alternateIconName ?: @"Primary");
                    }
                }];
            }
        }
    });
    
    // Post notification for UI to refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProfileAvatarDidChange" object:nil userInfo:@{@"avatarKey": avatarKey}];
}

@end