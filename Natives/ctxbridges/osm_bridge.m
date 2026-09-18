#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"

#include <dlfcn.h>
#include <pthread.h>
#include "environ.h"
#include "utils.h"

#include "bridge_tbl.h"
#include "osm_bridge.h"
#include "osmesa_internal.h"

static osmesa_library handle;

void dlsym_OSMesa() {
    void* dl_handle = dlopen([NSString stringWithFormat:@"@rpath/%s", getenv("AMETHYST_RENDERER")].UTF8String, RTLD_GLOBAL);
    if (!dl_handle) {
        NSLog(@"OSMesaBridge: Failed to load renderer library: %s", dlerror());
        return;
    }
    handle.OSMesaMakeCurrent = dlsym(dl_handle,"OSMesaMakeCurrent");
    handle.OSMesaGetCurrentContext = dlsym(dl_handle,"OSMesaGetCurrentContext");
    handle.OSMesaCreateContext = dlsym(dl_handle, "OSMesaCreateContext");
    handle.OSMesaDestroyContext = dlsym(dl_handle, "OSMesaDestroyContext");
    handle.OSMesaPixelStore = dlsym(dl_handle,"OSMesaPixelStore");
    handle.glGetString = dlsym(dl_handle,"glGetString");
    handle.glClearColor = dlsym(dl_handle, "glClearColor");
    handle.glClear = dlsym(dl_handle,"glClear");
    handle.glFinish = dlsym(dl_handle,"glFinish");
}

bool osm_init() {
    dlsym_OSMesa();
    return true;
}

osm_render_window_t* osm_init_context(osm_render_window_t* share) {
    osm_render_window_t* render_window = calloc(1, sizeof(osm_render_window_t));
    OSMesaContext context = handle.OSMesaCreateContext(GL_RGBA, share ? share->context : NULL);
    if(!context) {
        NSLog(@"OSMBridge: FAILED to create context");
        free(render_window);
        return NULL;
    }
    render_window->context = context;
    return render_window;
}

typedef struct {
    OSMesaContext context;
    void* buffer;
    uint32_t bufferBytes;
    uint32_t width, height;
} osm_thread_entry_t;

static pthread_key_t osm_thread_entry_key;
static pthread_once_t osm_thread_entry_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t osm_render_lock = PTHREAD_MUTEX_INITIALIZER;

static void osm_destroy_thread_entry(void* p) {
    osm_thread_entry_t* e = (osm_thread_entry_t*)p;
    if (e) {
        handle.OSMesaDestroyContext(e->context);
        free(e->buffer);
        free(e);
    }
}

static void osm_make_thread_entry_key(void) {
    pthread_key_create(&osm_thread_entry_key, osm_destroy_thread_entry);
}

static osm_thread_entry_t* osm_get_thread_entry(osm_render_window_t* master) {
    osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);
    if (!e) {
        e = calloc(1, sizeof(osm_thread_entry_t));
        e->context = handle.OSMesaCreateContext(GL_RGBA, master ? master->context : NULL);
        if (!e->context) {
            NSLog(@"OSMBridge: FAILED to create per-thread context");
            free(e);
            return NULL;
        }
        pthread_setspecific(osm_thread_entry_key, e);
    }
    return e;
}

static void osm_release_buffer_data(void* info, const void* data, size_t size) {
    free(info);
}

void osm_apply_current_ll_locked() {
    if (!currentBundle) {
        return;
    }
    osm_thread_entry_t* e = osm_get_thread_entry(&currentBundle->osm);
    if (!e) {
        return;
    }
    if (windowWidth <= 0 || windowHeight <= 0) {
        return;
    }
    if (e->width == (uint32_t)windowWidth && e->height == (uint32_t)windowHeight) {
        return;
    }

    e->width = windowWidth;
    e->height = windowHeight;

    uint32_t needBytes = (uint32_t)windowWidth * (uint32_t)windowHeight * 4;
    if (needBytes > e->bufferBytes) {
        void *newBuf = reallocf(e->buffer, needBytes);
        if (!newBuf) {
            NSLog(@"[OSMBridge] ✗ reallocf failed for %u bytes", needBytes);
            e->width = 0;
            e->height = 0;
            return;
        }
        e->buffer = newBuf;
        e->bufferBytes = needBytes;
    }

    handle.OSMesaMakeCurrent(e->context, e->buffer, GL_UNSIGNED_BYTE, e->width, e->height);
    handle.OSMesaPixelStore(OSMESA_ROW_LENGTH, e->width);
    handle.OSMesaPixelStore(OSMESA_Y_UP, 0);
}

void osm_apply_current_ll() {
    pthread_mutex_lock(&osm_render_lock);
    pthread_once(&osm_thread_entry_once, osm_make_thread_entry_key);
    osm_apply_current_ll_locked();
    pthread_mutex_unlock(&osm_render_lock);
}

void osm_make_current(osm_render_window_t* bundle) {
    pthread_mutex_lock(&osm_render_lock);
    pthread_once(&osm_thread_entry_once, osm_make_thread_entry_key);
    if(!bundle) {
        osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);
        if (e) {
            pthread_setspecific(osm_thread_entry_key, NULL);
            osm_destroy_thread_entry(e);
        }
        if (currentBundle) {
            if (currentBundle->osm.color_space) {
                CGColorSpaceRelease(currentBundle->osm.color_space);
                currentBundle->osm.color_space = NULL;
            }
            currentBundle = NULL;
        }
        pthread_mutex_unlock(&osm_render_lock);
        handle.OSMesaMakeCurrent(NULL, NULL, 0, 0, 0);
        return;
    }

    currentBundle = (basic_render_window_t *)bundle;
    currentBundle->osm.color_space = CGColorSpaceCreateDeviceRGB();
    osm_apply_current_ll_locked();
    pthread_mutex_unlock(&osm_render_lock);
}

void osm_swap_buffers() {
    pthread_mutex_lock(&osm_render_lock);
    pthread_once(&osm_thread_entry_once, osm_make_thread_entry_key);
    if (currentBundle) {
        osm_apply_current_ll_locked();
        handle.glFinish();
    }
    osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);

    static void* staticBufs[2] = {0};
    static size_t staticBufSizes[2] = {0};
    static int bufIdx = 0;

    size_t pixelBytes = 0;
    void* copy = NULL;
    GLsizei copyWidth = 0;
    GLsizei copyHeight = 0;
    if (e && e->buffer && e->width > 0 && e->height > 0) {
        copyWidth = e->width;
        copyHeight = e->height;
        pixelBytes = (size_t)e->width * (size_t)e->height * 4;

        int myIdx = bufIdx;
        bufIdx = (bufIdx + 1) % 2;

        if (staticBufSizes[myIdx] < pixelBytes) {
            void *newBuf = reallocf(staticBufs[myIdx], pixelBytes);
            if (newBuf) {
                staticBufs[myIdx] = newBuf;
                staticBufSizes[myIdx] = pixelBytes;
            } else {
                NSLog(@"[OSMBridge] ✗ swap buffer reallocf failed for %zu bytes", pixelBytes);
            }
        }
        copy = staticBufs[myIdx];
        if (copy) {
            memcpy(copy, e->buffer, pixelBytes);
        }
    }
    osm_render_window_t bundle = currentBundle ? currentBundle->osm : (osm_render_window_t){0};
    pthread_mutex_unlock(&osm_render_lock);
    if (copy == NULL) {
        return;
    }

    CGColorSpaceRef cs = bundle.color_space ? CGColorSpaceRetain(bundle.color_space) : CGColorSpaceCreateDeviceRGB();

    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, copy, pixelBytes, NULL);
        if (provider) {
            CGImageRef bitmap = CGImageCreate(copyWidth, copyHeight, 8, 32, 4 * copyWidth, cs,
                                              kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                                              provider, NULL, FALSE, kCGRenderingIntentDefault);
            if (bitmap) {
                SurfaceViewController.surface.layer.contents = (__bridge id)bitmap;
                CGImageRelease(bitmap);
            }
            CGDataProviderRelease(provider);
        }
        [CATransaction commit];
        if (cs) CGColorSpaceRelease(cs);
    });
}

void osm_swap_interval(int swapInterval) {
}

void osm_terminate() {
    NSLog(@"[OSMBridge] Terminating OSMesa bridge...");
    pthread_mutex_lock(&osm_render_lock);
    osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);
    if (e) {
        pthread_setspecific(osm_thread_entry_key, NULL);
        osm_destroy_thread_entry(e);
    }
    if (currentBundle) {
        if (currentBundle->osm.color_space) {
            CGColorSpaceRelease(currentBundle->osm.color_space);
            currentBundle->osm.color_space = NULL;
        }
        currentBundle = NULL;
    }
    pthread_mutex_unlock(&osm_render_lock);
    handle.OSMesaMakeCurrent(NULL, NULL, 0, 0, 0);
    NSLog(@"[OSMBridge] ✓ OSMesa bridge terminated");
}

void set_osm_bridge_tbl() {
    br_init = osm_init;
    br_init_context = (br_init_context_t) osm_init_context;
    br_make_current = (br_make_current_t) osm_make_current;
    br_swap_buffers = osm_swap_buffers;
    br_swap_interval = osm_swap_interval;
    br_terminate = osm_terminate;
}
