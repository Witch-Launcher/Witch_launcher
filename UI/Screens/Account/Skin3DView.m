#import "Skin3DView.h"
#import <SceneKit/SceneKit.h>
#import <QuartzCore/QuartzCore.h>

// Skin UV regions (64x64), in pixels. Verified against the default
// Steve/Alex textures and the community skin spec:
//   rows 0-15 : head    | 16-31: right leg / body / right arm
//   rows 32-47: outer   | 48-63: left leg / left arm
typedef struct { CGRect front, right, back, left, top, bottom; } WitchFaceSet;

// SCNBox material order (verified on macOS SceneKit): +z, +x, -z, -x, +y, -y
static const WitchFaceSet kHeadFaces   = {{8, 8, 8, 8},  {0, 8, 8, 8},  {24, 8, 8, 8}, {16, 8, 8, 8}, {8, 0, 8, 8},  {16, 0, 8, 8}};
static const WitchFaceSet kBodyFaces   = {{20, 20, 8, 12}, {16, 20, 4, 12}, {32, 20, 8, 12}, {28, 20, 4, 12}, {20, 16, 8, 4}, {28, 16, 8, 4}};
static const WitchFaceSet kRArmFaces   = {{44, 20, 4, 12}, {40, 20, 4, 12}, {52, 20, 4, 12}, {48, 20, 4, 12}, {44, 16, 4, 4}, {48, 16, 4, 4}};
static const WitchFaceSet kLArmFaces   = {{36, 52, 4, 12}, {32, 52, 4, 12}, {44, 52, 4, 12}, {40, 52, 4, 12}, {36, 48, 4, 4}, {40, 48, 4, 4}};
static const WitchFaceSet kRLegFaces   = {{4, 20, 4, 12},  {0, 20, 4, 12},  {12, 20, 4, 12}, {8, 20, 4, 12},  {4, 16, 4, 4},  {8, 16, 4, 4}};
static const WitchFaceSet kLLegFaces   = {{20, 52, 4, 12}, {16, 52, 4, 12}, {28, 52, 4, 12}, {24, 52, 4, 12}, {20, 48, 4, 4}, {24, 48, 4, 4}};
static const WitchFaceSet kHeadFacesO  = {{40, 8, 8, 8},  {32, 8, 8, 8},  {56, 8, 8, 8}, {48, 8, 8, 8}, {40, 0, 8, 8}, {48, 0, 8, 8}};
static const WitchFaceSet kBodyFacesO  = {{20, 36, 8, 12}, {16, 36, 4, 12}, {32, 36, 8, 12}, {28, 36, 4, 12}, {20, 32, 8, 4}, {28, 32, 8, 4}};
static const WitchFaceSet kRArmFacesO  = {{44, 36, 4, 12}, {40, 36, 4, 12}, {52, 36, 4, 12}, {48, 36, 4, 12}, {44, 32, 4, 4}, {48, 32, 4, 4}};
static const WitchFaceSet kLArmFacesO  = {{52, 52, 4, 12}, {48, 52, 4, 12}, {60, 52, 4, 12}, {56, 52, 4, 12}, {52, 48, 4, 4}, {56, 48, 4, 4}};
static const WitchFaceSet kRLegFacesO  = {{4, 36, 4, 12},  {0, 36, 4, 12},  {12, 36, 4, 12}, {8, 36, 4, 12},  {4, 32, 4, 4},  {8, 32, 4, 4}};
static const WitchFaceSet kLLegFacesO  = {{4, 52, 4, 12},  {0, 52, 4, 12},  {12, 52, 4, 12}, {8, 52, 4, 12},  {4, 48, 4, 4},  {8, 48, 4, 4}};

@interface Skin3DView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, strong) CAGradientLayer *backdropGradient;
@property (nonatomic, strong) UIView *pedestalView;
@property (nonatomic, strong) SCNView *scnView;
@property (nonatomic, strong) SCNScene *scene;
@property (nonatomic, strong) SCNNode *spinNode;
@property (nonatomic, strong) SCNNode *characterNode;
@property (nonatomic, strong) SCNNode *cameraNode;
@property (nonatomic, strong) SCNNode *cameraTarget;
@property (nonatomic, assign) Skin3DModel model;
@property (nonatomic, assign) CGFloat panStartYaw;
@property (nonatomic, assign) CGFloat panStartPitch;
@property (nonatomic, assign) CGFloat pinchStartDistance;
@end

static const CGFloat kCameraBaseY   = 20.0;
static const CGFloat kCameraBaseZ   = 88.0;
static const CGFloat kCameraTargetY = 14.0;

@implementation Skin3DView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _model = Skin3DModelClassic;
    // Default skins are mostly inspected statically: auto-rotation starts off
    // and the user can enable it from the bottom bar if they want the spin.
    _autoRotate = NO;

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;

    _backdropView = [[UIView alloc] init];
    _backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_backdropView];
    [NSLayoutConstraint activateConstraints:@[
        [_backdropView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_backdropView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_backdropView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_backdropView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.10].CGColor,
                  (id)[UIColor colorWithWhite:1 alpha:0.02].CGColor,
                  (id)[UIColor colorWithWhite:0 alpha:0.16].CGColor];
    bg.locations = @[@0.0, @0.55, @1.0];
    bg.startPoint = CGPointMake(0.5, 0.0);
    bg.endPoint = CGPointMake(0.5, 1.0);
    [_backdropView.layer insertSublayer:bg atIndex:0];
    _backdropGradient = bg;

    // Soft elliptical "pedestal" glow under the character.
    UIView *pedestal = [[UIView alloc] init];
    pedestal.translatesAutoresizingMaskIntoConstraints = NO;
    pedestal.layer.cornerRadius = 16;
    pedestal.clipsToBounds = YES;
    CAGradientLayer *glow = [CAGradientLayer layer];
    glow.type = kCAGradientLayerRadial;
    glow.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.30].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
    glow.startPoint = CGPointMake(0.5, 0.5);
    glow.endPoint = CGPointMake(1.0, 1.0);
    [pedestal.layer addSublayer:glow];
    [_backdropView addSubview:pedestal];
    _pedestalView = pedestal;
    [NSLayoutConstraint activateConstraints:@[
        [pedestal.centerXAnchor constraintEqualToAnchor:_backdropView.centerXAnchor],
        [pedestal.bottomAnchor constraintEqualToAnchor:_backdropView.bottomAnchor constant:-14],
        [pedestal.widthAnchor constraintEqualToConstant:170],
        [pedestal.heightAnchor constraintEqualToConstant:34],
    ]];
    _backdropView.layer.masksToBounds = YES;

    _scnView = [[SCNView alloc] init];
    _scnView.translatesAutoresizingMaskIntoConstraints = NO;
    _scnView.backgroundColor = UIColor.clearColor;
    _scnView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    _scnView.preferredFramesPerSecond = 60;
    _scnView.rendersContinuously = NO;
    _scnView.allowsCameraControl = NO;
    [self addSubview:_scnView];
    [NSLayoutConstraint activateConstraints:@[
        [_scnView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_scnView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_scnView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_scnView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    [self buildScene];
    [self installGestures];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.backdropGradient.frame = self.backdropView.bounds;
    for (CALayer *layer in self.pedestalView.layer.sublayers) {
        layer.frame = self.pedestalView.bounds;
    }
}

#pragma mark - Scene construction

- (void)buildScene {
    SCNScene *scene = [[SCNScene alloc] init];
    scene.background.contents = UIColor.clearColor;
    _scene = scene;
    _scnView.scene = scene;

    // Lights
    SCNNode *ambient = [SCNNode node];
    ambient.light = [SCNLight light];
    ambient.light.type = SCNLightTypeAmbient;
    ambient.light.color = [UIColor colorWithWhite:1.0 alpha:1.0];
    ambient.light.intensity = 550;
    [scene.rootNode addChildNode:ambient];

    SCNNode *key = [SCNNode node];
    key.light = [SCNLight light];
    key.light.type = SCNLightTypeDirectional;
    key.light.color = UIColor.whiteColor;
    key.light.intensity = 750;
    key.position = SCNVector3Make(24, 42, 32);
    [scene.rootNode addChildNode:key];

    SCNNode *fill = [SCNNode node];
    fill.light = [SCNLight light];
    fill.light.type = SCNLightTypeDirectional;
    fill.light.color = [UIColor colorWithRed:0.75 green:0.82 blue:1.0 alpha:1.0];
    fill.light.intensity = 320;
    fill.position = SCNVector3Make(-28, 10, -22);
    [scene.rootNode addChildNode:fill];

    // Camera rig: camera always looks at cameraTarget via constraint.
    _cameraTarget = [SCNNode node];
    _cameraTarget.position = SCNVector3Make(0, kCameraTargetY, 0);
    [scene.rootNode addChildNode:_cameraTarget];

    SCNNode *cameraNode = [SCNNode node];
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = 24.0;
    camera.zNear = 1.0;
    camera.zFar = 500.0;
    cameraNode.camera = camera;
    cameraNode.position = SCNVector3Make(0, kCameraBaseY, kCameraBaseZ);
    cameraNode.constraints = @[[SCNLookAtConstraint lookAtConstraintWithTarget:_cameraTarget]];
    [scene.rootNode addChildNode:cameraNode];
    _cameraNode = cameraNode;
    _scnView.pointOfView = cameraNode;

    // Character hierarchy: spinNode (auto-rotate) > characterNode (user pan)
    _spinNode = [SCNNode node];
    [scene.rootNode addChildNode:_spinNode];
    _characterNode = [SCNNode node];
    [_spinNode addChildNode:_characterNode];

    // Gentle idle bob on the character node (independent of user rotation).
    SCNAction *bobUp   = [SCNAction moveTo:SCNVector3Make(0, 0.35, 0) duration:1.5];
    bobUp.timingMode = SCNActionTimingModeEaseInEaseOut;
    SCNAction *bobDown = [SCNAction moveTo:SCNVector3Make(0, -0.15, 0) duration:1.5];
    bobDown.timingMode = SCNActionTimingModeEaseInEaseOut;
    [_characterNode runAction:[SCNAction repeatActionForever:[SCNAction sequence:@[bobUp, bobDown]]] forKey:@"idleBob"];

    [self applyAutoRotate:_autoRotate];
}

- (void)setAutoRotate:(BOOL)autoRotate {
    _autoRotate = autoRotate;
    [self applyAutoRotate:autoRotate];
}

- (void)applyAutoRotate:(BOOL)on {
    if (!_spinNode) return;
    if (on) {
        SCNAction *spin = [SCNAction rotateByX:0 y:2.0 * M_PI z:0 duration:18.0];
        spin.timingMode = SCNActionTimingModeLinear;
        [_spinNode runAction:[SCNAction repeatActionForever:spin] forKey:@"spin"];
    } else {
        [_spinNode removeActionForKey:@"spin"];
        // Ease the spin back to a neutral facing so the model does not snap.
        SCNAction *settle = [SCNAction rotateToX:0 y:0 z:0 duration:0.45];
        settle.timingMode = SCNActionTimingModeEaseInEaseOut;
        [_spinNode runAction:settle forKey:@"settle"];
    }
}

#pragma mark - Skin building

- (UIImage *)cropSkin:(UIImage *)skin rect:(CGRect)rect flipHorizontal:(BOOL)flip {
    CGImageRef full = skin.CGImage;
    if (!full) return nil;
    CGImageRef cropped = CGImageCreateWithImageInRect(full, rect);
    if (!cropped) return nil;
    UIImage *image = nil;
    if (!flip) {
        image = [UIImage imageWithCGImage:cropped scale:1.0 orientation:UIImageOrientationUp];
    } else {
        // Raw bitmap context (NOT UIGraphics*): a UIKit context would add a
        // vertical flip on top of the horizontal one and the face would show
        // upside down.
        size_t w = CGImageGetWidth(cropped);
        size_t h = CGImageGetHeight(cropped);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(space);
        if (ctx) {
            CGContextTranslateCTM(ctx, (CGFloat)w, 0);
            CGContextScaleCTM(ctx, -1, 1);
            CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cropped);
            CGImageRef flipped = CGBitmapContextCreateImage(ctx);
            CGContextRelease(ctx);
            if (flipped) {
                image = [UIImage imageWithCGImage:flipped scale:1.0 orientation:UIImageOrientationUp];
                CGImageRelease(flipped);
            }
        }
    }
    CGImageRelease(cropped);
    return image;
}

- (SCNMaterial *)materialWithImage:(UIImage *)image outer:(BOOL)outer {
    SCNMaterial *mat = [SCNMaterial material];
    mat.diffuse.contents = image ?: UIColor.magentaColor;
    mat.diffuse.magnificationFilter = SCNFilterModeNearest;
    mat.diffuse.minificationFilter = SCNFilterModeNearest;
    mat.lightingModelName = SCNLightingModelBlinn;
    mat.specular.contents = [UIColor colorWithWhite:0.06 alpha:1.0];
    if (outer) {
        // Keep the material in the transparent pass so the PNG's alpha
        // channel cuts the hat/jacket pixels out, and never writes depth
        // (which would punch holes into the base body).
        mat.transparency = 0.999;
        mat.writesToDepthBuffer = NO;
    }
    return mat;
}

- (NSArray<SCNMaterial *> *)materialsForSkin:(UIImage *)skin faces:(WitchFaceSet)faces outer:(BOOL)outer {
    UIImage *front  = [self cropSkin:skin rect:faces.front flipHorizontal:NO];
    UIImage *right  = [self cropSkin:skin rect:faces.right flipHorizontal:NO];
    UIImage *back   = [self cropSkin:skin rect:faces.back  flipHorizontal:YES];
    UIImage *left   = [self cropSkin:skin rect:faces.left  flipHorizontal:NO];
    UIImage *top    = [self cropSkin:skin rect:faces.top   flipHorizontal:NO];
    UIImage *bottom = [self cropSkin:skin rect:faces.bottom flipHorizontal:NO];
    // SCNBox material order (verified): +z, +x, -z, -x, +y, -y
    return @[[self materialWithImage:front outer:outer],
             [self materialWithImage:right outer:outer],
             [self materialWithImage:back  outer:outer],
             [self materialWithImage:left  outer:outer],
             [self materialWithImage:top   outer:outer],
             [self materialWithImage:bottom outer:outer]];
}

- (SCNNode *)boxWithWidth:(CGFloat)w height:(CGFloat)h length:(CGFloat)d
                  position:(SCNVector3)pos faces:(WitchFaceSet)faces outer:(BOOL)outer skin:(UIImage *)skin {
    SCNBox *box = [SCNBox boxWithWidth:w height:h length:d chamferRadius:0];
    box.materials = [self materialsForSkin:skin faces:faces outer:outer];
    SCNNode *node = [SCNNode nodeWithGeometry:box];
    node.position = pos;
    if (outer) node.renderingOrder = 10;
    return node;
}

- (void)setSkinImage:(UIImage *)image model:(Skin3DModel)model {
    _model = model;
    // Detach the old character wholesale and build a fresh one: cheap, and
    // avoids mutating the node tree while iterating over it.
    [_characterNode removeFromParentNode];
    _characterNode = [SCNNode node];
    [_spinNode addChildNode:_characterNode];
    if (!image) {
        [self applyAutoRotate:_autoRotate];
        return;
    }

    CGFloat armW = (model == Skin3DModelSlim) ? 3.0 : 4.0;
    CGFloat armX = 4.0 + armW / 2.0;

    // Base layer
    [_characterNode addChildNode:[self boxWithWidth:8 height:8 length:8 position:SCNVector3Make(0, 28, 0) faces:kHeadFaces outer:NO skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:8 height:12 length:4 position:SCNVector3Make(0, 18, 0) faces:kBodyFaces outer:NO skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:armW height:12 length:4 position:SCNVector3Make(-armX, 18, 0) faces:kRArmFaces outer:NO skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:armW height:12 length:4 position:SCNVector3Make(armX, 18, 0) faces:kLArmFaces outer:NO skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:4 height:12 length:4 position:SCNVector3Make(-2, 6, 0) faces:kRLegFaces outer:NO skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:4 height:12 length:4 position:SCNVector3Make(2, 6, 0) faces:kLLegFaces outer:NO skin:image]];

    // Outer (overlay) layer: +1 unit per axis (0.5 per side)
    [_characterNode addChildNode:[self boxWithWidth:9 height:9 length:9 position:SCNVector3Make(0, 28, 0) faces:kHeadFacesO outer:YES skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:9 height:13 length:5 position:SCNVector3Make(0, 18, 0) faces:kBodyFacesO outer:YES skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:armW + 1 height:13 length:5 position:SCNVector3Make(-armX, 18, 0) faces:kRArmFacesO outer:YES skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:armW + 1 height:13 length:5 position:SCNVector3Make(armX, 18, 0) faces:kLArmFacesO outer:YES skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:5 height:13 length:5 position:SCNVector3Make(-2, 6, 0) faces:kRLegFacesO outer:YES skin:image]];
    [_characterNode addChildNode:[self boxWithWidth:5 height:13 length:5 position:SCNVector3Make(2, 6, 0) faces:kLLegFacesO outer:YES skin:image]];

    // Restore the idle bob on the fresh character node.
    SCNAction *bobUp   = [SCNAction moveTo:SCNVector3Make(0, 0.35, 0) duration:1.5];
    bobUp.timingMode = SCNActionTimingModeEaseInEaseOut;
    SCNAction *bobDown = [SCNAction moveTo:SCNVector3Make(0, -0.15, 0) duration:1.5];
    bobDown.timingMode = SCNActionTimingModeEaseInEaseOut;
    [_characterNode runAction:[SCNAction repeatActionForever:[SCNAction sequence:@[bobUp, bobDown]]] forKey:@"idleBob"];

    // Pop-in animation
    _characterNode.opacity = 0.0;
    _characterNode.scale = SCNVector3Make(0.92, 0.92, 0.92);
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.28];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _characterNode.opacity = 1.0;
    _characterNode.scale = SCNVector3Make(1, 1, 1);
    [SCNTransaction commit];
}

#pragma mark - Gestures

- (void)installGestures {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    pan.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:pan];

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self addGestureRecognizer:pinch];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:doubleTap];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        CGPoint v = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self];
        return fabs(v.x) > fabs(v.y);
    }
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        _panStartYaw = _characterNode.eulerAngles.y;
        _panStartPitch = _characterNode.eulerAngles.x;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [pan translationInView:self];
        SCNVector3 euler = _characterNode.eulerAngles;
        euler.y = _panStartYaw + t.x * 0.011;
        CGFloat pitch = _panStartPitch + t.y * 0.004;
        pitch = MAX(-0.38, MIN(0.38, pitch));
        euler.x = pitch;
        _characterNode.eulerAngles = euler;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)pinch {
    if (pinch.state == UIGestureRecognizerStateBegan) {
        _pinchStartDistance = [self cameraDistance];
    } else if (pinch.state == UIGestureRecognizerStateChanged) {
        CGFloat dist = _pinchStartDistance / MAX(pinch.scale, 0.05);
        [self setCameraDistance:dist];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.35];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    _characterNode.eulerAngles = SCNVector3Make(0, 0, 0);
    [self setCameraDistance:hypot(kCameraBaseZ, kCameraBaseY - kCameraTargetY)];
    [SCNTransaction commit];
}

- (CGFloat)cameraDistance {
    SCNVector3 p = _cameraNode.position;
    SCNVector3 t = _cameraTarget.position;
    return hypot(p.x - t.x, hypot(p.y - t.y, p.z - t.z));
}

- (void)setCameraDistance:(CGFloat)distance {
    CGFloat clamped = MAX(52.0, MIN(140.0, distance));
    // Keep the base viewing direction (0, dy, dz) normalized from the rig.
    CGFloat dy = kCameraBaseY - kCameraTargetY;
    CGFloat dz = kCameraBaseZ;
    CGFloat len = hypot(dy, dz);
    CGFloat ny = dy / len, nz = dz / len;
    _cameraNode.position = SCNVector3Make(0, kCameraTargetY + ny * clamped, nz * clamped);
}

@end
