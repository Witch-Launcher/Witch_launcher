package net.witch.f3;

import java.io.ByteArrayOutputStream;
import java.nio.charset.Charset;

/**
 * Raw class-file surgery for the F3 debug overlay.
 *
 * Finds the system-information method of Minecraft's DebugScreenOverlay: the
 * method with descriptor {@code ()Ljava/util/List;} that references the format
 * string "Java: %s" (obfuscation-proof, string constants are never renamed).
 * For every areturn of that method the following two instructions are injected:
 *
 * <pre>dup
 * invokestatic net/witch/f3/WitchF3Append.appendInfo(Ljava/util/List;)V</pre>
 *
 * The constant pool is extended by six entries, branch offsets, switch tables,
 * exception table ranges and existing StackMapTable offset deltas are all
 * recomputed (the insertion is stack neutral, so the declared frames stay
 * valid; only their bytecode offsets shift). Local variable tables, local
 * variable type tables and line number tables are remapped as well, because
 * the HotSpot verifier rejects a local variable range that starts or ends in
 * the middle of an instruction. The class version is untouched. Any
 * unexpected structure aborts the patch and returns null, leaving the class
 * exactly as it was.
 */
public final class ClassPatcher {

    private ClassPatcher() {
    }

    private static final String JAVA_MARKER = "Java: %s";
    private static final Charset UTF8 = Charset.forName("UTF-8");
    private static final int MAX_CODE_LENGTH = 65535;

    public static byte[] patchDebugOverlay(byte[] bytes) {
        try {
            ClassFile patched = patch(bytes);
            if (patched == null) {
                return null;
            }
            byte[] result = patched.toBytes();
            if (!validate(result, patched)) {
                System.out.println("[WitchF3] self-check failed, keeping vanilla class");
                return null;
            }
            return result;
        } catch (Throwable t) {
            System.out.println("[WitchF3] patch aborted: " + t);
            return null;
        }
    }

    private static ClassFile patch(byte[] b) throws Exception {
        Reader r = new Reader(b);
        if (b.length < 10 || r.u4() != 0xCAFEBABEL) {
            return null;
        }
        int minor = r.u2();
        int major = r.u2();
        ConstantPool cp = ConstantPool.read(r);
        int cpEnd = r.pos;

        r.skip(6); // access_flags, this_class, super_class
        r.skip(r.u2() * 2); // interfaces

        int fieldsStart = r.pos;
        int fieldCount = r.u2();
        for (int i = 0; i < fieldCount; i++) {
            r.skip(6);
            skipAttributes(r);
        }
        int methodsStart = r.pos;

        int methodCount = r.u2();
        Method[] methods = new Method[methodCount];
        for (int i = 0; i < methodCount; i++) {
            Method m = new Method();
            m.access = r.u2();
            m.nameIndex = r.u2();
            m.descIndex = r.u2();
            int attrCount = r.u2();
            m.attrs = new Attr[attrCount];
            for (int a = 0; a < attrCount; a++) {
                Attr attr = new Attr();
                attr.nameIndex = r.u2();
                attr.data = r.bytes(r.u4AsInt());
                m.attrs[a] = attr;
            }
            methods[i] = m;
        }
        int classAttrsStart = r.pos;

        int targetIndex = -1;
        int targetCodeAttr = -1;
        CodeAttr targetCode = null;
        for (int i = 0; i < methodCount && targetIndex < 0; i++) {
            Method m = methods[i];
            if (m.descIndex <= 0 || m.descIndex >= cp.count) {
                continue;
            }
            if (!"()Ljava/util/List;".equals(cp.utf8[m.descIndex])) {
                continue;
            }
            for (int a = 0; a < m.attrs.length; a++) {
                Attr attr = m.attrs[a];
                if (attr.nameIndex <= 0 || attr.nameIndex >= cp.count) {
                    continue;
                }
                if (!"Code".equals(cp.utf8[attr.nameIndex])) {
                    continue;
                }
                CodeAttr code = CodeAttr.parse(attr.data);
                if (code != null && code.referencesString(cp, JAVA_MARKER)) {
                    targetIndex = i;
                    targetCodeAttr = a;
                    targetCode = code;
                }
            }
        }
        if (targetIndex < 0 || targetCode == null) {
            return null;
        }

        int methodRefIndex = cp.count + 5;
        byte[] newCodeData = buildCode(targetCode, cp, methodRefIndex);
        if (newCodeData == null) {
            return null;
        }
        methods[targetIndex].attrs[targetCodeAttr].data = newCodeData;

        ClassFile cf = new ClassFile();
        cf.minor = minor;
        cf.major = major;
        cf.cpCount = cp.count + 6;
        cf.cpCountValue = cp.count;
        cf.cpBytes = slice(b, 10, cpEnd);
        cf.headerBytes = slice(b, cpEnd, fieldsStart);
        cf.fieldsBytes = slice(b, fieldsStart, methodsStart);
        cf.methods = methods;
        cf.classAttrsBytes = slice(b, classAttrsStart, b.length);
        cf.targetMethodIndex = targetIndex;
        cf.targetMethodRef = methodRefIndex;
        cf.newCpCount = cp.count + 6;
        return cf;
    }

    /* ---------------------------------------------------------------- */
    /* Code attribute patch                                              */
    /* ---------------------------------------------------------------- */

    private static byte[] buildCode(CodeAttr code, ConstantPool cp, int methodRefIndex) throws Exception {
        int[] positions = Walk.positions(code.code);
        int areturnCount = 0;
        for (int pos : positions) {
            if (code.code[pos] == (byte) 0xB0) {
                areturnCount++;
            }
        }
        if (areturnCount == 0) {
            return null;
        }
        int[] areturns = new int[areturnCount];
        int n = 0;
        for (int pos : positions) {
            if (code.code[pos] == (byte) 0xB0) {
                areturns[n++] = pos;
            }
        }

        // Refuse to patch code we do not fully understand.
        Walk.verify(code.code);

        ByteArrayOutputStream cw = new ByteArrayOutputStream(code.code.length + areturnCount * 4 + 16);
        for (int pos : positions) {
            int op = code.code[pos] & 0xFF;
            int len = Walk.length(code.code, pos);

            if (op == 0xB0) { // areturn
                cw.write(0x59); // dup
                cw.write(0xB8); // invokestatic
                cw.write((methodRefIndex >> 8) & 0xFF);
                cw.write(methodRefIndex & 0xFF);
            }
            int newStart = cw.size();

            if (op >= 0x99 && op <= 0xA8 || op == 0xC6 || op == 0xC7) { // s2-relative branches
                int oldTarget = pos + readS2(code.code, pos + 1);
                if (oldTarget < 0 || oldTarget >= code.code.length) {
                    return null;
                }
                int offset = newPos(oldTarget, areturns) - newStart;
                if (offset < Short.MIN_VALUE || offset > Short.MAX_VALUE) {
                    return null;
                }
                cw.write(op);
                cw.write((offset >> 8) & 0xFF);
                cw.write(offset & 0xFF);
            } else if (op == 0xC8 || op == 0xC9) { // goto_w, jsr_w
                int oldTarget = pos + readS4(code.code, pos + 1);
                if (oldTarget < 0 || oldTarget >= code.code.length) {
                    return null;
                }
                cw.write(op);
                writeS4(cw, newPos(oldTarget, areturns) - newStart);
            } else if (op == 0xAA) { // tableswitch
                int pad = (4 - ((pos + 1) % 4)) % 4;
                int base = pos + 1 + pad;
                int def = readS4(code.code, base);
                int low = readS4(code.code, base + 4);
                int high = readS4(code.code, base + 8);
                if (high < low || (long) (high - low) + 1 > code.code.length) {
                    return null;
                }
                int newPad = (4 - ((newStart + 1) % 4)) % 4;
                cw.write(op);
                for (int z = 0; z < newPad; z++) {
                    cw.write(0);
                }
                writeS4(cw, newPos(pos + def, areturns) - newStart);
                writeS4(cw, low);
                writeS4(cw, high);
                int entries = base + 12;
                for (int k = 0; k <= high - low; k++) {
                    int oldTarget = pos + readS4(code.code, entries + k * 4);
                    writeS4(cw, newPos(oldTarget, areturns) - newStart);
                }
            } else if (op == 0xAB) { // lookupswitch
                int pad = (4 - ((pos + 1) % 4)) % 4;
                int base = pos + 1 + pad;
                int def = readS4(code.code, base);
                int npairs = readS4(code.code, base + 4);
                if (npairs < 0 || (long) npairs > code.code.length) {
                    return null;
                }
                int newPad = (4 - ((newStart + 1) % 4)) % 4;
                cw.write(op);
                for (int z = 0; z < newPad; z++) {
                    cw.write(0);
                }
                writeS4(cw, newPos(pos + def, areturns) - newStart);
                writeS4(cw, npairs);
                int entries = base + 8;
                for (int k = 0; k < npairs; k++) {
                    cw.write(code.code, entries + k * 8, 4); // match (verbatim)
                    int oldTarget = pos + readS4(code.code, entries + k * 8 + 4);
                    writeS4(cw, newPos(oldTarget, areturns) - newStart);
                }
            } else {
                cw.write(code.code, pos, len);
            }
        }
        byte[] newCode = cw.toByteArray();
        if (newCode.length > MAX_CODE_LENGTH || code.maxStack + 1 > 65535) {
            return null;
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream(newCode.length + 64);
        writeU2(out, code.maxStack + 1);
        writeU2(out, code.maxLocals);
        writeU4(out, newCode.length);
        out.write(newCode);
        writeU2(out, code.excStart.length);
        for (int i = 0; i < code.excStart.length; i++) {
            int start = newPos(code.excStart[i], areturns);
            int end = newPos(code.excEnd[i], areturns);
            int handler = newPos(code.excHandler[i], areturns);
            if (start < 0 || start > end || end > newCode.length || handler > newCode.length) {
                return null;
            }
            writeU2(out, start);
            writeU2(out, end);
            writeU2(out, handler);
            writeU2(out, code.excType[i]);
        }

        writeU2(out, code.attrs.length);
        for (Attr attr : code.attrs) {
            String name = (attr.nameIndex > 0 && attr.nameIndex < cp.count) ? cp.utf8[attr.nameIndex] : null;
            byte[] remapped;
            if ("StackMapTable".equals(name)) {
                remapped = remapStackMap(attr.data, areturns, newCode.length);
            } else if ("LocalVariableTable".equals(name) || "LocalVariableTypeTable".equals(name)) {
                remapped = remapLocalVariables(attr.data, areturns, code.code.length);
            } else if ("LineNumberTable".equals(name)) {
                remapped = remapLineNumbers(attr.data, areturns, code.code.length);
            } else {
                return null;
            }
            if (remapped == null) {
                return null;
            }
            writeU2(out, attr.nameIndex);
            writeU4(out, remapped.length);
            out.write(remapped);
        }
        return out.toByteArray();
    }

    private static int newPos(int oldPos, int[] areturns) {
        int lo = 0;
        int hi = areturns.length;
        while (lo < hi) {
            int mid = (lo + hi) >>> 1;
            if (areturns[mid] < oldPos) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return oldPos + 4 * lo;
    }

    private static byte[] remapLocalVariables(byte[] data, int[] areturns, int oldCodeLength) {
        try {
            Reader r = new Reader(data);
            int count = r.u2();
            ByteArrayOutputStream out = new ByteArrayOutputStream(data.length);
            writeU2(out, count);
            for (int i = 0; i < count; i++) {
                int start = r.u2();
                int length = r.u2();
                int end = start + length;
                if (start >= oldCodeLength || end > oldCodeLength) {
                    return null;
                }
                int newStart = newPos(start, areturns);
                int newEnd = newPos(end, areturns);
                int newLength = newEnd - newStart;
                if (newStart > 65535 || newLength < 0 || newLength > 65535) {
                    return null;
                }
                writeU2(out, newStart);
                writeU2(out, newLength);
                out.write(data, r.pos, 6);
                r.skip(6);
            }
            if (r.pos != data.length) {
                return null;
            }
            return out.toByteArray();
        } catch (Throwable t) {
            return null;
        }
    }

    private static byte[] remapLineNumbers(byte[] data, int[] areturns, int oldCodeLength) {
        try {
            Reader r = new Reader(data);
            int count = r.u2();
            ByteArrayOutputStream out = new ByteArrayOutputStream(data.length);
            writeU2(out, count);
            for (int i = 0; i < count; i++) {
                int start = r.u2();
                if (start >= oldCodeLength) {
                    return null;
                }
                writeU2(out, newPos(start, areturns));
                out.write(data, r.pos, 2);
                r.skip(2);
            }
            if (r.pos != data.length) {
                return null;
            }
            return out.toByteArray();
        } catch (Throwable t) {
            return null;
        }
    }

    /* ---------------------------------------------------------------- */
    /* StackMapTable remap                                               */
    /* ---------------------------------------------------------------- */

    private static final int FRAME_SAME_MAX = 63;
    private static final int FRAME_SAME_LOCALS_1_MAX = 127;
    private static final int FRAME_SAME_LOCALS_1_EXTENDED = 247;
    private static final int FRAME_SAME_EXTENDED = 251;
    private static final int FRAME_FULL = 255;

    private static byte[] remapStackMap(byte[] data, int[] areturns, int newCodeLength) throws Exception {
        Reader r = new Reader(data);
        int count = r.u2();
        int[] kinds = new int[count];
        int[] absOffsets = new int[count];
        byte[][] payloads = new byte[count][];
        int prevAbs = -1;
        for (int i = 0; i < count; i++) {
            int type = r.u1();
            int delta;
            byte[] payload = new byte[0];
            if (type <= FRAME_SAME_MAX) {
                delta = type;
            } else if (type <= FRAME_SAME_LOCALS_1_MAX) {
                delta = type - 64;
                payload = readVtis(r, 1);
            } else if (type == FRAME_SAME_LOCALS_1_EXTENDED) {
                delta = r.u2();
                payload = readVtis(r, 1);
            } else if (type >= 248 && type <= FRAME_SAME_EXTENDED) {
                delta = r.u2();
            } else if (type >= 252 && type <= 254) {
                delta = r.u2();
                payload = readVtis(r, type - FRAME_SAME_EXTENDED);
            } else if (type == FRAME_FULL) {
                delta = r.u2();
                int locals = r.u2();
                byte[] localsBytes = readVtis(r, locals);
                int stack = r.u2();
                byte[] stackBytes = readVtis(r, stack);
                payload = concat(localsBytes, stackBytes, locals, stack);
            } else {
                throw new IllegalStateException("bad frame type " + type);
            }
            int abs = (i == 0) ? delta : prevAbs + delta + 1;
            if (abs < 0) {
                throw new IllegalStateException("bad frame offset");
            }
            prevAbs = abs;
            kinds[i] = type;
            absOffsets[i] = abs;
            payloads[i] = payload;
        }
        if (r.pos != data.length) {
            throw new IllegalStateException("StackMapTable trailing bytes");
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream(data.length + 16);
        writeU2(out, count);
        int prevNewAbs = -1;
        for (int i = 0; i < count; i++) {
            int newAbs = newPos(absOffsets[i], areturns);
            if (newAbs < 0 || newAbs >= newCodeLength) {
                return null;
            }
            int newDelta = (i == 0) ? newAbs : newAbs - prevNewAbs - 1;
            if (newDelta < 0 || newDelta > 65535) {
                return null;
            }
            prevNewAbs = newAbs;
            int type = kinds[i];
            byte[] payload = payloads[i];
            if (type <= FRAME_SAME_MAX) {
                if (newDelta <= FRAME_SAME_MAX) {
                    out.write(newDelta);
                } else {
                    out.write(FRAME_SAME_EXTENDED);
                    writeU2(out, newDelta);
                }
            } else if (type <= FRAME_SAME_LOCALS_1_MAX) {
                if (newDelta <= FRAME_SAME_MAX) {
                    out.write(64 + newDelta);
                } else {
                    out.write(FRAME_SAME_LOCALS_1_EXTENDED);
                    writeU2(out, newDelta);
                }
                out.write(payload);
            } else if (type == FRAME_SAME_LOCALS_1_EXTENDED) {
                out.write(type);
                writeU2(out, newDelta);
                out.write(payload);
            } else if (type >= 248 && type <= FRAME_SAME_EXTENDED) {
                out.write(type);
                writeU2(out, newDelta);
            } else if (type >= 252 && type <= 254) {
                out.write(type);
                writeU2(out, newDelta);
                out.write(payload);
            } else { // full frame
                out.write(type);
                writeU2(out, newDelta);
                out.write(payload);
            }
        }
        return out.toByteArray();
    }

    private static byte[] readVtis(Reader r, int count) {
        ByteArrayOutputStream out = new ByteArrayOutputStream(count * 3);
        for (int i = 0; i < count; i++) {
            int tag = r.u1();
            out.write(tag);
            if (tag == 7 || tag == 8) { // Object, Uninitialized
                out.write(r.u1());
                out.write(r.u1());
            }
        }
        return out.toByteArray();
    }

    private static byte[] concat(byte[] locals, byte[] stack, int localCount, int stackCount) {
        ByteArrayOutputStream out = new ByteArrayOutputStream(4 + locals.length + stack.length);
        writeU2(out, localCount);
        out.write(locals, 0, locals.length);
        writeU2(out, stackCount);
        out.write(stack, 0, stack.length);
        return out.toByteArray();
    }

    /* ---------------------------------------------------------------- */
    /* Validation                                                        */
    /* ---------------------------------------------------------------- */

    private static boolean validate(byte[] b, ClassFile expected) {
        try {
            Reader r = new Reader(b);
            if (r.u4() != 0xCAFEBABEL) {
                return false;
            }
            if (r.u2() != expected.minor || r.u2() != expected.major) {
                System.out.println("[WitchF3] validate: version mismatch");
                return false;
            }
            ConstantPool cp = ConstantPool.read(r);
            if (cp.count != expected.newCpCount || cp.indexOfUtf8("net/witch/f3/WitchF3Append") <= 0
                    || cp.indexOfUtf8("appendInfo") <= 0
                    || cp.indexOfUtf8("(Ljava/util/List;)V") <= 0) {
                System.out.println("[WitchF3] validate: constant pool mismatch " + cp.count + " vs " + expected.newCpCount);
                return false;
            }
            r.skip(6);
            r.skip(r.u2() * 2);
            int fieldCount = r.u2();
            for (int i = 0; i < fieldCount; i++) {
                r.skip(6);
                skipAttributes(r);
            }
            int methodCount = r.u2();
            boolean sawCall = false;
            for (int i = 0; i < methodCount; i++) {
                r.skip(6);
                int attrCount = r.u2();
                for (int a = 0; a < attrCount; a++) {
                    int nameIndex = r.u2();
                    int len = r.u4AsInt();
                    String name = (nameIndex > 0 && nameIndex < cp.count) ? cp.utf8[nameIndex] : null;
                    if ("Code".equals(name)) {
                        CodeAttr code = CodeAttr.parse(r.bytes(len));
                        if (code == null) {
                            return false;
                        }
                        try {
                            Walk.verify(code.code);
                        } catch (Throwable t) {
                            System.out.println("[WitchF3] validate: method " + i + " walk: " + t);
                            return false;
                        }
                        if (i == expected.targetMethodIndex) {
                            sawCall |= containsCall(code.code, expected.targetMethodRef);
                            if (!checkExceptionTable(code)) {
                                System.out.println("[WitchF3] validate: method " + i + " exception table bad");
                                return false;
                            }
                            for (Attr attr : code.attrs) {
                                String attrName = (attr.nameIndex > 0 && attr.nameIndex < cp.count)
                                        ? cp.utf8[attr.nameIndex] : null;
                                if ("StackMapTable".equals(attrName)) {
                                    if (!checkStackMap(attr.data, code.code)) {
                                        System.out.println("[WitchF3] validate: method " + i + " stack map bad");
                                        return false;
                                    }
                                } else if ("LocalVariableTable".equals(attrName)
                                        || "LocalVariableTypeTable".equals(attrName)) {
                                    if (!checkLocalVariables(attr.data, code.code)) {
                                        System.out.println("[WitchF3] validate: method " + i + " local variables bad");
                                        return false;
                                    }
                                } else if ("LineNumberTable".equals(attrName)) {
                                    if (!checkLineNumbers(attr.data, code.code)) {
                                        System.out.println("[WitchF3] validate: method " + i + " line numbers bad");
                                        return false;
                                    }
                                } else {
                                    System.out.println("[WitchF3] validate: method " + i + " unexpected code attribute " + attrName);
                                    return false;
                                }
                            }
                        }
                    } else {
                        r.skip(len);
                    }
                }
            }
            if (!sawCall) {
                System.out.println("[WitchF3] validate: injected call not found (ref " + expected.targetMethodRef + ")");
            }
            return sawCall;
        } catch (Throwable t) {
            System.out.println("[WitchF3] validate error: " + t);
            return false;
        }
    }

    private static boolean checkStackMap(byte[] data, byte[] code) {
        try {
            int[] positions = Walk.positions(code);
            boolean[] starts = new boolean[code.length];
            for (int pos : positions) {
                starts[pos] = true;
            }
            Reader r = new Reader(data);
            int count = r.u2();
            int prevAbs = -1;
            for (int i = 0; i < count; i++) {
                int type = r.u1();
                int delta;
                if (type <= FRAME_SAME_MAX) {
                    delta = type;
                } else if (type <= FRAME_SAME_LOCALS_1_MAX) {
                    delta = type - 64;
                    skipVtis(r, 1);
                } else if (type == FRAME_SAME_LOCALS_1_EXTENDED) {
                    delta = r.u2();
                    skipVtis(r, 1);
                } else if (type >= 248 && type <= FRAME_SAME_EXTENDED) {
                    delta = r.u2();
                } else if (type >= 252 && type <= 254) {
                    delta = r.u2();
                    skipVtis(r, type - FRAME_SAME_EXTENDED);
                } else if (type == FRAME_FULL) {
                    delta = r.u2();
                    skipVtis(r, r.u2());
                    skipVtis(r, r.u2());
                } else {
                    return false;
                }
                int abs = (i == 0) ? delta : prevAbs + delta + 1;
                if (abs < 0 || abs >= code.length || !starts[abs]) {
                    return false;
                }
                prevAbs = abs;
            }
            return r.pos == data.length;
        } catch (Throwable t) {
            return false;
        }
    }

    private static boolean checkExceptionTable(CodeAttr code) {
        try {
            int[] positions = Walk.positions(code.code);
            boolean[] starts = new boolean[code.code.length];
            for (int pos : positions) {
                starts[pos] = true;
            }
            for (int i = 0; i < code.excStart.length; i++) {
                int start = code.excStart[i];
                int end = code.excEnd[i];
                int handler = code.excHandler[i];
                if (start < 0 || start >= code.code.length || !starts[start]) {
                    return false;
                }
                if (end < 0 || end > code.code.length || (end != code.code.length && !starts[end])) {
                    return false;
                }
                if (handler < 0 || handler >= code.code.length || !starts[handler]) {
                    return false;
                }
                if (start >= end) {
                    return false;
                }
            }
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    private static boolean checkLocalVariables(byte[] data, byte[] code) {
        try {
            int[] positions = Walk.positions(code);
            boolean[] starts = new boolean[code.length];
            for (int pos : positions) {
                starts[pos] = true;
            }
            Reader r = new Reader(data);
            int count = r.u2();
            for (int i = 0; i < count; i++) {
                int start = r.u2();
                int length = r.u2();
                r.skip(6);
                if (start < 0 || start >= code.length || !starts[start]) {
                    return false;
                }
                if (length != 0) {
                    int end = start + length;
                    if (end < 0 || end > code.length) {
                        return false;
                    }
                    if (end != code.length && !starts[end]) {
                        return false;
                    }
                }
            }
            return r.pos == data.length;
        } catch (Throwable t) {
            return false;
        }
    }

    private static boolean checkLineNumbers(byte[] data, byte[] code) {
        try {
            Reader r = new Reader(data);
            int count = r.u2();
            for (int i = 0; i < count; i++) {
                int start = r.u2();
                r.skip(2);
                if (start < 0 || start >= code.length) {
                    return false;
                }
            }
            return r.pos == data.length;
        } catch (Throwable t) {
            return false;
        }
    }

    private static void skipVtis(Reader r, int count) {
        for (int i = 0; i < count; i++) {
            int tag = r.u1();
            if (tag == 7 || tag == 8) {
                r.skip(2);
            }
        }
    }

    private static boolean containsCall(byte[] code, int methodRefIndex) {
        try {
            int[] positions = Walk.positions(code);
            for (int pos : positions) {
                if ((code[pos] & 0xFF) == 0xB8) {
                    int index = ((code[pos + 1] & 0xFF) << 8) | (code[pos + 2] & 0xFF);
                    if (index == methodRefIndex) {
                        return true;
                    }
                }
            }
        } catch (Throwable t) {
            return false;
        }
        return false;
    }

    /* ---------------------------------------------------------------- */
    /* Instruction walker                                                */
    /* ---------------------------------------------------------------- */

    private static final class Walk {

        static int[] positions(byte[] code) throws Exception {
            int[] tmp = new int[code.length];
            int count = 0;
            int p = 0;
            while (p < code.length) {
                tmp[count++] = p;
                p += length(code, p);
            }
            if (p != code.length) {
                throw new IllegalStateException("instruction stream overrun");
            }
            int[] result = new int[count];
            System.arraycopy(tmp, 0, result, 0, count);
            return result;
        }

        static void verify(byte[] code) throws Exception {
            int[] positions = positions(code);
            boolean[] starts = new boolean[code.length];
            for (int pos : positions) {
                starts[pos] = true;
            }
            for (int pos : positions) {
                int op = code[pos] & 0xFF;
                if (op >= 0x99 && op <= 0xA8 || op == 0xC6 || op == 0xC7) {
                    checkTarget(code, starts, pos + readS2(code, pos + 1));
                } else if (op == 0xC8 || op == 0xC9) {
                    checkTarget(code, starts, pos + readS4(code, pos + 1));
                } else if (op == 0xAA) {
                    int pad = (4 - ((pos + 1) % 4)) % 4;
                    int base = pos + 1 + pad;
                    int def = readS4(code, base);
                    int low = readS4(code, base + 4);
                    int high = readS4(code, base + 8);
                    if (high < low || (long) (high - low) + 1 > code.length) {
                        throw new IllegalStateException("bad tableswitch");
                    }
                    checkTarget(code, starts, pos + def);
                    int entries = base + 12;
                    for (int k = 0; k <= high - low; k++) {
                        checkTarget(code, starts, pos + readS4(code, entries + k * 4));
                    }
                } else if (op == 0xAB) {
                    int pad = (4 - ((pos + 1) % 4)) % 4;
                    int base = pos + 1 + pad;
                    int def = readS4(code, base);
                    int npairs = readS4(code, base + 4);
                    if (npairs < 0 || (long) npairs > code.length) {
                        throw new IllegalStateException("bad lookupswitch");
                    }
                    checkTarget(code, starts, pos + def);
                    int entries = base + 8;
                    for (int k = 0; k < npairs; k++) {
                        checkTarget(code, starts, pos + readS4(code, entries + k * 8 + 4));
                    }
                }
            }
        }

        private static void checkTarget(byte[] code, boolean[] starts, int target) {
            if (target < 0 || target >= code.length || !starts[target]) {
                throw new IllegalStateException("bad branch target " + target);
            }
        }

        static int length(byte[] code, int p) throws Exception {
            int op = code[p] & 0xFF;
            if (op >= 0x99 && op <= 0xA8 || op == 0xC6 || op == 0xC7) {
                need(code, p, 3);
                return 3;
            }
            if (op == 0xC8 || op == 0xC9) {
                need(code, p, 5);
                return 5;
            }
            if (op == 0xAA) {
                int pad = (4 - ((p + 1) % 4)) % 4;
                need(code, p, 1 + pad + 12);
                int low = readS4(code, p + 1 + pad + 4);
                int high = readS4(code, p + 1 + pad + 8);
                if (high < low || (long) (high - low) + 1 > code.length) {
                    throw new IllegalStateException("bad tableswitch size");
                }
                int len = 1 + pad + 12 + 4 * (high - low + 1);
                need(code, p, len);
                return len;
            }
            if (op == 0xAB) {
                int pad = (4 - ((p + 1) % 4)) % 4;
                need(code, p, 1 + pad + 8);
                int npairs = readS4(code, p + 1 + pad + 4);
                if (npairs < 0 || (long) npairs > code.length) {
                    throw new IllegalStateException("bad lookupswitch size");
                }
                int len = 1 + pad + 8 + 8 * npairs;
                need(code, p, len);
                return len;
            }
            if (op == 0xC4) { // wide
                need(code, p, 2);
                int sub = code[p + 1] & 0xFF;
                if (sub == 0x84) { // wide iinc
                    need(code, p, 6);
                    return 6;
                }
                need(code, p, 4);
                return 4;
            }
            if (op == 0x10 || op == 0x12 || op == 0xA9
                    || (op >= 0x15 && op <= 0x19) || (op >= 0x36 && op <= 0x3A) || op == 0xBC) {
                need(code, p, 2);
                return 2;
            }
            if (op == 0x11 || op == 0x13 || op == 0x14 || op == 0x84
                    || (op >= 0xB2 && op <= 0xB8) || op == 0xBB || op == 0xBD
                    || op == 0xC0 || op == 0xC1) {
                need(code, p, 3);
                return 3;
            }
            if (op == 0xB9 || op == 0xBA) {
                need(code, p, 5);
                return 5;
            }
            if (op == 0xC5) {
                need(code, p, 4);
                return 4;
            }
            if (op <= 0x0F || (op >= 0x1A && op <= 0x35) || (op >= 0x3B && op <= 0x83)
                    || (op >= 0x85 && op <= 0x98) || (op >= 0xAC && op <= 0xB1)
                    || op == 0xBE || op == 0xBF || op == 0xC2 || op == 0xC3) {
                need(code, p, 1);
                return 1;
            }
            throw new IllegalStateException("unknown opcode 0x" + Integer.toHexString(op));
        }

        private static void need(byte[] code, int p, int len) {
            if (len < 0 || p + len > code.length) {
                throw new IllegalStateException("truncated instruction");
            }
        }
    }

    /* ---------------------------------------------------------------- */
    /* Constant pool                                                     */
    /* ---------------------------------------------------------------- */

    private static final class ConstantPool {
        int count;
        int[] tag;
        String[] utf8;
        int[] utf8Ref;

        static ConstantPool read(Reader r) throws Exception {
            ConstantPool cp = new ConstantPool();
            cp.count = r.u2();
            if (cp.count < 1) {
                throw new IllegalStateException("bad constant pool");
            }
            cp.tag = new int[cp.count];
            cp.utf8 = new String[cp.count];
            cp.utf8Ref = new int[cp.count];
            for (int i = 1; i < cp.count; i++) {
                int t = r.u1();
                cp.tag[i] = t;
                switch (t) {
                    case 1: // Utf8
                        cp.utf8[i] = r.utf8();
                        break;
                    case 7: // Class
                    case 16: // MethodType
                    case 19: // Module
                    case 20: // Package
                        r.skip(2);
                        break;
                    case 8: // String
                        cp.utf8Ref[i] = r.u2();
                        break;
                    case 15: // MethodHandle
                        r.skip(3);
                        break;
                    case 3: // Integer
                    case 4: // Float
                    case 9: // Fieldref
                    case 10: // Methodref
                    case 11: // InterfaceMethodref
                    case 12: // NameAndType
                    case 17: // Dynamic
                    case 18: // InvokeDynamic
                        r.skip(4);
                        break;
                    case 5: // Long
                    case 6: // Double
                        r.skip(8);
                        i++;
                        break;
                    default:
                        throw new IllegalStateException("bad constant pool tag " + t);
                }
            }
            return cp;
        }

        String constantString(int index) {
            if (index <= 0 || index >= count || tag[index] != 8) {
                return null;
            }
            int ref = utf8Ref[index];
            if (ref <= 0 || ref >= count) {
                return null;
            }
            return utf8[ref];
        }

        int indexOfUtf8(String value) {
            for (int i = 1; i < count; i++) {
                if (value.equals(utf8[i])) {
                    return i;
                }
            }
            return -1;
        }
    }

    private static final class CodeAttr {
        int maxStack;
        int maxLocals;
        byte[] code;
        int[] excStart;
        int[] excEnd;
        int[] excHandler;
        int[] excType;
        Attr[] attrs;

        static CodeAttr parse(byte[] data) throws Exception {
            Reader r = new Reader(data);
            CodeAttr code = new CodeAttr();
            code.maxStack = r.u2();
            code.maxLocals = r.u2();
            code.code = r.bytes(r.u4AsInt());
            int excCount = r.u2();
            code.excStart = new int[excCount];
            code.excEnd = new int[excCount];
            code.excHandler = new int[excCount];
            code.excType = new int[excCount];
            for (int i = 0; i < excCount; i++) {
                code.excStart[i] = r.u2();
                code.excEnd[i] = r.u2();
                code.excHandler[i] = r.u2();
                code.excType[i] = r.u2();
            }
            int attrCount = r.u2();
            code.attrs = new Attr[attrCount];
            for (int i = 0; i < attrCount; i++) {
                Attr attr = new Attr();
                attr.nameIndex = r.u2();
                attr.data = r.bytes(r.u4AsInt());
                code.attrs[i] = attr;
            }
            return code;
        }

        boolean referencesString(ConstantPool cp, String value) {
            try {
                int[] positions = Walk.positions(code);
                for (int pos : positions) {
                    int op = code[pos] & 0xFF;
                    int index = -1;
                    if (op == 0x12) {
                        index = code[pos + 1] & 0xFF;
                    } else if (op == 0x13) {
                        index = ((code[pos + 1] & 0xFF) << 8) | (code[pos + 2] & 0xFF);
                    }
                    if (index > 0 && value.equals(cp.constantString(index))) {
                        return true;
                    }
                }
            } catch (Throwable t) {
                return false;
            }
            return false;
        }
    }

    /* ---------------------------------------------------------------- */
    /* Class rebuild                                                     */
    /* ---------------------------------------------------------------- */

    private static final class ClassFile {
        int minor;
        int major;
        int cpCountValue;
        int cpCount;
        int newCpCount;
        int targetMethodIndex;
        int targetMethodRef;
        byte[] cpBytes;
        byte[] headerBytes;
        byte[] fieldsBytes;
        Method[] methods;
        byte[] classAttrsBytes;

        byte[] toBytes() throws Exception {
            ByteArrayOutputStream out = new ByteArrayOutputStream(cpBytes.length + 256);
            writeU4(out, 0xCAFEBABEL);
            writeU2(out, minor);
            writeU2(out, major);
            writeU2(out, cpCount);
            out.write(cpBytes);
            int base = cpCountValue;
            writeUtf8Entry(out, "net/witch/f3/WitchF3Append");
            out.write(7); // Class
            writeU2(out, base);
            writeUtf8Entry(out, "appendInfo");
            writeUtf8Entry(out, "(Ljava/util/List;)V");
            out.write(12); // NameAndType
            writeU2(out, base + 2);
            writeU2(out, base + 3);
            out.write(10); // Methodref
            writeU2(out, base + 1);
            writeU2(out, base + 4);
            out.write(headerBytes);
            out.write(fieldsBytes);
            writeU2(out, methods.length);
            for (Method m : methods) {
                writeU2(out, m.access);
                writeU2(out, m.nameIndex);
                writeU2(out, m.descIndex);
                writeU2(out, m.attrs.length);
                for (Attr attr : m.attrs) {
                    writeU2(out, attr.nameIndex);
                    writeU4(out, attr.data.length);
                    out.write(attr.data);
                }
            }
            out.write(classAttrsBytes);
            return out.toByteArray();
        }
    }

    private static final class Method {
        int access;
        int nameIndex;
        int descIndex;
        Attr[] attrs;
    }

    private static final class Attr {
        int nameIndex;
        byte[] data;
    }

    /* ---------------------------------------------------------------- */
    /* Primitives                                                        */
    /* ---------------------------------------------------------------- */

    private static final class Reader {
        final byte[] b;
        int pos;

        Reader(byte[] b) {
            this.b = b;
        }

        private void need(int n) {
            if (n < 0 || pos + n > b.length) {
                throw new IllegalStateException("truncated class file");
            }
        }

        int u1() {
            need(1);
            return b[pos++] & 0xFF;
        }

        int u2() {
            need(2);
            int v = ((b[pos] & 0xFF) << 8) | (b[pos + 1] & 0xFF);
            pos += 2;
            return v;
        }

        long u4() {
            need(4);
            long v = ((long) (b[pos] & 0xFF) << 24) | ((b[pos + 1] & 0xFF) << 16)
                    | ((b[pos + 2] & 0xFF) << 8) | (b[pos + 3] & 0xFF);
            pos += 4;
            return v;
        }

        int u4AsInt() {
            long v = u4();
            if (v > Integer.MAX_VALUE) {
                throw new IllegalStateException("attribute too large");
            }
            return (int) v;
        }

        void skip(int n) {
            need(n);
            pos += n;
        }

        byte[] bytes(int n) {
            need(n);
            byte[] result = new byte[n];
            System.arraycopy(b, pos, result, 0, n);
            pos += n;
            return result;
        }

        String utf8() {
            return new String(bytes(u2()), UTF8);
        }
    }

    private static void skipAttributes(Reader r) {
        int count = r.u2();
        for (int i = 0; i < count; i++) {
            r.skip(2);
            r.skip(r.u4AsInt());
        }
    }

    private static int readS2(byte[] b, int p) {
        return (short) (((b[p] & 0xFF) << 8) | (b[p + 1] & 0xFF));
    }

    private static int readS4(byte[] b, int p) {
        return ((b[p] & 0xFF) << 24) | ((b[p + 1] & 0xFF) << 16) | ((b[p + 2] & 0xFF) << 8) | (b[p + 3] & 0xFF);
    }

    private static byte[] slice(byte[] b, int from, int to) {
        byte[] result = new byte[to - from];
        System.arraycopy(b, from, result, 0, to - from);
        return result;
    }

    private static void writeU2(ByteArrayOutputStream out, int value) {
        out.write((value >> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeU4(ByteArrayOutputStream out, long value) {
        out.write((int) (value >> 24) & 0xFF);
        out.write((int) (value >> 16) & 0xFF);
        out.write((int) (value >> 8) & 0xFF);
        out.write((int) value & 0xFF);
    }

    private static void writeS4(ByteArrayOutputStream out, int value) {
        out.write((value >> 24) & 0xFF);
        out.write((value >> 16) & 0xFF);
        out.write((value >> 8) & 0xFF);
        out.write(value & 0xFF);
    }

    private static void writeUtf8Entry(ByteArrayOutputStream out, String value) throws Exception {
        byte[] bytes = value.getBytes(UTF8);
        out.write(1);
        writeU2(out, bytes.length);
        out.write(bytes);
    }
}
