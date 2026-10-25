package net.kdt.patchjna;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Makes Minecraft's RenderPearl backend request Vulkan 1.4 instead of 1.2.
 *
 * The bundled MoltenVK is already Vulkan 1.4 (and the loader is 1.4.362), but
 * RenderPearl hard-codes {@code VK12.VK_API_VERSION_1_2} in VkApplicationInfo.
 * MoltenVK then clamps its advertised device version to 1.2.  This transformer
 * rewrites only that constant use to the literal VK_API_VERSION_1_4 value.
 *
 * The device-capability check is deliberately left at 1.2: the instance can
 * request a newer API than a device supports, and older A13 devices still have
 * a usable Vulkan 1.2 path.
 */
final class Vulkan14Transformer implements ClassFileTransformer {

    private static final String INSTANCE_CLASS = "com/mojang/renderpearl/backend/vulkan/VulkanInstance";
    private static final String BACKEND_CLASS = "com/mojang/renderpearl/backend/vulkan/VulkanBackend";
    private static final String VK12_CLASS = "org/lwjgl/vulkan/VK12";
    private static final String VK12_FIELD = "VK_API_VERSION_1_2";
    private static final String INT_DESCRIPTOR = "I";
    private static final int VK_API_VERSION_1_4 = (1 << 22) | (4 << 12);
    private static final Logger LOG = Logger.getLogger("WitchVulkan");

    public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
                            ProtectionDomain protectionDomain, byte[] classfileBuffer) {
        if (INSTANCE_CLASS.equals(className) || BACKEND_CLASS.equals(className)) {
            byte[] patched = patch(classfileBuffer, className);
            if (patched != null) {
                LOG.info("requesting Vulkan 1.4 in " + className);
                return patched;
            }
        }
        return classfileBuffer;
    }

    static byte[] patch(byte[] bytes, String className) {
        try {
            if (bytes == null || bytes.length < 10) {
                return null;
            }
            ConstantPool cp = ConstantPool.read(bytes);
            if (cp == null) {
                return null;
            }
            int vk12 = cp.findClass(VK12_CLASS);
            int fieldName = cp.findUtf8(VK12_FIELD);
            int intDescriptor = cp.findUtf8(INT_DESCRIPTOR);
            int nameAndType = cp.findNameAndType(fieldName, intDescriptor);
            int fieldRef = cp.findFieldRef(vk12, nameAndType);
            if (fieldRef < 0) {
                return null;
            }

            int constantIndex = cp.findInteger(VK_API_VERSION_1_4);
            int extraLength = 0;
            if (constantIndex < 0) {
                if (cp.count >= 65535) {
                    return null;
                }
                constantIndex = cp.count;
                extraLength = 5;
            }

            byte[] out = bytes.clone();
            int patched = patchMethods(out, cp, className, fieldRef, constantIndex);
            if (patched == 0) {
                return null;
            }
            if (extraLength == 0) {
                return out;
            }

            byte[] result = new byte[out.length + extraLength];
            System.arraycopy(out, 0, result, 0, 8);
            int newCount = cp.count + 1;
            result[8] = (byte) (newCount >>> 8);
            result[9] = (byte) newCount;
            System.arraycopy(out, 10, result, 10, cp.end - 10);
            int offset = cp.end;
            result[offset++] = 3;
            result[offset++] = (byte) (VK_API_VERSION_1_4 >>> 24);
            result[offset++] = (byte) (VK_API_VERSION_1_4 >>> 16);
            result[offset++] = (byte) (VK_API_VERSION_1_4 >>> 8);
            result[offset] = (byte) VK_API_VERSION_1_4;
            System.arraycopy(out, cp.end, result, cp.end + extraLength, out.length - cp.end);
            return result;
        } catch (Throwable t) {
            LOG.log(Level.WARNING, "could not patch " + className + ": " + t, t);
            return null;
        }
    }

    private static int patchMethods(byte[] b, ConstantPool cp, String className,
                                    int fieldRef, int constantIndex) {
        int p = cp.end;
        p += 6;
        int interfaces = readU2(b, p);
        p += 2 + interfaces * 2;

        int fields = readU2(b, p);
        p += 2;
        for (int i = 0; i < fields; i++) {
            p += 6;
            int attrs = readU2(b, p);
            p += 2;
            for (int a = 0; a < attrs; a++) {
                p += 2;
                int length = readU4(b, p);
                p += 4 + length;
            }
        }
        if (p + 2 > b.length) {
            return 0;
        }

        int methods = readU2(b, p);
        p += 2;
        int patched = 0;
        for (int i = 0; i < methods; i++) {
            if (p + 8 > b.length) {
                return patched;
            }
            p += 2;
            int nameIndex = readU2(b, p);
            p += 2;
            p += 2;
            int attrs = readU2(b, p);
            p += 2;
            String methodName = cp.utf8(nameIndex);
            boolean patchMethod = INSTANCE_CLASS.equals(className) || "createVma".equals(methodName);
            for (int a = 0; a < attrs; a++) {
                if (p + 6 > b.length) {
                    return patched;
                }
                int attrName = readU2(b, p);
                p += 2;
                int length = readU4(b, p);
                p += 4;
                if (p + length > b.length) {
                    return patched;
                }
                if (patchMethod && "Code".equals(cp.utf8(attrName))) {
                    if (length >= 8) {
                        int codeLength = readU4(b, p + 4);
                        if (p + 8 + codeLength <= b.length) {
                            patched += patchCode(b, p + 8, codeLength, fieldRef, constantIndex);
                        }
                    }
                }
                p += length;
            }
        }
        return patched;
    }

    private static int patchCode(byte[] b, int start, int length, int fieldRef, int constantIndex) {
        int patched = 0;
        int pos = 0;
        while (pos < length) {
            int op = b[start + pos] & 0xFF;
            int size = instructionLength(b, start, length, pos);
            if (size <= 0 || pos + size > length) {
                return patched;
            }
            if (op == 0xB2 && size == 3) {
                int index = ((b[start + pos + 1] & 0xFF) << 8) | (b[start + pos + 2] & 0xFF);
                if (index == fieldRef) {
                    b[start + pos] = 0x13;
                    b[start + pos + 1] = (byte) (constantIndex >>> 8);
                    b[start + pos + 2] = (byte) constantIndex;
                    patched++;
                }
            }
            pos += size;
        }
        return patched;
    }

    private static int instructionLength(byte[] b, int start, int limit, int pos) {
        int op = b[start + pos] & 0xFF;
        switch (op) {
            case 0x10: return 2;
            case 0x11: return 3;
            case 0x12: return 2;
            case 0x13:
            case 0x14: return 3;
            case 0x15: case 0x16: case 0x17: case 0x18: case 0x19: return 2;
            case 0x36: case 0x37: case 0x38: case 0x39: case 0x3A: return 2;
            case 0x84: return 3;
            case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9E:
            case 0x9F: case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4:
            case 0xA5: case 0xA6: case 0xA7: case 0xA8: return 3;
            case 0xA9: return 2;
            case 0xAA: {
                int pad = (4 - ((pos + 1) & 3)) & 3;
                if (pos + 1 + pad + 12 > limit) return -1;
                int low = readS4(b, start + pos + 1 + pad + 4);
                int high = readS4(b, start + pos + 1 + pad + 8);
                long entries = (long) high - low + 1;
                if (entries < 0 || entries > limit) return -1;
                long size = 1L + pad + 12 + entries * 4;
                return size > Integer.MAX_VALUE ? -1 : (int) size;
            }
            case 0xAB: {
                int pad = (4 - ((pos + 1) & 3)) & 3;
                if (pos + 1 + pad + 8 > limit) return -1;
                int pairs = readS4(b, start + pos + 1 + pad + 4);
                if (pairs < 0 || (long) pairs > limit) return -1;
                long size = 1L + pad + 8 + (long) pairs * 8;
                return size > Integer.MAX_VALUE ? -1 : (int) size;
            }
            case 0xB2: case 0xB3: case 0xB4: case 0xB5:
            case 0xB6: case 0xB7: case 0xB8: return 3;
            case 0xB9:
            case 0xBA: return 5;
            case 0xBB: return 3;
            case 0xBC: return 2;
            case 0xBD: return 3;
            case 0xC0:
            case 0xC1: return 3;
            case 0xC4: {
                if (pos + 1 >= limit) return -1;
                int next = b[start + pos + 1] & 0xFF;
                return next == 0x84 ? 6 : 4;
            }
            case 0xC5: return 4;
            case 0xC6:
            case 0xC7: return 3;
            case 0xC8:
            case 0xC9: return 5;
            default:
                if (op <= 0x0F || (op >= 0x1A && op <= 0x35) || (op >= 0x3B && op <= 0x83)
                        || (op >= 0x85 && op <= 0x98) || (op >= 0xAC && op <= 0xB1)
                        || (op >= 0xBE && op <= 0xBF) || (op >= 0xC2 && op <= 0xC3)) {
                    return 1;
                }
                return -1;
        }
    }

    private static int readU2(byte[] b, int p) {
        return ((b[p] & 0xFF) << 8) | (b[p + 1] & 0xFF);
    }

    private static int readU4(byte[] b, int p) {
        return ((b[p] & 0xFF) << 24) | ((b[p + 1] & 0xFF) << 16)
                | ((b[p + 2] & 0xFF) << 8) | (b[p + 3] & 0xFF);
    }

    private static int readS4(byte[] b, int p) {
        return readU4(b, p);
    }

    private static final class ConstantPool {
        final int count;
        final int end;
        final int[] tags;
        final int[] ref1;
        final int[] ref2;
        final int[] integers;
        final String[] strings;

        private ConstantPool(int count, int end, int[] tags, int[] ref1, int[] ref2,
                             int[] integers, String[] strings) {
            this.count = count;
            this.end = end;
            this.tags = tags;
            this.ref1 = ref1;
            this.ref2 = ref2;
            this.integers = integers;
            this.strings = strings;
        }

        static ConstantPool read(byte[] b) throws Exception {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(b));
            if (in.readInt() != 0xCAFEBABE) {
                return null;
            }
            in.readUnsignedShort();
            in.readUnsignedShort();
            int count = in.readUnsignedShort();
            int[] tags = new int[count];
            int[] ref1 = new int[count];
            int[] ref2 = new int[count];
            int[] integers = new int[count];
            String[] strings = new String[count];
            int p = 10;
            for (int i = 1; i < count; i++) {
                if (p >= b.length) {
                    return null;
                }
                int tag = b[p++] & 0xFF;
                tags[i] = tag;
                switch (tag) {
                    case 1: {
                        int length = readU2(b, p);
                        p += 2;
                        if (p + length > b.length) {
                            return null;
                        }
                        strings[i] = new String(b, p, length, "UTF-8");
                        p += length;
                        break;
                    }
                    case 3:
                        integers[i] = readU4(b, p);
                        p += 4;
                        break;
                    case 4:
                        p += 4;
                        break;
                    case 5:
                    case 6:
                        p += 8;
                        i++;
                        break;
                    case 7:
                        ref1[i] = readU2(b, p);
                        p += 2;
                        break;
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
                        ref1[i] = readU2(b, p);
                        ref2[i] = readU2(b, p + 2);
                        p += 4;
                        break;
                    case 15:
                        p += 3;
                        break;
                    default:
                        return null;
                }
            }
            return new ConstantPool(count, p, tags, ref1, ref2, integers, strings);
        }

        String utf8(int index) {
            return index > 0 && index < count ? strings[index] : null;
        }

        int findUtf8(String value) {
            for (int i = 1; i < count; i++) {
                if (value.equals(strings[i])) {
                    return i;
                }
            }
            return -1;
        }

        int findClass(String name) {
            int nameIndex = findUtf8(name);
            if (nameIndex < 0) {
                return -1;
            }
            for (int i = 1; i < count; i++) {
                if (tags[i] == 7 && ref1[i] == nameIndex) {
                    return i;
                }
            }
            return -1;
        }

        int findNameAndType(int nameIndex, int descriptorIndex) {
            if (nameIndex < 0 || descriptorIndex < 0) {
                return -1;
            }
            for (int i = 1; i < count; i++) {
                if (tags[i] == 12 && ref1[i] == nameIndex && ref2[i] == descriptorIndex) {
                    return i;
                }
            }
            return -1;
        }

        int findFieldRef(int classIndex, int nameAndTypeIndex) {
            if (classIndex < 0 || nameAndTypeIndex < 0) {
                return -1;
            }
            for (int i = 1; i < count; i++) {
                if (tags[i] == 9 && ref1[i] == classIndex && ref2[i] == nameAndTypeIndex) {
                    return i;
                }
            }
            return -1;
        }

        int findInteger(int value) {
            for (int i = 1; i < count; i++) {
                if (tags[i] == 3 && integers[i] == value) {
                    return i;
                }
            }
            return -1;
        }
    }
}
