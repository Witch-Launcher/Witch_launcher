package net.kdt.pojavlaunch.cacioinitagent;

import java.lang.instrument.Instrumentation;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public class CacioInitAgent {
    private static final String[] CACIO_FACTORIES = {
        "com.github.caciocavallosilano.cacio.ctc.CTCSurfaceManagerFactory",
        "net.java.openjdk.cacio.ctc.CTCSurfaceManagerFactory"
    };

    public static void premain(String args, Instrumentation inst) {
        // On Java 8 the bundled Cacio still provides its own factory and the
        // platform graphics environment does not install one, so this is safe.
        // On Java 17 (cacio 1.18) there is no Cacio factory: installing our
        // fallback this early would race with the platform GraphicsEnvironment,
        // which calls setInstance() during its static init and then fails with
        // "The surface manager factory is already initialized". That JRE is
        // handled by the explicit install() call after CTCPreloadClassLoader.
        if (createCacioFactory() != null) {
            install();
        }
    }

    /**
     * Makes sure sun.java2d.SurfaceManagerFactory has an instance.
     *
     * The JDK only installs one from the X11/Windows GraphicsEnvironment.
     * Caciocavallo replaces those environments, and cacio 1.18 additionally
     * clears the factory on purpose, so Swing's RepaintManager blows up with
     * "No SurfaceManagerFactory set." on every repaint. Use Cacio's own
     * implementation when the runtime ships one, otherwise fall back to the
     * software (BufferedImage) manager below.
     *
     * Must be called again after CTCPreloadClassLoader initializes, because
     * its static initializer resets the factory to null.
     */
    public static synchronized void install() {
        try {
            Class<?> smfClass = Class.forName("sun.java2d.SurfaceManagerFactory");

            if (getInstance(smfClass) != null) {
                return;
            }

            Object factory = createCacioFactory();
            if (factory == null) {
                factory = new SoftwareSurfaceManagerFactory();
            }

            Method setInstance = smfClass.getMethod("setInstance", smfClass);
            setInstance.invoke(null, factory);
            System.err.println("[CacioInitAgent] Installed SurfaceManagerFactory: "
                    + factory.getClass().getName());
        } catch (Throwable t) {
            System.err.println("[CacioInitAgent] Could not install SurfaceManagerFactory: " + t);
        }
    }

    private static Object getInstance(Class<?> smfClass) {
        try {
            return smfClass.getMethod("getInstance").invoke(null);
        } catch (InvocationTargetException e) {
            return null;
        } catch (Throwable t) {
            return null;
        }
    }

    private static Object createCacioFactory() {
        for (String name : CACIO_FACTORIES) {
            try {
                Class<?> factoryClass = Class.forName(name);
                Constructor<?> ctor = factoryClass.getDeclaredConstructor();
                ctor.setAccessible(true);
                return ctor.newInstance();
            } catch (Throwable ignored) {
            }
        }
        return null;
    }
}
