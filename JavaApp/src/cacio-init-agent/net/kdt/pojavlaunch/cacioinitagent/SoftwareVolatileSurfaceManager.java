package net.kdt.pojavlaunch.cacioinitagent;

import sun.awt.image.SunVolatileImage;
import sun.awt.image.VolatileSurfaceManager;
import sun.java2d.SurfaceData;

/**
 * Software-only volatile surface manager for Caciocavallo.
 *
 * Cacio has no accelerated pipeline, so Swing must fall back to a
 * BufferedImage-backed surface. Used when the Cacio distribution does not
 * ship a SurfaceManagerFactory of its own (cacio 1.18 removed the old
 * CTCSurfaceManagerFactory/CTCVolatileSurfaceManager classes).
 */
public class SoftwareVolatileSurfaceManager extends VolatileSurfaceManager {

    protected SoftwareVolatileSurfaceManager(SunVolatileImage image, Object context) {
        super(image, context);
    }

    @Override
    protected boolean isAccelerationEnabled() {
        return false;
    }

    @Override
    protected SurfaceData initAcceleratedSurface() {
        return null;
    }
}
