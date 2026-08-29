package net.kdt.pojavlaunch;

import java.beans.Beans;
import java.io.*;
import java.lang.reflect.Field;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.*;
import java.util.concurrent.*;
import java.util.zip.*;

import org.lwjgl.glfw.CallbackBridge;
import org.lwjgl.glfw.GLFW;

import net.kdt.pojavlaunch.uikit.*;
import net.kdt.pojavlaunch.touchcontroller.TouchControllerManager;
import net.kdt.pojavlaunch.utils.*;
import net.kdt.pojavlaunch.value.*;

public class PojavLauncher {
    private static float currProgress, maxProgress;

    public static void main(String[] args) throws Throwable {
        // Skip calling to com.apple.eawt.Application.nativeInitializeApplicationDelegate()
        Beans.setDesignTime(true);
        try {
            // Some places use macOS-specific code, which is unavailable on iOS
            // In this case, try to get it to use Linux-specific code instead.
            com.apple.eawt.Application.getApplication();
            Class clazz = Class.forName("com.apple.eawt.Application");
            Field field = clazz.getDeclaredField("sApplication");
            field.setAccessible(true);
            field.set(null, null);
            sun.font.FontUtilities.isLinux = true;
            System.setProperty("java.util.prefs.PreferencesFactory", "java.util.prefs.FileSystemPreferencesFactory");
        } catch (Throwable th) {
            // Not on JRE8, ignore exception
            //Tools.showError(th);
        }

        // Ensure JNA uses a writable directory with valid code signing support
        String pojavHome = System.getenv("POJAV_HOME");
        if (pojavHome != null) {
            String jnaTmpDir = pojavHome + "/jna_tmp";
            new File(jnaTmpDir).mkdirs();
            System.setProperty("jna.tmpdir", jnaTmpDir);
            System.setProperty("jna.nosys", "true");
            System.setProperty("jna.boot.library.path", jnaTmpDir);
        }

        // Create logs directory before any class loading triggers log4j init.
        // Fabric/Forge log4j configs write logs/latest.log relative to user.dir.
        try {
            new File(System.getProperty("user.dir"), "logs").mkdirs();
        } catch (Exception ignored) {}

        // Skip JNA's internal class-initialization that tries to dlopen dyld
        // shared-cache images (non-existent on iOS), preventing spurious
        // UnsatisfiedLinkError during Native.<clinit>
        System.setProperty("jna.nounpack", "true");
        System.setProperty("jna.noclassinit", "true");

        Thread.currentThread().setUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {

            public void uncaughtException(Thread t, Throwable th) {
                System.err.println("===== UNCAUGHT EXCEPTION on thread: " + t.getName() + " =====");
                th.printStackTrace();
                System.err.println("===== END UNCAUGHT EXCEPTION =====");
                System.err.flush();
                System.out.flush();
                try { Thread.sleep(500); } catch (InterruptedException e) {}
                System.exit(1);
            }
        });

        try {
            // Try to initialize Caciocavallo17
            Class.forName("com.github.caciocavallosilano.cacio.ctc.CTCPreloadClassLoader");
        } catch (ClassNotFoundException e) {}

        String runJar = System.getProperty("pojav.runJar");
        if (runJar != null) {
            // Forge/NeoForge installers: run headless with --installClient into the
            // game directory (POJAV_GAME_DIR), which the ObjC side passes as
            // -Dpojav.installDir=... when launching the installer jar.
            String installDir = System.getProperty("pojav.installDir");
            String[] jarArgs = (installDir != null && !installDir.isEmpty())
                ? new String[]{"--installClient", installDir}
                : new String[0];
            // The ObjC installer progress UI writes a marker file to cancel the
            // install; halt the JVM as soon as it appears (installers write their
            // output synchronously, so a halt here is safe).
            String cancelFile = System.getProperty("pojav.cancelFile");
            if (cancelFile != null && !cancelFile.isEmpty()) {
                final File cancelMarker = new File(cancelFile);
                Thread cancelWatcher = new Thread(() -> {
                    try {
                        while (!cancelMarker.exists()) {
                            Thread.sleep(400);
                        }
                        System.out.println("[Launcher] Install cancelled by user, stopping JVM");
                        System.out.flush();
                        Runtime.getRuntime().halt(130);
                    } catch (InterruptedException e) {
                        // watcher stopped
                    }
                }, "pojav-install-cancel-watcher");
                cancelWatcher.setDaemon(true);
                cancelWatcher.start();
            }
            UIKit.callback_JavaGUIViewController_launchJarFile(runJar, jarArgs);
        } else {
            try {
                launchMinecraft(args);
            } catch (Throwable th) {
                System.err.println("===== FATAL ERROR in launchMinecraft =====");
                th.printStackTrace();
                System.err.println("===== END FATAL ERROR =====");
                System.exit(1);
            }
        }
    }

    private static String downloadLog4jConfig(JMinecraftVersionList.LoggingConfig logging) {
        if (logging == null || logging.client == null || logging.client.file == null) return null;
        String fileId = logging.client.file.id;
        String fileUrl = logging.client.file.url;
        if (fileId == null) return null;

        // Known bundled configs
        if ("client-1.12.xml".equals(fileId)) {
            return Tools.DIR_BUNDLE + "/log4j-rce-patch-1.12.xml";
        }
        if ("client-1.7.xml".equals(fileId)) {
            return Tools.DIR_BUNDLE + "/log4j-rce-patch-1.7.xml";
        }

        // For unknown config IDs, try to download from the provided URL
        if (fileUrl == null) return null;

        String localPath = Tools.DIR_GAME_NEW + "/log4j/" + fileId;
        File localFile = new File(localPath);
        if (localFile.exists()) {
            return localPath;
        }

        try {
            System.out.println("Downloading log4j config: " + fileId + " from " + fileUrl);
            localFile.getParentFile().mkdirs();
            URL url = new URL(fileUrl);
            try (InputStream in = url.openStream()) {
                Files.copy(in, localFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
            System.out.println("Downloaded log4j config to: " + localPath);
            return localPath;
        } catch (Exception e) {
            System.err.println("Failed to download log4j config: " + fileId + " - " + e.getMessage());
            return null;
        }
    }

    // ============ LWJGL Library-order fix ============
    // The game's LWJGL (Fabric/Knot classloader) fails on JDK 25+ because eager
    // class init during System.load of the native executable initializes
    // org.lwjgl.glfw.GLFW before liblwjgl.dylib is registered: GLFWErrorCallbackI
    // <clinit> -> LibFFI.<clinit> -> FFI_TYPE_DOUBLE() throws UnsatisfiedLinkError
    // ("Could not initialize class org.lwjgl.glfw.GLFW"). Older builds of the
    // lwjgl jar call System.load(app binary) BEFORE loadSystem("org.lwjgl").
    // This patches the instance's lwjgl core jar with the fixed Library.class
    // (loadSystem first), matching lwjgl41's build.
    private static void patchInstanceLwjgl() {
        byte[] fixedLibrary = readResourceBytes("/lwjglfix/Library.class");
        if (fixedLibrary == null) {
            System.out.println("[LWJGLFix] fixed Library.class resource missing, skipping");
            return;
        }
        int patched = 0;
        File gameDir = new File(Tools.DIR_GAME_NEW);
        List<File> jars = new ArrayList<>();
        try {
            Files.walk(gameDir.toPath()).filter(p -> p.toString().endsWith(".jar"))
                .forEach(p -> jars.add(p.toFile()));
        } catch (IOException e) {
            System.err.println("[LWJGLFix] walk failed: " + e);
            return;
        }
        for (File jar : jars) {
            try {
                if (patchJarLibraryClass(jar, fixedLibrary)) patched++;
            } catch (Exception e) {
                System.err.println("[LWJGLFix] failed on " + jar + ": " + e);
            }
        }
        System.out.println("[LWJGLFix] patched " + patched + " lwjgl jar(s) under " + gameDir);
    }

    private static boolean patchJarLibraryClass(File jar, byte[] fixedLibrary) throws IOException {
        byte[] oldBytes = readJarEntry(jar, "org/lwjgl/system/Library.class");
        if (oldBytes == null) return false;
        if (Arrays.equals(oldBytes, fixedLibrary)) return false;
        File tmp = new File(jar.getParentFile(), jar.getName() + ".lwjglfix.tmp");
        byte[] buf = new byte[65536];
        try (ZipInputStream zin = new ZipInputStream(new FileInputStream(jar));
             ZipOutputStream zout = new ZipOutputStream(new FileOutputStream(tmp))) {
            ZipEntry in;
            while ((in = zin.getNextEntry()) != null) {
                ZipEntry out = new ZipEntry(in.getName());
                out.setTime(in.getTime());
                zout.putNextEntry(out);
                if (in.getName().equals("org/lwjgl/system/Library.class")) {
                    zout.write(fixedLibrary);
                } else {
                    int n;
                    while ((n = zin.read(buf)) > 0) zout.write(buf, 0, n);
                }
                zout.closeEntry();
            }
        }
        if (!tmp.renameTo(jar)) {
            Files.move(tmp.toPath(), jar.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
        System.out.println("[LWJGLFix] replaced Library.class in " + jar);
        return true;
    }

    // Mega-mods like Essential bundle unrelocated copies of LWJGL / blaze3d
    // platform classes inside their own jars. Fabric's Knot resolves classes
    // child-first across every game/mod jar BEFORE delegating to the launcher
    // classloader, so those REAL classes shadow the launcher's iOS shims
    // (com.mojang.blaze3d.platform.MacosUtil.IS_MACOS=false and the stubbed
    // GLFWNativeCocoa). Minecraft's macOS-only window utilities then execute
    // on iOS and die inside GLFWNativeCocoa$Functions.<clinit>
    // ("A required function is missing: glfwGetCocoaMonitor") as soon as such
    // a mod is installed.
    // Fix: overwrite the affected class files INSIDE every jar under the game
    // directory with the launcher's own shim bytecode (bundled under
    // /macosfix/), so no classloading order can pick the real ones anymore.
    // Same approach as patchInstanceLwjgl(); jars whose entries already match
    // are skipped, so repeat launches don't rewrite anything.
    private static void patchMacPlatformShims() {
        Map<String, byte[]> replacements = new HashMap<>();
        byte[] macosUtil = readResourceBytes("/macosfix/MacosUtil.class");
        if (macosUtil == null) {
            System.out.println("[MacShims] MacosUtil.class resource missing, skipping");
            return;
        }
        replacements.put("com/mojang/blaze3d/platform/MacosUtil.class", macosUtil);
        byte[] glfwNativeCocoa = readResourceBytes("/macosfix/GLFWNativeCocoa.class");
        if (glfwNativeCocoa != null) {
            replacements.put("org/lwjgl/glfw/GLFWNativeCocoa.class", glfwNativeCocoa);
            byte[] functions = readResourceBytes("/macosfix/GLFWNativeCocoa$Functions.class");
            if (functions != null) {
                replacements.put("org/lwjgl/glfw/GLFWNativeCocoa$Functions.class", functions);
            }
        }
        List<File> jars = new ArrayList<>();
        try {
            Files.walk(new File(Tools.DIR_GAME_NEW).toPath())
                .filter(p -> p.toString().endsWith(".jar"))
                .forEach(p -> jars.add(p.toFile()));
        } catch (IOException e) {
            System.err.println("[MacShims] walk failed: " + e);
            return;
        }
        int patched = 0;
        for (File jar : jars) {
            try {
                if (replaceJarEntries(jar, replacements)) patched++;
            } catch (Exception e) {
                System.err.println("[MacShims] failed on " + jar + ": " + e);
            }
        }
        System.out.println("[MacShims] patched " + patched + " jar(s) under " + Tools.DIR_GAME_NEW);
    }

    private static boolean isJarSignatureFile(String name) {
        String lower = name.toLowerCase(java.util.Locale.ROOT);
        return lower.startsWith("meta-inf/")
            && (lower.endsWith(".sf") || lower.endsWith(".rsa") || lower.endsWith(".dsa"));
    }

    private static boolean replaceJarEntries(File jar, Map<String, byte[]> replacements) throws IOException {
        // Cheap central-directory check first: only rewrite when a target
        // entry exists AND differs from its replacement — or when the jar was
        // rewritten earlier but still carries JAR-signature files: Mojang
        // signs the client jar, so replacing a class underneath the old
        // digests makes Knot's JarVerifier reject EVERY read from that jar
        // ("SecurityException: SHA-384 digest error"). Dropping *.SF/*.RSA/
        // *.DSA disables verification for the jar (Fabric never verifies).
        boolean present = false;
        boolean differs = false;
        try (ZipFile zip = new ZipFile(jar)) {
            for (Map.Entry<String, byte[]> entry : replacements.entrySet()) {
                if (zip.getEntry(entry.getKey()) == null) continue;
                present = true;
                if (!Arrays.equals(readJarEntry(jar, entry.getKey()), entry.getValue())) {
                    differs = true;
                    break;
                }
            }
            boolean signed = false;
            if (present && !differs) {
                java.util.Enumeration<? extends ZipEntry> entries = zip.entries();
                while (entries.hasMoreElements()) {
                    if (isJarSignatureFile(entries.nextElement().getName())) {
                        signed = true;
                        break;
                    }
                }
            }
            if (!present || (!differs && !signed)) return false;
        }
        File tmp = new File(jar.getParentFile(), jar.getName() + ".macshim.tmp");
        byte[] buf = new byte[65536];
        try (ZipInputStream zin = new ZipInputStream(new FileInputStream(jar));
             ZipOutputStream zout = new ZipOutputStream(new FileOutputStream(tmp))) {
            ZipEntry in;
            while ((in = zin.getNextEntry()) != null) {
                if (isJarSignatureFile(in.getName())) continue;
                ZipEntry out = new ZipEntry(in.getName());
                out.setTime(in.getTime());
                zout.putNextEntry(out);
                byte[] replacement = replacements.get(in.getName());
                if (replacement != null) {
                    zout.write(replacement);
                } else {
                    int n;
                    while ((n = zin.read(buf)) > 0) zout.write(buf, 0, n);
                }
                zout.closeEntry();
            }
        }
        if (!tmp.renameTo(jar)) {
            Files.move(tmp.toPath(), jar.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
        System.out.println("[MacShims] patched " + jar);
        return true;
    }

    private static byte[] readJarEntry(File jar, String entryName) throws IOException {
        try (ZipFile zip = new ZipFile(jar)) {
            ZipEntry entry = zip.getEntry(entryName);
            if (entry == null) return null;
            try (InputStream in = zip.getInputStream(entry)) {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[65536];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                return out.toByteArray();
            }
        }
    }

    private static byte[] readResourceBytes(String path) {
        try (InputStream in = PojavLauncher.class.getResourceAsStream(path)) {
            if (in == null) return null;
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toByteArray();
        } catch (IOException e) {
            return null;
        }
    }

    // net.minecraft:launchwrapper:1.12 is required by Mixin's service
    // discovery (org.spongepowered.asm.service.mojang.MixinServiceLaunchWrapper
    // must be instantiable on the classpath, otherwise the ServiceLoader loop
    // in MixinService.initService dies with a fatal NoClassDefFoundError
    // before it can reach the loader's own service -> Quilt: "LaunchClassLoader
    // not found" before its Knot service is ever tried). The library is missing
    // from the downloaded instance profiles and from its usual maven locations,
    // so it is bundled into launcher.jar (resources/launchwrapper) and copied
    // here; Tools.generateLibClasspath picks it up automatically.
    private static void ensureLaunchWrapperLibrary() throws IOException {
        byte[] jarBytes = readResourceBytes("/launchwrapper/launchwrapper-1.12.jar");
        if (jarBytes == null) {
            System.out.println("[MixinFix] bundled launchwrapper jar missing, skipping");
            return;
        }
        File libFile = new File(Tools.DIR_HOME_LIBRARY + "/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar");
        if (libFile.exists() && libFile.length() == jarBytes.length) {
            System.out.println("[MixinFix] launchwrapper-1.12.jar already installed");
            return;
        }
        libFile.getParentFile().mkdirs();
        Tools.write(libFile.getAbsolutePath(), jarBytes);
        System.out.println("[MixinFix] installed " + libFile);
    }

    // Mixin's ServiceLoader iterates IMixinService providers in classpath
    // order and dies fatally (MixinServiceException "No mixin host service
    // available") when the first provider cannot be instantiated. The
    // LaunchWrapper + ModLauncher providers shipped inside the sponge-mixin jar
    // cannot be instantiated on iOS (net.minecraft.launchwrapper absent,
    // cpw.mods.modlauncher absent), and on Fabric/Quilt the sponge-mixin jar
    // sorts before the loader's own Knot service. Emptying its provider list
    // lets the loader's own MixinServiceKnot be selected. The Forge/NeoForge
    // mixin jars (named mixin-*) are not touched.
    private static void patchSpongeMixinServices() {
        int patched = 0;
        List<File> jars = new ArrayList<>();
        try {
            Files.walk(new File(Tools.DIR_GAME_NEW).toPath())
                .filter(p -> p.toString().endsWith(".jar"))
                .forEach(p -> jars.add(p.toFile()));
        } catch (IOException e) {
            System.err.println("[MixinFix] walk failed: " + e);
            return;
        }
        for (File jar : jars) {
            String name = jar.getName();
            if (!name.startsWith("sponge-mixin") || !name.endsWith(".jar")) continue;
            try {
                if (patchMixinServicesFile(jar)) patched++;
            } catch (Exception e) {
                System.err.println("[MixinFix] failed on " + jar + ": " + e);
            }
        }
        System.out.println("[MixinFix] patched " + patched + " sponge-mixin jar(s)");
    }

    private static boolean patchMixinServicesFile(File jar) throws IOException {
        byte[] providers = readJarEntry(jar, "META-INF/services/org.spongepowered.asm.service.IMixinService");
        if (providers == null) return false;
        if (providers.length == 0) return false; // already patched

        File tmp = new File(jar.getParentFile(), jar.getName() + ".mixinfix.tmp");
        byte[] buf = new byte[65536];
        try (ZipInputStream zin = new ZipInputStream(new FileInputStream(jar));
             ZipOutputStream zout = new ZipOutputStream(new FileOutputStream(tmp))) {
            ZipEntry in;
            while ((in = zin.getNextEntry()) != null) {
                ZipEntry out = new ZipEntry(in.getName());
                out.setTime(in.getTime());
                zout.putNextEntry(out);
                if (!in.getName().equals("META-INF/services/org.spongepowered.asm.service.IMixinService")) {
                    int n;
                    while ((n = zin.read(buf)) > 0) zout.write(buf, 0, n);
                }
                zout.closeEntry();
            }
        }
        Files.move(tmp.toPath(), jar.toPath(), StandardCopyOption.REPLACE_EXISTING);
        System.out.println("[MixinFix] emptied IMixinService providers in " + jar);
        return true;
    }

    public static void launchMinecraft(String[] args) throws Throwable {
        // Args for Spiral Knights
        System.setProperty("appdir", "./spiral");
        System.setProperty("resource_dir", "./spiral/rsrc");

        String sizeStr = System.getProperty("cacio.managed.screensize");
        System.setProperty("glfw.windowSize", sizeStr);
        String[] size = sizeStr.split("x");
        // The TouchController launcher-side JNI (IosSocketTransport etc.)
        // lives in libTouchControllerBridge.dylib, which the launcher loads
        // here so nativeInit() resolves in the launcher classloader.
        // IMPORTANT: do NOT System.load the main executable (AngelAuraAmethyst)
        // from the launcher: the game's Knot classloader must be the one that
        // loads it (via LWJGL's Library.<clinit>), otherwise Knot's load fails
        // with "already loaded in another classloader" and the game crashes
        // with UnsatisfiedLinkError on the first GLFW native call.
        try {
            System.load(System.getenv("BUNDLE_PATH") + "/Frameworks/libTouchControllerBridge.dylib");
        } catch (Throwable t) {
            System.err.println("[TouchController] TouchControllerBridge load failed: " + t);
        }
        // Initialize the TouchController proxy (dormant until here).
        // Must run in the launcher's classloader, before the game main class,
        // so the shared ring-buffer transport and JNI refs are ready.
        // Only spin it up when the game actually ships the touchcontroller
        // mod; otherwise the socket/daemon sits idle and can cause issues.
        boolean hasTouchControllerMod = Tools.hasModLibrary(Tools.getVersionInfo(args[1]), "touchcontroller");
        try {
            if (hasTouchControllerMod) {
                TouchControllerManager.getInstance().initialize(
                    Integer.parseInt(size[0]), Integer.parseInt(size[1]));
            }
        } catch (Throwable t) {
            // Optional; TouchController is unavailable in this game instance.
        }
        MCOptionUtils.load();
        MCOptionUtils.set("fullscreen", "false");
        MCOptionUtils.set("overrideWidth", size[0]);
        MCOptionUtils.set("overrideHeight", size[1]);
        // Default settings for performance
        MCOptionUtils.setDefault("mipmapLevels", "0");
        MCOptionUtils.setDefault("particles", "1");
        MCOptionUtils.setDefault("renderDistance", "2");
        MCOptionUtils.setDefault("simulationDistance", "5");
        // MoltenVK renderer = direct Vulkan → MoltenVK → Metal, no GL. Force the
        // game's preferredGraphicsBackend to "vulkan" (values: default/vulkan/opengl)
        // so MC 26.x doesn't fall back to its OpenGL backend.
        if ("libMoltenVK.dylib".equals(System.getenv("AMETHYST_RENDERER"))) {
            MCOptionUtils.set("preferredGraphicsBackend", "vulkan");
        }
        MCOptionUtils.save();

        // Setup Forge splash.properties
        File forgeSplashFile = new File(Tools.DIR_GAME_NEW, "config/splash.properties");
        if (System.getProperty("pojav.internal.keepForgeSplash") == null) {
            forgeSplashFile.getParentFile().mkdir();
            if (forgeSplashFile.exists()) {
                Tools.write(forgeSplashFile.getAbsolutePath(), Tools.read(forgeSplashFile.getAbsolutePath().replace("enabled=true", "enabled=false")));
            } else {
                Tools.write(forgeSplashFile.getAbsolutePath(), "enabled=false");
            }
        }

        System.setProperty("org.lwjgl.vulkan.libname", "libMoltenVK.dylib");

        // NOTE: SDL_SetMainReady is now called from the native side
        // (aasdl_setMainReady at pojavInit). Do NOT touch org.lwjgl.sdl.SDLMain
        // here: initializing LWJGL in the launcher's classloader preloads
        // liblwjgl.dylib, which then makes Fabric/Knot fail with
        // "Native Library liblwjgl.dylib already loaded in another classloader"
        // (Mojang's LWJGL runs in a separate classloader and tries to load the
        // same native library again).

        MinecraftAccount account = MinecraftAccount.load(args[0]);
        JMinecraftVersionList.Version version = Tools.getVersionInfo(args[1]);
        System.out.println("Launching Minecraft " + (version != null ? version.id : "null"));
        String configPath = downloadLog4jConfig(version != null ? version.logging : null);
        if (configPath != null) {
            System.setProperty("log4j.configurationFile", configPath);
        } else if (version != null && version.logging != null && version.logging.client != null) {
            // Set the argument directly if available, instead of log4j.configurationFile
            String log4jArg = version.logging.client.argument;
            if (log4jArg != null) {
                System.out.println("Using log4j argument: " + log4jArg);
            }
        }

        try {
            patchInstanceLwjgl();
        } catch (Throwable t) {
            System.err.println("[LWJGLFix] patch failed: " + t);
        }
        try {
            patchMacPlatformShims();
        } catch (Throwable t) {
            System.err.println("[MacShims] patch failed: " + t);
        }
        try {
            ensureLaunchWrapperLibrary();
        } catch (Throwable t) {
            System.err.println("[MixinFix] launchwrapper install failed: " + t);
        }
        try {
            patchSpongeMixinServices();
        } catch (Throwable t) {
            System.err.println("[MixinFix] sponge-mixin services patch failed: " + t);
        }
        try {
            net.kdt.pojavlaunch.touchcontroller.TransportPatcher.patchAll();
        } catch (Throwable t) {
            System.err.println("[TCLoader] touchcontroller Transport patch failed: " + t);
        }

        // Pre-extract the zstd-jni library Distant Horizons needs so DH's
        // java.library.path lookup succeeds (its own tmp extraction is
        // rejected by iOS unless the disable-library-validation entitlement
        // is present, and the load succeeded on the first try is far more
        // reliable than the second).
        try {
            String dhNativeDir = Tools.prepareDistantHorizonsNativeLib(version);
            if (dhNativeDir != null) {
                System.out.println("[DH Fix] DH native library ready at: " + dhNativeDir);
            }
        } catch (Throwable t) {
            System.err.println("[DH Fix] prepareDistHorizonsNativeLib failed: " + t);
        }

        Tools.launchMinecraft(account, version);
    }
}
