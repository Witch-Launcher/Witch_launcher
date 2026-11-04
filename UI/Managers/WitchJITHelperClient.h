#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Starts Witch's embedded JIT helper extension (PlugIns/WitchJITHelper.appex).
///
/// A process cannot attach a debugger to itself, so the helper owns the StikJIT
/// connection. Requests are JSON in an NSExtensionItem; the helper replies with
/// JSON in the returning item. The `enable` request stays open for as long as
/// the debugger remains attached, which on iOS 26/27 is the whole game session.
@interface WitchJITHelperClient : NSObject

@property (class, readonly) WitchJITHelperClient *shared;

/// YES on iOS 17.4+ when the helper extension is present in this installation.
@property (nonatomic, readonly) BOOL isAvailable;

/// The helper's bundle identifier in this installation. Sideloaders that sign
/// with a user Apple ID append their team ID to the app and helper alike, so the
/// identifier is read from the embedded Info.plist instead of hard-coded.
@property (nonatomic, readonly, nullable) NSString *helperIdentifier;

- (void)prepareWithPairingData:(NSData *)pairingData
                    completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

- (void)enableWithTargetPID:(int32_t)targetPID
                 pairingData:(NSData *)pairingData
                scriptBase64:(NSString *)scriptBase64
                 forceScript:(BOOL)forceScript
                  completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

- (void)resetDDIWithCompletion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
