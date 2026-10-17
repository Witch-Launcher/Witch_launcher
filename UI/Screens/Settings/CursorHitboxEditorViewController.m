#import "CursorHitboxEditorViewController.h"
#import "CursorManager.h"
#import "ThemeManager.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import <AVFoundation/AVFoundation.h>
#import "utils.h"

@interface CursorHitboxEditorViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *hitboxMarker;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIImage *cursorImage;
@property (nonatomic) BOOL isDragging;

@end

@implementation CursorHitboxEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    self.navigationItem.title = localize(@"cursor.detail.hitbox", nil);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"Save", nil)
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(saveHitbox)];

    if (self.typeId) {
        _cursorImage = [CursorManager compositeImageForType:self.typeId];
    } else {
        _cursorImage = [CursorManager imageForCursor:self.cursorName];
    }

    _imageView = [[UIImageView alloc] initWithImage:_cursorImage];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.backgroundColor = UIColor.blackColor;
    _imageView.userInteractionEnabled = YES;
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_imageView];

    _hitboxMarker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    _hitboxMarker.translatesAutoresizingMaskIntoConstraints = NO;
    _hitboxMarker.userInteractionEnabled = NO;
    _hitboxMarker.layer.cornerRadius = 16;
    _hitboxMarker.layer.borderWidth = 3;
    _hitboxMarker.layer.borderColor = ThemeManager.shared.accentColor.CGColor;
    _hitboxMarker.backgroundColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.35];
    _hitboxMarker.layer.shadowColor = UIColor.blackColor.CGColor;
    _hitboxMarker.layer.shadowOpacity = 0.6;
    _hitboxMarker.layer.shadowRadius = 3;
    _hitboxMarker.layer.shadowOffset = CGSizeMake(0, 1);
    [_imageView addSubview:_hitboxMarker];

    _coordinateLabel = [[UILabel alloc] init];
    _coordinateLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _coordinateLabel.textColor = ThemeManager.shared.primaryTextColor;
    _coordinateLabel.textAlignment = NSTextAlignmentCenter;
    _coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_coordinateLabel];

    _hintLabel = [[UILabel alloc] init];
    _hintLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _hintLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    _hintLabel.numberOfLines = 0;
    _hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_hintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_imageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [_imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_imageView.bottomAnchor constraintEqualToAnchor:_coordinateLabel.topAnchor constant:-16],

        [_coordinateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_coordinateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_coordinateLabel.bottomAnchor constraintEqualToAnchor:_hintLabel.topAnchor constant:-8],

        [_hintLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_hintLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [_hintLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
    ]];

    _hintLabel.text = localize(@"Drag or tap to place the hitbox point (the tip of the cursor).", nil);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTouch:)];
    pan.minimumNumberOfTouches = 1;
    [_imageView addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTouch:)];
    [_imageView addGestureRecognizer:tap];

    [self syncMarkerFromHitbox];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!_isDragging) {
        [self syncMarkerFromHitbox];
    }
}

/// Vẽ marker tại vị trí hitbox hiện tại (toạ độ theo ảnh gốc -> toạ độ view).
- (void)syncMarkerFromHitbox {
    CGPoint hitbox;
    if (self.typeId) {
        hitbox = [CursorManager hitboxForCursor:self.cursorName inType:self.typeId];
    } else {
        hitbox = [CursorManager hitboxForCursor:self.cursorName];
    }
    CGPoint point = [self viewPointFromImagePoint:hitbox];
    [self placeMarkerAtPoint:point];
    _coordinateLabel.text = [NSString stringWithFormat:@"X: %.0f   Y: %.0f", hitbox.x, hitbox.y];
}

/// Chuyển toạ độ trong ảnh gốc sang toạ độ của imageView (aspect-fit).
- (CGPoint)viewPointFromImagePoint:(CGPoint)imgPoint {
    CGSize imgSize = _cursorImage.size;
    if (imgSize.width <= 0 || imgSize.height <= 0 || _imageView.bounds.size.width <= 0) return CGPointZero;
    CGRect fitRect = AVMakeRectWithAspectRatioInsideRect(imgSize, _imageView.bounds);
    return CGPointMake(fitRect.origin.x + (imgPoint.x / imgSize.width) * fitRect.size.width,
                       fitRect.origin.y + (imgPoint.y / imgSize.height) * fitRect.size.height);
}

/// Chuyển toạ độ trong imageView sang toạ độ trong ảnh gốc.
- (CGPoint)imagePointFromViewPoint:(CGPoint)viewPoint {
    CGSize imgSize = _cursorImage.size;
    if (imgSize.width <= 0 || imgSize.height <= 0 || _imageView.bounds.size.width <= 0) return CGPointZero;
    CGRect fitRect = AVMakeRectWithAspectRatioInsideRect(imgSize, _imageView.bounds);
    CGFloat x = (viewPoint.x - fitRect.origin.x) / fitRect.size.width * imgSize.width;
    CGFloat y = (viewPoint.y - fitRect.origin.y) / fitRect.size.height * imgSize.height;
    return CGPointMake(MAX(0, MIN(imgSize.width, x)), MAX(0, MIN(imgSize.height, y)));
}

- (void)placeMarkerAtPoint:(CGPoint)point {
    _hitboxMarker.center = CGPointMake(MAX(0, MIN(_imageView.bounds.size.width, point.x)),
                                       MAX(0, MIN(_imageView.bounds.size.height, point.y)));
}

- (void)handleTouch:(UIGestureRecognizer *)gesture {
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIGestureRecognizerState state = gesture.state;
        if (state == UIGestureRecognizerStateBegan) {
            _isDragging = YES;
            [HapticManager.shared play:HapticTypeLight];
        } else if (state == UIGestureRecognizerStateEnded ||
                   state == UIGestureRecognizerStateCancelled ||
                   state == UIGestureRecognizerStateFailed) {
            _isDragging = NO;
            return;
        }
    } else {
        [HapticManager.shared play:HapticTypeLight];
    }
    CGPoint loc = [gesture locationInView:_imageView];
    [self placeMarkerAtPoint:loc];
    CGPoint imgPoint = [self imagePointFromViewPoint:loc];
    _coordinateLabel.text = [NSString stringWithFormat:@"X: %.0f   Y: %.0f", imgPoint.x, imgPoint.y];
}

- (void)saveHitbox {
    CGPoint imgPoint = [self imagePointFromViewPoint:_hitboxMarker.center];
    if (self.typeId) {
        [CursorManager setHitboxForCursor:self.cursorName hitbox:imgPoint inType:self.typeId];
    } else {
        [CursorManager setHitboxForCursor:self.cursorName hitbox:imgPoint];
    }
    [HapticManager.shared play:HapticTypeSuccess];
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
