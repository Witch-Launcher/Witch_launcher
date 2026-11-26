#import "PerfSessionStore.h"

#import "PerfRecorder.h"
#import "utils.h"

#include <math.h>

@implementation PerfSession

- (BOOL)hasMetric:(NSString *)metric {
    return self.summary[metric] != nil;
}

- (double)metricValue:(NSString *)metric aggregate:(NSString *)aggregate {
    NSDictionary *stats = self.summary[metric];
    NSNumber *value = stats[aggregate];
    if (![value isKindOfClass:NSNumber.class]) {
        return NAN;
    }
    return value.doubleValue;
}

- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)pointsForMetric:(NSString *)metric
                                                          maxPoints:(NSUInteger)maxPoints {
    NSArray<NSString *> *names = PerfMetricNames();
    NSUInteger index = [names indexOfObject:metric];
    if (index == NSNotFound) {
        return @[];
    }
    NSString *path = [self.directory stringByAppendingPathComponent:@"samples.csv"];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (content.length == 0) {
        return @[];
    }

    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *points = [NSMutableArray new];
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSString *line = lines[i];
        if (line.length == 0) {
            continue;
        }
        NSArray<NSString *> *parts = [line componentsSeparatedByString:@","];
        if (parts.count < 1 + names.count) {
            continue;
        }
        NSString *raw = parts[index + 1];
        if (raw.length == 0) {
            continue;
        }
        double value = raw.doubleValue;
        if (value < 0 || isnan(value)) {
            continue;
        }
        [points addObject:@{@"x": @(parts[0].doubleValue / 1000.0), @"y": @(value)}];
    }

    if (maxPoints > 0 && points.count > maxPoints) {
        NSUInteger stride = (NSUInteger)ceil((double)points.count / (double)maxPoints);
        NSMutableArray *reduced = [NSMutableArray new];
        for (NSUInteger i = 0; i < points.count; i += stride) {
            [reduced addObject:points[i]];
        }
        NSDictionary *last = points.lastObject;
        if (reduced.lastObject != last && last) {
            [reduced addObject:last];
        }
        return reduced;
    }
    return points;
}

- (NSString *)localizedReason {
    if (self.interrupted) {
        return localize(@"perf.reason.interrupted", nil);
    }
    if ([self.status isEqualToString:@"crashed"]) {
        return localize(@"perf.reason.crash", nil);
    }
    NSString *key = [NSString stringWithFormat:@"perf.reason.%@", self.reason ?: @"unknown"];
    return localize(key, nil);
}

@end

@implementation PerfSessionStore

+ (NSString *)perfDirectory {
    return [PerfRecorder perfDirectory];
}

+ (NSInteger)sessionCount {
    NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self perfDirectory] error:nil];
    return entries.count;
}

+ (NSArray<PerfSession *> *)loadSessions {
    [PerfRecorder finalizeDanglingSessions];

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = [self perfDirectory];
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:nil];
    NSMutableArray<PerfSession *> *sessions = [NSMutableArray new];

    for (NSString *name in entries) {
        NSString *dir = [root stringByAppendingPathComponent:name];
        NSString *metaPath = [dir stringByAppendingPathComponent:@"meta.json"];
        NSDictionary *meta = parseJSONFromFile(metaPath);
        if (![meta isKindOfClass:NSDictionary.class] || meta[@"startedAt"] == nil) {
            continue;
        }

        PerfSession *session = [PerfSession new];
        session.sessionId = meta[@"id"] ?: name;
        session.directory = dir;
        session.meta = meta;
        session.startedAt = [NSDate dateWithTimeIntervalSince1970:[meta[@"startedAt"] doubleValue] / 1000.0];
        session.duration = [meta[@"durationMs"] doubleValue] / 1000.0;
        session.status = meta[@"status"] ?: @"done";
        session.reason = meta[@"reason"] ?: @"";
        session.summary = [meta[@"summary"] isKindOfClass:NSDictionary.class] ? meta[@"summary"] : @{};
        session.interrupted = [session.reason isEqualToString:@"interrupted"];
        [sessions addObject:session];
    }

    [sessions sortUsingComparator:^NSComparisonResult(PerfSession *a, PerfSession *b) {
        return [b.startedAt compare:a.startedAt];
    }];
    return sessions;
}

+ (BOOL)deleteSession:(PerfSession *)session {
    return [NSFileManager.defaultManager removeItemAtPath:session.directory error:nil];
}

@end
