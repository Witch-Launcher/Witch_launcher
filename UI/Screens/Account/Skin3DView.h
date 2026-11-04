#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, Skin3DModel) {
    // Steve: 4 px arms
    Skin3DModelClassic = 0,
    // Alex: 3 px arms
    Skin3DModelSlim = 1,
};

/// True 3D Minecraft skin renderer (SceneKit). Builds the humanoid out of
/// boxes UV-mapped to the 64x64 skin texture, including the outer
/// (hat/jacket/sleeves/pants) layer. Drag to rotate, pinch to zoom,
/// double-tap to reset. Used by the account panel for every account type.
@interface Skin3DView : UIView

// Auto-rotates the model. Default YES.
@property (nonatomic, assign) BOOL autoRotate;

- (void)setSkinImage:(nullable UIImage *)image model:(Skin3DModel)model;

@end

NS_ASSUME_NONNULL_END
