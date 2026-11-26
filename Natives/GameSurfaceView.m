#import "GameSurfaceView.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "utils.h"
#import <Metal/Metal.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

// Game framebuffer size published by SurfaceViewController.updateSavedResolution
// (physical size x video.resolution). TGLMT's render target and the layer's
// drawableSize must follow THIS size: the game renders windowWidth x
// windowHeight and CAMetalLayer stretches the drawable over the layer bounds.
// The drawable is also bounds x contentsScale, but that value can lag (at init
// the layer's contentsScale is still 1), and TGLMT presents
// min(target, drawable): a physical-size target left an uncovered border
// around the smaller render on reso changes and a stretched/wrong-aspect
// image after rotation (both GLFW and SDL sessions route through
// syncLayerSize).
extern int windowWidth, windowHeight;

@interface GameSurfaceView()
- (void)notifyTGLESResizeIfNeeded;
- (void)notifyTGLMTResizeIfNeeded;
@end

@implementation GameSurfaceView

// ANGLE (Metal + Vulkan) creates its window surface directly from the
// CAMetalLayer. It requires a BGRA8 pixel format and a non-zero drawable
// size at eglCreateWindowSurface time, otherwise EGL returns
// EGL_BAD_NATIVE_WINDOW (0x300B) and Minecraft aborts with
// "No supported graphics backend was found".
// framebufferOnly=NO is needed because MobileGL/ANGLE does readbacks
// (glReadPixels diagnostics) and compositing on the same drawable.
- (void)configureMetalLayerIfNeeded {
    CALayer *layer = self.layer;
    if (![layer isKindOfClass:CAMetalLayer.class]) {
        return;
    }
    CAMetalLayer *ml = (CAMetalLayer *)layer;
    // TGLMT presenta từ target RGBA8Unorm — pixelFormat phải khớp, ngược lại
    // presentTarget từ chối (màn hình đen). Mọi backend khác giữ BGRA8 của ANGLE.
    BOOL isTGLMT = [[PLProfiles resolveKeyForCurrentProfile:@"renderer"]
                    isEqualToString:@ RENDERER_NAME_TGLMT];
    MTLPixelFormat wantFormat = isTGLMT ? MTLPixelFormatRGBA8Unorm : MTLPixelFormatBGRA8Unorm;
    if (ml.pixelFormat != wantFormat) {
        ml.pixelFormat = wantFormat;
    }
    // Allow shader-read / readback on the drawable (MobileGL diagnostics,
    // ANGLE copy paths). Keeps Metal validation from rejecting the surface.
    ml.framebufferOnly = NO;
    CGSize boundsSize = ml.bounds.size;
    CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
    CGSize want = CGSizeMake(MAX(2, boundsSize.width * scale),
                             MAX(2, boundsSize.height * scale));
    if (isTGLMT) {
        // TGLMT render đúng drawableSize lúc CreateWindow nhưng present copy
        // min(target, drawable): drawable kẹt ở bounds×1 (736x414, do set lúc
        // init khi contentsScale chưa có) là toàn màn hình bị crop+upscale 3x.
        // Luồng sync phải theo FRAMEBUFFER của game (windowWidth/Height =
        // physical x video.resolution), không phải drawable physical: MC vẽ
        // vào windowWidth x windowHeight rồi CAMetalLayer stretch drawable
        // lên full layer. Target/drawable physical làm khung render nhỏ hơn
        // màn hình (viền đen khi hạ reso) và méo aspect khi xoay ngang.
        // Fallback về bounds x scale khi game chưa publish kích thước (lúc
        // init/updateSavedResolution chưa chạy).
        CGSize fbWant = (windowWidth >= 2 && windowHeight >= 2)
            ? CGSizeMake(windowWidth, windowHeight) : want;
        if (ml.drawableSize.width != fbWant.width || ml.drawableSize.height != fbWant.height) {
            ml.drawableSize = fbWant;
        }
    } else if (ml.drawableSize.width < 2 || ml.drawableSize.height < 2) {
        ml.drawableSize = want;
    }
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.layer.drawsAsynchronously = YES;
    self.layer.opaque = YES;
    [self configureMetalLayerIfNeeded];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Bounds can be zero at init (view not attached yet) and become valid
    // after autolayout / rotation. Refresh drawableSize so a later
    // eglCreateWindowSurface never sees a 0x0 native window.
    [self syncLayerSize];
}

- (void)syncLayerSize {
    [self configureMetalLayerIfNeeded];
    [self notifyTGLESResizeIfNeeded];
    [self notifyTGLMTResizeIfNeeded];
}

// TGLMT giữ target render theo drawable size lúc CreateWindow — xoay màn hình
// phải Resize target, không thì present letterbox. dlsym-bridge nội bộ
// (tglmt_bridge linked cùng binary) nên gọi trực tiếp, no-op khi không active.
- (void)notifyTGLMTResizeIfNeeded {
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    if (![renderer isEqualToString:@ RENDERER_NAME_TGLMT]) {
        NSString *profileRenderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
        if (![profileRenderer isEqualToString:@ RENDERER_NAME_TGLMT]) return;
    }
    CALayer *layer = self.layer;
    if (![layer isKindOfClass:CAMetalLayer.class]) return;
    CAMetalLayer *ml = (CAMetalLayer *)layer;
    // Resize target theo framebuffer của game (physical x video.resolution),
    // không phải drawable physical. Hạ reso thì game render windowWidth x
    // windowHeight; target full-size sẽ để lại viền không phủ, xoay ngang
    // thì target lệch aspect với viewport của game (ảnh kéo dãn). Fallback
    // bounds x scale khi game chưa publish size.
    int w, h;
    if (windowWidth >= 2 && windowHeight >= 2) {
        w = (int)windowWidth;
        h = (int)windowHeight;
    } else {
        CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
        w = (int)MAX(2, ml.bounds.size.width * scale);
        h = (int)MAX(2, ml.bounds.size.height * scale);
    }
    extern void tglmt_notify_resize(int, int);
    tglmt_notify_resize(w, h);
}

// TGLES (MobileGL DirectGLES and, now, MobileGlues) keeps its own layer size
// inside the dylib (tglHostAttachMetalLayer at surface creation). Rotation
// changes the drawable size, so forward it via tglHostResizeMetalLayer.
// Silent no-op (returns 0) before the first attach; logs only the first
// successful resize to avoid spamming layout. dlsym-based so non-TGLES
// renderers pay nothing and missing libtgles never crashes.
- (void)notifyTGLESResizeIfNeeded {
    // Same gate as tgles_is_active() in gl_bridge.m. MobileGL only reaches
    // TGLES through DirectGLES; MobileGlues reaches it when the launcher
    // pre-loaded libtgles (MOBILEGL_ANGLE_BACKEND=tgles, unset on the
    // MetalANGLE fallback).
    NSString *renderer = NSProcessInfo.processInfo.environment[@"AMETHYST_RENDERER"];
    BOOL isMobileGL = [renderer isEqualToString:@ RENDERER_NAME_MOBILEGL];
    BOOL isMobileGlues = [renderer isEqualToString:@ RENDERER_NAME_MOBILEGLUES];
    if (!isMobileGL && !isMobileGlues) return;
    const char *angleBackend = getenv("MOBILEGL_ANGLE_BACKEND");
    if (angleBackend && strcmp(angleBackend, "vulkan") == 0) return;
    if (isMobileGL) {
        const char *backendType = getenv("MOBILEGL_BACKEND_TYPE");
        if (!backendType || strcmp(backendType, "DirectGLES") != 0) return;
    } else if (!angleBackend || strcmp(angleBackend, "tgles") != 0) {
        return;
    }
    CALayer *layer = self.layer;
    if (![layer isKindOfClass:CAMetalLayer.class]) return;
    static int (*resizeFn)(int, int) = NULL;
    static BOOL lookedUp = NO;
    if (!lookedUp) {
        lookedUp = YES;
        void *lib = dlopen("@rpath/libtgles.dylib", RTLD_NOLOAD);
        if (lib) resizeFn = (int (*)(int, int))dlsym(lib, "tglHostResizeMetalLayer");
    }
    if (!resizeFn) return;
    CAMetalLayer *ml = (CAMetalLayer *)layer;
    CGFloat scale = ml.contentsScale > 0 ? ml.contentsScale : UIScreen.mainScreen.scale;
    int w = (int)MAX(2, ml.bounds.size.width * scale);
    int h = (int)MAX(2, ml.bounds.size.height * scale);
    static BOOL loggedResize = NO;
    if (resizeFn(w, h) && !loggedResize) {
        loggedResize = YES;
        NSLog(@"[TGLES] resize OK: %dx%d", w, h);
    }
}

+ (Class)layerClass {
    if ([[PLProfiles resolveKeyForCurrentProfile:@"renderer"] hasPrefix:@"libOSMesa"]) {
        return CALayer.class;
    } else {
        return CAMetalLayer.class;
    }
}

@end
