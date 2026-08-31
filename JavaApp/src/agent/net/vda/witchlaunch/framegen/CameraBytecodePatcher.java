package net.vda.witchlaunch.framegen;

import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

public class CameraBytecodePatcher {

    private static final String TARGET_CLASS = "net/minecraft/client/render/GameRenderer";
    private static final String BRIDGE_CLASS = "net/vda/witchlaunch/framegen/FrameGenBridge";
    private static final String UPDATE_CAMERA_METHOD = "updateCamera";
    private static final String UPDATE_CAMERA_SIG = "(FFFF[F[FFII)V";

    private byte[] classfileBuffer;
    private ConstantPool constantPool;
    private List<MethodInfo> methods;
    private int accessFlags;
    private int thisClass;
    private int superClass;
    private int[] interfaces;
    private FieldInfo[] fields;
    private AttributeInfo[] attributes;

    public static byte[] patch(byte[] classfileBuffer) {
        try {
            CameraBytecodePatcher patcher = new CameraBytecodePatcher(classfileBuffer);
            return patcher.patch();
        } catch (Throwable t) {
            System.err.println("[CameraBytecodePatcher] Patch failed: " + t);
            t.printStackTrace();
            return classfileBuffer;
        }
    }

    private CameraBytecodePatcher(byte[] classfileBuffer) throws IOException {
        this.classfileBuffer = classfileBuffer;
        parse();
    }

    private void parse() throws IOException {
        DataInputStream in = new DataInputStream(new java.io.ByteArrayInputStream(classfileBuffer));

        int magic = in.readInt();
        if (magic != 0xCAFEBABE) {
            throw new IOException("Not a valid class file");
        }

        in.readShort(); // minor_version
        in.readShort(); // major_version

        int cpCount = in.readUnsignedShort();
        constantPool = new ConstantPool(cpCount);
        constantPool.read(in);

        accessFlags = in.readUnsignedShort();
        thisClass = in.readUnsignedShort();
        superClass = in.readUnsignedShort();

        int interfacesCount = in.readUnsignedShort();
        interfaces = new int[interfacesCount];
        for (int i = 0; i < interfacesCount; i++) {
            interfaces[i] = in.readUnsignedShort();
        }

        int fieldsCount = in.readUnsignedShort();
        fields = new FieldInfo[fieldsCount];
        for (int i = 0; i < fieldsCount; i++) {
            fields[i] = FieldInfo.read(in, constantPool);
        }

        int methodsCount = in.readUnsignedShort();
        methods = new ArrayList<>(methodsCount);
        for (int i = 0; i < methodsCount; i++) {
            MethodInfo mi = MethodInfo.read(in, constantPool);
            methods.add(mi);
        }

        int attributesCount = in.readUnsignedShort();
        attributes = new AttributeInfo[attributesCount];
        for (int i = 0; i < attributesCount; i++) {
            attributes[i] = AttributeInfo.read(in, constantPool);
        }
    }

    private byte[] patch() throws IOException {
        boolean modified = false;

        for (MethodInfo method : methods) {
            if (shouldPatchMethod(method)) {
                String methodName = constantPool.getUtf8(method.nameIndex);
                System.out.println("[CameraBytecodePatcher] Patching method: " + methodName);
                try {
                    method.code = injectCameraCall(method.code);
                } catch (IOException e) {
                    System.err.println("[CameraBytecodePatcher] Failed to inject camera call: " + e);
                    e.printStackTrace();
                }
                modified = true;
            }
        }

        if (!modified) {
            System.out.println("[CameraBytecodePatcher] No suitable method found to patch");
            return classfileBuffer;
        }

        return writeClassfile();
    }

    private boolean shouldPatchMethod(MethodInfo method) {
        String name = constantPool.getUtf8(method.nameIndex);
        String desc = constantPool.getUtf8(method.descriptorIndex);

        return (name.equals("render") || name.equals("updateCamera") || name.equals("updateCameraAndProjection") || name.equals("renderLevel"))
                && desc.contains(")V");
    }

    private byte[] injectCameraCall(byte[] originalCode) throws IOException {
        if (originalCode == null || originalCode.length == 0) {
            return originalCode;
        }

        int cpBridgeClass = constantPool.addClass(BRIDGE_CLASS);
        int cpMethodRef = constantPool.addMethodref(cpBridgeClass, UPDATE_CAMERA_METHOD, UPDATE_CAMERA_SIG);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);

        int originalLen = originalCode.length;
        int maxStack = 16;

        out.writeByte(0xB8); // invokestatic
        out.writeShort(cpMethodRef);

        for (int i = 0; i < originalLen; i++) {
            out.writeByte(originalCode[i] & 0xFF);
        }

        return baos.toByteArray();
    }

    private byte[] writeClassfile() throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);

        out.writeInt(0xCAFEBABE);
        out.writeShort(0); // minor_version
        out.writeShort(52); // major_version (Java 8)

        constantPool.write(out);

        out.writeShort(accessFlags);
        out.writeShort(thisClass);
        out.writeShort(superClass);

        out.writeShort(interfaces.length);
        for (int i : interfaces) out.writeShort(i);

        out.writeShort(fields.length);
        for (FieldInfo f : fields) f.write(out);

        out.writeShort(methods.size());
        for (MethodInfo m : methods) m.write(out, constantPool);

        out.writeShort(attributes.length);
        for (AttributeInfo a : attributes) a.write(out);

        return baos.toByteArray();
    }

    static class ConstantPool {
        private final List<CpEntry> entries = new ArrayList<>();
        private final List<String> utf8Cache = new ArrayList<>();

        ConstantPool(int count) {
            entries.add(null); // index 0 unused
        }

        void read(DataInputStream in) throws IOException {
            int count = entries.size(); // already set from constructor
            for (int i = 1; i < count; i++) {
                int tag = in.readUnsignedByte();
                CpEntry entry = readEntry(in, tag);
                entries.add(entry);
                if (tag == 1) { // CONSTANT_Utf8
                    utf8Cache.add(((CpUtf8) entry).value);
                } else {
                    utf8Cache.add(null);
                }
                if (tag == 5 || tag == 6) { // Long/Double take 2 slots
                    entries.add(null);
                    utf8Cache.add(null);
                    i++;
                }
            }
        }

        private CpEntry readEntry(DataInputStream in, int tag) throws IOException {
            switch (tag) {
                case 1: return new CpUtf8(in.readUTF());
                case 3: return new CpInteger(in.readInt());
                case 4: return new CpFloat(in.readFloat());
                case 5: return new CpLong(in.readLong());
                case 6: return new CpDouble(in.readDouble());
                case 7: return new CpClass(in.readUnsignedShort());
                case 8: return new CpString(in.readUnsignedShort());
                case 9: return new CpFieldref(in.readUnsignedShort(), in.readUnsignedShort());
                case 10: return new CpMethodref(in.readUnsignedShort(), in.readUnsignedShort());
                case 11: return new CpInterfaceMethodref(in.readUnsignedShort(), in.readUnsignedShort());
                case 12: return new CpNameAndType(in.readUnsignedShort(), in.readUnsignedShort());
                case 15: return new CpMethodHandle(in.readUnsignedByte(), in.readUnsignedShort());
                case 16: return new CpMethodType(in.readUnsignedShort());
                case 18: return new CpInvokeDynamic(in.readUnsignedShort(), in.readUnsignedShort());
                default: throw new IOException("Unknown constant pool tag: " + tag);
            }
        }

        void write(DataOutputStream out) throws IOException {
            out.writeShort(entries.size());
            for (int i = 1; i < entries.size(); i++) {
                CpEntry e = entries.get(i);
                if (e != null) e.write(out);
            }
        }

        String getUtf8(int index) {
            return utf8Cache.get(index - 1);
        }

        int addUtf8(String value) {
            for (int i = 0; i < utf8Cache.size(); i++) {
                if (value.equals(utf8Cache.get(i))) return i + 1;
            }
            int idx = entries.size();
            entries.add(new CpUtf8(value));
            utf8Cache.add(value);
            return idx;
        }

        int addClass(String name) {
            int nameIdx = addUtf8(name);
            for (int i = 1; i < entries.size(); i++) {
                if (entries.get(i) instanceof CpClass) {
                    CpClass c = (CpClass) entries.get(i);
                    if (c.nameIndex == nameIdx) return i;
                }
            }
            int idx = entries.size();
            entries.add(new CpClass(nameIdx));
            utf8Cache.add(null);
            return idx;
        }

        int addMethodref(int classIdx, String name, String desc) {
            int ntIdx = addNameAndType(name, desc);
            for (int i = 1; i < entries.size(); i++) {
                if (entries.get(i) instanceof CpMethodref) {
                    CpMethodref m = (CpMethodref) entries.get(i);
                    if (m.classIndex == classIdx && m.nameAndTypeIndex == ntIdx) return i;
                }
            }
            int idx = entries.size();
            entries.add(new CpMethodref(classIdx, ntIdx));
            utf8Cache.add(null);
            return idx;
        }

        int addNameAndType(String name, String desc) {
            int nameIdx = addUtf8(name);
            int descIdx = addUtf8(desc);
            for (int i = 1; i < entries.size(); i++) {
                if (entries.get(i) instanceof CpNameAndType) {
                    CpNameAndType nt = (CpNameAndType) entries.get(i);
                    if (nt.nameIndex == nameIdx && nt.descriptorIndex == descIdx) return i;
                }
            }
            int idx = entries.size();
            entries.add(new CpNameAndType(nameIdx, descIdx));
            utf8Cache.add(null);
            return idx;
        }
    }

    static abstract class CpEntry {
        abstract void write(DataOutputStream out) throws IOException;
    }

    static class CpUtf8 extends CpEntry {
        String value;
        CpUtf8(String v) { value = v; }
        @Override void write(DataOutputStream out) throws IOException { out.writeByte(1); out.writeUTF(value); }
    }
    static class CpInteger extends CpEntry { int value; CpInteger(int v) { value = v; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(3); out.writeInt(value); } }
    static class CpFloat extends CpEntry { float value; CpFloat(float v) { value = v; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(4); out.writeFloat(value); } }
    static class CpLong extends CpEntry { long value; CpLong(long v) { value = v; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(5); out.writeLong(value); } }
    static class CpDouble extends CpEntry { double value; CpDouble(double v) { value = v; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(6); out.writeDouble(value); } }
    static class CpClass extends CpEntry { int nameIndex; CpClass(int n) { nameIndex = n; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(7); out.writeShort(nameIndex); } }
    static class CpString extends CpEntry { int stringIndex; CpString(int s) { stringIndex = s; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(8); out.writeShort(stringIndex); } }
    static class CpFieldref extends CpEntry { int classIndex, nameAndTypeIndex; CpFieldref(int c, int n) { classIndex = c; nameAndTypeIndex = n; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(9); out.writeShort(classIndex); out.writeShort(nameAndTypeIndex); } }
    static class CpMethodref extends CpEntry { int classIndex, nameAndTypeIndex; CpMethodref(int c, int n) { classIndex = c; nameAndTypeIndex = n; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(10); out.writeShort(classIndex); out.writeShort(nameAndTypeIndex); } }
    static class CpInterfaceMethodref extends CpEntry { int classIndex, nameAndTypeIndex; CpInterfaceMethodref(int c, int n) { classIndex = c; nameAndTypeIndex = n; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(11); out.writeShort(classIndex); out.writeShort(nameAndTypeIndex); } }
    static class CpNameAndType extends CpEntry { int nameIndex, descriptorIndex; CpNameAndType(int n, int d) { nameIndex = n; descriptorIndex = d; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(12); out.writeShort(nameIndex); out.writeShort(descriptorIndex); } }
    static class CpMethodHandle extends CpEntry { int referenceKind, referenceIndex; CpMethodHandle(int k, int r) { referenceKind = k; referenceIndex = r; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(15); out.writeByte(referenceKind); out.writeShort(referenceIndex); } }
    static class CpMethodType extends CpEntry { int descriptorIndex; CpMethodType(int d) { descriptorIndex = d; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(16); out.writeShort(descriptorIndex); } }
    static class CpInvokeDynamic extends CpEntry { int bootstrapMethodAttrIndex, nameAndTypeIndex; CpInvokeDynamic(int b, int n) { bootstrapMethodAttrIndex = b; nameAndTypeIndex = n; } @Override void write(DataOutputStream out) throws IOException { out.writeByte(18); out.writeShort(bootstrapMethodAttrIndex); out.writeShort(nameAndTypeIndex); } }

    static class FieldInfo {
        int accessFlags, nameIndex, descriptorIndex;
        AttributeInfo[] attributes;

        static FieldInfo read(DataInputStream in, ConstantPool cp) throws IOException {
            FieldInfo f = new FieldInfo();
            f.accessFlags = in.readUnsignedShort();
            f.nameIndex = in.readUnsignedShort();
            f.descriptorIndex = in.readUnsignedShort();
            int attrCount = in.readUnsignedShort();
            f.attributes = new AttributeInfo[attrCount];
            for (int i = 0; i < attrCount; i++) f.attributes[i] = AttributeInfo.read(in, cp);
            return f;
        }
        void write(DataOutputStream out) throws IOException {
            out.writeShort(accessFlags);
            out.writeShort(nameIndex);
            out.writeShort(descriptorIndex);
            out.writeShort(attributes.length);
            for (AttributeInfo a : attributes) a.write(out);
        }
    }

    static class MethodInfo {
        int accessFlags, nameIndex, descriptorIndex;
        byte[] code;
        int maxStack, maxLocals;
        AttributeInfo[] attributes;

        static MethodInfo read(DataInputStream in, ConstantPool cp) throws IOException {
            MethodInfo m = new MethodInfo();
            m.accessFlags = in.readUnsignedShort();
            m.nameIndex = in.readUnsignedShort();
            m.descriptorIndex = in.readUnsignedShort();
            int attrCount = in.readUnsignedShort();
            m.attributes = new AttributeInfo[attrCount];
            for (int i = 0; i < attrCount; i++) {
                m.attributes[i] = AttributeInfo.read(in, cp);
                if (m.attributes[i] instanceof CodeAttribute) {
                    CodeAttribute ca = (CodeAttribute) m.attributes[i];
                    m.code = ca.code;
                    m.maxStack = ca.maxStack;
                    m.maxLocals = ca.maxLocals;
                }
            }
            return m;
        }

        void write(DataOutputStream out, ConstantPool cp) throws IOException {
            out.writeShort(accessFlags);
            out.writeShort(nameIndex);
            out.writeShort(descriptorIndex);
            out.writeShort(attributes.length);
            for (AttributeInfo a : attributes) a.write(out);
        }
    }

    static abstract class AttributeInfo {
        static AttributeInfo read(DataInputStream in, ConstantPool cp) throws IOException {
            int nameIndex = in.readUnsignedShort();
            int length = in.readInt();
            String name = cp.getUtf8(nameIndex);

            if ("Code".equals(name)) {
                return CodeAttribute.read(in, cp);
            } else if ("LineNumberTable".equals(name) || "LocalVariableTable".equals(name) ||
                    "StackMapTable".equals(name) || "Exceptions".equals(name) ||
                    "Synthetic".equals(name) || "Deprecated".equals(name) ||
                    "RuntimeVisibleAnnotations".equals(name) || "RuntimeInvisibleAnnotations".equals(name) ||
                    "RuntimeVisibleParameterAnnotations".equals(name) || "RuntimeInvisibleParameterAnnotations".equals(name) ||
                    "AnnotationDefault".equals(name) || "MethodParameters".equals(name)) {
                byte[] data = new byte[length];
                in.readFully(data);
                return new GenericAttribute(nameIndex, data);
            } else {
                byte[] data = new byte[length];
                in.readFully(data);
                return new GenericAttribute(nameIndex, data);
            }
        }

        abstract void write(DataOutputStream out) throws IOException;
    }

    static class CodeAttribute extends AttributeInfo {
        int maxStack, maxLocals;
        byte[] code;
        AttributeInfo[] attributes;

        static CodeAttribute read(DataInputStream in, ConstantPool cp) throws IOException {
            CodeAttribute ca = new CodeAttribute();
            ca.maxStack = in.readUnsignedShort();
            ca.maxLocals = in.readUnsignedShort();
            int codeLen = in.readInt();
            ca.code = new byte[codeLen];
            in.readFully(ca.code);
            int exceptionCount = in.readUnsignedShort();
            for (int i = 0; i < exceptionCount; i++) {
                in.readUnsignedShort(); in.readUnsignedShort(); in.readUnsignedShort();
            }
            int attrCount = in.readUnsignedShort();
            ca.attributes = new AttributeInfo[attrCount];
            for (int i = 0; i < attrCount; i++) {
                ca.attributes[i] = AttributeInfo.read(in, cp);
            }
            return ca;
        }

        @Override
        void write(DataOutputStream out) throws IOException {
            out.writeShort(maxStack);
            out.writeShort(maxLocals);
            out.writeInt(code.length);
            out.write(code);
            out.writeShort(0); // exception table
            out.writeShort(attributes.length);
            for (AttributeInfo a : attributes) a.write(out);
        }
    }

    static class GenericAttribute extends AttributeInfo {
        int nameIndex;
        byte[] data;
        GenericAttribute(int n, byte[] d) { nameIndex = n; data = d; }
        @Override void write(DataOutputStream out) throws IOException {
            out.writeInt(data.length);
            out.write(data);
        }
    }
}