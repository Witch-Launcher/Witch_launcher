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

// Called from fg_on_next_drawable() to capture camera data from Java side.
// Runs on render thread — safe because FrameGenBridge uses only static methods.
void fg_request_camera_capture(void) {
    if (!gJavaVM) {
        static BOOL loggedNoVM;
        if (!loggedNoVM) { loggedNoVM = YES; NSLog(@"[FrameGen] fg_request_camera_capture: no gJavaVM"); }
        return;
    }

    JNIEnv* env = NULL;
    BOOL needsDetach = NO;
    int status = (*gJavaVM)->GetEnv(gJavaVM, (void**)&env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        (*gJavaVM)->AttachCurrentThread(gJavaVM, &env, NULL);
        needsDetach = YES;
    } else if (status != JNI_OK || !env) {
        static BOOL loggedEnvFail;
        if (!loggedEnvFail) { loggedEnvFail = YES; NSLog(@"[FrameGen] fg_request_camera_capture: GetEnv failed (%d)", status); }
        return;
    }

    jclass cls = (*env)->FindClass(env, "net/vda/witchlaunch/framegen/FrameGenBridge");
    if (cls) {
        jmethodID mid = (*env)->GetStaticMethodID(env, cls, "captureCameraData", "()V");
        if (mid) {
            (*env)->CallStaticVoidMethod(env, cls, mid);
            if ((*env)->ExceptionCheck(env)) {
                (*env)->ExceptionClear(env);
                static BOOL loggedExc;
                if (!loggedExc) { loggedExc = YES; NSLog(@"[FrameGen] captureCameraData threw exception"); }
            }
        } else {
            static BOOL loggedNoMethod;
            if (!loggedNoMethod) { loggedNoMethod = YES; NSLog(@"[FrameGen] captureCameraData method not found"); }
        }
    } else {
        static BOOL loggedNoClass;
        if (!loggedNoClass) { loggedNoClass = YES; NSLog(@"[FrameGen] FrameGenBridge class not found"); }
    }

    if (needsDetach) {
        (*gJavaVM)->DetachCurrentThread(gJavaVM);
    }
}
