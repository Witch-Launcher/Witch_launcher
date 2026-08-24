package net.minecraft.server.packs.resources;

/*
 * COMPILE-ONLY STUB — never packaged into any shipped jar.
 *
 * This directory exists so the iOS shim classes under src/lwjgl (e.g.
 * com.mojang.blaze3d.platform.MacosUtil) can declare method signatures that
 * reference real Minecraft types. javac resolves this type from the classpath
 * (JCFLAGS includes mcstub_sources/) and bakes its NAME into the descriptor,
 * but the compiled stub class is discarded: each per-file compile rule only
 * copies "<basename>*.class" out of the staging dir, and no jar target
 * packages mcstub_sources output.
 *
 * At runtime the descriptor resolves against Minecraft's REAL IoSupplier from
 * the minecraft module, which is all JPMS method linking needs.
 *
 * The real interface in MC 1.20.x is:
 *     public interface IoSupplier<T> { T get() throws IOException; }
 */
public interface IoSupplier<T> {
    T get() throws java.io.IOException;
}
