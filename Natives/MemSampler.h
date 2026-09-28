#pragma once

#import <Foundation/Foundation.h>

// Periodic phys_footprint sampler for Jetsam diagnosis.
// Started once when the game JVM launches; logs one line per interval so the
// footprint curve (native + GPU/IOKit, invisible to JVM heap stats) can be
// correlated with game log events (world join, chunk builds, etc.).
// Master switch for the whole sampler (memory-measurement logging).
// Must be called before WitchMemSamplerStart; when NO, Start does nothing
// and Mark is a no-op (zero log lines, zero timer, zero MobileGL dumps).
void WitchMemSamplerSetEnabled(BOOL enabled);
void WitchMemSamplerStart(void);

// Immediate one-shot sample with a tag (e.g. world-join markers).
void WitchMemSampleMark(const char *tag);

// Stop the periodic sampler during crash/abort paths: malloc_zone_statistics
// and NSLog re-enter JVM signal handlers (JVM_handle_bsd_signal ->
// VMError::report_and_die) and fight over the malloc zone lock, which is how
// a single native fault turns into stack-guard recursion across threads.
void WitchMemSamplerNoteCrash(void);
