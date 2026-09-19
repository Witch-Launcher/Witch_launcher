#pragma once

// Periodic phys_footprint sampler for Jetsam diagnosis.
// Started once when the game JVM launches; logs one line per interval so the
// footprint curve (native + GPU/IOKit, invisible to JVM heap stats) can be
// correlated with game log events (world join, chunk builds, etc.).
void WitchMemSamplerStart(void);

// Immediate one-shot sample with a tag (e.g. world-join markers).
void WitchMemSampleMark(const char *tag);
