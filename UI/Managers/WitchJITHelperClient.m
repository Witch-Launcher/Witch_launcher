#import "WitchJITHelperClient.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdlib.h>

static NSString *const WitchJITRequestItemKey = @"witch-jit-request";
static NSString *const WitchJITResponseItemKey = @"witch-jit-response";
static NSString *const WitchJITHelperFile = @"WitchJITHelper.appex";

@protocol WitchNSExtensionClassShim <NSObject>
+ (nullable instancetype)extensionWithIdentifier:(NSString *)identifier error:(NSError **)error;
@end

@protocol WitchNSExtensionShim <NSObject>
- (void)beginExtensionRequestWithInputItems:(NSArray *)items
                                 completion:(void (^)(NSUUID * _Nullable requestIdentifier))completion;
- (int)pidForRequestIdentifier:(NSUUID *)requestIdentifier;
- (void)setRequestCompletionBlock:(void (^)(NSUUID * _Nullable requestIdentifier, NSArray * _Nullable items))block;
- (void)setRequestCancellationBlock:(void (^)(NSUUID * _Nullable requestIdentifier, NSError * _Nullable error))block;
- (void)setRequestInterruptionBlock:(void (^)(NSUUID * _Nullable requestIdentifier))block;
@end

@interface WitchJITHelperRequest : NSObject
@property (nonatomic, strong) id extensionObject;
@property (nonatomic, strong) NSUUID *requestIdentifier;
@property (nonatomic, copy) void (^completion)(NSDictionary * _Nullable, NSError * _Nullable);
@property (nonatomic) BOOL finished;
- (void)finishWithResponse:(NSDictionary * _Nullable)response error:(NSError * _Nullable)error;
@end

@implementation WitchJITHelperRequest
- (void)finishWithResponse:(NSDictionary * _Nullable)response error:(NSError * _Nullable)error {
    if (self.finished) return;
    self.finished = YES;
    void (^completion)(NSDictionary *, NSError *) = self.completion;
    self.completion = nil;
    if (completion) completion(response, error);
}
@end

@interface WitchJITHelperClient ()
@property (nonatomic, strong) NSMutableArray<WitchJITHelperRequest *> *running;
@end

@implementation WitchJITHelperClient

+ (WitchJITHelperClient *)shared {
    static WitchJITHelperClient *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [WitchJITHelperClient new];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _running = [NSMutableArray array];
    }
    return self;
}

- (NSString *)helperIdentifier {
    NSURL *pluginsURL = NSBundle.mainBundle.builtInPlugInsURL;
    if (!pluginsURL) return nil;
    NSURL *helperURL = [pluginsURL URLByAppendingPathComponent:WitchJITHelperFile isDirectory:YES];
    NSBundle *helperBundle = [NSBundle bundleWithURL:helperURL];
    return helperBundle.bundleIdentifier;
}

- (BOOL)isAvailable {
#if TARGET_OS_IOS
    if (@available(iOS 17.4, *)) {
        if (getenv("LC_HOME_PATH") != NULL) return NO;
        return self.helperIdentifier.length > 0;
    }
#endif
    return NO;
}

- (void)prepareWithPairingData:(NSData *)pairingData
                    completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    [self sendOperation:@"prepare" targetPID:0 pairingData:pairingData scriptBase64:nil forceScript:NO completion:completion];
}

- (void)enableWithTargetPID:(int32_t)targetPID
                 pairingData:(NSData *)pairingData
                scriptBase64:(NSString *)scriptBase64
                 forceScript:(BOOL)forceScript
                  completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    [self sendOperation:@"enable" targetPID:targetPID pairingData:pairingData scriptBase64:scriptBase64 forceScript:forceScript completion:completion];
}

- (void)resetDDIWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    [self sendOperation:@"resetDDI" targetPID:0 pairingData:nil scriptBase64:nil forceScript:NO completion:completion];
}

- (void)sendOperation:(NSString *)operation
            targetPID:(int32_t)targetPID
          pairingData:(NSData * _Nullable)pairingData
         scriptBase64:(NSString * _Nullable)scriptBase64
          forceScript:(BOOL)forceScript
           completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    if (!self.isAvailable) {
        NSError *error = [NSError errorWithDomain:@"WitchJITHelperClient" code:1 userInfo:@{
            NSLocalizedDescriptionKey: @"Built-in StikJIT is unavailable on this installation."
        }];
        if (completion) completion(nil, error);
        return;
    }

    if (NSClassFromString(@"NSExtension") == nil) {
        dlopen("/System/Library/Frameworks/ExtensionFoundation.framework/ExtensionFoundation", RTLD_NOW);
    }
    Class extensionClass = NSClassFromString(@"NSExtension");
    if (!extensionClass || ![extensionClass respondsToSelector:@selector(extensionWithIdentifier:error:)]) {
        NSError *error = [NSError errorWithDomain:@"WitchJITHelperClient" code:2 userInfo:@{
            NSLocalizedDescriptionKey: @"iOS did not provide the app extension API."
        }];
        if (completion) completion(nil, error);
        return;
    }

    NSString *identifier = self.helperIdentifier;
    NSError *lookupError = nil;
    id extensionObject = [(id<WitchNSExtensionClassShim>)extensionClass extensionWithIdentifier:identifier error:&lookupError];
    if (!extensionObject) {
        NSError *error = [NSError errorWithDomain:@"WitchJITHelperClient" code:3 userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Witch's JIT helper (%@) could not be found: %@",
                                        identifier, lookupError.localizedDescription ?: @"missing"]
        }];
        if (completion) completion(nil, error);
        return;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    request[@"operation"] = operation;
    if (targetPID > 0) request[@"targetPID"] = @(targetPID);
    if (pairingData.length > 0) request[@"pairingData"] = [pairingData base64EncodedStringWithOptions:0];
    if (scriptBase64.length > 0) request[@"scriptBase64"] = scriptBase64;
    request[@"forceScript"] = @(forceScript);

    NSError *jsonError = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:&jsonError];
    if (!json) {
        if (completion) completion(nil, jsonError);
        return;
    }

    WitchJITHelperRequest *helperRequest = [WitchJITHelperRequest new];
    helperRequest.extensionObject = extensionObject;
    helperRequest.completion = completion;

    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = @{WitchJITRequestItemKey: json};

    id<WitchNSExtensionShim> shim = (id<WitchNSExtensionShim>)extensionObject;
    if (![extensionObject respondsToSelector:@selector(beginExtensionRequestWithInputItems:completion:)] ||
        ![extensionObject respondsToSelector:@selector(setRequestCompletionBlock:)]) {
        NSError *error = [NSError errorWithDomain:@"WitchJITHelperClient" code:8 userInfo:@{
            NSLocalizedDescriptionKey: @"This iOS version does not support the app extension request API Witch needs."
        }];
        if (completion) completion(nil, error);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [shim setRequestCompletionBlock:^(NSUUID *requestIdentifier, NSArray *items) {
        NSDictionary *response = nil;
        NSExtensionItem *resultItem = (NSExtensionItem *)items.firstObject;
        NSData *responseData = resultItem.userInfo[WitchJITResponseItemKey];
        if ([responseData isKindOfClass:NSData.class]) {
            id object = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            if ([object isKindOfClass:NSDictionary.class]) response = object;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [helperRequest finishWithResponse:response error:nil];
            [weakSelf finishRequest:helperRequest];
        });
    }];
    [shim setRequestCancellationBlock:^(NSUUID *requestIdentifier, NSError *error) {
        NSError *failure = [NSError errorWithDomain:@"WitchJITHelperClient" code:4 userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Witch's JIT helper stopped: %@",
                                        error.localizedDescription ?: @"cancelled"]
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [helperRequest finishWithResponse:nil error:failure];
            [weakSelf finishRequest:helperRequest];
        });
    }];
    [shim setRequestInterruptionBlock:^(NSUUID *requestIdentifier) {
        NSError *failure = [NSError errorWithDomain:@"WitchJITHelperClient" code:5 userInfo:@{
            NSLocalizedDescriptionKey: @"Witch's JIT helper stopped unexpectedly. Try again."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [helperRequest finishWithResponse:nil error:failure];
            [weakSelf finishRequest:helperRequest];
        });
    }];

    [self.running addObject:helperRequest];
    [shim beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *requestIdentifier) {
        dispatch_async(dispatch_get_main_queue(), ^{
            helperRequest.requestIdentifier = requestIdentifier;
            if (!requestIdentifier) {
                NSError *failure = [NSError errorWithDomain:@"WitchJITHelperClient" code:6 userInfo:@{
                    NSLocalizedDescriptionKey: @"Witch's JIT helper did not start. Reinstall Witch and keep its app extensions."
                }];
                [helperRequest finishWithResponse:nil error:failure];
                [weakSelf finishRequest:helperRequest];
            }
        });
    }];

    // A missing app extension can leave beginExtensionRequest without a
    // completion. Do not let the launch sit on a spinner forever.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (helperRequest.requestIdentifier == nil && !helperRequest.finished) {
            NSError *failure = [NSError errorWithDomain:@"WitchJITHelperClient" code:7 userInfo:@{
                NSLocalizedDescriptionKey: @"Witch's JIT helper did not start. Reinstall Witch and keep its app extensions."
            }];
            [helperRequest finishWithResponse:nil error:failure];
            [weakSelf finishRequest:helperRequest];
        }
    });
}

- (void)finishRequest:(WitchJITHelperRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.running removeObjectIdenticalTo:request];
    });
}

@end
