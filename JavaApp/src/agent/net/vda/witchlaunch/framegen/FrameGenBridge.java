package net.vda.witchlaunch.framegen;

/**
 * JNI bridge for Frame Generation.
 *
 * All native methods follow JNI naming convention (Java_net_vda_...).
 * The JVM resolves them automatically when libWitch.dylib is loaded —
 * no System.loadLibrary or RegisterNatives needed.
 */
public class FrameGenBridge {

    // Cached game classloader — set by FrameGenPatcher.transform() when it
    // first sees a Minecraft class. Without this, Class.forName() uses the
    // app classloader (launcher.jar) which cannot find game classes loaded
    // by PojavClassLoader (a child classloader).
    private static volatile ClassLoader gameClassLoader;

    public static void setGameClassLoader(ClassLoader cl) {
        if (cl != null && gameClassLoader == null) {
            gameClassLoader = cl;
        }
    }

    private static volatile boolean triedThreadScan;

    private static Class<?> findClass(String name) throws ClassNotFoundException {
        // 1. Try cached game classloader (set by FrameGenPatcher)
        ClassLoader cl = gameClassLoader;
        if (cl != null) {
            try { return Class.forName(name, true, cl); }
            catch (ClassNotFoundException ignored) {}
        }
        // 2. Try thread context classloader
        cl = Thread.currentThread().getContextClassLoader();
        if (cl != null) {
            try { return Class.forName(name, true, cl); }
            catch (ClassNotFoundException ignored) {}
        }
        // 3. Traverse parent classloaders from system
        cl = ClassLoader.getSystemClassLoader();
        while (cl != null) {
            try { return Class.forName(name, true, cl); }
            catch (ClassNotFoundException ignored) {}
            cl = cl.getParent();
        }
        // 4. Walk ALL threads' context classloaders (Fabric Knot bypass fix)
        //    KnotClassLoader is often only reachable from Fabric loader threads.
        if (!triedThreadScan) {
            triedThreadScan = true;
            Thread[] threads = new Thread[Thread.activeCount() + 16];
            int count = Thread.enumerate(threads);
            for (int i = 0; i < count; i++) {
                cl = threads[i].getContextClassLoader();
                if (cl == null) continue;
                try { return Class.forName(name, true, cl); }
                catch (ClassNotFoundException ignored) {}
                // Also try parent chain of each thread's classloader
                ClassLoader parent = cl.getParent();
                while (parent != null) {
                    try { return Class.forName(name, true, parent); }
                    catch (ClassNotFoundException ignored) {}
                    parent = parent.getParent();
                }
            }
            System.err.println("[FrameGenBridge] findClass: walked " + count
                + " threads, still cannot find " + name);
        }
        throw new ClassNotFoundException(name);
    }

    // --- Camera data update (via reflection) ---
    // captureCameraData() is called from native fg_on_next_drawable() via JNI.
    // It finds GameRenderer via MinecraftClient.getInstance() reflection —
    // no bytecode patching needed.

    /**
     * Called from native side (fg_on_next_drawable) each frame via JNI.
     * Finds GameRenderer through MinecraftClient.getInstance() and extracts
     * camera matrices. No bytecode modification required.
     */
    // Diagnostic counters (limited to avoid log spam)
    private static int noGRFieldCount;
    private static int nullGRCount;
    private static int cnfeCount;
    private static int camNotFoundCount;
    private static int camMethodFailCount;
    private static int fieldScanAttempts;

    // Cached Minecraft class and getInstance method (avoids reflection every frame)
    private static volatile Class<?> cachedMCClass;
    private static volatile java.lang.reflect.Method cachedGetInstance;

    // Cached GameRenderer field in Minecraft class
    private static volatile java.lang.reflect.Field cachedGRField;

    // Cached fields in GameRenderer: camera, matrices, window
    private static volatile java.lang.reflect.Field cachedCameraField;
    private static volatile java.lang.reflect.Field cachedMatricesField;
    private static volatile java.lang.reflect.Field cachedWindowField;
    private static volatile boolean fieldsScanned;

    // Both Mojang mappings ("Minecraft") and Yarn/Fabric mappings ("MinecraftClient")
    private static final String[] MC_CLASS_NAMES = {
        "net.minecraft.client.MinecraftClient",  // Fabric / Yarn
        "net.minecraft.client.Minecraft"         // Mojang mappings (1.20.5+)
    };

    /**
     * Find the Minecraft main class using multiple mapping names.
     * Caches the result after first successful lookup.
     */
    private static Class<?> findMinecraftClass() throws ClassNotFoundException {
        // Return cached result if available
        Class<?> cached = cachedMCClass;
        if (cached != null) return cached;

        // Try each known class name
        for (String name : MC_CLASS_NAMES) {
            try {
                Class<?> cl = findClass(name);
                cachedMCClass = cl;
                System.out.println("[FrameGenBridge] Found Minecraft class: " + name);
                return cl;
            } catch (ClassNotFoundException ignored) {}
        }

        throw new ClassNotFoundException("None of " + java.util.Arrays.toString(MC_CLASS_NAMES) + " found");
    }

    /**
     * Get MinecraftClient.getInstance() or Minecraft.getInstance().
     * Caches the Method after first successful lookup.
     */
    private static Object getMCInstance() throws Exception {
        Class<?> mcClass = findMinecraftClass();

        java.lang.reflect.Method getInstance = cachedGetInstance;
        if (getInstance == null) {
            getInstance = mcClass.getMethod("getInstance");
            cachedGetInstance = getInstance;
        }
        return getInstance.invoke(null);
    }

    /**
     * Find a field whose type name contains the given substring.
     * Searches declared fields first, then superclass fields.
     * Returns null if not found (does NOT throw).
     */
    private static java.lang.reflect.Field findFieldByType(Class<?> clazz, String typeSubstring) {
        // Search declared fields, then superclass hierarchy
        Class<?> current = clazz;
        while (current != null && current != Object.class) {
            try {
                for (java.lang.reflect.Field f : current.getDeclaredFields()) {
                    try {
                        String typeName = f.getType().getName();
                        if (typeName.contains(typeSubstring)) {
                            f.setAccessible(true);
                            return f;
                        }
                    } catch (Exception ignored) {}
                }
            } catch (Exception ignored) {}
            current = current.getSuperclass();
        }
        return null;
    }

    /**
     * Scan GameRenderer fields to find Camera, Matrices, Window.
     * Results are cached for subsequent frames.
     *
     * KEY FIX: Search by declared field type (f.getType()), not by field value.
     * Old code used f.get(obj).getType() which skips null fields — if Camera
     * is null on first call, it would never be found.
     *
     * Only marks fieldsScanned=true when Camera is found (retry otherwise).
     */
    private static void scanGameRendererFields(Object gameRenderer) {
        if (fieldsScanned) return;
        try {
            Class<?> grClass = gameRenderer.getClass();
            Class<?> current = grClass;
            while (current != null && current != Object.class) {
                try {
                    java.lang.reflect.Field[] fields = current.getDeclaredFields();
                    for (java.lang.reflect.Field f : fields) {
                        try {
                            f.setAccessible(true);

                            // Search by DECLARED field type name (works even if value is null)
                            String fieldTypeName = f.getType().getName().toLowerCase();

                            // Camera class
                            if (cachedCameraField == null && fieldTypeName.contains("camera")) {
                                cachedCameraField = f;
                                System.out.println("[FrameGenBridge] Found Camera field: " + f.getName()
                                    + " type=" + f.getType().getName());
                            }

                            // Matrices class
                            if (cachedMatricesField == null
                                    && (fieldTypeName.contains("matrices")
                                        || fieldTypeName.contains("matrixstack"))) {
                                cachedMatricesField = f;
                                System.out.println("[FrameGenBridge] Found Matrices field: " + f.getName()
                                    + " type=" + f.getType().getName());
                            }

                            // Window class
                            if (cachedWindowField == null && fieldTypeName.contains("window")) {
                                cachedWindowField = f;
                                System.out.println("[FrameGenBridge] Found Window field: " + f.getName()
                                    + " type=" + f.getType().getName());
                            }
                        } catch (Exception ignored) {}
                    }
                } catch (Exception ignored) {}
                current = current.getSuperclass();
            }

            // Fallback: if Camera not found by type name, try value-based scan
            // (handles obfuscated type names)
            if (cachedCameraField == null) {
                current = grClass;
                while (current != null && current != Object.class) {
                    try {
                        for (java.lang.reflect.Field f : current.getDeclaredFields()) {
                            if (cachedCameraField != null) break;
                            if (f.getType().isPrimitive()) continue;
                            try {
                                f.setAccessible(true);
                                Object val = f.get(gameRenderer);
                                if (val == null) continue;
                                // Check if value has getX/getY/getZ (Camera interface)
                                val.getClass().getMethod("getX");
                                val.getClass().getMethod("getY");
                                val.getClass().getMethod("getZ");
                                cachedCameraField = f;
                                System.out.println("[FrameGenBridge] Found Camera by value scan: " + f.getName()
                                    + " type=" + val.getClass().getName());
                            } catch (Exception ignored) {}
                        }
                    } catch (Exception ignored) {}
                    current = current.getSuperclass();
                }
            }

            // Diagnostic: list all GameRenderer fields if Camera still not found (first 3 attempts)
            if (cachedCameraField == null) {
                if (++fieldScanAttempts <= 3) {
                    current = grClass;
                    while (current != null && current != Object.class) {
                        try {
                            for (java.lang.reflect.Field f : current.getDeclaredFields()) {
                                System.out.println("[FrameGenBridge]   GR field: " + f.getName()
                                    + " -> " + f.getType().getName());
                            }
                        } catch (Exception ignored) {}
                        current = current.getSuperclass();
                    }
                }
                if (++camNotFoundCount <= 5) {
                    System.err.println("[FrameGenBridge] No Camera field found (attempt " + fieldScanAttempts + ")");
                }
            }

            // Mark scanned only if Camera found (retry next frame if not)
            if (cachedCameraField != null) {
                fieldsScanned = true;
            }
        } catch (Exception e) {
            if (++camNotFoundCount <= 5) {
                System.err.println("[FrameGenBridge] scanGameRendererFields error: " + e.getMessage());
            }
        }
    }

    public static void captureCameraData() {
        try {
            // Find Minecraft main class (try both mapping names)
            Object mc = getMCInstance();
            if (mc == null) return;
            Class<?> mcClass = mc.getClass();

            // Get gameRenderer field (cached or scan with superclass fallback)
            java.lang.reflect.Field grField = cachedGRField;
            if (grField == null) {
                grField = findFieldByType(mcClass, "GameRenderer");
                if (grField != null) {
                    cachedGRField = grField;
                } else {
                    if (++noGRFieldCount <= 5) System.err.println("[FrameGenBridge] No GameRenderer field found in " + mcClass.getName());
                    return;
                }
            }
            Object gameRenderer = grField.get(mc);
            if (gameRenderer == null) {
                if (++nullGRCount <= 5) System.err.println("[FrameGenBridge] GameRenderer instance is null");
                return;
            }

            updateCameraFromGameRenderer(gameRenderer);
        } catch (ClassNotFoundException e) {
            if (++cnfeCount <= 5) System.err.println("[FrameGenBridge] Cannot find Minecraft class: " + e.getMessage());
        } catch (Exception e) {
            if (++camNotFoundCount <= 5) System.err.println("[FrameGenBridge] captureCameraData error: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    /**
     * Extract camera data from GameRenderer via reflection and send to native FG.
     *
     * @param gameRenderer The GameRenderer instance
     */
    public static void updateCameraFromGameRenderer(Object gameRenderer) {
        try {
            if (gameRenderer == null) return;

            // Find Minecraft main class (try both Mojang and Yarn mappings)
            Object mc = getMCInstance();
            if (mc == null) return;

            // Find gameRenderer.camera (Camera object)
            // Field name is obfuscated but we can find it by type
            Object camera = null;
            Object matrices = null;
            Object window = null;

            // Use cached fields if available, otherwise scan once
            if (!fieldsScanned) {
                scanGameRendererFields(gameRenderer);
            }

            // Extract from cached fields
            try {
                if (cachedCameraField != null) {
                    camera = cachedCameraField.get(gameRenderer);
                }
            } catch (Exception ignored) {}
            try {
                if (cachedMatricesField != null) {
                    matrices = cachedMatricesField.get(gameRenderer);
                }
            } catch (Exception ignored) {}
            try {
                if (cachedWindowField != null) {
                    window = cachedWindowField.get(gameRenderer);
                }
            } catch (Exception ignored) {}

            // Extract camera position and rotation
            // Use individual try-catch per method — if one fails, others still work.
            float posX = 0, posY = 0, posZ = 0, pitch = 0, yaw = 0;
            boolean gotCamera = false;

            // Strategy 1: Camera.getX/Y/Z (Mojang mappings for MC 1.21+)
            if (camera != null) {
                try {
                    posX = ((Number) camera.getClass().getMethod("getX").invoke(camera)).floatValue();
                    posY = ((Number) camera.getClass().getMethod("getY").invoke(camera)).floatValue();
                    posZ = ((Number) camera.getClass().getMethod("getZ").invoke(camera)).floatValue();
                    gotCamera = true;
                } catch (Exception ignored) {}
                // Rotation: MC uses getXRot()/getYRot(), NOT getPitch()/getYaw()
                try {
                    pitch = ((Number) camera.getClass().getMethod("getXRot").invoke(camera)).floatValue();
                } catch (Exception ignored) {}
                try {
                    yaw = ((Number) camera.getClass().getMethod("getYRot").invoke(camera)).floatValue();
                } catch (Exception ignored) {}
            }

            // Strategy 2: Player entity (most reliable — always has world position)
            if (!gotCamera || (posX == 0 && posY == 0 && posZ == 0)) {
                try {
                    // try getCameraEntity() first (returns the entity the camera follows)
                    Object player = null;
                    try {
                        player = mc.getClass().getMethod("getCameraEntity").invoke(mc);
                    } catch (Exception ignored) {}
                    if (player == null) {
                        try { player = mc.getClass().getField("player").get(mc); } catch (Exception ignored) {}
                    }
                    if (player != null) {
                        try { posX = ((Number) player.getClass().getMethod("getX").invoke(player)).floatValue(); } catch (Exception ignored) {}
                        try { posY = ((Number) player.getClass().getMethod("getY").invoke(player)).floatValue(); } catch (Exception ignored) {}
                        try { posZ = ((Number) player.getClass().getMethod("getZ").invoke(player)).floatValue(); } catch (Exception ignored) {}
                        try { pitch = ((Number) player.getClass().getMethod("getXRot").invoke(player)).floatValue(); } catch (Exception ignored) {}
                        try { yaw = ((Number) player.getClass().getMethod("getYRot").invoke(player)).floatValue(); } catch (Exception ignored) {}
                        if (posX != 0 || posY != 0 || posZ != 0) {
                            gotCamera = true;
                        }
                    }
                } catch (Exception ignored) {}
            }

            // Extract view and projection matrices
            float[] viewMatrix = new float[16];
            float[] projMatrix = new float[16];
            // Initialize to identity
            viewMatrix[0] = viewMatrix[5] = viewMatrix[10] = viewMatrix[15] = 1.0f;
            projMatrix[0] = projMatrix[5] = projMatrix[10] = projMatrix[15] = 1.0f;

            if (matrices != null) {
                try {
                    // Try to get view matrix from matrices object
                    Object viewStack = matrices.getClass().getMethod("view").invoke(matrices);
                    if (viewStack != null) {
                        Object peek = viewStack.getClass().getMethod("peek").invoke(viewStack);
                        if (peek != null) {
                            Object positionMatrix = peek.getClass().getMethod("getPositionMatrix").invoke(peek);
                            // Extract float[16] from Matrix3f/Matrix4f
                            extractMatrix(positionMatrix, viewMatrix);
                        }
                    }
                } catch (Exception ignored) {}

                try {
                    // Try to get projection matrix
                    Object projStack = matrices.getClass().getMethod("projection").invoke(matrices);
                    if (projStack != null) {
                        Object peek = projStack.getClass().getMethod("peek").invoke(projStack);
                        if (peek != null) {
                            Object positionMatrix = peek.getClass().getMethod("getPositionMatrix").invoke(peek);
                            extractMatrix(positionMatrix, projMatrix);
                        }
                    }
                } catch (Exception ignored) {}
            }

            // Extract viewport size
            int width = 0, height = 0;
            if (window != null) {
                try {
                    width = ((Number) window.getClass().getMethod("getFramebufferWidth").invoke(window)).intValue();
                    height = ((Number) window.getClass().getMethod("getFramebufferHeight").invoke(window)).intValue();
                } catch (Exception ignored) {}
            }

            // A8: Get FOV via MinecraftClient.options.getFov().getValue()
            float fov = 70.0f;
            try {
                // Primary: MinecraftClient.getInstance().options.getFov().getValue()
                Object options = mc.getClass().getField("options").get(mc);
                if (options != null) {
                    Object fovOption = options.getClass().getMethod("getFov").invoke(options);
                    if (fovOption != null) {
                        fov = ((Number) fovOption.getClass().getMethod("getValue").invoke(fovOption)).floatValue();
                    }
                }
            } catch (Exception e) {
                // Fallback: scan GameRenderer fields for a float in [30,120]
                // that looks like a FOV field (not gamma, viewDistance, etc.)
                try {
                    java.lang.reflect.Field[] fields = gameRenderer.getClass().getDeclaredFields();
                    for (java.lang.reflect.Field f : fields) {
                        String fname = f.getName().toLowerCase();
                        // Skip known non-FOV fields
                        if (fname.contains("gamma") || fname.contains("distance")
                            || fname.contains("tick") || fname.contains("delta")
                            || fname.contains("progress") || fname.contains("alpha")) {
                            continue;
                        }
                        f.setAccessible(true);
                        if (f.getType() == float.class) {
                            float val = f.getFloat(gameRenderer);
                            if (val > 30.0f && val < 120.0f) {
                                fov = val;
                                break;
                            }
                        }
                    }
                } catch (Exception ignored) {}
            }

            // Send to native via JNI
            updateCamera(posX, posY, posZ, pitch, yaw, viewMatrix, projMatrix, fov, width, height);

        } catch (Exception e) {
            // Silently ignore — FG is best-effort
        }
    }

    /**
     * Extract float[16] from a Minecraft Matrix object (Matrix3f or Matrix4f).
     */
    private static void extractMatrix(Object matrixObj, float[] out) {
        if (matrixObj == null) return;
        try {
            // Try to get data() or getArray() method
            java.lang.reflect.Method getData = matrixObj.getClass().getMethod("getData");
            Object data = getData.invoke(matrixObj);
            if (data instanceof float[]) {
                float[] arr = (float[]) data;
                int len = Math.min(arr.length, 16);
                System.arraycopy(arr, 0, out, 0, len);
            }
        } catch (Exception ignored) {
            try {
                // Alternative: try to access fields directly
                java.lang.reflect.Field[] fields = matrixObj.getClass().getDeclaredFields();
                int idx = 0;
                for (java.lang.reflect.Field f : fields) {
                    if (f.getType() == float.class && idx < 16) {
                        f.setAccessible(true);
                        out[idx++] = f.getFloat(matrixObj);
                    }
                }
            } catch (Exception ignored2) {}
        }
    }

    // --- Native methods (resolved by JVM via JNI naming convention) ---

    public static native void updateCamera(
        float posX, float posY, float posZ,
        float pitch, float yaw,
        float[] viewMatrix,  // 16 floats column-major
        float[] projMatrix,  // 16 floats column-major
        float fov, int width, int height
    );

    public static native boolean isEnabled();

    public static native void setEnabled(boolean enabled);

    public static native boolean isSupported();
}
