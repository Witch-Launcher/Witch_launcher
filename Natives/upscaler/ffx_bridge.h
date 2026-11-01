#ifndef WITCH_FFX_BRIDGE_H
#define WITCH_FFX_BRIDGE_H

// AMD FidelityFX bridge (Vulkan backend) for the Witch launcher.
//
// Two independent features that can be enabled together (combo):
//   - Upscaler: FSR1 / FSR2 / FSR3 Upscaler (mode != 0). Renders at a scaled
//     resolution, upscales into a bridge-owned output and blits it over the
//     swapchain image.
//   - Frame Generation: FSR3 FrameInterpolation (fgEnabled). In pure FG mode it
//     interpolates from the game's full-res back buffer; in combo mode it
//     interpolates from the upscaler's display-res output instead, so the
//     interpolated frames keep the upscaled quality.
//
// The Java agent (net.vda.witchlaunch.fsr3) drives this through plain JNI
// naming; the JVM resolves Java_net_vda_witchlaunch_fsr3_Fsr3Native_* from the
// host binary without RegisterNatives (same pattern as the previous framegen
// core).
//
// Integration contract with the patched RenderPearl surface:
//  - Upscalers: ffxfg_record_upscale() allocates a bridge-owned command
//    buffer, records the upscale dispatch + a blit of the bridge output over
//    the whole swapchain image (which must be in PRESENT_SRC layout at that
//    point - the game's own blit ran first). The Java bridge adds the recorded
//    buffer to the frame submission via VulkanCommandEncoder.execute().
//  - Frame Generation: the same ffxfg_record_upscale() call records the FI
//    prepare+dispatch after the upscale work (combo) or on its own (pure FG,
//    swapchainImage == 0). ffxfg_present_interpolated() then acquires a
//    swapchain image, blits the interpolation output (ffxfg_last_fg_slot())
//    into it and presents it (bridge-owned sync objects).

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

// Upscaler mode (0 = none). 1 is reserved for the legacy pure-FG mode and is
// accepted by ffxfg_init as (no upscaler + frame generation).
enum {
    FFXFX_MODE_FRAMEGEN    = 1,  // legacy: pure FG, no upscaler
    FFXFX_MODE_FSR1        = 2,
    FFXFX_MODE_FSR2        = 3,
    FFXFX_MODE_FSR3UPSCALE = 4,
};

// Initialize the bridge on the game's Vulkan device.
// mode selects the upscaler (0/FSR1/FSR2/FSR3U; FFXFX_MODE_FRAMEGEN is legacy
// pure-FG). fgEnabled turns on frame generation independently - it can be
// combined with any upscaler (combo) or run alone. sharpness (0..1) drives
// RCAS sharpening inside the FSR dispatches.
// colorFormat is the swapchain's VkFormat (bridge outputs are created with
// it); srcColorFormat is the game render texture's VkFormat (used to register
// the externally-owned color image, and as the FI back buffer format in pure
// FG mode). Returns 0 on success.
int ffxfg_init(long long vkDevice,
               long long vkPhysicalDevice,
               long long vkGetDeviceProcAddr,
               long long vkQueue,
               int queueFamilyIndex,
               int mode,
               int fgEnabled,
               float sharpness,
               int renderWidth, int renderHeight,
               int displayWidth, int displayHeight,
               int colorFormat,
               int srcColorFormat,
               int depthInverted);

void ffxfg_destroy(void);

int ffxfg_isSupported(void);

// Frame generation path. Records one real frame's interpolation work into the
// game's transient command buffer. camData is 16 floats:
//   [0..2)  camera position (world)
//   [3..6)  camera right (normalized)
//   [6..9)  camera up (normalized)
//   [9..12) camera forward (normalized)
//   [12]    near plane, [13] far plane, [14] fovY radians,
//   [15]    frameTimeDelta ms
// Returns:
//   >= 0  the output slot whose VkImage holds the interpolated frame, or
//   -1    disabled/not initialized/error - caller must present the real frame.
int ffxfg_record_frame(long long vkCommandBuffer,
                       long long srcColorImage,
                       int srcWidth, int srcHeight,
                       const float* camData, int camDataCount,
                       int reset);

// Upscaler path (FSR1/FSR2/FSR3 Upscaler) and/or the frame generation path.
// When a swapchainImage is given the upscaler blit is recorded; when the
// bridge was initialized with fgEnabled the frame interpolation prepare +
// dispatch is recorded as well (reading the upscaler output in combo mode, or
// srcColor when no upscaler is active). Records into a bridge-owned command
// buffer: synthetic motion vector / depth uploads (when applicable), the
// upscale dispatch into a bridge output, the blit of the output over the
// whole swapchain image, then the interpolation dispatch into a separate
// bridge output. swapchainImage must currently be in PRESENT_SRC layout; it is
// left in PRESENT_SRC. camData has the same layout as above.
// Returns the bridge-owned VkCommandBuffer handle (submitted by the Java
// bridge through VulkanCommandEncoder.execute), or 0 on failure. The upscale
// result lives in ffxfg_get_output_image(ffxfg_last_upscale_slot()); the
// interpolated result in ffxfg_get_fg_output_image(ffxfg_last_fg_slot()).
long long ffxfg_record_upscale(long long srcColorImage,
                               int srcWidth, int srcHeight,
                               long long swapchainImage,
                               int srcColorFormat,
                               const float* camData, int camDataCount,
                               int reset);

// Output slot written by the last ffxfg_record_upscale call (0 or 1, -1 none).
int ffxfg_last_upscale_slot(void);

// Output slot holding the latest interpolated frame (or -1 none).
int ffxfg_last_fg_slot(void);

// Witch patch: frame generation multiplier M (2..6; number of frames shown
// per real frame). Must be set before the first record call. Returns 0 on
// success.
int ffxfg_set_fg_multiplier(int multiplier);

// Witch patch: measurement probe bitmask (perf tuning on A11, where MoltenVK
// provides no usable per-stage GPU counters). Bits:
//   1  skip the optical-flow dispatch entirely (stale flow for FI)
//   2  run the optical-flow dispatch every frame (disables the every-other
//      throttle that FG-only mode applies by default)
//   4  skip the interpolation dispatch (and prepare) - no generated frames
//   8  skip the generated-frame present batch (present hook no-ops)
// bits compose: 12 = "FG GPU bypass" (full-bypass baseline, closest to
// frame generation off while the record path still runs). Returns the set
// mask.
int ffxfg_set_probe(int probeMask);

// Witch patch: the generated sub-frame slots produced by the last record
// call, oldest first. The present hook shows them all (multi-frame
// generation).
int ffxfg_pending_fg_slot_count(void);
int ffxfg_pending_fg_slot(int index);

// Witch patch: current EMA frame rates for the launcher widget.
// outFps[0] = real (render) fps, outFps[1] = generated-frame fps.
void ffxfg_get_frame_stats(float* outFps);

// The VkCommandBuffer recorded by the last ffxfg_record_upscale call.
long long ffxfg_last_recorded_command_buffer(void);

// Frame generation present: blits the interpolated output slot into an
// acquired swapchain image and presents it, on the caller's (render) thread.
// Sync objects and the swapchain image list are bridge-owned. Returns 0 when
// presented or skipped, -1 on a swapchain error (generated frames pause until
// the surface is reconfigured).
int ffxfg_present_interpolated(long long vkSwapchain, int slot);

// The surface is about to destroy vkSwapchain (GpuSurface.configure/close,
// on the render thread): drop every cached image and rebuild the present sync
// objects on the next present. Pass 0 when the handle is unknown.
void ffxfg_swapchain_destroyed(long long vkSwapchain);

// The VkImage of an output slot (double buffered).
long long ffxfg_get_output_image(int slot);

// The VkImage of an interpolated-output slot (double buffered).
long long ffxfg_get_fg_output_image(int slot);

// Output slot count (double buffered).
int ffxfg_output_slot_count(void);

// Observability: 1 when the last recorded frame was actually processed.
int ffxfg_last_frame_ok(void);

// ---- JNI surface (auto-resolved by JVM naming convention) ----

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_init(
    JNIEnv* env, jclass clazz,
    jlong vkDevice, jlong vkPhysicalDevice, jlong vkGetDeviceProcAddr,
    jlong vkQueue, jint queueFamilyIndex, jint mode,
    jint fgEnabled, jfloat sharpness,
    jint renderWidth, jint renderHeight,
    jint displayWidth, jint displayHeight,
    jint colorFormat, jint srcColorFormat, jint depthInverted);

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_destroy(
    JNIEnv* env, jclass clazz);

JNIEXPORT jboolean JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_isSupported(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordFrame(
    JNIEnv* env, jclass clazz,
    jlong vkCommandBuffer, jlong srcColorImage,
    jint srcWidth, jint srcHeight,
    jfloatArray camData, jint reset);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordUpscale(
    JNIEnv* env, jclass clazz,
    jlong srcColorImage, jint srcWidth, jint srcHeight,
    jlong swapchainImage, jint srcColorFormat, jfloatArray camData, jint reset);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastUpscaleSlot(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastFgSlot(
    JNIEnv* env, jclass clazz);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastRecordedCommandBuffer(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_presentInterpolated(
    JNIEnv* env, jclass clazz, jlong vkSwapchain, jint slot);

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_swapchainDestroyed(
    JNIEnv* env, jclass clazz, jlong vkSwapchain);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getOutputImage(
    JNIEnv* env, jclass clazz, jint slot);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getFgOutputImage(
    JNIEnv* env, jclass clazz, jint slot);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_outputSlotCount(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_setFgMultiplier(
    JNIEnv* env, jclass clazz, jint multiplier);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_setProbe(
    JNIEnv* env, jclass clazz, jint probe);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_pendingFgSlotCount(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_pendingFgSlot(
    JNIEnv* env, jclass clazz, jint index);

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getFrameStats(
    JNIEnv* env, jclass clazz, jfloatArray stats);

#ifdef __cplusplus
}
#endif

#endif  // WITCH_FFX_BRIDGE_H
