#import "utils.h"
#include "external/fishhook/fishhook.h"
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach/vm_map.h>
#include <pthread.h>
#include <stdatomic.h>

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

typedef kern_return_t (*vm_protect_fn)(
    vm_map_t target_task,
    vm_address_t address,
    vm_size_t size,
    boolean_t set_maximum,
    vm_prot_t new_protection);

static vm_remap_fn real_vm_remap;
static vm_protect_fn real_vm_protect;
static vm_address_t g_lastPreparedRx;
static vm_size_t g_lastPreparedSize;
static atomic_bool g_pollThreadStarted;
static atomic_bool g_dyldHookRegistered;

static void rebind_vm_hooks_in_image(const struct mach_header *header, intptr_t slide, const char *name);

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
        real_vm_protect = (vm_protect_fn)dlsym(lib, "vm_protect");
        if (!real_vm_remap || !real_vm_protect) {
            NSLog(@"[JIT26] failed to resolve kernel VM symbols");
        }
    });
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
        prepareMirrorPair(src_address, *target_address, size);
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
        prepareMirrorPair(address - size, address, size);
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

        if (region_start >= 0x700000000ULL && region_size >= 16 * 1024 * 1024
            && (info.protection & VM_PROT_EXECUTE)) {
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
        {"vm_protect", hooked_vm_protect, NULL},
    };
    int result = rebind_symbols_image((void *)header, slide, rebindings, 2);
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
        {"vm_protect", hooked_vm_protect, NULL},
    };
    if (rebind_symbols(rebindings, 2) != 0) {
        NSLog(@"[JIT26] fishhook vm_remap/vm_protect registration failed");
        return;
    }
    bool expected = false;
    if (atomic_compare_exchange_strong(&g_dyldHookRegistered, &expected, true)) {
        _dyld_register_func_for_add_image(rebind_vm_hooks_on_image_load);
    }
    NSLog(@"[JIT26] fishhook vm_remap/vm_protect registered");
}
