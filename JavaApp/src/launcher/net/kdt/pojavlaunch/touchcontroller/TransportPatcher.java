package net.kdt.pojavlaunch.touchcontroller;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipException;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import net.kdt.pojavlaunch.Tools;

/**
 * Patches the TouchController mod jar before the game boots.
 *
 * 1) Replaces Transport.class (inside its touchcontroller-common jar) with a
 *    generated copy whose static initializer System.load()s
 *    libTouchControllerGameBridge.dylib from the app bundle.
 *
 *    The load MUST happen from the game's Knot classloader: the launcher loads
 *    the main executable and libTouchControllerBridge.dylib itself, so any
 *    dylib registered with the launcher classloader is invisible to Knot's JNI
 *    resolution ("already loaded in another classloader"). The generated class
 *    is loaded by Knot (the mod lives in the game classpath), so its <clinit>
 *    registers the game bridge with exactly the classloader that resolves
 *    Transport.new/receive/send.
 *
 *    The class is generated as raw bytecode because the mod's methods are named
 *    "new", which cannot be declared in Java source.
 *
 * 2) Replaces DoubleClickCounter.class with a fixed copy whose clean() is a
 *    no-op. The original wipes double-click state whenever the game's client
 *    tick outruns the mod's render tick; on the ~14-20fps iOS software
 *    renderer (vs 20tps game tick) that is every frame, so double-click
 *    triggers (sneak/fly toggle) can never fire.
 */
public class TransportPatcher {

    private static final String TRANSPORT_ENTRY = "top/fifthlight/touchcontroller/common/platform/ios/Transport.class";
    private static final String DOUBLE_CLICK_ENTRY = "top/fifthlight/touchcontroller/common/layout/click/DoubleClickCounter.class";

    // Pre-compiled DoubleClickCounter.class (Java 8, compiled standalone against
    // kotlin-stdlib signatures; the jar keeps its own DoubleClickCounter$CounterEntry).
    private static final String DOUBLE_CLICK_B64 =
        "yv66vgAAADQAQQcAKgoAAQArCgAMACwKAA0AKwkADAAtCwAuAC8HADAKAAcAMQsALgAyCgAHADMK"
        + "AAcANAcANQcANgEADENvdW50ZXJFbnRyeQEADElubmVyQ2xhc3NlcwEADmxhc3RDbGlja1RpbWVz"
        + "AQAPTGphdmEvdXRpbC9NYXA7AQAJU2lnbmF0dXJlAQB3TGphdmEvdXRpbC9NYXA8TGtvdGxpbi91"
        + "dWlkL1V1aWQ7THRvcC9maWZ0aGxpZ2h0L3RvdWNoY29udHJvbGxlci9jb21tb24vbGF5b3V0L2Ns"
        + "aWNrL0RvdWJsZUNsaWNrQ291bnRlciRDb3VudGVyRW50cnk7PjsBAAY8aW5pdD4BAAMoKVYBAARD"
        + "b2RlAQAPTGluZU51bWJlclRhYmxlAQASKExqYXZhL3V0aWwvTWFwOylWAQB6KExqYXZhL3V0aWwv"
        + "TWFwPExrb3RsaW4vdXVpZC9VdWlkO0x0b3AvZmlmdGhsaWdodC90b3VjaGNvbnRyb2xsZXIvY29t"
        + "bW9uL2xheW91dC9jbGljay9Eb3VibGVDbGlja0NvdW50ZXIkQ291bnRlckVudHJ5Oz47KVYBAEEo"
        + "TGphdmEvdXRpbC9NYXA7SUxrb3RsaW4vanZtL2ludGVybmFsL0RlZmF1bHRDb25zdHJ1Y3Rvck1h"
        + "cmtlcjspVgEADVN0YWNrTWFwVGFibGUHADcHADgBAKkoTGphdmEvdXRpbC9NYXA8TGtvdGxpbi91"
        + "dWlkL1V1aWQ7THRvcC9maWZ0aGxpZ2h0L3RvdWNoY29udHJvbGxlci9jb21tb24vbGF5b3V0L2Ns"
        + "aWNrL0RvdWJsZUNsaWNrQ291bnRlciRDb3VudGVyRW50cnk7PjtJTGtvdGxpbi9qdm0vaW50ZXJu"
        + "YWwvRGVmYXVsdENvbnN0cnVjdG9yTWFya2VyOylWAQAGdXBkYXRlAQAWKElMa290bGluL3V1aWQv"
        + "VXVpZDspVgcAMAEABWNsaWNrAQAXKElMa290bGluL3V1aWQvVXVpZDtJKVoBAAVyZXNldAEAFShM"
        + "a290bGluL3V1aWQvVXVpZDspVgEABWNsZWFuAQAEKEkpVgEAClNvdXJjZUZpbGUBABdEb3VibGVD"
        + "bGlja0NvdW50ZXIuamF2YQEAF2phdmEvdXRpbC9MaW5rZWRIYXNoTWFwDAAUABUMABQAGAwAEAAR"
        + "BwA3DAA5ADoBAFJ0b3AvZmlmdGhsaWdodC90b3VjaGNvbnRyb2xsZXIvY29tbW9uL2xheW91dC9j"
        + "bGljay9Eb3VibGVDbGlja0NvdW50ZXIkQ291bnRlckVudHJ5DAAUADsMADwAPQwAPgA/DABAAD8B"
        + "AEV0b3AvZmlmdGhsaWdodC90b3VjaGNvbnRyb2xsZXIvY29tbW9uL2xheW91dC9jbGljay9Eb3Vi"
        + "bGVDbGlja0NvdW50ZXIBABBqYXZhL2xhbmcvT2JqZWN0AQANamF2YS91dGlsL01hcAEALGtvdGxp"
        + "bi9qdm0vaW50ZXJuYWwvRGVmYXVsdENvbnN0cnVjdG9yTWFya2VyAQADZ2V0AQAmKExqYXZhL2xh"
        + "bmcvT2JqZWN0OylMamF2YS9sYW5nL09iamVjdDsBAAUoSUkpVgEAA3B1dAEAOChMamF2YS9sYW5n"
        + "L09iamVjdDtMamF2YS9sYW5nL09iamVjdDspTGphdmEvbGFuZy9PYmplY3Q7AQAQZ2V0TGFzdENs"
        + "aWNrVGljawEAAygpSQEAEWdldExhc3RVcGRhdGVUaWNrADEADAANAAAAAQASABAAEQABABIAAAAC"
        + "ABMABwABABQAFQABABYAAAAoAAMAAQAAAAwquwABWbcAArcAA7EAAAABABcAAAAKAAIAAAAdAAsA"
        + "HgABABQAGAACABYAAAAqAAIAAgAAAAoqtwAEKiu1AAWxAAAAAQAXAAAADgADAAAAIAAEACEACQAi"
        + "ABIAAAACABkAAQAUABoAAgAWAAAATwADAAQAAAAWKhwEfpkADbsAAVm3AAKnAAQrtwADsQAAAAIA"
        + "FwAAAAoAAgAAACYAFQAnABsAAAAXAAJRBv8AAAAEBgcAHAEHAB0AAgYHABwAEgAAAAIAHgABAB8A"
        + "IAABABYAAAB4AAYABAAAAEEqtAAFLLkABgIAwAAHTi3HABoqtAAFLLsAB1kCG7cACLkACQMAV6cA"
        + "Giq0AAUsuwAHWS22AAobtwAIuQAJAwBXsQAAAAIAFwAAABYABQAAACoADgArABIALAApAC4AQAAw"
        + "ABsAAAAJAAL8ACkHACEWAAEAIgAjAAEAFgAAAMEABgAIAAAAayq0AAUsuQAGAgDAAAc6BBkExwAF"
        + "A6wZBLYACjYFGxUFZDYGFQYdowAHBKcABAM2BxUHmQAeKrQABSy7AAdZAhkEtgALtwAIuQAJAwBX"
        + "pwAbKrQABSy7AAdZGxkEtgALtwAIuQAJAwBXFQesAAAAAgAXAAAAKgAKAAAAMwAPADQAFAA1ABYA"
        + "NwAdADgAIwA5ADAAOgA1ADsAUAA9AGgAPwAbAAAAFAAF/AAWBwAh/QAWAQFAAfwAIQEXAAEAJAAl"
        + "AAEAFgAAAFwABgADAAAAKiq0AAUruQAGAgDAAAdNLMYAGiq0AAUruwAHWQIstgALtwAIuQAJAwBX"
        + "sQAAAAIAFwAAABIABAAAAEMADgBEABIARQApAEcAGwAAAAgAAfwAKQcAIQABACYAJwABABYAAAAZ"
        + "AAAAAgAAAAGxAAAAAQAXAAAABgABAAAASwACACgAAAACACkADwAAAAoAAQAHAAwADgAZ";

    private static final String[] MOD_DIRS = {
        Tools.DIR_GAME_PROFILE + "/mods",
        Tools.DIR_GAME_PROFILE + "/.minecraft/mods"
    };

    public static void patchAll() {
        int patched = 0;
        List<File> jars = new ArrayList<>();
        for (String dirPath : MOD_DIRS) {
            File dir = new File(dirPath);
            if (!dir.isDirectory()) continue;
            File[] files = dir.listFiles((d, name) -> name.endsWith(".jar"));
            if (files != null) jars.addAll(Arrays.asList(files));
        }
        Map<String, byte[]> replacements = new HashMap<String, byte[]>();
        replacements.put(TRANSPORT_ENTRY, generateTransportClass());
        try {
            replacements.put(DOUBLE_CLICK_ENTRY, Base64.getDecoder().decode(DOUBLE_CLICK_B64));
        } catch (IllegalArgumentException e) {
            System.err.println("[TCLoader] failed to decode DoubleClickCounter.class: " + e);
        }
        for (File jar : jars) {
            try {
                if (patchJarEntry(jar, replacements)) patched++;
            } catch (Exception e) {
                System.err.println("[TCLoader] failed on " + jar.getName() + ": " + e);
            }
        }
        if (patched > 0) {
            System.out.println("[TCLoader] patched " + patched + " class(es) in TouchController jar(s)");
        }
    }

    private static boolean patchJarEntry(File jar, Map<String, byte[]> replacements) throws IOException {
        boolean changed = false;
        File tmp = new File(jar.getParentFile(), jar.getName() + ".tcloader.tmp");
        byte[] buf = new byte[65536];
        // Read via ZipFile (central directory), NEVER ZipInputStream (local
        // headers): publisher zips exist whose local headers disagree with the
        // central directory, and streaming over them yields GARBAGE bytes for
        // some entries. That silently corrupted every nested jar inside
        // mod bundles like Essential (its embedded stage2 jar's MD5 changed,
        // so Essential's loader rejected its own payload and the mod never
        // appeared). ZipFile resolves entries through the central directory —
        // the same structure every consumer (unzip, JarFile) trusts.
        try (ZipFile zin = new ZipFile(jar);
             ZipOutputStream zout = new ZipOutputStream(new FileOutputStream(tmp))) {
            Enumeration<? extends ZipEntry> entries = zin.entries();
            while (entries.hasMoreElements()) {
                ZipEntry in = entries.nextElement();
                ZipEntry out = new ZipEntry(in.getName());
                out.setTime(in.getTime());
                zout.putNextEntry(out);
                byte[] replacement = replacements.get(in.getName());
                if (replacement != null) {
                    zout.write(replacement);
                    changed = true;
                } else if (in.getName().endsWith(".jar")) {
                    byte[] nestedBytes = readAll(zin.getInputStream(in));
                    // Only re-zip a nested jar when it REALLY contains a
                    // target entry (checked against its central directory).
                    // Untouched nested jars are written back unmodified, so
                    // their contents (and hashes) stay bit-exact.
                    if (nestedJarContainsAny(nestedBytes, replacements)) {
                        byte[] newNested = patchNestedJar(nestedBytes, replacements);
                        if (!Arrays.equals(nestedBytes, newNested)) changed = true;
                        nestedBytes = newNested;
                    }
                    zout.write(nestedBytes);
                } else {
                    InputStream inStream = zin.getInputStream(in);
                    int n;
                    while ((n = inStream.read(buf)) > 0) zout.write(buf, 0, n);
                    inStream.close();
                }
                zout.closeEntry();
            }
        }
        if (!changed) {
            tmp.delete();
            return false;
        }
        if (!tmp.renameTo(jar)) {
            java.nio.file.Files.move(tmp.toPath(), jar.toPath(),
                java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
        System.out.println("[TCLoader] replaced " + replacements.size() + " class(es) in " + jar.getName());
        return true;
    }

    private static byte[] readAll(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[65536];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        in.close();
        return out.toByteArray();
    }

    /** Accurate containment probe: scans the nested jar's central directory. */
    private static boolean nestedJarContainsAny(byte[] nestedJar, Map<String, byte[]> replacements) throws IOException {
        File tmp = File.createTempFile("tclscan", ".jar", new File(System.getProperty("java.io.tmpdir")));
        try {
            java.nio.file.Files.write(tmp.toPath(), nestedJar);
            try (ZipFile zip = new ZipFile(tmp)) {
                for (String name : replacements.keySet()) {
                    if (zip.getEntry(name) != null) return true;
                }
            } catch (ZipException e) {
                // Not a readable zip (some ".jar"-named resources aren't);
                // leave such entries untouched rather than failing the jar.
                return false;
            }
            return false;
        } finally {
            tmp.delete();
        }
    }

    private static byte[] patchNestedJar(byte[] nestedJar, Map<String, byte[]> replacements) throws IOException {
        File srcTmp = File.createTempFile("tclsrc", ".jar", new File(System.getProperty("java.io.tmpdir")));
        try {
            java.nio.file.Files.write(srcTmp.toPath(), nestedJar);
            ByteArrayOutputStream outBytes = new ByteArrayOutputStream();
            try (ZipFile zin = new ZipFile(srcTmp);
                 ZipOutputStream zout = new ZipOutputStream(outBytes)) {
                Enumeration<? extends ZipEntry> entries = zin.entries();
                byte[] buf = new byte[65536];
                while (entries.hasMoreElements()) {
                    ZipEntry in = entries.nextElement();
                    ZipEntry out = new ZipEntry(in.getName());
                    out.setTime(in.getTime());
                    zout.putNextEntry(out);
                    byte[] replacement = replacements.get(in.getName());
                    if (replacement != null) {
                        zout.write(replacement);
                    } else {
                        InputStream inStream = zin.getInputStream(in);
                        int n;
                        while ((n = inStream.read(buf)) > 0) zout.write(buf, 0, n);
                        inStream.close();
                    }
                    zout.closeEntry();
                }
            }
            return outBytes.toByteArray();
        } finally {
            srcTmp.delete();
        }
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

    private static void writeUtf8(DataOutputStream out, String s) throws IOException {
        out.writeByte(1);
        out.writeUTF(s);
    }

    private static void writeClassRef(DataOutputStream out, int utf8Index) throws IOException {
        out.writeByte(7);
        out.writeShort(utf8Index);
    }

    private static void writeNameAndType(DataOutputStream out, int name, int desc) throws IOException {
        out.writeByte(12);
        out.writeShort(name);
        out.writeShort(desc);
    }

    private static void writeMethodref(DataOutputStream out, int classIdx, int natIdx) throws IOException {
        out.writeByte(10);
        out.writeShort(classIdx);
        out.writeShort(natIdx);
    }

    private static void writeCodeAttribute(DataOutputStream out, int maxLocals, byte[] code) throws IOException {
        out.writeShort(28);  // attribute_name_index: Utf8 "Code"
        out.writeInt(12 + code.length); // attribute_length
        out.writeShort(2);   // max_stack
        out.writeShort(maxLocals);
        out.writeInt(code.length);
        out.write(code);
        out.writeShort(0);   // exception_table_length
        out.writeShort(0);   // attributes_count
    }

    /**
     * Builds a class file:
     *   public final class top.fifthlight.touchcontroller.common.platform.ios.Transport {
     *       public Transport();                                   // <init>
     *       public static native long new(String);
     *       public static native int receive(long, byte[]);
     *       public static native void send(long, byte[], int, int);
     *       public static native void init();                     // older mods
     *       public static native int receive(byte[]);             // older mods
     *       public static native void send(byte[], int, int);     // older mods
     *       static {
     *           System.load(System.getenv("BUNDLE_PATH") + "/Frameworks/libTouchControllerGameBridge.dylib");
     *       }
     *   }
     */
    public static byte[] generateTransportClass() {
        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(baos);

            out.writeInt(0xCAFEBABE);
            out.writeShort(0); // minor
            out.writeShort(52); // major (Java 8)
            out.writeShort(39); // constant_pool_count (39 entries: 1..38)

            // constant pool (1-indexed)
            writeUtf8(out, "top/fifthlight/touchcontroller/common/platform/ios/Transport"); // 1
            writeClassRef(out, 1);          // 2: this class
            writeUtf8(out, "java/lang/Object"); // 3
            writeClassRef(out, 3);          // 4: super class
            writeUtf8(out, "java/lang/System"); // 5
            writeClassRef(out, 5);          // 6
            writeUtf8(out, "java/lang/String"); // 7
            writeClassRef(out, 7);          // 8
            writeUtf8(out, "<init>");       // 9
            writeUtf8(out, "()V");          // 10
            writeNameAndType(out, 9, 10);   // 11
            writeMethodref(out, 4, 11);     // 12: Object.<init>
            writeUtf8(out, "new");          // 13
            writeUtf8(out, "(Ljava/lang/String;)J"); // 14
            writeUtf8(out, "receive");      // 15
            writeUtf8(out, "(J[B)I");       // 16
            writeUtf8(out, "send");         // 17
            writeUtf8(out, "(J[BII)V");     // 18
            writeUtf8(out, "init");         // 19
            writeUtf8(out, "([B)I");        // 20
            writeUtf8(out, "([BII)V");      // 21
            writeUtf8(out, "<clinit>");     // 22
            writeUtf8(out, "getenv");       // 23
            writeUtf8(out, "(Ljava/lang/String;)Ljava/lang/String;"); // 24
            writeUtf8(out, "concat");       // 25
            writeUtf8(out, "load");         // 26
            writeUtf8(out, "(Ljava/lang/String;)V"); // 27
            writeUtf8(out, "Code");         // 28
            writeUtf8(out, "BUNDLE_PATH");  // 29
            writeUtf8(out, "/Frameworks/libTouchControllerGameBridge.dylib"); // 30
            writeNameAndType(out, 23, 24);  // 31
            writeMethodref(out, 6, 31);     // 32: System.getenv
            writeNameAndType(out, 25, 24);  // 33
            writeMethodref(out, 8, 33);     // 34: String.concat
            writeNameAndType(out, 26, 27);  // 35
            writeMethodref(out, 6, 35);     // 36: System.load
            out.writeByte(8);               // CONSTANT_String
            out.writeShort(29);             // 37: "BUNDLE_PATH"
            out.writeByte(8);               // CONSTANT_String
            out.writeShort(30);             // 38: "/Frameworks/libTouchControllerGameBridge.dylib"

            out.writeShort(0x0021);         // ACC_PUBLIC | ACC_SUPER
            out.writeShort(2);              // this_class
            out.writeShort(4);              // super_class
            out.writeShort(0);              // interfaces_count

            // fields_count
            out.writeShort(0);

            // methods_count: <init>, <clinit>, 6 natives = 8
            out.writeShort(8);

            // <init>
            out.writeShort(0x0001);         // ACC_PUBLIC
            out.writeShort(9);              // name <init>
            out.writeShort(10);             // descriptor ()V
            out.writeShort(1);              // attributes_count
            writeCodeAttribute(out, 1, new byte[] {
                0x2A,             // aload_0
                (byte) 0xB7, 0x00, 0x0C,   // invokespecial #12
                (byte) 0xB1              // return
            });

            // native methods (no Code attribute)
            int nativeFlags = 0x0109;       // ACC_PUBLIC|ACC_STATIC|ACC_NATIVE
            writeNative(out, nativeFlags, 13, 14); // new(String)J
            writeNative(out, nativeFlags, 15, 16); // receive(J[B)I
            writeNative(out, nativeFlags, 17, 18); // send(J[BII)V
            writeNative(out, nativeFlags, 19, 20); // init()V
            writeNative(out, nativeFlags, 15, 21); // receive([B)I
            writeNative(out, nativeFlags, 17, 20); // send([BII)V

            // <clinit>
            out.writeShort(0x0008);         // ACC_STATIC
            out.writeShort(22);             // name <clinit>
            out.writeShort(10);             // descriptor ()V
            out.writeShort(1);              // attributes_count
            writeCodeAttribute(out, 0, new byte[] {
                0x12, 0x25,             // ldc #37 "BUNDLE_PATH"
                (byte) 0xB8, 0x00, 0x20, // invokestatic #32 System.getenv
                0x12, 0x26,             // ldc #38 "/Frameworks/..."
                (byte) 0xB6, 0x00, 0x22, // invokevirtual #34 String.concat
                (byte) 0xB8, 0x00, 0x24, // invokestatic #36 System.load
                (byte) 0xB1              // return
            });

            // class attributes
            out.writeShort(0);

            return baos.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Failed to generate Transport.class", e);
        }
    }

    private static void writeNative(DataOutputStream out, int flags, int nameIdx, int descIdx) throws IOException {
        out.writeShort(flags);
        out.writeShort(nameIdx);
        out.writeShort(descIdx);
        out.writeShort(0); // attributes_count
    }
}
