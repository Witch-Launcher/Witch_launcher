#import "utils.h"
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <mach-o/getsect.h>
#include <mach-o/dyld.h>
#include <mach/vm_map.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <string.h>
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

void verify_libjvm_mirror_brk_patch(void) {
    if (!DeviceNeedsDebugJITMapping()) {
        return;
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
            return;
        }
        if (*site == kMirrorBrk0x6a) {
            NSLog(@"[JIT26] libjvm mirror brk #0x6a patch verified at %p in %s", site, name);
        } else {
            NSLog(@"[JIT26] ERROR: libjvm mirror brk patch missing at %p in %s (insn=%#x, expected brk #0x6a). "
                  @"Run scripts/patch_libjvm_mirror_brk.py on bundled runtimes.",
                  site, name, *site);
        }
        return;
    }
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