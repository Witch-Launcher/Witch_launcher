#pragma once

#import <Foundation/Foundation.h>

// Persistent performance recorder: one session per game launch, sampled at
// 1 Hz into <POJAV_HOME>/.amethyst/perf/<id>/ (meta.json + samples.csv).
// Samples are flushed to disk as they are taken, so a session survives a
// crash, a jetsam kill or a force close; leftover "recording" sessions are
// finalized as "crashed"/"interrupted" on the next app launch.
// Metric identifiers in CSV column order: fps, cpu, gpu, ram, devram,
// battery, battemp, thermal. Pref key for each metric is "perf.metric_<name>".
NSArray<NSString *> *PerfMetricNames(void);

typedef NS_ENUM(NSInteger, PerfStopReason) {
    PerfStopReasonUser = 0,   // user pressed "stop recording" in-game
    PerfStopReasonExited,     // JVM returned (game closed normally)
    PerfStopReasonForceClose, // force close menu item
    PerfStopReasonCrash,      // fatal exit / crash handler fired
};

@interface PerfRecorder : NSObject

+ (instancetype)shared;

@property(readonly) BOOL isRecording;

// Starts a session (no-op when disabled by pref or already recording).
// Safe to call from any thread. metadata may carry @"version" / @"instance".
- (void)startWithMetadata:(NSDictionary *)metadata;

// Manual start from the in-game menu: ignores the "perf.record" launch pref
// (that pref only controls automatic recording on every launch). No-op when
// already recording. Safe to call from any thread.
- (void)startManuallyWithMetadata:(NSDictionary *)metadata;

// Finalizes the active session. Safe to call from any thread; no-op when
// nothing is being recorded. A pending crash note overrides the reason.
- (void)stopWithReason:(PerfStopReason)reason;

// Flags that the process is about to die from a crash/fatal exit; the next
// stopWithReason: (or the next-launch sweep) will label the session crashed.
- (void)noteCrash;

+ (NSString *)perfDirectory;

// Marks every leftover "recording" session as crashed/interrupted. Safe to
// call repeatedly; also called automatically when a new session starts.
+ (void)finalizeDanglingSessions;

@end
