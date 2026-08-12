package com.mojang.blaze3d.platform;

/*
 * iOS shim for Minecraft's macOS-only window utilities.
 *
 * The real class talks to AppKit through ca.weblite (RoboVM jcocoa), which
 * links Cocoa.framework and cannot load on iOS (26.3 crashes in
 * RuntimeUtils.<clinit> → UnsatisfiedLinkError). Earlier versions route
 * through GLFWNativeCocoa, also macOS-only.
 *
 * IS_MACOS=false makes every macOS-gated call site take the non-macOS path
 * (verified against 26.2's Window/GlStateManager/GlBackend bytecode), so the
 * weblite/GLFW-Cocoa entry points are never reached. disableCloseWindowMenuItem
 * is guarded by Util.getPlatform() == OSX (true on this port since os.name
 * reports "Mac OS X"), so it still needs a no-op body.
 */
public final class MacosUtil {

    public static final boolean IS_MACOS = false;

    private MacosUtil() {
    }

    public static void disableCloseWindowMenuItem() {
    }
}