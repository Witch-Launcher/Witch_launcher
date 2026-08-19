package net.kdt.pojavlaunch.uikit;

import java.io.*;
import java.lang.reflect.*;
import java.util.jar.*;
import net.kdt.pojavlaunch.utils.MCOptionUtils;
import net.kdt.pojavlaunch.*;

public class UIKit {
    public static final int ACTION_DOWN = 0;
    public static final int ACTION_UP = 1;
    public static final int ACTION_MOVE = 2;
    public static final int ACTION_MOVE_MOTION = 3;

    private static int guiScale;

    private static void patch_FlatLAF_setLinux() {
        String osName = System.getProperty("os.name");
        System.setProperty("os.name", "Linux");
        try {
            Class<?> clazz = ClassLoader.getSystemClassLoader().loadClass("com.formdev.flatlaf.util.SystemInfo");
            // trigger static init
            clazz.getField("isMacOS").get(null);
        } catch (Throwable e) {
            System.out.println("Skipped patch_FlatLAF_setLinux");
            //e.printStackTrace();
        }
        System.setProperty("os.name", osName);
    }

    public static void callback_JavaGUIViewController_launchJarFile(final String filepath, String[] args) throws Throwable {
        System.out.println("[JarLauncher] Launching JAR: " + filepath);

        JarFile jarfile = new JarFile(filepath);
        String mainClass = jarfile.getManifest().getMainAttributes().getValue("Main-Class");
        jarfile.close();
        if (mainClass == null) {
            throw new IllegalArgumentException("no main manifest attribute, in \"" + filepath + "\"");
        }
        System.out.println("[JarLauncher] Main class: " + mainClass);

        // Ensure user.home/Library/Application Support/minecraft exists (needed by OptiFine, Forge installers, etc.)
        String userHome = System.getProperty("user.home", ".");
        File mcDir = new File(userHome, "Library/Application Support/minecraft");
        if (!mcDir.exists()) {
            System.out.println("[JarLauncher] Creating " + mcDir.getAbsolutePath());
            mcDir.mkdirs();
        } else {
            System.out.println("[JarLauncher] " + mcDir.getAbsolutePath() + " already exists");
        }
        // Also create the user.dir working directory
        String userDir = System.getProperty("user.dir", ".");
        File workDir = new File(userDir);
        if (!workDir.exists()) {
            System.out.println("[JarLauncher] Creating " + workDir.getAbsolutePath());
            workDir.mkdirs();
        }

        // LabyMod Installer uses FlatLAF which has some macOS-specific codes, so we make it think it's running on Linux.
        patch_FlatLAF_setLinux();

        System.out.println("[JarLauncher] Loading class " + mainClass);
        Class<?> clazz = ClassLoader.getSystemClassLoader().loadClass(mainClass);
        Method method = clazz.getMethod("main", String[].class);
        System.out.println("[JarLauncher] Invoking main()");
        method.invoke(null, new Object[]{args});
        System.out.println("[JarLauncher] main() returned");
    }

    public static void updateMCGuiScale() {
        MCOptionUtils.load();
        String str = MCOptionUtils.get("guiScale");
        guiScale = (str == null ? 0 :Integer.parseInt(str));

        // Window size comes from the glfw.windowSize property set at launch;
        // do NOT read org.lwjgl.glfw.GLFW statics here — initializing LWJGL in
        // the launcher's classloader conflicts with Fabric/Knot's separate
        // classloader ("liblwjgl.dylib already loaded in another classloader").
        int winW = 1280, winH = 720;
        String sizeStr = System.getProperty("glfw.windowSize");
        if (sizeStr != null) {
            try {
                String[] size = sizeStr.split("x");
                winW = Integer.parseInt(size[0]);
                winH = Integer.parseInt(size[1]);
            } catch (Exception ignored) {}
        }
        int scale = Math.max(Math.min(winW / 320, winH / 240), 1);
        if(scale < guiScale || guiScale == 0){
            guiScale = scale;
        }
        updateMCGuiScale(guiScale);
    }

    static {
        // The executable name lives in the bundle's Info.plist
        // (CFBundleExecutable). Load it dynamically so renaming the app
        // (e.g. AngelAuraAmethyst -> Witch) does not break the JVM.
        String bundlePath = System.getenv("BUNDLE_PATH");
        String executableName = "Witch";
        try (BufferedReader reader = new BufferedReader(new FileReader(new File(bundlePath, "Info.plist")))) {
            String line;
            boolean inExecutableKey = false;
            while ((line = reader.readLine()) != null) {
                if (line.contains("<key>CFBundleExecutable</key>")) {
                    inExecutableKey = true;
                } else if (inExecutableKey && line.contains("<string>")) {
                    int start = line.indexOf("<string>") + 8;
                    int end = line.indexOf("</string>");
                    if (start > 8 && end > start) {
                        executableName = line.substring(start, end);
                    }
                    break;
                }
            }
        } catch (Exception ignored) {
            // fall back to the default executable name
        }
        System.load(bundlePath + "/" + executableName);
    }


    // public static native void runOnUIThread(UIKitCallback callback);

    public static native void showError(String title, String message, boolean exitIfOk);

    private static native void updateMCGuiScale(int scale);
} 
