#import <Foundation/Foundation.h>
#import "PLLogOutputView.h"
#import "SurfaceViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "mach_excServer.h"
#import "MemSampler.h"

#include <dlfcn.h>
#include <libgen.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "external/fishhook/fishhook.h"

#if __has_include(<execinfo.h>)
#include <execinfo.h>
#define WITCH_HAVE_BACKTRACE 1
#endif

mach_port_t excPort;
void *hooked_dlopen_26_ppl(const char *path, int mode);

void (*orig_abort)();
void (*orig_exit)(int code);
void* (*orig_dlopen)(const char* path, int mode);
int (*orig_open)(const char *path, int oflag, ...);

void crashScreenCloseLauncher(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication.sharedApplication performSelector:@selector(suspend)];
    });
    usleep(300*1000);
    if (fatalExitGroup != nil) {
        dispatch_group_leave(fatalExitGroup);
    } else {
        orig_exit(0);
    }
}

void handle_fatal_exit(int code) {
    if (NSThread.isMainThread) {
        return;
    }

    [PLLogOutputView handleExitCode:code];

    if (fatalExitGroup != nil) {
        // Likely other threads are crashing, put them to sleep
        sleep(INT_MAX);
    }
    fatalExitGroup = dispatch_group_create();
    dispatch_group_enter(fatalExitGroup);
    dispatch_group_wait(fatalExitGroup, DISPATCH_TIME_FOREVER);
}

void hooked_abort() {
    // abort() is often entered from a signal/crash reporter (HotSpot
    // VMError::report_and_die → os::die). NSLog / malloc / ObjC here
    // re-enters the same handlers until the stack guard is hit.
    static volatile sig_atomic_t in_abort;
    if (in_abort) {
        if (orig_abort) {
            orig_abort();
        }
        _exit(128 + SIGABRT);
    }
    in_abort = 1;
    WitchMemSamplerNoteCrash();
    static const char msg[] = "abort() called\n";
    (void)write(STDERR_FILENO, msg, sizeof(msg) - 1);
    if (orig_abort) {
        orig_abort();
    }
    _exit(128 + SIGABRT);
}

void hooked___assert_rtn(const char* func, const char* file, int line, const char* failedexpr)
{
    // fprintf/malloc here re-enters JVM signal handlers the same way
    // customNSLog did — format on the stack and write(2) only.
    char buf[512];
    int n;
    if (func == NULL) {
        n = snprintf(buf, sizeof(buf),
            "Assertion failed: (%s), file %s, line %d.\n",
            failedexpr ? failedexpr : "?",
            file ? file : "?", line);
    } else {
        n = snprintf(buf, sizeof(buf),
            "Assertion failed: (%s), function %s, file %s, line %d.\n",
            failedexpr ? failedexpr : "?",
            func, file ? file : "?", line);
    }
    if (n > 0) {
        (void)write(STDERR_FILENO, buf, (size_t)(n < (int)sizeof(buf) ? n : (int)sizeof(buf)));
    }
    hooked_abort();
}

void hooked_exit(int code) {
    // exit() can be reached from JVM fatal-error paths (System.exit during
    // VMError handling). backtrace_symbols() mallocs and customNSLog retains
    // ObjC objects — both re-enter JVM_handle_bsd_signal until the stack
    // guard is hit. So: write(2) only, dladdr() only, no NSString here.
    {
        char hdr[64];
        int n = snprintf(hdr, sizeof(hdr), "exit(%d) called\n", code);
        if (n > 0) {
            (void)write(STDERR_FILENO, hdr, (size_t)(n < (int)sizeof(hdr) ? n : (int)sizeof(hdr)));
        }
    }
#ifdef WITCH_HAVE_BACKTRACE
    // exit(0) during the loading screen means SOMEONE decided to quit
    // (game, launcher or user action) — the log never said who. Dump the
    // caller chain before suspending so the next latestlog names it.
    // NOTE: backtrace() + dladdr() only. backtrace_symbols() is deliberately
    // NOT used: it mallocs and deadlocks against the malloc zone lock when
    // exit() races a crash on another thread.
    {
        void *frames[32];
        int n = backtrace(frames, 32);
        char line[256];
        int limit = n < 12 ? n : 12;
        for (int i = 0; i < limit; i++) {
            Dl_info info;
            int m;
            if (dladdr(frames[i], &info) != 0 && info.dli_sname != NULL) {
                long long off = (long long)((char *)frames[i] - (char *)info.dli_saddr);
                m = snprintf(line, sizeof(line), "  exit-bt #%d %s (+%lld) %p\n",
                             i, info.dli_sname, off, frames[i]);
            } else {
                m = snprintf(line, sizeof(line), "  exit-bt #%d %p\n", i, frames[i]);
            }
            if (m > 0) {
                (void)write(STDERR_FILENO, line, (size_t)(m < (int)sizeof(line) ? m : (int)sizeof(line)));
            }
        }
    }
#endif
    if (code == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication.sharedApplication performSelector:@selector(suspend)];
        });
        usleep(100*1000);
        orig_exit(0);
        return;
    }
    // Give the stdout/stderr pipe read thread time to flush so we capture
    // any Java exception stack traces logged right before System.exit().
    // Stop the mem sampler first: its malloc_zone_statistics fights over the
    // malloc zone lock while other threads may be crashing concurrently.
    WitchMemSamplerNoteCrash();
    usleep(500*1000);
    handle_fatal_exit(code);
    orig_exit(code);
}

static const char *signedMoltenVKPath(const char *requested) {
    if (!requested) {
        return NULL;
    }
    const char *base = strrchr(requested, '/');
    base = base ? base + 1 : requested;
    BOOL want12 = strcmp(base, "libMoltenVK12.dylib") == 0;
    if (!want12 && strcmp(base, "libMoltenVK.dylib") != 0) {
        return NULL;
    }
    if (strstr(requested, "/Frameworks/")) {
        return NULL;
    }
    static char path14[PATH_MAX];
    static char path12[PATH_MAX];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
        snprintf(path14, sizeof(path14), "%s/libMoltenVK.dylib", frameworks.UTF8String);
        snprintf(path12, sizeof(path12), "%s/libMoltenVK12.dylib", frameworks.UTF8String);
    });
    if (want12 && access(path12, F_OK) == 0) {
        return path12;
    }
    if (access(path14, F_OK) == 0) {
        return path14;
    }
    return NULL;
}

void* hooked_dlopen(const char* path, int mode) {
    const char *mvk = signedMoltenVKPath(path);
    if (mvk) {
        // Java-level error messages print the originally requested path, so
        // log the redirect here — otherwise a natives-dir path in
        // UnsatisfiedLinkError looks like the hook never ran.
        static char lastLogged[PATH_MAX];
        if (strcmp(mvk, lastLogged) != 0) {
            snprintf(lastLogged, sizeof(lastLogged), "%s", mvk);
            NSLog(@"[MoltenVK] dlopen redirect: %s → %s", path, mvk);
        }
        path = mvk;
    }
    BOOL shouldUseDyldBypass26PPL = NO;
    if (DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED)) {
        shouldUseDyldBypass26PPL = hwRedirectOrig[0] && !DeviceHasJITFlags(JIT_FLAG_HAS_TXM);
    }
    // Only patch Mach-O and use dyld bypass dylib is in the home dir
    // or tmp dir: LiveContainer makes a symlink to its own tmp dir so checking home dir alone would fail
    const char *home = getenv("HOME");
    const char *tmp = getenv("TMPDIR");
    char fullpath[PATH_MAX];
    BOOL shouldUseDyldBypass = path && realpath(path, fullpath) && (strstr(fullpath, home) || strstr(fullpath, tmp));
    shouldUseDyldBypass26PPL &= shouldUseDyldBypass;
    if (shouldUseDyldBypass) {
        PLPatchMachOPlatformForFile(path);
    }
    if (shouldUseDyldBypass26PPL) {
        __attribute__((musttail)) return hooked_dlopen_26_ppl(path, mode);
    } else if (shouldUseDyldBypass) {
        /// Special case for LiveContainer multitask mode where it hooks dlopen to hook mmap, which will break this dyld bypass, so we redirect calls to the original dlopen.
        static void *(*sys_dlopen)(const char *, int);
        if(!sys_dlopen) sys_dlopen = dlsym(RTLD_NEXT, "dlopen");
        __attribute__((musttail)) return sys_dlopen(path, mode);
    } else {
        __attribute__((musttail)) return orig_dlopen(path, mode);
    }
}
// hack dlopen for non-TXM 26.x
void *exception_handler(void *unused) {
    mach_msg_server(mach_exc_server, sizeof(union __RequestUnion__catch_mach_exc_subsystem), excPort, MACH_MSG_OPTION_NONE);
    abort();
}
void *hooked_dlopen_26_ppl(const char *path, int mode) {
    if (!excPort) {
        mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &excPort);
        mach_port_insert_right(mach_task_self(), excPort, excPort, MACH_MSG_TYPE_MAKE_SEND);
        pthread_t thread;
        pthread_create(&thread, NULL, exception_handler, NULL);
    }
    
    // save old thread states
    exception_mask_t mask = EXC_MASK_BREAKPOINT;
    mach_msg_type_number_t masksCnt = 1;
    exception_handler_t handler = excPort;
    exception_behavior_t behavior = EXCEPTION_STATE | MACH_EXCEPTION_CODES;
    thread_state_flavor_t flavor = ARM_THREAD_STATE64;
    arm_debug_state64_t origDebugState;
    mach_port_t thread = mach_thread_self();
    thread_get_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&origDebugState, &(mach_msg_type_number_t){ARM_DEBUG_STATE64_COUNT});
    thread_swap_exception_ports(thread, mask, handler, behavior, flavor, &mask, &masksCnt, &handler, &behavior, &flavor);
    if (masksCnt != 1) {
        NSLog(@"main_hook: Expected 1 exception port, got %d. HW breakpoint hook may fail.", masksCnt);
    }
    
    // hook stuff. this will overwrite LiveContainer private container multitask's hook, we will load __TEXT using JIT inside
    arm_debug_state64_t hookDebugState = {0};
    for(int i = 0; i < 6 && hwRedirectOrig[i]; i++) {
        hookDebugState.__bvr[i] = (uint64_t)hwRedirectOrig[i];
        hookDebugState.__bcr[i] = 0x1e5;
    }
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&hookDebugState, ARM_DEBUG_STATE64_COUNT);
    
    // fixup @loader_path since we cannot use musttail here
    void *result;
    void *callerAddr = __builtin_return_address(0);
    struct dl_info info;
    if (path && !strncmp(path, "@loader_path/", 13) && dladdr(callerAddr, &info)) {
        char resolvedPath[PATH_MAX];
        snprintf(resolvedPath, sizeof(resolvedPath), "%s/%s", dirname((char *)info.dli_fname), path + 13);
        result = orig_dlopen(resolvedPath, mode);
    } else {
        result = orig_dlopen(path, mode);
    }
    
    // restore old thread states
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&origDebugState, ARM_DEBUG_STATE64_COUNT);
    thread_swap_exception_ports(thread, mask, handler, behavior, flavor, &mask, &masksCnt, &handler, &behavior, &flavor);
    
    return result;
}
kern_return_t catch_mach_exception_raise_state( mach_port_t exception_port, exception_type_t exception, const mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, const thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    arm_thread_state64_t *old = (arm_thread_state64_t *)old_state;
    arm_thread_state64_t *new = (arm_thread_state64_t *)new_state;
    uint64_t pc = arm_thread_state64_get_pc(*old);
    
    for(int i = 0; i < 6 && hwRedirectOrig[i]; i++) {
        if(pc == (uint64_t)hwRedirectOrig[i]) {
            *new = *old;
            *new_stateCnt = old_stateCnt;
            arm_thread_state64_set_pc_fptr(*new, hwRedirectTarget[i]);
            return KERN_SUCCESS;
        }
    }
    NSLog(@"[DyldLVBypass] Unknown breakpoint at pc: %p", (void*)pc);
    return KERN_FAILURE;
}
kern_return_t catch_mach_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt) {
    abort();
}
kern_return_t catch_mach_exception_raise_state_identity(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    abort();
}

int hooked_open(const char *path, int oflag, ...) {
    va_list args;
    va_start(args, oflag);
    mode_t mode = va_arg(args, int);
    va_end(args);
    if (path && !strcmp(path, "/etc/resolv.conf")) {
        return orig_open([NSString stringWithFormat:@"%s/resolv.conf", getenv("POJAV_HOME")].UTF8String, oflag, mode);
    }

    return orig_open(path, oflag, mode);
}

void init_hookFunctions() {
    struct rebinding rebindings[] = (struct rebinding[]){
        {"abort", hooked_abort, (void *)&orig_abort},
        {"__assert_rtn", hooked___assert_rtn, NULL},
        {"exit", hooked_exit, (void *)&orig_exit},
        {"dlopen", hooked_dlopen, (void *)&orig_dlopen},
        {"open", hooked_open, (void *)&orig_open}
    };
    rebind_symbols(rebindings, sizeof(rebindings)/sizeof(struct rebinding));
}
