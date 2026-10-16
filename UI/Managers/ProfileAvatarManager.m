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

@end