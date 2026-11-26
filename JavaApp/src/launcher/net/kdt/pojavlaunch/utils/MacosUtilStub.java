package net.kdt.pojavlaunch.utils;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Builds an iOS-safe replacement for {@code com.mojang.blaze3d.platform.MacosUtil}.
 *
 * <p>The class is version dependent: 26.3 uses Mojang-mapped names
 * ({@code disableCloseWindowMenuItem}, {@code setFullscreenMenuVisibility},
 * {@code setCtrlClickEmulatesRightClick} and an {@code IS_MACOS} flag), while
 * 1.19 - 1.21 srg jars use numeric names ({@code m_182517_(J)V},
 * {@code m_247671_(IoSupplier)V}, ...) and no flag at all. Shipping one fixed
 * shim for every version made old instances die with
 * {@code NoSuchMethodError: MacosUtil.m_247671_} (Window.<init> calls it).
 *
 * <p>The game directory is shared by every installed version, so a stub must
 * satisfy whichever version is launched next. {@link #unionStub(byte[])} keeps
 * the installed class's own API and adds the other known API on top; all method
 * bodies are neutralised because every real one talks to AppKit/weblite or SDL,
 * which cannot run on iOS. Static fields keep their names/descriptors and
 * default to 0/false, which also forces {@code IS_MACOS} to false on 26.x.
 *
 * <p>Generated code is straight-line ({@code return}/{@code iconst_0; ireturn}),
 * so no StackMapTable is needed and the result verifies on every JVM.
 */
public final class MacosUtilStub {

    private static final String CLASS_NAME = "com/mojang/blaze3d/platform/MacosUtil";
    private static final String IO_SUPPLIER = "Lnet/minecraft/server/packs/resources/IoSupplier;";
    private static final String NS_OBJECT = "Lca/weblite/objc/NSObject;";
    private static final int ACC_PUBLIC = 0x0001;
    private static final int ACC_PRIVATE = 0x0002;
    private static final int ACC_STATIC = 0x0008;
    private static final int ACC_FINAL = 0x0010;
    private static final int ACC_SUPER = 0x0020;
    private static final int ACC_INTERFACE = 0x0200;
    private static final int ACC_ABSTRACT = 0x0400;
    private static final int ACC_ANNOTATION = 0x2000;
    private static final int ACC_ENUM = 0x4000;

    private MacosUtilStub() {
    }

    private static final class Member {
        final int access;
        final String name;
        final String descriptor;

        Member(int access, String name, String descriptor) {
            this.access = access;
            this.name = name;
            this.descriptor = descriptor;
        }
    }

    private static final class Parsed {
        int major;
        int access;
        String thisName;
        String superName;
        final List<Member> fields = new ArrayList<Member>();
        final List<Member> methods = new ArrayList<Member>();
    }

    /**
     * Neutralises every method body of the given class and adds the missing
     * MacosUtil APIs other installed versions may call.
     */
    public static byte[] unionStub(byte[] classBytes) throws IOException {
        Parsed p = parse(classBytes);
        if ((p.access & (ACC_INTERFACE | ACC_ABSTRACT)) != 0) {
            throw new IOException("refusing to stub abstract/interface class");
        }
        Set<String> fieldKeys = new HashSet<String>();
        for (Member f : p.fields) fieldKeys.add(f.name + '\u0000' + f.descriptor);
        Set<String> methodKeys = new HashSet<String>();
        for (Member m : p.methods) methodKeys.add(m.name + '\u0000' + m.descriptor);

        // 26.x reads this field; it must exist and default to false.
        addField(p.fields, fieldKeys, new Member(ACC_PUBLIC | ACC_STATIC | ACC_FINAL,
                "IS_MACOS", "Z"));

        // 26.x API.
        addMethod(p.methods, methodKeys, new Member(ACC_PUBLIC | ACC_STATIC,
                "disableCloseWindowMenuItem", "()V"));
        addMethod(p.methods, methodKeys, new Member(ACC_PUBLIC | ACC_STATIC,
                "setFullscreenMenuVisibility", "(Z)V"));
        addMethod(p.methods, methodKeys, new Member(ACC_PUBLIC | ACC_STATIC,
                "setCtrlClickEmulatesRightClick", "(Z)V"));

        // 1.19 - 1.21 srg API (Window.<init> calls m_247671_ on 1.20.x).
        addMethod(p.methods, methodKeys, new Member(ACC_PUBLIC | ACC_STATIC,
                "m_182517_", "(J)V"));
        addMethod(p.methods, methodKeys, new Member(ACC_PRIVATE | ACC_STATIC,
                "m_182521_", "(J)Ljava/util/Optional;"));
        addMethod(p.methods, methodKeys, new Member(ACC_PRIVATE | ACC_STATIC,
                "m_182519_", "(" + NS_OBJECT + ")Z"));
        addMethod(p.methods, methodKeys, new Member(ACC_PRIVATE | ACC_STATIC,
                "m_182523_", "(" + NS_OBJECT + ")V"));
        addMethod(p.methods, methodKeys, new Member(ACC_PUBLIC | ACC_STATIC,
                "m_247671_", "(" + IO_SUPPLIER + ")V"));

        // Always expose a public no-arg constructor: the 26.3 shim's is private
        // and old srg classes may be instantiated by mods.
        List<Member> withoutCtors = new ArrayList<Member>();
        for (Member m : p.methods) if (!"<init>".equals(m.name)) withoutCtors.add(m);
        p.methods.clear();
        p.methods.addAll(withoutCtors);
        p.methods.add(new Member(ACC_PUBLIC, "<init>", "()V"));

        return write(p.major, p.access, p.thisName,
                p.superName == null ? "java/lang/Object" : p.superName, p.fields, p.methods);
    }

    private static void addField(List<Member> list, Set<String> keys, Member member) {
        if (keys.add(member.name + '\u0000' + member.descriptor)) list.add(member);
    }

    private static void addMethod(List<Member> list, Set<String> keys, Member member) {
        if (keys.add(member.name + '\u0000' + member.descriptor)) list.add(member);
    }

    // ------------------------------------------------------------------
    // Class file writer
    // ------------------------------------------------------------------

    private static byte[] write(int major, int access, String thisName, String superName,
                                List<Member> fields, List<Member> methods) throws IOException {
        ConstantPool cp = new ConstantPool();
        int thisIdx = cp.classEntry(thisName);
        int superIdx = cp.classEntry(superName);
        int codeName = cp.utf8("Code");
        int superInit = cp.methodRef(superName, "<init>", "()V");
        // Register every name/descriptor before the pool is serialised; adding
        // constants afterwards would write indices that do not exist.
        int[] fieldNames = new int[fields.size()];
        int[] fieldDescs = new int[fields.size()];
        for (int i = 0; i < fields.size(); i++) {
            fieldNames[i] = cp.utf8(fields.get(i).name);
            fieldDescs[i] = cp.utf8(fields.get(i).descriptor);
        }
        int[] methodNames = new int[methods.size()];
        int[] methodDescs = new int[methods.size()];
        boolean needsOptional = false;
        for (int i = 0; i < methods.size(); i++) {
            methodNames[i] = cp.utf8(methods.get(i).name);
            methodDescs[i] = cp.utf8(methods.get(i).descriptor);
            if (methods.get(i).descriptor.endsWith(")Ljava/util/Optional;")) needsOptional = true;
        }
        int optionalEmpty = needsOptional
                ? cp.methodRef("java/util/Optional", "empty", "()Ljava/util/Optional;") : -1;

        ByteArrayOutputStream bytes = new ByteArrayOutputStream(4096);
        DataOutputStream out = new DataOutputStream(bytes);
        out.writeInt(0xCAFEBABE);
        out.writeShort(0);
        out.writeShort(major < 52 ? 52 : major);
        cp.writeTo(out);
        out.writeShort((access & ~(ACC_INTERFACE | ACC_ABSTRACT | ACC_ANNOTATION | ACC_ENUM)) | ACC_SUPER);
        out.writeShort(thisIdx);
        out.writeShort(superIdx);
        out.writeShort(0); // interfaces
        out.writeShort(fields.size());
        for (int i = 0; i < fields.size(); i++) {
            Member f = fields.get(i);
            out.writeShort(f.access);
            out.writeShort(fieldNames[i]);
            out.writeShort(fieldDescs[i]);
            out.writeShort(0); // no attributes (drops ConstantValue, defaults to 0/false)
        }
        out.writeShort(methods.size());
        for (int i = 0; i < methods.size(); i++) {
            Member m = methods.get(i);
            int mAccess = m.access & ~(ACC_ABSTRACT | 0x0100 /* native */);
            out.writeShort(mAccess);
            out.writeShort(methodNames[i]);
            out.writeShort(methodDescs[i]);
            out.writeShort(1); // Code
            out.writeShort(codeName);
            byte[] code;
            int maxStack;
            int maxLocals;
            if ("<init>".equals(m.name)) {
                code = new byte[] {0x2a, (byte) 0xb7, (byte) (superInit >> 8), (byte) superInit, (byte) 0xb1};
                maxStack = 1;
                maxLocals = 1 + argumentSlots(m.descriptor);
            } else if (optionalEmpty != -1 && m.descriptor.endsWith(")Ljava/util/Optional;")) {
                // Optional.empty(): never null, so reflective/mod callers cannot NPE.
                code = new byte[] {(byte) 0xb8, (byte) (optionalEmpty >> 8), (byte) optionalEmpty, (byte) 0xb0};
                maxStack = 1;
                maxLocals = argumentSlots(m.descriptor) + ((m.access & ACC_STATIC) != 0 ? 0 : 1);
            } else {
                code = defaultReturn(m.descriptor);
                maxStack = returnStack(m.descriptor);
                maxLocals = argumentSlots(m.descriptor) + ((m.access & ACC_STATIC) != 0 ? 0 : 1);
            }
            out.writeInt(2 + 2 + 4 + code.length + 2 + 2);
            out.writeShort(maxStack);
            out.writeShort(maxLocals);
            out.writeInt(code.length);
            out.write(code);
            out.writeShort(0); // exception table
            out.writeShort(0); // code attributes
        }
        out.writeShort(0); // class attributes
        out.flush();
        return bytes.toByteArray();
    }

    private static byte[] defaultReturn(String descriptor) {
        char r = descriptor.charAt(descriptor.indexOf(')') + 1);
        switch (r) {
            case 'V':
                return new byte[] {(byte) 0xb1};                  // return
            case 'Z': case 'B': case 'C': case 'S': case 'I':
                return new byte[] {0x03, (byte) 0xac};            // iconst_0; ireturn
            case 'J':
                return new byte[] {0x09, (byte) 0xad};            // lconst_0; lreturn
            case 'F':
                return new byte[] {0x0b, (byte) 0xae};            // fconst_0; freturn
            case 'D':
                return new byte[] {0x0e, (byte) 0xaf};            // dconst_0; dreturn
            default:
                return new byte[] {0x01, (byte) 0xb0};            // aconst_null; areturn
        }
    }

    private static int returnStack(String descriptor) {
        char r = descriptor.charAt(descriptor.indexOf(')') + 1);
        if (r == 'V') return 0;
        if (r == 'J' || r == 'D') return 2;
        return 1;
    }

    private static int argumentSlots(String descriptor) {
        int i = 1;
        int slots = 0;
        while (i < descriptor.length() && descriptor.charAt(i) != ')') {
            char c = descriptor.charAt(i);
            if (c == 'J' || c == 'D') {
                slots += 2;
                i++;
            } else if (c == 'L') {
                slots++;
                i = descriptor.indexOf(';', i) + 1;
            } else if (c == '[') {
                slots++;
                while (descriptor.charAt(i) == '[') i++;
                if (descriptor.charAt(i) == 'L') i = descriptor.indexOf(';', i);
                i++;
            } else {
                slots++;
                i++;
            }
        }
        return slots;
    }

    private static final class ConstantPool {
        private final List<byte[]> entries = new ArrayList<byte[]>();
        private final Map<String, Integer> utf8 = new LinkedHashMap<String, Integer>();
        private final Map<String, Integer> classes = new LinkedHashMap<String, Integer>();
        private final Map<String, Integer> nameAndTypes = new LinkedHashMap<String, Integer>();
        private final Map<String, Integer> methodRefs = new LinkedHashMap<String, Integer>();

        int utf8(String value) {
            Integer existing = utf8.get(value);
            if (existing != null) return existing;
            byte[] data = value.getBytes(StandardCharsets.UTF_8);
            ByteArrayOutputStream b = new ByteArrayOutputStream(data.length + 3);
            b.write(1);
            b.write((data.length >> 8) & 0xff);
            b.write(data.length & 0xff);
            b.write(data, 0, data.length);
            entries.add(b.toByteArray());
            int index = entries.size();
            utf8.put(value, index);
            return index;
        }

        int classEntry(String name) {
            Integer existing = classes.get(name);
            if (existing != null) return existing;
            int nameIdx = utf8(name);
            entries.add(new byte[] {7, (byte) (nameIdx >> 8), (byte) nameIdx});
            int index = entries.size();
            classes.put(name, index);
            return index;
        }

        int nameAndType(String name, String descriptor) {
            String key = name + '\u0000' + descriptor;
            Integer existing = nameAndTypes.get(key);
            if (existing != null) return existing;
            int nameIdx = utf8(name);
            int descIdx = utf8(descriptor);
            entries.add(new byte[] {12, (byte) (nameIdx >> 8), (byte) nameIdx,
                    (byte) (descIdx >> 8), (byte) descIdx});
            int index = entries.size();
            nameAndTypes.put(key, index);
            return index;
        }

        int methodRef(String owner, String name, String descriptor) {
            String key = owner + '\u0000' + name + '\u0000' + descriptor;
            Integer existing = methodRefs.get(key);
            if (existing != null) return existing;
            int ownerIdx = classEntry(owner);
            int natIdx = nameAndType(name, descriptor);
            entries.add(new byte[] {10, (byte) (ownerIdx >> 8), (byte) ownerIdx,
                    (byte) (natIdx >> 8), (byte) natIdx});
            int index = entries.size();
            methodRefs.put(key, index);
            return index;
        }

        void writeTo(DataOutputStream out) throws IOException {
            out.writeShort(entries.size() + 1);
            for (byte[] entry : entries) out.write(entry);
        }
    }

    // ------------------------------------------------------------------
    // Class file reader (constant pool, fields, methods only)
    // ------------------------------------------------------------------

    private static Parsed parse(byte[] b) throws IOException {
        Reader in = new Reader(b);
        if (in.u4() != 0xCAFEBABEL) throw new IOException("not a class file");
        in.u2(); // minor
        Parsed p = new Parsed();
        p.major = in.u2();
        int cpCount = in.u2();
        String[] strings = new String[cpCount];
        int[] classNames = new int[cpCount];
        for (int i = 1; i < cpCount; i++) {
            int tag = in.u1();
            switch (tag) {
                case 1: {
                    int len = in.u2();
                    strings[i] = new String(b, in.pos, len, StandardCharsets.UTF_8);
                    in.pos += len;
                    break;
                }
                case 3: case 4: in.skip(4); break;
                case 5: case 6: in.skip(8); i++; break;
                case 7: classNames[i] = in.u2(); break;
                case 8: case 16: case 19: case 20: in.skip(2); break;
                case 9: case 10: case 11: case 12: case 17: case 18: in.skip(4); break;
                case 15: in.skip(3); break;
                default: throw new IOException("unknown constant pool tag " + tag);
            }
        }
        p.access = in.u2();
        int thisIdx = in.u2();
        int superIdx = in.u2();
        p.thisName = strings[classNames[thisIdx]];
        p.superName = superIdx == 0 ? null : strings[classNames[superIdx]];
        int interfaces = in.u2();
        in.skip(interfaces * 2);
        int fieldCount = in.u2();
        for (int i = 0; i < fieldCount; i++) {
            p.fields.add(readMember(in, strings));
        }
        int methodCount = in.u2();
        for (int i = 0; i < methodCount; i++) {
            p.methods.add(readMember(in, strings));
        }
        return p;
    }

    private static Member readMember(Reader in, String[] strings) throws IOException {
        int access = in.u2();
        String name = strings[in.u2()];
        String descriptor = strings[in.u2()];
        int attributes = in.u2();
        for (int i = 0; i < attributes; i++) {
            in.u2();
            in.skip((int) in.u4());
        }
        return new Member(access, name, descriptor);
    }

    private static final class Reader {
        final byte[] data;
        int pos;

        Reader(byte[] data) {
            this.data = data;
        }

        int u1() throws IOException {
            if (pos + 1 > data.length) throw new IOException("truncated class file");
            return data[pos++] & 0xff;
        }

        int u2() throws IOException {
            return (u1() << 8) | u1();
        }

        long u4() throws IOException {
            return ((long) u2() << 16) | u2();
        }

        void skip(int n) throws IOException {
            if (n < 0 || pos + n > data.length) throw new IOException("truncated class file");
            pos += n;
        }
    }
}
