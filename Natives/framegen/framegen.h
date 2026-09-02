#pragma once
//
//  framegen.h
//  Witch - Frame Generation module
//
//  Inserts interpolated intermediate frames between real rendered frames
//  to increase apparent FPS. Uses Metal compute shaders for
//  motion-vector reprojection and temporal blending.
//
//  Architecture (hybrid approach):
//    1. CAMetalLayer -nextDrawable is swizzled to intercept drawable acquisition.
//    2. When FG is enabled and enough frames have been captured:
//       a. Copy the current drawable texture into a ring buffer.
//       b. Run a compute shader to interpolate between prev and current frames.
//       c. Present the interpolated frame first, then the real frame.
//    3. Camera motion data is collected via JNI from the game side.
//    4. For OSMesa/Zink: frames captured from OSMesa pixel buffer via osm_swap_buffers.
//
//  Limitations:
//    - Only works with MoltenVK renderer (Vulkan -> Metal path) in Phase 1.
//    - Motion vectors are estimated from camera position/rotation only.
//    - No depth buffer handling in Phase 1 (may cause artifacts with fast motion).
//    - OSMesa path: stores CPU pixel buffers as Metal textures for interpolation.

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

// MARK: - Configuration

/// Ring buffer size for captured frames. Need at least 2 for interpolation.
#define FG_RING_BUFFER_SIZE 3

/// Minimum native FPS required before FG activates.
#define FG_MIN_NATIVE_FPS 20

/// Maximum interpolation factor (0.5 = exactly between two frames).
#define FG_MAX_INTERP_FACTOR 0.5f

// MARK: - Camera Data

/// Camera state for motion estimation.
typedef struct {
    float pos[3];       // Camera world position (x, y, z)
    float rot[2];       // Camera rotation (pitch, yaw) in radians
    float viewMatrix[16];   // 4x4 view matrix (column-major)
    float projMatrix[16];   // 4x4 projection matrix (column-major)
    float fov;          // Field of view in degrees
    int   width;        // Viewport width
    int   height;       // Viewport height
    BOOL  valid;        // Whether data has been populated
} FGCameraData;

// MARK: - Frame Ring Buffer Entry

/// A single captured frame in the ring buffer.
typedef struct {
    id<MTLTexture> texture;     // Copy of the frame's color buffer (Metal texture)
    uint64_t       frameIndex;  // Monotonic frame counter
    double         timestamp;   // CACurrentMediaTime when captured
    FGCameraData   camera;      // Camera state at time of capture
} FGFrameEntry;

// MARK: - Public API

/// Initialize the Frame Generation module. Call once at app launch.
void fg_init(void);

/// Enable or disable frame generation at runtime.
void fg_set_enabled(BOOL enabled);

/// Check if frame generation is currently enabled AND active.
BOOL fg_is_enabled(void);

/// Check if frame generation is supported on this device.
BOOL fg_is_supported(void);

// MARK: - Metal Layer Hook & Frame Interception

/// Hook a CAMetalLayer for frame generation initialization.
//  Must be called when setting up the renderer (including OSMesa/Zink paths)
//  to initialize the FG Metal state (pipelines, ring buffer, etc.).
void fg_hook_metal_layer(CAMetalLayer *layer);

/// Called from the CAMetalLayer swizzle on each frame.
/// Intercepts drawable presentation to inject interpolated frames.
BOOL fg_on_next_drawable(id<CAMetalDrawable> drawable, CAMetalLayer *layer);

typedef NS_ENUM(NSInteger, FGInterpolationMode) {
    FG_MODE_MOTION_ADAPTIVE = 0,  // Mode 1: Motion-Adaptive GPU (MADI/MEMC)
    FG_MODE_CAMERA_REPROJECT = 1, // Mode 2: Camera-Guided GPU
    FG_MODE_TEMPORAL_INTERP = 2,  // Mode 2 Sub-A: Temporal Interpolation (fill between native frames)
    FG_MODE_PREDICTIVE = 3        // Mode 2 Sub-B: Predictive Extrapolation (predict next frame)
};

/// FG2 sub-modes (used when framegen_mode = camera_reproject)
typedef NS_ENUM(NSInteger, FG2SubMode) {
    FG2_SUBMODE_INTERP = 0,   // Temporal Interpolation
    FG2_SUBMODE_PREDICT = 1   // Predictive Extrapolation
};

/// Set Frame Generation algorithm mode.
void fg_set_mode(int mode);

/// Get current Frame Generation algorithm mode.
int fg_get_mode(void);

/// Set/get FG2 sub-mode (Temporal Interp vs Predictive)
void fg_set_fg2_submode(int submode);
int fg_get_fg2_submode(void);

/// Set/get target FPS for frame generation
void fg_set_target_fps(int fps);
int fg_get_target_fps(void);

/// GPU-Accelerated Metal Frame Generation for OSMesa RGBA buffers.
/// Dispatches Metal Compute Shader on Apple GPU (A11+) for ~0.02ms latency and 0% CPU overhead.
BOOL fg_gpu_interpolate(const uint8_t* prev, const uint8_t* curr, uint8_t* out,
                        uint32_t width, uint32_t height, float interpFactor);

/// GPU Temporal Interpolation: fill frame between prev and curr, using lastInterp for temporal stability.
BOOL fg_gpu_temporal_interp(const uint8_t* prev, const uint8_t* curr,
                            const uint8_t* _Nullable lastInterp, uint8_t* out,
                            uint32_t width, uint32_t height, float factor);

/// GPU Predictive Extrapolation: predict next frame from source (native or virtual).
BOOL fg_gpu_predict(const uint8_t* prev, const uint8_t* source, uint8_t* out,
                    uint32_t width, uint32_t height, float factor);

/// High-performance NEON SIMD blend of two RGBA uint8 buffers (fallback).
void fg_neon_blend(const uint8_t* curr, const uint8_t* prev, uint8_t* out, size_t numPixels, float t);

/// High-performance motion-compensated frame generation for RGBA pixel buffers.
void fg_motion_interpolate(const uint8_t* prev, const uint8_t* curr, uint8_t* out,
                           uint32_t width, uint32_t height, float t);

/// Record an interpolated frame generated for OSMesa.
void fg_osm_record_interpolated(void);

/// Update OSMesa FPS calculation for stats display.
void fg_osm_update_fps(float nativeFPS, float displayFPS);

/// Legacy OSMesa capture function (for compatibility).
int fg_capture_frame_from_osmesa(void* pixelData, uint32_t width, uint32_t height);

/// Update camera data from the game side (via JNI or polling).
/// Same as the Metal path - called from render thread or game thread.
void fg_update_camera(const FGCameraData *data);

/// Get current FG statistics for HUD display.
typedef struct {
    uint64_t framesInterpolated;
    uint64_t framesSkipped;
    uint64_t totalFrames;
    float    nativeFPS;
    float    displayFPS;
    BOOL     isActive;
    BOOL     isSupported;
} FGStats;

FGStats fg_get_stats(void);

// MARK: - Camera Data Access

/// Get the FG camera data pointer (for JNI updates from Java side).
FGCameraData *fg_get_camera_data(void);

// MARK: - Frame Pacing / Timing

/// Request camera capture from Java side (calls FrameGenBridge.captureCameraData via JNI).
/// Implemented in framegen_jni_bridge.m.
void fg_request_camera_capture(void);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif