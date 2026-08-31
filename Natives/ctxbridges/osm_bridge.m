#import <Foundation/Foundation.h>
#import "SurfaceViewController.h"

#include <dlfcn.h>
#include <pthread.h>
#include "environ.h"
#include "utils.h"

#include "bridge_tbl.h"
#include "osm_bridge.h"
#include "osmesa_internal.h"
#include "framegen/framegen.h"

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
    return true; // no more specific initialization required
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

// OSMesaMakeCurrent binds the context on the CALLING thread and FIRST flushes
// the previous framebuffer into its user buffer (osmesa_st_framebuffer_flush_
// front -> memmove). Sharing one context + one buffer across threads is
// therefore fundamentally racy: FML's "fml-loadingscreen" background thread
// binds the same context the main thread renders with, so each bind flushes
// the OTHER window's framebuffer into a buffer the other thread may realloc
// at the same instant -> memmove into freed memory -> SIGSEGV in
// _platform_memmove (the buffer contents show libmalloc's freed-memory
// scribble pattern at the fault site).
//
// Instead every thread that binds gets its OWN OSMesa context + its OWN
// grow-only pixel buffer (entries are per-thread via pthread_key and only
// touched by their owning thread, so no cross-thread realloc/free races).
// The bundle's original context remains the share-list root. A mutex
// serializes bind/flush/copy so two threads never run OSMesaMakeCurrent
// concurrently.
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
    if (e->width == windowWidth && e->height == windowHeight) {
        return;
    }

    e->width = windowWidth;
    e->height = windowHeight;

    // Grow-only pixel buffer: the flush in OSMesaMakeCurrent copies the
    // PREVIOUS framebuffer (sized for the last bind) into the user buffer
    // before resizing, so shrinking the allocation would overflow.
    uint32_t needBytes = windowWidth * windowHeight * 4;
    if (needBytes > e->bufferBytes) {
        e->buffer = reallocf(e->buffer, needBytes);
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
        // Release this thread's own context/buffer (destroys on thread exit too).
        osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);
        if (e) {
            pthread_setspecific(osm_thread_entry_key, NULL);
            osm_destroy_thread_entry(e);
        }
        CGColorSpaceRelease(currentBundle->osm.color_space);
        currentBundle->osm.color_space = NULL;
        currentBundle = NULL;
        pthread_mutex_unlock(&osm_render_lock);
        //technically this does nothing as its not possible to unbind a context in OSMesa
        handle.OSMesaMakeCurrent(NULL, NULL, 0, 0, 0);
        return;
    }

    currentBundle = (basic_render_window_t *)bundle;
    currentBundle->osm.color_space = CGColorSpaceCreateDeviceRGB();
    osm_apply_current_ll_locked();
    pthread_mutex_unlock(&osm_render_lock);
}

void osm_swap_buffers() {
    // The rendered pixels are copied out of the live GL buffer before it can
    // be realloc'd or freed (thread-owned context rebinding, resize, unbind).
    // Posting the CGImage with a reference into the live buffer crashes the
    // render server's in-process compositing pass (memmove SIGSEGV) whenever
    // the buffer moves or is freed between swaps.
    pthread_mutex_lock(&osm_render_lock);
    pthread_once(&osm_thread_entry_once, osm_make_thread_entry_key);
    if (currentBundle) {
        osm_apply_current_ll_locked();
        handle.glFinish(); // this will force osmesa to write the last rendered image into the buffer
    }
    osm_thread_entry_t* e = pthread_getspecific(osm_thread_entry_key);

    // Use static buffer to avoid per-frame malloc/free overhead.
    // The buffer is only used until dispatch_async delivers it to main thread.
    // Double-buffer: alternate between two static buffers so the main thread
    // can safely read one while we write the other.
    static void* staticBufs[2] = {0};
    static size_t staticBufSizes[2] = {0};
    static int bufIdx = 0;
    static uint64_t swapCounter = 0;

    size_t pixelBytes = 0;
    void* copy = NULL;
    GLsizei copyWidth = 0;
    GLsizei copyHeight = 0;
    if (e && e->width > 0 && e->height > 0) {
        copyWidth = e->width;
        copyHeight = e->height;
        pixelBytes = (size_t)e->width * (size_t)e->height * 4;

        // Alternate buffers — main thread reads the previous one via CGDataProvider,
        // we write into the current one. osm_release_buffer_data is NOT called
        // for static buffers (they persist).
        int myIdx = bufIdx;
        bufIdx = (bufIdx + 1) % 2;
        swapCounter++;

        if (staticBufSizes[myIdx] < pixelBytes) {
            staticBufs[myIdx] = reallocf(staticBufs[myIdx], pixelBytes);
            staticBufSizes[myIdx] = pixelBytes;
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

    // Frame Generation: capture frame and try to interpolate
    // Return values: 0=raw, 1=interpolated
    if (copyWidth > 0 && copyHeight > 0) {
        fg_capture_frame_from_osmesa(copy, copyWidth, copyHeight);
    }

    CGColorSpaceRef cs = bundle.color_space ? CGColorSpaceRetain(bundle.color_space) : CGColorSpaceCreateDeviceRGB();

    dispatch_async(dispatch_get_main_queue(), ^{
    // Cached finalCopy buffer: avoid per-frame malloc/free (8MB per frame at 1080p).
    // The render thread writes into staticBufs[bufIdx], main thread reads a DIFFERENT buffer.
    // We keep a separate cached buffer for CGImage that persists across frames.
    static void* cachedFinalCopy = NULL;
    static size_t cachedFinalCopySize = 0;
    if (cachedFinalCopySize < pixelBytes) {
        free(cachedFinalCopy);
        cachedFinalCopy = malloc(pixelBytes);
        cachedFinalCopySize = cachedFinalCopy ? pixelBytes : 0;
    }
    void* finalCopy = cachedFinalCopy;
    if (finalCopy) {
        memcpy(finalCopy, copy, pixelBytes);
    } else {
        finalCopy = copy; // fallback: use static buffer directly
    }
    CGDataProviderRef bitmapProvider = CGDataProviderCreateWithData(NULL, finalCopy, pixelBytes, NULL);
    CGImageRef bitmap = CGImageCreate(copyWidth, copyHeight, 8, 32, 4 * copyWidth, cs, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault, bitmapProvider, NULL, FALSE, kCGRenderingIntentDefault);
    if (bitmap) {
        SurfaceViewController.surface.layer.contents = (__bridge id)bitmap;
        CGImageRelease(bitmap);
    }
    CGDataProviderRelease(bitmapProvider);
    CGColorSpaceRelease(cs);
    });
}

void osm_swap_interval(int swapInterval) {
    // Nothing to do here
}

void osm_terminate() {
    // Nothing to do here
}

void set_osm_bridge_tbl() {
    br_init = osm_init;
    br_init_context = (br_init_context_t) osm_init_context;
    br_make_current = (br_make_current_t) osm_make_current;
    br_swap_buffers = osm_swap_buffers;
    br_swap_interval = osm_swap_interval;
    br_terminate = osm_terminate;
}
