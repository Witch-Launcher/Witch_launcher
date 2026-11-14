#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <mach-o/dyld.h>
#include "jni.h"
#include "external/fishhook/fishhook.h"

// GLsync fence compatibility shim.
//
// Embeddium (Forge 1.20.1) calls GL32C.glFenceSync() every frame and aborts
// with "Failed to create fence object" when it returns NULL. LWJGL resolves
// that entry point with dlsym() on the renderer handle (libtinygl4angle.dylib),
// which lands on whatever copy of glFenceSync the dynamic linker exposes for
// that image — in practice a GLES instance that does not own the current EGL
// context, so the call returns 0 (or the symbol is not reachable at all).
//
// We interpose dlsym() inside liblwjgl.dylib so LWJGL's function lookups get
// our wrappers, which resolve the real entry point through the active EGL
// implementation (PLResolveGLEntry -> eglGetProcAddress of the renderer that
// created the context). If the real call still fails we hand back a sentinel
// GLsync that reports itself as already signaled, which degrades Embeddium's
// GPU frame pacing to a no-op instead of crashing the game.

extern void* PLResolveGLEntry(const char* name);
extern void* PLResolveGLEntryPreferred(const char* name);
extern JavaVM* runtimeJavaVMPtr;

typedef void* (*PFN_FENCE_SYNC)(unsigned int condition, unsigned int flags);
typedef int   (*PFN_CLIENT_WAIT_SYNC)(void* sync, unsigned int flags, unsigned long long timeout);
typedef void  (*PFN_DELETE_SYNC)(void* sync);
typedef unsigned char (*PFN_IS_SYNC)(void* sync);
typedef void  (*PFN_WAIT_SYNC)(void* sync, unsigned int flags, unsigned long long timeout);
typedef void  (*PFN_GET_SYNCIV)(void* sync, unsigned int pname, int bufSize, int* length, int* values);

#define SYNC_SENTINEL ((void*)(uintptr_t)0x5A17u)

#define GL_SYNC_GPU_COMMANDS_COMPLETE 0x9117
#define GL_SYNC_CONDITION             0x9111
#define GL_SYNC_STATUS                0x9114
#define GL_SIGNALED                   0x9119
#define GL_ALREADY_SIGNALED           0x911A

static void* (*orig_dlsym_sync)(void* handle, const char* symbol) = NULL;
static void* g_gl_handle = NULL;

// LTW links ANGLE's framework copy of libGLESv2 as a dependency, so a plain
// dlsym() on the renderer handle resolves every gl* entry point against that
// image — which is NOT the instance that owns the current context (the
// launcher loads libEGL/libGLESv2_angle_*). Objects created through those
// pointers are invalid (glGenTextures returned 0, buffers could not be
// mapped), while LTW's own wrappers worked. When the LTW renderer is active,
// route all gl* lookups through the active EGL instead.
// AMETHYST_RENDERER is only set when the game launches (after this shim is
// installed), so the check has to happen per lookup.
static int glLookupMode(void) {
    const char* renderer = getenv("AMETHYST_RENDERER");
    int ltw = renderer && strstr(renderer, "ltw") != NULL;
    static BOOL logged = NO;
    if (!logged && renderer) {
        logged = YES;
        NSLog(@"[GLSync] renderer=%s: gl* lookups %s", renderer,
              ltw ? "routed through the active EGL" : "resolved via dlsym");
    }
    return ltw;
}

static PFN_FENCE_SYNC real_fence_sync = NULL;
static PFN_CLIENT_WAIT_SYNC real_client_wait_sync = NULL;
static PFN_DELETE_SYNC real_delete_sync = NULL;
static PFN_IS_SYNC real_is_sync = NULL;
static PFN_WAIT_SYNC real_wait_sync = NULL;
static PFN_GET_SYNCIV real_get_synciv = NULL;

static void* resolveSyncEntry(const char* name) {
    void* eglFn = PLResolveGLEntry(name);
    void* dlFn = (orig_dlsym_sync && g_gl_handle) ? orig_dlsym_sync(g_gl_handle, name) : NULL;
    if (!strcmp(name, "glFenceSync")) {
        // If these differ, dlsym() was pointing at a GLES instance that does
        // not own the current context — the reason fences returned NULL.
        NSLog(@"[GLSync] resolve %s: eglGetProcAddress=%p dlsym=%p", name, eglFn, dlFn);
    }
    return eglFn ? eglFn : dlFn;
}

static void* shim_glFenceSync(unsigned int condition, unsigned int flags) {
    if (!real_fence_sync) {
        real_fence_sync = (PFN_FENCE_SYNC)resolveSyncEntry("glFenceSync");
        NSLog(@"[GLSync] glFenceSync entry point = %p", real_fence_sync);
    }
    if (real_fence_sync) {
        void* sync = real_fence_sync(condition, flags);
        if (sync) return sync;
        static BOOL logged = NO;
        if (!logged) {
            logged = YES;
            unsigned int (*getError)(void) = (unsigned int (*)(void))PLResolveGLEntry("glGetError");
            NSLog(@"[GLSync] real glFenceSync returned NULL (glGetError=0x%x); using no-op fence (GPU frame pacing disabled)",
                  getError ? getError() : 0);
        }
    }
    return SYNC_SENTINEL;
}

static int shim_glClientWaitSync(void* sync, unsigned int flags, unsigned long long timeout) {
    if (sync == SYNC_SENTINEL) return GL_ALREADY_SIGNALED;
    if (!real_client_wait_sync) real_client_wait_sync = (PFN_CLIENT_WAIT_SYNC)resolveSyncEntry("glClientWaitSync");
    if (real_client_wait_sync) return real_client_wait_sync(sync, flags, timeout);
    return GL_ALREADY_SIGNALED;
}

static void shim_glDeleteSync(void* sync) {
    if (sync == SYNC_SENTINEL || !sync) return;
    if (!real_delete_sync) real_delete_sync = (PFN_DELETE_SYNC)resolveSyncEntry("glDeleteSync");
    if (real_delete_sync) real_delete_sync(sync);
}

static unsigned char shim_glIsSync(void* sync) {
    if (sync == SYNC_SENTINEL) return 1;
    if (!real_is_sync) real_is_sync = (PFN_IS_SYNC)resolveSyncEntry("glIsSync");
    if (real_is_sync) return real_is_sync(sync);
    return 0;
}

static void shim_glWaitSync(void* sync, unsigned int flags, unsigned long long timeout) {
    if (sync == SYNC_SENTINEL || !sync) return;
    if (!real_wait_sync) real_wait_sync = (PFN_WAIT_SYNC)resolveSyncEntry("glWaitSync");
    if (real_wait_sync) real_wait_sync(sync, flags, timeout);
}

static void shim_glGetSynciv(void* sync, unsigned int pname, int bufSize, int* length, int* values) {
    if (sync == SYNC_SENTINEL) {
        if (length) *length = 1;
        if (values && bufSize > 0) {
            if (pname == GL_SYNC_STATUS) values[0] = GL_SIGNALED;
            else if (pname == GL_SYNC_CONDITION) values[0] = GL_SYNC_GPU_COMMANDS_COMPLETE;
            else values[0] = 0;
        }
        return;
    }
    if (!real_get_synciv) real_get_synciv = (PFN_GET_SYNCIV)resolveSyncEntry("glGetSynciv");
    if (real_get_synciv) real_get_synciv(sync, pname, bufSize, length, values);
}

static void* shim_dlsym(void* handle, const char* symbol) {
    if (!symbol) return orig_dlsym_sync ? orig_dlsym_sync(handle, symbol) : NULL;
    if (!strcmp(symbol, "glFenceSync")) {
        g_gl_handle = handle;
        return (void*)shim_glFenceSync;
    }
    if (!strcmp(symbol, "glClientWaitSync")) return (void*)shim_glClientWaitSync;
    if (!strcmp(symbol, "glDeleteSync")) return (void*)shim_glDeleteSync;
    if (!strcmp(symbol, "glIsSync")) return (void*)shim_glIsSync;
    if (!strcmp(symbol, "glWaitSync")) return (void*)shim_glWaitSync;
    if (!strcmp(symbol, "glGetSynciv")) return (void*)shim_glGetSynciv;

    if (symbol[0] == 'g' && symbol[1] == 'l' && glLookupMode()) {
        if (!g_gl_handle) g_gl_handle = handle;
        void* fn = PLResolveGLEntryPreferred(symbol);
        if (fn) return fn;
    }

    return orig_dlsym_sync ? orig_dlsym_sync(handle, symbol) : NULL;
}

// LWJGL stores the per-thread capability table pointer in JNIEnv's reserved3
// slot (org_lwjgl_system_ThreadLocalUtil.c: CAPABILITIES_OFFSET = 3 * ptr).
// Every GL*C call does tlsGetFunction(index) = caps[index], so if the table
// entry for a function is NULL, LWJGL replaces it with a "function missing"
// stub that prints a message and returns 0. That is what happens to
// glFenceSync here (Embeddium then throws "Failed to create fence object").
//
// Patch the entries in place on the render thread; the table layout is
// GLCapabilities' (fenceSync=658, isSync=659, deleteSync=660,
// clientWaitSync=661, waitSync=662, getSynciv=665). On a GLES-layout table
// those indices are unsupported NV 64-bit uniform entry points (already
// stubbed), so overwriting them is harmless.
void PLPatchGLSyncTable(void) {
    JavaVM* vm = runtimeJavaVMPtr;
    if (!vm) return;
    JNIEnv* env = NULL;
    if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK || !env) return;

    void** jni = *(void***)env;
    if (!jni) return;
    void** caps = (void**)jni[3];
    if (!caps) return;

    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        NSLog(@"[GLSync] caps table=%p fenceSync=%p isSync=%p deleteSync=%p clientWaitSync=%p waitSync=%p getSynciv=%p",
              caps, caps[658], caps[659], caps[660], caps[661], caps[662], caps[665]);
    }

    caps[658] = (void*)shim_glFenceSync;
    caps[659] = (void*)shim_glIsSync;
    caps[660] = (void*)shim_glDeleteSync;
    caps[661] = (void*)shim_glClientWaitSync;
    caps[662] = (void*)shim_glWaitSync;
    caps[665] = (void*)shim_glGetSynciv;
}

static void rebindSyncInImage(const struct mach_header* mh, intptr_t slide) {    if (!mh) return;
    const char* name = NULL;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) == mh) {
            name = _dyld_get_image_name(i);
            break;
        }
    }
    if (!name || !strstr(name, "liblwjgl")) return;

    // Rebind at most once per image: a second interposition would make our
    // shim resolve through itself and recurse.
    static const struct mach_header* done[16];
    static int doneCount = 0;
    for (int i = 0; i < doneCount; i++) {
        if (done[i] == mh) return;
    }
    if (doneCount >= (int)(sizeof(done) / sizeof(done[0]))) return;
    done[doneCount++] = mh;

    // Only the first rebind captures the real dlsym; later images must not
    // overwrite it with an already-interposed pointer (that would recurse).
    static void* ignoredOriginal = NULL;
    struct rebinding rb[] = (struct rebinding[]){
        {"dlsym", (void*)shim_dlsym, orig_dlsym_sync ? &ignoredOriginal : (void**)&orig_dlsym_sync},
    };
    int rc = rebind_symbols_image((void*)mh, slide, rb, sizeof(rb) / sizeof(rb[0]));
    NSLog(@"[GLSync] dlsym interposed in %s (rc=%d)", name, rc);
    if (rc != 0) {
        static BOOL triedGlobal = NO;
        if (!triedGlobal) {
            triedGlobal = YES;
            int rc2 = rebind_symbols(rb, sizeof(rb) / sizeof(rb[0]));
            NSLog(@"[GLSync] image rebind failed, global dlsym interpose rc=%d", rc2);
        }
    }
}

// Called once from init_hookFunctions() before the JVM (and liblwjgl) loads.
// The dyld callback fires for images loaded later; the loop covers anything
// that is already mapped.
void PLInstallGLSyncShim(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;
    _dyld_register_func_for_add_image(rebindSyncInImage);
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        rebindSyncInImage(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
    }
}
