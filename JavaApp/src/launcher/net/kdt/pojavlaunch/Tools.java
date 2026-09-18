package net.kdt.pojavlaunch;

import android.util.ArrayMap;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileFilter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.jar.JarFile;
import java.util.zip.ZipEntry;
import net.kdt.pojavlaunch.uikit.UIKit;
import net.kdt.pojavlaunch.utils.JSONUtils;
import net.kdt.pojavlaunch.value.DependentLibrary;
import net.kdt.pojavlaunch.value.MinecraftAccount;
import net.kdt.pojavlaunch.value.MinecraftLibraryArtifact;

public final class Tools {
    public static final Gson GLOBAL_GSON = new GsonBuilder().setPrettyPrinting().create();

    public static final String DIR_BUNDLE = System.getenv("BUNDLE_PATH"); // path to "PojavLauncher.app"
    public static final String DIR_GAME_HOME = System.getenv("POJAV_HOME");
    public static final String DIR_GAME_NEW = System.getenv("POJAV_GAME_DIR"); // path to "Library/Application Support/minecraft"
    public static final String DIR_GAME_PROFILE = System.getProperty("user.dir");
    
    public static final String DIR_APP_DATA = System.getenv("POJAV_HOME");
    public static final String DIR_ACCOUNT_NEW = DIR_APP_DATA + "/accounts";

    // New since 2.4.2
    public static final String DIR_HOME_VERSION = DIR_GAME_NEW + "/versions";
    public static final String DIR_HOME_LIBRARY = DIR_GAME_NEW + "/libraries";

    public static final String ASSETS_PATH = DIR_GAME_NEW + "/assets";
    public static final String OBSOLETE_RESOURCES_PATH=DIR_GAME_NEW + "/resources";

    // Voxy fix: RocksDB native is not usable on iOS (macOS build SIGILLs on
    // A11). Voxy reads <world>/voxy/config.json and uses whatever storage
    // backend is written there, so force every save (existing AND newly
    // created in-game) to use the pure-Java "Memory" backend (TYPE=Memory)
    // instead of the default RocksDB+ZSTD.
    //
    // A watchdog thread keeps scanning <gameDir>/saves while the game runs,
    // because worlds created after launch would otherwise get Voxy's default
    // config (RocksDB) and crash the JVM the moment it loads the native lib.
    private static void injectVoxyMemoryStorageConfig() {
        injectVoxyMemoryStorageConfigOnce();
        Thread watcher = new Thread(new Runnable() {
            public void run() {
                long deadline = System.currentTimeMillis() + 15L * 60L * 1000L;
                while (System.currentTimeMillis() < deadline) {
                    try { Thread.sleep(2000L); } catch (InterruptedException e) { break; }
                    try { injectVoxyMemoryStorageConfigOnce(false); } catch (Throwable ignored) {}
                }
            }
        }, "VoxyConfigWatcher");
        watcher.setDaemon(true);
        watcher.start();
    }

    private static void injectVoxyMemoryStorageConfigOnce() {
        injectVoxyMemoryStorageConfigOnce(true);
    }

    private static void injectVoxyMemoryStorageConfigOnce(boolean verbose) {
        try {
            File savesDir = new File(DIR_GAME_PROFILE, "saves");
            if (!savesDir.isDirectory()) {
                if (verbose) {
                    System.out.println("[Voxy Fix] No saves dir at " + savesDir + ", skipping");
                }
                return;
            }
            String memoryConfig = "{\n" +
                "  \"version\": 1,\n" +
                "  \"disabled\": false,\n" +
                "  \"sectionStorageConfig\": {\n" +
                "    \"TYPE\": \"Serializer\",\n" +
                "    \"storage\": {\n" +
                "      \"TYPE\": \"Memory\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
            File[] worlds = savesDir.listFiles();
            if (worlds == null) return;
            int patched = 0;
            for (File world : worlds) {
                if (!world.isDirectory() || !new File(world, "level.dat").exists()) continue;
                File voxyDir = new File(world, "voxy");
                File configFile = new File(voxyDir, "config.json");
                if (configFile.exists()) {
                    // Skip already-configured worlds
                    try {
                        byte[] b = new byte[(int) configFile.length()];
                        java.io.FileInputStream fis = new java.io.FileInputStream(configFile);
                        try { int rd = 0; while (rd < b.length) { int r = fis.read(b, rd, b.length - rd); if (r < 0) break; rd += r; } }
                        finally { fis.close(); }
                        if (new String(b, java.nio.charset.StandardCharsets.UTF_8).contains("Memory")) continue;
                    } catch (Exception ignored) {}
                }
                voxyDir.mkdirs();
                try (java.io.FileOutputStream fos = new java.io.FileOutputStream(configFile)) {
                    fos.write(memoryConfig.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                }
                patched++;
            }
            if (verbose || patched > 0) {
                System.out.println("[Voxy Fix] Injected Memory storage config into " + patched + " world(s)");
            }
        } catch (Exception e) {
            System.err.println("[Voxy Fix] Failed to inject voxy config: " + e);
        }
    }

    public static void launchMinecraft(MinecraftAccount profile, final JMinecraftVersionList.Version versionInfo) throws Throwable {
        System.out.println("[DEBUG] launchMinecraft: id=" + versionInfo.id + " inheritsFrom=" + versionInfo.inheritsFrom + " assets=" + versionInfo.assets + " mainClass=" + versionInfo.mainClass);
        injectVoxyMemoryStorageConfig();
        // Forge/NeoForge/Fabric log4j configs write logs/latest.log relative to
        // the process working directory; create it before the game's logging
        // starts or its RollingRandomAccessFile appender fails to open.
        try {
            new File(System.getProperty("user.dir"), "logs").mkdirs();
        } catch (Exception ignored) {}
        String mainClass = versionInfo.mainClass;
        if (mainClass != null && (mainClass.contains("fabric") || mainClass.contains("quilt"))) {
            neutralizeFabricLwjgl(versionInfo);
        }
        String[] launchArgs = getMinecraftArgs(profile, versionInfo);
        System.out.println("[DEBUG] Minecraft Args: " + Arrays.toString(launchArgs));

        final String launchClassPath = generateLaunchClassPath(versionInfo);
        System.out.println("[DEBUG] Launch classpath: " + launchClassPath);

        System.out.println("Args init finished. Now starting game");

        PojavClassLoader loader = (PojavClassLoader) ClassLoader.getSystemClassLoader();
        // add launcher.jar itself
        for (String s : System.getProperty("java.class.path").split(":")) {
            loader.appendToClassPathForInstrumentation(s);
        }
        for (String s : launchClassPath.split(":")) {
            if (!s.isEmpty()) {
                loader.addURL(new File(s).toURI().toURL());
            }
        }

        // Ensure Log4j libraries are accessible (needed by Fabric mods like config_manager)
        if (mainClass != null && (mainClass.contains("fabric") || mainClass.contains("quilt"))) {
            loadLog4jLibraries(loader);
        }

        Class<?> clazz = loader.loadClass(mainClass);
        Method method = clazz.getMethod("main", String[].class);
        method.invoke(null, new Object[]{launchArgs});
    }

    // Fabric/Quilt instances load Mojang's original (unpatched) LWJGL jars from
    // the version JSON. Those crash on iOS at org.lwjgl.glfw.GLFW init
    // (MemoryUtil -> Library.<clinit> -> System.load of liblwjgl.dylib fails,
    // "Could not initialize class org.lwjgl.glfw.GLFW"). The bundled patched
    // LWJGL (pure-Java, resolves native symbols from the app executable, no
    // .dylib loading) is already on the JVM classpath, so strip org.lwjgl
    // entries from the version JSON files Fabric reads -> Knot delegates to the
    // launcher classloader and picks up the patched jars instead. Only touches
    // Fabric/Quilt instance JSONs, harmless to all other instances and iOS
    // versions. Works on first launch too (JSON files exist by then).
    public static void neutralizeFabricLwjgl(JMinecraftVersionList.Version info) {
        String id = info.id;
        int guard = 0;
        while (id != null && guard++ < 5) {
            File jsonFile = new File(DIR_HOME_VERSION, id + "/" + id + ".json");
            if (jsonFile.exists()) {
                try {
                    String content = Tools.read(jsonFile.getAbsolutePath());
                    JsonObject root = JsonParser.parseString(content).getAsJsonObject();
                    boolean changed = false;
                    if (root.has("libraries")) {
                        JsonArray libs = root.getAsJsonArray("libraries");
                        JsonArray kept = new JsonArray();
                        for (JsonElement el : libs) {
                            String name = null;
                            if (el.isJsonObject() && el.getAsJsonObject().has("name")) {
                                name = el.getAsJsonObject().get("name").getAsString();
                            }
                            if (name != null && name.startsWith("org.lwjgl:")) {
                                changed = true;
                                continue;
                            }
                            kept.add(el);
                        }
                        if (changed) {
                            File backup = new File(jsonFile.getAbsolutePath() + ".no-lwjgl.bak");
                            if (!backup.exists()) {
                                Files.copy(jsonFile.toPath(), backup.toPath(), StandardCopyOption.COPY_ATTRIBUTES);
                            }
                            root.add("libraries", kept);
                            Tools.write(jsonFile.getAbsolutePath(), root.toString());
                            System.out.println("[LWJGLFix] Removed org.lwjgl libraries from " + jsonFile);
                        }
                    }
                } catch (Exception e) {
                    System.err.println("[LWJGLFix] Failed to patch " + jsonFile + ": " + e);
                }
            }
            id = null;
            try {
                JsonObject root = JsonParser.parseString(Tools.read(jsonFile.getAbsolutePath())).getAsJsonObject();
                if (root.has("inheritsFrom")) id = root.get("inheritsFrom").getAsString();
            } catch (Exception ignored) {
            }
        }
        // Drop any stale Mojang lwjgl jars Fabric may have downloaded on a
        // previous run, so they can never be picked up again.
        File lwjglLibDir = new File(DIR_HOME_LIBRARY, "org/lwjgl");
        if (lwjglLibDir.exists()) {
            try {
                deleteRecursively(lwjglLibDir);
                System.out.println("[LWJGLFix] Removed stale Mojang lwjgl jars from " + lwjglLibDir);
            } catch (Exception e) {
                System.err.println("[LWJGLFix] Could not remove " + lwjglLibDir + ": " + e);
            }
        }
    }

    private static void deleteRecursively(File dir) throws IOException {
        if (dir.isDirectory()) {
            File[] children = dir.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursively(child);
                }
            }
        }
        if (!dir.delete() && dir.exists()) {
            throw new IOException("Could not delete " + dir);
        }
    }

    private static final String[][] LOG4J_ARTIFACTS = {
        {"org/apache/logging/log4j/log4j-api/2.26.0/log4j-api-2.26.0.jar", "https://libraries.minecraft.net/org/apache/logging/log4j/log4j-api/2.26.0/log4j-api-2.26.0.jar"},
        {"org/apache/logging/log4j/log4j-core/2.26.0/log4j-core-2.26.0.jar", "https://libraries.minecraft.net/org/apache/logging/log4j/log4j-core/2.26.0/log4j-core-2.26.0.jar"},
        {"org/apache/logging/log4j/log4j-slf4j2-impl/2.26.0/log4j-slf4j2-impl-2.26.0.jar", "https://libraries.minecraft.net/org/apache/logging/log4j/log4j-slf4j2-impl/2.26.0/log4j-slf4j2-impl-2.26.0.jar"},
    };

    private static void loadLog4jLibraries(PojavClassLoader loader) throws IOException {
        boolean foundAny = false;
        for (String[] artifact : LOG4J_ARTIFACTS) {
            File jarFile = new File(DIR_HOME_LIBRARY, artifact[0]);
            if (jarFile.exists()) {
                loader.addURL(jarFile.toURI().toURL());
                System.out.println("Added Log4j jar: " + jarFile.getAbsolutePath());
                foundAny = true;
            }
        }
        if (foundAny) return;

        // Fallback: download Log4j from Maven if not found locally
        System.out.println("Log4j libraries not found, downloading from Maven...");
        File log4jDir = new File(DIR_HOME_LIBRARY, "org/apache/logging/log4j");
        for (String[] artifact : LOG4J_ARTIFACTS) {
            File destFile = new File(DIR_HOME_LIBRARY, artifact[0]);
            destFile.getParentFile().mkdirs();
            try {
                URL url = new URL(artifact[1]);
                try (InputStream in = url.openStream(); OutputStream out = new FileOutputStream(destFile)) {
                    byte[] buf = new byte[8192];
                    int n;
                    while ((n = in.read(buf)) >= 0) {
                        out.write(buf, 0, n);
                    }
                }
                loader.addURL(destFile.toURI().toURL());
                System.out.println("Downloaded and added Log4j jar: " + destFile.getAbsolutePath());
            } catch (Exception e) {
                System.err.println("Failed to download Log4j library: " + artifact[0] + " - " + e.getMessage());
            }
        }
    }

    // The TouchController mod (v0.3.1-alpha13+) defaults to tick thresholds
    // calibrated for 60fps Android. On the iOS software renderer the game runs
    // at ~14fps, so "hold to break" (viewHoldDetectTicks=5 -> ~350ms) fires on
    // ordinary placement taps. Seed a minimal config with thresholds tuned for
    // the actual frame rate, so taps place blocks and only deliberate long
    // holds break. Only written when absent: in-game TouchController settings
    // take precedence and are never overwritten.
    private static void seedTouchControllerConfig(File gameDir) {
        try {
            File cfgDir = new File(gameDir, "config/touchcontroller");
            File cfgFile = new File(cfgDir, "config.json");
            if (cfgFile.exists()) {
                return;
            }
            cfgDir.mkdirs();
            String json = "{\n"
                + "  \"control\": {\n"
                + "    \"viewHoldDetectTicks\": 8,\n"
                + "    \"creativeBreakDetectTicks\": 10\n"
                + "  }\n"
                + "}\n";
            BufferedWriter writer = new BufferedWriter(new java.io.FileWriter(cfgFile));
            try {
                writer.write(json);
            } finally {
                writer.close();
            }
            System.out.println("Seeded TouchController config: " + cfgFile.getAbsolutePath());
        } catch (Exception e) {
            System.err.println("Failed to seed TouchController config: " + e.getMessage());
        }
    }

    public static String[] getMinecraftArgs(MinecraftAccount profile, JMinecraftVersionList.Version versionInfo) {
        String username = profile.username.replace("Demo.", "");
        String versionName = versionInfo.id;
        if (versionInfo.inheritsFrom != null) {
            versionName = versionInfo.inheritsFrom;
        }

        File gameDir = new File(Tools.DIR_GAME_PROFILE);
        gameDir.mkdirs();

        seedTouchControllerConfig(gameDir);

        Map<String, String> varArgMap = new ArrayMap<String, String>();
        varArgMap.put("auth_session", profile.accessToken); // For legacy versions of MC
        varArgMap.put("auth_access_token", profile.accessToken);
        varArgMap.put("auth_player_name", username);
        varArgMap.put("auth_uuid", profile.profileId.replace("-", ""));
        varArgMap.put("auth_xuid", profile.xuid);
        varArgMap.put("assets_root", Tools.ASSETS_PATH);
        varArgMap.put("assets_index_name", versionInfo.assets);
        varArgMap.put("clientid", profile.clientToken);
        varArgMap.put("game_assets", Tools.ASSETS_PATH);
        varArgMap.put("game_directory", gameDir.getAbsolutePath());
        varArgMap.put("user_properties", "{}");
        varArgMap.put("user_type", "mojang");
        varArgMap.put("version_name", versionName);
        varArgMap.put("version_type", versionInfo.type);
        varArgMap.put("natives_directory", System.getProperty("java.library.path"));

        List<String> minecraftArgs = new ArrayList<String>();
        boolean hasArgs = versionInfo.arguments != null && versionInfo.arguments.game != null && versionInfo.arguments.game.length > 0;
        if (hasArgs) {
            // Support Minecraft 1.13+
            for (Object arg : versionInfo.arguments.game) {
                if (arg instanceof String) {
                    minecraftArgs.add((String) arg);
                    if (arg.equals("--xuid")) {
                        varArgMap.put("user_type", "msa");
                    }
                } else {
                    /*
                    JMinecraftVersionList.Arguments.ArgValue argv = (JMinecraftVersionList.Arguments.ArgValue) arg;
                    if (argv.values != null) {
                        minecraftArgs.add(argv.values[0]);
                    } else {
                        
                         for (JMinecraftVersionList.Arguments.ArgValue.ArgRules rule : arg.rules) {
                         // rule.action = allow
                         // TODO implement this
                         }
                         
                    }
                    */
                }
            }
        }
        if (!hasArgs && versionInfo.minecraftArguments == null) {
            // Default arguments for modern Minecraft when version JSON lacks them
            String[][] defaultArgs = {
                {"--username", "${auth_player_name}"},
                {"--version", "${version_name}"},
                {"--gameDir", "${game_directory}"},
                {"--assetsDir", "${assets_root}"},
                {"--assetIndex", "${assets_index_name}"},
                {"--uuid", "${auth_uuid}"},
                {"--accessToken", "${auth_session}"},
                {"--userType", "${user_type}"},
                {"--versionType", "${version_type}"},
                {"--xuid", "${auth_xuid}"},
                {"--clientId", "${clientid}"},
            };
            for (String[] argPair : defaultArgs) {
                minecraftArgs.add(argPair[0]);
                minecraftArgs.add(argPair[1]);
                if (argPair[0].equals("--xuid")) {
                    varArgMap.put("user_type", "msa");
                }
            }
            System.out.println("[DEBUG] Using default Minecraft arguments");
        }
        String[] argsFromJson = JSONUtils.insertJSONValueList(
            splitAndFilterEmpty(
                versionInfo.minecraftArguments == null ?
                fromStringArray(minecraftArgs.toArray(new String[0])):
                versionInfo.minecraftArguments,
                profile
            ), varArgMap
        );
        // Tools.dialogOnUiThread(this, "Result args", Arrays.asList(argsFromJson).toString());
        return argsFromJson;
    }

    public static String fromStringArray(String[] strArr) {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < strArr.length; i++) {
            if (i > 0) builder.append(" ");
            builder.append(strArr[i]);
        }

        return builder.toString();
    }

    private static String[] splitAndFilterEmpty(String argStr, MinecraftAccount profile) {
        List<String> strList = new ArrayList<String>();
        if(profile.username.startsWith("Demo.")) {
            strList.add("--demo");
        }
        for (String arg : argStr.split(" ")) {
            if (!arg.isEmpty()) {
                strList.add(arg);
            }
        }
        return strList.toArray(new String[0]);
    }

    public static String artifactToPath(DependentLibrary library) {
        if (library.downloads != null &&
            library.downloads.artifact != null &&
            library.downloads.artifact.path != null)
            return library.downloads.artifact.path;
        String[] libInfos = library.name.split(":");
        return libInfos[0].replaceAll("\\.", "/") + "/" + libInfos[1] + "/" + libInfos[2] + "/" + libInfos[1] + "-" + libInfos[2] + ".jar";
    }

/*
    private static String getLWJGL3ClassPath() {
        StringBuilder libStr = new StringBuilder();
        File lwjgl3Folder = new File(Tools.DIR_GAME_NEW, "lwjgl3");
        if (/* info.arguments != null && @lwjgl3Folder.exists()) {
            for (File file: lwjgl3Folder.listFiles()) {
                if (file.getName().endsWith(".jar")) {
                    libStr.append(file.getAbsolutePath() + ":");
                }
            }
            // Remove the ':' at the end
            libStr.setLength(libStr.length() - 1);
        }
        return libStr.toString();
    }
*/
    public static String generateLaunchClassPath(JMinecraftVersionList.Version info) {
        System.out.println("[DEBUG] generateLaunchClassPath: info.id=" + info.id);
        StringBuilder libStr = new StringBuilder(); //versnDir + "/" + version + "/" + version + ".jar:";

        String[] classpath = generateLibClasspath(info);

        // Debug: LWJGL 3 override
        // File lwjgl2Folder = new File(Tools.MAIN_PATH, "lwjgl2");

        /*
         File lwjgl3Folder = new File(Tools.MAIN_PATH, "lwjgl3");
         if (lwjgl3Folder.exists()) {
         for (File file: lwjgl3Folder.listFiles()) {
         if (file.getName().endsWith(".jar")) {
         libStr.append(file.getAbsolutePath() + ":");
         }
         }
         } else if (lwjgl2Folder.exists()) {
         for (File file: lwjgl2Folder.listFiles()) {
         if (file.getName().endsWith(".jar")) {
         libStr.append(file.getAbsolutePath() + ":");
         }
         }
         }
         */

        for (String perJar : classpath) {
            if (!new File(perJar).exists()) {
                System.out.println("Ignored non-exists file: " + perJar);
                continue;
            }
            libStr.append(perJar + ":");
        }
        String jarPath = DIR_HOME_VERSION + "/" + info.id + "/" + info.id + ".jar";
        File jarFile = new File(jarPath);
        System.out.println("[DEBUG] Main JAR: " + jarPath + " exists=" + jarFile.exists() + " size=" + (jarFile.exists() ? jarFile.length() : -1));
        libStr.append(jarPath);

        return libStr.toString();
    }
    
    public static void moveInside(String from, String to) {
        File fromFile = new File(from);
        for (File fromInside : fromFile.listFiles()) {
            moveRecursive(fromInside.getAbsolutePath(), to);
        }
        fromFile.delete();
    }

    public static void moveRecursive(String from, String to) {
        moveRecursive(new File(from), new File(to));
    }

    public static void moveRecursive(File from, File to) {
        File toFrom = new File(to, from.getName());
        try {
            if (from.isDirectory()) {
                for (File child : from.listFiles()) {
                    moveRecursive(child, toFrom);
                }
            }
        } finally {
            from.getParentFile().mkdirs();
            from.renameTo(toFrom);
        }
    }

    public static void preProcessLibraries(DependentLibrary[] libraries) {
        if (libraries == null) return;
        // Ignore some libraries since they are unsupported (jinput, text2speech) or unused (LWJGL)
        // Support for text2speech is not planned, so skip it for now.
        for (int i = 0; i < libraries.length; i++) {
            DependentLibrary libItem = libraries[i];
            if (libItem.name.startsWith("com.mojang:text2speech") ||
                //libItem.name.startsWith("net.java.jinput") ||
                libItem.name.startsWith("net.java.dev.jna:platform:") ||
                libItem.name.startsWith("org.lwjgl") ||
                libItem.name.startsWith("tv.twitch")) {
                    libItem._skip = true;
                    continue;
            }

            String[] libParts = libItem.name.split(":");
            if (libParts.length < 3) {
                System.out.println("Skipping malformed library entry: " + libItem.name);
                libItem._skip = true;
                continue;
            }
            String[] version = libParts[2].split("\\.");
            if (libItem.name.startsWith("net.java.dev.jna:jna:")) {
                // Special handling for LabyMod 1.8.9 and Forge 1.12.2(?)
                // we have libjnidispatch 5.13.0 in Frameworks directory
                if (Integer.parseInt(version[0]) >= 5 && Integer.parseInt(version[1]) >= 13) continue;
                //System.out.println("Library " + libItem.name + " has been changed to version 5.13.0");
                
createLibraryInfo(libItem);
                libItem.name = "net.java.dev.jna:jna:5.13.0";
                libItem.downloads.artifact.path = "net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar";
                libItem.downloads.artifact.url = "https://libraries.minecraft.net/net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar";
            } else if (libItem.name.startsWith("org.ow2.asm:asm-all:")) {
                if(Integer.parseInt(version[0]) >= 5) continue;
                //System.out.println("Library " + libItem.name + " has been changed to version 5.0.4");
                createLibraryInfo(libItem);
                libItem.name = "org.ow2.asm:asm-all:5.0.4";
                libItem.url = null;
                libItem.downloads.artifact.path = "org/ow2/asm/asm-all/5.0.4/asm-all-5.0.4.jar";
                libItem.downloads.artifact.sha1 = "e6244859997b3d4237a552669279780876228909";
                libItem.downloads.artifact.url = "https://repo1.maven.org/maven2/org/ow2/asm/asm-all/5.0.4/asm-all-5.0.4.jar";
            } else if (libItem.name.startsWith("org.ow2.asm:asm:") ||
                       libItem.name.startsWith("org.ow2.asm:asm-analysis:") ||
                       libItem.name.startsWith("org.ow2.asm:asm-commons:") ||
                       libItem.name.startsWith("org.ow2.asm:asm-tree:") ||
                       libItem.name.startsWith("org.ow2.asm:asm-util:")) {
                // Replace ASM < 9.9.1 with 9.9.1 for Java 25 class file support (major version 69).
                // 9.7.1 (used by Quilt meta and NeoForge < 26.2) cannot read Java 25 class files.
                if (version.length >= 2) {
                    int major = Integer.parseInt(version[0]);
                    int minor = Integer.parseInt(version[1]);
                    int patch = version.length > 2 ? Integer.parseInt(version[2]) : 0;
                    if (major > 9 || (major == 9 && minor > 9) || (major == 9 && minor == 9 && patch >= 1)) {
                        continue;
                    }
                }
                String asmArtifact = libParts[1];
                createLibraryInfo(libItem);
                libItem.name = "org.ow2.asm:" + asmArtifact + ":9.9.1";
                libItem.url = "https://repo1.maven.org/maven2/";
                libItem.downloads.artifact.path = "org/ow2/asm/" + asmArtifact + "/9.9.1/" + asmArtifact + "-9.9.1.jar";
                libItem.downloads.artifact.url = "https://repo1.maven.org/maven2/org/ow2/asm/" + asmArtifact + "/9.9.1/" + asmArtifact + "-9.9.1.jar";
            }
        }
    }

    private static void createLibraryInfo(DependentLibrary library) {
        if(library.downloads == null || library.downloads.artifact == null)
            library.downloads = new DependentLibrary.LibraryDownloads(new MinecraftLibraryArtifact());
    }

    public static String[] generateLibClasspath(JMinecraftVersionList.Version info) {
        List<String> libDir = new ArrayList<String>();

        preProcessLibraries(info.libraries);
        for (DependentLibrary libItem : info.libraries) {
            if (libItem._skip) continue;
            String fullPath = Tools.DIR_HOME_LIBRARY + "/" + artifactToPath(libItem);
            if (!libDir.contains(fullPath)) {
                libDir.add(fullPath);
            }
        }
        // net.minecraft:launchwrapper:1.12 is required by Mixin's service
        // discovery (MixinServiceLaunchWrapper must be instantiable) but is
        // missing from the downloaded instance profiles. PojavLauncher copies
        // the bundled jar here; append it if present.
        File launchWrapperJar = new File(Tools.DIR_HOME_LIBRARY + "/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar");
        if (launchWrapperJar.exists() && !libDir.contains(launchWrapperJar.getAbsolutePath())) {
            libDir.add(launchWrapperJar.getAbsolutePath());
        }
        // Forge 26.x keeps the "forge" system mod inside the *-universal.jar
        // artifact, but the installed instance version JSON omits that
        // classifier entry, so the jar never lands on the classpath and FML
        // aborts with "Failed to find system mod: forge". Append every
        // *-universal.jar shipped under libraries/net/minecraftforge/forge/.
        File forgeLibRoot = new File(Tools.DIR_HOME_LIBRARY + "/net/minecraftforge/forge");
        if (forgeLibRoot.isDirectory()) {
            File[] forgeVersionDirs = forgeLibRoot.listFiles();
            if (forgeVersionDirs != null) {
                for (File forgeVersionDir : forgeVersionDirs) {
                    if (!forgeVersionDir.isDirectory()) continue;
                    File[] forgeJars = forgeVersionDir.listFiles();
                    if (forgeJars == null) continue;
                    for (File forgeJar : forgeJars) {
                        if (forgeJar.getName().endsWith("-universal.jar")
                                && !libDir.contains(forgeJar.getAbsolutePath())) {
                            libDir.add(forgeJar.getAbsolutePath());
                        }
                    }
                }
            }
        }
        return libDir.toArray(new String[0]);
    }

    public static JMinecraftVersionList.Version getVersionInfo(String versionName) {
        try {
            System.out.println("[DEBUG] getVersionInfo: loading version " + versionName);
            JMinecraftVersionList.Version version = Tools.GLOBAL_GSON.fromJson(read(DIR_HOME_VERSION + "/" + versionName + "/" + versionName + ".json"), JMinecraftVersionList.Version.class);
            System.out.println("[DEBUG] Raw version: id=" + version.id + " inheritsFrom=" + version.inheritsFrom + " assets=" + version.assets + " mainClass=" + version.mainClass);
            
            // Resolve the full inheritsFrom chain recursively
            if (version.inheritsFrom != null && !version.inheritsFrom.equals(version.id)) {
                version = resolveInheritsChain(version, new HashSet<String>());
            }
            
            System.out.println("[DEBUG] Merged version: id=" + version.id + " inheritsFrom=" + version.inheritsFrom + " assets=" + version.assets + " mainClass=" + version.mainClass + " logging=" + (version.logging != null ? version.logging.client != null ? version.logging.client.file != null ? version.logging.client.file.id : "noFile" : "noClient" : "null"));
            
            preProcessLibraries(version.libraries);
            
            return version;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
    
    private static JMinecraftVersionList.Version resolveInheritsChain(JMinecraftVersionList.Version child, Set<String> seen) throws IOException {
        if (child.inheritsFrom == null || child.inheritsFrom.equals(child.id) || seen.contains(child.inheritsFrom)) {
            return child;
        }
        seen.add(child.inheritsFrom);
        
        JMinecraftVersionList.Version parent = Tools.GLOBAL_GSON.fromJson(
            read(DIR_HOME_VERSION + "/" + child.inheritsFrom + "/" + child.inheritsFrom + ".json"),
            JMinecraftVersionList.Version.class);
        
        // Recursively resolve grandparent first
        if (parent.inheritsFrom != null && !parent.inheritsFrom.equals(parent.id)) {
            parent = resolveInheritsChain(parent, seen);
        }
        
        // Merge child's fields into parent (keep child id so jar path resolves correctly)
        insertSafety(parent, child,
                     "id", "assetIndex", "assets",
                     "mainClass", "minecraftArguments",
                     "releaseTime", "time", "type"
                     );

        // Merge libraries: child's libs override parent's libs by name
        List<DependentLibrary> parentLibList = new ArrayList<>(Arrays.asList(parent.libraries));
        for (DependentLibrary library : child.libraries) {
            if (library.name == null || !library.name.contains(":")) continue;
            String libGroup = library.name.substring(0, library.name.lastIndexOf(":"));
            int matchedIdx = -1;
            for (int i = 0; i < parentLibList.size(); i++) {
                String parentLibName = parentLibList.get(i).name;
                if (parentLibName != null && parentLibName.contains(":")) {
                    String parentLibGroup = parentLibName.substring(0, parentLibName.lastIndexOf(":"));
                    if (libGroup.equals(parentLibGroup)) {
                        matchedIdx = i;
                        break;
                    }
                }
            }
            if (matchedIdx >= 0) {
                parentLibList.set(matchedIdx, library);
            } else {
                parentLibList.add(library);
            }
        }
        parent.libraries = parentLibList.toArray(new DependentLibrary[0]);

        // Merge arguments for Minecraft 1.13+
        if (parent.arguments != null && child.arguments != null) {
            List totalArgList = new ArrayList();
            totalArgList.addAll(Arrays.asList(parent.arguments.game));
            
            int nskip = 0;
            for (int i = 0; i < child.arguments.game.length; i++) {
                if (nskip > 0) {
                    nskip--;
                    continue;
                }
                
                Object perCustomArg = child.arguments.game[i];
                if (perCustomArg instanceof String) {
                    String perCustomArgStr = (String) perCustomArg;
                    if (perCustomArgStr.startsWith("--") && totalArgList.contains(perCustomArgStr)) {
                        perCustomArg = child.arguments.game[i + 1];
                        if (perCustomArg instanceof String) {
                            perCustomArgStr = (String) perCustomArg;
                            if (!perCustomArgStr.startsWith("--")) {
                                nskip++;
                            }
                        }
                    } else {
                        totalArgList.add(perCustomArgStr);
                    }
                } else if (!totalArgList.contains(perCustomArg)) {
                    totalArgList.add(perCustomArg);
                }
            }

            parent.arguments.game = totalArgList.toArray(new Object[0]);
        }

        return parent;
    }

    // Prevent NullPointerException
    private static void insertSafety(JMinecraftVersionList.Version targetVer, JMinecraftVersionList.Version fromVer, String... keyArr) {
        for (String key : keyArr) {
            Object value = null;
            try {
                Field fieldA = fromVer.getClass().getField(key);
                value = fieldA.get(fromVer);
                if (((value instanceof String) && !((String) value).isEmpty()) || value != null) {
                    Field fieldB = targetVer.getClass().getField(key);
                    fieldB.set(targetVer, value);
                }
            } catch (Throwable th) {
                System.err.println("Unable to insert " + key + "=" + value);
                th.printStackTrace();
            }
        }
    }
    
    public static String convertStream(InputStream inputStream) throws IOException {
        return convertStream(inputStream, Charset.forName("UTF-8"));
    }
    
    public static String convertStream(InputStream inputStream, Charset charset) throws IOException {
        String out = "";
        int len;
        byte[] buf = new byte[512];
        while((len = inputStream.read(buf))!=-1) {
            out += new String(buf,0,len,charset);
        }
        return out;
    }

    public static void copy(final InputStream input, final OutputStream output) throws IOException {
        final byte[] buffer = new byte[8192];
        int n = 0;
        while ((n = input.read(buffer)) != -1) {
            output.write(buffer, 0, n);
        }
    }

    public static File lastFileModified(String dir) {
        File fl = new File(dir);

        File[] files = fl.listFiles(new FileFilter() {
                public boolean accept(File file) {
                    return file.isFile();
                }
            });

        long lastMod = Long.MIN_VALUE;
        File choice = null;
        for (File file : files) {
            if (file.lastModified() > lastMod) {
                choice = file;
                lastMod = file.lastModified();
            }
        }

        return choice;
    }

    public static String read(InputStream is) throws IOException {
        String out = "";
        int len;
        byte[] buf = new byte[512];
        while((len = is.read(buf))!=-1) {
            out += new String(buf,0,len);
        }
        return out;
    }

    public static String read(String path) throws IOException {
        return read(new FileInputStream(path));
    }

    public static void write(String path, byte[] content) throws IOException
    {
        File outPath = new File(path);
        outPath.getParentFile().mkdirs();
        outPath.createNewFile();

        BufferedOutputStream fos = new BufferedOutputStream(new FileOutputStream(path));
        fos.write(content, 0, content.length);
        fos.close();
    }

    public static void write(String path, String content) throws IOException {
        write(path, content.getBytes());
    }

    // ==================== Distant Horizons Fix ====================
    // On iOS, DH mod extracts libzstd-jni_dh-1.5.7-6.dylib to a temp directory,
    // but the relocation process invalidates the code signature, causing crash.
    // Fix: Pre-extract the library, sign it with ad-hoc signature, and add to java.library.path

    private static final String DH_MOD_ID = "distanthorizons";
    private static final String ZSTD_LIB_NAME = "libzstd-jni_dh-1.5.7-6.dylib";
    private static final String ZSTD_LIB_NAME_ALT = "libzstd-jni_dh.dylib"; // fallback

    /**
     * Detect if a mod with the given keyword is in the library list.
     */
    public static boolean hasModLibrary(JMinecraftVersionList.Version versionInfo, String keyword) {
        String kw = keyword.toLowerCase();
        if (versionInfo != null && versionInfo.libraries != null) {
            for (DependentLibrary lib : versionInfo.libraries) {
                if (lib.name != null && lib.name.toLowerCase().contains(kw)) {
                    return true;
                }
            }
        }
        // Fallback: the mod jar may have been dropped manually into the
        // instance's mods folder instead of the version libraries.
        String[] modDirs = {DIR_GAME_PROFILE + "/mods", DIR_GAME_PROFILE + "/.minecraft/mods"};
        for (String dirPath : modDirs) {
            File dir = new File(dirPath);
            if (!dir.isDirectory()) continue;
            File[] jars = dir.listFiles((d, name) -> name.endsWith(".jar"));
            if (jars == null) continue;
            for (File jar : jars) {
                if (jar.getName().toLowerCase().contains(kw)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Detect if Distant Horizons mod is installed: either in the version
     * library list (Forge-style) or dropped manually into the instance's
     * mods folder (Fabric/Quilt).
     */
    public static boolean hasDistantHorizonsMod(JMinecraftVersionList.Version versionInfo) {
        if (versionInfo != null && versionInfo.libraries != null) {
            for (DependentLibrary lib : versionInfo.libraries) {
                if (lib.name != null && lib.name.toLowerCase().contains(DH_MOD_ID)) {
                    return true;
                }
            }
        }
        String[] modDirs = {DIR_GAME_PROFILE + "/mods", DIR_GAME_PROFILE + "/.minecraft/mods"};
        for (String dirPath : modDirs) {
            File dir = new File(dirPath);
            if (!dir.isDirectory()) continue;
            File[] jars = dir.listFiles((d, name) -> name.endsWith(".jar"));
            if (jars == null) continue;
            for (File jar : jars) {
                if (jar.getName().toLowerCase().contains("distant")) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Extract and sign zstd-jni native library for Distant Horizons.
     * Returns the directory containing the signed library, or null if failed.
     */
    public static String prepareDistantHorizonsNativeLib(JMinecraftVersionList.Version versionInfo) {
        if (!hasDistantHorizonsMod(versionInfo)) {
            System.err.println("[DH Fix] Distant Horizons mod not found in version libraries or mods folder");
            return null;
        }

        System.out.println("[DH Fix] Distant Horizons detected, preparing native library...");

        // Find DH jar in libraries
        String dhJarPath = findDhJarPath(versionInfo);
        if (dhJarPath == null) {
            System.err.println("[DH Fix] Could not find Distant Horizons jar");
            return null;
        }

        // Extract library to app's Documents directory (persistent, signable)
        File extractDir = new File(DIR_APP_DATA, "dh_natives");
        if (!extractDir.exists()) {
            extractDir.mkdirs();
        }

        File targetLib = new File(extractDir, ZSTD_LIB_NAME);
        if (targetLib.exists()) {
            System.out.println("[DH Fix] Library already exists at: " + targetLib.getAbsolutePath());
        } else {
            if (!extractNativeLibFromJar(dhJarPath, targetLib)) {
                System.err.println("[DH Fix] Failed to extract native library from DH jar");
                return null;
            }
        }

        // Sign the library with ad-hoc signature (required for iOS)
        if (!signLibrary(targetLib)) {
            System.err.println("[DH Fix] Failed to sign library");
            return null;
        }

        System.out.println("[DH Fix] Successfully prepared DH native library at: " + extractDir.getAbsolutePath());
        return extractDir.getAbsolutePath();
    }

    private static String findDhJarPath(JMinecraftVersionList.Version versionInfo) {
        if (versionInfo.libraries != null) {
            for (DependentLibrary lib : versionInfo.libraries) {
                if (lib.name != null && lib.name.toLowerCase().contains(DH_MOD_ID)) {
                    String artifactPath = artifactToPath(lib);
                    File jarFile = new File(DIR_HOME_LIBRARY, artifactPath);
                    if (jarFile.exists()) {
                        return jarFile.getAbsolutePath();
                    }
                }
            }
        }
        // Fallback: the mod jar may have been dropped manually into the
        // instance's mods folder instead of the version libraries.
        String[] modDirs = {DIR_GAME_PROFILE + "/mods", DIR_GAME_PROFILE + "/.minecraft/mods"};
        for (String dirPath : modDirs) {
            File dir = new File(dirPath);
            if (!dir.isDirectory()) continue;
            File[] jars = dir.listFiles((d, name) -> name.endsWith(".jar"));
            if (jars == null) continue;
            for (File jar : jars) {
                if (jar.getName().toLowerCase().contains("distant")) {
                    return jar.getAbsolutePath();
                }
            }
        }
        return null;
    }

    private static boolean extractNativeLibFromJar(String jarPath, File targetLib) {
        try (JarFile jar = new JarFile(jarPath)) {
            // Try primary name first
            ZipEntry entry = jar.getEntry(ZSTD_LIB_NAME);
            if (entry == null) {
                // Try alternative name (maybe in different path)
                entry = findLibEntry(jar, ZSTD_LIB_NAME_ALT);
            }
            if (entry == null) {
                // Search for any zstd-jni library
                entry = findLibEntry(jar, "zstd-jni");
            }
            if (entry == null) {
                System.err.println("[DH Fix] No zstd-jni library found in DH jar");
                return false;
            }

            System.out.println("[DH Fix] Extracting " + entry.getName() + " from DH jar");
            try (InputStream is = jar.getInputStream(entry);
                 FileOutputStream fos = new FileOutputStream(targetLib)) {
                byte[] buffer = new byte[8192];
                int len;
                while ((len = is.read(buffer)) > 0) {
                    fos.write(buffer, 0, len);
                }
            }
            return true;
        } catch (IOException e) {
            System.err.println("[DH Fix] Error extracting library: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    private static ZipEntry findLibEntry(JarFile jar, String keyword) {
        java.util.jar.JarEntry fallback = null;
        for (java.util.Enumeration<java.util.jar.JarEntry> e = jar.entries(); e.hasMoreElements(); ) {
            java.util.jar.JarEntry entry = e.nextElement();
            String name = entry.getName().toLowerCase();
            if (name.contains(keyword.toLowerCase()) && name.endsWith(".dylib")) {
                if (name.contains("aarch64") || name.contains("arm64")) {
                    return entry;
                }
                if (fallback == null) fallback = entry;
            }
        }
        return fallback;
    }

    private static boolean signLibrary(File libFile) {
        // iOS has no /usr/bin/codesign. The app bundles an arm64 iOS ldid
        // at <bundle>/ldid (signed ad-hoc at package time), which we fall
        // back to. On TXM devices (A12+) an UNSIGNED dylib will not dlopen
        // ("code signature invalid") even inside the app container, so
        // signing is mandatory, not optional.
        String ldidPath = null;
        if (DIR_BUNDLE != null) {
            File bundledLdid = new File(DIR_BUNDLE, "ldid");
            if (bundledLdid.isFile()) {
                ldidPath = bundledLdid.getAbsolutePath();
            }
        }

        if (ldidPath == null) {
            if (runSignTool(new String[]{"codesign", "--force", "--sign", "-", libFile.getAbsolutePath()},
                    "codesign", libFile.getName())) {
                return true;
            }
            System.err.println("[DH Fix] codesign unavailable and no bundled ldid at " + DIR_BUNDLE + "/ldid");
            return false;
        }
        return runSignTool(new String[]{ldidPath, "-S", libFile.getAbsolutePath()}, "ldid", libFile.getName());
    }

    private static boolean runSignTool(String[] command, String toolName, String libName) {
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(true);
            Process process = pb.start();
            int exitCode = process.waitFor();
            if (exitCode == 0) {
                System.out.println("[DH Fix] Successfully signed library (" + toolName + "): " + libName);
                return true;
            }
            StringBuilder output = new StringBuilder();
            try (InputStream is = process.getInputStream()) {
                byte[] buffer = new byte[1024];
                int len;
                while ((len = is.read(buffer)) > 0) {
                    output.append(new String(buffer, 0, len));
                }
            }
            System.err.println("[DH Fix] " + toolName + " failed (exit " + exitCode + "): " + output);
            return false;
        } catch (Exception e) {
            System.err.println("[DH Fix] " + toolName + " unavailable (" + e.getMessage() + ")");
            return false;
        }
    }
}
