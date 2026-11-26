#import "WitchMemoryPressure.h"
#import "CursorManager.h"
#import "MemSampler.h"
#import "PLLogOutputView.h"
#import "jni.h"

#import <malloc/malloc.h>
#import <dlfcn.h>

// Set in input_bridge_v3.m's JNI_OnLoad and cleared after JLI_Launch returns.
// Do not call into a VM that has already been destroyed.
extern JavaVM* runtimeJavaVMPtr;

static CFAbsoluteTime gLastJavaGC = 0;

// TGLMT (MobileGL) giữ thêm shadow CPU/pool mà đọc lại được từ GPU. Gọi qua
// dlsym để launcher không phụ thuộc cứng vào dylib; hàm tự defer về render
// thread (chỉ ghi cờ, áp dụng ở SwapBuffers kế tiếp) nên gọi từ queue nào cũng an toàn.
typedef size_t (*TGLMTTrimMemoryFn)(int);
static TGLMTTrimMemoryFn gTGLMTTrimFn = NULL;
static BOOL gTGLMTTrimLooked = NO;
static void WitchMaybeTrimTGLMT(BOOL critical) {
    if (!gTGLMTTrimLooked) {
        gTGLMTTrimLooked = YES;
        gTGLMTTrimFn = (TGLMTTrimMemoryFn)dlsym(RTLD_DEFAULT, "TGLMT_TrimMemory");
    }
    if (gTGLMTTrimFn) {
        gTGLMTTrimFn(critical ? 2 : 1);
    }
}

static void WitchRequestJavaGC(void) {
    JavaVM *vm = runtimeJavaVMPtr;
    if (vm == NULL) {
        return;
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (gLastJavaGC != 0 && now - gLastJavaGC < 60.0) {
        return;
    }
    gLastJavaGC = now;

    JNIEnv *env = NULL;
    jint getEnvResult = (*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6);
    BOOL attached = NO;
    if (getEnvResult == JNI_EDETACHED) {
        if ((*vm)->AttachCurrentThreadAsDaemon(vm, &env, NULL) != JNI_OK) {
            return;
        }
        attached = YES;
    } else if (getEnvResult != JNI_OK) {
        return;
    }

    jclass systemClass = (*env)->FindClass(env, "java/lang/System");
    if (systemClass != NULL) {
        jmethodID gcMethod = (*env)->GetStaticMethodID(env, systemClass, "gc", "()V");
        if (gcMethod != NULL) {
            (*env)->CallStaticVoidMethod(env, systemClass, gcMethod);
        }
        if ((*env)->ExceptionCheck(env)) {
            (*env)->ExceptionClear(env);
        }
        (*env)->DeleteLocalRef(env, systemClass);
    }

    if (attached) {
        (*vm)->DetachCurrentThread(vm);
    }
}

void WitchMemoryPressureHandle(BOOL critical) {
    WitchMemSampleMark(critical ? "memory-critical" : "memory-warning");
    WitchMaybeTrimTGLMT(critical);

    // UIKit/table/icon work must stay on the main thread; the sampler calls
    // this from its own serial queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        [PLLogOutputView trimLogToMaxLines:critical ? 500 : 1000];
        [CursorManager invalidateCursorRuntimeCaches];
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        // Return free malloc pages to the OS instead of keeping them in the
        // zone's free lists (helps after a big log/shader-compile burst).
        malloc_zone_pressure_relief(malloc_default_zone(), 0);
    });

    if (critical) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            WitchRequestJavaGC();
        });
    }
}
