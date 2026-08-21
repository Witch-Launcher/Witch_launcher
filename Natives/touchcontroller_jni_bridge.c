/*
 * TouchController iOS Bridge
 * Connects native touch events (from input_bridge_v3.m / SurfaceViewController.m)
 * directly to the shared in-process ring buffer used by the TouchController
 * mod (top.fifthlight.touchcontroller.common.platform.ios.Transport).
 *
 * Touch messages are encoded here in C (matching the mod's ProxyMessage wire
 * format: big-endian [type:4][payload]) and enqueued via
 * touchcontroller_launcher_send() (launcher -> game queue). This deliberately
 * avoids calling Java on the touch path: the game's Knot classloader can load
 * its own copy of net.kdt.pojavlaunch.touchcontroller.TouchControllerManager,
 * and the JNI FindClass() call then resolves to the Knot copy, whose singleton
 * is never initialized -> every touch used to be dropped with index -1.
 *
 * The receive side (mod -> launcher) stays in Java (LauncherProxyClient
 * message loop), which runs on a launcher-classloader thread and works.
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include <dispatch/dispatch.h>

#include "touchcontroller_jni_bridge.h"
#include "touchcontroller_launcher.h"

// Diagnostic logging (disabled): used to write to process stderr, which the
// launcher captures into the JVM log file alongside Java output.
#define TCL_LOG(...) do {} while (0)

// No-op stubs kept for compatibility with callers (JavaLauncher JNI init,
// launcher transport). All touch handling is classloader-free C code now.
void touchcontroller_jni_init(void* vm) { (void)vm; }
void touchcontroller_jni_shutdown(void) {}

// Monotonic pointer index (the mod requires indices to increase from 1).
static int g_nextPointerIndex = 1;

// Big-endian wire encoding helpers (JVM ByteBuffer is big-endian).
static void put_be32(uint8_t* p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24);
    p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);
    p[3] = (uint8_t)v;
}

static void put_be32f(uint8_t* p, float f) {
    uint32_t bits;
    memcpy(&bits, &f, sizeof(bits));
    put_be32(p, bits);
}

// AddPointerMessage: [1:i32][index:i32][x:f32][y:f32] (16 bytes)
static void enqueue_add_pointer(int index, float x, float y) {
    uint8_t msg[16];
    put_be32(msg, 1);
    put_be32(msg + 4, (uint32_t)index);
    put_be32f(msg + 8, x);
    put_be32f(msg + 12, y);
    touchcontroller_launcher_send(msg, (int)sizeof(msg));
}

// RemovePointerMessage: [2:i32][index:i32] (8 bytes)
static void enqueue_remove_pointer(int index) {
    uint8_t msg[8];
    put_be32(msg, 2);
    put_be32(msg + 4, (uint32_t)index);
    touchcontroller_launcher_send(msg, (int)sizeof(msg));
}

// ClearPointerMessage: [3:i32] (4 bytes)
static void enqueue_clear_pointer(void) {
    uint8_t msg[4];
    put_be32(msg, 3);
    touchcontroller_launcher_send(msg, (int)sizeof(msg));
}

// MoveViewMessage: [12:i32][screenBased:u8][deltaPitch:f32][deltaYaw:f32] (13 bytes)
static void enqueue_move_view(float deltaPitch, float deltaYaw) {
    uint8_t msg[13];
    put_be32(msg, 12);
    msg[4] = 1; // screenBased
    put_be32f(msg + 5, deltaPitch);
    put_be32f(msg + 9, deltaYaw);
    touchcontroller_launcher_send(msg, (int)sizeof(msg));
}

// Drain marker table: per-pointer game read position recorded when its
// AddPointerMessage was enqueued (see the pending-remove logic below).
// Pointer indices grow monotonically and never reset, so the table must be
// large enough that a wrap-around collision (which would delay a Remove until
// the hard deadline and can get the Remove dropped when it lands in the same
// drain batch as its Add) is effectively impossible within a session.
#define TC_MARKER_MASK 4095
static size_t g_down_markers[4096];

// Called from SurfaceViewController.m when a touch begins (ACTION_DOWN)
// Returns pointer index assigned to this touch, or -1 on failure
int touchcontroller_onTouchDown(float x, float y) {
    int index = g_nextPointerIndex++;
    size_t marker = touchcontroller_launcher_game_drain_marker();
    enqueue_add_pointer(index, x, y);
    // Remember the game's read position before this Add: the matching Remove
    // is only sent once the mod has drained past it (see pending removes).
    g_down_markers[index & TC_MARKER_MASK] = marker;
    TCL_LOG("onTouchDown x=%.3f y=%.3f -> %d\n", x, y, index);
    return index;
}

// Called from SurfaceViewController.m when a touch moves (ACTION_MOVE)
void touchcontroller_onTouchMove(int index, float x, float y) {
    enqueue_add_pointer(index, x, y);
    TCL_LOG("onTouchMove %d x=%.3f y=%.3f\n", index, x, y);
}

// Pending (drain-aware) remove list.
//
// The mod drains the whole queue once per render frame (RenderEvents). If an
// AddPointer + RemovePointer pair for a quick tap lands in the SAME drain,
// the mod's pointer goes New -> Released(previousState=New) without ever
// pressing a button, so tap-driven buttons (chat, inventory, pause, sneak
// double-click) silently die. Worse, a fixed Remove delay pushes borderline
// taps past the mod's viewHoldDetectTicks (5 client ticks), turning "tap to
// place" into "hold to break".
//
// Instead, the Remove is sent only after the game's dequeue position passes
// the marker recorded when the Add was enqueued: the Add has been drained in
// an earlier frame, so the Remove is drained ~1 frame later. A hard deadline
// bounds the wait when the game stops rendering (messages stockpile then).
#define TC_MAX_PENDING 32

typedef struct {
    int index;
    size_t marker;
    dispatch_time_t deadline;
} pending_remove_t;

static pending_remove_t g_pending[TC_MAX_PENDING];
static int g_pending_count = 0;
static bool g_poller_active = false;

// Sends removes whose Add has been drained by the mod (or whose deadline
// passed). Reschedules itself every 5ms while pending entries remain.
// All state is only touched on the main queue/thread.
static void poll_pending_removes(void) {
    dispatch_time_t now = dispatch_time(DISPATCH_TIME_NOW, 0);
    int kept = 0;
    for (int i = 0; i < g_pending_count; i++) {
        if (touchcontroller_launcher_game_drained_past(g_pending[i].marker) || now > g_pending[i].deadline) {
            enqueue_remove_pointer(g_pending[i].index);
            TCL_LOG("onTouchUpDelayed %d\n", g_pending[i].index);
        } else {
            g_pending[kept++] = g_pending[i];
        }
    }
    g_pending_count = kept;
    if (g_pending_count == 0) {
        g_poller_active = false;
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            poll_pending_removes();
        });
    }
}

static void ensure_poller(void) {
    if (g_pending_count == 0 || g_poller_active) return;
    g_poller_active = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        poll_pending_removes();
    });
}

// Called from SurfaceViewController.m when a touch ends (ACTION_UP)
void touchcontroller_onTouchUp(int index) {
    if (g_pending_count < TC_MAX_PENDING) {
        g_pending[g_pending_count].index = index;
        g_pending[g_pending_count].marker = g_down_markers[index & TC_MARKER_MASK];
        g_pending[g_pending_count].deadline = dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC);
        g_pending_count++;
        ensure_poller();
    } else {
        enqueue_remove_pointer(index);
    }
    TCL_LOG("onTouchUp %d\n", index);
}

// Called from SurfaceViewController.m when all touches are cancelled
void touchcontroller_onTouchCancel(void) {
    for (int i = 0; i < g_pending_count; i++) {
        enqueue_remove_pointer(g_pending[i].index);
    }
    g_pending_count = 0;
    g_poller_active = false;
    enqueue_clear_pointer();
    TCL_LOG("onTouchCancel\n");
}

// Called for view movement (camera rotation via drag)
void touchcontroller_onViewMove(float deltaPitch, float deltaYaw) {
    enqueue_move_view(deltaPitch, deltaYaw);
    TCL_LOG("onViewMove pitch=%.3f yaw=%.3f\n", deltaPitch, deltaYaw);
}
