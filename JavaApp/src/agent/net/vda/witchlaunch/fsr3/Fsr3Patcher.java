package net.vda.witchlaunch.fsr3;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;

/**
 * Bytecode patcher for the FidelityFX integration.
 *
 * Two transformation shapes are used, both verifier-safe:
 *  - Prefix injection: a branch-free, stack-neutral static call is prepended
 *    to the method body. Exception tables, line number tables, local variable
 *    tables and StackMapTable frames are shifted accordingly (only the first
 *    StackMapTable frame's delta changes, re-encoded as an extended frame when
 *    it would overflow the compact encoding).
 *  - Getter body replacement: straight-line bodies (no branch targets, no
 *    exception handlers) are replaced wholesale, which needs no StackMapTable
 *    at all.
 */
public class Fsr3Patcher implements ClassFileTransformer {

    private static final String BRIDGE_CLASS = "net/vda/witchlaunch/fsr3/Fsr3Bridge";

    // Patch targets (dotted names as passed to transform()).
    private static final String CLASS_MINECRAFT = "net.minecraft.client.Minecraft";
    private static final String CLASS_WINDOW = "com.mojang.blaze3d.platform.Window";
    private static final String CLASS_SURFACE = "com.mojang.renderpearl.backend.vulkan.VulkanGpuSurface";
    private static final String CLASS_ENCODER = "com.mojang.renderpearl.backend.vulkan.VulkanCommandEncoder";
    private static final String CLASS_PROJECTION = "net.minecraft.client.renderer.ProjectionMatrixBuffer";

    /**
     * The configuration record type, in the internal (slash separated) form.
     *
     * A CONSTANT_Class entry has to carry the internal name: the JVM rejects
     * the whole class file with "Illegal class name" when the name contains
     * dots (it expects the binary name only for the loader, not in the
     * constant pool).
     */
    private static final String CLASS_CONFIGURATION_INTERNAL =
            "com/mojang/renderpearl/api/device/GpuSurface$Configuration";

    private final Instrumentation instrumentation;

    /**
     * The upscaler that is active (0 = off, 1 = FSR1, 2 = FSR2, 3 = FSR3).
     *
     * Only the upscaler needs the swapchain to be as big as the drawable, so
     * the surface configuration is only patched when an upscaler runs. In the
     * frame generation mode the game keeps its own configuration, which means
     * one less patch on a code path that has to be exactly right.
     */
    private static volatile int upscalerMode = 0;

    public static void setUpscalerMode(int mode) {
        upscalerMode = mode;
    }

    public static void install(Instrumentation inst) {
        if (inst == null) {
            System.err.println("[Fsr3Patcher] No Instrumentation, cannot patch");
            return;
        }
        inst.addTransformer(new Fsr3Patcher(inst), true);
    }

    private Fsr3Patcher(Instrumentation inst) {
        this.instrumentation = inst;
    }

    @Override
    public byte[] transform(ClassLoader loader, String className,
                            Class<?> classBeingRedefined,
                            ProtectionDomain protectionDomain,
                            byte[] classfileBuffer) {
        if (classfileBuffer == null || className == null) {
            return null;
        }
        // The JVM hands the class name to transformers in the internal slash
        // form on this runtime (verified: PatchJNAAgent matches slash names);
        // normalize so dot-form constants work on both shapes. Every defining
        // classloader gets its own patched copy (a second copy of the game
        // classes silently used unpatched code before).
        String normalizedName = className.replace('/', '.');
        try {
            if (CLASS_MINECRAFT.equals(normalizedName)) {
                byte[] out = patchMinecraft(classfileBuffer);
                if (out != null) {
                    return out;
                }
            } else if (CLASS_WINDOW.equals(normalizedName)) {
                byte[] out = patchWindow(classfileBuffer);
                if (out != null) {
                    return out;
                }
            } else if (CLASS_SURFACE.equals(normalizedName)) {
                byte[] out = patchSurface(classfileBuffer);
                if (out != null) {
                    return out;
                }
            } else if (CLASS_ENCODER.equals(normalizedName)) {
                byte[] out = patchEncoder(classfileBuffer);
                if (out != null) {
                    return out;
                }
            } else if (CLASS_PROJECTION.equals(normalizedName)) {
                byte[] out = patchProjection(classfileBuffer);
                if (out != null) {
                    return out;
                }
            }
        } catch (Throwable t) {
            System.err.println("[Fsr3Patcher] transform failed for " + className + ": " + t);
        }
        return null;
    }

    // ---- per-class patch rules ------------------------------------------------

    private byte[] patchMinecraft(byte[] data) throws IOException {
        ClassFileParser parser = new ClassFileParser(data);
        boolean modified = false;
        for (MethodInfo m : parser.methods) {
            if ("renderFrame".equals(parser.getUtf8(m.nameIndex))
                    && "(Z)V".equals(parser.getUtf8(m.descriptorIndex))) {
                System.out.println("[Fsr3Patcher] patching Minecraft.renderFrame");
                m.code = injectPrefix(parser, m, new int[]{0x2A},
                        "onRenderFrame", "(Ljava/lang/Object;)V");
                modified = true;
            }
        }
        if (!modified) return null;
        // The JVM rejects a class file with a broken constant pool, so the
        // pool is checked before the bytes are handed over. A broken patch
        // then only disables the feature instead of crashing the game.
        parser.constantPool.validate();
        return parser.write();
    }

    private byte[] patchWindow(byte[] data) throws IOException {
        ClassFileParser parser = new ClassFileParser(data);
        boolean modified = false;
        for (MethodInfo m : parser.methods) {
            String name = parser.getUtf8(m.nameIndex);
            String desc = parser.getUtf8(m.descriptorIndex);
            if (!"()I".equals(desc)) continue;
            String bridge = null;
            if ("getWidth".equals(name)) bridge = "scaledWidth";
            else if ("getHeight".equals(name)) bridge = "scaledHeight";
            else if ("getGuiScaledWidth".equals(name)) bridge = "scaledGuiWidth";
            else if ("getGuiScaledHeight".equals(name)) bridge = "scaledGuiHeight";
            if (bridge == null) continue;
            System.out.println("[Fsr3Patcher] patching Window." + name);
            m.code = replaceBodyWithBridge(parser, bridge);
            m.maxStack = 1;
            m.maxLocals = 1;
            m.codeExcAndSubAttrs = null; // straight-line body: no frames needed
            modified = true;
        }
        if (!modified) return null;
        // The JVM rejects a class file with a broken constant pool, so the
        // pool is checked before the bytes are handed over. A broken patch
        // then only disables the feature instead of crashing the game.
        parser.constantPool.validate();
        return parser.write();
    }

    private byte[] patchSurface(byte[] data) throws IOException {
        ClassFileParser parser = new ClassFileParser(data);
        boolean modified = false;
        for (MethodInfo m : parser.methods) {
            String name = parser.getUtf8(m.nameIndex);
            String desc = parser.getUtf8(m.descriptorIndex);
            if ("blitFromTexture".equals(name)
                    && "(Lcom/mojang/renderpearl/backend/api/CommandEncoderBackend;Lcom/mojang/renderpearl/api/textures/GpuTextureView;)V".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.blitFromTexture");
                m.code = injectPrefix(parser, m, new int[]{0x2A, 0x2B, 0x2C},
                        "onBlit", "(Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/Object;)V");
                modified = true;
            } else if ("present".equals(name) && "()V".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.present");
                m.code = injectPrefix(parser, m, new int[]{0x2A},
                        "onPresent", "(Ljava/lang/Object;)V");
                modified = true;
            } else if ("configure".equals(name)
                    && "(Lcom/mojang/renderpearl/api/device/GpuSurface$Configuration;)V".equals(desc)) {
                if (upscalerMode != 0) {
                    // Witch patch: the swapchain has to match the CAMetalLayer's
                    // drawable, but the game only asks for its framebuffer size.
                    // The bridge rewrites the configuration to the drawable size
                    // so the FidelityFX upscaler can write a full resolution
                    // frame into the swapchain (the HUD keeps its size because
                    // the game renders into its own, smaller render target).
                    //
                    // The rewrite is a prefix, the original body still runs: it
                    // is the only shape that survives the verifier. Replacing
                    // the body with "invokevirtual configure" made the JVM
                    // reject the class ("Bad type on operand stack"), because
                    // the bridge hands back an Object that is not a
                    // Configuration.
                    System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.configure (rewrite)");
                    m.code = injectConfigurationRewrite(parser, m);
                } else {
                    // No upscaler: the configuration stays as the game asked
                    // for it. The hook is still needed - the frame generation
                    // reads the swapchain size from it and has to drop the
                    // cached images when the surface is reconfigured.
                    System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.configure (hook)");
                    m.code = injectPrefix(parser, m, new int[]{0x2A, 0x2B},
                            "onSurfaceConfigure", "(Ljava/lang/Object;Ljava/lang/Object;)V");
                }
                modified = true;
            } else if ("close".equals(name) && "()V".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.close");
                m.code = injectPrefix(parser, m, new int[]{0x2A},
                        "onSurfaceClose", "(Ljava/lang/Object;)V");
                modified = true;
            } else if ("isSuboptimal".equals(name) && "()Z".equals(desc)) {
                // MoltenVK marks a swapchain suboptimal whenever its extent
                // differs from the layer's natural drawable size. The launcher
                // deliberately renders below native resolution, so the flag is
                // permanently set and Minecraft recreates the swapchain every
                // frame (vkDeviceWaitIdle + destroy + create), collapsing the
                // frame rate. SUBOPTIMAL is advisory; real window resizes and
                // vsync changes still set windowSurfaceNeedsReconfiguring.
                System.out.println("[Fsr3Patcher] patching VulkanGpuSurface.isSuboptimal");
                m.code = new byte[]{0x03, (byte) 0xAC}; // iconst_0; ireturn
                m.maxStack = 1;
                m.maxLocals = 1;
                m.codeExcAndSubAttrs = null;
                modified = true;
            }
        }
        if (!modified) return null;
        // The JVM rejects a class file with a broken constant pool, so the
        // pool is checked before the bytes are handed over. A broken patch
        // then only disables the feature instead of crashing the game.
        parser.constantPool.validate();
        return parser.write();
    }

    private byte[] patchEncoder(byte[] data) throws IOException {
        ClassFileParser parser = new ClassFileParser(data);
        boolean modified = false;
        for (MethodInfo m : parser.methods) {
            String name = parser.getUtf8(m.nameIndex);
            String desc = parser.getUtf8(m.descriptorIndex);
            if ("submit".equals(name) && "()V".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching VulkanCommandEncoder.submit");
                m.code = injectPrefix(parser, m, new int[]{0x2A},
                        "onBeforeSubmit", "(Ljava/lang/Object;)V");
                modified = true;
            } else if ("signalSemaphore".equals(name) && "(JJJ)V".equals(desc)) {
                // Witch patch: the upscaler is recorded here instead of at
                // submit(). VulkanGpuSurface.blitFromTexture() copies the
                // frame into the swapchain and signals the present semaphore
                // right after it, so this is the exact spot where the game's
                // own copy happens - the upscale replaces that copy instead of
                // overwriting the whole swapchain at the end of the frame.
                System.out.println("[Fsr3Patcher] patching VulkanCommandEncoder.signalSemaphore");
                m.code = injectPrefix(parser, m, new int[]{0x2A},
                        "onEncoderSignalSemaphore", "(Ljava/lang/Object;)V");
                modified = true;
            }
        }
        if (!modified) return null;
        // The JVM rejects a class file with a broken constant pool, so the
        // pool is checked before the bytes are handed over. A broken patch
        // then only disables the feature instead of crashing the game.
        parser.constantPool.validate();
        return parser.write();
    }

    /**
     * The projection matrix upload path. FidelityFX's temporal accumulation
     * can only resolve the aliasing when the scene is rendered at a different
     * sub-pixel position every frame, so the launcher skews the projection
     * matrix by a sub-pixel jitter right before it is uploaded.
     *
     * Two hooks are needed:
     *  - getBuffer(Projection): the game only re-uploads the matrix when the
     *    Projection reports a new version, so a per-frame jitter would never
     *    reach the GPU while the camera stands still. The hook drops the
     *    buffer's cache so the matrix is written again every frame.
     *  - writeBuffer(Matrix4f): the matrix that is about to be uploaded is
     *    skewed by the current jitter.
     */
    private byte[] patchProjection(byte[] data) throws IOException {
        ClassFileParser parser = new ClassFileParser(data);
        boolean modified = false;
        for (MethodInfo m : parser.methods) {
            String name = parser.getUtf8(m.nameIndex);
            String desc = parser.getUtf8(m.descriptorIndex);
            if ("getBuffer".equals(name)
                    && "(Lnet/minecraft/client/renderer/Projection;)Lcom/mojang/renderpearl/api/buffers/GpuBufferSlice;".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching ProjectionMatrixBuffer.getBuffer");
                m.code = injectPrefix(parser, m, new int[]{0x2A, 0x2B},
                        "onProjectionBufferGet", "(Ljava/lang/Object;Ljava/lang/Object;)V");
                modified = true;
            } else if ("writeBuffer".equals(name)
                    && "(Lorg/joml/Matrix4f;)Lcom/mojang/renderpearl/api/buffers/GpuBufferSlice;".equals(desc)) {
                System.out.println("[Fsr3Patcher] patching ProjectionMatrixBuffer.writeBuffer");
                m.code = injectPrefix(parser, m, new int[]{0x2A, 0x2B},
                        "onProjectionWrite", "(Ljava/lang/Object;Ljava/lang/Object;)V");
                modified = true;
            }
        }
        if (!modified) return null;
        // The JVM rejects a class file with a broken constant pool, so the
        // pool is checked before the bytes are handed over. A broken patch
        // then only disables the feature instead of crashing the game.
        parser.constantPool.validate();
        return parser.write();
    }

    // ---- bytecode emission ----------------------------------------------------

    /** Prepend [loads...] + invokestatic bridge.name(desc) to the method body. */
    private static byte[] injectPrefix(ClassFileParser parser, MethodInfo method,
                                       int[] loads, String bridgeMethod, String bridgeDesc)
            throws IOException {
        int cpBridge = parser.constantPool.addClass(BRIDGE_CLASS);
        int cpMethodRef = parser.constantPool.addMethodref(cpBridge, bridgeMethod, bridgeDesc);

        int prefixLen = loads.length + 3; // loads + invokestatic (3 bytes)

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);
        for (int load : loads) {
            out.writeByte(load);
        }
        out.writeByte(0xB8); // invokestatic
        out.writeShort(cpMethodRef);
        out.write(method.code);

        byte[] original = method.code;
        byte[] combined = baos.toByteArray();
        method.codeExcAndSubAttrs = shiftCodeMetadata(method.codeExcAndSubAttrs, prefixLen, parser);
        if (method.maxStack < loads.length) {
            method.maxStack = loads.length;
        }
        return combined;
    }

    /** Replace the method body with aload_0; invokestatic bridge(...)I; ireturn. */
    private static byte[] replaceBodyWithBridge(ClassFileParser parser, String bridgeMethod)
            throws IOException {
        int cpBridge = parser.constantPool.addClass(BRIDGE_CLASS);
        int cpMethodRef = parser.constantPool.addMethodref(cpBridge, bridgeMethod,
                "(Ljava/lang/Object;)I");
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);
        out.writeByte(0x2A); // aload_0 (this)
        out.writeByte(0xB8); // invokestatic
        out.writeShort(cpMethodRef);
        out.writeByte(0xAC); // ireturn
        return baos.toByteArray();
    }

    /**
     * Prepend a call that lets the bridge rewrite the configuration and store
     * the result back into the parameter slot before the original body runs:
     *
     * <pre>aload_0
     * aload_1
     * invokestatic Fsr3Bridge.surfaceConfiguration(Object,Object)Object
     * checkcast GpuSurface$Configuration
     * astore_1</pre>
     *
     * The configuration is an immutable record, so it has to be replaced as a
     * whole; the original body then uses the rewritten value from slot 1.
     *
     * The checkcast is required by the verifier: surfaceConfiguration() is
     * typed on Object (the agent must not link against game classes), and the
     * raw Object it returns cannot be stored into the Configuration slot - the
     * StackMapTable frames of the original body declare that slot as
     * Configuration, so without the cast the class fails verification with
     * "Bad type on operand stack".
     */
    private static byte[] injectConfigurationRewrite(ClassFileParser parser, MethodInfo method)
            throws IOException {
        int cpBridge = parser.constantPool.addClass(BRIDGE_CLASS);
        int cpBridgeMethod = parser.constantPool.addMethodref(cpBridge,
                "surfaceConfiguration", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
        int cpConfiguration = parser.constantPool.addClass(CLASS_CONFIGURATION_INTERNAL);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(baos);
        out.writeByte(0x2A); // aload_0 (this, the surface)
        out.writeByte(0x2B); // aload_1 (the configuration)
        out.writeByte(0xB8); // invokestatic
        out.writeShort(cpBridgeMethod);
        out.writeByte(0xC0); // checkcast
        out.writeShort(cpConfiguration);
        out.writeByte(0x4C); // astore_1
        int prefixLen = baos.size();
        out.write(method.code);

        byte[] combined = baos.toByteArray();
        method.codeExcAndSubAttrs = shiftCodeMetadata(method.codeExcAndSubAttrs, prefixLen, parser);
        if (method.maxStack < 2) {
            method.maxStack = 2;
        }
        return combined;
    }

    /**
     * Shift all code metadata (exception table entries, StackMapTable frame
     * offsets, LineNumberTable, LocalVariableTable/TypeTable start PCs) by
     * delta bytes. raw is the preserved bytes after the Code attribute's
     * bytecode section: [excCount u2][8-byte entries][subAttrCount u2]{attrs}.
     */
    private static byte[] shiftCodeMetadata(byte[] raw, int delta, ClassFileParser parser) {
        if (raw == null || raw.length == 0 || delta == 0) {
            return raw;
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream(raw.length + 16);
        DataOutputStream o = new DataOutputStream(out);
        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(raw));
            int excCount = in.readUnsignedShort();
            o.writeShort(excCount);
            for (int i = 0; i < excCount; i++) {
                int startPc = in.readUnsignedShort() + delta;
                int endPc = in.readUnsignedShort() + delta;
                int handlerPc = in.readUnsignedShort() + delta;
                int catchType = in.readUnsignedShort();
                o.writeShort(startPc);
                o.writeShort(endPc);
                o.writeShort(handlerPc);
                o.writeShort(catchType);
            }
            int subAttrCount = in.readUnsignedShort();
            o.writeShort(subAttrCount);
            for (int i = 0; i < subAttrCount; i++) {
                int nameIdx = in.readUnsignedShort();
                int len = in.readInt();
                byte[] attrData = new byte[len];
                in.readFully(attrData);
                String attrName = parser.getUtf8(nameIdx);
                if ("StackMapTable".equals(attrName)) {
                    attrData = shiftStackMapTable(attrData, delta);
                } else if ("LineNumberTable".equals(attrName)
                        || "LocalVariableTable".equals(attrName)
                        || "LocalVariableTypeTable".equals(attrName)) {
                    attrData = shiftPcTable(attrData, delta, attrName);
                }
                o.writeShort(nameIdx);
                o.writeInt(attrData.length);
                o.write(attrData);
            }
        } catch (IOException e) {
            // Corrupt metadata: fall back to the untouched original.
            System.err.println("[Fsr3Patcher] metadata shift failed: " + e);
            return raw;
        }
        return out.toByteArray();
    }

    /**
     * Shift StackMapTable frame offsets. Only the first frame's offset_delta
     * changes (deltas are relative); compact same_frame / append / chop
     * encodings are re-emitted as their *_extended forms when the shifted
     * delta no longer fits.
     */
    private static byte[] shiftStackMapTable(byte[] data, int delta) {
        ByteArrayOutputStream out = new ByteArrayOutputStream(data.length + 8);
        DataOutputStream o = new DataOutputStream(out);
        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(data));
            int count = in.readUnsignedShort();
            o.writeShort(count);
            for (int i = 0; i < count; i++) {
                int frameType = in.readUnsignedByte();
                if (i == 0) {
                    writeFirstFrame(o, in, frameType, delta);
                } else {
                    copyFrame(o, in, frameType);
                }
            }
        } catch (IOException e) {
            System.err.println("[Fsr3Patcher] StackMapTable shift failed: " + e);
            return data;
        }
        return out.toByteArray();
    }

    private static void writeFirstFrame(DataOutputStream o, DataInputStream in,
                                        int frameType, int delta) throws IOException {
        int originalDelta;
        int trailingKind; // 0 = none, 1 = one vti, 2 = chop (nothing but delta)
        if (frameType <= 63) {
            originalDelta = frameType;
            trailingKind = 0;
        } else if (frameType <= 127) {
            originalDelta = frameType - 64;
            trailingKind = 1;
        } else if (frameType == 247) {
            originalDelta = in.readUnsignedShort();
            trailingKind = 1;
        } else if (frameType <= 250) { // 248..250 chop
            originalDelta = in.readUnsignedShort();
            trailingKind = 2;
        } else if (frameType == 251) {
            originalDelta = in.readUnsignedShort();
            trailingKind = 0;
        } else { // 252..255 append / full
            originalDelta = in.readUnsignedShort();
            trailingKind = 0;
        }
        int newDelta = originalDelta + delta;

        if (trailingKind == 1) {
            if (newDelta <= 63 && frameType <= 127) {
                // compact same_locals_1_stack_item still fits
                o.writeByte(frameType + newDelta - originalDelta);
            } else {
                o.writeByte(247); // same_locals_1_stack_item_extended
                o.writeShort(newDelta);
            }
            copyVti(o, in);
        } else if (frameType <= 63 && newDelta <= 63) {
            o.writeByte(newDelta);
        } else if (frameType <= 63) {
            o.writeByte(251); // same_frame_extended
            o.writeShort(newDelta);
        } else if (frameType <= 250) { // chop forms
            o.writeByte(frameType);
            o.writeShort(newDelta);
        } else if (frameType == 251) {
            o.writeByte(251);
            o.writeShort(newDelta);
        } else { // 252..255 append / full
            o.writeByte(frameType);
            o.writeShort(newDelta);
            if (frameType == 255) {
                copyFullFrameRest(o, in);
            } else {
                int appends = frameType - 251;
                for (int i = 0; i < appends; i++) {
                    copyVti(o, in);
                }
            }
        }
    }

    /** Copy a non-first frame (offset deltas are relative - unchanged). */
    private static void copyFrame(DataOutputStream o, DataInputStream in, int frameType)
            throws IOException {
        o.writeByte(frameType);
        if (frameType == 247 || (frameType >= 248 && frameType <= 251) || frameType >= 252) {
            o.writeShort(in.readUnsignedShort());
        }
        if ((frameType >= 64 && frameType <= 127) || frameType == 247) {
            copyVti(o, in);
        } else if (frameType == 255) {
            copyFullFrameRest(o, in);
        } else if (frameType >= 252) {
            int appends = frameType - 251;
            for (int i = 0; i < appends; i++) {
                copyVti(o, in);
            }
        }
    }

    private static void copyVti(DataOutputStream o, DataInputStream in) throws IOException {
        int tag = in.readUnsignedByte();
        o.writeByte(tag);
        if (tag == 7 || tag == 8) {
            o.writeShort(in.readUnsignedShort());
        }
    }

    private static void copyFullFrameRest(DataOutputStream o, DataInputStream in)
            throws IOException {
        int locals = in.readUnsignedShort();
        o.writeShort(locals);
        for (int i = 0; i < locals; i++) {
            copyVti(o, in);
        }
        int stack = in.readUnsignedShort();
        o.writeShort(stack);
        for (int i = 0; i < stack; i++) {
            copyVti(o, in);
        }
    }

    /**
     * Shift start_pc values in a LineNumberTable ([u2 count][u2 pc, u2 line]...)
     * or LocalVariableTable/TypeTable ([u2 count][10-byte entries]).
     */
    private static byte[] shiftPcTable(byte[] data, int delta, String attrName) {
        ByteArrayOutputStream out = new ByteArrayOutputStream(data.length);
        DataOutputStream o = new DataOutputStream(out);
        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(data));
            int count = in.readUnsignedShort();
            o.writeShort(count);
            boolean local = attrName.startsWith("LocalVariable");
            for (int i = 0; i < count; i++) {
                int startPc = in.readUnsignedShort() + delta;
                o.writeShort(startPc);
                if (local) {
                    // length, nameIdx, descIdx, index
                    for (int j = 0; j < 4; j++) {
                        o.writeShort(in.readUnsignedShort());
                    }
                } else {
                    o.writeShort(in.readUnsignedShort()); // line
                }
            }
        } catch (IOException e) {
            System.err.println("[Fsr3Patcher] " + attrName + " shift failed: " + e);
            return data;
        }
        return out.toByteArray();
    }

    // ============================================================
    // Class file parser (raw-bytes constant pool, preserves attributes)
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

        String getUtf8(int idx) {
            return constantPool.getUtf8(idx);
        }

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

    // ============================================================
    // Constant pool - raw bytes with append support
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
        /** tag / fieldA / fieldB of every entry, so the pool can be checked. */
        private final java.util.List<int[]> entryMeta = new java.util.ArrayList<int[]>();
        /** the text of the UTF8 entries that were added (null for the originals). */
        private final java.util.List<String> entryUtf8 = new java.util.ArrayList<String>();

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
                entryMeta.add(new int[]{tag, -1, -1});
                entryUtf8.add(null);
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
                        entryMeta.get(entryMeta.size() - 1)[1] =
                                ((tmp[0] & 0xFF) << 8) | (tmp[1] & 0xFF);
                        break;
                    }
                    case 9: case 10: case 11: case 12: case 17: case 18: {
                        byte[] tmp = new byte[4];
                        in.readFully(tmp);
                        rawBuf.write(tmp);
                        int[] meta = entryMeta.get(entryMeta.size() - 1);
                        meta[1] = ((tmp[0] & 0xFF) << 8) | (tmp[1] & 0xFF);
                        meta[2] = ((tmp[2] & 0xFF) << 8) | (tmp[3] & 0xFF);
                        break;
                    }
                    case 19: case 20: {
                        byte[] tmp = new byte[2];
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
                if (tag == 5 || tag == 6) {
                    // long and double take two constant pool slots
                    entryMeta.add(new int[]{-1, -1, -1});
                    entryUtf8.add(null);
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
            entryMeta.add(new int[]{1, -1, -1});
            entryUtf8.add(value);
            return idx;
        }

        int addClass(String name) {
            // A CONSTANT_Class entry must use the internal name (slashes).
            // A dotted name makes the JVM reject the whole class file with
            // "Illegal class name ... in class file ...".
            String internal = name.indexOf('.') >= 0 ? name.replace('.', '/') : name;
            int nameIdx = addUtf8(internal);
            int existing = findClassByNameIndex(nameIdx);
            if (existing >= 0) return existing;
            int idx = nextIndex++;
            newEntriesBuf.write(7);
            newEntriesBuf.write((nameIdx >> 8) & 0xFF);
            newEntriesBuf.write(nameIdx & 0xFF);
            entryMeta.add(new int[]{7, nameIdx, -1});
            entryUtf8.add(null);
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
            newEntriesBuf.write((nIdx) & 0xFF); // keep low byte (name idx)
            newEntriesBuf.write((dIdx >> 8) & 0xFF);
            newEntriesBuf.write((dIdx) & 0xFF);
            entryMeta.add(new int[]{12, nIdx, dIdx});
            entryUtf8.add(null);
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
            entryMeta.add(new int[]{10, classIdx, ntIdx});
            entryUtf8.add(null);
            return idx;
        }

        /**
         * Checks the references the JVM checks when it loads the class.
         *
         * A broken constant pool makes the JVM reject the whole class file
         * ("Illegal class name ..."), which crashes the game on startup. The
         * patcher runs this before it hands the bytes over, so a broken patch
         * can only disable the feature instead of killing the game.
         */
        void validate() {
            for (int i = 0; i < entryMeta.size(); i++) {
                int[] meta = entryMeta.get(i);
                int tag = meta[0];
                int index = i + 1;
                if (tag == 7) {
                    String name = utf8At(meta[1]);
                    if (name == null) {
                        throw new IllegalStateException("cp #" + index
                                + ": the class name #" + meta[1] + " is not a UTF8");
                    }
                    if (name.indexOf('.') >= 0) {
                        throw new IllegalStateException("cp #" + index
                                + ": the class name '" + name
                                + "' has to use the internal form (slashes)");
                    }
                } else if (tag == 9 || tag == 10 || tag == 11) {
                    if (tagAt(meta[1]) != 7) {
                        throw new IllegalStateException("cp #" + index
                                + ": the class index #" + meta[1] + " is not a class");
                    }
                    if (tagAt(meta[2]) != 12) {
                        throw new IllegalStateException("cp #" + index
                                + ": the name and type index #" + meta[2]
                                + " is not a name and type");
                    }
                } else if (tag == 12) {
                    if (tagAt(meta[1]) != 1 || tagAt(meta[2]) != 1) {
                        throw new IllegalStateException("cp #" + index
                                + ": the name and type does not point at UTF8 entries");
                    }
                }
            }
        }

        private int tagAt(int index) {
            if (index < 1 || index > entryMeta.size()) return -1;
            return entryMeta.get(index - 1)[0];
        }

        private String utf8At(int index) {
            if (index < 1 || index > entryMeta.size()) return null;
            if (entryMeta.get(index - 1)[0] != 1) return null;
            String added = entryUtf8.get(index - 1);
            if (added != null) return added;
            return getUtf8(index);
        }

        private int findUtf8(String value) {
            byte[] valueBytes = encodeModifiedUtf8(value);
            final int[] found = {-1};
            walk(new CpVisitor() {
                @Override
                public void visit(int index, int tag, int dataPos, int dataSize) {
                    if (found[0] >= 0 || tag != 1) return;
                    int len = dataSize - 2;
                    if (len != valueBytes.length) return;
                    int p = dataPos + 2;
                    for (int j = 0; j < len; j++) {
                        if (rawEntries[p + j] != valueBytes[j]) return;
                    }
                    found[0] = index;
                }
            });
            return found[0];
        }

        private int findClassByNameIndex(int nameIndex) {
            return findEntry1(7, nameIndex);
        }

        private int findNameAndType(int nameIdx, int descIdx) {
            return findEntry2(12, nameIdx, descIdx);
        }

        private int findMethodref(int classIdx, int natIdx) {
            return findEntry2(10, classIdx, natIdx);
        }

        /** Finds the first entry of the given tag whose single u2 field matches. */
        private int findEntry1(final int tag, final int fieldA) {
            final int[] found = {-1};
            walk(new CpVisitor() {
                @Override
                public void visit(int index, int t, int dataPos, int dataSize) {
                    if (found[0] >= 0 || t != tag) return;
                    if (u2At(dataPos) == fieldA) found[0] = index;
                }
            });
            return found[0];
        }

        /** Finds the first entry of the given tag whose two u2 fields match. */
        private int findEntry2(final int tag, final int fieldA, final int fieldB) {
            final int[] found = {-1};
            walk(new CpVisitor() {
                @Override
                public void visit(int index, int t, int dataPos, int dataSize) {
                    if (found[0] >= 0 || t != tag) return;
                    if (u2At(dataPos) == fieldA && u2At(dataPos + 2) == fieldB) {
                        found[0] = index;
                    }
                }
            });
            return found[0];
        }

        private int u2At(int pos) {
            return ((rawEntries[pos] & 0xFF) << 8) | (rawEntries[pos + 1] & 0xFF);
        }

        /**
         * Walks the raw constant pool entries.
         *
         * The UTF8 entries carry their byte length, so they have to be skipped
         * with it. Ignoring it shifts every following entry, and the lookups
         * then return indices of unrelated entries - which silently produced
         * broken constant pool references (the JVM rejected the whole class
         * file with "Illegal class name").
         */
        private void walk(CpVisitor visitor) {
            int pos = 0;
            int idx = 1;
            while (pos < rawEntriesLen && idx < entryCount) {
                int tag = rawEntries[pos++] & 0xFF;
                int dataPos = pos;
                int size;
                if (tag == 1) {
                    int len = u2At(pos);
                    size = 2 + len;
                } else {
                    size = entryDataSize(tag);
                }
                visitor.visit(idx, tag, dataPos, size);
                pos += size;
                if (tag == 5 || tag == 6) idx++;
                idx++;
            }
        }

        private interface CpVisitor {
            void visit(int index, int tag, int dataPos, int dataSize);
        }

        private static int entryDataSize(int tag) {
            switch (tag) {
                case 3: case 4: return 4;
                case 5: case 6: return 8;
                case 7: case 8: case 16: return 2;
                case 9: case 10: case 11: case 12: case 17: case 18: return 4;
                case 19: case 20: return 2;
                case 15: return 3;
                default: return 0;
            }
        }

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
                    r[p++] = (byte) (c & 0x3F);
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
    // MethodInfo - preserves non-Code attributes
    // ============================================================

    static class MethodInfo {
        int accessFlags, nameIndex, descriptorIndex;
        byte[] code;
        int maxStack = 64, maxLocals = 64;
        byte[] nonCodeAttrs;
        int nonCodeAttrCount;
        byte[] codeExcAndSubAttrs;

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
                    byte[] attrData = new byte[length];
                    in.readFully(attrData);
                    otherAttrs.write(attrData);
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
