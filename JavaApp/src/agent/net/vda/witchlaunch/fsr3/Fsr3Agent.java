package net.vda.witchlaunch.fsr3;

import java.lang.instrument.Instrumentation;

/**
 * FidelityFX (FSR 1/2/3 + Frame Generation) Java agent.
 *
 * Installed with -javaagent only when the user enabled an FidelityFX effect in
 * the launcher settings. agentArgs format: "mode=<0..4>&fg=<0|1>" with
 * optional "&scale=<0.25..1.0>" (render resolution scale, upscaler only) and
 * "&sharp=<0.0..1.0>" (RCAS sharpening). mode selects the upscaler (1=FSR1,
 * 2=FSR2, 3=FSR3U; 0=off) and fg enables frame generation - both can be on
 * at the same time.
 *
 * Patches (prefix injection / getter body replacement):
 *  - Minecraft.renderFrame          -> capture the Minecraft instance
 *  - Window.getWidth/getHeight      -> render-resolution scaling
 *  - Window.getGuiScaledWidth/...   -> keep GUI layout consistent with it
 *  - VulkanGpuSurface.blitFromTexture -> capture the main color texture
 *  - VulkanCommandEncoder.submit    -> record FidelityFX work into the frame
 *  - VulkanGpuSurface.present       -> frame generation extra present
 */
public class Fsr3Agent {
    private static volatile boolean initialized = false;
    private static volatile Instrumentation savedInstrumentation;

    public static void premain(String agentArgs, Instrumentation inst) {
        if (initialized) return;
        initialized = true;
        savedInstrumentation = inst;

        int mode = parseMode(agentArgs);
        int fg = parseFg(agentArgs);
        float scale = parseScale(agentArgs);
        float sharpness = parseSharpness(agentArgs);
        System.out.println("[Fsr3Agent] Initializing (upscaler=" + mode
                + " fg=" + fg + " scale=" + scale + " sharp=" + sharpness + ")");

        Fsr3Bridge.configure(mode, fg, scale, sharpness);

        try {
            Fsr3Patcher.install(inst);
            System.out.println("[Fsr3Agent] Patcher installed");
        } catch (Throwable t) {
            System.err.println("[Fsr3Agent] Could not install patcher: " + t);
        }
        System.out.println("[Fsr3Agent] Agent installed");
    }

    public static void agentmain(String agentArgs, Instrumentation inst) {
        premain(agentArgs, inst);
    }

    public static Instrumentation getInstrumentation() {
        return savedInstrumentation;
    }

    private static int parseMode(String agentArgs) {
        int mode = Fsr3Native.MODE_NONE;
        if (agentArgs != null) {
            for (String part : agentArgs.split("&")) {
                part = part.trim();
                if (part.startsWith("mode=")) {
                    try {
                        mode = Integer.parseInt(part.substring(5).trim());
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        return mode;
    }

    private static int parseFg(String agentArgs) {
        int fg = 0;
        if (agentArgs != null) {
            for (String part : agentArgs.split("&")) {
                part = part.trim();
                if (part.startsWith("fg=")) {
                    try {
                        fg = Integer.parseInt(part.substring(3).trim());
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        return fg != 0 ? 1 : 0;
    }

    private static float parseScale(String agentArgs) {
        float scale = 1.0f;
        if (agentArgs != null) {
            for (String part : agentArgs.split("&")) {
                part = part.trim();
                if (part.startsWith("scale=")) {
                    try {
                        scale = Float.parseFloat(part.substring(6).trim());
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        return Math.max(0.25f, Math.min(1.0f, scale));
    }

    private static float parseSharpness(String agentArgs) {
        float sharpness = 0.6f;
        if (agentArgs != null) {
            for (String part : agentArgs.split("&")) {
                part = part.trim();
                if (part.startsWith("sharp=")) {
                    try {
                        sharpness = Float.parseFloat(part.substring(6).trim());
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        return Math.max(0.0f, Math.min(1.0f, sharpness));
    }
}
