package com.mojang.text2speech;

import java.util.Locale;

/**
 * iOS stub of Mojang's text2speech OperatingSystem enum.
 *
 * The launcher replaces com.mojang:text2speech with its own Narrator stubs
 * (native speech is unavailable on iOS), but mods still reference the real
 * API. ModernFix's GameNarratorMixin, for example, switches on
 * OperatingSystem.LINUX and calls OperatingSystem.get(), so the enum has to
 * exist with the same shape or Mixin fails with
 * ClassMetadataNotFoundException while loading GameNarrator.
 */
public enum OperatingSystem {
    WINDOWS,
    LINUX,
    OSX,
    UNKNOWN;

    public static OperatingSystem get() {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        if (os.contains("win")) return WINDOWS;
        if (os.contains("mac") || os.contains("darwin") || os.contains("ios")) return OSX;
        if (os.contains("linux") || os.contains("android")) return LINUX;
        return UNKNOWN;
    }
}
