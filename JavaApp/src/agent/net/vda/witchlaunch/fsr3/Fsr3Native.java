package net.vda.witchlaunch.fsr3;

/**
 * JNI declarations for the AMD FidelityFX bridge compiled into the host
 * binary. Method names follow the plain JNI naming convention - the JVM
 * resolves them from the host binary without RegisterNatives.
 */
public final class Fsr3Native {
    private Fsr3Native() {}

    // Upscaler modes - must match the values in Natives/upscaler/ffx_bridge.h.
    // MODE_FRAMEGEN is the legacy pure-FG value (no upscaler + FG on).
    public static final int MODE_NONE = 0;
    public static final int MODE_FRAMEGEN = 1;
    public static final int MODE_FSR1 = 2;
    public static final int MODE_FSR2 = 3;
    public static final int MODE_FSR3UPSCALE = 4;

    /**
     * Initialize the FidelityFX contexts. mode selects the upscaler (0/FSR1/
     * FSR2/FSR3U), fgEnabled turns on frame generation independently - both
     * may be active at once (upscale first, then interpolate the upscaled
     * frame). sharpness (0..1) drives RCAS sharpening. colorFormat is the
     * swapchain's VkFormat (bridge outputs), srcColorFormat the render
     * texture's VkFormat. Returns 0 on success.
     */
    public static native int init(long vkDevice, long vkPhysicalDevice,
                                  long vkGetDeviceProcAddr, long vkQueue,
                                  int queueFamilyIndex, int mode,
                                  int fgEnabled, float sharpness,
                                  int renderWidth, int renderHeight,
                                  int displayWidth, int displayHeight,
                                  int colorFormat, int srcColorFormat,
                                  int depthInverted);

    public static native void destroy();

    public static native boolean isSupported();

    /**
     * Record the per-frame FidelityFX work into a bridge-owned command
     * buffer. camData is 16 floats: pos(3) right(3) up(3) fwd(3) near far
     * fovY(dtMs at [15]).
     *
     * Returns the fg output slot written this frame (>= 0, see
     * lastFgSlot()); negative when nothing was recorded. The recorded
     * VkCommandBuffer is fetched via lastRecordedCommandBuffer().
     */
    public static native int recordUpscale(long srcColorImage, int srcWidth,
                                           int srcHeight, long swapchainImage,
                                           int srcColorFormat,
                                           float[] camData, int reset);

    /** Output slot written by the last recordUpscale (0/1, or -1). */
    public static native int lastUpscaleSlot();

    /** Output slot holding the latest interpolated frame (0/1, or -1). */
    public static native int lastFgSlot();

    /** The VkCommandBuffer recorded by the last recordUpscale. */
    public static native long lastRecordedCommandBuffer();

    /**
     * Frame generation present: blit the interpolated output slot into an
     * acquired swapchain image and present it (render thread). Returns 0 when
     * presented or skipped, -1 when the swapchain failed.
     */
    public static native int presentInterpolated(long vkSwapchain, int slot);

    /**
     * The surface is about to destroy {@code vkSwapchain} (configure/close):
     * drop cached images and reset the present sync objects. Pass 0 when the
     * handle is unknown.
     */
    public static native void swapchainDestroyed(long vkSwapchain);

    public static native long getOutputImage(int slot);

    /** The VkImage of an interpolated-output slot (double buffered). */
    public static native long getFgOutputImage(int slot);

    public static native int outputSlotCount();

    /** Witch patch: frame generation multiplier M (2..6). */
    public static native int setFgMultiplier(int multiplier);

    /** Witch patch: measurement probe bitmask (see ffxfg_set_probe). */
    public static native int setProbe(int probe);

    /** Witch patch: generated sub-frame slots pending presentation. */
    public static native int pendingFgSlotCount();

    public static native int pendingFgSlot(int index);

    /** Witch patch: out[0] = render fps, out[1] = generated-frame fps. */
    public static native void getFrameStats(float[] out);
}
