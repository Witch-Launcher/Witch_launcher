package net.vda.witchlaunch.fsr3;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/**
 * Hook callbacks invoked from the patched game classes plus the reflection
 * plumbing that feeds the native FidelityFX bridge.
 *
 * Hook sites (see Fsr3Patcher):
 *  - Minecraft.renderFrame            -> onRenderFrame(mc)
 *  - VulkanGpuSurface.blitFromTexture -> onBlit(surface, encoder, textureView)
 *  - VulkanCommandEncoder.submit      -> onBeforeSubmit(encoder)
 *  - VulkanGpuSurface.present         -> onPresent(surface)
 *  - Window getters                   -> scaledWidth/scaledHeight/...
 */
public class Fsr3Bridge {

    // Upscaler mode (0 = off) and frame generation flag are independent:
    // the upscaler renders at a scaled resolution, frame generation inserts
    // interpolated frames (from the upscaler output when both are active).
    // Defaults come from system properties because the patched game classes
    // resolve this class through the GAME classloader (which may define its
    // own copy - configure() runs on the agent's copy); properties reach both.
    private static volatile int upscalerMode =
            Integer.getInteger("witch.fsr3.upscaler", 0);
    private static volatile int fgEnabled =
            Integer.getInteger("witch.fsr3.fg", 0) != 0 ? 1 : 0;
    private static volatile float scale =
            clampScale(parseFloatProperty("witch.fsr3.scale", 1.0f));
    private static volatile float sharpness =
            clampSharpness(parseFloatProperty("witch.fsr3.sharpness", 0.6f));
    // Witch patch: frame generation multiplier M (2..6) - the number of frames
    // displayed per real frame.
    private static volatile int fgMultiplier =
            clampMultiplier(Integer.getInteger("witch.fsr3.fgx", 2));

    // Witch patch: measurement probe bitmask (GPU cost isolation; see
    // ffxfg_set_probe).
    private static volatile int probe =
            Integer.getInteger("witch.fsr3.probe", 0);

    // Witch patch: sub-pixel jitter for the FidelityFX temporal accumulation.
    // The accumulation can only resolve aliasing when the scene is rendered at
    // a different sub-pixel position every frame, so the launcher skews the
    // game's projection matrix by the jitter and tells the upscaler about the
    // same value. Only the modes with a temporal accumulation benefit from
    // it (FSR2 and the FSR3 upscaler); FSR1 is purely spatial and the pure
    // frame generation mode has no accumulation, so jittering there would
    // only add shimmer.
    private static volatile int jitterEnabled =
            Integer.getInteger("witch.fsr3.jitter", 1) != 0 ? 1 : 0;

    // The surface (display) size - the reference for the GUI size.
    private static volatile int displayWidth = 0;
    private static volatile int displayHeight = 0;
    // The render (framebuffer) size - the jitter is expressed in these
    // pixels and the projection skew is derived from them.
    private static volatile int renderWidth = 0;
    private static volatile int renderHeight = 0;

    // Per-frame state (render thread only).
    private static volatile Object minecraft;
    private static volatile Object lastSurface;
    private static volatile Object lastTextureView;
    private static volatile Object lastEncoder;

    // Native init state.
    private static volatile boolean nativeReady = false;
    private static volatile boolean nativeFailed = false;
    private static volatile boolean frameRecordPending = false;
    private static org.lwjgl.vulkan.VkDevice lwjglDevice;

    // Reflection caches.
    private static boolean reflectionReady = false;
    private static String reflectionError = null;

    private static Method mcGetWindow;
    private static Field mcGameRendererField;

    private static Method cameraPosition, cameraXRot, cameraYRot, cameraFov,
            cameraForward, cameraUp;
    private static Method vec3X, vec3Y, vec3Z;
    private static Method v3fX, v3fY, v3fZ;

    private static Field surfaceSwapchain, surfaceSwapchainImages,
            surfaceCurrentImageIndex, surfaceSwapchainWidth,
            surfaceSwapchainHeight, surfaceSwapchainImageFormat, surfaceDevice;
    private static Method deviceVkDevice, deviceGraphicsQueue;
    private static Method queueVkQueue, queueFamilyIdx;
    private static Method viewVkImage, viewGetWidth, viewGetHeight,
            viewTexture, textureGetFormat, textureVkImage;
    private static Method encoderExecute;
    private static Method longListGetLong;
    // ProjectionMatrixBuffer internals: the buffer only re-uploads the matrix
    // when the Projection reports a new version, so the cache has to be
    // dropped for a per-frame jitter to reach the GPU.
    private static Field projectionBufferLastUploaded;
    private static Field projectionBufferVersion;
    // Projection.projectionType - the GUI is drawn with an orthographic
    // projection, which must never be jittered (see isOrthographicProjection).
    private static Field projectionProjectionType;
    // True while the projection that is currently being uploaded is the
    // orthographic GUI one.
    private static volatile boolean guiProjectionPending = false;
    // org.joml.Matrix4f z terms of the first two rows (m20/m21): they shift
    // the projected image by a constant sub-pixel amount at every depth.
    // JOML is not on the agent's classpath and its matrix fields are package
    // private, so the public accessors are used on the runtime class.
    private static Method matrixM20, matrixM20Set, matrixM21, matrixM21Set;

    // Camera delta state for reset detection and frame time.
    private static long lastSubmitNanos = 0;
    private static float prevCamX, prevCamY, prevCamZ, prevXRot, prevYRot;
    private static boolean havePrevCam = false;

    // TAA jitter state (render thread only).
    private static float jitterX = 0.0f;
    private static float jitterY = 0.0f;
    // The jitter that was actually written to the GPU. It is the one the
    // native side is told about: if the game skipped the projection upload
    // (the matrix is only re-uploaded when it changes) the image on the GPU
    // still carries the previous jitter.
    private static float appliedJitterX = 0.0f;
    private static float appliedJitterY = 0.0f;
    private static int jitterIndex = 0;

    // Camera deltas that count as a discontinuity and therefore require the
    // temporal history to be reset: a teleport (blocks) or a camera cut
    // (degrees of combined pitch/yaw change).
    private static final float CAMERA_TELEPORT_DISTANCE = 4.0f;
    private static final float CAMERA_CUT_ROTATION = 90.0f;

    public static void configure(int newUpscalerMode, int newFgEnabled,
                                 int newFgMultiplier, float newScale,
                                 float newSharpness, int newProbe) {
        configure(newUpscalerMode, newFgEnabled, newFgMultiplier, newScale,
                newSharpness, newProbe, 1);
    }

    public static void configure(int newUpscalerMode, int newFgEnabled,
                                 int newFgMultiplier, float newScale,
                                 float newSharpness, int newProbe,
                                 int newJitter) {
        // Clamp before publishing: a corrupt preferences file must not be able
        // to produce a broken native configuration (the game's classloader
        // copy of this class reads the same properties).
        int clampedMultiplier = clampMultiplier(newFgMultiplier);
        float clampedScale = clampScale(newScale);
        float clampedSharpness = clampSharpness(newSharpness);
        // Publish through system properties FIRST: if the game's classloader
        // defines its own copy of this class, its static init runs on first
        // hook touch and must already see the real values.
        System.setProperty("witch.fsr3.upscaler", Integer.toString(newUpscalerMode));
        System.setProperty("witch.fsr3.fg", newFgEnabled != 0 ? "1" : "0");
        System.setProperty("witch.fsr3.fgx", Integer.toString(clampedMultiplier));
        System.setProperty("witch.fsr3.scale", Float.toString(clampedScale));
        System.setProperty("witch.fsr3.sharpness", Float.toString(clampedSharpness));
        System.setProperty("witch.fsr3.probe", Integer.toString(newProbe));
        System.setProperty("witch.fsr3.jitter", newJitter != 0 ? "1" : "0");
        upscalerMode = newUpscalerMode;
        fgEnabled = newFgEnabled != 0 ? 1 : 0;
        fgMultiplier = clampedMultiplier;
        scale = clampedScale;
        sharpness = clampedSharpness;
        probe = newProbe;
        jitterEnabled = newJitter != 0 ? 1 : 0;
    }

    // Frame generation multiplier M (2..6) - the number of frames displayed
    // per real frame.
    private static int clampMultiplier(int value) {
        return Math.max(2, Math.min(6, value));
    }

    // Render-resolution scale: (0, 1]. 0 would render nothing, > 1 would
    // defeat the upscaler; NaN falls back to 1.
    private static float clampScale(float value) {
        if (!(value > 0.0f) || value > 1.0f) return 1.0f;
        return value;
    }

    // RCAS sharpening strength: [0, 1]. NaN falls back to the default.
    private static float clampSharpness(float value) {
        if (Float.isNaN(value)) return 0.6f;
        return Math.max(0.0f, Math.min(1.0f, value));
    }

    // Read a float system property, falling back to the default when the
    // value is missing or unparsable.
    private static float parseFloatProperty(String key, float fallback) {
        String raw = System.getProperty(key);
        if (raw == null) return fallback;
        try {
            return Float.parseFloat(raw.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    /**
     * Height of the eye above the ground the player stands on, or 0 when it
     * cannot be determined.
     *
     * The native side uses it to model the ground as a plane and derive the
     * distance of the ground pixels from it, instead of assuming one
     * constant distance for the whole screen. That cuts the parallax error of
     * the synthetic motion vectors by 3-7x while the player walks.
     *
     * It is only valid when the player stands on the ground and the camera
     * is the first person eye (1.62 m above the feet) - flying, jumping,
     * riding or a third person camera all change the camera height in a way
     * the ground plane cannot know.
     */
    private static float groundEyeHeight() {
        try {
            Object mc = minecraft;
            if (mc == null || mcPlayerField == null) return 0.0f;
            Object player = mcPlayerField.get(mc);
            if (player == null) return 0.0f;
            if (entityOnGround == null || entityGetY == null) return 0.0f;
            if (!((Boolean) entityOnGround.invoke(player))) return 0.0f;
            // The camera has to be the player's eye: a third person camera is
            // moved back and up, which breaks the ground plane.
            float camY = num(vec3Y.invoke(cameraPosition.invoke(
                    gameRendererMainCamera().invoke(mcGameRendererField.get(mc)))));
            float eyeY = (Float) entityGetY.invoke(player) + PLAYER_EYE_HEIGHT;
            if (Math.abs(camY - eyeY) > 0.2f) return 0.0f;
            return PLAYER_EYE_HEIGHT;
        } catch (Throwable t) {
            return 0.0f;
        }
    }

    // Minecraft's standing eye height (the player is 1.8 blocks tall).
    private static final float PLAYER_EYE_HEIGHT = 1.62f;

    // ---- reflection caches for the ground plane ---------------------------------

    private static Field mcPlayerField;
    private static Method entityOnGround;
    private static Method entityGetY;

    // Reflection caches for the GUI scale: the scale the user picked in the
    // options and the "force unicode font" flag decide the automatic scale
    // the game uses - both are needed to reproduce it exactly.
    private static Field mcOptionsField;
    private static Method optionsGuiScale;
    private static Method optionInstanceGet;
    private static Method minecraftIsEnforceUnicode;

    // ---- hook callbacks ---------------------------------------------------------

    // One-shot diagnostics: prove each hook actually fires (silent early
    // returns made a mis-wired pipeline indistinguishable from no hooks).
    private static boolean dbgRenderFrame, dbgBlit, dbgSubmit, dbgPresent, dbgSignal;

    public static void onRenderFrame(Object mc) {
        if (!dbgRenderFrame) {
            dbgRenderFrame = true;
            System.out.println("[Fsr3Bridge] onRenderFrame (mc=" + (mc != null)
                    + " upscaler=" + upscalerMode + " fg=" + fgEnabled + ")");
        }
        minecraft = mc;
        // Pick the jitter for this frame before the projection is built.
        updateJitter();
        logGuiMetrics();
    }

    /**
     * Log the GUI geometry once a second.
     *
     * The HUD is laid out in Window.getGuiScaledWidth() units and drawn with
     * the orthographic projection that covers
     * WindowRenderState.width / WindowRenderState.guiScale units. Those two
     * numbers have to match, otherwise the HUD is drawn at the wrong size or
     * outside the screen. The agent overrides getGuiScaledWidth(), so the
     * numbers are logged here: the raw framebuffer the game uses, the
     * (possibly scaled) size the agent reports, the GUI scale the game
     * computed and both GUI sizes.
     */
    private static void logGuiMetrics() {
        long now = System.currentTimeMillis();
        if (now - lastGuiLogMillis < 1000) return;
        lastGuiLogMillis = now;
        try {
            Object window = getWindow();
            if (window == null) return;
            int rawW = readIntField(window, "framebufferWidth", 0);
            int rawH = readIntField(window, "framebufferHeight", 0);
            int gameScale = readIntField(window, "guiScale", 0);
            int gameGuiW = readIntField(window, "guiScaledWidth", 0);
            int gameGuiH = readIntField(window, "guiScaledHeight", 0);
            int agentGuiW = guiSize(window, true);
            int agentGuiH = guiSize(window, false);
            System.out.println("[Fsr3Bridge] gui: fb=" + rawW + "x" + rawH
                    + " patched=" + scaledWidth(window) + "x" + scaledHeight(window)
                    + " guiScale=" + gameScale
                    + " gameGui=" + gameGuiW + "x" + gameGuiH
                    + " agentGui=" + agentGuiW + "x" + agentGuiH
                    + (gameGuiW == agentGuiW && gameGuiH == agentGuiH
                       ? " (match)" : " (MISMATCH)"));        } catch (Throwable t) {
            // Diagnostics only: never disturb the render thread.
        }
    }

    private static long lastGuiLogMillis = 0;

    /** The game's Window instance (via Minecraft.getWindow()). */
    private static Object getWindow() {
        try {
            if (minecraft == null) return null;
            if (mcGetWindow == null) {
                mcGetWindow = minecraft.getClass().getMethod("getWindow");
            }
            return mcGetWindow.invoke(minecraft);
        } catch (Throwable t) {
            return null;
        }
    }

    /**
     * Called at the start of ProjectionMatrixBuffer.getBuffer(Projection).
     *
     * The game only re-uploads the projection matrix when the Projection
     * reports a new version, and the version only changes when the camera
     * parameters change. A per-frame sub-pixel jitter would therefore never
     * reach the GPU while the player stands still - the image would keep the
     * jitter of an older frame while the upscaler is told a different one,
     * and the accumulation would blur instead of resolving. Dropping the
     * buffer's cache forces the matrix to be written again every frame.
     */
    public static void onProjectionBufferGet(Object buffer, Object projection) {
        // Witch patch: remember whether the projection that is about to be
        // uploaded is the orthographic GUI one. The jitter skew must never
        // touch it (see onProjectionWrite).
        guiProjectionPending = isOrthographicProjection(projection);
        if (!jitterActive()) return;
        if (guiProjectionPending) {
            // The GUI projection never carries the jitter, so its upload
            // cache does not have to be dropped every frame - only when the
            // game itself changes the projection.
            return;
        }
        try {
            if (projectionBufferLastUploaded == null) {
                // The reflection is normally set up on the first submit, but
                // the projection is written before that.
                ensureReflection();
            }
            if (projectionBufferLastUploaded != null) {
                projectionBufferLastUploaded.set(buffer, null);
                projectionBufferVersion.setLong(buffer, -1L);
            }
        } catch (Throwable t) {
            logOnce("projection cache invalidation failed: " + t);
        }
    }

    /**
     * Whether the projection is the orthographic one the GUI is drawn with.
     *
     * The HUD/GUI is rendered with Projection.setupOrtho(1000, 11000, w/gui,
     * h/gui, true) - an orthographic projection with a clip space depth of
     * 1000..11000. The jitter skew lives in the z terms of the first two rows
     * (m20/m21) and multiplies the view space z, so on that projection it
     * shifts the whole GUI by up to 8 clip units (the screen is 2 units wide):
     * the HUD is sheared completely off the screen. Only the perspective
     * projection of the world may be skewed.
     */
    private static boolean isOrthographicProjection(Object projection) {
        if (projection == null) return false;
        try {
            if (projectionProjectionType == null) {
                Field field = projection.getClass().getDeclaredField("projectionType");
                field.setAccessible(true);
                projectionProjectionType = field;
            }
            Object type = projectionProjectionType.get(projection);
            if (type != null) {
                String name = type.toString();
                // ProjectionType.ORTHOGRAPHIC
                if (name.indexOf("ORTHOGRAPHIC") >= 0) return true;
            }
        } catch (Throwable t) {
            // Fall through to the depth check below.
        }
        try {
            // Second, independent signal: the GUI projection is built with
            // setupOrtho(1000, 11000, ...), so its near plane is far away from
            // the 0.05 of the world's perspective projection. A near plane
            // that far out means the clip space depth is huge and a shear in
            // m20/m21 would move the GUI by several clip units.
            Method zNear = projection.getClass().getMethod("zNear");
            double near = ((Number) zNear.invoke(projection)).doubleValue();
            return near > 10.0;
        } catch (Throwable t) {
            // Unknown: assume the world projection (the jitter is harmless
            // there) rather than the GUI one.
            return false;
        }
    }

    /**
     * Called with the projection matrix that is about to be uploaded to the
     * GPU. Skew it by the current jitter so the scene really is rendered at a
     * different sub-pixel position every frame.
     *
     * The skew goes into the z terms of the first two rows (m20/m21): they
     * shift the NDC by a constant amount for every depth, which is what a
     * lens shift (and therefore what the FidelityFX accumulation expects).
     * The clip-space w terms (m30/m31) would shift by an amount that depends
     * on the depth instead.
     *
     * The sign: the content has to move by +jitter (right and up), and
     * m20 = +s moves the NDC by -s, hence the subtraction.
     *
     * Witch patch: the orthographic GUI projection is never skewed. Its clip
     * space depth is 1000..11000, so the same skew would shift the whole HUD
     * by up to 8 clip units - the screen is only 2 units wide - and the GUI
     * would disappear completely. That was the "FSR loses the UI" bug.
     */
    public static void onProjectionWrite(Object buffer, Object matrix) {
        if (!jitterActive()) return;
        if (guiProjectionPending) {
            // The GUI projection: no jitter, and the native side must not be
            // told about one either.
            guiProjectionPending = false;
            return;
        }
        try {
            // JOML is provided by the game, not by the agent, and its matrix
            // fields are package-private, so the accessors are used.
            if (matrixM20 == null) {
                Class<?> matrixClass = matrix.getClass();
                matrixM20 = matrixClass.getMethod("m20");
                matrixM20Set = matrixClass.getMethod("m20", float.class);
                matrixM21 = matrixClass.getMethod("m21");
                matrixM21Set = matrixClass.getMethod("m21", float.class);
            }
            if (renderWidth > 0) {
                float value = (Float) matrixM20.invoke(matrix);
                matrixM20Set.invoke(matrix, value - 2.0f * jitterX / (float) renderWidth);
            }
            if (renderHeight > 0) {
                float value = (Float) matrixM21.invoke(matrix);
                matrixM21Set.invoke(matrix, value - 2.0f * jitterY / (float) renderHeight);
            }
            // Remember what was really uploaded: the native side has to be
            // told the jitter the GPU saw, not the one we intended.
            appliedJitterX = jitterX;
            appliedJitterY = jitterY;
        } catch (Throwable t) {
            logOnce("projection jitter failed: " + t);
        }
    }

    /** True when the sub-pixel jitter has to be applied to the frame. */
    private static boolean jitterActive() {
        // Only the modes with a temporal accumulation: FSR2 and the FSR3
        // upscaler. FSR1 is purely spatial and the pure frame generation mode
        // has no accumulation to resolve the jitter.
        return jitterEnabled != 0
                && (upscalerMode == Fsr3Native.MODE_FSR2
                    || upscalerMode == Fsr3Native.MODE_FSR3UPSCALE)
                && renderWidth > 0 && renderHeight > 0;
    }

    /**
     * Advance the jitter sequence. It reproduces the FidelityFX Halton
     * sequence exactly (ffxFsr3UpscalerGetJitterOffset), so the value the
     * upscaler is told about is the value that was rendered.
     */
    private static void updateJitter() {
        if (!jitterActive()) {
            jitterX = 0.0f;
            jitterY = 0.0f;
            return;
        }
        int phaseCount = jitterPhaseCount();
        int index = (jitterIndex % phaseCount) + 1;
        jitterX = halton(index, 2) - 0.5f;
        jitterY = halton(index, 3) - 0.5f;
        jitterIndex++;
    }

    /**
     * The number of jitter phases, the same formula the FidelityFX SDK uses
     * (ffxFsr3UpscalerGetJitterPhaseCount): the finer the render resolution
     * is, the more phases are needed to cover the pixel grid.
     */
    private static int jitterPhaseCount() {
        if (renderWidth <= 0 || displayWidth <= 0) return 8;
        float basePhaseCount = 8.0f;
        int count = (int) (basePhaseCount
                * (float) Math.pow((float) displayWidth / (float) renderWidth, 2.0f));
        return count < 1 ? 1 : count;
    }

    /** Halton sequence, identical to the FidelityFX SDK implementation. */
    private static float halton(int index, int base) {
        float f = 1.0f;
        float result = 0.0f;
        int currentIndex = index;
        while (currentIndex > 0) {
            f /= (float) base;
            result = result + f * (float) (currentIndex % base);
            currentIndex = (int) Math.floor((float) currentIndex / (float) base);
        }
        return result;
    }

    public static void onBlit(Object surface, Object encoder, Object textureView) {
        if (!dbgBlit) {
            dbgBlit = true;
            System.out.println("[Fsr3Bridge] onBlit (surface=" + (surface != null)
                    + " view=" + (textureView != null) + ")");
        }
        lastSurface = surface;
        lastEncoder = encoder;
        lastTextureView = textureView;
        // blitFromTexture runs once per frame; gate the FidelityFX record to
        // the first submit() that follows it. The game's encoder can call
        // submit() multiple times per frame and each invocation opens a new
        // queue submission - recording into every one of them would advance
        // the output slots more than once per frame.
        frameRecordPending = true;
    }

    /**
     * Called instead of VulkanGpuSurface.configure(Configuration)'s body.
     *
     * The swapchain has to match the CAMetalLayer's drawable, but the game
     * only asks for its framebuffer size (the launcher's resolution scale).
     * When the FidelityFX upscaler is on, the swapchain is created with the
     * drawable size instead: the game keeps rendering into its own, smaller
     * render target (so the HUD keeps the size it has without FSR) and the
     * upscaler writes a full resolution frame into the swapchain.
     *
     * The configuration is an immutable record, so a new one is built and
     * returned; the original is returned unchanged when nothing has to
     * change (or when the query failed), which keeps the old behaviour.
     */
    public static Object surfaceConfiguration(Object surface, Object configuration) {
        try {
            if (configuration == null) return configuration;
            // The bridge has to drop the images it cached from the old
            // swapchain before the surface destroys it.
            invalidateSwapchain(surface, "configure");
            if (upscalerMode == Fsr3Native.MODE_NONE) {
                // No upscaler: the swapchain stays at the framebuffer size
                // (the frame generation path blits into it itself).
                return configuration;
            }
            Class<?> configClass = configuration.getClass();
            int requestedW = ((Number) configClass.getMethod("width")
                    .invoke(configuration)).intValue();
            int requestedH = ((Number) configClass.getMethod("height")
                    .invoke(configuration)).intValue();
            int[] extent = querySurfaceExtent(surface);
            if (extent == null || extent[0] <= 0 || extent[1] <= 0) {
                return configuration;
            }
            if (extent[0] <= requestedW || extent[1] <= requestedH) {
                // The drawable is not bigger than what the game asked for:
                // nothing to gain, and shrinking the swapchain is never safe.
                return configuration;
            }
            Object presentMode = configClass.getMethod("presentMode").invoke(configuration);
            Object replacement = configClass
                    .getConstructor(int.class, int.class, presentMode.getClass())
                    .newInstance(extent[0], extent[1], presentMode);
            System.out.println("[Fsr3Bridge] surface: swapchain " + requestedW + "x"
                    + requestedH + " -> " + extent[0] + "x" + extent[1]
                    + " (drawable, the upscaler fills it)");
            return replacement;
        } catch (Throwable t) {
            logOnce("surface configuration rewrite failed: " + t);
            return configuration;
        }
    }

    /**
     * The drawable size of the surface, or null when it cannot be queried.
     */
    private static int[] querySurfaceExtent(Object surface) {
        try {
            if (surface == null) return null;
            long surfaceHandle = readLongField(surface, "surface");
            if (surfaceHandle == 0) return null;
            Object deviceObj = surfaceDevice.get(surface);
            if (deviceObj == null) return null;
            // The instance: device.instance().vkInstance().address()
            Object instanceObj = deviceObj.getClass().getMethod("instance").invoke(deviceObj);
            org.lwjgl.vulkan.VkInstance instance = (org.lwjgl.vulkan.VkInstance)
                    instanceObj.getClass().getMethod("vkInstance").invoke(instanceObj);
            long instanceAddr = instance.address();
            // The physical device: the LWJGL device can hand it out.
            if (lwjglDevice == null) {
                lwjglDevice = (org.lwjgl.vulkan.VkDevice) deviceVkDevice.invoke(deviceObj);
            }
            long physAddr = 0;
            try {
                org.lwjgl.vulkan.VkPhysicalDevice phys = lwjglDevice.getPhysicalDevice();
                physAddr = phys.address();
            } catch (Throwable ignored) {
                physAddr = 0;
            }
            if (instanceAddr == 0 || physAddr == 0) return null;
            int[] out = new int[2];
            if (Fsr3Native.surfaceExtent(instanceAddr, physAddr, surfaceHandle, out) != 0) {
                return null;
            }
            return out;
        } catch (Throwable t) {
            logOnce("surface extent query failed: " + t);
            return null;
        }
    }

    private static long readLongField(Object obj, String name) {
        if (obj == null) return 0;
        try {
            Field f = obj.getClass().getDeclaredField(name);
            f.setAccessible(true);
            return f.getLong(obj);
        } catch (Throwable t) {
            return 0;
        }
    }

    public static void onBeforeSubmit(Object encoder) {
        if (!dbgSubmit) {
            dbgSubmit = true;
            System.out.println("[Fsr3Bridge] onBeforeSubmit (surface=" + (lastSurface != null)
                    + " view=" + (lastTextureView != null) + " upscaler=" + upscalerMode
                    + " fg=" + fgEnabled + ")");
        }
        if ((upscalerMode == 0 && fgEnabled == 0) || nativeFailed) return;
        // The upscale is normally recorded at the blit point (see
        // onEncoderSignalSemaphore). This is the fallback for the case that
        // the game did not run through blitFromTexture this frame.
        if (!frameRecordPending) return;
        frameRecordPending = false;
        recordUpscaleInto(encoder);
    }

    /**
     * Called from VulkanCommandEncoder.signalSemaphore().
     *
     * VulkanGpuSurface.blitFromTexture() copies the rendered frame into the
     * swapchain and signals the present semaphore right after it. The hook
     * runs in that gap, so the FidelityFX upscale is recorded exactly where
     * the game's own copy is: the upscale replaces the game's copy instead of
     * overwriting the whole swapchain at the end of the frame, which wiped
     * out everything the game had drawn into it.
     */
    public static void onEncoderSignalSemaphore(Object encoder) {
        if (!dbgSignal) {
            dbgSignal = true;
            System.out.println("[Fsr3Bridge] onEncoderSignalSemaphore (upscaler="
                    + upscalerMode + " fg=" + fgEnabled + ")");
        }
        if (!frameRecordPending) return;
        if (encoder != null && lastEncoder != null && encoder != lastEncoder) return;
        frameRecordPending = false;
        recordUpscaleInto(encoder);
    }

    /**
     * Record the FidelityFX pass for this frame and insert the recorded
     * command buffer into the game's encoder.
     */
    private static void recordUpscaleInto(Object encoder) {
        if ((upscalerMode == 0 && fgEnabled == 0) || nativeFailed) return;
        Object surface = lastSurface;
        Object view = lastTextureView;
        if (surface == null || view == null) return;
        lastEncoder = encoder;
        try {
            ensureReflection();
            if (!ensureNativeInit()) return;

            long srcImage = (Long) textureVkImage.invoke(viewTexture.invoke(view));
            int srcW = (Integer) viewGetWidth.invoke(view, 0);
            int srcH = (Integer) viewGetHeight.invoke(view, 0);
            if (srcImage == 0 || srcW <= 0 || srcH <= 0) return;

            // The render texture's true format (GpuFormat enum name).
            int srcFormat = mapFormat(textureGetFormat.invoke(
                    viewTexture.invoke(view)).toString());

            long swapchainImage = 0;
            if (upscalerMode != Fsr3Native.MODE_NONE) {
                int imageIndex = surfaceCurrentImageIndex.getInt(surface);
                if (imageIndex < 0) return;
                swapchainImage = (Long) longListGetLong.invoke(
                        surfaceSwapchainImages.get(surface), imageIndex);
                if (swapchainImage == 0) return;
            }

            float[] cam = captureCamera();
            if (cam == null) return;

            int writtenSlot = Fsr3Native.recordUpscale(srcImage, srcW, srcH,
                    swapchainImage, srcFormat, cam, resetFlag);
            if (writtenSlot >= 0 && encoderClass().isInstance(encoder)) {
                long cb = Fsr3Native.lastRecordedCommandBuffer();
                if (cb != 0) {
                    org.lwjgl.vulkan.VkCommandBuffer lwjglCb =
                            new org.lwjgl.vulkan.VkCommandBuffer(cb, lwjglDevice);
                    encoderExecute.invoke(encoder, lwjglCb);
                }
            }
        } catch (Throwable t) {
            logOnce("upscale record failed: " + t);
            nativeFailed = true;
        }
    }

    public static void onPresent(Object surface) {
        if (!dbgPresent) {
            dbgPresent = true;
            System.out.println("[Fsr3Bridge] onPresent (surface=" + (surface != null)
                    + " fg=" + fgEnabled + ")");
        }
        if (fgEnabled == 0 || nativeFailed) return;
        try {
            ensureReflection();
            if (!nativeReady) return;
            long swapchain = surfaceSwapchain.getLong(surface);
            if (swapchain == 0) return;
            // Witch patch: multi-frame generation - present every generated
            // sub-frame produced by the last record pass, oldest first.
            int count = Fsr3Native.pendingFgSlotCount();
            for (int i = 0; i < count; i++) {
                int slot = Fsr3Native.pendingFgSlot(i);
                if (slot < 0) break;
                if (Fsr3Native.presentInterpolated(swapchain, slot) < 0) break;
            }
        } catch (Throwable t) {
            logOnce("onPresent failed: " + t);
            nativeFailed = true;
        }
    }

    // Witch patch: VulkanGpuSurface.configure / close destroy the swapchain
    // (and every presentable image) on the render thread. The bridge must
    // never present on cached images from the old swapchain afterwards.
    private static boolean dbgSurfaceConfigure, dbgSurfaceClose;

    public static void onSurfaceConfigure(Object surface, Object configuration) {
        if (!dbgSurfaceConfigure) {
            dbgSurfaceConfigure = true;
            System.out.println("[Fsr3Bridge] onSurfaceConfigure (surface="
                    + (surface != null) + " config=" + describeConfiguration(configuration)
                    + ")");
        }
        invalidateSwapchain(surface, "configure");
    }

    public static void onSurfaceClose(Object surface) {
        if (!dbgSurfaceClose) {
            dbgSurfaceClose = true;
            System.out.println("[Fsr3Bridge] onSurfaceClose (surface="
                    + (surface != null) + ")");
        }
        invalidateSwapchain(surface, "close");
    }

    private static void invalidateSwapchain(Object surface, String reason) {
        try {
            long swapchain = 0;
            if (surface != null) {
                ensureReflection();
                swapchain = surfaceSwapchain.getLong(surface);
            }
            if (nativeReady) {
                Fsr3Native.swapchainDestroyed(swapchain);
            }
            System.out.println("[Fsr3Bridge] swapchain invalidated (" + reason
                    + " handle=" + swapchain + ")");
        } catch (Throwable t) {
            logOnce("swapchain invalidate failed: " + t);
        }
    }

    private static String describeConfiguration(Object configuration) {
        if (configuration == null) return "null";
        try {
            Method w = configuration.getClass().getMethod("width");
            Method h = configuration.getClass().getMethod("height");
            Object width = w.invoke(configuration);
            Object height = h.invoke(configuration);
            // The surface size is the reference for the GUI size: the game
            // UI must not change its on-screen size when the render
            // resolution changes.
            if (width instanceof Number) {
                displayWidth = ((Number) width).intValue();
            }
            if (height instanceof Number) {
                displayHeight = ((Number) height).intValue();
            }
            return width + "x" + height;
        } catch (Throwable t) {
            return configuration.getClass().getSimpleName();
        }
    }

    // ---- Window getters (body-replaced) -----------------------------------------
    //
    // Witch patch: the GUI must not change its size when the FidelityFX
    // features are on. MC 26.3 draws the HUD into the main render target -
    // the same texture as the world - and its orthographic GUI projection
    // covers exactly WindowRenderState.width / WindowRenderState.guiScale
    // units, while the HUD is laid out in Window.getGuiScaledWidth() units.
    //
    // Scaling Window.getWidth() (the old "render scale") therefore shrank
    // the projection but not the layout space, and the whole HUD was drawn
    // 1.4x too big and ran off the screen. Reporting the game's own values
    // makes the FidelityFX features completely invisible to the GUI: the
    // render resolution is the launcher's resolution scale and the HUD is
    // exactly as large as it is without FSR/frame generation.

    public static int scaledWidth(Object window) {
        return readIntField(window, "framebufferWidth", 0);
    }

    public static int scaledHeight(Object window) {
        return readIntField(window, "framebufferHeight", 0);
    }

    public static int scaledGuiWidth(Object window) {
        return readIntField(window, "guiScaledWidth", 0);
    }

    public static int scaledGuiHeight(Object window) {
        return readIntField(window, "guiScaledHeight", 0);
    }

    /**
     * The GUI size of the game.
    /**
     * The GUI size of the game.
     *
     * The HUD is drawn into the game's main render target, NOT into the
     * swapchain: GuiRenderer.executeDrawRange() uses
     * GameRenderer.mainRenderTarget().getColorTextureView() as the colour
     * attachment. The target's size is Window.getWidth()/getHeight() (the
     * values GameRenderer.extractWindow() copies into WindowRenderState
     * every frame), and the GUI's orthographic projection covers exactly
     * [0, width/guiScale] x [0, height/guiScale] GUI units.
     *
     * The HUD is laid out in Window.getGuiScaledWidth() units, so the
     * agent must report the game's own value - anything else makes the HUD
     * a different size than the projection was built for (it was drawn
     * 1.4x too big and ran off the screen).
     */
    private static int guiSize(Object window, boolean width) {
        return width ? scaledGuiWidth(window) : scaledGuiHeight(window);
    }

    /**
     * The GUI scale the game uses (its own setting, never changed).
     *
     * Only used for the diagnostic below: the agent does not touch the
     * game's GUI scale any more.
     */
    private static int effectiveGuiScale(int width, int height) {
        int userScale = readGuiScaleOption();
        int i = 1;
        while (i != userScale && width >= i && height >= i
                && width / (i + 1) >= 320 && height / (i + 1) >= 240) {
            i++;
        }
        if (forceUnicodeFont() && (i % 2) != 0) {
            i++;
        }
        return Math.max(1, Math.min(12, i));
    }

    /** The GUI scale the user picked in the options (0 = automatic). */
    private static int readGuiScaleOption() {
        try {
            Object mc = minecraft;
            if (mc == null || mcOptionsField == null) return 0;
            Object options = mcOptionsField.get(mc);
            if (options == null) return 0;
            Object optInstance = optionsGuiScale.invoke(options);
            Object value = optionInstanceGet.invoke(optInstance);
            return ((Number) value).intValue();
        } catch (Throwable t) {
            return 0;
        }
    }

    /** Whether the game forces the unicode font (it bumps odd GUI scales). */
    private static boolean forceUnicodeFont() {
        try {
            Object mc = minecraft;
            if (mc == null || minecraftIsEnforceUnicode == null) return false;
            return (Boolean) minecraftIsEnforceUnicode.invoke(mc);
        } catch (Throwable t) {
            return false;
        }
    }

    private static int readIntField(Object obj, String name, int fallback) {
        if (obj == null) return fallback;
        try {
            Field f = obj.getClass().getDeclaredField(name);
            f.setAccessible(true);
            return f.getInt(obj);
        } catch (Throwable t) {
            return fallback;
        }
    }

    // ---- native init ------------------------------------------------------------

    private static boolean ensureNativeInit() throws Exception {
        if (nativeReady) return true;
        if (nativeFailed) return false;

        Object surface = lastSurface;
        Object view = lastTextureView;
        if (surface == null || view == null) return false;

        Object deviceObj = surfaceDevice.get(surface);
        if (deviceObj == null) {
            logOnce("no VulkanDevice on surface");
            nativeFailed = true;
            return false;
        }

        org.lwjgl.vulkan.VkDevice vkDev = (org.lwjgl.vulkan.VkDevice) deviceVkDevice.invoke(deviceObj);
        lwjglDevice = vkDev;
        long deviceAddr = vkDev.address();

        long physAddr = 0;
        try {
            Method getPhys = org.lwjgl.vulkan.VkDevice.class.getMethod("getPhysicalDevice");
            org.lwjgl.vulkan.VkPhysicalDevice phys =
                    (org.lwjgl.vulkan.VkPhysicalDevice) getPhys.invoke(vkDev);
            physAddr = phys.address();
        } catch (Throwable t) {
            logOnce("VkDevice.getPhysicalDevice unavailable: " + t);
        }

        Object queueRec = deviceGraphicsQueue.invoke(deviceObj);
        org.lwjgl.vulkan.VkQueue vkQueue =
                (org.lwjgl.vulkan.VkQueue) queueVkQueue.invoke(queueRec);
        int family = (Integer) queueFamilyIdx.invoke(queueRec);

        long gdpa = 0;
        try {
            Object provider = org.lwjgl.vulkan.VK.getFunctionProvider();
            Method getAddr = provider.getClass().getMethod("getFunctionAddress", String.class);
            gdpa = (Long) getAddr.invoke(provider, "vkGetDeviceProcAddr");
        } catch (Throwable t) {
            logOnce("LWJGL function provider unavailable, native dlsym fallback");
        }

        // Formats: the swapchain's raw VkFormat (bridge-owned outputs must
        // match it for correct blits) and the render texture's GpuFormat.
        int vkFormat = surfaceSwapchainImageFormat.getInt(surface);
        if (vkFormat <= 0) {
            vkFormat = 44; // VK_FORMAT_B8G8R8A8_UNORM
        }
        int srcFormat = mapFormat(textureGetFormat.invoke(
                viewTexture.invoke(view)).toString());

        int renderW = (Integer) viewGetWidth.invoke(view, 0);
        int renderH = (Integer) viewGetHeight.invoke(view, 0);
        int displayW = surfaceSwapchainWidth.getInt(surface);
        int displayH = surfaceSwapchainHeight.getInt(surface);
        // The jitter is expressed in render pixels and the projection skew
        // is derived from the render size.
        renderWidth = renderW;
        renderHeight = renderH;

        int rc = Fsr3Native.init(deviceAddr, physAddr, gdpa, vkQueue.address(), family,
                upscalerMode, fgEnabled, sharpness,
                renderW, renderH, displayW, displayH, vkFormat, srcFormat, 0);
        if (rc != 0) {
            logOnce("Fsr3Native.init failed rc=" + rc);
            nativeFailed = true;
            return false;
        }
        nativeReady = true;
        // The multiplier is a configuration value, not a run-time switch:
        // push it even when frame generation is currently off, otherwise the
        // native side keeps its default (fgx=2) and ignores the user setting.
        int fgRc = Fsr3Native.setFgMultiplier(fgMultiplier);
        if (fgRc != 0) {
            logOnce("setFgMultiplier(" + fgMultiplier + ") failed rc=" + fgRc);
        }
        if (probe != 0) {
            Fsr3Native.setProbe(probe);
        }
        System.out.println("[Fsr3Bridge] native init ok (upscaler=" + upscalerMode
                + " fg=" + fgEnabled + " fgx=" + fgMultiplier + " scale=" + scale
                + " sharp=" + sharpness + " probe=" + probe
                + " render=" + renderW + "x" + renderH
                + " display=" + displayW + "x" + displayH
                + " fmt=" + vkFormat + " srcFmt=" + srcFormat + ")");
        return true;
    }

    /**
     * Map a com.mojang.renderpearl.api.GpuFormat enum name to a VkFormat
     * value. The enum uses RGBA-style names (no BGRA - MoltenVK swapchains
     * are BGRA8 and are read from the surface's swapchainImageFormat int
     * instead, not from this mapping).
     */
    private static int mapFormat(String name) {
        if (name == null) return 37; // VK_FORMAT_R8G8B8A8_UNORM
        if (name.equals("RGBA8_UNORM")) return 37;
        if (name.equals("RGBA8_SNORM")) return 35;
        if (name.equals("RGBA16_UNORM")) return 93;
        if (name.equals("RGBA16_SNORM")) return 95;
        if (name.equals("RGBA16_FLOAT")) return 97;
        if (name.equals("RGBA32_FLOAT")) return 126;
        if (name.equals("RGB10A2_UNORM")) return 56;
        if (name.equals("RG11B10_FLOAT")) return 122;
        if (name.equals("R8_UNORM")) return 9;
        if (name.equals("RG8_UNORM")) return 16;
        if (name.equals("R16_FLOAT")) return 83;
        if (name.equals("RG16_FLOAT")) return 87;
        if (name.equals("R32_FLOAT")) return 100;
        if (name.equals("RG32_FLOAT")) return 107;
        return 37;
    }

    // ---- camera capture ----------------------------------------------------------

    private static float num(Object o) {
        return ((Number) o).floatValue();
    }

    private static float[] captureCamera() {
        try {
            Object mc = minecraft;
            if (mc == null) return null;
            Object gameRenderer = mcGameRendererField.get(mc);
            if (gameRenderer == null) return null;
            Object camera = gameRendererMainCamera().invoke(gameRenderer);

            Object pos = cameraPosition.invoke(camera);
            float px = num(vec3X.invoke(pos));
            float py = num(vec3Y.invoke(pos));
            float pz = num(vec3Z.invoke(pos));
            float xRot = num(cameraXRot.invoke(camera));
            float yRot = num(cameraYRot.invoke(camera));
            float fovDeg = num(cameraFov.invoke(camera));
            Object fwd = cameraForward.invoke(camera);
            Object up = cameraUp.invoke(camera);

            // 19 floats: 0-15 camera, 16-17 jitter, 18 eye height above the
            // ground (see the native contract in ffx_bridge.h).
            float[] cam = new float[19];
            cam[0] = px;
            cam[1] = py;
            cam[2] = pz;
            // Witch patch: the camera basis. The "right" slot used to hold
            // -forward, which is not a view basis at all (right must be
            // perpendicular to forward and up). The synthetic motion
            // vectors are built from that basis, so the broken right vector
            // produced garbage motion vectors - the FSR2/FSR3 temporal
            // accumulation reprojected the history with them and the frame
            // interpolation warped the generated frames (double images,
            // smeared blocks).
            float fx = num(v3fX.invoke(fwd));
            float fy = num(v3fY.invoke(fwd));
            float fz = num(v3fZ.invoke(fwd));
            float ux = num(v3fX.invoke(up));
            float uy = num(v3fY.invoke(up));
            float uz = num(v3fZ.invoke(up));
            // right = forward x up (right handed: +x when looking down -z).
            float rx = fy * uz - fz * uy;
            float ry = fz * ux - fx * uz;
            float rz = fx * uy - fy * ux;
            float rightLength = (float) Math.sqrt(rx * rx + ry * ry + rz * rz);
            if (rightLength > 1e-6f) {
                rx /= rightLength;
                ry /= rightLength;
                rz /= rightLength;
            }
            cam[3] = rx;
            cam[4] = ry;
            cam[5] = rz;
            cam[6] = ux;
            cam[7] = uy;
            cam[8] = uz;
            cam[9] = fx;
            cam[10] = fy;
            cam[11] = fz;
            cam[12] = 0.05f; // near
            cam[13] = 64.0f; // far (synthetic depth constant anyway)
            cam[14] = (float) Math.toRadians(fovDeg);

            long now = System.nanoTime();
            if (lastSubmitNanos == 0) {
                cam[15] = 16.666f;
            } else {
                cam[15] = (float) Math.max(1.0, Math.min(100.0, (now - lastSubmitNanos) / 1e6));
            }
            lastSubmitNanos = now;
            // The sub-pixel jitter this frame was rendered with. The native
            // side feeds it to the upscaler as the frame's jitter offset so
            // that the accumulation lines the frames up correctly.
            cam[16] = appliedJitterX;
            cam[17] = appliedJitterY;
            // Height of the eye above the ground the player stands on. The
            // native side uses it to derive the distance of the ground pixels
            // from the ground plane instead of assuming one constant for the
            // whole screen, which cuts the parallax error of a walking camera
            // by 3-7x. Zero when the player is not on the ground (flying,
            // jumping, swimming) - the constant reference depth is used then.
            cam[18] = groundEyeHeight();

            boolean reset = false;
            if (havePrevCam) {
                float dPos = Math.abs(px - prevCamX) + Math.abs(py - prevCamY) + Math.abs(pz - prevCamZ);
                // Camera angles are degrees and wrap at +/-180, so compare
                // wrapped deltas: 179 -> -179 is a 2 degree turn, not 358.
                float dRot = Math.abs(wrapDegrees(xRot - prevXRot))
                        + Math.abs(wrapDegrees(yRot - prevYRot));
                // Only a genuine discontinuity resets the temporal history:
                // a >4 block jump (teleport) or a 90 degree camera cut.
                // Ordinary mouse look must NOT reset it - the FSR2/FSR3
                // accumulation and the FG motion vectors need the history.
                if (dPos > CAMERA_TELEPORT_DISTANCE || dRot > CAMERA_CUT_ROTATION) {
                    reset = true;
                    logHistoryReset(dPos, dRot);
                }
            } else {
                reset = true;
            }
            prevCamX = px; prevCamY = py; prevCamZ = pz;
            prevXRot = xRot; prevYRot = yRot;
            havePrevCam = true;
            resetFlag = reset ? 1 : 0;

            return cam;
        } catch (Throwable t) {
            // A camera capture failure disables the whole FidelityFX path
            // (no motion vectors, no upscale, no frame generation) but the
            // game keeps running, so the failure looks like "the feature does
            // not work". Make it loud and keep counting it.
            cameraFailures++;
            if (cameraFailures <= 5 || cameraFailures % 300 == 0) {
                System.out.println("[Fsr3Bridge] camera capture failed ("
                        + cameraFailures + "): " + t);
                if (cameraFailures == 1) {
                    System.out.println("[Fsr3Bridge] FidelityFX is DISABLED "
                            + "until the camera capture works");
                }
            }
            return null;
        }
    }

    private static int cameraFailures = 0;

    private static int resetFlag = 1;

    // Wrap a degree delta into [-180, 180] so a camera angle crossing
    // +/-180 (e.g. 179 -> -179) counts as a 2 degree turn, not 358.
    private static float wrapDegrees(float delta) {
        float wrapped = delta % 360.0f;
        if (wrapped > 180.0f) wrapped -= 360.0f;
        else if (wrapped < -180.0f) wrapped += 360.0f;
        return wrapped;
    }

    // Rate-limited log of the temporal-history resets. A reset makes the
    // frame interpolation fall back to the game motion vectors for the
    // next frames, so a frequent reset shows up as ghosting.
    private static long lastResetLogNanos = 0;

    private static void logHistoryReset(float dPos, float dRot) {
        long now = System.nanoTime();
        if (now - lastResetLogNanos < 1000000000L) return;
        lastResetLogNanos = now;
        System.out.println("[Fsr3Bridge] history reset (dPos=" + dPos
                + " dRot=" + dRot + ")");
    }

    // ---- reflection ---------------------------------------------------------------

    private static void ensureReflection() throws Exception {
        if (reflectionReady) return;
        Object mc = minecraft;
        if (mc == null) throw new IllegalStateException("Minecraft not captured yet");
        ClassLoader cl = mc.getClass().getClassLoader();

        Class<?> mcClass = mc.getClass();
        mcGetWindow = mcClass.getMethod("getWindow");
        mcGameRendererField = mcClass.getField("gameRenderer");
        // The local player: its on-ground state and position decide whether
        // the ground plane can be used for the motion vectors.
        mcPlayerField = mcClass.getField("player");
        Class<?> entityClass = cl.loadClass("net.minecraft.world.entity.Entity");
        entityOnGround = entityClass.getMethod("onGround");
        entityGetY = entityClass.getMethod("getY");

        // The GUI scale: the user's option and the unicode flag decide the
        // automatic scale (Window.calculateScale).
        try {
            mcOptionsField = mcClass.getField("options");
            Class<?> optionsClass = cl.loadClass("net.minecraft.client.Options");
            optionsGuiScale = optionsClass.getMethod("guiScale");
            optionInstanceGet = cl.loadClass("net.minecraft.client.OptionInstance")
                    .getMethod("get");
            minecraftIsEnforceUnicode = mcClass.getMethod("isEnforceUnicode");
        } catch (Throwable t) {
            mcOptionsField = null;
            optionsGuiScale = null;
            optionInstanceGet = null;
            minecraftIsEnforceUnicode = null;
            System.out.println("[Fsr3Bridge] GUI scale options not reachable: " + t);
        }

        Class<?> cameraClass = cl.loadClass("net.minecraft.client.Camera");
        cameraPosition = cameraClass.getMethod("position");
        cameraXRot = cameraClass.getMethod("xRot");
        cameraYRot = cameraClass.getMethod("yRot");
        cameraFov = cameraClass.getMethod("getFov");
        cameraForward = cameraClass.getMethod("forwardVector");
        cameraUp = cameraClass.getMethod("upVector");

        Class<?> vec3 = cl.loadClass("net.minecraft.world.phys.Vec3");
        vec3X = vec3.getMethod("x");
        vec3Y = vec3.getMethod("y");
        vec3Z = vec3.getMethod("z");

        Class<?> v3fc = cl.loadClass("org.joml.Vector3fc");
        v3fX = v3fc.getMethod("x");
        v3fY = v3fc.getMethod("y");
        v3fZ = v3fc.getMethod("z");

        Class<?> surfaceC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanGpuSurface");
        surfaceSwapchain = surfaceC.getDeclaredField("swapchain");
        surfaceSwapchain.setAccessible(true);
        surfaceSwapchainImages = surfaceC.getDeclaredField("swapchainImages");
        surfaceSwapchainImages.setAccessible(true);
        surfaceCurrentImageIndex = surfaceC.getDeclaredField("currentImageIndex");
        surfaceCurrentImageIndex.setAccessible(true);
        surfaceSwapchainWidth = surfaceC.getDeclaredField("swapchainWidth");
        surfaceSwapchainWidth.setAccessible(true);
        surfaceSwapchainHeight = surfaceC.getDeclaredField("swapchainHeight");
        surfaceSwapchainHeight.setAccessible(true);
        surfaceSwapchainImageFormat = surfaceC.getDeclaredField("swapchainImageFormat");
        surfaceSwapchainImageFormat.setAccessible(true);
        surfaceDevice = surfaceC.getDeclaredField("device");
        surfaceDevice.setAccessible(true);

        Class<?> deviceC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanDevice");
        deviceVkDevice = deviceC.getMethod("vkDevice");
        deviceGraphicsQueue = deviceC.getMethod("graphicsQueue");

        Class<?> queueC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanQueue");
        queueVkQueue = queueC.getMethod("vkQueue");
        queueFamilyIdx = queueC.getMethod("queueFamilyIndex");

        Class<?> viewC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanGpuTextureView");
        viewGetWidth = viewC.getMethod("getWidth", int.class);
        viewGetHeight = viewC.getMethod("getHeight", int.class);
        viewTexture = viewC.getMethod("texture");

        // The VkImage lives on VulkanGpuTexture, not on the view; the view
        // only exposes texture() (BaseGpuTextureView getWidth/getHeight).
        Class<?> textureC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanGpuTexture");
        textureVkImage = textureC.getMethod("vkImage");
        textureGetFormat = textureC.getMethod("getFormat");

        Class<?> encoderC = cl.loadClass("com.mojang.renderpearl.backend.vulkan.VulkanCommandEncoder");
        encoderExecute = encoderC.getMethod("execute", org.lwjgl.vulkan.VkCommandBuffer.class);

        Class<?> longListC = cl.loadClass("it.unimi.dsi.fastutil.longs.LongList");
        longListGetLong = longListC.getMethod("getLong", int.class);

        // ProjectionMatrixBuffer internals: the upload cache has to be
        // dropped so a per-frame sub-pixel jitter reaches the GPU.
        try {
            Class<?> projC = cl.loadClass("net.minecraft.client.renderer.ProjectionMatrixBuffer");
            projectionBufferLastUploaded = projC.getDeclaredField("lastUploadedProjection");
            projectionBufferLastUploaded.setAccessible(true);
            projectionBufferVersion = projC.getDeclaredField("projectionMatrixVersion");
            projectionBufferVersion.setAccessible(true);
        } catch (Throwable t) {
            projectionBufferLastUploaded = null;
            projectionBufferVersion = null;
            System.out.println("[Fsr3Bridge] projection buffer cache not reachable: " + t);
        }

        reflectionReady = true;
        System.out.println("[Fsr3Bridge] reflection ready");
    }

    private static Method gameRendererMainCamera;

    private static Method gameRendererMainCamera() throws Exception {
        if (gameRendererMainCamera == null) {
            ClassLoader cl = minecraft.getClass().getClassLoader();
            Class<?> gr = cl.loadClass("net.minecraft.client.renderer.GameRenderer");
            gameRendererMainCamera = gr.getMethod("mainCamera");
        }
        return gameRendererMainCamera;
    }

    private static Class<?> encoderClass() throws Exception {
        // Cached via ensureReflection; safe to re-derive here.
        return Class.forName("com.mojang.renderpearl.backend.vulkan.VulkanCommandEncoder",
                false, minecraft.getClass().getClassLoader());
    }

    private static void logOnce(String message) {
        // Render-thread logging: rate limit by keying off a flag reset per second.
        long now = System.currentTimeMillis();
        if (now - lastLogMillis > 1000) {
            lastLogMillis = now;
            System.err.println("[Fsr3Bridge] " + message);
        }
    }

    private static long lastLogMillis = 0;
}
