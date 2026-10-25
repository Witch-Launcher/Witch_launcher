package net.kdt.patchjna;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.HashMap;
import java.util.Map;

/**
 * Runtime compatibility layer for the unmodified Metallum jar.
 *
 * Metallum bundles MetalJVM inside its nested jar.  That copy is built for
 * macOS: it resolves MTLCopyAllDevices eagerly, asks SPIRV-Cross for macOS MSL
 * 4.0, and creates a CoreGraphics colour space for the Metal layer.  None of
 * those are available (or valid) on iOS.  Rather than requiring users to
 * replace the original mod, replace only the affected classes while they are
 * being defined.
 */
final class MetalCompatTransformer implements ClassFileTransformer {

    private static final Map<String, byte[]> PATCHES = new HashMap<String, byte[]>();

    static {
        String[] names = {
                "io/github/kokodio/metaljvm/metal/Metal",
                "io/github/kokodio/metaljvm/coregraphics/CGColorSpace",
                "com/metallum/render/MetalCrossShaderCompiler",
                "com/metallum/render/MetalUtilities",
                "com/metallum/render/MetalSurface"
        };
        for (String name : names) {
            byte[] bytes = read("/patched/" + name + ".class");
            if (bytes == null) {
                System.out.println("[MetalCompat] missing patch resource: " + name);
            } else {
                PATCHES.put(name, bytes);
            }
        }
    }

    public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
                            ProtectionDomain protectionDomain, byte[] classfileBuffer) {
        if (className == null) {
            return null;
        }
        byte[] patch = PATCHES.get(className);
        if (patch == null) {
            return null;
        }
        System.out.println("[MetalCompat] replaced " + className);
        return patch;
    }

    private static byte[] read(String path) {
        InputStream in = null;
        try {
            in = MetalCompatTransformer.class.getResourceAsStream(path);
            if (in == null) {
                return null;
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            while ((count = in.read(buffer)) != -1) {
                out.write(buffer, 0, count);
            }
            return out.toByteArray();
        } catch (Throwable t) {
            System.out.println("[MetalCompat] failed to read " + path + ": " + t);
            return null;
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (Throwable ignored) {
                }
            }
        }
    }
}
