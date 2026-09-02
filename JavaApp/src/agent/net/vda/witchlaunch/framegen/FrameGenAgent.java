package net.vda.witchlaunch.framegen;

import java.lang.instrument.Instrumentation;

/**
 * Frame Generation Java Agent.
 *
 * Responsibilities:
 * 1. Save the Instrumentation instance for launcher-side use.
 * 2. Install FrameGenPatcher to inject FrameGenBridge.updateCamera() into GameRenderer.
 * 3. Best-effort: register native methods early.
 *
 * This removes dependency on Fabric Mixin. The launcher patches
 * directly into Minecraft via standard JVM Instrumentation API.
 *
 * IMPORTANT: This class is loaded via -javaagent, NOT from launcher.jar.
 * This ensures premain() receives the real Instrumentation instance.
 */
public class FrameGenAgent {
    private static volatile boolean initialized = false;
    private static volatile Instrumentation savedInstrumentation;

    public static void premain(String agentArgs, Instrumentation inst) {
        if (initialized) return;
        initialized = true;
        savedInstrumentation = inst;

        System.out.println("[FrameGenAgent] Initializing Frame Generation Agent");

        // Install the patcher directly from the agent
        // This ensures it runs even if Tools.installFrameGenPatcher() can't find us
        try {
            Class<?> patcherClass = Class.forName("net.vda.witchlaunch.framegen.FrameGenPatcher");
            java.lang.reflect.Method installMethod = patcherClass.getMethod("install", Instrumentation.class);
            installMethod.invoke(null, inst);
            System.out.println("[FrameGenAgent] Patcher installed via agent premain");
        } catch (Throwable t) {
            System.err.println("[FrameGenAgent] Could not install patcher in premain: " + t.getMessage());
        }

        // Native side is enabled by JavaLauncher.m before JVM start.
        System.out.println("[FrameGenAgent] Agent installed successfully");
    }

    public static void agentmain(String agentArgs, Instrumentation inst) {
        premain(agentArgs, inst);
    }

    /**
     * Get the saved Instrumentation instance.
     * Called by the launcher (Tools.launchMinecraft) to install
     * the FrameGenPatcher as a fallback.
     */
    public static Instrumentation getInstrumentation() {
        return savedInstrumentation;
    }
}
