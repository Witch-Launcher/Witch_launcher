#ifndef WITCH_FFX_BRIDGE_H
#define WITCH_FFX_BRIDGE_H

// AMD FidelityFX bridge (Vulkan backend) for the Witch launcher.
//
// Supports one FidelityFX context at a time:
//   - FSR3 Frame Generation (FrameInterpolation)
//   - FSR1 / FSR2 / FSR3 Upscaler
//
// The Java agent (net.vda.witchlaunch.fsr3) drives this through plain JNI
// naming; the JVM resolves Java_net_vda_witchlaunch_fsr3_Fsr3Native_* from the
// host binary without RegisterNatives (same pattern as the previous framegen
// core).
//
// Integration contract with the patched RenderPearl surface:
//  - Frame Generation: ffxfg_record_frame() is invoked from inside the patched
//    VulkanGpuSurface.blitFromTexture, BEFORE the surface's own blit/submit,
//    with the transient VkCommandBuffer and the source texture's VkImage. The
//    bridge records FI prepare+dispatch into that command buffer and tells the
//    caller which VkImage to present as the interpolated frame (a bridge-owned
//    output). ffxfg_present_interpolated() then acquires a swapchain image,
//    blits that output into it and presents it (bridge-owned sync objects).
//  - Upscalers: ffxfg_record_upscale() allocates a bridge-owned command
//    buffer, records the upscale dispatch + a blit of the bridge output over
//    the whole swapchain image (which must be in PRESENT_SRC layout at that
//    point - the game's own blit ran first). The Java bridge adds the recorded
//    buffer to the frame submission via VulkanCommandEncoder.execute().

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

// One FidelityFX effect context active at a time.
enum {
    FFXFX_MODE_FRAMEGEN    = 1,
    FFXFX_MODE_FSR1        = 2,
    FFXFX_MODE_FSR2        = 3,
    FFXFX_MODE_FSR3UPSCALE = 4,
};

// Initialize the bridge on the game's Vulkan device.
// colorFormat is a VkFormat (BGRA8_UNORM family). Returns 0 on success.
int ffxfg_init(long long vkDevice,
               long long vkPhysicalDevice,
               long long vkGetDeviceProcAddr,
               long long vkQueue,
               int queueFamilyIndex,
               int mode,
               int renderWidth, int renderHeight,
               int displayWidth, int displayHeight,
               int colorFormat,
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

// Upscaler path (FSR1/FSR2/FSR3 Upscaler). Records into a bridge-owned command
// buffer: synthetic motion vector / depth uploads (when applicable), the
// upscale dispatch into a bridge output, then a blit of the output over the
// whole swapchain image. swapchainImage must currently be in PRESENT_SRC
// layout; it is left in PRESENT_SRC. camData has the same layout as above.
// Returns the bridge-owned VkCommandBuffer handle (submitted by the Java
// bridge through VulkanCommandEncoder.execute), or 0 on failure. Use
// ffxfg_get_output_image(slot) with the slot returned by
// ffxfg_last_upscale_slot().
long long ffxfg_record_upscale(long long srcColorImage,
                               int srcWidth, int srcHeight,
                               long long swapchainImage,
                               const float* camData, int camDataCount,
                               int reset);

// Output slot written by the last ffxfg_record_upscale call (0 or 1, -1 none).
int ffxfg_last_upscale_slot(void);

// The VkCommandBuffer recorded by the last ffxfg_record_upscale call.
long long ffxfg_last_recorded_command_buffer(void);

// Frame generation pacing: acquires a swapchain image (bridge-owned semaphore),
// blits the interpolated output slot into it, submits on the game's graphics
// queue and presents it. Returns the acquired index or -1 on failure.
int ffxfg_present_interpolated(long long vkSwapchain, int slot);

// The VkImage of an output slot (double buffered).
long long ffxfg_get_output_image(int slot);

// Output slot count (double buffered).
int ffxfg_output_slot_count(void);

// Observability: 1 when the last recorded frame was actually processed.
int ffxfg_last_frame_ok(void);

// ---- JNI surface (auto-resolved by JVM naming convention) ----

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_init(
    JNIEnv* env, jclass clazz,
    jlong vkDevice, jlong vkPhysicalDevice, jlong vkGetDeviceProcAddr,
    jlong vkQueue, jint queueFamilyIndex, jint mode,
    jint renderWidth, jint renderHeight,
    jint displayWidth, jint displayHeight,
    jint colorFormat, jint depthInverted);

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_destroy(
    JNIEnv* env, jclass clazz);

JNIEXPORT jboolean JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_isSupported(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordFrame(
    JNIEnv* env, jclass clazz,
    jlong vkCommandBuffer, jlong srcColorImage,
    jint srcWidth, jint srcHeight,
    jfloatArray camData, jint reset);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordUpscale(
    JNIEnv* env, jclass clazz,
    jlong srcColorImage, jint srcWidth, jint srcHeight,
    jlong swapchainImage, jfloatArray camData, jint reset);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastUpscaleSlot(
    JNIEnv* env, jclass clazz);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastRecordedCommandBuffer(
    JNIEnv* env, jclass clazz);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_presentInterpolated(
    JNIEnv* env, jclass clazz, jlong vkSwapchain, jint slot);

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getOutputImage(
    JNIEnv* env, jclass clazz, jint slot);

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_outputSlotCount(
    JNIEnv* env, jclass clazz);

#ifdef __cplusplus
}
#endif

#endif  // WITCH_FFX_BRIDGE_H
