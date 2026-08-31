package net.vda.witchlaunch.framegen;

/**
 * Frame Generation test harness.
 *
 * Tests the JNI bridge and native module without requiring Minecraft.
 * Run on-device to verify FG support and basic camera data flow.
 *
 * Usage: java -cp launcher.jar net.vda.witchlaunch.framegen.FrameGenTest
 */
public class FrameGenTest {
    public static void main(String[] args) {
        System.out.println("=== FrameGen Test ===");
        boolean allPassed = true;

        // Test 1: Check if native library is already loaded (by launcher)
        System.out.println("Test 1: Checking native library availability...");
        try {
            // Native methods follow JNI naming convention.
            // They are resolved automatically when libWitch.dylib is loaded.
            FrameGenBridge.isSupported();
            System.out.println("  [PASS] Native library loaded and methods resolved");
        } catch (UnsatisfiedLinkError e) {
            System.err.println("  [FAIL] Native library not loaded: " + e.getMessage());
            System.err.println("  (Expected if running outside Witch launcher)");
            allPassed = false;
        }

        // Test 2: Check if FG is supported
        System.out.println("Test 2: Checking FG support...");
        try {
            boolean supported = FrameGenBridge.isSupported();
            System.out.println("  FG Supported: " + supported);
            if (!supported) {
                System.out.println("  (Expected on non-Metal devices or simulators)");
            }
        } catch (UnsatisfiedLinkError e) {
            System.err.println("  [SKIP] Cannot check support (natives not loaded)");
            allPassed = false;
        }

        // Test 3: Enable FG
        System.out.println("Test 3: Enabling FG...");
        try {
            FrameGenBridge.setEnabled(true);
            boolean enabled = FrameGenBridge.isEnabled();
            System.out.println("  FG Enabled: " + enabled);
        } catch (UnsatisfiedLinkError e) {
            System.err.println("  [SKIP] Cannot enable (natives not loaded)");
            allPassed = false;
        }

        // Test 4: Call updateCamera with dummy data
        System.out.println("Test 4: Calling updateCamera with test data...");
        try {
            float[] viewMatrix = new float[16];
            float[] projMatrix = new float[16];
            // Identity matrices
            viewMatrix[0] = viewMatrix[5] = viewMatrix[10] = viewMatrix[15] = 1.0f;
            projMatrix[0] = projMatrix[5] = projMatrix[10] = projMatrix[15] = 1.0f;

            FrameGenBridge.updateCamera(
                0.0f, 64.0f, 0.0f,  // pos
                0.0f, 0.0f,         // pitch, yaw
                viewMatrix, projMatrix,
                70.0f,              // fov
                1920, 1080          // width, height
            );
            System.out.println("  [PASS] updateCamera called successfully");
        } catch (UnsatisfiedLinkError e) {
            System.err.println("  [SKIP] Cannot update camera (natives not loaded)");
            allPassed = false;
        }

        // Test 5: Disable FG
        System.out.println("Test 5: Disabling FG...");
        try {
            FrameGenBridge.setEnabled(false);
            boolean enabled = FrameGenBridge.isEnabled();
            System.out.println("  FG Enabled after disable: " + enabled);
        } catch (UnsatisfiedLinkError e) {
            System.err.println("  [SKIP] Cannot disable (natives not loaded)");
            allPassed = false;
        }

        System.out.println("=== " + (allPassed ? "All Tests Passed" : "Some Tests Skipped/Failed") + " ===");
    }
}
