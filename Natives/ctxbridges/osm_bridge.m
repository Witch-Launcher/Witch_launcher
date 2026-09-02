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
    fg_init();
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

// MARK: - CADisplayLink Hardware-VSync-Locked Pacing Engine for OSMesa

@interface OSMDisplayLinkPacer : NSObject
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL isRunning;
+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)onDisplayLink:(CADisplayLink *)link;
@end

#define OSM_RING_SLOTS 3

// Thread-safe Triple-Buffering state for CADisplayLink presentation (eliminates tearing)
typedef struct {
    uint8_t *ringBuffers[OSM_RING_SLOTS];
    uint8_t *interpBuffer;
    uint8_t *lastInterpBuffer; // Previous virtual frame for temporal stability & chaining
    size_t bufferSize;
    uint32_t width;
    uint32_t height;
    CGColorSpaceRef colorSpace;
    pthread_mutex_t lock;
    int latestSlot; // Slot containing newest completed native frame
    int prevSlot;   // Slot containing previous native frame
    int interpTickCount; // Number of VSync ticks since last real frame (for progressive extrapolation)
    BOOL hasPrevFrame;
    BOOL hasCurrFrame;
    BOOL newFrameArrived;
    BOOL hasLastInterp;
    BOOL displayedInterp;
    BOOL initialized;
} OSMFrameState;

static OSMFrameState sPacerState = {0};

@implementation OSMDisplayLinkPacer

+ (instancetype)shared {
    static OSMDisplayLinkPacer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OSMDisplayLinkPacer alloc] init];
    });
    return instance;
}

- (void)start {
    if (self.isRunning) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isRunning) return;
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
        CGFloat targetHz = (CGFloat)fg_get_target_fps();
        if (targetHz <= 0) targetHz = 60.0;
        CGFloat maxScreenHz = 60.0;
        if (@available(iOS 15.0, *)) {
            maxScreenHz = (CGFloat)[UIScreen mainScreen].maximumFramesPerSecond;
            if (maxScreenHz <= 0) maxScreenHz = 60.0;
            if (targetHz > maxScreenHz) targetHz = maxScreenHz;
            self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0, targetHz, targetHz);
        }
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.isRunning = YES;
        NSLog(@"[OSMBridge] CADisplayLink pacing engine STARTED (Target %.0f Hz, Screen max %.0f Hz)", (double)targetHz, (double)maxScreenHz);
    });
}

- (void)stop {
    if (!self.isRunning) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.displayLink) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
        self.isRunning = NO;
        NSLog(@"[OSMBridge] CADisplayLink pacing engine STOPPED");
    });
}

- (void)onDisplayLink:(CADisplayLink *)link {
    pthread_mutex_lock(&sPacerState.lock);

    if (!sPacerState.hasCurrFrame || sPacerState.latestSlot < 0 || sPacerState.width == 0 || sPacerState.height == 0) {
        pthread_mutex_unlock(&sPacerState.lock);
        return;
    }

    int curSlot = sPacerState.latestSlot;
    int prvSlot = sPacerState.prevSlot;
    BOOL hasPrev = sPacerState.hasPrevFrame && prvSlot >= 0;
    BOOL isNew = sPacerState.newFrameArrived;

    size_t pixelBytes = sPacerState.bufferSize;
    uint32_t w = sPacerState.width;
    uint32_t h = sPacerState.height;
    CGColorSpaceRef cs = sPacerState.colorSpace;

    const uint8_t* currPix = sPacerState.ringBuffers[curSlot];
    const uint8_t* prevPix = hasPrev ? sPacerState.ringBuffers[prvSlot] : currPix;
    uint8_t* interpBuf = sPacerState.interpBuffer;
    uint8_t* lastInterpBuf = sPacerState.lastInterpBuffer;
    BOOL hasLastInterp = sPacerState.hasLastInterp;

    // True 2X Alternating Cadence:
    // Alternate between In-Between Virtual Frame and Native Frame
    BOOL showInterp = NO;
    int interpTick = 1;

    if (!isNew && hasPrev) {
        // Intermediate VSync tick where no new native frame arrived yet -> generate in-between frame!
        showInterp = YES;
        interpTick = ++sPacerState.interpTickCount;
    } else if (isNew && hasPrev && !sPacerState.displayedInterp) {
        // A fresh frame arrived, but we interleave the intermediate virtual frame first for smooth 2X doubling!
        showInterp = YES;
        sPacerState.displayedInterp = YES;
        interpTick = 1;
    } else {
        // Display the native frame
        showInterp = NO;
        sPacerState.newFrameArrived = NO;
        sPacerState.displayedInterp = NO;
        sPacerState.interpTickCount = 0;
    }

    // Release lock IMMEDIATELY so the Minecraft render thread in osm_swap_buffers
    // is NEVER blocked!
    pthread_mutex_unlock(&sPacerState.lock);

    uint8_t *bufToDisplay = NULL;

    if (showInterp && hasPrev) {
        int mode = fg_get_mode();
        int submode = fg_get_fg2_submode();

        if (mode == FG_MODE_CAMERA_REPROJECT) {
            if (submode == FG2_SUBMODE_INTERP) {
                // Option 1 (Sub-Option A): Temporal Interpolation In-Between (50% midpoint)
                fg_gpu_temporal_interp(prevPix, currPix,
                                      hasLastInterp ? lastInterpBuf : NULL,
                                      interpBuf, w, h, 0.5f);
                if (lastInterpBuf) {
                    memcpy(lastInterpBuf, interpBuf, pixelBytes);
                    pthread_mutex_lock(&sPacerState.lock);
                    sPacerState.hasLastInterp = YES;
                    pthread_mutex_unlock(&sPacerState.lock);
                }
            } else {
                // Option 2 (Sub-Option B): Predictive Forward Extrapolation (Dựng trước)
                float extrapFactor = (float)interpTick * 0.5f;
                if (extrapFactor > 1.0f) extrapFactor = 1.0f;

                const uint8_t* sourcePix = (hasLastInterp && interpTick > 1 && lastInterpBuf) ? lastInterpBuf : currPix;
                fg_gpu_predict(prevPix, sourcePix, interpBuf, w, h, extrapFactor);
                if (lastInterpBuf) {
                    memcpy(lastInterpBuf, interpBuf, pixelBytes);
                    pthread_mutex_lock(&sPacerState.lock);
                    sPacerState.hasLastInterp = YES;
                    pthread_mutex_unlock(&sPacerState.lock);
                }
            }
        } else {
            // Mode 0: Motion-Adaptive Extrapolation (50% midpoint)
            float extrapFactor = (float)interpTick * 0.5f;
            if (extrapFactor > 1.0f) extrapFactor = 1.0f;

            fg_gpu_interpolate(prevPix, currPix, interpBuf, w, h, extrapFactor);
        }

        fg_osm_record_interpolated();
        bufToDisplay = interpBuf;
    } else {
        bufToDisplay = (uint8_t*)currPix;
    }

    if (bufToDisplay) {
        // Present directly to CALayer with CATransaction commit (VSync-locked)
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bufToDisplay, pixelBytes, NULL);
        if (provider) {
            CGImageRef bitmap = CGImageCreate(w, h, 8, 32, 4 * w, cs ?: CGColorSpaceCreateDeviceRGB(),
                                              kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                                              provider, NULL, FALSE, kCGRenderingIntentDefault);
            if (bitmap) {
                SurfaceViewController.surface.layer.contents = (__bridge id)bitmap;
                CGImageRelease(bitmap);
            }
            CGDataProviderRelease(provider);
        }
        [CATransaction commit];
    }
}

@end

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
    if (e && e->width > 0 && e->height > 0) {
        copyWidth = e->width;
        copyHeight = e->height;
        pixelBytes = (size_t)e->width * (size_t)e->height * 4;

        int myIdx = bufIdx;
        bufIdx = (bufIdx + 1) % 2;

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

    CGColorSpaceRef cs = bundle.color_space ? CGColorSpaceRetain(bundle.color_space) : CGColorSpaceCreateDeviceRGB();

    double now = CACurrentMediaTime();
    static double sLastFrameTime = 0;
    static float sFrameTimes[8] = {0};
    static int sFrameTimeIdx = 0;
    static int sFrameTimeCount = 0;
    static float sAvgFPS = 0;

    double dt = 0;
    if (sLastFrameTime > 0) {
        dt = now - sLastFrameTime;
        if (dt > 0.001 && dt < 1.0) {
            sFrameTimes[sFrameTimeIdx] = (float)dt;
            sFrameTimeIdx = (sFrameTimeIdx + 1) % 8;
            if (sFrameTimeCount < 8) sFrameTimeCount++;

            float avgDt = 0;
            for (int i = 0; i < sFrameTimeCount; i++) {
                avgDt += sFrameTimes[i];
            }
            avgDt /= sFrameTimeCount;
            sAvgFPS = (avgDt > 0) ? (1.0f / avgDt) : 0;
        }
    }
    sLastFrameTime = now;
    float nativeFPS = sAvgFPS > 0 ? sAvgFPS : 30.0f;

    // Helper block to present a raw buffer directly
    void (^presentRawBufferDirect)(void*) = ^(void* buf) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buf, pixelBytes, NULL);
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
    };

    // If Frame Generation is OFF:
    if (!fg_is_enabled() || !fg_is_supported()) {
        [OSMDisplayLinkPacer.shared stop];
        fg_osm_update_fps(nativeFPS, nativeFPS);

        static void* cachedRawBuf = NULL;
        static size_t cachedRawSize = 0;
        if (cachedRawSize < pixelBytes) {
            free(cachedRawBuf);
            cachedRawBuf = malloc(pixelBytes);
            cachedRawSize = cachedRawBuf ? pixelBytes : 0;
        }
        void* dst = cachedRawBuf ? cachedRawBuf : copy;
        if (dst != copy) memcpy(dst, copy, pixelBytes);
        presentRawBufferDirect(dst);
        return;
    }

    // Frame Generation is ON:
    fg_osm_update_fps(nativeFPS, nativeFPS * 2.0f);

    // Initialize/start the VSync Display Link
    if (!sPacerState.initialized) {
        pthread_mutex_init(&sPacerState.lock, NULL);
        sPacerState.initialized = YES;
    }
    [OSMDisplayLinkPacer.shared start];

    // Deliver raw frame to CADisplayLink Triple-Buffering pipeline
    pthread_mutex_lock(&sPacerState.lock);

    if (sPacerState.width != (uint32_t)copyWidth || sPacerState.height != (uint32_t)copyHeight || sPacerState.bufferSize < pixelBytes) {
        for (int i = 0; i < OSM_RING_SLOTS; i++) {
            free(sPacerState.ringBuffers[i]);
            sPacerState.ringBuffers[i] = (uint8_t*)malloc(pixelBytes);
        }
        free(sPacerState.interpBuffer);
        sPacerState.interpBuffer = (uint8_t*)malloc(pixelBytes);
        free(sPacerState.lastInterpBuffer);
        sPacerState.lastInterpBuffer = (uint8_t*)malloc(pixelBytes);

        sPacerState.bufferSize = pixelBytes;
        sPacerState.width = (uint32_t)copyWidth;
        sPacerState.height = (uint32_t)copyHeight;
        sPacerState.latestSlot = 0;
        sPacerState.prevSlot = -1;
        sPacerState.hasPrevFrame = NO;
        sPacerState.hasCurrFrame = NO;
        sPacerState.newFrameArrived = NO;
        sPacerState.hasLastInterp = NO;
        sPacerState.displayedInterp = NO;
    }

    // Find next available write slot in the 3-slot ring (that is neither latestSlot nor prevSlot)
    int writeSlot = (sPacerState.latestSlot + 1) % OSM_RING_SLOTS;
    if (writeSlot == sPacerState.prevSlot) {
        writeSlot = (writeSlot + 1) % OSM_RING_SLOTS;
    }

    if (sPacerState.ringBuffers[writeSlot]) {
        memcpy(sPacerState.ringBuffers[writeSlot], copy, pixelBytes);
        sPacerState.prevSlot = sPacerState.hasCurrFrame ? sPacerState.latestSlot : -1;
        sPacerState.latestSlot = writeSlot;
        sPacerState.hasPrevFrame = (sPacerState.prevSlot >= 0);
        sPacerState.hasCurrFrame = YES;
        sPacerState.newFrameArrived = YES;
    }

    if (sPacerState.colorSpace) {
        CGColorSpaceRelease(sPacerState.colorSpace);
    }
    sPacerState.colorSpace = cs; // transferred to sPacerState

    pthread_mutex_unlock(&sPacerState.lock);

    // Request camera updates from Java side if Camera Reprojection mode is active
    if (fg_get_mode() == FG_MODE_CAMERA_REPROJECT) {
        fg_request_camera_capture();
    }
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
