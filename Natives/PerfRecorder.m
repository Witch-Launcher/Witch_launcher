#import "PerfRecorder.h"

#import "config.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "system_monitor.h"
#import "utils.h"

#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <os/proc.h>
#import <sys/sysctl.h>
#import <unistd.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

extern uint64_t pojavSwapCount(void);

// Metric identifiers: index 0 is the timestamp column, 1...8 match the CSV.
NSArray<NSString *> *PerfMetricNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[@"fps", @"cpu", @"gpu", @"ram", @"devram", @"battery", @"battemp", @"thermal"];
    });
    return names;
}

typedef struct {
    double t;        // ms since session start
    double fps;
    double cpu;      // %
    double gpu;      // %
    double ram;      // MB, launcher phys_footprint
    double avail;    // MB, os_proc_available_memory
    double battery;  // %
    double battTemp; // C
    double thermal;  // 0 nominal / 1 fair / 2 serious / 3 critical
} PerfSample;

static double PerfSampleField(const PerfSample *sample, NSUInteger index) {
    switch (index) {
        case 0: return sample->fps;
        case 1: return sample->cpu;
        case 2: return sample->gpu;
        case 3: return sample->ram;
        case 4: return sample->avail;
        case 5: return sample->battery;
        case 6: return sample->battTemp;
        case 7: return sample->thermal;
    }
    return -1;
}

static NSString *PerfReasonString(PerfStopReason reason) {
    switch (reason) {
        case PerfStopReasonUser: return @"user";
        case PerfStopReasonExited: return @"exit";
        case PerfStopReasonForceClose: return @"force_close";
        case PerfStopReasonCrash: return @"crash";
    }
    return @"unknown";
}

static double PerfCurrentFootprintMB(void) {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
        return -1;
    }
    return (double)info.phys_footprint / (1024.0 * 1024.0);
}

static double PerfCurrentThermalState(void) {
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: return 0;
        case NSProcessInfoThermalStateFair: return 1;
        case NSProcessInfoThermalStateSerious: return 2;
        case NSProcessInfoThermalStateCritical: return 3;
    }
    return -1;
}

@implementation PerfRecorder {
    BOOL _recording;
    BOOL _crashPending;
    NSString *_sessionId;
    NSString *_sessionDir;
    double _startedAtMs;
    NSMutableData *_samples;
    NSFileHandle *_csv;
    NSTimer *_timer;
    uint64_t _lastSwap;
    double _lastSwapMs;
    BOOL _haveSwap;
    NSDictionary *_launchMeta;
    NSDictionary<NSString *, NSNumber *> *_enabledMetrics;
}

+ (instancetype)shared {
    static PerfRecorder *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [PerfRecorder new];
    });
    return shared;
}

+ (NSString *)perfDirectory {
    return amethyst_hidden_dir(@"perf");
}

- (BOOL)isRecording {
    return _recording;
}

#pragma mark - Session lifecycle

- (void)startWithMetadata:(NSDictionary *)metadata {
    [self startWithMetadata:metadata force:NO];
}

- (void)startManuallyWithMetadata:(NSDictionary *)metadata {
    [self startWithMetadata:metadata force:YES];
}

- (void)startWithMetadata:(NSDictionary *)metadata force:(BOOL)force {
    void (^begin)(void) = ^{
        [self beginSession:metadata force:force];
    };
    if (NSThread.isMainThread) {
        begin();
    } else {
        dispatch_async(dispatch_get_main_queue(), begin);
    }
}

- (void)beginSession:(NSDictionary *)metadata force:(BOOL)force {
    if (_recording || (!force && !getPrefBool(@"perf.record"))) {
        return;
    }

    [PerfRecorder finalizeDanglingSessions];

    _launchMeta = metadata ?: @{};
    _crashPending = NO;
    _haveSwap = NO;
    _samples = [NSMutableData new];

    NSDate *now = NSDate.date;
    _startedAtMs = now.timeIntervalSince1970 * 1000.0;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    _sessionId = [NSString stringWithFormat:@"%@-%04X", [formatter stringFromDate:now], (unsigned)arc4random_uniform(0x10000)];

    NSFileManager *fm = NSFileManager.defaultManager;
    _sessionDir = [[PerfRecorder perfDirectory] stringByAppendingPathComponent:_sessionId];
    [fm createDirectoryAtPath:_sessionDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *csvPath = [_sessionDir stringByAppendingPathComponent:@"samples.csv"];
    [fm createFileAtPath:csvPath contents:nil attributes:nil];
    _csv = [NSFileHandle fileHandleForWritingAtPath:csvPath];
    [_csv seekToEndOfFile];
    [_csv writeData:[@"t_ms,fps,cpu_percent,gpu_percent,ram_mb,avail_mb,battery_percent,battery_temp_c,thermal\n"
        dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableDictionary *metrics = [NSMutableDictionary new];
    for (NSString *name in PerfMetricNames()) {
        NSString *prefKey = [@"perf.metric_" stringByAppendingString:name];
        metrics[name] = @(getPrefBool(prefKey));
    }
    _enabledMetrics = metrics;

    _recording = YES;
    [self writeMetaWithStatus:@"recording" reason:nil final:NO];

    _timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    _timer.tolerance = 0.25;
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopWithReason:(PerfStopReason)reason {
    void (^finish)(void) = ^{
        [self finishSession:reason];
    };
    if (NSThread.isMainThread) {
        finish();
    } else {
        dispatch_async(dispatch_get_main_queue(), finish);
    }
}

- (void)finishSession:(PerfStopReason)reason {
    if (!_recording) {
        return;
    }
    _recording = NO;
    [_timer invalidate];
    _timer = nil;

    if (_crashPending) {
        reason = PerfStopReasonCrash;
    }
    NSString *status = (reason == PerfStopReasonCrash) ? @"crashed" : @"done";
    [self writeMetaWithStatus:status reason:PerfReasonString(reason) final:YES];

    [_csv closeFile];
    _csv = nil;
    _sessionId = nil;
    _sessionDir = nil;
    _samples = nil;
    _enabledMetrics = nil;
    _launchMeta = nil;
    _crashPending = NO;
}

- (void)noteCrash {
    if (_recording) {
        _crashPending = YES;
    }
}

#pragma mark - Sampling

- (void)tick {
    if (!_recording) {
        return;
    }

    double nowMs = NSDate.date.timeIntervalSince1970 * 1000.0;
    PerfSample sample;
    memset(&sample, 0, sizeof(sample));
    sample.t = nowMs - _startedAtMs;
    sample.fps = sample.cpu = sample.gpu = sample.ram = -1;
    sample.avail = sample.battery = sample.battTemp = sample.thermal = -1;

    BOOL appActive = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;

    if ([_enabledMetrics[@"fps"] boolValue] && appActive) {
        uint64_t swaps = pojavSwapCount();
        if (_haveSwap) {
            double dt = (nowMs - _lastSwapMs) / 1000.0;
            if (dt > 0.2) {
                sample.fps = (double)(swaps - _lastSwap) / dt;
            }
        }
        _lastSwap = swaps;
        _lastSwapMs = nowMs;
        _haveSwap = YES;
    } else {
        // Restart the baseline when counting resumes (app was backgrounded).
        _haveSwap = NO;
    }

    if ([_enabledMetrics[@"cpu"] boolValue]) {
        sample.cpu = tm_cpu_usage_percent();
    }
    if ([_enabledMetrics[@"gpu"] boolValue]) {
        sample.gpu = tm_gpu_usage_percent();
    }
    if ([_enabledMetrics[@"ram"] boolValue]) {
        sample.ram = PerfCurrentFootprintMB();
    }
    if ([_enabledMetrics[@"devram"] boolValue]) {
        sample.avail = (double)os_proc_available_memory() / (1024.0 * 1024.0);
    }
    if ([_enabledMetrics[@"battery"] boolValue]) {
        sample.battery = tm_battery_percent();
    }
    if ([_enabledMetrics[@"battemp"] boolValue]) {
        sample.battTemp = tm_battery_temperature_celsius();
    }
    if ([_enabledMetrics[@"thermal"] boolValue]) {
        sample.thermal = PerfCurrentThermalState();
    }

    [_samples appendBytes:&sample length:sizeof(sample)];

    char line[256];
    snprintf(line, sizeof(line), "%.0f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n",
             sample.t, sample.fps, sample.cpu, sample.gpu, sample.ram, sample.avail,
             sample.battery, sample.battTemp, sample.thermal);
    [_csv writeData:[[NSString stringWithUTF8String:line] dataUsingEncoding:NSUTF8StringEncoding]];
    // Flush every sample so a hard kill keeps the data up to this second.
    fsync(_csv.fileDescriptor);
}

#pragma mark - Metadata

- (NSDictionary<NSString *, NSNumber *> *)summaryFromSamples {
    NSUInteger count = _samples.length / sizeof(PerfSample);
    const PerfSample *samples = _samples.bytes;
    NSMutableDictionary *summary = [NSMutableDictionary new];
    NSArray *names = PerfMetricNames();

    for (NSUInteger m = 0; m < names.count; m++) {
        double total = 0, minimum = 0, maximum = 0;
        NSUInteger valid = 0;
        for (NSUInteger i = 0; i < count; i++) {
            double value = PerfSampleField(&samples[i], m);
            if (value < 0 || isnan(value) || isinf(value)) {
                continue;
            }
            if (valid == 0 || value < minimum) minimum = value;
            if (valid == 0 || value > maximum) maximum = value;
            total += value;
            valid++;
        }
        if (valid == 0) {
            continue;
        }
        summary[names[m]] = @{
            @"count": @(valid),
            @"avg": @(round(total / valid * 100.0) / 100.0),
            @"min": @(round(minimum * 100.0) / 100.0),
            @"max": @(round(maximum * 100.0) / 100.0),
        };
    }
    return summary;
}

- (NSDictionary<NSString *, NSNumber *> *)enabledMetricFlags {
    NSMutableDictionary *flags = [NSMutableDictionary new];
    for (NSString *name in PerfMetricNames()) {
        flags[name] = _enabledMetrics[name] ?: @NO;
    }
    return flags;
}

- (void)writeMetaWithStatus:(NSString *)status reason:(NSString *)reason final:(BOOL)final {
    NSMutableDictionary *meta = [NSMutableDictionary new];
    meta[@"id"] = _sessionId ?: @"";
    meta[@"startedAt"] = @(_startedAtMs);
    meta[@"status"] = status;
    meta[@"reason"] = reason ?: @"";
    meta[@"sampleIntervalMs"] = @(1000);
    meta[@"sampleCount"] = @(_samples.length / sizeof(PerfSample));
    meta[@"metrics"] = [self enabledMetricFlags];

    NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
    meta[@"device"] = @{
        @"model": WitchHardwareMachine(),
        @"iosVersion": UIDevice.currentDevice.systemVersion ?: @"",
        @"launcherVersion": info[@"CFBundleShortVersionString"] ?: @"",
        @"launcherBuild": info[@"CFBundleVersion"] ?: @"",
        @"launcherName": info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"",
        @"buildType": CONFIG_RELEASE ? @"release" : @"dev",
    };
    meta[@"game"] = @{
        @"profile": PLProfiles.current.selectedProfileName ?: @"",
        @"version": _launchMeta[@"version"] ?: @"",
    };

    if (final) {
        double endedAtMs = _startedAtMs;
        NSUInteger count = _samples.length / sizeof(PerfSample);
        if (count > 0) {
            const PerfSample *samples = _samples.bytes;
            endedAtMs = _startedAtMs + samples[count - 1].t;
        }
        meta[@"endedAt"] = @(endedAtMs);
        meta[@"durationMs"] = @(endedAtMs - _startedAtMs);
        meta[@"summary"] = [self summaryFromSamples];
    }

    if (_sessionDir) {
        saveJSONToFile(meta, [_sessionDir stringByAppendingPathComponent:@"meta.json"]);
    }
}

#pragma mark - Dangling session sweep

+ (void)finalizeDanglingSessions {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = [self perfDirectory];
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:nil];
    for (NSString *name in entries) {
        NSString *dir = [root stringByAppendingPathComponent:name];
        NSString *metaPath = [dir stringByAppendingPathComponent:@"meta.json"];
        NSDictionary *existing = parseJSONFromFile(metaPath);
        if (![existing[@"status"] isEqualToString:@"recording"]) {
            continue;
        }
        NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithDictionary:existing];
        NSDictionary *stats = [self statsFromCSVAtPath:[dir stringByAppendingPathComponent:@"samples.csv"]];
        double startedAt = [meta[@"startedAt"] doubleValue];
        double duration = [stats[@"durationMs"] doubleValue];
        meta[@"status"] = @"crashed";
        meta[@"reason"] = @"interrupted";
        meta[@"sampleCount"] = stats[@"sampleCount"];
        meta[@"durationMs"] = @(duration);
        meta[@"endedAt"] = @(startedAt + duration);
        meta[@"summary"] = stats[@"summary"];
        saveJSONToFile(meta, metaPath);
        NSLog(@"[PerfRecorder] finalized dangling session %@ as interrupted", name);
    }
}

// Rebuilds the summary/duration of a session from its flushed CSV. Used for
// sessions that ended without running the in-process finalizer.
+ (NSDictionary *)statsFromCSVAtPath:(NSString *)path {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (content.length == 0) {
        return @{@"sampleCount": @0, @"durationMs": @0, @"summary": @{}};
    }
    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    NSArray *names = PerfMetricNames();
    NSUInteger metricCount = names.count;
    double totals[8] = {0}, minimums[8] = {0}, maximums[8] = {0};
    NSUInteger counts[8] = {0};
    NSUInteger sampleCount = 0;
    double lastT = 0;

    for (NSUInteger li = 1; li < lines.count; li++) {
        NSString *line = lines[li];
        if (line.length == 0) {
            continue;
        }
        NSArray<NSString *> *parts = [line componentsSeparatedByString:@","];
        if (parts.count < 1 + metricCount) {
            continue;
        }
        sampleCount++;
        lastT = parts[0].doubleValue;
        for (NSUInteger m = 0; m < metricCount; m++) {
            double value = parts[m + 1].doubleValue;
            if (value < 0) {
                continue;
            }
            if (counts[m] == 0 || value < minimums[m]) minimums[m] = value;
            if (counts[m] == 0 || value > maximums[m]) maximums[m] = value;
            totals[m] += value;
            counts[m]++;
        }
    }

    NSMutableDictionary *summary = [NSMutableDictionary new];
    for (NSUInteger m = 0; m < metricCount; m++) {
        if (counts[m] == 0) {
            continue;
        }
        summary[names[m]] = @{
            @"count": @(counts[m]),
            @"avg": @(round(totals[m] / counts[m] * 100.0) / 100.0),
            @"min": @(round(minimums[m] * 100.0) / 100.0),
            @"max": @(round(maximums[m] * 100.0) / 100.0),
        };
    }
    return @{@"sampleCount": @(sampleCount), @"durationMs": @(lastT), @"summary": summary};
}

@end
