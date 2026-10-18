#ifndef WitchJREPatcher_h
#define WitchJREPatcher_h

#include <stdbool.h>

/// Status of the bundled/downloaded libjvm.dylib JIT mirror support.
/// The launcher refuses runtimes without the mirror brk hooks on iOS 26+,
/// because the JVM's code-cache allocation goes through those breakpoints.
typedef enum {
    WitchJREMirrorStatusMissingLibjvm = 3, // lib/server/libjvm.dylib not readable
    WitchJREMirrorStatusNoMirrorCode = 2,  // libjvm has no JIT26 mirror build at all
    WitchJREMirrorStatusPatchable = 1,     // mirror code present, brk hooks missing
    WitchJREMirrorStatusHooksPresent = 0,  // brk #0x6a + brk #0xf00d present
} WitchJREMirrorStatus;

/// Inspect `<jreDir>/lib/server/libjvm.dylib`.
WitchJREMirrorStatus witch_jre_libjvm_mirror_status(const char *jreDir);

/// C port of scripts/patch_libjvm_mirror_brk.py — replace the mirror-mapping
/// printf call with `brk #0x6a`. Idempotent.
bool witch_jre_patch_libjvm_mirror_brk(const char *libjvmPath);

/// C port of scripts/patch_libjvm_jit_alloc.py — route the JIT superpage
/// allocation through `brk #0xf00d` and save/restore the mapping size around
/// printf. Idempotent.
bool witch_jre_patch_libjvm_jit_alloc(const char *libjvmPath);

/// Make an extracted runtime usable for the iOS 26+ mirror JIT path:
///   1. hooks already present -> only (re)write the marker -> true
///   2. mirror code present  -> apply both brk patches, re-verify, then
///      write `.witch-mirror-mapping` -> true
///   3. no mirror code       -> false, NO marker written (launcher shows the
///      "runtime does not support JIT" dialog instead of black-screening)
bool witch_jre_ensure_jit_ready(const char *jreDir);

#endif /* WitchJREPatcher_h */
