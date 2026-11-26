#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ModpackExportFormat) {
    ModpackExportFormatModrinth = 0,
    ModpackExportFormatCurseForge = 1,
};

@interface ModpackExporter : NSObject

+ (void)exportProfile:(NSDictionary *)profile
               format:(ModpackExportFormat)format
                 name:(NSString *)name
              version:(NSString *)version
               author:(NSString *)author
             progress:(nullable void (^)(double fraction, NSString *message))progress
           completion:(void (^)(NSString * _Nullable path, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
