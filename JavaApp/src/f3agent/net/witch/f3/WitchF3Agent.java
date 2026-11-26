package net.witch.f3;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.nio.charset.Charset;
import java.security.ProtectionDomain;

/**
 * Java agent that appends launcher information (chip, iOS version, launcher
 * name/version/build) to the Minecraft F3 debug overlay.
 *
 * Targets the obfuscation-proof marker "Java: %s": the selection string used
 * by DebugScreenOverlay's system-information method. The transform is purely
 * additive and any failure falls through to the vanilla class.
 */
public final class WitchF3Agent {

    private WitchF3Agent() {
    }

    private static final byte[] JAVA_MARKER = "Java: %s".getBytes(Charset.forName("UTF-8"));

    public static void premain(String options, Instrumentation instrumentation) {
        install(instrumentation);
    }

    public static void agentmain(String options, Instrumentation instrumentation) {
        install(instrumentation);
    }

    private static void install(Instrumentation instrumentation) {
        if (instrumentation == null) {
            return;
        }
        try {
            instrumentation.addTransformer(new Transformer(), false);
            System.out.println("[WitchF3] agent loaded");
        } catch (Throwable t) {
            System.out.println("[WitchF3] agent disabled: " + t);
        }
    }

    private static final class Transformer implements ClassFileTransformer {

        public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
                ProtectionDomain protectionDomain, byte[] classfileBuffer) {
            try {
                if (classfileBuffer == null || className == null) {
                    return null;
                }
                if (className.startsWith("java/") || className.startsWith("javax/")
                        || className.startsWith("jdk/") || className.startsWith("sun/")
                        || className.startsWith("com/sun/") || className.startsWith("net/witch/")) {
                    return null;
                }
                if (!contains(classfileBuffer, JAVA_MARKER)) {
                    return null;
                }
                byte[] patched = ClassPatcher.patchDebugOverlay(classfileBuffer);
                if (patched != null) {
                    System.out.println("[WitchF3] patched debug overlay in " + className);
                    return patched;
                }
                return null;
            } catch (Throwable t) {
                return null;
            }
        }
    }

    private static boolean contains(byte[] haystack, byte[] needle) {
        if (needle.length == 0 || haystack.length < needle.length) {
            return false;
        }
        int limit = haystack.length - needle.length;
        outer:
        for (int i = 0; i <= limit; i++) {
            for (int j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    continue outer;
                }
            }
            return true;
        }
        return false;
    }
}
