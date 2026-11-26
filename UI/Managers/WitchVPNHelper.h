#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// LocalDevVPN hand-off used by Built-in StikJIT and StikDebug.
///
/// LocalDevVPN is an App Store app, so Witch cannot embed its tunnel. It can
/// ask LocalDevVPN to connect and return here through the `witch://` scheme.
/// The loopback probe checks the tunnel without reading any VPN status API.
@interface WitchVPNHelper : NSObject

+ (BOOL)isInstalled;
+ (void)connect;
+ (void)disconnect;
+ (void)openAppStore;

/// YES when 10.7.0.1 answers on the lockdownd/RSD ports LocalDevVPN exposes.
+ (void)probeWithCompletion:(void (^)(BOOL reachable))completion;

@end

NS_ASSUME_NONNULL_END
