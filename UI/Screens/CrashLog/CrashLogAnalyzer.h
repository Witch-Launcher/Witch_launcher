#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CrashLogCategory) {
    CrashLogCategoryModConflict = 0,
    CrashLogCategoryError,
    CrashLogCategoryRaw
};

@interface CrashLogAnalyzerResult : NSObject
@property (nonatomic) CrashLogCategory category;
@property (nonatomic, copy) NSString *excerpt;
@property (nonatomic, copy) NSString *fullLog;
@property (nonatomic, copy) NSString *latestLogPath;
@property (nonatomic, copy) NSString *crashReportPath;
@property (nonatomic, copy) NSString *hsErrPath;
@end

@interface CrashLogAnalyzer : NSObject

+ (CrashLogAnalyzerResult *)analyzeWithExitCode:(int)code;

@end
