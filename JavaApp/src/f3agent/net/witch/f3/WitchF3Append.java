package net.witch.f3;

import java.util.List;

/**
 * Runtime helper injected into Minecraft's debug overlay. The launcher passes
 * the formatted values as system properties so this class never needs to touch
 * any game class or mapping.
 */
public final class WitchF3Append {
    private WitchF3Append() {
    }

    public static void appendInfo(List<String> lines) {
        try {
            if (lines == null) {
                return;
            }
            addProp(lines, "witch.f3.chip", "Chip: ");
            addProp(lines, "witch.f3.ios", "iOS: ");
            addProp(lines, "witch.f3.launcher", "Launcher: ");
            addProp(lines, "witch.f3.version", "Launcher version: ");
            addProp(lines, "witch.f3.build", "Launcher build: ");
            addProp(lines, "witch.f3.buildtype", "Build type: ");
        } catch (Throwable ignored) {
            // Never let the overlay append break the game.
        }
    }

    private static void addProp(List<String> lines, String key, String prefix) {
        try {
            String value = System.getProperty(key);
            if (value != null && !value.isEmpty()) {
                lines.add(prefix + value);
            }
        } catch (Throwable ignored) {
        }
    }
}
