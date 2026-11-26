#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const WitchJITStatusDidChangeNotification;

/// Central JIT method selection and Built-in StikJIT setup.
///
/// `auto` prefers TrollStore when that JIT entitlement is present, then
/// Built-in StikJIT when the device is paired, then StikDebug. A selected
/// method is never silently replaced after a failure: the caller shows the
/// helper's error and offers the other methods explicitly.
@interface WitchJITCoordinator : NSObject

@property (class, readonly) WitchJITCoordinator *shared;

/// auto | builtin | stikdebug | wait | trollstore
@property (nonatomic, copy) NSString *selectedMethod;
@property (nonatomic, readonly) NSString *resolvedMethod;
@property (nonatomic, readonly) BOOL isBuiltInAvailable;
@property (nonatomic, readonly) BOOL isBuiltInConfigured;
@property (nonatomic, readonly) BOOL hasPairingFile;
@property (nonatomic, readonly) BOOL isLiveContainer;
@property (nonatomic, readonly, nullable) NSString *pairingFileName;
@property (nonatomic, readonly) BOOL forceScript;
@property (nonatomic, readonly) BOOL txmPresent;
@property (nonatomic, readonly, nullable) NSString *lastPreparationMessage;

- (BOOL)importPairingFileAtURL:(NSURL *)url error:(NSError **)error;
- (BOOL)removePairingFile:(NSError **)error;

/// Imports a pairing file another app opened "in Witch" (iLoader, SideInstall,
/// StikDebug, Files). Returns YES when the URL was a pairing candidate, so the
/// caller can stop looking at other document handlers.
+ (BOOL)handleIncomingPairingURL:(NSURL *)url;

/// Imports a valid pairing file that iOS copied into Documents/Inbox without
/// calling the open-URL path (Files "Copy to Witch", AirDrop). Returns YES if
/// one was imported.
- (BOOL)importInboxPairingFileIfNeeded;

/// Downloads/mounts the DDI and checks LocalDevVPN without enabling JIT.
- (void)prepareWithCompletion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

/// Starts the helper and returns once the debugger is attached and JIT is
/// readable. The helper request itself stays open for the whole game session.
- (void)enableBuiltInJITWithCompletion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

- (void)resetDDIWithCompletion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

/// Existing external flows (StikDebug / TrollStore / SideStore URL).
- (void)requestExternalJITEnable;

@end

NS_ASSUME_NONNULL_END
