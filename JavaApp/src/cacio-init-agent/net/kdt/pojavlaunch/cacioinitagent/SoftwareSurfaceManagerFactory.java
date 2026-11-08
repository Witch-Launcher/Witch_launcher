package net.kdt.pojavlaunch.cacioinitagent;

import sun.awt.image.SunVolatileImage;
import sun.awt.image.VolatileSurfaceManager;
import sun.java2d.SurfaceManagerFactory;

/**
 * Fallback SurfaceManagerFactory for Caciocavallo on JDK 9+.
 *
 * SunVolatileImage (used by Swing's RepaintManager for double buffering)
 * requires a SurfaceManagerFactory. The X11/Windows graphics environments
 * install one, but Cacio replaces them and the 1.18 fork ships neither the
 * factory nor the volatile-surface manager. Without this, every repaint
 * throws "java.lang.IllegalStateException: No SurfaceManagerFactory set."
 * and Swing windows only ever show their black background.
 */
public class SoftwareSurfaceManagerFactory extends SurfaceManagerFactory {

    @Override
    public VolatileSurfaceManager createVolatileManager(SunVolatileImage image, Object context) {
        return new SoftwareVolatileSurfaceManager(image, context);
    }
}
