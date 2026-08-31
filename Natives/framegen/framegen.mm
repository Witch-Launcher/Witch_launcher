//
//  framegen.mm
//  Witch - Frame Generation module
//
//  Inserts interpolated intermediate frames between real rendered frames
//  to increase apparent FPS. Uses Metal compute shaders for
//  motion-vector reprojection and temporal blending.
//
//  Fixes applied:
//  - A1: fgPresentInterpolatedFrame uses originalDrawable (no double nextDrawable)
//  - A2: Placeholder depth texture when depth is nil
//  - A5: Interpolation factor calculated BEFORE lastFrameTime update
//  - A6: os_unfair_lock for thread safety on gContext
//  - A7: Matrix inverse computed on CPU, uploaded precomputed
//  - A9: Camera data propagated when ring buffer advances
//

#import "framegen.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <os/lock.h>

extern "C" void widgetEnsureMetalSwizzle(void);

typedef id<CAMetalDrawable> FGMetalDrawable;

#define FG_RING_BUFFER_SIZE 3
#define FG_MIN_NATIVE_FPS 20
#define FG_MAX_INTERP_FACTOR 0.5f

// MARK: - Internal Structures

typedef struct {
    float pos[3];
    float rot[2];
    float viewMatrix[16];
    float projMatrix[16];
    float invViewMatrix[16];   // Precomputed inverse (A7)
    float invProjMatrix[16];   // Precomputed inverse (A7)
    float fov;
    int width;
    int height;
    BOOL valid;
    double timestamp;
} FGInternalCameraData;

typedef struct {
    id<MTLTexture> colorTexture;
    id<MTLTexture> depthTexture;
    uint64_t frameIndex;
    double timestamp;
    FGInternalCameraData camera;
    BOOL valid;
} FGFrameBufferEntry;

typedef struct {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> reprojectionPipeline;
    id<MTLComputePipelineState> blendPipeline;
    id<MTLComputePipelineState> predictionPipeline;  // Predictive/extrapolation pipeline
    id<MTLBuffer> cameraDataBuffer;
    FGFrameBufferEntry ringBuffer[FG_RING_BUFFER_SIZE];
    int ringHead;
    int ringCount;
    uint64_t frameCounter;
    BOOL enabled;
    BOOL supported;
    BOOL initialized;
    dispatch_queue_t fgQueue;
    double lastFrameTime;
    uint64_t framesInterpolated;
    uint64_t framesSkipped;
    uint64_t totalFrames;
    float nativeFPS;
    float displayFPS;
    id<MTLTexture> placeholderDepth;  // A2: placeholder depth texture

    // OSMesa-specific timing (separate from Metal path to avoid shared timer corruption)
    double osmLastFrameTime;
    float  osmNativeFPS;
    float  osmAvgFPS;       // Exponential moving average for stability
    float  osmFrameTimes[8]; // Ring buffer for frame time averaging
    int    osmFrameTimeIdx;
    int    osmFrameTimeCount;
    double osmBlendStartTime; // When the blend started (for overhead measurement)
    uint64_t osmBlendOverheadUs; // Last blend overhead in microseconds

    // OSMesa camera data (bypasses Metal ring buffer — needed because fgProcessFrame
    // only runs on Metal path, leaving Metal ring buffer empty in OSMesa mode)
    FGInternalCameraData osmLatestCamera;   // Latest camera data from JNI
    FGInternalCameraData osmPrevCamera;     // Previous camera data (for motion vector)

    // Cached Metal textures for OSMesa GPU path (avoid per-frame create/destroy)
    id<MTLTexture> osmCachedUploadTex0;    // Reusable upload texture for prev frame
    id<MTLTexture> osmCachedUploadTex1;    // Reusable upload texture for curr frame
    id<MTLTexture> osmCachedOutputTex;     // Reusable output texture
    uint32_t osmCachedTexWidth;
    uint32_t osmCachedTexHeight;
} FGContext;

static FGContext gContext = {0};
static dispatch_once_t gInitOnce;
static os_unfair_lock gLock = OS_UNFAIR_LOCK_INIT;  // A6: thread safety

// MARK: - CPU Matrix Inverse (A7)

static void fgMatrixInverse4x4(const float* m, float* out) {
    float a00 = m[0], a01 = m[1], a02 = m[2], a03 = m[3];
    float a10 = m[4], a11 = m[5], a12 = m[6], a13 = m[7];
    float a20 = m[8], a21 = m[9], a22 = m[10], a23 = m[11];
    float a30 = m[12], a31 = m[13], a32 = m[14], a33 = m[15];

    float b00 = a00 * a11 - a01 * a10;
    float b01 = a00 * a12 - a02 * a10;
    float b02 = a00 * a13 - a03 * a10;
    float b03 = a01 * a12 - a02 * a11;
    float b04 = a01 * a13 - a03 * a11;
    float b05 = a02 * a13 - a03 * a12;
    float b06 = a20 * a31 - a21 * a30;
    float b07 = a20 * a32 - a22 * a30;
    float b08 = a20 * a33 - a23 * a30;
    float b09 = a21 * a32 - a22 * a31;
    float b10 = a21 * a33 - a23 * a31;
    float b11 = a22 * a33 - a23 * a32;

    float det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
    if (fabsf(det) < 1e-10f) {
        // Identity fallback
        out[0] = 1; out[1] = 0; out[2] = 0; out[3] = 0;
        out[4] = 0; out[5] = 1; out[6] = 0; out[7] = 0;
        out[8] = 0; out[9] = 0; out[10] = 1; out[11] = 0;
        out[12] = 0; out[13] = 0; out[14] = 0; out[15] = 1;
        return;
    }
    float invDet = 1.0f / det;
    out[0]  = ( a11 * b11 - a12 * b10 + a13 * b09) * invDet;
    out[1]  = ( a02 * b10 - a01 * b11 - a03 * b09) * invDet;
    out[2]  = ( a31 * b05 - a32 * b04 + a33 * b03) * invDet;
    out[3]  = ( a22 * b04 - a21 * b05 - a23 * b03) * invDet;
    out[4]  = ( a12 * b08 - a10 * b11 - a13 * b07) * invDet;
    out[5]  = ( a00 * b11 - a02 * b08 + a03 * b07) * invDet;
    out[6]  = ( a32 * b02 - a30 * b05 - a33 * b01) * invDet;
    out[7]  = ( a20 * b05 - a22 * b02 + a23 * b01) * invDet;
    out[8]  = ( a10 * b10 - a11 * b08 + a13 * b06) * invDet;
    out[9]  = ( a01 * b08 - a00 * b10 - a03 * b06) * invDet;
    out[10] = ( a30 * b04 - a31 * b02 + a33 * b00) * invDet;
    out[11] = ( a21 * b02 - a20 * b04 - a23 * b00) * invDet;
    out[12] = ( a11 * b07 - a10 * b09 - a12 * b06) * invDet;
    out[13] = ( a00 * b09 - a01 * b07 + a02 * b06) * invDet;
    out[14] = ( a31 * b01 - a30 * b03 - a32 * b00) * invDet;
    out[15] = ( a20 * b03 - a21 * b01 + a22 * b00) * invDet;
}

// MARK: - Metal Shaders

// Shader now uses precomputed inverse matrices from CPU (A7)
// No manualInverse() needed in shader — huge performance win
static const char* kReprojectionShader = R"(
#include <metal_stdlib>
using namespace metal;

struct CameraData {
    float4x4 viewMatrix;
    float4x4 projMatrix;
    float4x4 prevViewMatrix;
    float4x4 prevProjMatrix;
    float4x4 invViewMatrix;    // Precomputed on CPU (A7)
    float4x4 invProjMatrix;    // Precomputed on CPU (A7)
    float2 viewportSize;
    float interpFactor;
};

kernel void reprojectionKernel(
    texture2d<float, access::sample> prevColor [[texture(0)]],
    texture2d<float, access::sample> currColor [[texture(1)]],
    texture2d<float, access::sample> prevDepth [[texture(2)]],
    texture2d<float, access::sample> currDepth [[texture(3)]],
    texture2d<float, access::write> output [[texture(4)]],
    constant CameraData& cameraData [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= (uint)cameraData.viewportSize.x || gid.y >= (uint)cameraData.viewportSize.y) return;

    float2 uv = (float2(gid) + 0.5) / cameraData.viewportSize;

    // Sample depth (A2: placeholder depth is 1.0 when nil)
    constexpr sampler depthSampler(coord::normalized, filter::nearest, address::clamp_to_edge);
    float currDepthVal = currDepth.sample(depthSampler, uv).r;

    // Reconstruct view-space position from current frame depth
    float2 ndc = uv * 2.0 - 1.0;
    float4 clipPos = float4(ndc, currDepthVal * 2.0 - 1.0, 1.0);

    // Clip -> View space (using precomputed inverse projection)
    float4 viewPos = cameraData.invProjMatrix * clipPos;
    viewPos /= viewPos.w;

    // View -> World space (using precomputed inverse view)
    float4 worldPos = cameraData.invViewMatrix * viewPos;

    // World -> Previous frame clip space
    float4 prevClip = cameraData.prevViewMatrix * worldPos;
    prevClip = cameraData.prevProjMatrix * prevClip;
    prevClip /= prevClip.w;

    // Previous clip -> UV
    float2 prevUV = (prevClip.xy + 1.0) * 0.5;

    // Motion vector
    float2 motionVector = prevUV - uv;

    // Sample with motion compensation
    constexpr sampler colorSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float2 sampleUV = uv + motionVector * cameraData.interpFactor;
    sampleUV = clamp(sampleUV, float2(0.0), float2(1.0));

    float4 prevSample = prevColor.sample(colorSampler, sampleUV);
    float4 currSample = currColor.sample(colorSampler, uv);

    // Temporal blend
    float4 result = mix(currSample, prevSample, cameraData.interpFactor);
    output.write(result, gid);
}
)";

static const char* kSimpleBlendShader = R"(
#include <metal_stdlib>
using namespace metal;

kernel void simpleBlendKernel(
    texture2d<float, access::sample> prevColor [[texture(0)]],
    texture2d<float, access::sample> currColor [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float& interpFactor [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    constexpr sampler colorSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float2 uv = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());

    float4 prev = prevColor.sample(colorSampler, uv);
    float4 curr = currColor.sample(colorSampler, uv);
    float4 result = mix(curr, prev, interpFactor);
    output.write(result, gid);
}
)";

// MARK: - Predictive Shader (extrapolate forward from current frame)
// Instead of interpolating between two frames, this predicts the NEXT frame
// by applying forward motion vector to the current frame.
// This eliminates ghosting because we never blend two different images.
// v2: Added edge-aware blending, disocclusion detection, adaptive predict factor.

static const char* kPredictionShader = R"(
#include <metal_stdlib>
using namespace metal;

struct PredictionData {
    float4x4 currViewMatrix;
    float4x4 currProjMatrix;
    float4x4 prevViewMatrix;
    float4x4 prevProjMatrix;
    float4x4 invViewMatrix;
    float4x4 invProjMatrix;
    float2 viewportSize;
    float predictFactor;  // t: 0 = current frame, 1 = predict next frame, >1 = extrapolate further
};

kernel void predictionKernel(
    texture2d<float, access::sample> currColor [[texture(0)]],
    texture2d<float, access::sample> currDepth [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant PredictionData& data [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= (uint)data.viewportSize.x || gid.y >= (uint)data.viewportSize.y) return;

    float2 uv = (float2(gid) + 0.5) / data.viewportSize;

    // Sample depth (placeholder = 1.0 when no depth buffer)
    constexpr sampler depthSampler(coord::normalized, filter::nearest, address::clamp_to_edge);
    float depthVal = currDepth.sample(depthSampler, uv).r;

    // Reconstruct view-space position from current frame depth
    float2 ndc = uv * 2.0 - 1.0;
    float4 clipPos = float4(ndc, depthVal * 2.0 - 1.0, 1.0);

    // Clip -> View space
    float4 viewPos = data.invProjMatrix * clipPos;
    viewPos /= viewPos.w;

    // View -> World space
    float4 worldPos = data.invViewMatrix * viewPos;

    // World -> Previous frame clip space (to compute motion vector)
    float4 prevClip = data.prevViewMatrix * worldPos;
    prevClip = data.prevProjMatrix * prevClip;
    prevClip /= prevClip.w;

    // Previous frame UV
    float2 prevUV = (prevClip.xy + 1.0) * 0.5;

    // Motion vector: direction from current to previous
    float2 motionVector = prevUV - uv;

    // EXTRAPOLATE FORWARD: to predict next frame, move in OPPOSITE direction
    float2 predictedUV = uv - motionVector * data.predictFactor;
    predictedUV = clamp(predictedUV, float2(0.0), float2(1.0));

    // === Edge-aware sampling: detect disocclusion by checking depth gradient ===
    constexpr sampler colorSampler(coord::normalized, filter::linear, address::clamp_to_edge);

    // Sample neighboring depths to detect edges (disocclusion occurs at depth discontinuities)
    float2 texelSize = 1.0 / data.viewportSize;
    float depthL = currDepth.sample(depthSampler, uv + float2(-texelSize.x, 0.0)).r;
    float depthR = currDepth.sample(depthSampler, uv + float2( texelSize.x, 0.0)).r;
    float depthU = currDepth.sample(depthSampler, uv + float2(0.0, -texelSize.y)).r;
    float depthD = currDepth.sample(depthSampler, uv + float2(0.0,  texelSize.y)).r;

    // Depth gradient magnitude (Sobel-like)
    float depthGrad = abs(depthR - depthL) + abs(depthD - depthU);

    // At depth edges, reduce predict factor to avoid disocclusion artifacts
    // High gradient = edge = likely occlusion boundary
    float edgeFactor = 1.0 - saturate(depthGrad * 10.0);
    float adaptiveFactor = data.predictFactor * mix(0.3, 1.0, edgeFactor);

    // Recalculate predicted UV with adaptive factor
    predictedUV = uv - motionVector * adaptiveFactor;
    predictedUV = clamp(predictedUV, float2(0.0), float2(1.0));

    // Sample with motion compensation
    float4 predictedColor = currColor.sample(colorSampler, predictedUV);

    // === Confidence blending: at edges, blend more toward original position ===
    float4 originalColor = currColor.sample(colorSampler, uv);
    float4 result = mix(predictedColor, originalColor, edgeFactor * 0.3);

    output.write(result, gid);
}
)";

// MARK: - Forward Declarations

static BOOL fgSetupMetal(FGContext* ctx);
static void fgCleanupMetal(FGContext* ctx);
static void fgProcessFrame(FGContext* ctx, id<CAMetalDrawable> drawable);
static id<MTLTexture> fgCreateTextureCopy(FGContext* ctx, id<MTLTexture> src, uint64_t frameIndex);
static id<MTLTexture> fgCreatePlaceholderDepth(FGContext* ctx, int width, int height);  // A2
static void fgRunReprojection(FGContext* ctx, FGFrameBufferEntry* prev, FGFrameBufferEntry* curr, id<MTLTexture> output, float interpFactor);
static void fgRunSimpleBlend(FGContext* ctx, FGFrameBufferEntry* prev, FGFrameBufferEntry* curr, id<MTLTexture> output, float interpFactor);
static FGFrameBufferEntry* fgGetPrevFrame(FGContext* ctx);
static FGFrameBufferEntry* fgGetCurrFrame(FGContext* ctx);
static void fgUpdateCameraDataBuffer(FGContext* ctx, FGInternalCameraData* prevCam, FGInternalCameraData* currCam, float interpFactor);
static float fgCalculateInterpFactor(FGContext* ctx, double currentTime);
static void fgPresentInterpolatedFrame(FGContext* ctx, id<CAMetalDrawable> originalDrawable, id<MTLTexture> interpolatedTexture);  // A1
static void fg_try_setup_metal(void);

// MARK: - Public API Implementation

void fg_init(void) {
    dispatch_once(&gInitOnce, ^{
        gContext.fgQueue = dispatch_queue_create("com.witch.framegen", DISPATCH_QUEUE_SERIAL);
        gContext.enabled = NO;
        gContext.initialized = YES;
        gContext.ringHead = 0;
        gContext.ringCount = 0;
        gContext.frameCounter = 0;
        gContext.framesInterpolated = 0;
        gContext.framesSkipped = 0;
        gContext.totalFrames = 0;
        gContext.nativeFPS = 0;
        gContext.displayFPS = 0;
        gContext.lastFrameTime = 0;
        gContext.osmLastFrameTime = 0;
        gContext.osmNativeFPS = 0;
        gContext.osmAvgFPS = 0;
        memset(gContext.osmFrameTimes, 0, sizeof(gContext.osmFrameTimes));
        gContext.osmFrameTimeIdx = 0;
        gContext.osmFrameTimeCount = 0;
        gContext.osmBlendOverheadUs = 0;

        // Skip Metal setup if FG preference is OFF — avoids unnecessary GPU
        // pipeline creation that may interfere with the game's Metal rendering.
        // Metal will be set up on demand when the user enables FG.
        // NOTE: Using NSUserDefaults directly instead of getPrefBool() to avoid
        // missing symbol crash — getPrefBool is defined in LauncherPreferences.m
        // but the linker cannot resolve it from framegen.mm (different compilation unit).
        BOOL fgPrefEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"video.frame_generation"];
        if (!fgPrefEnabled) {
            gContext.supported = NO;
            NSLog(@"[FrameGen] Initialized (Metal skipped, FG preference OFF)");
            return;
        }

        gContext.supported = fgSetupMetal(&gContext);
        if (!gContext.supported) {
            NSLog(@"[FrameGen] Metal setup failed, FG not supported");
        } else {
            NSLog(@"[FrameGen] Initialized successfully");
        }
    });
}

void fg_set_enabled(BOOL enabled) {
    if (!gContext.initialized) fg_init();
    // If enabling but Metal wasn't set up (was OFF at startup), try now
    if (enabled && !gContext.supported) {
        fg_try_setup_metal();
    }
    // Install the class-level CAMetalLayer swizzle when enabling at runtime.
    // This is needed when FG was OFF at startup (widgetHookMetalOnce skipped it).
    if (enabled) {
        widgetEnsureMetalSwizzle();
    }
    os_unfair_lock_lock(&gLock);  // A6
    gContext.enabled = enabled && gContext.supported;
    if (!enabled) {
        gContext.ringCount = 0;
        gContext.ringHead = 0;
    }
    os_unfair_lock_unlock(&gLock);  // A6
    NSLog(@"[FrameGen] Enabled: %d", gContext.enabled);
}

/**
 * Set up Metal pipelines on demand (called when FG is enabled after startup).
 * Safe to call multiple times — only sets up once.
 */
static void fg_try_setup_metal(void) {
    if (gContext.supported) return; // already set up
    os_unfair_lock_lock(&gLock);
    if (!gContext.supported) {
        gContext.supported = fgSetupMetal(&gContext);
        if (gContext.supported) {
            NSLog(@"[FrameGen] Metal setup completed on demand");
        } else {
            NSLog(@"[FrameGen] Metal setup failed on demand");
        }
    }
    os_unfair_lock_unlock(&gLock);
}

BOOL fg_is_enabled(void) {
    return gContext.enabled && gContext.supported;
}

BOOL fg_is_supported(void) {
    if (!gContext.initialized) fg_init();
    return gContext.supported;
}

void fg_hook_metal_layer(CAMetalLayer* layer) {
    if (!gContext.initialized) fg_init();
    // Only try Metal setup on demand if FG preference is ON.
    // When FG is OFF at startup, fg_init() intentionally skips Metal setup.
    // Do NOT set up Metal here unconditionally — it causes pipelines to be
    // created even when FG is disabled, which can interfere with rendering.
    if (!gContext.supported) {
        BOOL fgPrefEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"video.frame_generation"];
        if (fgPrefEnabled) {
            fg_try_setup_metal();
        }
    }
    // Install the class-level CAMetalLayer swizzle if not already present.
    // This is needed when FG is toggled ON at runtime (widgetHookMetalOnce
    // may have skipped it during startup because FG was OFF).
    widgetEnsureMetalSwizzle();
    NSLog(@"[FrameGen] fg_hook_metal_layer: initialized=%d supported=%d enabled=%d", gContext.initialized, gContext.supported, gContext.enabled);
}

BOOL fg_on_next_drawable(id drawable, CAMetalLayer* layer) {
    // UNCONDITIONAL: log first 5 calls, then every 30 — confirms swizzle fires at all.
    static uint64_t entryCount = 0;
    entryCount++;
    if (entryCount <= 5 || entryCount % 30 == 0) {
        NSLog(@"[FrameGen] fg_on_next_drawable ENTER #%llu enabled=%d supported=%d initialized=%d drawable=%p",
              entryCount, gContext.enabled, gContext.supported, gContext.initialized, drawable);
    }

    if (!gContext.initialized || !gContext.enabled || !gContext.supported) {
        if (entryCount <= 3) {
            NSLog(@"[FrameGen] fg_on_next_drawable: SKIP init/enabled/supported");
        }
        return NO;
    }

    FGMetalDrawable metalDrawable = (FGMetalDrawable)drawable;
    if (!metalDrawable || !metalDrawable.texture) {
        NSLog(@"[FrameGen] fg_on_next_drawable: SKIP nil drawable or texture drawable=%p", drawable);
        return NO;
    }

    os_unfair_lock_lock(&gLock);  // A6

    gContext.totalFrames++;
    double currentTime = CACurrentMediaTime();

    // A5: Calculate interp factor BEFORE updating lastFrameTime
    float interpFactor = fgCalculateInterpFactor(&gContext, currentTime);

    if (gContext.lastFrameTime > 0) {
        double dt = currentTime - gContext.lastFrameTime;
        if (dt > 0) {
            gContext.nativeFPS = 1.0 / dt;
        }
    }
    gContext.lastFrameTime = currentTime;

    if (gContext.nativeFPS < FG_MIN_NATIVE_FPS) {
        gContext.framesSkipped++;
        FGFrameBufferEntry* entry = &gContext.ringBuffer[gContext.ringHead];
        if (entry->colorTexture) entry->colorTexture = nil;
        if (entry->depthTexture) entry->depthTexture = nil;
        entry->valid = NO;
        gContext.ringHead = (gContext.ringHead + 1) % FG_RING_BUFFER_SIZE;
        if (gContext.ringCount < FG_RING_BUFFER_SIZE) gContext.ringCount++;
        os_unfair_lock_unlock(&gLock);  // A6
        if (entryCount <= 5 || gContext.framesSkipped % 30 == 0) {
            NSLog(@"[FrameGen] fg_on_next_drawable: SKIP lowFPS nativeFPS=%.1f < %d skip=%llu",
                  gContext.nativeFPS, FG_MIN_NATIVE_FPS, gContext.framesSkipped);
        }
        return NO;
    }

    fgProcessFrame(&gContext, metalDrawable);

    if (interpFactor > 0.001f && gContext.ringCount >= 2) {
        FGFrameBufferEntry* prev = fgGetPrevFrame(&gContext);
        FGFrameBufferEntry* curr = fgGetCurrFrame(&gContext);

        if (prev && curr && prev->valid && curr->valid) {
            id<MTLTexture> interpolatedTexture = fgCreateTextureCopy(&gContext, curr->colorTexture, gContext.frameCounter + 1000);
            if (interpolatedTexture) {
                if (prev->camera.valid && curr->camera.valid) {
                    fgRunReprojection(&gContext, prev, curr, interpolatedTexture, interpFactor);
                } else {
                    fgRunSimpleBlend(&gContext, prev, curr, interpolatedTexture, interpFactor);
                }
                // A1: Pass originalDrawable instead of calling nextDrawable again
                fgPresentInterpolatedFrame(&gContext, metalDrawable, interpolatedTexture);
                gContext.framesInterpolated++;
                gContext.displayFPS = gContext.nativeFPS * 2.0f;
                os_unfair_lock_unlock(&gLock);  // A6

                // Request camera capture AFTER releasing lock (fg_update_camera
                // acquires the same lock — os_unfair_lock is non-reentrant on iOS).
                fg_request_camera_capture();
                if (gContext.framesInterpolated <= 5 || gContext.framesInterpolated % 30 == 0) {
                    NSLog(@"[FrameGen] INTERPOLATED #%llu interpF=%.3f nativeFPS=%.1f ring=%d",
                          gContext.framesInterpolated, interpFactor, gContext.nativeFPS, gContext.ringCount);
                }
                return YES;
            } else {
                NSLog(@"[FrameGen] fg_on_next_drawable: FAIL createTextureCopy");
            }
        } else {
            if (entryCount <= 3) {
                NSLog(@"[FrameGen] fg_on_next_drawable: SKIP prev/curr invalid prev=%p curr=%p prevValid=%d currValid=%d ring=%d",
                      prev, curr, prev ? prev->valid : -1, curr ? curr->valid : -1, gContext.ringCount);
            }
        }
    }

    gContext.displayFPS = gContext.nativeFPS;
    os_unfair_lock_unlock(&gLock);  // A6

    // Request camera capture outside lock — see note above.
    static uint64_t logCounter = 0;
    if (++logCounter % 5 == 0) {
        NSLog(@"[FrameGen] fg_on_next_drawable: NO_INTERP total=%llu interp=%llu skip=%llu nativeFPS=%.1f ring=%d interpF=%.3f",
              gContext.totalFrames, gContext.framesInterpolated, gContext.framesSkipped,
              gContext.nativeFPS, gContext.ringCount, interpFactor);
    }
    fg_request_camera_capture();
    return NO;
}

void fg_update_camera(const FGCameraData* data) {
    if (!gContext.initialized || !data || !data->valid) {
        NSLog(@"[FrameGen] fg_update_camera: REJECTED initialized=%d data=%p valid=%d",
              gContext.initialized, data, data ? data->valid : -1);
        return;
    }

    os_unfair_lock_lock(&gLock);  // A6

    // Always store in OSM-specific camera fields (for OSMesa path)
    // This bypasses the Metal ring buffer which is empty in OSMesa mode.
    gContext.osmPrevCamera = gContext.osmLatestCamera; // shift current → prev
    gContext.osmLatestCamera.pos[0] = data->pos[0];
    gContext.osmLatestCamera.pos[1] = data->pos[1];
    gContext.osmLatestCamera.pos[2] = data->pos[2];
    gContext.osmLatestCamera.rot[0] = data->rot[0];
    gContext.osmLatestCamera.rot[1] = data->rot[1];
    memcpy(gContext.osmLatestCamera.viewMatrix, data->viewMatrix, 16 * sizeof(float));
    memcpy(gContext.osmLatestCamera.projMatrix, data->projMatrix, 16 * sizeof(float));
    fgMatrixInverse4x4(data->viewMatrix, gContext.osmLatestCamera.invViewMatrix);
    fgMatrixInverse4x4(data->projMatrix, gContext.osmLatestCamera.invProjMatrix);
    gContext.osmLatestCamera.fov = data->fov;
    gContext.osmLatestCamera.width = data->width;
    gContext.osmLatestCamera.height = data->height;
    gContext.osmLatestCamera.valid = YES;
    gContext.osmLatestCamera.timestamp = CACurrentMediaTime();

    // Also try Metal ring buffer (for Metal path)
    FGFrameBufferEntry* curr = fgGetCurrFrame(&gContext);
    if (curr && curr->valid) {
        curr->camera.pos[0] = data->pos[0];
        curr->camera.pos[1] = data->pos[1];
        curr->camera.pos[2] = data->pos[2];
        curr->camera.rot[0] = data->rot[0];
        curr->camera.rot[1] = data->rot[1];
        memcpy(curr->camera.viewMatrix, data->viewMatrix, 16 * sizeof(float));
        memcpy(curr->camera.projMatrix, data->projMatrix, 16 * sizeof(float));
        fgMatrixInverse4x4(data->viewMatrix, curr->camera.invViewMatrix);
        fgMatrixInverse4x4(data->projMatrix, curr->camera.invProjMatrix);
        curr->camera.fov = data->fov;
        curr->camera.width = data->width;
        curr->camera.height = data->height;
        curr->camera.valid = YES;
        curr->camera.timestamp = CACurrentMediaTime();
    }

    static uint64_t camLog = 0;
    if (camLog < 5 || ++camLog % 10 == 0) {
        NSLog(@"[FrameGen] fg_update_camera: pos=[%.1f,%.1f,%.1f] rot=[%.1f,%.1f] fov=%.1f",
              data->pos[0], data->pos[1], data->pos[2], data->rot[0], data->rot[1], data->fov);
        camLog++;
    }
    os_unfair_lock_unlock(&gLock);  // A6
}

FGStats fg_get_stats(void) {
    os_unfair_lock_lock(&gLock);  // A6
    FGStats stats = {0};
    stats.framesInterpolated = gContext.framesInterpolated;
    stats.framesSkipped = gContext.framesSkipped;
    stats.totalFrames = gContext.totalFrames;
    stats.nativeFPS = gContext.nativeFPS;
    stats.displayFPS = gContext.displayFPS;
    stats.isActive = gContext.enabled && gContext.supported;
    stats.isSupported = gContext.supported;
    os_unfair_lock_unlock(&gLock);  // A6
    return stats;
}

FGCameraData* fg_get_camera_data(void) {
    os_unfair_lock_lock(&gLock);  // A6
    FGFrameBufferEntry* curr = fgGetCurrFrame(&gContext);
    FGCameraData* result = curr ? (FGCameraData*)&curr->camera : NULL;
    os_unfair_lock_unlock(&gLock);  // A6
    return result;
}

// MARK: - Private Implementation

static BOOL fgSetupMetal(FGContext* ctx) {
    ctx->device = MTLCreateSystemDefaultDevice();
    if (!ctx->device) return NO;

    ctx->commandQueue = [ctx->device newCommandQueue];
    if (!ctx->commandQueue) return NO;

    NSError* error = nil;

    // Compile reprojection shader
    id<MTLLibrary> library = [ctx->device newLibraryWithSource:[NSString stringWithUTF8String:kReprojectionShader] options:nil error:&error];
    if (!library) {
        NSLog(@"[FrameGen] Failed to compile reprojection shader: %@", error);
        ctx->reprojectionPipeline = nil;
    } else {
        id<MTLFunction> reprojectionFunction = [library newFunctionWithName:@"reprojectionKernel"];
        if (reprojectionFunction) {
            ctx->reprojectionPipeline = [ctx->device newComputePipelineStateWithFunction:reprojectionFunction error:&error];
            if (!ctx->reprojectionPipeline) {
                NSLog(@"[FrameGen] Failed to create reprojection pipeline: %@", error);
            } else {
                NSLog(@"[FrameGen] Reprojection pipeline ready (threadgroup width: %lu)", (unsigned long)ctx->reprojectionPipeline.threadExecutionWidth);
            }
        }
    }

    // Compile simple blend shader
    id<MTLLibrary> blendLib = [ctx->device newLibraryWithSource:[NSString stringWithUTF8String:kSimpleBlendShader] options:nil error:&error];
    if (!blendLib) {
        NSLog(@"[FrameGen] Failed to compile simple blend shader: %@", error);
        return NO;
    }
    id<MTLFunction> blendFunction = [blendLib newFunctionWithName:@"simpleBlendKernel"];
    if (!blendFunction) return NO;
    ctx->blendPipeline = [ctx->device newComputePipelineStateWithFunction:blendFunction error:&error];
    if (!ctx->blendPipeline) {
        NSLog(@"[FrameGen] Failed to create blend pipeline: %@", error);
        return NO;
    }

    // A7: CameraData buffer now includes inverse matrices (6 matrices + viewportSize + interpFactor = 400 bytes)
    // Layout: view(16) + proj(16) + prevView(16) + prevProj(16) + invView(16) + invProj(16) + viewportSize(2) + interpFactor(1)
    size_t bufferSize = sizeof(float) * 16 * 6 + sizeof(float) * 2 + sizeof(float);
    ctx->cameraDataBuffer = [ctx->device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    if (!ctx->cameraDataBuffer) return NO;

    // Compile prediction shader (extrapolate forward from current frame)
    id<MTLLibrary> predLib = [ctx->device newLibraryWithSource:[NSString stringWithUTF8String:kPredictionShader] options:nil error:&error];
    if (!predLib) {
        NSLog(@"[FrameGen] Failed to compile prediction shader: %@", error);
    } else {
        id<MTLFunction> predFunc = [predLib newFunctionWithName:@"predictionKernel"];
        if (predFunc) {
            ctx->predictionPipeline = [ctx->device newComputePipelineStateWithFunction:predFunc error:&error];
            if (!ctx->predictionPipeline) {
                NSLog(@"[FrameGen] Failed to create prediction pipeline: %@", error);
            } else {
                NSLog(@"[FrameGen] Prediction pipeline ready (threadgroup width: %lu)", (unsigned long)ctx->predictionPipeline.threadExecutionWidth);
            }
        }
    }

    NSLog(@"[FrameGen] Metal setup complete (reprojection: %@, blend: %@, prediction: %@)",
          ctx->reprojectionPipeline ? @"YES" : @"NO (will use blend fallback)",
          ctx->blendPipeline ? @"YES" : @"NO",
          ctx->predictionPipeline ? @"YES" : @"NO");
    return YES;
}

static void fgCleanupMetal(FGContext* ctx) {
    for (int i = 0; i < FG_RING_BUFFER_SIZE; i++) {
        ctx->ringBuffer[i].colorTexture = nil;
        ctx->ringBuffer[i].depthTexture = nil;
        ctx->ringBuffer[i].valid = NO;
    }
    ctx->reprojectionPipeline = nil;
    ctx->blendPipeline = nil;
    ctx->predictionPipeline = nil;
    ctx->cameraDataBuffer = nil;
    ctx->placeholderDepth = nil;  // A2
    ctx->osmCachedUploadTex0 = nil;
    ctx->osmCachedUploadTex1 = nil;
    ctx->osmCachedOutputTex = nil;
    ctx->osmCachedTexWidth = 0;
    ctx->osmCachedTexHeight = 0;
    ctx->commandQueue = nil;
    ctx->device = nil;
}

static void fgProcessFrame(FGContext* ctx, FGMetalDrawable drawable) {
    FGFrameBufferEntry* entry = &ctx->ringBuffer[ctx->ringHead];

    if (entry->colorTexture) entry->colorTexture = nil;
    if (entry->depthTexture) entry->depthTexture = nil;

    entry->colorTexture = fgCreateTextureCopy(ctx, drawable.texture, ctx->frameCounter);

    // A2: Cache placeholder depth texture (created once, reused)
    if (!ctx->placeholderDepth ||
        ctx->placeholderDepth.width != drawable.texture.width ||
        ctx->placeholderDepth.height != drawable.texture.height) {
        ctx->placeholderDepth = fgCreatePlaceholderDepth(ctx, drawable.texture.width, drawable.texture.height);
    }
    entry->depthTexture = ctx->placeholderDepth;

    entry->frameIndex = ctx->frameCounter;
    entry->timestamp = CACurrentMediaTime();
    entry->valid = YES;

    // A9: Propagate camera data from previous frame to new entry.
    // Camera data arrives asynchronously via JNI (fg_update_camera) and may
    // update the CURRENT frame. When we advance ringHead, the new entry should
    // inherit the previous entry's camera data as a starting point.
    int prevIdx = (ctx->ringHead - 1 + FG_RING_BUFFER_SIZE) % FG_RING_BUFFER_SIZE;
    if (ctx->ringBuffer[prevIdx].camera.valid) {
        entry->camera = ctx->ringBuffer[prevIdx].camera;
        entry->camera.timestamp = entry->timestamp;  // update timestamp
    } else {
        entry->camera.valid = NO;
    }

    ctx->frameCounter++;
    ctx->ringHead = (ctx->ringHead + 1) % FG_RING_BUFFER_SIZE;
    if (ctx->ringCount < FG_RING_BUFFER_SIZE) ctx->ringCount++;
}

static id<MTLTexture> fgCreateTextureCopy(FGContext* ctx, id<MTLTexture> src, uint64_t frameIndex) {
    if (!src) return nil;

    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:src.pixelFormat
                                                                                     width:src.width
                                                                                    height:src.height
                                                                                 mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModePrivate;

    id<MTLTexture> dst = [ctx->device newTextureWithDescriptor:desc];
    if (!dst) return nil;

    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [cmdBuf blitCommandEncoder];
    [blitEncoder copyFromTexture:src sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(src.width, src.height, 1)
                      toTexture:dst destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitEncoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    return dst;
}

// A2: Create placeholder depth texture (all 1.0 = far plane)
static id<MTLTexture> fgCreatePlaceholderDepth(FGContext* ctx, int width, int height) {
    if (!ctx->device || width <= 0 || height <= 0) return nil;

    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                                                     width:width
                                                                                    height:height
                                                                                 mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModePrivate;

    id<MTLTexture> tex = [ctx->device newTextureWithDescriptor:desc];
    if (!tex) return nil;

    // Fill with 1.0 (far plane) via GPU blit from a shared buffer
    int pixelCount = width * height;
    size_t dataSize = pixelCount * sizeof(float);
    id<MTLBuffer> fillBuffer = [ctx->device newBufferWithLength:dataSize options:MTLResourceStorageModeShared];
    if (fillBuffer) {
        float* bufPtr = (float*)fillBuffer.contents;
        for (int i = 0; i < pixelCount; i++) {
            bufPtr[i] = 1.0f;
        }
        id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
        [blit copyFromBuffer:fillBuffer sourceOffset:0 sourceBytesPerRow:width * sizeof(float) sourceBytesPerImage:dataSize sourceSize:MTLSizeMake(width, height, 1)
                    toTexture:tex destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
        [blit endEncoding];
        [cmdBuf commit];
        [cmdBuf waitUntilCompleted];
    }
    return tex;
}

static void fgRunReprojection(FGContext* ctx, FGFrameBufferEntry* prev, FGFrameBufferEntry* curr, id<MTLTexture> output, float interpFactor) {
    if (!ctx->reprojectionPipeline) {
        fgRunSimpleBlend(ctx, prev, curr, output, interpFactor);
        return;
    }

    fgUpdateCameraDataBuffer(ctx, &prev->camera, &curr->camera, interpFactor);

    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:ctx->reprojectionPipeline];
    [encoder setTexture:prev->colorTexture atIndex:0];
    [encoder setTexture:curr->colorTexture atIndex:1];
    // A2: Use placeholder depth if nil
    id<MTLTexture> prevDepthTex = prev->depthTexture ? prev->depthTexture : ctx->placeholderDepth;
    id<MTLTexture> currDepthTex = curr->depthTexture ? curr->depthTexture : ctx->placeholderDepth;
    [encoder setTexture:prevDepthTex atIndex:2];
    [encoder setTexture:currDepthTex atIndex:3];
    [encoder setTexture:output atIndex:4];
    [encoder setBuffer:ctx->cameraDataBuffer offset:0 atIndex:0];

    NSUInteger threadgroupWidth = ctx->reprojectionPipeline.threadExecutionWidth;
    NSUInteger threadgroupHeight = ctx->reprojectionPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
    MTLSize gridSize = MTLSizeMake(
        (output.width + threadgroupWidth - 1) / threadgroupWidth,
        (output.height + threadgroupHeight - 1) / threadgroupHeight,
        1
    );
    [encoder dispatchThreadgroups:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];
}

static void fgRunSimpleBlend(FGContext* ctx, FGFrameBufferEntry* prev, FGFrameBufferEntry* curr, id<MTLTexture> output, float interpFactor) {
    if (!ctx->blendPipeline) return;

    float* bufferPtr = (float*)ctx->cameraDataBuffer.contents;
    bufferPtr[0] = interpFactor;

    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:ctx->blendPipeline];
    [encoder setTexture:prev->colorTexture atIndex:0];
    [encoder setTexture:curr->colorTexture atIndex:1];
    [encoder setTexture:output atIndex:2];
    [encoder setBuffer:ctx->cameraDataBuffer offset:0 atIndex:0];

    NSUInteger threadgroupWidth = ctx->blendPipeline.threadExecutionWidth;
    NSUInteger threadgroupHeight = ctx->blendPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
    MTLSize gridSize = MTLSizeMake(
        (output.width + threadgroupWidth - 1) / threadgroupWidth,
        (output.height + threadgroupHeight - 1) / threadgroupHeight,
        1
    );
    [encoder dispatchThreadgroups:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];
}

static FGFrameBufferEntry* fgGetPrevFrame(FGContext* ctx) {
    if (ctx->ringCount < 2) return NULL;
    int prevIdx = (ctx->ringHead - 2 + FG_RING_BUFFER_SIZE) % FG_RING_BUFFER_SIZE;
    return &ctx->ringBuffer[prevIdx];
}

static FGFrameBufferEntry* fgGetCurrFrame(FGContext* ctx) {
    if (ctx->ringCount < 1) return NULL;
    int currIdx = (ctx->ringHead - 1 + FG_RING_BUFFER_SIZE) % FG_RING_BUFFER_SIZE;
    return &ctx->ringBuffer[currIdx];
}

// A7: Upload precomputed inverse matrices to GPU buffer
static void fgUpdateCameraDataBuffer(FGContext* ctx, FGInternalCameraData* prevCam, FGInternalCameraData* currCam, float interpFactor) {
    float* bufferPtr = (float*)ctx->cameraDataBuffer.contents;
    // Layout: view(16) + proj(16) + prevView(16) + prevProj(16) + invView(16) + invProj(16) + viewportSize(2) + interpFactor(1)
    memcpy(bufferPtr,       currCam->viewMatrix,    16 * sizeof(float));  // [0..15]
    memcpy(bufferPtr + 16,  currCam->projMatrix,    16 * sizeof(float));  // [16..31]
    memcpy(bufferPtr + 32,  prevCam->viewMatrix,    16 * sizeof(float));  // [32..47]
    memcpy(bufferPtr + 48,  prevCam->projMatrix,    16 * sizeof(float));  // [48..63]
    memcpy(bufferPtr + 64,  currCam->invViewMatrix, 16 * sizeof(float));  // [64..79]
    memcpy(bufferPtr + 80,  currCam->invProjMatrix, 16 * sizeof(float));  // [80..95]
    bufferPtr[96] = (float)currCam->width;                                // viewportSize.x
    bufferPtr[97] = (float)currCam->height;                               // viewportSize.y
    bufferPtr[98] = interpFactor;                                          // interpFactor
}

// A5: Interpolation factor calculated BEFORE lastFrameTime is updated
static float fgCalculateInterpFactor(FGContext* ctx, double currentTime) {
    if (ctx->nativeFPS <= 0 || ctx->lastFrameTime <= 0) return 0.5f;

    double nativeFrameTime = 1.0 / ctx->nativeFPS;
    double timeSinceLastFrame = currentTime - ctx->lastFrameTime;

    float factor = (float)(timeSinceLastFrame / nativeFrameTime);
    return fminf(fmaxf(factor, 0.0f), FG_MAX_INTERP_FACTOR);
}

// A1: Blit interpolated texture onto originalDrawable's texture.
// The swizzle returns the original drawable to the renderer, which presents it.
// We do NOT call presentDrawable here — the renderer handles presentation.
static void fgPresentInterpolatedFrame(FGContext* ctx, id<CAMetalDrawable> originalDrawable, id<MTLTexture> interpolatedTexture) {
    if (!originalDrawable || !originalDrawable.texture) return;

    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [cmdBuf blitCommandEncoder];
    [blitEncoder copyFromTexture:interpolatedTexture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(interpolatedTexture.width, interpolatedTexture.height, 1)
                      toTexture:originalDrawable.texture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitEncoder endEncoding];
    [cmdBuf commit];
    // No presentDrawable — the renderer will present the originalDrawable
}

// MARK: - OSMesa Integration (Phase 1+2+3)
// CPU-side frame blending with camera-based motion reprojection for OSMesa/Zink.
//
// Phase 1: NEON SIMD blend + grow-only buffer reuse (no malloc/free per frame)
// Phase 2: Timestamp-based interpolation factor (not hardcoded 50/50)
// Phase 3: Per-pixel camera motion reprojection using view/proj matrices
//
// Flow: store frame → compute interp factor → reproject prev→curr using camera → blend → return

#include <arm_neon.h>

#define FG_OSM_RING_SIZE 3

typedef struct {
    void*   pixels;       // RGBA pixel data (grow-only, never freed until reuse)
    uint32_t capacity;    // allocated size in bytes
    uint32_t width;
    uint32_t height;
    double  timestamp;
    // Camera data copied from Metal ring buffer (via fg_update_camera)
    float   viewMatrix[16];
    float   projMatrix[16];
    float   invViewMatrix[16];
    float   invProjMatrix[16];
    float   pos[3];
    float   rot[2];
    float   fov;
    BOOL    hasCamera;
    BOOL    valid;
} FGOSMEntry;

static struct {
    FGOSMEntry ring[FG_OSM_RING_SIZE];
    int head;
    int count;
} gOSMRing;

// MARK: - NEON SIMD Blend (Phase 1)

// out = curr * (1-t) + prev * t  (direction matches Metal shader: mix(curr, prev, t))
// Processes 8 pixels per iteration using ARM NEON.
// v2: Processes all 4 channels in a single pass for better cache utilization.
static void fg_neon_blend(const uint8_t* curr, const uint8_t* prev, uint8_t* out,
                           size_t numPixels, float t) {
    const float invT = 1.0f - t;
    const float32x4_t vT = vdupq_n_f32(t);
    const float32x4_t vInvT = vdupq_n_f32(invT);
    size_t i = 0;

    // NEON path: 8 pixels (32 bytes) per iteration
    for (; i + 8 <= numPixels; i += 8) {
        // De-interleave RGBA channels from both inputs (8 pixels = 32 bytes each)
        uint8x8x4_t c4 = vld4_u8(curr + i * 4);
        uint8x8x4_t p4 = vld4_u8(prev + i * 4);

        // Process all 4 channels using the same pattern
        uint8x8x4_t o4;
        for (int ch = 0; ch < 4; ch++) {
            uint16x8_t c16 = vmovl_u8(c4.val[ch]);
            uint16x8_t p16 = vmovl_u8(p4.val[ch]);

            // Low 4 pixels
            float32x4_t cLo = vcvtq_f32_u32(vmovl_u16(vget_low_u16(c16)));
            float32x4_t pLo = vcvtq_f32_u32(vmovl_u16(vget_low_u16(p16)));
            float32x4_t rLo = vmlaq_f32(vmulq_f32(cLo, vInvT), pLo, vT);

            // High 4 pixels
            float32x4_t cHi = vcvtq_f32_u32(vmovl_u16(vget_high_u16(c16)));
            float32x4_t pHi = vcvtq_f32_u32(vmovl_u16(vget_high_u16(p16)));
            float32x4_t rHi = vmlaq_f32(vmulq_f32(cHi, vInvT), pHi, vT);

            // Pack back to uint8
            uint16x4_t r16Lo = vmovn_u32(vcvtq_u32_f32(rLo));
            uint16x4_t r16Hi = vmovn_u32(vcvtq_u32_f32(rHi));
            o4.val[ch] = vmovn_u16(vcombine_u16(r16Lo, r16Hi));
        }

        // Re-interleave RGBA and store
        vst4_u8(out + i * 4, o4);
    }

    // Scalar tail
    for (; i < numPixels; i++) {
        size_t b = i * 4;
        out[b]     = (uint8_t)(curr[b]     * invT + prev[b]     * t);
        out[b + 1] = (uint8_t)(curr[b + 1] * invT + prev[b + 1] * t);
        out[b + 2] = (uint8_t)(curr[b + 2] * invT + prev[b + 2] * t);
        out[b + 3] = (uint8_t)(curr[b + 3] * invT + prev[b + 3] * t);
    }
}

// MARK: - GPU Reprojection for OSMesa frames

// Upload raw RGBA uint8 pixel buffer to a Metal texture.
// Uses cached texture when possible (avoids per-frame alloc).
static id<MTLTexture> fgUploadPixelsToTexture(FGContext* ctx, const uint8_t* pixels,
                                               uint32_t w, uint32_t h, bool useCache) {
    if (!ctx->device || !pixels || w == 0 || h == 0) return nil;
    id<MTLTexture> tex;
    if (useCache && ctx->osmCachedUploadTex0
        && ctx->osmCachedTexWidth == w && ctx->osmCachedTexHeight == h) {
        tex = ctx->osmCachedUploadTex0;
    } else {
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                         width:w height:h mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead;
        desc.storageMode = MTLStorageModeShared;
        tex = [ctx->device newTextureWithDescriptor:desc];
        if (useCache) {
            ctx->osmCachedUploadTex0 = tex;
            ctx->osmCachedTexWidth = w;
            ctx->osmCachedTexHeight = h;
        }
    }
    if (tex) {
        [tex replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:pixels bytesPerRow:w * 4];
    }
    return tex;
}

// Create output texture for GPU reprojection (shared storage for CPU readback).
// Uses cached texture when possible (avoids per-frame alloc).
static id<MTLTexture> fgCreateOSMOutputTexture(FGContext* ctx, uint32_t w, uint32_t h, bool useCache) {
    if (!ctx->device || w == 0 || h == 0) return nil;
    if (useCache && ctx->osmCachedOutputTex
        && ctx->osmCachedTexWidth == w && ctx->osmCachedTexHeight == h) {
        return ctx->osmCachedOutputTex;
    }
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                     width:w height:h mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModeShared;
    id<MTLTexture> tex = [ctx->device newTextureWithDescriptor:desc];
    if (useCache) {
        ctx->osmCachedOutputTex = tex;
        ctx->osmCachedTexWidth = w;
        ctx->osmCachedTexHeight = h;
    }
    return tex;
}

// Populate cameraDataBuffer with matrices from FGOSMEntry for the Metal shader.
// Layout matches CameraData struct in kReprojectionShader:
//   view(16) + proj(16) + prevView(16) + prevProj(16) + invView(16) + invProj(16) + viewportSize(2) + interpFactor(1)
static void fgUpdateCameraDataBufferForOSM(FGContext* ctx, FGOSMEntry* prev, FGOSMEntry* curr, float interpFactor) {
    float* buf = (float*)ctx->cameraDataBuffer.contents;
    int off = 0;
    memcpy(buf + off, curr->viewMatrix, 16 * sizeof(float));   off += 16;
    memcpy(buf + off, curr->projMatrix, 16 * sizeof(float));   off += 16;
    memcpy(buf + off, prev->viewMatrix, 16 * sizeof(float));   off += 16;
    memcpy(buf + off, prev->projMatrix, 16 * sizeof(float));   off += 16;
    memcpy(buf + off, curr->invViewMatrix, 16 * sizeof(float)); off += 16;
    memcpy(buf + off, curr->invProjMatrix, 16 * sizeof(float)); off += 16;
    buf[off] = (float)curr->width;
    buf[off + 1] = (float)curr->height;
    buf[off + 2] = interpFactor;
}

// Upload OSMesa frames to GPU, run reprojection shader, readback result to CPU buffer.
// Returns true on success, false on failure (caller should present raw frame).
// Uses cached Metal textures to avoid per-frame alloc overhead.
static bool fgOSMUploadAndReproject(FGContext* ctx, FGOSMEntry* prev, FGOSMEntry* curr,
                                     uint8_t* outPixels, float interpFactor) {
    if (!ctx->reprojectionPipeline || !prev->hasCamera || !curr->hasCamera) return false;

    // 1. Upload prev frame as Metal texture (uses cached slot 0)
    id<MTLTexture> prevTex = fgUploadPixelsToTexture(ctx, (const uint8_t*)prev->pixels, prev->width, prev->height, true);

    // 2. Upload curr frame as Metal texture (uses cached slot 1)
    id<MTLTexture> currTex;
    if (ctx->osmCachedUploadTex1 && ctx->osmCachedTexWidth == curr->width && ctx->osmCachedTexHeight == curr->height) {
        currTex = ctx->osmCachedUploadTex1;
    } else {
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                         width:curr->width height:curr->height mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead;
        desc.storageMode = MTLStorageModeShared;
        currTex = [ctx->device newTextureWithDescriptor:desc];
        ctx->osmCachedUploadTex1 = currTex;
    }
    if (currTex) {
        [currTex replaceRegion:MTLRegionMake2D(0, 0, curr->width, curr->height) mipmapLevel:0
                     withBytes:curr->pixels bytesPerRow:curr->width * 4];
    }

    // 3. Get cached output texture
    id<MTLTexture> outTex = fgCreateOSMOutputTexture(ctx, curr->width, curr->height, true);
    if (!prevTex || !currTex || !outTex) return false;

    // 2. Populate camera uniforms
    fgUpdateCameraDataBufferForOSM(ctx, prev, curr, interpFactor);

    // 3. Dispatch reprojection compute shader on GPU
    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:ctx->reprojectionPipeline];
    [encoder setTexture:prevTex atIndex:0];
    [encoder setTexture:currTex atIndex:1];
    // Use placeholder depth (OSMesa has no depth buffer)
    id<MTLTexture> depthTex = ctx->placeholderDepth;
    [encoder setTexture:depthTex atIndex:2];
    [encoder setTexture:depthTex atIndex:3];
    [encoder setTexture:outTex atIndex:4];
    [encoder setBuffer:ctx->cameraDataBuffer offset:0 atIndex:0];

    NSUInteger threadgroupWidth = ctx->reprojectionPipeline.threadExecutionWidth;
    NSUInteger threadgroupHeight = ctx->reprojectionPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
    MTLSize gridSize = MTLSizeMake(
        (curr->width + threadgroupWidth - 1) / threadgroupWidth,
        (curr->height + threadgroupHeight - 1) / threadgroupHeight,
        1);
    [encoder dispatchThreadgroups:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // 4. Readback: GPU texture → CPU buffer for CGImage presentation
    [outTex getBytes:outPixels bytesPerRow:curr->width * 4
         fromRegion:MTLRegionMake2D(0, 0, curr->width, curr->height) mipmapLevel:0];

    return true;
}

// MARK: - Predictive Frame Generation (extrapolate forward)

// Populate PredictionData buffer for the prediction shader.
// Layout matches PredictionData struct in kPredictionShader:
//   currView(16) + currProj(16) + prevView(16) + prevProj(16) + invView(16) + invProj(16) + viewportSize(2) + predictFactor(1)
static void fgUpdatePredictionDataBuffer(FGContext* ctx, FGOSMEntry* curr, FGOSMEntry* prev, float predictFactor) {
    float* buf = (float*)ctx->cameraDataBuffer.contents;
    int off = 0;
    memcpy(buf + off, curr->viewMatrix, 16 * sizeof(float));    off += 16;
    memcpy(buf + off, curr->projMatrix, 16 * sizeof(float));    off += 16;
    memcpy(buf + off, prev->viewMatrix, 16 * sizeof(float));    off += 16;
    memcpy(buf + off, prev->projMatrix, 16 * sizeof(float));    off += 16;
    memcpy(buf + off, curr->invViewMatrix, 16 * sizeof(float)); off += 16;
    memcpy(buf + off, curr->invProjMatrix, 16 * sizeof(float)); off += 16;
    buf[off] = (float)curr->width;
    buf[off + 1] = (float)curr->height;
    buf[off + 2] = predictFactor;
}

// Predict the NEXT frame by extrapolating forward from the current frame.
// Uses camera motion delta (prev→curr) to predict where pixels will move.
// This is different from interpolation: we only need the current frame + camera motion.
// predictFactor: 0=current frame, 1=one frame ahead, 2=two frames ahead, etc.
// Uses cached Metal textures to avoid per-frame alloc overhead.
static bool fgOSMPredictNextFrame(FGContext* ctx, FGOSMEntry* curr, FGOSMEntry* prev,
                                   uint8_t* outPixels, float predictFactor) {
    if (!ctx->predictionPipeline || !curr->hasCamera || !prev->hasCamera) return false;

    // 1. Upload current frame as Metal texture (cached)
    id<MTLTexture> currTex = fgUploadPixelsToTexture(ctx, (const uint8_t*)curr->pixels, curr->width, curr->height, true);
    id<MTLTexture> outTex  = fgCreateOSMOutputTexture(ctx, curr->width, curr->height, true);
    if (!currTex || !outTex) return false;

    // 2. Populate prediction uniforms
    fgUpdatePredictionDataBuffer(ctx, curr, prev, predictFactor);

    // 3. Dispatch prediction compute shader on GPU
    id<MTLCommandBuffer> cmdBuf = [ctx->commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:ctx->predictionPipeline];
    [encoder setTexture:currTex atIndex:0];
    // Use placeholder depth (OSMesa has no depth buffer)
    id<MTLTexture> depthTex = ctx->placeholderDepth;
    [encoder setTexture:depthTex atIndex:1];
    [encoder setTexture:outTex atIndex:2];
    [encoder setBuffer:ctx->cameraDataBuffer offset:0 atIndex:0];

    NSUInteger threadgroupWidth = ctx->predictionPipeline.threadExecutionWidth;
    NSUInteger threadgroupHeight = ctx->predictionPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
    MTLSize gridSize = MTLSizeMake(
        (curr->width + threadgroupWidth - 1) / threadgroupWidth,
        (curr->height + threadgroupHeight - 1) / threadgroupHeight,
        1);
    [encoder dispatchThreadgroups:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // 4. Readback: GPU texture → CPU buffer for CGImage presentation
    [outTex getBytes:outPixels bytesPerRow:curr->width * 4
         fromRegion:MTLRegionMake2D(0, 0, curr->width, curr->height) mipmapLevel:0];

    return true;
}

// MARK: - OSMesa Capture & Interpolate

// Return values:
//   FG_OSM_RAW    = 0: present raw frame without interpolation
//   FG_OSM_INTERP = 1: present interpolated/blended frame
#define FG_OSM_RAW    (0)
#define FG_OSM_INTERP (1)

// Camera rotation threshold for detecting significant camera change (radians)
// ~0.5 rad ≈ 28.6 degrees — only trigger on teleportation / big jumps, NOT normal mouse movement.
#define FG_CAMERA_ROT_THRESHOLD 0.5f

int fg_capture_frame_from_osmesa(void* pixelData, uint32_t width, uint32_t height) {
    if (!gContext.initialized) {
        fg_init();
    }
    if (!gContext.enabled || !gContext.supported) {
        return FG_OSM_RAW;
    }
    if (!pixelData || width == 0 || height == 0) return FG_OSM_RAW;

    gContext.totalFrames++;
    double currentTime = CACurrentMediaTime();

    // Use OSMesa-specific timer (NOT gContext.lastFrameTime which is shared with Metal path)
    double dt = 0;
    if (gContext.osmLastFrameTime > 0) {
        dt = currentTime - gContext.osmLastFrameTime;
        if (dt > 0 && dt < 2.0) {
            gContext.osmNativeFPS = (float)(1.0 / dt);
        }
    }
    gContext.osmLastFrameTime = currentTime;

    // Update FPS averaging (sliding window average for stability)
    if (dt > 0 && dt < 2.0) {
        gContext.osmFrameTimes[gContext.osmFrameTimeIdx] = (float)dt;
        gContext.osmFrameTimeIdx = (gContext.osmFrameTimeIdx + 1) % 8;
        if (gContext.osmFrameTimeCount < 8) gContext.osmFrameTimeCount++;

        float avgDt = 0;
        for (int i = 0; i < gContext.osmFrameTimeCount; i++) {
            avgDt += gContext.osmFrameTimes[i];
        }
        avgDt /= gContext.osmFrameTimeCount;
        gContext.osmAvgFPS = (avgDt > 0) ? (1.0f / avgDt) : 0;
    }

    float effectiveNativeFPS = gContext.osmAvgFPS;

    // === DECISION: Should we interpolate this frame? ===
    // If FPS is out of reasonable range, present raw frame without interpolation
    if ((effectiveNativeFPS < FG_MIN_NATIVE_FPS && gContext.osmFrameTimeCount >= 3) ||
        effectiveNativeFPS > 45.0f) {
        gContext.displayFPS = effectiveNativeFPS;
        os_unfair_lock_lock(&gLock);
        FGOSMEntry* entry = &gOSMRing.ring[gOSMRing.head];
        uint32_t frameBytes = width * height * 4;
        if (entry->capacity < frameBytes) {
            entry->pixels = reallocf(entry->pixels, frameBytes);
            entry->capacity = frameBytes ? frameBytes : 0;
        }
        if (entry->pixels) {
            memcpy(entry->pixels, pixelData, frameBytes);
        }
        entry->width = width;
        entry->height = height;
        entry->timestamp = currentTime;
        entry->hasCamera = NO;
        entry->valid = (entry->pixels != NULL);
        gOSMRing.head = (gOSMRing.head + 1) % FG_OSM_RING_SIZE;
        if (gOSMRing.count < FG_OSM_RING_SIZE) gOSMRing.count++;
        os_unfair_lock_unlock(&gLock);

        fg_request_camera_capture();
        return FG_OSM_RAW;
    }

    os_unfair_lock_lock(&gLock);

    // --- Camera change detection: compare current camera with previous OSM entry ---
    bool cameraChanged = false;
    if (gOSMRing.count >= 1 && gContext.osmLatestCamera.valid && gContext.osmPrevCamera.valid) {
        int prevIdx = (gOSMRing.head - 1 + FG_OSM_RING_SIZE) % FG_OSM_RING_SIZE;
        FGOSMEntry* prevEntry = &gOSMRing.ring[prevIdx];
        if (prevEntry->valid && prevEntry->hasCamera) {
            float dyaw = fabsf(gContext.osmLatestCamera.rot[0] - prevEntry->rot[0]);
            float dpitch = fabsf(gContext.osmLatestCamera.rot[1] - prevEntry->rot[1]);
            if (dyaw > M_PI) dyaw = 2.0f * M_PI - dyaw;
            if (dyaw > FG_CAMERA_ROT_THRESHOLD || dpitch > FG_CAMERA_ROT_THRESHOLD) {
                cameraChanged = true;
            }
        }
    }

    if (cameraChanged) {
        gOSMRing.count = 0;
        gOSMRing.head = 0;
        gContext.displayFPS = effectiveNativeFPS;
        static uint64_t camLog = 0;
        if (camLog < 5 || ++camLog % 30 == 0) {
            NSLog(@"[FrameGen] OSM_CAM_CHANGE ring cleared, presenting raw frame");
        }
        os_unfair_lock_unlock(&gLock);
        fg_request_camera_capture();
        return FG_OSM_RAW;
    }

    // --- Store frame in ring buffer ---
    FGOSMEntry* entry = &gOSMRing.ring[gOSMRing.head];
    uint32_t frameBytes = width * height * 4;
    if (entry->capacity < frameBytes) {
        entry->pixels = reallocf(entry->pixels, frameBytes);
        entry->capacity = frameBytes ? frameBytes : 0;
    }
    if (entry->pixels) {
        memcpy(entry->pixels, pixelData, frameBytes);
    }
    entry->width = width;
    entry->height = height;
    entry->timestamp = currentTime;

    bool hasRealCamera = gContext.osmLatestCamera.valid &&
        (gContext.osmLatestCamera.pos[0] != 0.0f || gContext.osmLatestCamera.pos[1] != 0.0f ||
         gContext.osmLatestCamera.pos[2] != 0.0f ||
         gContext.osmLatestCamera.rot[0] != 0.0f || gContext.osmLatestCamera.rot[1] != 0.0f);
    if (hasRealCamera) {
        entry->hasCamera = YES;
        memcpy(entry->viewMatrix, gContext.osmLatestCamera.viewMatrix, 16 * sizeof(float));
        memcpy(entry->projMatrix, gContext.osmLatestCamera.projMatrix, 16 * sizeof(float));
        memcpy(entry->invViewMatrix, gContext.osmLatestCamera.invViewMatrix, 16 * sizeof(float));
        memcpy(entry->invProjMatrix, gContext.osmLatestCamera.invProjMatrix, 16 * sizeof(float));
        memcpy(entry->pos, gContext.osmLatestCamera.pos, 3 * sizeof(float));
        memcpy(entry->rot, gContext.osmLatestCamera.rot, 2 * sizeof(float));
        entry->fov = gContext.osmLatestCamera.fov;
    } else {
        entry->hasCamera = NO;
    }
    entry->valid = (entry->pixels != NULL);

    gOSMRing.head = (gOSMRing.head + 1) % FG_OSM_RING_SIZE;
    if (gOSMRing.count < FG_OSM_RING_SIZE) gOSMRing.count++;

    int result = FG_OSM_RAW;

    if (gOSMRing.count >= 2) {
        int currIdx = (gOSMRing.head - 1 + FG_OSM_RING_SIZE) % FG_OSM_RING_SIZE;
        int prevIdx = (gOSMRing.head - 2 + FG_OSM_RING_SIZE) % FG_OSM_RING_SIZE;
        FGOSMEntry* curr = &gOSMRing.ring[currIdx];
        FGOSMEntry* prev = &gOSMRing.ring[prevIdx];

        if (curr->valid && prev->valid &&
            curr->width == prev->width && curr->height == prev->height) {

            gContext.osmBlendStartTime = CACurrentMediaTime();

            // High performance NEON SIMD temporal blend (<0.5ms on CPU, no GPU sync stalls)
            // Blends prev and curr frames smoothly without GPU roundtrip latency
            fg_neon_blend((const uint8_t*)curr->pixels, (const uint8_t*)prev->pixels,
                          (uint8_t*)pixelData, (size_t)width * height, 0.5f);
            result = FG_OSM_INTERP;
            gContext.framesInterpolated++;
            gContext.displayFPS = effectiveNativeFPS * 2.0f;

            static uint64_t blendLog = 0;
            if (blendLog < 5 || ++blendLog % 30 == 0) {
                NSLog(@"[FrameGen] OSM_NEON_BLEND #%llu hasCam=%d avgFPS=%.1f ring=%d",
                      gContext.framesInterpolated, curr->hasCamera, effectiveNativeFPS, gOSMRing.count);
            }

            double blendEnd = CACurrentMediaTime();
            gContext.osmBlendOverheadUs = (uint64_t)((blendEnd - gContext.osmBlendStartTime) * 1e6);
        }
    }

    if (result == FG_OSM_RAW) {
        gContext.displayFPS = effectiveNativeFPS;
        static uint64_t osmLogCounter = 0;
        if (++osmLogCounter % 30 == 0) {
            NSLog(@"[FrameGen] OSM_RAW total=%llu interp=%llu avgFPS=%.1f ring=%d",
                  gContext.totalFrames, gContext.framesInterpolated, effectiveNativeFPS, gOSMRing.count);
        }
    }

    os_unfair_lock_unlock(&gLock);

    // Request camera capture for next frame (triggers Java → JNI → fg_update_camera)
    // Must be called OUTSIDE the lock (fg_update_camera acquires the same lock).
    fg_request_camera_capture();

    return result;
}
