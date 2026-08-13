#import "utils.h"
#include "external/fishhook/fishhook.h"
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

typedef kern_return_t (*vm_remap_fn)(
    vm_map_t target_task,
    vm_address_t *target_address,
    vm_size_t size,
    vm_offset_t mask,
    int flags,
    vm_map_t src_task,
    vm_address_t src_address,
    boolean_t copy,
    vm_prot_t *cur_protection,
    vm_prot_t *max_protection,
    vm_inherit_t inheritance);

typedef kern_return_t (*mach_vm_remap_fn)(
    vm_map_t target_task,
    mach_vm_address_t *target_address,
    mach_vm_size_t size,
    mach_vm_offset_t mask,
    int flags,
    vm_map_t src_task,
    mach_vm_address_t src_address,
    boolean_t copy,
    vm_prot_t *cur_protection,
    vm_prot_t *max_protection,
    vm_inherit_t inheritance);

typedef kern_return_t (*vm_protect_fn)(
    vm_map_t target_task,
    vm_address_t address,
    vm_size_t size,
    boolean_t set_maximum,
    vm_prot_t new_protection);

static vm_remap_fn real_vm_remap;
static mach_vm_remap_fn real_mach_vm_remap;
static vm_protect_fn real_vm_protect;
static int (*real_vprintf)(const char *restrict, va_list);
static vm_address_t g_lastPreparedRx;
static vm_size_t g_lastPreparedSize;
static atomic_bool g_pollThreadStarted;
static atomic_bool g_dyldHookRegistered;

static void rebind_vm_hooks_in_image(const struct mach_header *header, intptr_t slide, const char *name);

static void prepareMirrorPair(vm_address_t rx, vm_address_t rw, vm_size_t size);

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
    const char *cstring = getsectiondata((const struct mach_header_64 *)header, "__TEXT", "__cstring", &cstringSize);
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
    const char *text = getsectiondata((const struct mach_header_64 *)header, "__TEXT", "__text", &textSize);
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

static BOOL looksLikeJITSuperpage(vm_address_t addr) {
    return addr >= 0x700000000ULL && addr < 0x800000000ULL;
}

static void resolveKernelSymbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *lib = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_NOW);
        if (!lib) {
            NSLog(@"[JIT26] failed to dlopen libsystem_kernel: %s", dlerror());
            return;
        }
        real_vm_remap = (vm_remap_fn)dlsym(lib, "vm_remap");
        real_mach_vm_remap = (mach_vm_remap_fn)dlsym(lib, "mach_vm_remap");
        real_vm_protect = (vm_protect_fn)dlsym(lib, "vm_protect");
        if (!real_vm_remap || !real_mach_vm_remap || !real_vm_protect) {
            NSLog(@"[JIT26] failed to resolve kernel VM symbols");
        }
        if (!real_vprintf) {
            real_vprintf = (int (*)(const char *restrict, va_list))dlsym(RTLD_DEFAULT, "vprintf");
        }
    });
}

static BOOL tryPrepareMirrorFromMappingLog(void *rw, void *rx) {
    if (!DeviceNeedsDebugJITMapping() || !rw || !rx) {
        return NO;
    }
    vm_address_t rwAddr = (vm_address_t)(uintptr_t)rw;
    vm_address_t rxAddr = (vm_address_t)(uintptr_t)rx;
    if (rwAddr <= rxAddr || !looksLikeJITSuperpage(rxAddr)) {
        return NO;
    }
    vm_size_t size = (vm_size_t)(rwAddr - rxAddr);
    if (size < 16 * 1024 * 1024) {
        return NO;
    }
    NSLog(@"[JIT26] mirror setup hook: preparing RX=%p RW=%p size=%zu MB",
          (void *)(uintptr_t)rxAddr, (void *)(uintptr_t)rwAddr, size / (1024 * 1024));
    prepareMirrorPair(rxAddr, rwAddr, size);
    return YES;
}

static int hooked_printf(const char *restrict fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    if (fmt && strstr(fmt, "mapping at RW=%p, RX=%p")) {
        void *rw = va_arg(ap, void *);
        void *rx = va_arg(ap, void *);
        tryPrepareMirrorFromMappingLog(rw, rx);
        va_end(ap);
        va_start(ap, fmt);
    }
    if (!real_vprintf) {
        va_end(ap);
        return 0;
    }
    int result = real_vprintf(fmt, ap);
    va_end(ap);
    return result;
}

static BOOL looksLikeMirrorCodeCacheRemap(vm_address_t src, vm_size_t size) {
    if (size < 16 * 1024 * 1024) {
        return NO;
    }
    return looksLikeJITSuperpage(src);
}

static BOOL looksLikeMirrorRWProtect(vm_address_t addr, vm_size_t size, vm_prot_t prot) {
    if (size < 16 * 1024 * 1024) {
        return NO;
    }
    if ((prot & VM_PROT_WRITE) == 0 || (prot & VM_PROT_EXECUTE) != 0) {
        return NO;
    }
    if (!looksLikeJITSuperpage(addr)) {
        return NO;
    }
    vm_address_t rx = addr - size;
    return looksLikeJITSuperpage(rx);
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

static void prepareMirrorPair(vm_address_t rx, vm_address_t rw, vm_size_t size) {
    AmethystJIT26PrepareMirrorPair((void *)rx, (void *)rw, (size_t)size);
}

static BOOL regionCoversAddress(vm_address_t addr, vm_size_t minSize) {
    vm_address_t query = addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object;

    kern_return_t kr = vm_region_64(
        mach_task_self(), &query, &size, VM_REGION_BASIC_INFO_64,
        (vm_region_info_64_t)&info, &count, &object);
    return kr == KERN_SUCCESS && query <= addr && addr < query + size && size >= minSize;
}

static BOOL tryPrepareKnownMirrorLayout(void) {
    vm_address_t rx = 0x700000000ULL;
    vm_address_t rw = 0x700f000000ULL;
    vm_size_t size = 0xf000000ULL;

    if (!regionCoversAddress(rx, size) || !regionCoversAddress(rw, size)) {
        return NO;
    }
    prepareMirrorPair(rx, rw, size);
    return YES;
}

static kern_return_t hooked_vm_remap(
    vm_map_t target_task,
    vm_address_t *target_address,
    vm_size_t size,
    vm_offset_t mask,
    int flags,
    vm_map_t src_task,
    vm_address_t src_address,
    boolean_t copy,
    vm_prot_t *cur_protection,
    vm_prot_t *max_protection,
    vm_inherit_t inheritance) {
    resolveKernelSymbols();
    if (!real_vm_remap) {
        return KERN_FAILURE;
    }

    kern_return_t result = real_vm_remap(
        target_task, target_address, size, mask, flags, src_task, src_address, copy,
        cur_protection, max_protection, inheritance);

    if (result != KERN_SUCCESS || target_address == NULL) {
        return result;
    }

    if (looksLikeMirrorCodeCacheRemap(src_address, size)) {
        NSLog(@"[JIT26] vm_remap mirror: RX=%p RW=%p size=%zu MB",
              (void *)(uintptr_t)src_address, (void *)(uintptr_t)*target_address, size / (1024 * 1024));
        prepareMirrorPair(src_address, *target_address, size);
    }
    return result;
}

static kern_return_t hooked_mach_vm_remap(
    vm_map_t target_task,
    mach_vm_address_t *target_address,
    mach_vm_size_t size,
    mach_vm_offset_t mask,
    int flags,
    vm_map_t src_task,
    mach_vm_address_t src_address,
    boolean_t copy,
    vm_prot_t *cur_protection,
    vm_prot_t *max_protection,
    vm_inherit_t inheritance) {
    resolveKernelSymbols();
    if (!real_mach_vm_remap) {
        return KERN_FAILURE;
    }

    kern_return_t result = real_mach_vm_remap(
        target_task, target_address, size, mask, flags, src_task, src_address, copy,
        cur_protection, max_protection, inheritance);

    if (result != KERN_SUCCESS || target_address == NULL) {
        return result;
    }

    if (looksLikeMirrorCodeCacheRemap((vm_address_t)src_address, (vm_size_t)size)) {
        NSLog(@"[JIT26] mach_vm_remap mirror: RX=%p RW=%p size=%zu MB",
              (void *)(uintptr_t)src_address, (void *)(uintptr_t)*target_address, (size_t)size / (1024 * 1024));
        prepareMirrorPair((vm_address_t)src_address, (vm_address_t)*target_address, (vm_size_t)size);
    }
    return result;
}

static kern_return_t hooked_vm_protect(
    vm_map_t target_task,
    vm_address_t address,
    vm_size_t size,
    boolean_t set_maximum,
    vm_prot_t new_protection) {
    resolveKernelSymbols();
    if (!real_vm_protect) {
        return KERN_FAILURE;
    }

    kern_return_t result = real_vm_protect(target_task, address, size, set_maximum, new_protection);
    if (result == KERN_SUCCESS && looksLikeMirrorRWProtect(address, size, new_protection)) {
        vm_address_t rx = address - size;
        NSLog(@"[JIT26] vm_protect mirror RW=%p RX=%p size=%zu MB",
              (void *)(uintptr_t)address, (void *)(uintptr_t)rx, size / (1024 * 1024));
        prepareMirrorPair(rx, address, size);
    }
    return result;
}

static BOOL findMirrorMapping(vm_address_t *out_rx, vm_address_t *out_rw, vm_size_t *out_size) {
    vm_address_t cursor = 0x700000000ULL;
    const vm_address_t limit = 0x800000000ULL;

    while (cursor < limit) {
        vm_address_t region_start = cursor;
        vm_size_t region_size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        memory_object_name_t object;

        kern_return_t kr = vm_region_64(
            mach_task_self(), &region_start, &region_size, VM_REGION_BASIC_INFO_64,
            (vm_region_info_64_t)&info, &count, &object);
        if (kr != KERN_SUCCESS) {
            break;
        }

        if (region_start >= 0x700000000ULL && region_size >= 16 * 1024 * 1024) {
            vm_address_t rw_candidate = region_start + region_size;
            vm_address_t rw_query = rw_candidate;
            vm_size_t rw_size = 0;
            vm_region_basic_info_data_64_t rw_info;
            mach_msg_type_number_t rw_count = VM_REGION_BASIC_INFO_COUNT_64;
            memory_object_name_t rw_object;

            kr = vm_region_64(
                mach_task_self(), &rw_query, &rw_size, VM_REGION_BASIC_INFO_64,
                (vm_region_info_64_t)&rw_info, &rw_count, &rw_object);
            if (kr == KERN_SUCCESS && rw_query <= rw_candidate && rw_candidate < rw_query + rw_size
                && (rw_info.protection & VM_PROT_WRITE) && !(rw_info.protection & VM_PROT_EXECUTE)) {
                *out_rx = region_start;
                *out_rw = rw_candidate;
                *out_size = region_size;
                return YES;
            }
        }

        vm_address_t next = region_start + region_size;
        if (next <= cursor) {
            break;
        }
        cursor = next;
    }
    return NO;
}

static void *mirror_prepare_poll_thread(void *arg) {
    (void)arg;
    for (int attempt = 0; attempt < 20000; attempt++) {
        if (tryPrepareKnownMirrorLayout()) {
            return NULL;
        }
        vm_address_t rx = 0;
        vm_address_t rw = 0;
        vm_size_t size = 0;
        if (findMirrorMapping(&rx, &rw, &size)) {
            prepareMirrorPair(rx, rw, size);
            return NULL;
        }
        usleep(500);
    }
    NSLog(@"[JIT26] mirror prepare poll thread timed out");
    return NULL;
}

void start_jit_mirror_prepare_poll_thread(void) {
    if (!DeviceNeedsDebugJITMapping()) {
        return;
    }
    bool expected = false;
    if (!atomic_compare_exchange_strong(&g_pollThreadStarted, &expected, true)) {
        return;
    }
    pthread_t thread;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    if (pthread_create(&thread, &attr, mirror_prepare_poll_thread, NULL) != 0) {
        atomic_store(&g_pollThreadStarted, false);
        NSLog(@"[JIT26] failed to start mirror prepare poll thread");
    } else {
        NSLog(@"[JIT26] mirror prepare poll thread started");
    }
    pthread_attr_destroy(&attr);
}

static void rebind_vm_hooks_in_image(const struct mach_header *header, intptr_t slide, const char *name) {
    if (!name || !strstr(name, "libjvm.dylib")) {
        return;
    }
    struct rebinding rebindings[] = {
        {"vm_remap", hooked_vm_remap, NULL},
        {"mach_vm_remap", hooked_mach_vm_remap, NULL},
        {"vm_protect", hooked_vm_protect, NULL},
        {"printf", hooked_printf, NULL},
    };
    int result = rebind_symbols_image((void *)header, slide, rebindings, 4);
    NSLog(@"[JIT26] fishhook rebind in %s -> %d", name, result);
}

static void rebind_vm_hooks_on_image_load(const struct mach_header *header, intptr_t slide) {
    if (!DeviceNeedsDebugJITMapping()) {
        return;
    }
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (_dyld_get_image_header(i) == header) {
            rebind_vm_hooks_in_image(header, slide, _dyld_get_image_name(i));
            return;
        }
    }
}

void rebind_jit_vm_hooks_after_libjvm_load(void) {
    if (!DeviceNeedsDebugJITMapping()) {
        return;
    }
    resolveKernelSymbols();
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "libjvm.dylib")) {
            rebind_vm_hooks_in_image(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i), name);
        }
    }
}

void init_jit_vm_remap_hook(void) {
    resolveKernelSymbols();
    struct rebinding rebindings[] = {
        {"vm_remap", hooked_vm_remap, NULL},
        {"mach_vm_remap", hooked_mach_vm_remap, NULL},
        {"vm_protect", hooked_vm_protect, NULL},
        {"printf", hooked_printf, NULL},
    };
    if (rebind_symbols(rebindings, 4) != 0) {
        NSLog(@"[JIT26] fishhook vm_remap/vm_protect registration failed");
        return;
    }
    bool expected = false;
    if (atomic_compare_exchange_strong(&g_dyldHookRegistered, &expected, true)) {
        _dyld_register_func_for_add_image(rebind_vm_hooks_on_image_load);
    }
    NSLog(@"[JIT26] fishhook vm_remap/mach_vm_remap/vm_protect/printf registered");
}
