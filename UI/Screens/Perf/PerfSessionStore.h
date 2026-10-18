#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One recorded performance session (a folder under .amethyst/perf with
// meta.json + samples.csv written by PerfRecorder).
@interface PerfSession : NSObject

@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, copy) NSDictionary *meta;
@property (nonatomic, copy) NSDate *startedAt;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, copy) NSString *status;  // done / crashed / recording
@property (nonatomic, copy) NSString *reason;  // user / exit / force_close / crash / interrupted
@property (nonatomic, copy) NSDictionary *summary;
@property (nonatomic) BOOL interrupted;

- (double)metricValue:(NSString *)metric aggregate:(NSString *)aggregate; // avg/max/min, NAN when absent
- (BOOL)hasMetric:(NSString *)metric;

// Line-chart points: @[@{@"x": seconds, @"y": value}] downsampled to maxPoints.
- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)pointsForMetric:(NSString *)metric
                                                          maxPoints:(NSUInteger)maxPoints;

- (NSString *)localizedReason;

@end

@interface PerfSessionStore : NSObject

// Newest first. Also sweeps dangling "recording" sessions as crashed.
+ (NSArray<PerfSession *> *)loadSessions;
+ (BOOL)deleteSession:(PerfSession *)session;
+ (NSInteger)sessionCount;
+ (NSString *)perfDirectory;

@end

NS_ASSUME_NONNULL_END
