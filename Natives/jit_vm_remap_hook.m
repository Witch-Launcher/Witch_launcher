#import "utils.h"
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <mach/vm_region.h>
#include <mach-o/getsect.h>
#include <mach-o/dyld.h>
#include <mach/vm_map.h>
#include <pthread.h>
#include <signal.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static vm_address_t g_lastPreparedRx;
static vm_size_t g_lastPreparedSize;

static const uint32_t kMirrorBrk0x6a = 0xD4200D40u;

static vm_address_t decode_adrp_add_immediate(vm_address_t pc, uint32_t adrp, uint32_t add) {
    uint32_t immlo = (adrp >> 29) & 0x3u;
    uint32_t immhi = (adrp >> 5) & 0x7ffffu;
    int64_t imm21 = ((int64_t)immhi << 2) | immlo;
    if (imm21 & 0x100000) {
        imm21 -= 0x200000;
    }
    vm_address_t page = (pc & ~0xfffULL) + ((vm_address_t)imm21 << 12);
    uint32_t imm12 = (add >> 10) & 0xfffu;
    uint32_t shift = (add >> 22) & 0x1u;
    vm_address_t offset = (vm_address_t)imm12 << (shift ? 12 : 0);
    return page + offset;
}

static uint32_t *find_mirror_mapping_brk_site_in_image(const struct mach_header *header) {
    unsigned long cstringSize = 0;
    const char *cstring = (const char *)getsectiondata((const struct mach_header_64 *)header, "__TEXT", "__cstring", &cstringSize);
    if (!cstring || cstringSize == 0) {
        return NULL;
    }

    const char *needle = "[JIT26] mapping at RW=%p, RX=%p\n";
    size_t needleLen = strlen(needle);
    vm_address_t strAddr = 0;
    for (unsigned long off = 0; off + needleLen <= cstringSize; off++) {
        if (memcmp(cstring + off, needle, needleLen) == 0) {
            strAddr = (vm_address_t)(uintptr_t)(cstring + off);
            break;
        }
    }
    if (strAddr == 0) {
        return NULL;
    }

    unsigned long textSize = 0;
    const char *text = (const char *)getsectiondata((const struct mach_header_64 *)header, "__TEXT", "__text", &textSize);
    if (!text || textSize < 12) {
        return NULL;
    }

    for (unsigned long insn = 0; insn + 12 <= textSize; insn += 4) {
        const uint32_t *words = (const uint32_t *)(text + insn);
        uint32_t w0 = words[0];
        uint32_t w1 = words[1];
        uint32_t w2 = words[2];
        if ((w0 & 0x9F000000u) != 0x90000000u || (w1 & 0xFF000000u) != 0x91000000u) {
            continue;
        }
        if ((w2 & 0xFC000000u) != 0x94000000u && w2 != kMirrorBrk0x6a) {
            continue;
        }
        vm_address_t pc = (vm_address_t)(uintptr_t)(text + insn);
        if (decode_adrp_add_immediate(pc, w0, w1) != strAddr) {
            continue;
        }
        return (uint32_t *)(text + insn + 8);
    }
    return NULL;
}

static BOOL write_rx_u32(uint32_t *site, uint32_t insn) {
    vm_size_t page = (vm_size_t)getpagesize();
    vm_address_t addr = (vm_address_t)(uintptr_t)site;
    vm_address_t pageAddr = addr & ~(page - 1);
    vm_size_t offset = addr - pageAddr;

    JIT26PrepareRegionForPatching((void *)pageAddr, page);

    vm_address_t mirrored = 0;
    vm_prot_t cur_prot = 0, max_prot = 0;
    kern_return_t ret = vm_remap(mach_task_self(), &mirrored, page, 0, VM_FLAGS_ANYWHERE,
                                 mach_task_self(), pageAddr, FALSE, &cur_prot, &max_prot,
                                 VM_INHERIT_SHARE);
    if (ret != KERN_SUCCESS) {
        NSLog(@"[JIT26] vm_remap for libjvm brk patch failed: 0x%x", ret);
        return NO;
    }
    ret = vm_protect(mach_task_self(), mirrored, page, FALSE,
                     VM_PROT_READ | VM_PROT_WRITE);
    if (ret != KERN_SUCCESS) {
        // NOTE: no VM_PROT_COPY here on purpose — COW would route the write to a
        // private copy and the patch would silently never land (same trap as the
        // old dyld mirrored path). Fail loudly; the caller reports it.
        NSLog(@"[JIT26] vm_protect(RW) for libjvm brk patch failed: 0x%x", ret);
        vm_deallocate(mach_task_self(), mirrored, page);
        return NO;
    }
    *(volatile uint32_t *)(mirrored + offset) = insn;
    sys_icache_invalidate(site, sizeof(insn));
    vm_deallocate(mach_task_self(), mirrored, page);
    return *site == insn;
}

BOOL verify_libjvm_mirror_brk_patch(void) {
    if (!DeviceNeedsDebugJITMapping()) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "libjvm.dylib")) {
            continue;
        }
        uint32_t *site = find_mirror_mapping_brk_site_in_image(_dyld_get_image_header(i));
        if (!site) {
            NSLog(@"[JIT26] WARNING: could not locate mirror prepare site in %s", name);
            return NO;
        }
        if (*site == kMirrorBrk0x6a) {
            NSLog(@"[JIT26] libjvm mirror brk #0x6a patch verified at %p in %s", site, name);
            return YES;
        }
        if ((*site & 0xFC000000u) != 0x94000000u) {
            NSLog(@"[JIT26] ERROR: unexpected insn %#x at mirror prepare site %p in %s",
                  *site, site, name);
            return NO;
        }
        NSLog(@"[JIT26] libjvm mirror brk patch missing at %p (insn=%#x). Patching BL printf → brk #0x6a at runtime.",
              site, *site);
        if (!write_rx_u32(site, kMirrorBrk0x6a)) {
            NSLog(@"[JIT26] ERROR: failed to install brk #0x6a at %p in %s. "
                  @"Run scripts/patch_libjvm_mirror_brk.py on bundled runtimes.",
                  site, name);
            return NO;
        }
        NSLog(@"[JIT26] libjvm mirror brk #0x6a patch verified at %p in %s", site, name);
        return YES;
    }
    NSLog(@"[JIT26] ERROR: libjvm.dylib is not loaded; cannot verify mirror brk patch");
    return NO;
}

void AmethystJIT26PrepareMirrorPair(void *rx, void *rw, size_t size) {
    if (!DeviceNeedsDebugJITMapping() || size < 16 * 1024 * 1024) {
        return;
    }
    vm_address_t rxAddr = (vm_address_t)(uintptr_t)rx;
    if (rxAddr == g_lastPreparedRx && size == g_lastPreparedSize) {
        return;
    }
    g_lastPreparedRx = rxAddr;
    g_lastPreparedSize = size;

    JIT26PrepareRegion(rx, size);
    JIT26PrepareRegion(rw, size);
    sys_icache_invalidate(rx, size);
    NSLog(@"[JIT26] Re-prepared mirror pair: RW=%p RX=%p size=%zu MB",
          rw, rx, size / (1024 * 1024));
}

void prewarm_jit_mirror_superpage(void) {
    // No-op: JIT mirror regions are prepared directly via libjvm brk 0x69/0x6a and StikDebug
}

void start_jit_mirror_prepare_poll_thread(void) {
    // No-op: Native brk 0x69/0x6a breakpoints handle JIT memory preparation in StikDebug
}

void rebind_jit_vm_hooks_after_libjvm_load(void) {
    // No-op on iOS 26+/27 to preserve memory safety and avoid dyld symbol corruption
}

void init_jit_vm_remap_hook(void) {
    NSLog(@"[JIT26] JIT handler initialized (breakpoint-driven JIT mode for iOS 26+/27)");
}

static sigjmp_buf g_jitPreflightJmp;
static volatile sig_atomic_t g_jitPreflightArmed = 0;

static void jit_preflight_fault(int sig) {
    (void)sig;
    if (g_jitPreflightArmed) {
        siglongjmp(g_jitPreflightJmp, 1);
    }
}

// Pre-flight proof that debugger-backed JIT execution REALLY works with the
// attached StikDebug session: bless 2 pages via brk, mirror an RW alias, write
// a `mov w0,#42; ret` stub, and CALL it under a fault guard. Returns YES only
// if the stub executes and returns 42. A stale debugger, detached session, or
// wrong script fails LOUDLY here instead of crashing later inside JLI_Launch
// with a black screen and no dialog (the JVM abort path cannot show UI).
BOOL JIT26ExecPreflight(void) {
    vm_size_t page = (vm_size_t)getpagesize();
    vm_size_t len = page * 2;

    NSLog(@"[JIT26] preflight: requesting scratch RX region via debugger");
    void *rx = JIT26PrepareRegion(NULL, len);
    if (!rx || rx == MAP_FAILED || ((vm_address_t)rx & (page - 1)) != 0) {
        NSLog(@"[JIT26] preflight: debugger did not return a usable RX region (%p)", rx);
        return NO;
    }
    NSLog(@"[JIT26] preflight: got RX=%p, mirroring RW alias", rx);

    vm_address_t mirrored = 0;
    vm_prot_t cur_prot = 0, max_prot = 0;
    kern_return_t ret = vm_remap(mach_task_self(), &mirrored, len, 0, VM_FLAGS_ANYWHERE,
                                 mach_task_self(), (vm_address_t)rx, FALSE,
                                 &cur_prot, &max_prot, VM_INHERIT_SHARE);
    if (ret != KERN_SUCCESS) {
        NSLog(@"[JIT26] preflight: vm_remap failed: 0x%x", ret);
        return NO;
    }
    // Keep this alias shared with RX. VM_PROT_COPY makes writes private (COW),
    // so the stub would be written to a different backing page than the one
    // executed below. The debugger has already prepared the RX mapping; this
    // alias only needs ordinary RW protection, matching write_rx_u32 above.
    ret = vm_protect(mach_task_self(), mirrored, len, FALSE, VM_PROT_READ | VM_PROT_WRITE);
    if (ret != KERN_SUCCESS) {
        NSLog(@"[JIT26] preflight: vm_protect(RW) failed: 0x%x", ret);
        vm_deallocate(mach_task_self(), mirrored, len);
        return NO;
    }
    static const uint32_t stub[] = { 0x52800540u, 0xD65F03C0u }; // movz w0, #42; ret
    memcpy((void *)mirrored, stub, sizeof(stub));
    sys_icache_invalidate(rx, sizeof(stub));
    NSLog(@"[JIT26] preflight: stub written, calling it under fault guard");

    struct sigaction sa = {0}, oldBus, oldSegv, oldTrap, oldIll;
    sa.sa_handler = jit_preflight_fault;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, &oldBus);
    sigaction(SIGSEGV, &sa, &oldSegv);
    sigaction(SIGTRAP, &sa, &oldTrap);
    sigaction(SIGILL, &sa, &oldIll);

    volatile int result = -1;
    g_jitPreflightArmed = 1;
    if (sigsetjmp(g_jitPreflightJmp, 1) == 0) {
        int (*fn)(void) = (int (*)(void))rx;
        result = fn();
    } else {
        NSLog(@"[JIT26] preflight: fault while executing blessed region (blessing ineffective)");
    }
    g_jitPreflightArmed = 0;

    sigaction(SIGBUS, &oldBus, NULL);
    sigaction(SIGSEGV, &oldSegv, NULL);
    sigaction(SIGTRAP, &oldTrap, NULL);
    sigaction(SIGILL, &oldIll, NULL);
    vm_deallocate(mach_task_self(), mirrored, len);
    // NOTE: the 2 RX pages stay reserved (debugger-owned); negligible and keeps
    // the debugger allocator state intact for the JVM's own requests.

    if (result != 42) {
        NSLog(@"[JIT26] preflight: FAILED (stub returned %d, want 42)", result);
        return NO;
    }
    NSLog(@"[JIT26] preflight: executable JIT memory works (stub returned 42)");
    return YES;
}

// Run the `mov w0,#42; ret` stub at `rx` with every fatal fault signal bound to
// jit_preflight_fault, so a non-executable region reports -1 instead of
// killing the app. Shared by the mirror-region preflight strategies below.
static int jit_run_guarded_stub(void *rx) {
    struct sigaction sa = {0}, oldBus, oldSegv, oldTrap, oldIll;
    sa.sa_handler = jit_preflight_fault;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, &oldBus);
    sigaction(SIGSEGV, &sa, &oldSegv);
    sigaction(SIGTRAP, &sa, &oldTrap);
    sigaction(SIGILL, &sa, &oldIll);

    volatile int result = -1;
    g_jitPreflightArmed = 1;
    if (sigsetjmp(g_jitPreflightJmp, 1) == 0) {
        int (*fn)(void) = (int (*)(void))rx;
        result = fn();
    }
    g_jitPreflightArmed = 0;

    sigaction(SIGBUS, &oldBus, NULL);
    sigaction(SIGSEGV, &oldSegv, NULL);
    sigaction(SIGTRAP, &oldTrap, NULL);
    sigaction(SIGILL, &oldIll, NULL);
    return result;
}

// Write the `mov w0,#42; ret` stub into a region shared with `rx` through an
// RW alias (same vm_remap + vm_protect(RW) mechanism as JIT26ExecPreflight —
// proven to make the bytes visible to the RX side on both the A16 iPhone and
// the A13 iPad). No VM_PROT_COPY: the alias must write the shared pages.
static BOOL jit_write_stub_via_alias(void *rx, size_t len) {
    vm_address_t mirrored = 0;
    vm_prot_t cur_prot = 0, max_prot = 0;
    kern_return_t ret = vm_remap(mach_task_self(), &mirrored, len, 0, VM_FLAGS_ANYWHERE,
                                 mach_task_self(), (vm_address_t)rx, FALSE,
                                 &cur_prot, &max_prot, VM_INHERIT_SHARE);
    if (ret != KERN_SUCCESS) {
        NSLog(@"[JIT26] mirror preflight: vm_remap(%zu MB alias) failed: 0x%x", len >> 20, ret);
        return NO;
    }
    ret = vm_protect(mach_task_self(), mirrored, len, FALSE, VM_PROT_READ | VM_PROT_WRITE);
    if (ret != KERN_SUCCESS) {
        NSLog(@"[JIT26] mirror preflight: vm_protect(RW) on alias failed: 0x%x", ret);
        vm_deallocate(mach_task_self(), mirrored, len);
        return NO;
    }
    static const uint32_t stub[] = { 0x52800540u, 0xD65F03C0u }; // movz w0, #42; ret
    memcpy((void *)mirrored, stub, sizeof(stub));
    sys_icache_invalidate(rx, sizeof(stub));
    vm_deallocate(mach_task_self(), mirrored, len);
    return YES;
}

// Big mirror preflight: reserve + PROVE a full-size (240 MB) executable region
// BEFORE the JVM exists, then offer it to the script (brk cmd 5) so libjvm's
// own 240 MB request (get_debug_jit_mapping → brk cmd 1, addr=0 at ~1.8 s) is
// served from this region instead of a fresh _M mapping.
//
// Why: the small JIT26ExecPreflight above only proves 2 pages. On A13/A14 TXM
// devices (iPad9, iPadOS 27) the debugger's _M allocator can return the 240 MB
// mapping in the high band (0x7000_0000_0000) where the exec blessing never
// takes effect: prepare_memory_region reports success, but every stub call
// SIGBUSes — the JVM dies in StubRoutines::call_stub with hs_err BUS_ADRALN
// pc=0x70075340bc ~1.9 s after launch. Small low-band allocations are fine,
// so the launcher used to boot straight into that crash.
//
// Strategy A: request the region early via the debugger — the same allocator
//   call the JVM would make, just earlier. If it lands somewhere blessable the
//   probe passes and the JVM serves this exact region (today's flow, minus the
//   address roulette).
// Strategy B (high-band TXM fallback): mmap it ourselves with PROT_READ |
//   PROT_EXEC — the one mmap prot proven to yield executable anonymous memory
//   on TXM devices (every DyldLVBypass exec dylib mapping is born this way, and
//   the A13 iPad runs libjvm.dylib's 12.5 MB text from such a map; a later
//   mprotect that ADDS exec is what iOS strips, so the X must be in mmap).
//   A plain app mmap also lands in the low band with the app's other mappings
//   (~0x14x_xxxxxxxx), never the debugger's unblessable 0x7000_0000_0000 band.
//   The debugger blesses that exact address, the stub is written through the
//   shared RW alias, and the probe call proves it with a hard yes/no before the
//   JVM is allowed to depend on it.
//   NOTE (iPad12,1/A13 run 2026-10-18): on the A13 the kernel parks this R+X
//   mmap in the SAME 0x7000_0000_0000 band as the debugger's _M allocator, and
//   the probe then fails there too — so B alone does not save the A13.
// Strategy C (low-placement, A13/A14): scan our address space for a free hole
//   below the high band (< 0x7000_0000_0000) and force the mapping there: first
//   a plain mmap with the hole as a *hint* (kernel honours it when free, never
//   clobbers), then, if the kernel ignored every hint, an atomic
//   mach_vm_allocate(VM_FLAGS_FIXED) + mprotect(RX) in the largest hole.
//   Low regions are the only ones this OS executes anon code from (small
//   preflight stub at 0x11ex_xxxxxxxx, DyldLVBypass exec maps, iPhone13,4
//   strategy A at 0x15a8_d8000); the whole 0x7000_0000_0000+ band SIGBUSes on
//   every TXM unit we have, regardless of how the mapping was created.
static int jit26_find_low_gaps(size_t size, vm_address_t *gaps, int maxGaps,
                               int *outRegionsWalked, vm_size_t *outLargestGap,
                               vm_address_t *outLargestGapAt) {
    typedef struct { vm_address_t start; vm_size_t len; } gap_t;
    gap_t found[8];
    int foundCount = 0;
    int regionsWalked = 0;
    vm_size_t largestGap = 0;
    vm_address_t largestGapAt = 0;
    const vm_address_t scanStart = 0x100000000ULL;
    const vm_address_t scanEnd = 0x7000000000ULL;
    vm_address_t cursor = scanStart;
    while (cursor < scanEnd) {
        vm_size_t regionSize = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        vm_address_t addr = cursor;
        kern_return_t kr = vm_region_64(mach_task_self(), &addr, &regionSize,
                                        VM_REGION_BASIC_INFO_64,
                                        (vm_region_info_t)&info, &count, &object);
        if (object != MACH_PORT_NULL) {
            mach_port_deallocate(mach_task_self(), object);
        }
        if (kr != KERN_SUCCESS) {
            break;
        }
        regionsWalked++;
        if (addr > cursor) {
            vm_size_t gapLen = (vm_size_t)(addr - cursor);
            if (gapLen > largestGap) {
                largestGap = gapLen;
                largestGapAt = cursor;
            }
            if (gapLen >= size && foundCount < 8) {
                found[foundCount].start = cursor;
                found[foundCount].len = gapLen;
                foundCount++;
            }
        }
        vm_address_t next = addr + regionSize;
        if (next <= cursor) {
            next = cursor + 0x4000;
        }
        cursor = next;
    }
    if (scanEnd > cursor) {
        vm_size_t gapLen = (vm_size_t)(scanEnd - cursor);
        if (gapLen > largestGap) {
            largestGap = gapLen;
            largestGapAt = cursor;
        }
        if (gapLen >= size && foundCount < 8) {
            found[foundCount].start = cursor;
            found[foundCount].len = gapLen;
            foundCount++;
        }
    }
    for (int i = 0; i < foundCount; i++) {
        for (int j = i + 1; j < foundCount; j++) {
            if (found[j].len > found[i].len) {
                gap_t t = found[i];
                found[i] = found[j];
                found[j] = t;
            }
        }
    }
    int n = foundCount < maxGaps ? foundCount : maxGaps;
    for (int i = 0; i < n; i++) {
        gaps[i] = found[i].start;
    }
    if (outRegionsWalked) {
        *outRegionsWalked = regionsWalked;
    }
    if (outLargestGap) {
        *outLargestGap = largestGap;
    }
    if (outLargestGapAt) {
        *outLargestGapAt = largestGapAt;
    }
    return n;
}

// Early mirror reservation (constructor time, before main()). The 240 MB
// mirror region must be PLACED LOW to be executable: the whole
// 0x7000_0000_0000+ JIT band SIGBUSes on TXM devices no matter how the
// mapping was created (measured on iPad12,1/A13, iPhone13,4/A14 and
// iPhone14,5/A15 — _M via debugger, app mmap(R+X), all dead up there), while
// low R+X anon mappings execute (DyldLVBypass exec maps, small preflight,
// iPhone13,4 strategy A at 0x15a8_d8000). Fragmentation grows fast during
// launcher init, so the preflight (right before the JVM starts) can find no
// low 240 MB hole left (latestlog 2026-10-18 05:41, iPhone14,5: "C found no
// executable low region"). Reserving here — before Mesa/MoltenVK/SDL/JVM
// mappings exist — is the reliable moment. Harmless if unused: untouched
// anonymous pages cost no RAM, and the region is released if its exec probe
// fails or if the JVM never asks.
static void *g_earlyMirrorRx = NULL;
static size_t g_earlyMirrorSize = 0;

__attribute__((constructor))
static void jit26_reserve_early_mirror_region(void) {
    const size_t size = JIT26_MIRROR_REGION_SIZE; // 244 MB >= JDK21/25 CodeCache request
    uintptr_t tries[16];
    int n = 0;
    vm_address_t gaps[8] = {0};
    int gapCount = jit26_find_low_gaps(size, gaps, 8, NULL, NULL, NULL);
    for (int i = 0; i < gapCount && n < 14; i++) {
        tries[n++] = (uintptr_t)gaps[i];
    }
    static const uintptr_t fallback[] = {
        0x120000000ULL, 0x130000000ULL, 0x140000000ULL, 0x150000000ULL,
        0x160000000ULL, 0x170000000ULL, 0x200000000ULL,
    };
    for (size_t i = 0; i < sizeof(fallback) / sizeof(fallback[0]) && n < 16; i++) {
        tries[n++] = fallback[i];
    }
    for (int i = 0; i < n; i++) {
        void *r = mmap((void *)tries[i], size, PROT_READ | PROT_EXEC,
                       MAP_PRIVATE | MAP_ANON, -1, 0);
        if (r == MAP_FAILED) {
            continue;
        }
        if ((uintptr_t)r < 0x100000000ULL || (uintptr_t)r >= 0x7000000000ULL) {
            munmap(r, size);
            continue;
        }
        g_earlyMirrorRx = r;
        g_earlyMirrorSize = size;
        NSLog(@"[JIT26] early mirror reservation: %p (%zu MB R+X, hint 0x%lx, gapScan=%d)",
              r, size >> 20, (unsigned long)tries[i], gapCount);
        return;
    }
    NSLog(@"[JIT26] early mirror reservation: no low %zu MB hole at constructor time (gaps=%d)", size >> 20, gapCount);
}

// Bless a mapped region through the debugger, write the probe stub via the RW
// alias, prove it executes, then offer it to the script (cmd 5) and verify the
// offer round-trip (cmd 6). Returns YES only when the region is provably
// executable. Does NOT unmap on failure — the caller owns the mapping.
static BOOL jit26_finish_mirror_region(void *rx, size_t size, const char *tag) {
    NSLog(@"[JIT26] mirror preflight: %s mapped at %p, blessing via prepare_memory_region", tag, rx);
    JIT26PrepareRegion(rx, size);
    if (!jit_write_stub_via_alias(rx, size)) {
        NSLog(@"[JIT26] mirror preflight: %s alias write failed at %p", tag, rx);
        return NO;
    }
    int result = jit_run_guarded_stub(rx);
    if (result != 42) {
        NSLog(@"[JIT26] mirror preflight: %s probe of %p returned %d (want 42)", tag, rx, result);
        return NO;
    }
    NSLog(@"[JIT26] mirror preflight: %s OK at %p (%zu MB, blessed + executable)", tag, rx, size >> 20);
    JIT26OfferMirrorRegion(rx, size);
    NSLog(@"[JIT26] mirror preflight: offered region to script (cmd 5)");
    uintptr_t echo = (uintptr_t)JIT26VerifyMirrorOffer(NULL);
    BOOL verified = (echo == (uintptr_t)rx);
    NSLog(@"[JIT26] mirror preflight: %s offer echo=0x%lx verified=%d%s", tag, (unsigned long)echo, verified,
          verified ? "" : " (script did not take the offer — stale assigned script or extension not evaluated?)");
    JITReportLine(@"mirror_region=%s:%p:%zu offer_echo=0x%lx offer_verify=%d", tag, rx, size >> 20, (unsigned long)echo, verified);
    return YES;
}
BOOL JIT26MirrorRegionPreflight(size_t size, void **outAddr) {
    if (outAddr) {
        *outAddr = NULL;
    }
    if (size < 16u * 1024u * 1024u) {
        NSLog(@"[JIT26] mirror preflight: refusing undersized request (%zu)", size);
        return NO;
    }
    vm_size_t page = (vm_size_t)getpagesize();
    size = (size + page - 1) & ~(page - 1);

    // Strategy E: the region reserved at constructor time (jit26_reserve_early_mirror_region).
    // Placed when the address space was still empty, so it sits LOW — the only
    // band that executes on these TXM devices. Bless + probe + offer it now.
    if (g_earlyMirrorRx && g_earlyMirrorSize >= size) {
        NSLog(@"[JIT26] mirror preflight: E — early low reservation at %p", g_earlyMirrorRx);
        if (jit26_finish_mirror_region(g_earlyMirrorRx, size, "E")) {
            if (outAddr) {
                *outAddr = g_earlyMirrorRx;
            }
            return YES;
        }
        NSLog(@"[JIT26] mirror preflight: E reservation %p failed the probe — releasing, trying A", g_earlyMirrorRx);
        munmap(g_earlyMirrorRx, g_earlyMirrorSize);
        g_earlyMirrorRx = NULL;
        g_earlyMirrorSize = 0;
    }

    NSLog(@"[JIT26] mirror preflight: A — requesting %zu MB RX region via debugger", size >> 20);
    void *rxA = JIT26PrepareRegion(NULL, size);
    if (rxA && rxA != MAP_FAILED && ((vm_address_t)rxA & (page - 1)) == 0) {
        if (jit_write_stub_via_alias(rxA, size)) {
            int resultA = jit_run_guarded_stub(rxA);
            if (resultA == 42) {
                NSLog(@"[JIT26] mirror preflight: A OK at %p (%zu MB, blessed + executable)", rxA, size >> 20);
                JIT26OfferMirrorRegion(rxA, size);
                NSLog(@"[JIT26] mirror preflight: offered region to script (cmd 5)");
                uintptr_t echoA = (uintptr_t)JIT26VerifyMirrorOffer(NULL);
                BOOL verifiedA = (echoA == (uintptr_t)rxA);
                NSLog(@"[JIT26] mirror preflight: A offer echo=0x%lx verified=%d%s", (unsigned long)echoA, verifiedA,
                      verifiedA ? "" : " (script did not take the offer — stale assigned script or extension not evaluated?)");
                JITReportLine(@"mirror_region=A:%p:%zu offer_echo=0x%lx offer_verify=%d", rxA, size >> 20, (unsigned long)echoA, verifiedA);
                if (outAddr) {
                    *outAddr = rxA;
                }
                return YES;
            }
            NSLog(@"[JIT26] mirror preflight: A probe of %p returned %d (want 42)", rxA, resultA);
        }
        NSLog(@"[JIT26] mirror preflight: A region %p is NOT executable — deallocating, trying B", rxA);
        kern_return_t dret = vm_deallocate(mach_task_self(), (vm_address_t)rxA, size);
        NSLog(@"[JIT26] mirror preflight: A dealloc → 0x%x", dret);
    } else {
        NSLog(@"[JIT26] mirror preflight: A returned unusable region %p", rxA);
    }

    // Strategy B: mmap R+X directly (the only mmap prot proven to hand out
    // executable anonymous memory on TXM devices — the DyldLVBypass fallback
    // maps every exec dylib exactly this way), bless that address through the
    // debugger, write the stub via the RW alias, then prove it with the call.
    // Deliberately NOT mmap(RW) → mprotect(RX): adding exec via a later
    // mprotect is the operation iOS strips; the X must be in the mmap prot.
    NSLog(@"[JIT26] mirror preflight: B — app mmap %zu MB R+X + debugger bless", size >> 20);
    void *rxB = mmap(NULL, size, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (rxB == MAP_FAILED) {
        NSLog(@"[JIT26] mirror preflight: B mmap failed: %s — skipping to C", strerror(errno));
        rxB = NULL;
    } else {
        NSLog(@"[JIT26] mirror preflight: B mapped at %p, blessing via prepare_memory_region", rxB);
        JIT26PrepareRegion(rxB, size);
        if (jit_write_stub_via_alias(rxB, size)) {
            int resultB = jit_run_guarded_stub(rxB);
            if (resultB == 42) {
                NSLog(@"[JIT26] mirror preflight: B OK at %p (%zu MB, blessed + executable)", rxB, size >> 20);
                JIT26OfferMirrorRegion(rxB, size);
                NSLog(@"[JIT26] mirror preflight: offered region to script (cmd 5)");
                uintptr_t echoB = (uintptr_t)JIT26VerifyMirrorOffer(NULL);
                BOOL verifiedB = (echoB == (uintptr_t)rxB);
                NSLog(@"[JIT26] mirror preflight: B offer echo=0x%lx verified=%d%s", (unsigned long)echoB, verifiedB,
                      verifiedB ? "" : " (script did not take the offer — stale assigned script or extension not evaluated?)");
                JITReportLine(@"mirror_region=B:%p:%zu offer_echo=0x%lx offer_verify=%d", rxB, size >> 20, (unsigned long)echoB, verifiedB);
                if (outAddr) {
                    *outAddr = rxB;
                }
                return YES;
            }
            NSLog(@"[JIT26] mirror preflight: B probe of %p returned %d (want 42)", rxB, resultB);
        }
        NSLog(@"[JIT26] mirror preflight: B region %p is NOT executable — trying C", rxB);
        munmap(rxB, size);
    }

    // Strategy C: force a LOW placement. On the A13 both A (_M) and B (our own
    // R+X mmap) land in the high 0x7000_0000_0000 band where iOS 27 refuses to
    // execute anything. Low regions do execute (small preflight, DyldLVBypass,
    // iPhone13,4 A at 0x15a8_d8000), so place the mapping there explicitly.
    NSLog(@"[JIT26] mirror preflight: C — searching for a low %zu MB hole below 0x7000000000", size >> 20);
    vm_address_t gaps[8] = {0};
    int regionsWalked = 0;
    vm_size_t largestGap = 0;
    vm_address_t largestGapAt = 0;
    int gapCount = jit26_find_low_gaps(size, gaps, 3, &regionsWalked, &largestGap, &largestGapAt);
    NSLog(@"[JIT26] mirror preflight: C scan walked %d regions; largest low gap 0x%lx at 0x%lx (need 0x%zx)",
          regionsWalked, (unsigned long)largestGap, (unsigned long)largestGapAt, size);
    uintptr_t cTries[8];
    int cN = 0;
    for (int i = 0; i < gapCount && cN < 5; i++) {
        cTries[cN++] = (uintptr_t)gaps[i];
    }
    static const uintptr_t cFallback[] = {
        0x120000000ULL, 0x140000000ULL, 0x160000000ULL, 0x200000000ULL,
    };
    for (size_t i = 0; i < sizeof(cFallback) / sizeof(cFallback[0]) && cN < 8; i++) {
        cTries[cN++] = cFallback[i];
    }
    for (int gi = 0; gi < cN; gi++) {
        NSLog(@"[JIT26] mirror preflight: C hint mmap at 0x%lx (try %d/%d)", (unsigned long)cTries[gi], gi + 1, cN);
        void *rxC = mmap((void *)cTries[gi], size, PROT_READ | PROT_EXEC,
                         MAP_PRIVATE | MAP_ANON, -1, 0);
        if (rxC == MAP_FAILED) {
            NSLog(@"[JIT26] mirror preflight: C hint mmap failed: %s", strerror(errno));
            continue;
        }
        if ((uintptr_t)rxC >= 0x7000000000ULL) {
            NSLog(@"[JIT26] mirror preflight: C kernel ignored low hint, mapped high at %p — munmap", rxC);
            munmap(rxC, size);
            continue;
        }
        if (jit26_finish_mirror_region(rxC, size, "C")) {
            if (outAddr) {
                *outAddr = rxC;
            }
            return YES;
        }
        munmap(rxC, size);
    }
    for (int gi = 0; gi < cN; gi++) {
        vm_address_t reserve = cTries[gi];
        kern_return_t ar = vm_allocate(mach_task_self(), &reserve, size, VM_FLAGS_FIXED);
        if (ar != KERN_SUCCESS) {
            NSLog(@"[JIT26] mirror preflight: C fixed reserve at 0x%lx failed: 0x%x", (unsigned long)cTries[gi], ar);
            continue;
        }
        int mret = mprotect((void *)reserve, size, PROT_READ | PROT_EXEC);
        if (mret != 0) {
            NSLog(@"[JIT26] mirror preflight: C mprotect(RX) at 0x%lx failed: %s", (unsigned long)reserve, strerror(errno));
            vm_deallocate(mach_task_self(), reserve, size);
            continue;
        }
        if (jit26_finish_mirror_region((void *)reserve, size, "C")) {
            if (outAddr) {
                *outAddr = (void *)reserve;
            }
            return YES;
        }
        vm_deallocate(mach_task_self(), reserve, size);
    }
    NSLog(@"[JIT26] mirror preflight: C found no executable low region — no offer; "
          @"JVM falls back to its own _M flow (will SIGBUS on high-band TXM devices)");
    JITReportLine(@"mirror_region=none");
    return NO;
}
