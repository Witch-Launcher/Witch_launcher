#include <jni.h>
#include <stdio.h>
#include <string.h>
#include "framegen.h"

static JavaVM* gJavaVM = NULL;

void JNI_OnLoad_framegen(JavaVM* vm, void* reserved) {
    gJavaVM = vm;
    // All native methods follow JNI naming convention (Java_*).
    // The JVM resolves them automatically — no RegisterNatives needed.
}

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_framegen_FrameGenBridge_updateCamera(
    JNIEnv* env, jclass cls,
    jfloat posX, jfloat posY, jfloat posZ,
    jfloat pitch, jfloat yaw,
    jfloatArray viewMatrix, jfloatArray projMatrix,
    jfloat fov, jint width, jint height
) {
    FGCameraData data = {0};
    data.pos[0] = posX;
    data.pos[1] = posY;
    data.pos[2] = posZ;
    data.rot[0] = pitch;
    data.rot[1] = yaw;
    data.fov = fov;
    data.width = width;
    data.height = height;
    data.valid = JNI_TRUE;

    if (viewMatrix) {
        jsize len = (*env)->GetArrayLength(env, viewMatrix);
        if (len >= 16) {
            jfloat* elements = (*env)->GetFloatArrayElements(env, viewMatrix, NULL);
            if (elements) {
                for (int i = 0; i < 16; i++) {
                    data.viewMatrix[i] = elements[i];
                }
                (*env)->ReleaseFloatArrayElements(env, viewMatrix, elements, JNI_ABORT);
            }
        }
    }

    if (projMatrix) {
        jsize len = (*env)->GetArrayLength(env, projMatrix);
        if (len >= 16) {
            jfloat* elements = (*env)->GetFloatArrayElements(env, projMatrix, NULL);
            if (elements) {
                for (int i = 0; i < 16; i++) {
                    data.projMatrix[i] = elements[i];
                }
                (*env)->ReleaseFloatArrayElements(env, projMatrix, elements, JNI_ABORT);
            }
        }
    }

    fg_update_camera(&data);
}

JNIEXPORT jboolean JNICALL Java_net_vda_witchlaunch_framegen_FrameGenBridge_isEnabled(
    JNIEnv* env, jclass cls
) {
    return fg_is_enabled() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_framegen_FrameGenBridge_setEnabled(
    JNIEnv* env, jclass cls, jboolean enabled
) {
    fg_set_enabled(enabled ? JNI_TRUE : JNI_FALSE);
}

JNIEXPORT jboolean JNICALL Java_net_vda_witchlaunch_framegen_FrameGenBridge_isSupported(
    JNIEnv* env, jclass cls
) {
    return fg_is_supported() ? JNI_TRUE : JNI_FALSE;
}

// Called to capture camera data from Java side.
// Throttled to max 20Hz and uses cached JNI class/method refs for near-zero overhead.
void fg_request_camera_capture(void) {
    if (!gJavaVM) return;

    static double lastCaptureTime = 0;
    double now = CACurrentMediaTime();
    if (now - lastCaptureTime < 0.05) { // 20 Hz throttle
        return;
    }
    lastCaptureTime = now;

    JNIEnv* env = NULL;
    BOOL needsDetach = NO;
    int status = (*gJavaVM)->GetEnv(gJavaVM, (void**)&env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        (*gJavaVM)->AttachCurrentThread(gJavaVM, &env, NULL);
        needsDetach = YES;
    } else if (status != JNI_OK || !env) {
        return;
    }

    static jclass cachedCls = NULL;
    static jmethodID cachedMid = NULL;
    if (!cachedCls) {
        jclass localCls = (*env)->FindClass(env, "net/vda/witchlaunch/framegen/FrameGenBridge");
        if (localCls) {
            cachedCls = (*env)->NewGlobalRef(env, localCls);
            (*env)->DeleteLocalRef(env, localCls);
            if (cachedCls) {
                cachedMid = (*env)->GetStaticMethodID(env, cachedCls, "captureCameraData", "()V");
            }
        }
    }

    if (cachedCls && cachedMid) {
        (*env)->CallStaticVoidMethod(env, cachedCls, cachedMid);
        if ((*env)->ExceptionCheck(env)) {
            (*env)->ExceptionClear(env);
        }
    }

    if (needsDetach) {
        (*gJavaVM)->DetachCurrentThread(gJavaVM);
    }
}
