package net.kdt.patchjna;

import java.lang.instrument.ClassFileTransformer;
import java.nio.charset.StandardCharsets;
import java.security.ProtectionDomain;
import java.util.logging.Level;
import java.util.logging.Logger;

final class ShadercSyncTransformer implements ClassFileTransformer {

    private static final String TARGET = "org/lwjgl/util/shaderc/Shaderc";
    private static final int ACC_SYNCHRONIZED = 0x0020;
    private static final Logger LOG = Logger.getLogger("WitchShaderc");

    @Override
    public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
                            ProtectionDomain protectionDomain, byte[] classfileBuffer) {
        if (!TARGET.equals(className)) {
            return classfileBuffer;
        }
        byte[] patched = patch(classfileBuffer);
        if (patched == null) {
            return classfileBuffer;
        }
        LOG.info("serializing native shaderc compilation");
        return patched;
    }

    static byte[] patch(byte[] bytes) {
        try {
            if (bytes == null || bytes.length < 10 || readU4(bytes, 0) != 0xCAFEBABE) {
                return null;
            }
            int p = 8;
            int cpCount = readU2(bytes, p);
            p += 2;
            String[] utf8 = new String[cpCount];
            for (int i = 1; i < cpCount; i++) {
                int tag = bytes[p++] & 0xFF;
                switch (tag) {
                    case 1: {
                        int length = readU2(bytes, p);
                        p += 2;
                        utf8[i] = new String(bytes, p, length, StandardCharsets.UTF_8);
                        p += length;
                        break;
                    }
                    case 3:
                    case 4:
                        p += 4;
                        break;
                    case 5:
                    case 6:
                        p += 8;
                        i++;
                        break;
                    case 7:
                    case 8:
                    case 16:
                    case 19:
                    case 20:
                        p += 2;
                        break;
                    case 9:
                    case 10:
                    case 11:
                    case 12:
                    case 17:
                    case 18:
                        p += 4;
                        break;
                    case 15:
                        p += 3;
                        break;
                    default:
                        return null;
                }
                if (p > bytes.length) {
                    return null;
                }
            }

            p += 6;
            int interfaces = readU2(bytes, p);
            p += 2 + interfaces * 2;
            int fields = readU2(bytes, p);
            p += 2;
            for (int i = 0; i < fields; i++) {
                p += 6;
                int attributes = readU2(bytes, p);
                p += 2;
                for (int a = 0; a < attributes; a++) {
                    p += 2;
                    int length = readU4(bytes, p);
                    p += 4 + length;
                }
            }

            int methods = readU2(bytes, p);
            p += 2;
            byte[] out = null;
            int patched = 0;
            for (int i = 0; i < methods; i++) {
                int accessOffset = p;
                int access = readU2(bytes, p);
                p += 2;
                int nameIndex = readU2(bytes, p);
                p += 2;
                int descriptorIndex = readU2(bytes, p);
                p += 2;
                int attributes = readU2(bytes, p);
                p += 2;

                String name = nameIndex < utf8.length ? utf8[nameIndex] : null;
                String descriptor = descriptorIndex < utf8.length ? utf8[descriptorIndex] : null;
                if (name != null && name.startsWith("nshaderc_compile_into_")
                        && descriptor != null && descriptor.startsWith("(JJJ")) {
                    if (out == null) {
                        out = bytes.clone();
                    }
                    int newAccess = access | ACC_SYNCHRONIZED;
                    out[accessOffset] = (byte) (newAccess >>> 8);
                    out[accessOffset + 1] = (byte) newAccess;
                    patched++;
                }

                for (int a = 0; a < attributes; a++) {
                    p += 2;
                    int length = readU4(bytes, p);
                    p += 4 + length;
                }
                if (p > bytes.length) {
                    return null;
                }
            }
            return patched == 0 ? null : out;
        } catch (Throwable t) {
            LOG.log(Level.WARNING, "could not patch Shaderc: " + t, t);
            return null;
        }
    }

    private static int readU2(byte[] bytes, int offset) {
        return ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);
    }

    private static int readU4(byte[] bytes, int offset) {
        return ((bytes[offset] & 0xFF) << 24) | ((bytes[offset + 1] & 0xFF) << 16)
                | ((bytes[offset + 2] & 0xFF) << 8) | (bytes[offset + 3] & 0xFF);
    }
}
