#import "MemSampler.h"
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <os/proc.h>

static dispatch_source_t gMemSamplerTimer = NULL;
static uint64_t gMemPeakFootprint = 0;
static BOOL gMemWarned75 = NO;
static BOOL gMemWarned90 = NO;
static unsigned gMemSampleCount = 0;

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
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
        return NO;
    }
    if (footprint) *footprint = info.phys_footprint;
    // NOTE: no iokit_mapped field exists here; GPU/IOKit memory shows up inside
    // phys_footprint (and largely under external). footprint - internal -
    // compressed is the interesting remainder for triage.
    // These early fields (through phys_footprint) are layout-stable across OS
    // versions (Apple only appends), so read them unconditionally: on older
    // systems task_info returns fewer fields than the SDK's TASK_VM_INFO_COUNT
    // and a count-based guard would wrongly zero everything out.
    (void)count;
    if (internalOut) *internalOut = info.internal;
    if (compressedOut) *compressedOut = info.compressed;
    if (externalOut) *externalOut = info.external;
    if (regionsOut) *regionsOut = (uint64_t)info.region_count;
    return YES;
}

static void WitchLogMemSample(const char *tag) {
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
    NSLog(@"[MemSample]%s footprint=%lluMB (internal=%lluMB compressed=%lluMB external=%lluMB regions=%llu) avail=%zuMB used=%.0f%% peak=%lluMB",
          tag ? tag : "",
          (unsigned long long)(footprint / 1048576),
          (unsigned long long)(internal / 1048576),
          (unsigned long long)(compressed / 1048576),
          (unsigned long long)(external / 1048576),
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
    char buf[96];
    if (tag) {
        snprintf(buf, sizeof(buf), "[%s]", tag);
        WitchLogMemSample(buf);
    } else {
        WitchLogMemSample(NULL);
    }
}

void WitchMemSamplerStart(void) {
    if (gMemSamplerTimer != NULL) {
        return;
    }
    // Immediate baseline sample, then every 5s on a private serial queue at
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
    dispatch_source_set_timer(gMemSamplerTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                              (uint64_t)(5 * NSEC_PER_SEC),
                              (uint64_t)(1 * NSEC_PER_SEC));
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
