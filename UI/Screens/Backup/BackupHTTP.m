#import "BackupHTTP.h"

static NSString *const kBackupHTTPErrorDomain = @"WitchBackupHTTPErrorDomain";

@implementation BackupHTTP

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)url method:(NSString *)method {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method ?: @"GET";
    request.timeoutInterval = 120;
    [request setValue:@"Witch-iOS/1.0" forHTTPHeaderField:@"User-Agent"];
    return request;
}

+ (void)jsonRequest:(NSURLRequest *)request
         completion:(void (^)(id, NSData *, NSHTTPURLResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id json = nil;
        if (data.length > 0) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(json, data, (NSHTTPURLResponse *)response, error);
        });
    }];
    [task resume];
}

+ (void)dataRequest:(NSURLRequest *)request
         completion:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, (NSHTTPURLResponse *)response, error);
        });
    }];
    [task resume];
}

+ (void)downloadRequest:(NSURLRequest *)request
                 toPath:(NSString *)path
             completion:(void (^)(NSError *))completion {
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(error);
            });
            return;
        }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (![self isSuccess:http]) {
            NSData *body = location ? [NSData dataWithContentsOfURL:location] : nil;
            NSError *httpError = [self errorFromData:body response:http fallback:@"Download failed"];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(httpError);
            });
            return;
        }
        NSString *parent = [path stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:&moveError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(moveError);
        });
    }];
    [task resume];
}

+ (void)uploadRequest:(NSURLRequest *)request
              fromFile:(NSString *)path
            completion:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))completion {
    NSURLSessionUploadTask *task = [[NSURLSession sharedSession] uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:path] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, (NSHTTPURLResponse *)response, error);
        });
    }];
    [task resume];
}

+ (BOOL)isSuccess:(NSHTTPURLResponse *)response {
    if (!response) return NO;
    return response.statusCode >= 200 && response.statusCode < 300;
}

+ (NSError *)errorFromData:(NSData *)data response:(NSHTTPURLResponse *)response fallback:(NSString *)fallback {
    NSString *message = fallback ?: @"Cloud request failed";
    if (data.length > 0) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]]) {
            id detail = json[@"error_description"] ?: json[@"message"] ?: json[@"error"];
            if ([detail isKindOfClass:[NSDictionary class]]) detail = detail[@"message"];
            if ([detail isKindOfClass:[NSString class]] && [detail length] > 0) message = detail;
        }
    }
    if (response) {
        message = [NSString stringWithFormat:@"%@ (HTTP %ld)", message, (long)response.statusCode];
    }
    return [NSError errorWithDomain:kBackupHTTPErrorDomain
                               code:response.statusCode ?: -1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

+ (NSString *)urlEncode:(NSString *)value {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

@end
