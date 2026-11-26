// MBMetalShims.h — macOS-only Metal APIs reimplemented on iOS, part of MetalBridgeKit's facade.
//
// Scope: the macOS-only surface that third-party Metal code (e.g. the mcopt native) uses and the
// iOS SDK lacks: MTLDevice.newResidencySetWithDescriptor:error:, MTLCommandQueue.addResidencySet:,
// the MTLResidencySet family, CAMetalLayer.displaySyncEnabled, and the CoreVideo CVDisplayLink C
// API plus CGMainDisplayID.
//
// Design, kept root-correct on every OS level:
//   - The ObjC shim methods live on NSObject's category in MetalBridgeKit's binary: the compile
//     finds them for any id-typed receiver, and at runtime every real device and queue instance
//     inherits them. On a system with the real API (iOS 18+) the class's own implementation is
//     found first in the hierarchy lookup; below that the shim emulates (iOS unified memory keeps
//     every resource resident, so request/release/commit are bookkeeping and addResidencySet: on
//     the queue is a no-op).
//   - CAMetalLayer.displaySyncEnabled is explicitly unavailable in the iOS SDK, so a same-name
//     declaration cannot override it: the shim adds a mbDisplaySyncEnabled property and the
//     caller compiles with a -D macro mapping the call site to it.
//   - The C pieces (CVDisplayLink*, CGMainDisplayID) are only DEFINED in the iOS build. On macOS
//     real CoreVideo/CG exports win the two-level bind, so the shim must not shadow them.
//   - The caller binds these symbols at dyld time because MetalBridgeKit is loaded with
//     RTLD_GLOBAL before the JVM (JavaLauncher.m) — no hard link needed.
//
// Usage from C/ObjC code compiled for iOS: force-include this header
//   -include MBMetalShims.h -DMTLResidencySetDescriptor=MBResidencySetDescriptor
// Pure-C translation units also work: the CoreVideo imports are C-safe and the ObjC decls are
// guarded by __OBJC__.

#ifndef MB_METAL_SHIMS_H
#define MB_METAL_SHIMS_H

#include <stdint.h>
#import <CoreVideo/CVBase.h>   // C-safe: CVTimeStamp, CVOptionFlags, CVTimeStampFlags
#import <CoreVideo/CVReturn.h> // C-safe: CVReturn, kCVReturnSuccess

#if !TARGET_OS_OSX

#if defined(__OBJC__)
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - MTLResidencySet family (macOS/iOS 18+; emulated below iOS 18)

// The descriptor class is NOT declared here: the caller compiles with
//   -DMTLResidencySetDescriptor=MBResidencySetDescriptor
// which renames the SDK's own (iOS 18-annotated) MTLResidencySetDescriptor declaration, so the
// name resolves to MetalBridgeKit's emulation class without a duplicate declaration.

/// Mirrors the real MTLResidencySet protocol's methods that callers use.
@protocol MBResidencySet <NSObject>
- (void)addAllocation:(id<MTLResource>)allocation;
- (void)removeAllocation:(id<MTLResource>)allocation;
- (void)requestResidency;
- (void)releaseResidency;
- (void)commit;
- (BOOL)containsAllocation:(id<MTLResource>)allocation;
@end

#pragma mark - NSObject shim methods (mb-named; callers reach them through the macros below)

// These never shadow a real selector: shimming the runtime's own name makes every msgSend land on
// the shim, and a captured-IMP forward into a missing real selector loops forever (rendered as
// `[MBMetalShims] mathMode=` x millions in latestlog 2). The macros below rename the callers' call
// sites, and the shim resolves the REAL method with class_getInstanceMethod (nil-safe) at call time.
#ifdef __OBJC__
@interface NSObject (MBMetalShims)
- (id)mbResidencySetWithDescriptor:(id)descriptor error:(NSError **)error;
- (void)mbAddResidencySet:(id)set;
- (void)setMbMathMode:(NSUInteger)mbMathMode;
- (NSUInteger)mbMathMode;
@end
#endif

// Caller-side remaps (pure C macros, so the mod's already-written real names compile to mb selectors):
#define newResidencySetWithDescriptor mbResidencySetWithDescriptor
#define addResidencySet mbAddResidencySet
#define mathMode mbMathMode

#pragma mark - CAMetalLayer.displaySyncEnabled (macOS-only; stored no-op on iOS)

@interface CAMetalLayer (MBMetalShims)
/// macOS compositor pacing hint. On iOS every present already syncs to the display via the
/// drawable latch, so this only stores the requested flag.
@property (nonatomic) BOOL mbDisplaySyncEnabled;
@end

#define displaySyncEnabled mbDisplaySyncEnabled

#endif // defined(__OBJC__)

#pragma mark - CVDisplayLink (CoreVideo C API, macOS-only) + CGMainDisplayID

typedef struct __CVDisplayLink *CVDisplayLinkRef;

typedef CVReturn (*CVDisplayLinkOutputCallback)(CVDisplayLinkRef displayLink,
                                                const CVTimeStamp *inNow,
                                                const CVTimeStamp *inOutputTime,
                                                CVOptionFlags flagsIn,
                                                CVOptionFlags *flagsOut,
                                                void *displayLinkContext);

#ifdef __cplusplus
extern "C" {
#endif

extern CVReturn CVDisplayLinkCreateWithCGDisplay(uint32_t display,
                                                            CVDisplayLinkRef *displayLinkOut);
extern CVReturn CVDisplayLinkSetOutputCallback(CVDisplayLinkRef displayLink,
                                                          CVDisplayLinkOutputCallback callback,
                                                          void *userInfo);
extern CVReturn CVDisplayLinkStart(CVDisplayLinkRef displayLink);
extern CVReturn CVDisplayLinkStop(CVDisplayLinkRef displayLink);
extern void CVDisplayLinkRelease(CVDisplayLinkRef displayLink);

/// CoreGraphics exists on iOS, but the display-id API is macOS-only. iOS has exactly one screen
/// for this purpose, so the shim answers a constant id.
extern uint32_t CGMainDisplayID(void);

#ifdef __cplusplus
}
#endif

#endif // !TARGET_OS_OSX

#endif // MB_METAL_SHIMS_H
