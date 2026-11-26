#pragma once

#import <Foundation/Foundation.h>

// React to iOS memory pressure and to the sampler's 75%/90% Jetsam
// thresholds. Safe to call from any thread: UI/cache work is marshalled to
// the main queue, and the optional Java GC runs on a utility queue.
//
// critical == YES also requests one System.gc() (rate-limited) so direct
// ByteBuffer cleaners can release LWJGL/Sodium/Iris memory before Jetsam
// kills the process. non-critical only trims caches/logs.
void WitchMemoryPressureHandle(BOOL critical);
