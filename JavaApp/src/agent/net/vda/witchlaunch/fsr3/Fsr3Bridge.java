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
    private static volatile int upscalerMode = 0;
    private static volatile int fgEnabled = 0;
    private static volatile float scale = 1.0f;
    private static volatile float sharpness = 0.6f;

    // Per-frame state (render thread only).
    private static volatile Object minecraft;
    private static volatile Object lastSurface;
    private static volatile Object lastTextureView;
    private static volatile Object lastEncoder;

    // Native init state.
    private static volatile boolean nativeReady = false;
    private static volatile boolean nativeFailed = false;
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

    // Camera delta state for reset detection and frame time.
    private static long lastSubmitNanos = 0;
    private static float prevCamX, prevCamY, prevCamZ, prevXRot, prevYRot;
    private static boolean havePrevCam = false;

    public static void configure(int newUpscalerMode, int newFgEnabled,
                                 float newScale, float newSharpness) {
        upscalerMode = newUpscalerMode;
        fgEnabled = newFgEnabled != 0 ? 1 : 0;
        scale = newScale;
        sharpness = newSharpness;
    }

    // ---- hook callbacks ---------------------------------------------------------

    public static void onRenderFrame(Object mc) {
        minecraft = mc;
    }

    public static void onBlit(Object surface, Object encoder, Object textureView) {
        lastSurface = surface;
        lastEncoder = encoder;
        lastTextureView = textureView;
    }

    public static void onBeforeSubmit(Object encoder) {
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

            long cb = Fsr3Native.recordUpscale(srcImage, srcW, srcH,
                    swapchainImage, srcFormat, cam, resetFlag);
            if (cb != 0 && encoderClass().isInstance(encoder)) {
                org.lwjgl.vulkan.VkCommandBuffer lwjglCb =
                        new org.lwjgl.vulkan.VkCommandBuffer(cb, lwjglDevice);
                encoderExecute.invoke(encoder, lwjglCb);
            }
        } catch (Throwable t) {
            logOnce("onBeforeSubmit failed: " + t);
            nativeFailed = true;
        }
    }

    public static void onPresent(Object surface) {
        if (fgEnabled == 0 || nativeFailed) return;
        try {
            ensureReflection();
            if (!nativeReady) return;
            long swapchain = surfaceSwapchain.getLong(surface);
            if (swapchain == 0) return;
            int slot = Fsr3Native.lastFgSlot();
            if (slot < 0) return;
            Fsr3Native.presentInterpolated(swapchain, slot);
        } catch (Throwable t) {
            logOnce("onPresent failed: " + t);
            nativeFailed = true;
        }
    }

    // ---- Window getters (body-replaced) -----------------------------------------

    public static int scaledWidth(Object window) {
        return scaleValue(window, "framebufferWidth");
    }

    public static int scaledHeight(Object window) {
        return scaleValue(window, "framebufferHeight");
    }

    public static int scaledGuiWidth(Object window) {
        int guiScale = readIntField(window, "guiScale", 1);
        int scaled = scaleValue(window, "framebufferWidth");
        return Math.max(1, (int) Math.ceil((double) scaled / Math.max(1, guiScale)));
    }

    public static int scaledGuiHeight(Object window) {
        int guiScale = readIntField(window, "guiScale", 1);
        int scaled = scaleValue(window, "framebufferHeight");
        return Math.max(1, (int) Math.ceil((double) scaled / Math.max(1, guiScale)));
    }

    private static int scaleValue(Object window, String fieldName) {
        int raw = readIntField(window, fieldName, 0);
        if (raw <= 0) return raw;
        boolean upscalerActive = (upscalerMode == Fsr3Native.MODE_FSR1
                || upscalerMode == Fsr3Native.MODE_FSR2
                || upscalerMode == Fsr3Native.MODE_FSR3UPSCALE);
        if (!upscalerActive || scale >= 0.999f) return raw;
        return Math.max(1, (int) (raw * scale));
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

        int rc = Fsr3Native.init(deviceAddr, physAddr, gdpa, vkQueue.address(), family,
                upscalerMode, fgEnabled, sharpness,
                renderW, renderH, displayW, displayH, vkFormat, srcFormat, 0);
        if (rc != 0) {
            logOnce("Fsr3Native.init failed rc=" + rc);
            nativeFailed = true;
            return false;
        }
        nativeReady = true;
        System.out.println("[Fsr3Bridge] native init ok (upscaler=" + upscalerMode
                + " fg=" + fgEnabled + " scale=" + scale + " sharp=" + sharpness
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

    private static float[] captureCamera() {
        try {
            Object mc = minecraft;
            if (mc == null) return null;
            Object gameRenderer = mcGameRendererField.get(mc);
            if (gameRenderer == null) return null;
            Object camera = gameRendererMainCamera().invoke(gameRenderer);

            Object pos = cameraPosition.invoke(camera);
            float px = (Float) vec3X.invoke(pos);
            float py = (Float) vec3Y.invoke(pos);
            float pz = (Float) vec3Z.invoke(pos);
            float xRot = (Float) cameraXRot.invoke(camera);
            float yRot = (Float) cameraYRot.invoke(camera);
            float fovDeg = (Float) cameraFov.invoke(camera);
            Object fwd = cameraForward.invoke(camera);
            Object up = cameraUp.invoke(camera);

            float[] cam = new float[16];
            cam[0] = px;
            cam[1] = py;
            cam[2] = pz;
            cam[3] = (Float) v3fX.invoke(fwd) * -1f; // left -> right
            cam[4] = (Float) v3fY.invoke(fwd) * -1f;
            cam[5] = (Float) v3fZ.invoke(fwd) * -1f;
            cam[6] = (Float) v3fX.invoke(up);
            cam[7] = (Float) v3fY.invoke(up);
            cam[8] = (Float) v3fZ.invoke(up);
            cam[9] = (Float) v3fX.invoke(fwd);
            cam[10] = (Float) v3fY.invoke(fwd);
            cam[11] = (Float) v3fZ.invoke(fwd);
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

            boolean reset = false;
            if (havePrevCam) {
                float dPos = Math.abs(px - prevCamX) + Math.abs(py - prevCamY) + Math.abs(pz - prevCamZ);
                float dRot = Math.abs(xRot - prevXRot) + Math.abs(yRot - prevYRot);
                if (dPos > 4.0f || dRot > 0.6f) {
                    reset = true;
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
            logOnce("camera capture failed: " + t);
            return null;
        }
    }

    private static int resetFlag = 1;

    // ---- reflection ---------------------------------------------------------------

    private static void ensureReflection() throws Exception {
        if (reflectionReady) return;
        Object mc = minecraft;
        if (mc == null) throw new IllegalStateException("Minecraft not captured yet");
        ClassLoader cl = mc.getClass().getClassLoader();

        Class<?> mcClass = mc.getClass();
        mcGetWindow = mcClass.getMethod("getWindow");
        mcGameRendererField = mcClass.getField("gameRenderer");

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
