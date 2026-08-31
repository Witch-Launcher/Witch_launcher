package net.vda.witchlaunch.framegen;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;

public class FrameGenPatcher implements ClassFileTransformer {

    private static final String[] TARGET_CLASSES = {
        "net.minecraft.client.render.GameRenderer",
        "net/minecraft/client/render/GameRenderer",
        "com.mojang.blaze3d.platform.Window",
        "net/minecraft/client/Minecraft",
        "net/minecraft/client/renderer/GameRenderer"
    };

    private static final String BRIDGE_CLASS_INTERNAL = "net/vda/witchlaunch/framegen/FrameGenBridge";

    private final Instrumentation instrumentation;

    public FrameGenPatcher(Instrumentation inst) {
        this.instrumentation = inst;
    }

    public static void install(Instrumentation inst) {
        if (inst == null) {
            System.err.println("[FrameGenPatcher] No Instrumentation available, cannot patch");
            return;
        }
        FrameGenPatcher patcher = new FrameGenPatcher(inst);
        inst.addTransformer(patcher, true);
        System.out.println("[FrameGenPatcher] Installed on Instrumentation (bytecode patching disabled)");
        // No retransformClasses needed — camera capture is done from native side via JNI.
    }

    private static int transformCount;
    private static int mcClassCount;

    @Override
    public byte[] transform(ClassLoader loader, String className,
                            Class<?> classBeingRedefined,
                            ProtectionDomain protectionDomain,
                            byte[] classfileBuffer) {
        // Bytecode patching disabled — camera capture is now done from native
        // side via JNI (fg_on_next_drawable → FrameGenBridge.captureCameraData).
        // Cache the game classloader so captureCameraData can find Minecraft classes.
        if (loader != null && className != null) {
            if (className.contains("minecraft") || className.contains("Minecraft")) {
                FrameGenBridge.setGameClassLoader(loader);
                if (++mcClassCount <= 3) {
                    System.out.println("[FrameGenPatcher] Cached game classloader from: "
                        + className + " loader=" + loader.getClass().getName());
                }
            }
            if (++transformCount <= 5 || transformCount % 1000 == 0) {
                System.out.println("[FrameGenPatcher] transform #" + transformCount
                    + " class=" + className);
            }
        }
        return null;
    }

    private byte[] patchClass(byte[] classfileBuffer) throws IOException {
        ClassFileParser parser = new ClassFileParser(classfileBuffer);
        if (!parser.isValid()) {
            System.err.println("[FrameGenPatcher] Not a valid class file");
            return classfileBuffer;
        }

        boolean modified = false;
        for (MethodInfo method : parser.methods) {
            String name = parser.getUtf8(method.nameIndex);
            String desc = parser.getUtf8(method.descriptorIndex);

            if (name != null && desc != null
                    && (name.equals("render") || name.equals("updateCamera")
                        || name.equals("updateCameraAndProjection") || name.equals("renderLevel"))
                    && desc.contains(")V")) {
                System.out.println("[FrameGenPatcher] Patching method: " + name + desc);
                method.code = injectCameraCall(parser, method.code);
                method.codeExcAndSubAttrs = null; // old offsets invalid after bytecode modification
                modified = true;
            }
        }

        return modified ? parser.write() : classfileBuffer;
    }

    private byte[] injectCameraCall(ClassFileParser parser, byte[] originalCode) throws IOException {
        if (originalCode == null || originalCode.length == 0) return originalCode;

        int cpBridgeClass = parser.constantPool.addClass(BRIDGE_CLASS_INTERNAL);
        int cpMethodRef = parser.constantPool.addMethodref(cpBridgeClass,
                "updateCameraFromGameRenderer", "(Ljava/lang/Object;)V");

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);

        out.writeByte(0x2A); // aload_0 (this)
        out.writeByte(0xB8); // invokestatic
        out.writeShort(cpMethodRef);
        out.write(originalCode);

        return baos.toByteArray();
    }

    // ============================================================
    // Minimal class file parser
    // ============================================================

    static class ClassFileParser {
        final ConstantPool constantPool;
        final MethodInfo[] methods;
        final byte[] rawFieldBytes;
        final byte[] rawClassAttributes;
        final int fieldCount;
        final int accessFlags, thisClass, superClass;
        final int[] interfaces;
        final int minorVersion, majorVersion;

        ClassFileParser(byte[] data) throws IOException {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(data));

            int magic = in.readInt();
            if (magic != 0xCAFEBABE) throw new IOException("Not a valid class file");

            minorVersion = in.readUnsignedShort();
            majorVersion = in.readUnsignedShort();

            int cpCount = in.readUnsignedShort();
            constantPool = new ConstantPool(cpCount);
            constantPool.read(in);

            accessFlags = in.readUnsignedShort();
            thisClass = in.readUnsignedShort();
            superClass = in.readUnsignedShort();

            int ifaceCount = in.readUnsignedShort();
            interfaces = new int[ifaceCount];
            for (int i = 0; i < ifaceCount; i++) interfaces[i] = in.readUnsignedShort();

            fieldCount = in.readUnsignedShort();
            rawFieldBytes = skipFieldsAndCaptureRaw(in, fieldCount);

            int methodCount = in.readUnsignedShort();
            methods = new MethodInfo[methodCount];
            for (int i = 0; i < methodCount; i++) {
                methods[i] = MethodInfo.read(in, constantPool);
            }

            // Capture class attributes as raw bytes (BootstrapMethods, etc.)
            ByteArrayOutputStream classAttrBuf = new ByteArrayOutputStream();
            int classAttrCount = in.readUnsignedShort();
            writeShortBE(classAttrBuf, classAttrCount);
            for (int i = 0; i < classAttrCount; i++) {
                int nameIdx = in.readUnsignedShort();
                writeShortBE(classAttrBuf, nameIdx);
                int len = in.readInt();
                writeIntBE(classAttrBuf, len);
                byte[] attrData = new byte[len];
                in.readFully(attrData);
                classAttrBuf.write(attrData);
            }
            rawClassAttributes = classAttrBuf.toByteArray();
        }

        boolean isValid() { return constantPool != null; }
        String getUtf8(int idx) { return constantPool.getUtf8(idx); }

        byte[] write() throws IOException {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(baos);

            out.writeInt(0xCAFEBABE);
            out.writeShort(minorVersion);
            out.writeShort(majorVersion);

            constantPool.write(out);
            out.writeShort(accessFlags);
            out.writeShort(thisClass);
            out.writeShort(superClass);
            out.writeShort(interfaces.length);
            for (int i : interfaces) out.writeShort(i);

            out.writeShort(fieldCount);
            out.write(rawFieldBytes);

            out.writeShort(methods.length);
            for (MethodInfo m : methods) m.write(out, constantPool);

            out.write(rawClassAttributes);

            return baos.toByteArray();
        }

        static void writeShortBE(ByteArrayOutputStream out, int val) {
            out.write((val >> 8) & 0xFF);
            out.write(val & 0xFF);
        }

        static void writeIntBE(ByteArrayOutputStream out, int val) {
            out.write((val >> 24) & 0xFF);
            out.write((val >> 16) & 0xFF);
            out.write((val >> 8) & 0xFF);
            out.write(val & 0xFF);
        }

        private static byte[] skipFieldsAndCaptureRaw(DataInputStream in, int count) throws IOException {
            ByteArrayOutputStream tmp = new ByteArrayOutputStream(4096);
            for (int i = 0; i < count; i++) {
                int af = in.readUnsignedShort();
                tmp.write((af >> 8) & 0xFF);
                tmp.write(af & 0xFF);
                int ni = in.readUnsignedShort();
                tmp.write((ni >> 8) & 0xFF);
                tmp.write(ni & 0xFF);
                int di = in.readUnsignedShort();
                tmp.write((di >> 8) & 0xFF);
                tmp.write(di & 0xFF);
                int attrCount = in.readUnsignedShort();
                tmp.write((attrCount >> 8) & 0xFF);
                tmp.write(attrCount & 0xFF);
                for (int j = 0; j < attrCount; j++) {
                    int attrNameIdx = in.readUnsignedShort();
                    tmp.write((attrNameIdx >> 8) & 0xFF);
                    tmp.write(attrNameIdx & 0xFF);
                    int len = in.readInt();
                    tmp.write((len >> 24) & 0xFF);
                    tmp.write((len >> 16) & 0xFF);
                    tmp.write((len >> 8) & 0xFF);
                    tmp.write(len & 0xFF);
                    byte[] attrData = new byte[len];
                    in.readFully(attrData);
                    tmp.write(attrData);
                }
            }
            return tmp.toByteArray();
        }
    }

    // ============================================================
    // Constant pool — raw-bytes, no per-entry object allocation
    // ============================================================

    static class ConstantPool {
        private final int entryCount;
        private final ByteArrayOutputStream rawBuf;
        private byte[] rawEntries;
        private int rawEntriesLen;
        private final int[] utf8Offsets;
        private final int[] utf8Lens;
        private final ByteArrayOutputStream newEntriesBuf;
        private int nextIndex;

        ConstantPool(int count) {
            this.entryCount = count;
            this.rawBuf = new ByteArrayOutputStream(count * 8);
            this.utf8Offsets = new int[count];
            this.utf8Lens = new int[count];
            java.util.Arrays.fill(utf8Offsets, -1);
            this.newEntriesBuf = new ByteArrayOutputStream(64);
            this.nextIndex = count;
        }

        void read(DataInputStream in) throws IOException {
            int idx = 1;
            while (idx < entryCount) {
                int tag = in.readUnsignedByte();
                rawBuf.write(tag);
                switch (tag) {
                    case 1: {
                        int len = in.readUnsignedShort();
                        rawBuf.write((len >> 8) & 0xFF);
                        rawBuf.write(len & 0xFF);
                        int off = rawBuf.size();
                        byte[] tmp = new byte[len];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        utf8Offsets[idx] = off;
                        utf8Lens[idx] = len;
                        break;
                    }
                    case 3: case 4: {
                        byte[] tmp = new byte[4];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        break;
                    }
                    case 5: case 6: {
                        byte[] tmp = new byte[8];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        idx++;
                        break;
                    }
                    case 7: case 8: case 16: {
                        byte[] tmp = new byte[2];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        break;
                    }
                    case 9: case 10: case 11: case 12: case 18: {
                        byte[] tmp = new byte[4];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        break;
                    }
                    case 15: {
                        byte[] tmp = new byte[3];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        break;
                    }
                    default:
                        throw new IOException("Unknown CP tag: " + tag);
                }
                idx++;
            }
            rawEntries = rawBuf.toByteArray();
            rawEntriesLen = rawEntries.length;
        }

        void write(DataOutputStream out) throws IOException {
            out.writeShort(nextIndex);
            out.write(rawEntries, 0, rawEntriesLen);
            byte[] newEntries = newEntriesBuf.toByteArray();
            if (newEntries.length > 0) out.write(newEntries);
        }

        String getUtf8(int index) {
            if (index < 1 || index >= entryCount) return null;
            int off = utf8Offsets[index];
            if (off < 0) return null;
            return decodeModifiedUtf8(rawEntries, off, utf8Lens[index]);
        }

        int addUtf8(String value) {
            int existing = findUtf8(value);
            if (existing >= 0) return existing;
            int idx = nextIndex++;
            byte[] encoded = encodeModifiedUtf8(value);
            newEntriesBuf.write(1);
            newEntriesBuf.write((encoded.length >> 8) & 0xFF);
            newEntriesBuf.write(encoded.length & 0xFF);
            newEntriesBuf.write(encoded, 0, encoded.length);
            return idx;
        }

        int addClass(String name) {
            int nameIdx = addUtf8(name);
            int existing = findClassByNameIndex(nameIdx);
            if (existing >= 0) return existing;
            int idx = nextIndex++;
            newEntriesBuf.write(7);
            newEntriesBuf.write((nameIdx >> 8) & 0xFF);
            newEntriesBuf.write(nameIdx & 0xFF);
            return idx;
        }

        int addNameAndType(String name, String desc) {
            int nIdx = addUtf8(name);
            int dIdx = addUtf8(desc);
            int existing = findNameAndType(nIdx, dIdx);
            if (existing >= 0) return existing;
            int idx = nextIndex++;
            newEntriesBuf.write(12);
            newEntriesBuf.write((nIdx >> 8) & 0xFF);
            newEntriesBuf.write(nIdx & 0xFF);
            newEntriesBuf.write((dIdx >> 8) & 0xFF);
            newEntriesBuf.write(dIdx & 0xFF);
            return idx;
        }

        int addMethodref(int classIdx, String name, String desc) {
            int ntIdx = addNameAndType(name, desc);
            int existing = findMethodref(classIdx, ntIdx);
            if (existing >= 0) return existing;
            int idx = nextIndex++;
            newEntriesBuf.write(10);
            newEntriesBuf.write((classIdx >> 8) & 0xFF);
            newEntriesBuf.write(classIdx & 0xFF);
            newEntriesBuf.write((ntIdx >> 8) & 0xFF);
            newEntriesBuf.write(ntIdx & 0xFF);
            return idx;
        }

        // --- Raw-byte scanning helpers ---

        private int findUtf8(String value) {
            byte[] valueBytes = encodeModifiedUtf8(value);
            int pos = 0;
            int idx = 1;
            while (pos < rawEntriesLen && idx < entryCount) {
                int tag = rawEntries[pos++] & 0xFF;
                if (tag == 1) {
                    int len = ((rawEntries[pos] & 0xFF) << 8) | (rawEntries[pos + 1] & 0xFF);
                    pos += 2;
                    if (len == valueBytes.length) {
                        boolean match = true;
                        for (int j = 0; j < len; j++) {
                            if (rawEntries[pos + j] != valueBytes[j]) {
                                match = false;
                                break;
                            }
                        }
                        if (match) return idx;
                    }
                    pos += len;
                } else {
                    pos += entryDataSize(tag);
                }
                if (tag == 5 || tag == 6) idx++;
                idx++;
            }
            return -1;
        }

        private int findClassByNameIndex(int nameIndex) {
            int pos = 0;
            int idx = 1;
            while (pos < rawEntriesLen && idx < entryCount) {
                int tag = rawEntries[pos++] & 0xFF;
                if (tag == 7) {
                    int cnIdx = ((rawEntries[pos] & 0xFF) << 8) | (rawEntries[pos + 1] & 0xFF);
                    if (cnIdx == nameIndex) return idx;
                }
                pos += entryDataSize(tag);
                if (tag == 5 || tag == 6) idx++;
                idx++;
            }
            return -1;
        }

        private int findNameAndType(int nameIdx, int descIdx) {
            int pos = 0;
            int idx = 1;
            while (pos < rawEntriesLen && idx < entryCount) {
                int tag = rawEntries[pos++] & 0xFF;
                if (tag == 12) {
                    int nIdx = ((rawEntries[pos] & 0xFF) << 8) | (rawEntries[pos + 1] & 0xFF);
                    int dIdx = ((rawEntries[pos + 2] & 0xFF) << 8) | (rawEntries[pos + 3] & 0xFF);
                    if (nIdx == nameIdx && dIdx == descIdx) return idx;
                }
                pos += entryDataSize(tag);
                if (tag == 5 || tag == 6) idx++;
                idx++;
            }
            return -1;
        }

        private int findMethodref(int classIdx, int natIdx) {
            int pos = 0;
            int idx = 1;
            while (pos < rawEntriesLen && idx < entryCount) {
                int tag = rawEntries[pos++] & 0xFF;
                if (tag == 10) {
                    int cIdx = ((rawEntries[pos] & 0xFF) << 8) | (rawEntries[pos + 1] & 0xFF);
                    int nIdx = ((rawEntries[pos + 2] & 0xFF) << 8) | (rawEntries[pos + 3] & 0xFF);
                    if (cIdx == classIdx && nIdx == natIdx) return idx;
                }
                pos += entryDataSize(tag);
                if (tag == 5 || tag == 6) idx++;
                idx++;
            }
            return -1;
        }

        private static int entryDataSize(int tag) {
            switch (tag) {
                case 3: case 4: return 4;
                case 5: case 6: return 8;
                case 7: case 8: case 16: return 2;
                case 9: case 10: case 11: case 12: case 18: return 4;
                case 15: return 3;
                default: return 0;
            }
        }

        // --- Modified UTF-8 encoding/decoding ---

        private static byte[] encodeModifiedUtf8(String s) {
            int len = s.length();
            boolean allAscii = true;
            for (int i = 0; i < len; i++) {
                char c = s.charAt(i);
                if (c > 0x7F || c == 0) { allAscii = false; break; }
            }
            if (allAscii) {
                byte[] r = new byte[len];
                for (int i = 0; i < len; i++) r[i] = (byte) s.charAt(i);
                return r;
            }
            int byteLen = 0;
            for (int i = 0; i < len; i++) {
                char c = s.charAt(i);
                if (c >= 1 && c <= 0x7F) byteLen++;
                else if (c <= 0x7FF) byteLen += 2;
                else byteLen += 3;
            }
            byte[] r = new byte[byteLen];
            int p = 0;
            for (int i = 0; i < len; i++) {
                char c = s.charAt(i);
                if (c >= 1 && c <= 0x7F) {
                    r[p++] = (byte) c;
                } else if (c <= 0x7FF) {
                    r[p++] = (byte) (0xC0 | ((c >> 6) & 0x1F));
                    r[p++] = (byte) (0x80 | (c & 0x3F));
                } else {
                    r[p++] = (byte) (0xE0 | ((c >> 12) & 0x0F));
                    r[p++] = (byte) (0x80 | ((c >> 6) & 0x3F));
                    r[p++] = (byte) (0x80 | (c & 0x3F));
                }
            }
            return r;
        }

        private static String decodeModifiedUtf8(byte[] data, int offset, int length) {
            byte[] buf = new byte[2 + length];
            buf[0] = (byte) ((length >> 8) & 0xFF);
            buf[1] = (byte) (length & 0xFF);
            System.arraycopy(data, offset, buf, 2, length);
            try {
                return new DataInputStream(new ByteArrayInputStream(buf)).readUTF();
            } catch (IOException e) {
                return null;
            }
        }
    }

    // ============================================================
    // MethodInfo — preserves non-Code attributes
    // ============================================================

    static class MethodInfo {
        int accessFlags, nameIndex, descriptorIndex;
        byte[] code;
        int maxStack = 64, maxLocals = 64;
        byte[] nonCodeAttrs;
        int nonCodeAttrCount;
        byte[] codeExcAndSubAttrs; // exception table + Code sub-attributes (StackMapTable, etc.)

        static MethodInfo read(DataInputStream in, ConstantPool cp) throws IOException {
            MethodInfo m = new MethodInfo();
            m.accessFlags = in.readUnsignedShort();
            m.nameIndex = in.readUnsignedShort();
            m.descriptorIndex = in.readUnsignedShort();
            int attrCount = in.readUnsignedShort();

            ByteArrayOutputStream otherAttrs = new ByteArrayOutputStream();
            int otherCount = 0;

            for (int i = 0; i < attrCount; i++) {
                int nameIdx = in.readUnsignedShort();
                int length = in.readInt();
                String name = cp.getUtf8(nameIdx);
                if ("Code".equals(name) && m.code == null) {
                    m.maxStack = in.readUnsignedShort();
                    m.maxLocals = in.readUnsignedShort();
                    int codeLen = in.readInt();
                    m.code = new byte[codeLen];
                    in.readFully(m.code);
                    ByteArrayOutputStream excSubBuf = new ByteArrayOutputStream();
                    int excCount = in.readUnsignedShort();
                    writeShortBE(excSubBuf, excCount);
                    for (int j = 0; j < excCount; j++) {
                        byte[] excEntry = new byte[8];
                        in.readFully(excEntry);
                        excSubBuf.write(excEntry);
                    }
                    int subAttrCount = in.readUnsignedShort();
                    writeShortBE(excSubBuf, subAttrCount);
                    for (int j = 0; j < subAttrCount; j++) {
                        int subNameIdx = in.readUnsignedShort();
                        writeShortBE(excSubBuf, subNameIdx);
                        int subLen = in.readInt();
                        writeIntBE(excSubBuf, subLen);
                        byte[] subData = new byte[subLen];
                        in.readFully(subData);
                        excSubBuf.write(subData);
                    }
                    m.codeExcAndSubAttrs = excSubBuf.toByteArray();
                } else {
                    writeShortBE(otherAttrs, nameIdx);
                    writeIntBE(otherAttrs, length);
                    byte[] data = new byte[length];
                    in.readFully(data);
                    otherAttrs.write(data);
                    otherCount++;
                }
            }
            m.nonCodeAttrs = otherAttrs.toByteArray();
            m.nonCodeAttrCount = otherCount;
            return m;
        }

        void write(DataOutputStream out, ConstantPool cp) throws IOException {
            out.writeShort(accessFlags);
            out.writeShort(nameIndex);
            out.writeShort(descriptorIndex);
            int totalAttrs = (code != null ? 1 : 0) + nonCodeAttrCount;
            out.writeShort(totalAttrs);
            if (nonCodeAttrs != null && nonCodeAttrs.length > 0) {
                out.write(nonCodeAttrs);
            }
            if (code != null) {
                out.writeShort(cp.addUtf8("Code"));
                ByteArrayOutputStream codeBaos = new ByteArrayOutputStream();
                DataOutputStream codeOut = new DataOutputStream(codeBaos);
                codeOut.writeShort(maxStack);
                codeOut.writeShort(maxLocals);
                codeOut.writeInt(code.length);
                codeOut.write(code);
                if (codeExcAndSubAttrs != null) {
                    codeOut.write(codeExcAndSubAttrs);
                } else {
                    codeOut.writeShort(0);
                    codeOut.writeShort(0);
                }
                codeOut.flush();
                byte[] codeAttrData = codeBaos.toByteArray();
                out.writeInt(codeAttrData.length);
                out.write(codeAttrData);
            }
        }

        static void writeShortBE(ByteArrayOutputStream out, int val) {
            out.write((val >> 8) & 0xFF);
            out.write(val & 0xFF);
        }

        static void writeIntBE(ByteArrayOutputStream out, int val) {
            out.write((val >> 24) & 0xFF);
            out.write((val >> 16) & 0xFF);
            out.write((val >> 8) & 0xFF);
            out.write(val & 0xFF);
        }
    }
}
