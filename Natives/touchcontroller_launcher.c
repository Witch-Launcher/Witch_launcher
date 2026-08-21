/*
 * TouchController iOS Launcher JNI Bridge
 *
 * Provides a shared in-process ring-buffer queue used by BOTH sides:
 *   - launcher-side transport: net.kdt.pojavlaunch.touchcontroller.IosSocketTransport
 *   - game-side transport:     top.fifthlight.touchcontroller.common.platform.ios.Transport
 *
 * The game and the launcher run in the same JVM process, so both JNI sets
 * operate on the same queue. Message framing is RAW message bytes
 * ([type:4][payload]) with no length prefix, matching the mod's
 * proxy/server/ios/ios.c semantics. Queue initialization happens lazily
 * (first use from either side), so the launcher may initialize before the
 * mod and vice versa.
 */

#include <jni.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "touchcontroller_launcher.h"
#include "touchcontroller_jni_bridge.h"

// ===== Ring buffer (same semantics as the mod's ring_buffer.c) =====

typedef struct ring_buffer {
    void** queue;
    size_t capacity;
    size_t head;
    size_t tail;
} ring_buffer_t;

static ring_buffer_t* ring_buffer_alloc(size_t capacity) {
    if (capacity == 0) return NULL;
    ring_buffer_t* buf = malloc(sizeof(ring_buffer_t));
    if (buf == NULL) return NULL;
    buf->queue = calloc(capacity, sizeof(void*));
    if (buf->queue == NULL) {
        free(buf);
        return NULL;
    }
    buf->capacity = capacity;
    buf->head = 0;
    buf->tail = 0;
    return buf;
}

static void ring_buffer_free(ring_buffer_t* buf) {
    if (buf) {
        free(buf->queue);
        free(buf);
    }
}

static int ring_buffer_enqueue(ring_buffer_t* buf, void* data) {
    size_t used = (buf->tail >= buf->head) ? (buf->tail - buf->head) : (buf->capacity - (buf->head - buf->tail));
    size_t remaining = (buf->capacity - 1) - used;
    if (remaining == 0) {
        if (buf->capacity >= SIZE_MAX / 2) return -1;
        size_t new_capacity = buf->capacity * 2;
        void** new_queue = realloc(buf->queue, new_capacity * sizeof(void*));
        if (!new_queue) return -1;
        buf->queue = new_queue;
        if (buf->tail < buf->head) {
            size_t head_section_size = buf->capacity - buf->head;
            size_t new_head_pos = new_capacity - head_section_size;
            memmove(&buf->queue[new_head_pos], &buf->queue[buf->head], head_section_size * sizeof(void*));
            buf->head = new_head_pos;
        }
        buf->capacity = new_capacity;
    }
    buf->queue[buf->tail++] = data;
    buf->tail = buf->tail % buf->capacity;
    return 0;
}

static void* ring_buffer_dequeue(ring_buffer_t* buf) {
    if (buf->head == buf->tail) return NULL;
    void* data = buf->queue[buf->head++];
    buf->head = buf->head % buf->capacity;
    return data;
}

// ===== Message queue =====

#define MAX_MESSAGE_SIZE 255

typedef struct message {
    size_t size;
    void* data;
} message_t;

typedef struct queue {
    ring_buffer_t* launcher_to_game; // launcher send -> game receive
    ring_buffer_t* game_to_launcher; // game send -> launcher receive
    pthread_mutex_t launcher_to_game_mutex;
    pthread_mutex_t game_to_launcher_mutex;
} queue_t;

static queue_t* g_queue = NULL;
static pthread_mutex_t g_queue_mutex = PTHREAD_MUTEX_INITIALIZER;

static queue_t* ensure_queue(void) {
    if (g_queue != NULL) return g_queue;

    pthread_mutex_lock(&g_queue_mutex);
    if (g_queue == NULL) {
        queue_t* queue = calloc(1, sizeof(queue_t));
        if (queue != NULL) {
            queue->launcher_to_game = ring_buffer_alloc(4 * 1024);
            queue->game_to_launcher = ring_buffer_alloc(4 * 1024);
            if (queue->launcher_to_game == NULL || queue->game_to_launcher == NULL) {
                ring_buffer_free(queue->launcher_to_game);
                ring_buffer_free(queue->game_to_launcher);
                free(queue);
            } else {
                pthread_mutex_init(&queue->launcher_to_game_mutex, NULL);
                pthread_mutex_init(&queue->game_to_launcher_mutex, NULL);
                g_queue = queue;
            }
        }
    }
    pthread_mutex_unlock(&g_queue_mutex);
    return g_queue;
}

static void throw_exception(JNIEnv* env, const char* msg) {
    (*env)->ThrowNew(env, (*env)->FindClass(env, "java/lang/Exception"), msg);
}

static int enqueue_message(ring_buffer_t* buffer, pthread_mutex_t* mutex, const void* data, size_t len) {
    if (len <= 0 || len > MAX_MESSAGE_SIZE) return -1;

    message_t* msg = malloc(sizeof(message_t));
    if (msg == NULL) return -1;
    msg->size = len;
    msg->data = malloc(len);
    if (msg->data == NULL) {
        free(msg);
        return -1;
    }
    memcpy(msg->data, data, len);

    pthread_mutex_lock(mutex);
    int ret = ring_buffer_enqueue(buffer, msg);
    pthread_mutex_unlock(mutex);
    if (ret != 0) {
        free(msg->data);
        free(msg);
    }
    return ret;
}

static int dequeue_message(ring_buffer_t* buffer, pthread_mutex_t* mutex, void* out, size_t max_len) {
    pthread_mutex_lock(mutex);
    message_t* msg = ring_buffer_dequeue(buffer);
    pthread_mutex_unlock(mutex);
    if (msg == NULL) return 0;

    size_t len = msg->size;
    if (len > max_len) len = max_len;
    memcpy(out, msg->data, len);
    size_t full_len = msg->size;
    free(msg->data);
    free(msg);
    return (int)full_len;
}

// ===== JNI: launcher-side transport (IosSocketTransport) =====

JNIEXPORT jlong JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosSocketTransport_nativeInit(JNIEnv* env, jclass clazz) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) {
        throw_exception(env, "Failed to initialize iOS transport queue");
        return 0;
    }

    // The mod (0.3.1-alpha13+) only activates its iOS platform when
    // TOUCH_CONTROLLER_PROXY_SOCKET is set. The value is not used as a real
    // socket path: the transport is an in-process ring buffer, so any
    // non-empty value unlocks the mod's IosPlatform.
    setenv("TOUCH_CONTROLLER_PROXY_SOCKET", "inproc:touchcontroller", 1);

    // Attach the JNI bridge refs here: the launcher classloader is active at
    // this point, so FindClass for TouchControllerManager resolves correctly.
    JavaVM* vm = NULL;
    if ((*env)->GetJavaVM(env, &vm) == JNI_OK) {
        touchcontroller_jni_init(vm);
    }

    return (jlong)queue;
}

JNIEXPORT void JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosSocketTransport_nativeSend(JNIEnv* env, jclass clazz, jlong handlePtr, jbyteArray buffer, jint offset, jint length) {
    queue_t* queue = ensure_queue();
    if (queue == NULL || length <= 0) return;

    if (length > MAX_MESSAGE_SIZE) {
        throw_exception(env, "Message too big");
        return;
    }

    jbyte* data = (*env)->GetByteArrayElements(env, buffer, NULL);
    if (data == NULL) return;
    enqueue_message(queue->launcher_to_game, &queue->launcher_to_game_mutex, data + offset, length);
    (*env)->ReleaseByteArrayElements(env, buffer, data, JNI_ABORT);
}

JNIEXPORT jint JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosSocketTransport_nativeReceive(JNIEnv* env, jclass clazz, jlong handlePtr, jbyteArray buffer) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return -1;

    jsize arrayLen = (*env)->GetArrayLength(env, buffer);
    jbyte* data = (*env)->GetByteArrayElements(env, buffer, NULL);
    if (data == NULL) return -1;

    int result = dequeue_message(queue->game_to_launcher, &queue->game_to_launcher_mutex, data, arrayLen);
    (*env)->ReleaseByteArrayElements(env, buffer, data, 0);
    return result;
}

JNIEXPORT void JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosSocketTransport_nativeClose(JNIEnv* env, jclass clazz, jlong handlePtr) {
    // The queue is shared with the game-side transport; keep it alive.
}

// ===== JNI: game-side transport (top.fifthlight...ios.Transport) =====
//
// NOTE: these stubs live in the main executable (touchcontroller_game_bridge.c),
// NOT in this dylib: the game runs in the Knot classloader and resolves them
// against AngelAuraAmethyst, which only Knot System.load()s. If they were
// here, the launcher's System.load() of this dylib would register them with
// the launcher classloader and the game would fail to resolve them.

// ===== JNI: vibration & keyboard (unchanged) =====

int touchcontroller_queue_ensure(void) {
    return ensure_queue() != NULL ? 0 : -1;
}

// Game-side transport: the mod runs in the Knot classloader, so these
// functions are called from the game bridge stubs in the executable.
//   - game SEND (Transport.send) -> launcher receives it (game_to_launcher)
//   - game RECEIVE (Transport.receive) -> launcher sent it (launcher_to_game)
int touchcontroller_ios_send(const void* buf, int len) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return -1;
    return enqueue_message(queue->game_to_launcher, &queue->game_to_launcher_mutex, buf, len);
}

// Launcher -> game (read by the mod's Transport.receive). Used by the C touch
// path (touchcontroller_jni_bridge.c), which bypasses Java entirely.
int touchcontroller_launcher_send(const void* buf, int len) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return -1;
    return enqueue_message(queue->launcher_to_game, &queue->launcher_to_game_mutex, buf, len);
}

// Drain tracking: the mod's receive drains the whole launcher_to_game queue
// once per render frame. The C touch path records a marker (the game's read
// position) before enqueueing an AddPointerMessage, then delays the matching
// RemovePointerMessage until the mod has drained past that marker. This keeps
// Add+Remove out of the same drain batch (which would silently drop quick
// taps) while keeping release latency to ~1 render frame.
size_t touchcontroller_launcher_game_drain_marker(void) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return 0;
    pthread_mutex_lock(&queue->launcher_to_game_mutex);
    size_t head = queue->launcher_to_game->head;
    pthread_mutex_unlock(&queue->launcher_to_game_mutex);
    return head;
}

// Non-zero once the game's dequeue position has advanced past the given
// marker (i.e. every message enqueued after it has been consumed).
int touchcontroller_launcher_game_drained_past(size_t marker) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return 1;
    pthread_mutex_lock(&queue->launcher_to_game_mutex);
    int drained = queue->launcher_to_game->head != marker;
    pthread_mutex_unlock(&queue->launcher_to_game_mutex);
    return drained;
}

// Non-zero once the game-side transport has drained at least one message from
// the launcher_to_game queue. That proves the mod's Transport.receive loop is
// live, so the mod owns pointer/view handling and the launcher must stop
// injecting raw MoveView messages (which cannot know the mod's layout and
// would rotate the camera while dragging the mod's joystick/buttons).
int touchcontroller_launcher_mod_active(void) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return 0;
    pthread_mutex_lock(&queue->launcher_to_game_mutex);
    int active = queue->launcher_to_game->head != 0;
    pthread_mutex_unlock(&queue->launcher_to_game_mutex);
    return active;
}

int touchcontroller_ios_receive(void* buf, size_t max_len) {
    queue_t* queue = ensure_queue();
    if (queue == NULL) return -1;
    return dequeue_message(queue->launcher_to_game, &queue->launcher_to_game_mutex, buf, max_len);
}

// ===== JNI: vibration & keyboard (unchanged) =====

JNIEXPORT void JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosVibrationHandler_nativeVibrate(JNIEnv* env, jobject obj, jint type) {
    touchcontroller_vibrate(type);
}

JNIEXPORT void JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosKeyboardShowHandler_nativeShowKeyboard(JNIEnv* env, jclass clazz) {
    touchcontroller_showKeyboard();
}

JNIEXPORT void JNICALL
Java_net_kdt_pojavlaunch_touchcontroller_IosKeyboardShowHandler_nativeHideKeyboard(JNIEnv* env, jclass clazz) {
    touchcontroller_hideKeyboard();
}