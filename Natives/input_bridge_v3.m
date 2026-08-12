/*
 * V3 input bridge implementation.
 *
 * Status:
 * - Active development
 * - Works with some bugs:
 *  + Modded versions gives broken stuff..
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "SurfaceViewController.h"

#include <assert.h>
#include <dlfcn.h>
#include <libgen.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <string.h>

#include "jni.h"
#include "glfw_keycodes.h"
#include "ios_uikit_bridge.h"
#include "utils.h"

#include "JavaLauncher.h"
#include "touchcontroller_jni_bridge.h"

jint (*orig_ProcessImpl_forkAndExec)(JNIEnv *env, jobject process, jint mode, jbyteArray helperpath, jbyteArray prog, jbyteArray argBlock, jint argc, jbyteArray envBlock, jint envc, jbyteArray dir, jintArray std_fds, jboolean redirectErrorStream);
jlong (*orig_ProcessHandleImpl_isAlive0)(JNIEnv *env, jclass clazz, jlong jpid);

NSString* processPath(NSString* path) {
    if ([path hasPrefix:@"file:"]) {
        path = [path substringFromIndex:5].stringByRemovingPercentEncoding;
    }
    path = path.stringByResolvingSymlinksInPath;

    NSString *prefix = @"file";
    if ([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"shareddocuments://"]] &&
      ![path hasPrefix:@"/var/mobile/Documents"]) {
        // Prefer opening in Files if containerized
        prefix = @"shareddocuments";
    } else if ([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"filza://"]]) {
        // Open in Filza if installed
        prefix = @"filza";
    } else if ([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"santander://"]]) {
        // Open in Santander if installed
        prefix = @"santander";
    }

    return [NSString stringWithFormat:@"%@://%@", prefix, path];
}

void openURLGlobal(NSString *path) {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([path hasPrefix:@"http"]) {
            openLink(UIWindow.mainWindow.rootViewController, [NSURL URLWithString:path]);
            dispatch_group_leave(group);
            return;
        }
        NSString *realPath = processPath(path);
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:realPath] options:@{} completionHandler:^(BOOL success) {
            if (success) {
                NSLog(@"Opened \"%@\"", realPath);
            } else {
                NSLog(@"Failed to open \"%@\"", realPath);
            }
            dispatch_group_leave(group);
        }];
    });

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

/**
 * Hooked version of java.lang.UNIXProcess.forkAndExec()
 * which is used to handle the "open" command.
 */
jint
hooked_ProcessImpl_forkAndExec(JNIEnv *env, jobject process, jint mode, jbyteArray helperpath, jbyteArray prog, jbyteArray argBlock, jint argc, jbyteArray envBlock, jint envc, jbyteArray dir, jintArray std_fds, jboolean redirectErrorStream) {
    char *pProg = (char *)((*env)->GetByteArrayElements(env, prog, NULL));

    // Here we only handle the "open" command
    if (strcmp(basename(pProg), "open")) {
        (*env)->ReleaseByteArrayElements(env, prog, (jbyte *)pProg, 0);
        return orig_ProcessImpl_forkAndExec(env, process, mode, helperpath, prog, argBlock, argc, envBlock, envc, dir, std_fds, redirectErrorStream);
    }

    char *path = (char *)((*env)->GetByteArrayElements(env, argBlock, NULL));
    openURLGlobal(@(path));

    (*env)->ReleaseByteArrayElements(env, prog, (jbyte *)pProg, 0);
    (*env)->ReleaseByteArrayElements(env, argBlock, (jbyte *)path, 0);
    return 0;
}

/**
 * Hooked version of java.lang.ProcessHandleImpl.isAlive0()
 * which is used to ignore "Operation not permitted"
 */
jlong hooked_ProcessHandleImpl_isAlive0(JNIEnv *env, jclass clazz, jlong jpid) {
    jlong result = orig_ProcessHandleImpl_isAlive0(env, clazz, jpid);
    if ((*env)->ExceptionOccurred(env)) {
        (*env)->ExceptionClear(env);
    }
    return result;
}

// Part of awt_bridge
void CTCClipboard_nQuerySystemClipboard(JNIEnv *env, jclass clazz) {
    if(method_SystemClipboardDataReceived == NULL) {
        class_CTCClipboard = (*env)->NewGlobalRef(env, clazz);
        method_SystemClipboardDataReceived = (*env)->GetStaticMethodID(env, clazz, "systemClipboardDataReceived", "(Ljava/lang/String;Ljava/lang/String;)V");
    }
    // From Java_net_kdt_pojavlaunch_AWTInputBridge_nativeClipboardReceived
    // Note: we cannot use main_queue here as it will cause deadlock
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        JNIEnv *env;
        // Daemon attach: GCD worker threads live forever, so a non-daemon
        // attach here would keep the JVM from exiting after the game stops.
        (*runtimeJavaVMPtr)->AttachCurrentThreadAsDaemon(runtimeJavaVMPtr, &env, NULL);
        const char* mimeChars = "text/plain";
        (*env)->CallStaticVoidMethod(env, class_CTCClipboard, method_SystemClipboardDataReceived,
            UIKit_accessClipboard(env, CLIPBOARD_PASTE, NULL),
            (*env)->NewStringUTF(env, mimeChars));
        (*runtimeJavaVMPtr)->DetachCurrentThread(runtimeJavaVMPtr);
    });
}

void CTCClipboard_nPutClipboardData(JNIEnv* env, jclass clazz, jstring clipboardData, jstring clipboardDataMime) {
    // TODO: handle non-text data(?)
    UIKit_accessClipboard(env, CLIPBOARD_COPY, clipboardData);
}

void CTCDesktopPeer_openGlobal(JNIEnv *env, jclass clazz, jstring path) {
    const char* stringChars = (*env)->GetStringUTFChars(env, path, NULL);
    openURLGlobal(@(stringChars));
    (*env)->ReleaseStringUTFChars(env, path, stringChars);
}

void hackFix18LWJGL(void *addr) {
    addr = (void *)((uintptr_t)addr & ~PAGE_MASK);
    if(DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED)) return;
    if(!mprotect(addr, PAGE_SIZE, PROT_READ | PROT_EXEC)) return;
    // FIXME: For some reason the one page in liblwjgl.dylib is mapped as r-x/rwx (COW), and recent builds on iOS 18 switches it to r--/rw- causing codesign failure. Here we hack it to map anon page to get r-x back
    char tempPage[PAGE_SIZE];
    memcpy(tempPage, addr, PAGE_SIZE);
    void *result = mmap(addr, PAGE_SIZE, PROT_READ | PROT_WRITE, MAP_FIXED | MAP_PRIVATE | MAP_ANON, -1, 0);
    if (result == MAP_FAILED) {
        NSLog(@"hackFix18LWJGL: mmap failed: %s", strerror(errno));
        return;
    }
    memcpy(addr, tempPage, PAGE_SIZE);
    mprotect(addr, PAGE_SIZE, PROT_READ | PROT_EXEC);
}

void registerOpenHandler(JNIEnv *env) {
    jclass cls;

    // Hook forkAndExec
    orig_ProcessImpl_forkAndExec = dlsym(RTLD_DEFAULT, "Java_java_lang_UNIXProcess_forkAndExec");
    if (!orig_ProcessImpl_forkAndExec) {
        orig_ProcessImpl_forkAndExec = dlsym(RTLD_DEFAULT, "Java_java_lang_ProcessImpl_forkAndExec");
        cls = (*env)->FindClass(env, "java/lang/ProcessImpl");
    } else {
        cls = (*env)->FindClass(env, "java/lang/UNIXProcess");
    }
    JNINativeMethod forkAndExecMethod[] = {
        {"forkAndExec", "(I[B[B[BI[BI[B[IZ)I", (void *)&hooked_ProcessImpl_forkAndExec}
    };
    (*env)->RegisterNatives(env, cls, forkAndExecMethod, 1);

    // (Java 17 only) Hook isAlive0
    cls = (*env)->FindClass(env, "java/lang/ProcessHandleImpl");
    if ((*env)->ExceptionOccurred(env)) {
        // Java 8
        (*env)->ExceptionClear(env);
    } else {
        orig_ProcessHandleImpl_isAlive0 = dlsym(RTLD_DEFAULT, "Java_java_lang_ProcessHandleImpl_isAlive0");
        JNINativeMethod isAlive0Method[] = {
            {"isAlive0", "(J)J", (void *)&hooked_ProcessHandleImpl_isAlive0}
        };
        (*env)->RegisterNatives(env, cls, isAlive0Method, 1);
    }

    // Register CTCClipboard natives
    cls = (*env)->FindClass(env, "net/java/openjdk/cacio/ctc/CTCClipboard");
    if ((*env)->ExceptionOccurred(env)) {
        // Java 17
        (*env)->ExceptionClear(env);
        cls = (*env)->FindClass(env, "com/github/caciocavallosilano/cacio/ctc/CTCClipboard");
    }
    JNINativeMethod clipboardMethods[] = {
        {"nQuerySystemClipboard", "()V", (void *)&CTCClipboard_nQuerySystemClipboard},
        {"nPutClipboardData", "(Ljava/lang/String;Ljava/lang/String;)V", (void *)&CTCClipboard_nPutClipboardData}
    };
    (*env)->RegisterNatives(env, cls, clipboardMethods, 2);

    // Register CTCDesktopPeer natives
    cls = (*env)->FindClass(env, "net/java/openjdk/cacio/ctc/CTCDesktopPeer");
    if ((*env)->ExceptionOccurred(env)) {
        // Java 17, not available
        //(*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        return;
    }
    JNINativeMethod peerOpenMethods[] = {
        {"openFile", "(Ljava/lang/String;)V", (void *)&CTCDesktopPeer_openGlobal},
        {"openUri", "(Ljava/lang/String;)V", (void *)&CTCDesktopPeer_openGlobal}
    };
    (*env)->RegisterNatives(env, cls, peerOpenMethods, 2);
}

// JNI_OnLoad
void JNI_OnLoadGLFW() {
    jclass glfwClass = (*runtimeJNIEnvPtr)->FindClass(runtimeJNIEnvPtr, "org/lwjgl/glfw/GLFW");
    if (glfwClass == NULL) {
        if ((*runtimeJNIEnvPtr)->ExceptionCheck(runtimeJNIEnvPtr)) {
            (*runtimeJNIEnvPtr)->ExceptionClear(runtimeJNIEnvPtr);
        }
        return;
    }
    vmGlfwClass = (*runtimeJNIEnvPtr)->NewGlobalRef(runtimeJNIEnvPtr, glfwClass);
    method_internalWindowSizeChanged = (*runtimeJNIEnvPtr)->GetStaticMethodID(runtimeJNIEnvPtr, vmGlfwClass, "internalWindowSizeChanged", "(JII)V");
    if (method_internalWindowSizeChanged == NULL) {
        if ((*runtimeJNIEnvPtr)->ExceptionCheck(runtimeJNIEnvPtr)) {
            (*runtimeJNIEnvPtr)->ExceptionClear(runtimeJNIEnvPtr);
        }
    }
    jfieldID field_keyDownBuffer = (*runtimeJNIEnvPtr)->GetStaticFieldID(runtimeJNIEnvPtr, vmGlfwClass, "keyDownBuffer", "Ljava/nio/ByteBuffer;");
    if (field_keyDownBuffer == NULL) {
        if ((*runtimeJNIEnvPtr)->ExceptionCheck(runtimeJNIEnvPtr)) {
            (*runtimeJNIEnvPtr)->ExceptionClear(runtimeJNIEnvPtr);
        }
        return;
    }
    jobject keyDownBufferJ = (*runtimeJNIEnvPtr)->GetStaticObjectField(runtimeJNIEnvPtr, vmGlfwClass, field_keyDownBuffer);
    keyDownBuffer = (*runtimeJNIEnvPtr)->GetDirectBufferAddress(runtimeJNIEnvPtr, keyDownBufferJ);
}

jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    runtimeJavaVMPtr = vm;

    JNIEnv *env;
    (*runtimeJavaVMPtr)->GetEnv(runtimeJavaVMPtr, (void **)&env, JNI_VERSION_1_4);
    registerOpenHandler(env);
    if (!getenv("POJAV_SKIP_JNI_GLFW")) {
        runtimeJNIEnvPtr = env;
        JNI_OnLoadGLFW();
    }
    // Best-effort early init; refs are re-resolved lazily on first touch event
    // (see touchcontroller_jni_bridge.c), so this may safely fail if the
    // launcher classes are not loaded yet.
    touchcontroller_jni_init(vm);

    return JNI_VERSION_1_4;
}

// Should be?
void JNI_OnUnload(JavaVM* vm, void* reserved) {
    runtimeJNIEnvPtr = NULL;
}

#define ADD_CALLBACK_WWIN(NAME) \
JNIEXPORT jlong JNICALL Java_org_lwjgl_glfw_GLFW_nglfwSet##NAME##Callback(JNIEnv * env, jclass cls, jlong window, jlong callbackptr) { \
    void** oldCallback = (void**) &GLFW_invoke_##NAME; \
    GLFW_invoke_##NAME = (GLFW_invoke_##NAME##_func*) (uintptr_t) callbackptr; \
    if (showingWindow == 0 && window != 0) { \
        showingWindow = (long) window; \
    } \
    return (jlong) (uintptr_t) *oldCallback; \
}

ADD_CALLBACK_WWIN(Char)
ADD_CALLBACK_WWIN(CharMods)
ADD_CALLBACK_WWIN(CursorEnter)
ADD_CALLBACK_WWIN(CursorPos)
ADD_CALLBACK_WWIN(FramebufferSize)
ADD_CALLBACK_WWIN(Key)
ADD_CALLBACK_WWIN(MouseButton)
ADD_CALLBACK_WWIN(Scroll)
ADD_CALLBACK_WWIN(WindowPos)
ADD_CALLBACK_WWIN(WindowSize)

#undef ADD_CALLBACK_WWIN

void handleFramebufferSizeJava(void* window, int w, int h) {
    if(GLFW_invoke_CursorEnter)GLFW_invoke_CursorEnter(window, 1);
    if(GLFW_invoke_WindowPos)GLFW_invoke_WindowPos(window, 0, 0);
    if (vmGlfwClass != NULL && method_internalWindowSizeChanged != NULL) {
        (*runtimeJNIEnvPtr)->CallStaticVoidMethod(runtimeJNIEnvPtr, vmGlfwClass, method_internalWindowSizeChanged, (long)window, w, h);
    }
}

void pojavPumpEvents(void* window) {
    static BOOL setInputReady = NO;
    if (window && showingWindow == 0) {
        showingWindow = (long) window;
    }
    if(!setInputReady) {
        setInputReady = YES;
        CallbackBridge_nativeSetInputReady(YES);
    }
    //__android_log_print(ANDROID_LOG_INFO, "input_bridge_v3", "pojavPumpevents %d", eventCounter);
    size_t counter = atomic_load_explicit(&eventCounter, memory_order_acquire);
    if((cLastX != cursorX || cLastY != cursorY) && GLFW_invoke_CursorPos) {
        cLastX = cursorX;
        cLastY = cursorY;
        if (isUseStackQueueCall)
            GLFW_invoke_CursorPos(window, cursorX, cursorY);
    }
    for(size_t i = 0; i < counter; i++) {
        GLFWInputEvent event = events[i];
        switch(event.type) {
            case EVENT_TYPE_CHAR:
                if(GLFW_invoke_Char) GLFW_invoke_Char(window, event.i1);
                break;
            case EVENT_TYPE_CHAR_MODS:
                if(GLFW_invoke_CharMods) {
                    GLFW_invoke_CharMods(window, event.i1, event.i2);
                } else if (GLFW_invoke_Char) {
                    GLFW_invoke_Char(window, event.i1);
                }
                break;
            case EVENT_TYPE_KEY:
                if(GLFW_invoke_Key) GLFW_invoke_Key(window, event.i1, event.i2, event.i3, event.i4);
                break;
            case EVENT_TYPE_MOUSE_BUTTON:
                if(GLFW_invoke_MouseButton) GLFW_invoke_MouseButton(window, event.i1, event.i2, event.i3);
                break;
            case EVENT_TYPE_SCROLL:
                if(GLFW_invoke_Scroll) GLFW_invoke_Scroll(window, event.f1, event.f2);
                break;
            case EVENT_TYPE_FRAMEBUFFER_SIZE:
                handleFramebufferSizeJava(window, event.i1, event.i2);
                if(GLFW_invoke_FramebufferSize) GLFW_invoke_FramebufferSize(window, event.i1, event.i2);
                break;
            case EVENT_TYPE_WINDOW_SIZE:
                handleFramebufferSizeJava(window, event.i1, event.i2);
                if(GLFW_invoke_WindowSize) GLFW_invoke_WindowSize(window, event.i1, event.i2);
                break;
        }
    }
    atomic_store_explicit(&eventCounter, counter, memory_order_release);
}
void pojavRewindEvents() {
    atomic_store_explicit(&eventCounter, 0, memory_order_release);
}

JNIEXPORT void JNICALL
Java_org_lwjgl_glfw_GLFW_nglfwGetCursorPos(JNIEnv *env, jclass clazz, jlong window, jobject xpos,
                                          jobject ypos) {
    *(double*)(*env)->GetDirectBufferAddress(env, xpos) = cursorX;
    *(double*)(*env)->GetDirectBufferAddress(env, ypos) = cursorY;
}

JNIEXPORT void JNICALL
Java_org_lwjgl_glfw_GLFW_nglfwGetCursorPosA(JNIEnv *env, jclass clazz, jlong window,
                                            jdoubleArray xpos, jdoubleArray ypos) {
    (*env)->SetDoubleArrayRegion(env, xpos, 0,1, &cursorX);
    (*env)->SetDoubleArrayRegion(env, ypos, 0,1, &cursorY);
}

JNIEXPORT void JNICALL
Java_org_lwjgl_glfw_GLFW_glfwSetCursorPos(JNIEnv *env, jclass clazz, jlong window, jdouble xpos,
                                          jdouble ypos) {
    cLastX = cursorX = xpos;
    cLastY = cursorY = ypos;
}

void sendData(short type, int i1, int i2, short i3, short i4) {
    size_t counter = atomic_load_explicit(&eventCounter, memory_order_acquire);
    if (counter < 7999) {
        GLFWInputEvent *event = &events[counter++];
        event->type = type;
        event->i1 = i1;
        event->i2 = i2;
        event->i3 = i3;
        event->i4 = i4;
    }
    atomic_store_explicit(&eventCounter, counter, memory_order_release);
}

void sendDataFloat(short type, float i1, float i2, short i3, short i4) {
    size_t counter = atomic_load_explicit(&eventCounter, memory_order_acquire);
    if (counter < 7999) {
        GLFWInputEvent *event = &events[counter++];
        event->type = type;
        event->f1 = i1;
        event->f2 = i2;
        event->i3 = i3;
        event->i4 = i4;
    }
    atomic_store_explicit(&eventCounter, counter, memory_order_release);
}

void closeGLFWWindow() {
    NSLog(@"Closing GLFW window");

    /*
    jclass glfwClazz = (*runtimeJNIEnvPtr)->FindClass(runtimeJNIEnvPtr, "org/lwjgl/glfw/GLFW");
    assert(glfwClazz != NULL);
    jmethodID glfwMethod = (*runtimeJNIEnvPtr)->GetStaticMethodID(runtimeJNIEnvPtr, glfwMethod, "glfwSetWindowShouldClose", "(JZ)V");
    assert(glfwMethod != NULL);
    
    (*runtimeJNIEnvPtr)->CallStaticVoidMethod(
        runtimeJNIEnvPtr,
        glfwClazz, glfwMethod,
        (jlong) showingWindow, JNI_TRUE
    );
    */
    exit(-1);
}

const int hotbarKeys[9] = {
    GLFW_KEY_1, GLFW_KEY_2, GLFW_KEY_3,
    GLFW_KEY_4, GLFW_KEY_5, GLFW_KEY_6,
    GLFW_KEY_7, GLFW_KEY_8, GLFW_KEY_9
};
int guiScale = 1;
int mcscale(CGFloat input) {
    return (int)((guiScale * input)/resolutionScale);
}
int callback_SurfaceViewController_touchHotbar(CGFloat x, CGFloat y) {
    if (isGrabbing == JNI_FALSE) {
        return -1;
    }

    int barHeight = mcscale(20);
    int barY = physicalHeight - barHeight;
    if (y < barY) return -1;

    int barWidth = mcscale(180);
    int barX = (physicalWidth / 2) - (barWidth / 2);
    if (x < barX || x >= barX + barWidth) return -1;

    return hotbarKeys[(int) MathUtils_map(x, barX, barX + barWidth, 0, 9)];
}

JNIEXPORT void JNICALL Java_net_kdt_pojavlaunch_uikit_UIKit_updateMCGuiScale(JNIEnv* env, jclass clazz, jint scale) {
    guiScale = scale;
}

JNIEXPORT jstring JNICALL Java_org_lwjgl_glfw_CallbackBridge_nativeClipboard(JNIEnv* env, jclass clazz, jint action, jstring copySrc) {
    NSDebugLog(@"Debug: Clipboard access is going on\n");
    return UIKit_accessClipboard(env, action, copySrc);
}

JNIEXPORT void JNICALL Java_org_lwjgl_glfw_CallbackBridge_nativeSetGrabbing(JNIEnv* env, jclass clazz, jboolean grabbing, jfloat xset, jfloat yset) {
    isGrabbing = grabbing;

    dispatch_async(dispatch_get_main_queue(), ^{
        SurfaceViewController *vc = ((SurfaceViewController *)UIWindow.mainWindow.rootViewController);
        [vc updateGrabState];
    });
}

JNIEXPORT jboolean JNICALL Java_org_lwjgl_glfw_CallbackBridge_nativeIsGrabbing(JNIEnv* env, jclass clazz) {
    return isGrabbing;
}

void CallbackBridge_nativeSetInputReady(BOOL inputReady) {
    isInputReady = inputReady;
    if (inputReady) {
        if (GLFW_invoke_FramebufferSize) {
            hackFix18LWJGL(GLFW_invoke_FramebufferSize);
            GLFW_invoke_FramebufferSize((void*) showingWindow, windowWidth, windowHeight);
        }
        if (GLFW_invoke_WindowSize) {
            GLFW_invoke_WindowSize((void*) showingWindow, windowWidth, windowHeight);
        }
    }
}

#pragma mark - SDL3 event injection (Minecraft 26.x / RenderPearl backend)

/*
 * Minecraft 26.x replaced GLFW with SDL3 windowing (RenderPearl) and polls SDL
 * events directly. The launcher's UIKit layers intercept all touches, so input
 * never reaches SDL. These helpers push synthetic events via SDL_PushEvent,
 * mirroring the event layout of the vendored SDL3 fork
 * (amethyst-prebuilt-libraries/SDL/SDL3, include/SDL3/SDL_events.h).
 * SDL_Event is a 128-byte union; a zero timestamp is auto-filled by
 * SDL_PushEvent. Activation is implicit: when a GLFW game runs it registers
 * GLFW callbacks (GLFW_invoke_* non-NULL) and this path stays dormant.
 */

typedef struct {
    uint32_t type;       /* SDL_EVENT_MOUSE_MOTION = 0x400 */
    uint32_t reserved;
    uint64_t timestamp;
    uint32_t windowID;
    uint32_t which;
    uint32_t state;      /* SDL_MouseButtonFlags */
    float x, y, xrel, yrel;
} AASDL_MouseMotionEvent;

typedef struct {
    uint32_t type;       /* SDL_EVENT_MOUSE_BUTTON_DOWN = 0x401, _UP = 0x402 */
    uint32_t reserved;
    uint64_t timestamp;
    uint32_t windowID;
    uint32_t which;
    uint8_t button;      /* SDL buttons are 1-based: 1=left, 2=middle, 3=right */
    uint8_t down;
    uint8_t clicks;
    uint8_t padding;
    float x, y;
} AASDL_MouseButtonEvent;

typedef struct {
    uint32_t type;       /* SDL_EVENT_MOUSE_WHEEL = 0x403 */
    uint32_t reserved;
    uint64_t timestamp;
    uint32_t windowID;
    uint32_t which;
    float x, y;
    int32_t direction;   /* 1 = SDL_MOUSEWHEEL_NORMAL */
    float mouse_x, mouse_y;
    int32_t integer_x, integer_y;
} AASDL_MouseWheelEvent;

typedef struct {
    uint32_t type;       /* SDL_EVENT_KEY_DOWN = 0x300, _UP = 0x301 */
    uint32_t reserved;
    uint64_t timestamp;
    uint32_t windowID;
    uint32_t which;
    uint32_t scancode;
    uint32_t key;
    uint32_t mod;        /* SDL_Keymod of the vendored fork */
    uint16_t raw;
    uint8_t down, repeat;
} AASDL_KeyboardEvent;

typedef struct {
    uint32_t type;       /* SDL_EVENT_TEXT_INPUT = 0x302 */
    uint32_t reserved;
    uint64_t timestamp;
    uint32_t windowID;
    const char *text;    /* UTF-8 */
} AASDL_TextInputEvent;

/* SDL3 touch finger events. TouchController 0.3.1-alpha13+ drives its iOS
 * input through SdlPlatform, which only consumes SDL_EVENT_FINGER_* events;
 * the launcher's UIKit layers intercept all touches, so we mirror them here
 * like the mouse/keyboard events above. Layout matches the vendored SDL3 fork
 * (include/SDL3/SDL_events.h: struct SDL_TouchFingerEvent). */
#define SDL_EVENT_FINGER_DOWN 0x700
#define SDL_EVENT_FINGER_UP 0x701
#define SDL_EVENT_FINGER_MOTION 0x702
#define SDL_EVENT_FINGER_CANCELED 0x703

typedef struct {
    uint32_t type;
    uint32_t reserved;
    uint64_t timestamp;
    uint64_t touchID;    /* SDL_TouchID */
    uint64_t fingerID;   /* SDL_FingerID */
    float x, y;          /* normalized 0..1 */
    float dx, dy;
    float pressure;      /* normalized 0..1 */
    uint32_t windowID;
} AASDL_TouchFingerEvent;  /* 56 bytes, fits the 128-byte SDL_Event union */

typedef union {
    uint8_t raw[128];    /* matches sizeof(SDL_Event) */
} AASDL_Event;

static int (*aasdl_PushEvent)(void *event);
static uint32_t aasdl_buttons;

/* Written only by the patched SDL3 UIKit backend (AASDL_NoteWindow), which runs
 * on the main thread; read by the input paths (also main thread / controller
 * thread tolerates torn reads). Avoids SDL_GetWindows()/SDL_GetWindowSize()
 * which walk the window list without locking and crash when the game thread
 * mutates it concurrently. */
static uint32_t aasdl_winID;
static int aasdl_winW;
static int aasdl_winH;

static BOOL aasdl_available(void) {
    if (!aasdl_PushEvent) {
        aasdl_PushEvent = (int (*)(void *)) dlsym(RTLD_DEFAULT, "SDL_PushEvent");
        if (!aasdl_PushEvent) {
            static int logged;
            if (!logged) {
                logged = 1;
                NSLog(@"[SDLInject] SDL_PushEvent not found yet, will retry");
            }
            return NO;
        }
        NSLog(@"[SDLInject] SDL event injection ready");
    }
    return YES;
}

/* Minecraft 26.x (SDL3 windowing / RenderPearl) refuses SDL_Init(SDL_INIT_VIDEO)
 * until SDL_SetMainReady() has been called. The launcher used to do this
 * through org.lwjgl.sdl.SDLMain, but that initialized LWJGL in the launcher's
 * classloader and preloaded liblwjgl.dylib — which then makes Fabric/Knot
 * (separate classloader with Mojang's LWJGL) fail with "Native Library
 * liblwjgl.dylib already loaded in another classloader". Set the flag
 * directly on the native SDL3 instead, so whichever classloader the game
 * uses finds it already set. */
void aasdl_setMainReady(NSString *nativesDir) {
    static BOOL done;
    if (done) return;
    done = YES;
    /* nativesDir should be the bare dir name (e.g. "lwjgl41_natives") matching
     * org.lwjgl.librarypath: dlopen'ing a *different* copy registers a second
     * SDL instance under its own install name, and SDL_SetMainReady on one
     * instance is invisible to the other. Fall back to the other dirs in case
     * the version resolution disagrees with the installed bundle layout. */
    NSArray<NSString *> *candidates = @[ @"lwjgl41_natives", @"lwjgl36_natives", @"lwjgl33_natives" ];
    if (nativesDir.length > 0 && [candidates indexOfObject:nativesDir] == NSNotFound) {
        candidates = [candidates arrayByAddingObject:nativesDir];
    }
    NSString *sdlPath = nil;
    for (NSString *candidate in candidates) {
        NSString *sdlDir = [[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"libs"] stringByAppendingPathComponent:candidate];
        NSString *probe = [sdlDir stringByAppendingPathComponent:@"libSDL3.dylib"];
        if ([NSFileManager.defaultManager fileExistsAtPath:probe]) {
            sdlPath = probe;
            break;
        }
    }
    if (!sdlPath) {
        NSLog(@"[SDLInject] libSDL3.dylib not found in any natives dir, skipping SDL_SetMainReady");
        return;
    }
    NSLog(@"[SDLInject] using libSDL3.dylib from %@", sdlPath.stringByDeletingLastPathComponent);
    void *handle = dlopen(sdlPath.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    if (!handle) {
        NSLog(@"[SDLInject] dlopen libSDL3.dylib failed: %s", dlerror());
        return;
    }
    void (*setMainReady)(void) = (void (*)(void)) dlsym(handle, "SDL_SetMainReady");
    if (setMainReady) {
        setMainReady();
        NSLog(@"[SDLInject] SDL_SetMainReady called from C");
    } else {
        NSLog(@"[SDLInject] SDL_SetMainReady not found in libSDL3.dylib");
    }
}

static uint32_t aasdl_windowID(void) {
    return aasdl_winID;
}

/*
 * Called by the patched SDL3 UIKit backend (UIKit_ShowWindow /
 * viewDidLayoutSubviews / UIKit_DestroyWindow) on the main thread.
 * windowID == 0 means the SDL window is gone.
 */
void AASDL_NoteWindow(uint32_t windowID, int w, int h) {
    BOOL wasUp = aasdl_winID != 0;
    BOOL isUp = windowID != 0;
    aasdl_winID = windowID;
    aasdl_winW = w;
    aasdl_winH = h;
    if (isUp && !wasUp) {
        NSLog(@"[SDLInject] SDL window up: id=%u %dx%d", windowID, w, h);
    } else if (!isUp && wasUp) {
        NSLog(@"[SDLInject] SDL window gone");
    } else if (isUp) {
        // size may have changed (rotation); nothing else to do
    }
}

/*
 * Called by the patched SDL3 UIKit backend (UIKit_CreateWindow) on the main
 * thread: returns the launcher view the game must render into (the game
 * surface, matching the old GLKView architecture) so the game stays inside
 * the launcher's view hierarchy and follows its layout (controls, edge-swipe
 * menu shrinking the game, rotation). Returns NULL before the game screen
 * exists; SDL then falls back to creating its own window.
 */
UIView *AASDL_GetHostView(void) {
    return SurfaceViewController.surface;
}

static double aasdl_lastGrabSec;
static double aasdl_lastKeySec;

/* Called by the launcher whenever a physical (Bluetooth/hardware) key is
 * pressed, so SDL can decide whether the on-screen keyboard is needed.
 * Some Bluetooth keyboards are not exposed through GCKeyboard.coalescedKeyboard,
 * so the launcher's UIKey events are the only reliable signal. */
void AASDL_NoteKey(void) {
    aasdl_lastKeySec = CACurrentMediaTime();
}

/* Seconds elapsed since the last grab change (used to debounce taps that
 * would otherwise be mis-translated right after resume/pause). */
double AASDL_LastGrabChangeAge(void) {
    return CACurrentMediaTime() - aasdl_lastGrabSec;
}

/* True if a physical key was pressed within the given number of seconds. */
bool AASDL_HardwareKeySeenWithin(double seconds) {
    return aasdl_lastKeySec > 0 && (CACurrentMediaTime() - aasdl_lastKeySec) <= seconds;
}

/*
 * Called by the patched SDL3 UIKit backend (SetGCMouseRelativeMode) when the
 * game enables/disables relative mouse mode (mouse grab). Mirrors
 * nativeSetGrabbing: switches the launcher's touch translation to relative
 * deltas and hides the virtual mouse.
 */
void AASDL_NoteGrab(bool grabbed) {
    aasdl_lastGrabSec = CACurrentMediaTime();
    isGrabbing = grabbed ? JNI_TRUE : JNI_FALSE;
    dispatch_async(dispatch_get_main_queue(), ^{
        SurfaceViewController *vc = ((SurfaceViewController *)UIWindow.mainWindow.rootViewController);
        [vc updateGrabState];
    });
}

/* Map game-window pixel coords to SDL event coordinates. The game (Minecraft
 * 26.x) treats SDL mouse event coordinates as framebuffer pixels (the basis
 * of its GUI and renderer), so pass the launcher's framebuffer-space
 * coordinates through unchanged. */
static BOOL aasdl_coords(CGFloat x, CGFloat y, float *outX, float *outY) {
    if (windowWidth <= 0 || windowHeight <= 0) return NO;
    *outX = (float) x;
    *outY = (float) y;
    return YES;
}

static void aasdl_pushMouseMotion(float x, float y, float xrel, float yrel, uint32_t state) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_MouseMotionEvent *m = (AASDL_MouseMotionEvent *) ev.raw;
    m->type = 0x400;
    m->windowID = aasdl_windowID();
    m->state = state;
    /* Local fix: never expose out-of-bounds absolute positions to the game.
     * SDL keeps the absolute coordinate in mouse->last_x/last_y even while
     * in relative mode, so an off-window x/y would corrupt the cursor
     * position seen by SDL_GetMouseState when the menu opens. */
    m->x = fmaxf(0.0f, fminf(x, (float) windowWidth - 1.0f));
    m->y = fmaxf(0.0f, fminf(y, (float) windowHeight - 1.0f));
    m->xrel = xrel; m->yrel = yrel;
    aasdl_PushEvent(&ev);
}

static void aasdl_pushMouseButton(int button, bool down, float x, float y) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_MouseButtonEvent *b = (AASDL_MouseButtonEvent *) ev.raw;
    b->type = down ? 0x401 : 0x402;
    b->windowID = aasdl_windowID();
    b->button = (uint8_t) button;
    b->down = down;
    b->clicks = 1;
    b->x = x; b->y = y;
    aasdl_PushEvent(&ev);
    if (down) {
        aasdl_buttons |= (1u << (button - 1));
    } else {
        aasdl_buttons &= ~(1u << (button - 1));
    }
}

static void aasdl_pushMouseWheel(float xoffset, float yoffset) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_MouseWheelEvent *w = (AASDL_MouseWheelEvent *) ev.raw;
    w->type = 0x403;
    w->windowID = aasdl_windowID();
    w->x = xoffset; w->y = yoffset;
    w->direction = 1;
    w->integer_x = (int32_t) xoffset;
    w->integer_y = (int32_t) yoffset;
    float mx, my;
    if (aasdl_coords(cursorX, cursorY, &mx, &my)) {
        w->mouse_x = mx; w->mouse_y = my;
    }
    aasdl_PushEvent(&ev);
}

static void aasdl_pushKey(uint32_t scancode, uint32_t keycode, bool down, uint32_t mods) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_KeyboardEvent *k = (AASDL_KeyboardEvent *) ev.raw;
    k->type = down ? 0x300 : 0x301;
    k->windowID = aasdl_windowID();
    k->scancode = scancode;
    k->key = keycode;
    k->mod = mods;
    k->down = down;
    aasdl_PushEvent(&ev);
}

static void aasdl_pushTextInput(uint32_t codepoint) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_TextInputEvent *t = (AASDL_TextInputEvent *) ev.raw;
    char utf8[8];
    if (codepoint < 0x80) {
        utf8[0] = (char) codepoint; utf8[1] = 0;
    } else if (codepoint < 0x800) {
        utf8[0] = (char) (0xC0 | (codepoint >> 6));
        utf8[1] = (char) (0x80 | (codepoint & 0x3F));
        utf8[2] = 0;
    } else if (codepoint < 0x10000) {
        utf8[0] = (char) (0xE0 | (codepoint >> 12));
        utf8[1] = (char) (0x80 | ((codepoint >> 6) & 0x3F));
        utf8[2] = (char) (0x80 | (codepoint & 0x3F));
        utf8[3] = 0;
    } else {
        utf8[0] = (char) (0xF0 | (codepoint >> 18));
        utf8[1] = (char) (0x80 | ((codepoint >> 12) & 0x3F));
        utf8[2] = (char) (0x80 | ((codepoint >> 6) & 0x3F));
        utf8[3] = (char) (0x80 | (codepoint & 0x3F));
        utf8[4] = 0;
    }
    t->type = 0x303; /* SDL_EVENT_TEXT_INPUT (was 0x302 TEXT_EDITING: chat text never committed) */
    t->windowID = aasdl_windowID();
    t->text = utf8;
    aasdl_PushEvent(&ev);
}

/* Mirrors a UIKit touch into an SDL touch finger event. The launcher tracks a
 * single primary touch, so touchID/fingerID are fixed; x/y are normalized to
 * the game surface like SDL's own touch pipeline. Consumed by TouchController
 * (SdlPlatform) and ignored by anything that only looks at mouse events. */
static void aasdl_pushFinger(uint32_t type, CGFloat x, CGFloat y) {
    AASDL_Event ev;
    memset(&ev, 0, sizeof(ev));
    AASDL_TouchFingerEvent *f = (AASDL_TouchFingerEvent *) ev.raw;
    f->type = type;
    f->touchID = 1;
    f->fingerID = 1;
    if (windowWidth > 0) f->x = (float) x / (float) windowWidth;
    if (windowHeight > 0) f->y = (float) y / (float) windowHeight;
    f->pressure = 1.0f;
    f->windowID = aasdl_windowID();
    aasdl_PushEvent(&ev);
}

/* GLFW keycode -> SDL3 scancode + keycode (vendored fork enum values) */
typedef struct {
    int glfw;
    uint32_t scancode;
    uint32_t keycode;
} AASDL_KeyMap;

static const AASDL_KeyMap aasdl_keyMap[] = {
    { GLFW_KEY_SPACE, 44, 0x20 },
    { GLFW_KEY_APOSTROPHE, 52, 0x27 },
    { GLFW_KEY_COMMA, 54, 0x2C },
    { GLFW_KEY_MINUS, 45, 0x2D },
    { GLFW_KEY_PERIOD, 55, 0x2E },
    { GLFW_KEY_SLASH, 56, 0x2F },
    { GLFW_KEY_SEMICOLON, 51, 0x3B },
    { GLFW_KEY_EQUAL, 46, 0x3D },
    { GLFW_KEY_LEFT_BRACKET, 47, 0x5B },
    { GLFW_KEY_BACKSLASH, 49, 0x5C },
    { GLFW_KEY_RIGHT_BRACKET, 48, 0x5D },
    { GLFW_KEY_GRAVE_ACCENT, 53, 0x60 },
    { GLFW_KEY_ENTER, 40, 0x0D },
    { GLFW_KEY_TAB, 43, 0x09 },
    { GLFW_KEY_BACKSPACE, 42, 0x08 },
    { GLFW_KEY_INSERT, 73, 0x40000049u },
    { GLFW_KEY_DELETE, 76, 0x7F },
    { 262, 79, 0x4000004Fu },  /* GLFW_KEY_RIGHT */
    { 263, 80, 0x40000050u },  /* GLFW_KEY_LEFT */
    { 264, 81, 0x40000051u },  /* GLFW_KEY_DOWN */
    { 265, 82, 0x40000052u },  /* GLFW_KEY_UP */
    { GLFW_KEY_PAGE_UP, 75, 0x4000004Bu },
    { GLFW_KEY_PAGE_DOWN, 78, 0x4000004Eu },
    { GLFW_KEY_HOME, 74, 0x4000004Au },
    { GLFW_KEY_END, 77, 0x4000004Du },
    { GLFW_KEY_CAPS_LOCK, 57, 0x40000039u },
    { GLFW_KEY_SCROLL_LOCK, 71, 0x40000047u },
    { GLFW_KEY_NUM_LOCK, 83, 0x40000053u },
    { GLFW_KEY_ESCAPE, 41, 0x1B },
    { GLFW_KEY_LEFT_SHIFT, 225, 0x400000E1u },
    { GLFW_KEY_LEFT_CONTROL, 224, 0x400000E0u },
    { GLFW_KEY_LEFT_ALT, 226, 0x400000E2u },
    { GLFW_KEY_LEFT_SUPER, 227, 0x400000E3u },
    { GLFW_KEY_RIGHT_SHIFT, 229, 0x400000E5u },
    { GLFW_KEY_RIGHT_CONTROL, 228, 0x400000E4u },
    { GLFW_KEY_RIGHT_ALT, 230, 0x400000E6u },
    { GLFW_KEY_RIGHT_SUPER, 231, 0x400000E7u },
    { GLFW_KEY_MENU, 232, 0x400000E8u },
};

static BOOL aasdl_mapKey(int key, uint32_t *scancode, uint32_t *keycode) {
    if (key >= GLFW_KEY_A && key <= GLFW_KEY_Z) {
        *scancode = 4 + (key - GLFW_KEY_A);
        *keycode = (uint32_t) key + 32; /* SDL keycodes use lowercase */
        return YES;
    }
    if (key >= GLFW_KEY_0 && key <= GLFW_KEY_9) {
        *scancode = 30 + (key - GLFW_KEY_0);
        *keycode = (uint32_t) key;
        return YES;
    }
    if (key >= GLFW_KEY_F1 && key <= GLFW_KEY_F24) {
        uint32_t s = 58 + (key - GLFW_KEY_F1);
        *scancode = s;
        *keycode = 0x40000000u | s;
        return YES;
    }
    for (size_t i = 0; i < sizeof(aasdl_keyMap) / sizeof(aasdl_keyMap[0]); i++) {
        if (aasdl_keyMap[i].glfw == key) {
            *scancode = aasdl_keyMap[i].scancode;
            *keycode = aasdl_keyMap[i].keycode;
            return YES;
        }
    }
    return NO;
}

/* GLFW mod bits -> SDL_Keymod of the vendored SDL3 fork */
static uint32_t aasdl_mapMods(int mods) {
    uint32_t m = 0;
    if (mods & 0x01) m |= 0x0003;  /* SHIFT -> LSHIFT|RSHIFT */
    if (mods & 0x02) m |= 0x00C0;  /* CONTROL -> LCTRL|RCTRL */
    if (mods & 0x04) m |= 0x0300;  /* ALT -> LALT|RALT */
    if (mods & 0x08) m |= 0x0C00;  /* SUPER -> LGUI|RGUI */
    if (mods & 0x10) m |= 0x2000;  /* CAPS_LOCK */
    if (mods & 0x20) m |= 0x1000;  /* NUM_LOCK */
    return m;
}

BOOL CallbackBridge_nativeSendChar(jchar codepoint /* jint codepoint */) {
    if (GLFW_invoke_Char && isInputReady) {
        if (isUseStackQueueCall) {
            sendData(EVENT_TYPE_CHAR, codepoint, 0, 0, 0);
        } else {
            GLFW_invoke_Char((void*) showingWindow, (unsigned int) codepoint);
            // return lwjgl2_triggerCharEvent(codepoint);
        }
        return YES;
    } else if (aasdl_available()) {
        aasdl_pushTextInput((uint32_t) codepoint);
        return YES;
    }
    return NO;
}

BOOL CallbackBridge_nativeSendCharMods(jchar codepoint, int mods) {
    if ((GLFW_invoke_CharMods || GLFW_invoke_Char) && isInputReady) {
        if (isUseStackQueueCall) {
            sendData(EVENT_TYPE_CHAR_MODS, (unsigned int) codepoint, mods, 0, 0);
        } else {
            if (GLFW_invoke_CharMods) {
                GLFW_invoke_CharMods((void*) showingWindow, codepoint, mods);
            } else {
                GLFW_invoke_Char((void*) showingWindow, (unsigned int) codepoint);
            }
        }
        return YES;
    } else if (aasdl_available()) {
        aasdl_pushTextInput((uint32_t) codepoint);
        return YES;
    }
    return NO;
}
/*
JNIEXPORT void JNICALL Java_org_lwjgl_glfw_CallbackBridge_nativeSendCursorEnter(JNIEnv* env, jclass clazz, jint entered) {
    if (GLFW_invoke_CursorEnter && isInputReady) {
        GLFW_invoke_CursorEnter(showingWindow, entered);
    }
}
*/
void CallbackBridge_nativeSendCursorPos(char event, CGFloat x, CGFloat y) {
    if (!isInputReady && GLFW_invoke_CursorPos) return;

    switch (event) {
        case ACTION_DOWN:
        case ACTION_UP:
            if (!isGrabbing) {
                cursorX = x;
                cursorY = y;
            }
            break;

        case ACTION_MOVE:
            if (isGrabbing) {
                cursorX += x - cLastX;
                cursorY += y - cLastY;
            } else {
                cursorX = x;
                cursorY = y;
            }
            break;

        case ACTION_MOVE_MOTION:
            cursorX += x;
            cursorY += y;
            break;
    }

    if (GLFW_invoke_CursorPos) {
        if (isInputReady && !isUseStackQueueCall) {
            GLFW_invoke_CursorPos((void*) showingWindow, (double) cursorX, (double) cursorY);
        }
    } else if (aasdl_available()) {
        float mx, my;
        if (aasdl_coords(cursorX, cursorY, &mx, &my)) {
            float xrel = 0.0f, yrel = 0.0f;
            if (event == ACTION_MOVE_MOTION) {
                xrel = (float) x;
                yrel = (float) y;
            }
            aasdl_pushMouseMotion(mx, my, xrel, yrel, aasdl_buttons);
        }
    }

    /* TouchController (SdlPlatform) consumes SDL finger events; mirror the
     * launcher's primary touch alongside the mouse translation. Grab mode
     * (camera control) still gets both: the mod only reacts inside its UI. */
    if (aasdl_available()) {
        switch (event) {
            case ACTION_DOWN:
                aasdl_pushFinger(SDL_EVENT_FINGER_DOWN, cursorX, cursorY);
                break;
            case ACTION_MOVE:
                aasdl_pushFinger(SDL_EVENT_FINGER_MOTION, cursorX, cursorY);
                break;
            case ACTION_UP:
                aasdl_pushFinger(SDL_EVENT_FINGER_UP, cursorX, cursorY);
                break;
            case ACTION_CANCEL:
                aasdl_pushFinger(SDL_EVENT_FINGER_CANCELED, cursorX, cursorY);
                break;
            default:
                break;
        }
    }
}

char getKeyModifiers(int key, int action) {
    static char currMods;
    char mod;
    switch (key) {
        case GLFW_KEY_LEFT_SHIFT:
            mod = GLFW_MOD_SHIFT;
            break;
        case GLFW_KEY_LEFT_CONTROL:
            mod = GLFW_MOD_CONTROL;
            break;
        case GLFW_KEY_LEFT_ALT:
            mod = GLFW_MOD_ALT;
            break;
        case GLFW_KEY_CAPS_LOCK:
            mod = GLFW_MOD_CAPS_LOCK;
            break;
        case GLFW_KEY_NUM_LOCK:
            mod = GLFW_MOD_NUM_LOCK;
            break;
        default:
            return currMods;
    }
    if (action) {
        currMods |= mod;
    } else {
        currMods &= ~mod;
    }
    return currMods;
}

void CallbackBridge_nativeSendKey(int key, int scancode, int action, int mods) {
    if (GLFW_invoke_Key) {
        if (isInputReady) {
            keyDownBuffer[MAX(0, key-31)]=(jbyte)action;
            if (mods == 0) {
                mods = getKeyModifiers(key, action);
            }

            if (isUseStackQueueCall) {
                sendData(EVENT_TYPE_KEY, key, scancode, action, mods);
            } else {
                GLFW_invoke_Key((void*) showingWindow, key, scancode, action, mods);
            }
        }

        // On macOS, Minecraft expects the Command key
        if (key == GLFW_KEY_LEFT_CONTROL) {
            CallbackBridge_nativeSendKey(GLFW_KEY_LEFT_SUPER, 0, action, mods);
        } else if (key == GLFW_KEY_RIGHT_CONTROL) {
            CallbackBridge_nativeSendKey(GLFW_KEY_RIGHT_SUPER, 0, action, mods);
        }
    } else if (aasdl_available()) {
        uint32_t sdlScan, sdlKey;
        if (aasdl_mapKey(key, &sdlScan, &sdlKey)) {
            if (mods == 0) {
                mods = getKeyModifiers(key, action);
            }
            aasdl_pushKey(sdlScan, sdlKey, action != 0, aasdl_mapMods(mods));
        }
    }
}

void CallbackBridge_nativeSendMouseButton(int button, int action, int mods) {
    if (GLFW_invoke_MouseButton) {
        if (isInputReady) {
            if (button == -1) {
            } else {
                if (mods == 0) {
                    mods = getKeyModifiers(0, action);
                }

                if (isUseStackQueueCall) {
                    sendData(EVENT_TYPE_MOUSE_BUTTON, button, action, mods, 0);
                } else {
                    GLFW_invoke_MouseButton((void*) showingWindow, button, action, mods);
                }
            }
        }
    } else if (aasdl_available()) {
        if (button == -1) return;
        static const int glfwToSdl[3] = { 1, 3, 2 };
        int sdlButton = (button >= 0 && button < 3) ? glfwToSdl[button] : button + 1;
        if (sdlButton < 1 || sdlButton > 8) return;
        float mx, my;
        if (isGrabbing) {
            // In grab mode cursorX/cursorY accumulate relative deltas and can
            // go negative or beyond the window; clamp button coordinates to
            // the window center so the game never sees out-of-window clicks.
            mx = (float) aasdl_winW / 2.0f;
            my = (float) aasdl_winH / 2.0f;
            aasdl_pushMouseButton(sdlButton, action != 0, mx, my);
        } else if (aasdl_coords(cursorX, cursorY, &mx, &my)) {
            aasdl_pushMouseButton(sdlButton, action != 0, mx, my);
        }
    }
}

/* Local: expose the launcher's framebuffer size to SDL. The game's render
 * surface (CAMetalLayer contentsScale = UIScreen.scale x resolutionScale) and
 * its GUI hit-testing use this size, but SDL's UIKit_GetWindowSizeInPixels
 * derives a pixel size from UIScreen.nativeScale, which differs on devices
 * like iPhone 6/7/8 Plus (2.6087 vs 3.0) and would clamp/drop injected mouse
 * events to a fraction of the screen. SDL resolves this symbol via dlsym. */
__attribute__((used)) void AASDL_GetFramebufferSize(int *w, int *h) {
    if (w) *w = windowWidth;
    if (h) *h = windowHeight;
}

void CallbackBridge_nativeSendScreenSize(int width, int height) {
    windowWidth = width;
    windowHeight = height;
    
    if (isInputReady) {
        if (GLFW_invoke_FramebufferSize) {
            if (isUseStackQueueCall) {
                sendData(EVENT_TYPE_FRAMEBUFFER_SIZE, width, height, 0, 0);
            } else {
                GLFW_invoke_FramebufferSize((void*) showingWindow, width, height);
            }
        }
        if (GLFW_invoke_WindowSize) {
            if (isUseStackQueueCall) {
                sendData(EVENT_TYPE_WINDOW_SIZE, width, height, 0, 0);
            } else {
                GLFW_invoke_WindowSize((void*) showingWindow, width, height);
            }
        }
    }
    
    // return (isInputReady && (GLFW_invoke_FramebufferSize || GLFW_invoke_WindowSize));
}

void CallbackBridge_nativeSendScroll(CGFloat xoffset, CGFloat yoffset) {
    if (GLFW_invoke_Scroll && isInputReady) {
        if (isUseStackQueueCall) {
            sendDataFloat(EVENT_TYPE_SCROLL, xoffset, yoffset, 0, 0);
        } else {
            GLFW_invoke_Scroll((void*) showingWindow, (double) xoffset, (double) yoffset);
        }
    } else if (aasdl_available()) {
        aasdl_pushMouseWheel((float) xoffset, (float) yoffset);
    }
}

JNIEXPORT void JNICALL Java_org_lwjgl_glfw_GLFW_nglfwSetShowingWindow(JNIEnv* env, jclass clazz, jlong window) {
    showingWindow = (long) window;
}

void CallbackBridge_pauseGameIfNeed() {
    if (isGrabbing) {
        CallbackBridge_nativeSendKey(GLFW_KEY_ESCAPE, 0, 1, 0);
        CallbackBridge_nativeSendKey(GLFW_KEY_ESCAPE, 0, 0, 0);
    }
}
