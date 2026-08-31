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

// MARK: - OSMesa Integration

/// Hook a CAMetalLayer for frame generation initialization.
//  Must be called when setting up the renderer (including OSMesa/Zink paths)
//  to initialize the FG Metal state (pipelines, ring buffer, etc.).
void fg_hook_metal_layer(CAMetalLayer *layer);

/// Called from the OSMesa swap path when a new frame is presented.
//  Captures the frame from pixel data and stores it in the FG ring buffer.
//  Triggers interpolation if enough frames are available.
//  Returns:
//     0 (FG_OSM_RAW):  present raw frame without interpolation
//    +1 (FG_OSM_INTERP): present interpolated/blended frame
//  'width' and 'height' are the frame dimensions.
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