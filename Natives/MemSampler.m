#import "MemSampler.h"
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <os/proc.h>
#include <string.h>
#include <malloc/malloc.h>

static dispatch_source_t gMemSamplerTimer = NULL;
static uint64_t gMemPeakFootprint = 0;
static BOOL gMemWarned75 = NO;
static BOOL gMemWarned90 = NO;
static unsigned gMemSampleCount = 0;
// Set from abort/crash paths (see WitchMemSamplerNoteCrash). malloc_zone_statistics
// and NSLog are not signal-safe; sampling while HotSpot reports a fatal error
// deadlocks on the malloc zone lock and recurses into JVM_handle_bsd_signal.
static volatile sig_atomic_t gMemSamplerCrashing = 0;
// Master switch (default ON = current behavior). Set from the
// debug.mem_sample_log preference before Start.
static BOOL gMemSamplerEnabled = YES;

void WitchMemSamplerSetEnabled(BOOL enabled) {
    gMemSamplerEnabled = enabled;
}

// Optional MobileGL-side accounting dump (provided by libMobileGL when the
// MobileGL renderer is active; resolved lazily so other renderers are
// unaffected and no hard link is needed).
typedef void (*MobileGLDumpMemoryStatsFn)(void);
static MobileGLDumpMemoryStatsFn gMobileGLDumpFn = NULL;

static void WitchMaybeDumpMobileGL(void) {
    // Retry the probe on every tick until MobileGL is loaded: probing once and
    // latching NULL misses it, because libMobileGL.dylib is dlopen'd lazily at
    // first context creation, well after the sampler starts. One dlsym per 30s
    // is negligible.
    if (gMobileGLDumpFn == NULL) {
        gMobileGLDumpFn = (MobileGLDumpMemoryStatsFn)dlsym(RTLD_DEFAULT, "MobileGL_DumpMemoryStats");
    }
    if (gMobileGLDumpFn != NULL) {
        gMobileGLDumpFn();
    }
}

static BOOL WitchCurrentVMInfo(uint64_t *footprint, uint64_t *internalOut,
                               uint64_t *compressedOut, uint64_t *externalOut,
                               uint64_t *regionsOut) {
    // Zero first: a newer SDK's TASK_VM_INFO_COUNT can be larger than the
    // struct the running kernel fills, so trailing fields must read 0 rather
    // than stack garbage. Retry with an older revision, then with basic info,
    // instead of dropping the whole sample (an all-failed call here is how
    // this sampler emitted zero lines while [MEM] kept logging).
    task_vm_info_data_t info;
    memset(&info, 0, sizeof(info));
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
        memset(&info, 0, sizeof(info));
        count = TASK_VM_INFO_REV1_COUNT;
        if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
            mach_task_basic_info_data_t basic;
            mach_msg_type_number_t bcount = MACH_TASK_BASIC_INFO_COUNT;
            memset(&basic, 0, sizeof(basic));
            if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                          (task_info_t)&basic, &bcount) != KERN_SUCCESS) {
                return NO;
            }
            if (footprint) *footprint = basic.resident_size;
            if (internalOut) *internalOut = 0;
            if (compressedOut) *compressedOut = 0;
            if (externalOut) *externalOut = 0;
            if (regionsOut) *regionsOut = 0;
            return YES;
        }
    }
    // NOTE: no iokit_mapped field exists here; GPU/IOKit memory shows up inside
    // phys_footprint (and largely under external). footprint - internal -
    // compressed is the interesting remainder for triage.
    // These early fields (through phys_footprint) are layout-stable across OS
    // versions (Apple only appends). REV0 kernels predate phys_footprint:
    // fall back to resident so the sample is still usable.
    (void)count;
    if (footprint) *footprint = info.phys_footprint ? info.phys_footprint : info.resident_size;
    if (internalOut) *internalOut = info.internal;
    if (compressedOut) *compressedOut = info.compressed;
    if (externalOut) *externalOut = info.external;
    if (regionsOut) *regionsOut = (uint64_t)info.region_count;
    return YES;
}

// Native heap (malloc zones) in use. footprint = internal+compressed+
// iokit cannot tell a JVM heap from a native one; this splits them: HotSpot
// mmaps its heap, so a flat mz with a climbing footprint means the growth is
// the JVM (or an mmap cache), not MobileGL/TGLES/LWJGL mallocs.
static uint64_t WitchMallocInUseBytes(void) {
    struct malloc_statistics_t st;
    memset(&st, 0, sizeof(st));
    malloc_zone_statistics(malloc_default_zone(), &st);
    return (uint64_t)st.size_in_use;
}

static void WitchLogMemSample(const char *tag) {
    if (gMemSamplerCrashing) {
        return;
    }
    uint64_t footprint = 0, internal = 0, compressed = 0, external = 0, regions = 0;
    if (!WitchCurrentVMInfo(&footprint, &internal, &compressed, &external, &regions) || footprint == 0) {
        return;
    }
    if (footprint > gMemPeakFootprint) {
        gMemPeakFootprint = footprint;
    }
    // os_proc_available_memory() = bytes left before THIS process hits its
    // Jetsam kill limit. footprint + available ~= effective limit.
    size_t available = os_proc_available_memory();
    uint64_t limit = footprint + available;
    double usedPct = limit > 0 ? (double)footprint / (double)limit * 100.0 : 0.0;
    NSLog(@"[MemSample]%s footprint=%lluMB (internal=%lluMB compressed=%lluMB external=%lluMB mz=%lluMB regions=%llu) avail=%zuMB used=%.0f%% peak=%lluMB",
          tag ? tag : "",
          (unsigned long long)(footprint / 1048576),
          (unsigned long long)(internal / 1048576),
          (unsigned long long)(compressed / 1048576),
          (unsigned long long)(external / 1048576),
          (unsigned long long)(WitchMallocInUseBytes() / 1048576),
          (unsigned long long)regions,
          available / 1048576,
          usedPct,
          (unsigned long long)(gMemPeakFootprint / 1048576));
    if (!gMemWarned75 && usedPct >= 75.0) {
        gMemWarned75 = YES;
        NSLog(@"[MemSample] WARNING: footprint at %.0f%% of Jetsam allowance — close other apps / lower view distance / reduce MobileGL frames-in-flight", usedPct);
        // Dump MobileGL accounting exactly when crossing into danger: this is
        // the moment that matters if the process dies seconds later.
        WitchMaybeDumpMobileGL();
    }
    if (!gMemWarned90 && usedPct >= 90.0) {
        gMemWarned90 = YES;
        NSLog(@"[MemSample] CRITICAL: footprint at %.0f%% of Jetsam allowance — kill imminent, expect jetsam termination", usedPct);
        WitchMaybeDumpMobileGL();
    }
}

void WitchMemSampleMark(const char *tag) {
    if (!gMemSamplerEnabled || gMemSamplerCrashing) return;
    char buf[96];
    if (tag) {
        snprintf(buf, sizeof(buf), "[%s]", tag);
        WitchLogMemSample(buf);
    } else {
        WitchLogMemSample(NULL);
    }
}

void WitchMemSamplerStart(void) {
    // Always emit one line, even when the switch is off: a session with zero
    // [MemSample] lines is indistinguishable from a dead sampler, and the
    // baseline footprint (pre-JVM) is needed to split JVM heap from native.
    uint64_t bootFp = 0, bootInternal = 0, bootCompressed = 0, bootExternal = 0,
             bootRegions = 0;
    BOOL bootOk = WitchCurrentVMInfo(&bootFp, &bootInternal, &bootCompressed,
                                     &bootExternal, &bootRegions);
    size_t bootAvail = os_proc_available_memory();
    NSLog(@"[MemSample][boot] enabled=%d tvi=%d footprint=%lluMB (internal=%lluMB "
          @"compressed=%lluMB external=%lluMB mz=%lluMB) avail=%zuMB regions=%llu",
          gMemSamplerEnabled ? 1 : 0, bootOk ? 1 : 0,
          (unsigned long long)(bootFp / 1048576),
          (unsigned long long)(bootInternal / 1048576),
          (unsigned long long)(bootCompressed / 1048576),
          (unsigned long long)(bootExternal / 1048576),
          (unsigned long long)(WitchMallocInUseBytes() / 1048576), bootAvail / 1048576,
          (unsigned long long)bootRegions);
    if (!gMemSamplerEnabled) {
        return;
    }
    if (gMemSamplerTimer != NULL) {
        return;
    }
    // Immediate baseline sample, then every 2s on a private serial queue at
    // USER_INITIATED QoS. A private queue (not the shared background queue) is
    // deliberate: under severe memory/CPU pressure the global background queue
    // can starve for tens of seconds (observed: 33s silence before a jetsam
    // kill), which blinds exactly the samples that matter most.
    WitchLogMemSample("[game-start]");
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    dispatch_queue_t q = dispatch_queue_create("org.angelauramc.amethyst.memsample", attr);
    gMemSamplerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    if (gMemSamplerTimer == NULL) {
        return;
    }
    // 2s: the v14 run went 914MB -> 1835MB inside the last 5s, and a 5s
    // tick can only catch it after the fact (or never).
    dispatch_source_set_timer(gMemSamplerTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                              (uint64_t)(2 * NSEC_PER_SEC),
                              (uint64_t)(500 * NSEC_PER_MSEC));
    dispatch_source_set_event_handler(gMemSamplerTimer, ^{
        WitchLogMemSample(NULL);
        // MobileGL accounting dump every 3rd sample (~15s). No-op unless
        // libMobileGL (with the diagnostic export) is loaded.
        if ((++gMemSampleCount % 3) == 0) {
            WitchMaybeDumpMobileGL();
        }
    });
    dispatch_resume(gMemSamplerTimer);
}

void WitchMemSamplerNoteCrash(void) {
    gMemSamplerCrashing = 1;
    // Best-effort: stop future ticks. dispatch_source_cancel is safe to call
    // here; the already-queued handler checks gMemSamplerCrashing first.
    if (gMemSamplerTimer != NULL) {
        dispatch_source_cancel(gMemSamplerTimer);
    }
}
