package net.vda.witchlaunch.fsr3;

/**
 * JNI declarations for the AMD FidelityFX bridge compiled into the host
 * binary. Method names follow the plain JNI naming convention - the JVM
 * resolves them from the host binary without RegisterNatives.
 */
public final class Fsr3Native {
    private Fsr3Native() {}

    // Modes - must match the values in Natives/upscaler/ffx_bridge.h.
    public static final int MODE_FRAMEGEN = 1;
    public static final int MODE_FSR1 = 2;
    public static final int MODE_FSR2 = 3;
    public static final int MODE_FSR3UPSCALE = 4;

    /** Initialize the FidelityFX context. Returns 0 on success. */
    public static native int init(long vkDevice, long vkPhysicalDevice,
                                  long vkGetDeviceProcAddr, long vkQueue,
                                  int queueFamilyIndex, int mode,
                                  int renderWidth, int renderHeight,
                                  int displayWidth, int displayHeight,
                                  int colorFormat, int depthInverted);

    public static native void destroy();

    public static native boolean isSupported();

    /**
     * Record the per-frame FidelityFX work into a bridge-owned command
     * buffer. camData is 16 floats: pos(3) right(3) up(3) fwd(3) near far
     * fovY(dtMs at [15]).
     *
     * Returns the bridge-owned VkCommandBuffer handle (0 on failure); add it
     * to the frame submission via VulkanCommandEncoder.execute().
     */
    public static native long recordUpscale(long srcColorImage, int srcWidth,
                                            int srcHeight, long swapchainImage,
                                            float[] camData, int reset);

    /** Output slot written by the last recordUpscale (0/1, or -1). */
    public static native int lastUpscaleSlot();

    /** The VkCommandBuffer recorded by the last recordUpscale. */
    public static native long lastRecordedCommandBuffer();

    /**
     * Frame generation pacing: acquire a swapchain image, blit the
     * interpolated output slot into it, submit and present. Returns the
     * acquired index or -1.
     */
    public static native int presentInterpolated(long vkSwapchain, int slot);

    public static native long getOutputImage(int slot);

    public static native int outputSlotCount();
}
