#pragma once

#import <UIKit/UIKit.h>

#include <stdbool.h>
#include "environ.h"
#include "jni.h"

// Remove date + time from NSLog, unneeded
#define NSLog(args...) customNSLog(__FILE__,__LINE__,__PRETTY_FUNCTION__,args)

// Control button actions
#define ACTION_DOWN 0
#define ACTION_UP 1
#define ACTION_MOVE 2
#define ACTION_MOVE_MOTION 3
#define ACTION_CANCEL 4

#define BUTTON1_DOWN_MASK 1 << 10 // left btn
#define BUTTON2_DOWN_MASK 1 << 11 // mid btn
#define BUTTON3_DOWN_MASK 1 << 12 // right btn

// GLFW event types
#define EVENT_TYPE_CHAR 1000
#define EVENT_TYPE_CHAR_MODS 1001
#define EVENT_TYPE_CURSOR_ENTER 1002
#define EVENT_TYPE_CURSOR_POS 1003
#define EVENT_TYPE_FRAMEBUFFER_SIZE 1004
#define EVENT_TYPE_KEY 1005
#define EVENT_TYPE_MOUSE_BUTTON 1006
#define EVENT_TYPE_SCROLL 1007
#define EVENT_TYPE_WINDOW_POS 1008
#define EVENT_TYPE_WINDOW_SIZE 1009

#define GLFW_FOCUSED 0x00020001
#define GLFW_VISIBLE 0x00020004

#define RENDERER_NAME_GL4ES "libgl4es_114.dylib"
#define RENDERER_NAME_MTL_ANGLE "libtinygl4angle.dylib"
#define RENDERER_NAME_MOBILEGLUES "libmobileglues.dylib"
#define RENDERER_NAME_MOBILEGLUES_OLD "libmobileglues_old.dylib"
#define RENDERER_NAME_LTW "libltw.dylib"
#define RENDERER_NAME_VK_ZINK "libOSMesa.8.dylib"
// Vulkan → MoltenVK → Metal direct renderer. The on-disk value is kept as the
// historical "libMoltenVK.dylib" so existing profiles/settings stay valid.
#define RENDERER_NAME_MOLTENVK "libMoltenVK.dylib"
// MobileGL: desktop OpenGL 4.2+ implementation via Vulkan/MoltenVK backend
#define RENDERER_NAME_MOBILEGL "libMobileGL.dylib"
// TGLMT: OpenGL 4.6 Core -> Metal directly (libtglmt.dylib, no MoltenVK,
// no ANGLE). Vanilla boot path, A11+. Selected from the renderer picker;
// LWJGL resolves plain gl* symbols straight from this dylib.
#define RENDERER_NAME_TGLMT "libtglmt.dylib"
// Metal: direct Metal rendering. The launcher exposes the single host
// CAMetalLayer through SDL_Metal_CreateView; a user-installed Metal mod
// replaces the GPU backend and renders/presents on that layer.
#define RENDERER_NAME_METAL "metal"
// Metal (macOS port): same single host CAMetalLayer as RENDERER_NAME_METAL,
// but reserved for mods ported from macOS (AppKit/NSWindow-style host code).
// Keeping it separate means a future iOS-only API shim can be enabled here
// without changing the plain "metal" renderer used by native iOS mods.
#define RENDERER_NAME_METAL_MACOS "metal_macos"

#define SPECIALBTN_KEYBOARD -1
#define SPECIALBTN_TOGGLECTRL -2
#define SPECIALBTN_MOUSEPRI -3
#define SPECIALBTN_MOUSESEC -4
#define SPECIALBTN_VIRTUALMOUSE -5
#define SPECIALBTN_MOUSEMID -6
#define SPECIALBTN_SCROLLUP -7
#define SPECIALBTN_SCROLLDOWN -8
#define SPECIALBTN_MENU -9

#define NSDebugLog(...) if (debugLogEnabled) { NSLog(__VA_ARGS__); }
BOOL debugLogEnabled, isJailbroken;

//__weak UIViewController *viewController;

#define CS_DEBUGGED 0x10000000
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
BOOL isJITEnabled(BOOL checkCSOps);
BOOL processIsCurrentlyDebugged(void);
void requestExternalJITEnable(void);
// legacy method used to check if we're using universal script
void* JIT26CreateRegionLegacy(size_t len);
// used for large memory regions
void* JIT26PrepareRegion(void *addr, size_t len);
// same as JIT26PrepareRegion, but used for smaller memory regions
// and retain content instead of filling 0x69
void JIT26PrepareRegionForPatching(void *addr, size_t len);
// offers the launcher's pre-blessed + exec-probed full-size mirror region to
// the script (brk cmd 5); libjvm's 240 MB request is then served from it
void JIT26OfferMirrorRegion(void *addr, size_t size);
// echoes the script's stored mirror offer back through the return value
// (brk cmd 6): equals the offered address when the script took the offer,
// 0/NULL when the offer was dropped (stale script / missing handler)
void* JIT26VerifyMirrorOffer(void *sentinel);
void JIT26SetDetachAfterFirstBr(BOOL value);
void JIT26SendJITScript(NSString* script);

// Device JIT flags
typedef enum {
    JIT_FLAG_IS_IOS_26 = 1 << 0,
    JIT_FLAG_FORCE_MIRRORED = 1 << 1,
    JIT_FLAG_HAS_TXM = 1 << 2,
} JITFlags;
JITFlags DeviceGetJITFlags(BOOL refresh);
BOOL DeviceHasJITFlags(JITFlags flags);
BOOL DeviceNeedsDebugJITMapping(void);
BOOL DeviceHasTXMReal(void);
BOOL DeviceHasTXM(void);
BOOL JIT26IsLikelyDebuggerKeepAttached(void);

void handle_fatal_exit(int code);

// Defined in egl_bridge.m. Pre-loads the GLES backend that
// libmobileglues.dylib resolves via dlsym(RTLD_DEFAULT) (TGLES by default;
// ANGLE Vulkan/Metal when mobileglues.angle_backend says so).
// Must run before MobileGlues is dlopened: JavaLauncher calls it before
// JLI_Launch (MC 26.2 boots MobileGlues during JVM startup), and
// pojavInitOpenGL calls it again on the GLFW path (idempotent).
void PLPreloadMobileGluesBackend(void);

// Defined in egl_bridge.m. Pre-loads the selected LTW ANGLE backend and sets
// LIBGL_EGL before libltw's constructor runs. JavaLauncher calls it before
// JLI_Launch (MC 26.3 loads libltw during JVM startup); pojavInitOpenGL calls
// it again on the GLFW path (idempotent).
void PLPreloadLTWBackend(void);

// Init functions
void init_bypassDyldLibValidation();
void init_jit_vm_remap_hook();
void rebind_jit_vm_hooks_after_libjvm_load();
BOOL verify_libjvm_mirror_brk_patch(void);
void start_jit_mirror_prepare_poll_thread(void);
void prewarm_jit_mirror_superpage(void);
void AmethystJIT26PrepareMirrorPair(void *rx, void *rw, size_t size);
BOOL JIT26ExecPreflight(void);
// Size the launcher reserves AND offers for the JVM's CodeCache mirror (see
// JIT26MirrorRegionPreflight). Must be >= what libjvm later requests through
// get_debug_jit_mapping: the script only serves the offer when
// offeredSize >= requestedSize. JDK 21's ergonomic segmented total is exactly
// 0xF000000 (240 MB), but JDK 25 rounds it up by one 16 KB page —
// ReservedCodeCacheSize = 251674624 = 0xF004000 (hs_err_pid9437) — and a
// 240 MB offer is refused there; libjvm then falls back to a fresh _M mapping
// in the non-executable 0x7000_0000_0000 band and SIGBUSes in
// StubRoutines::call_stub. 244 MB keeps a 4 MB margin over every bundled
// runtime's request while staying easy to place low + cheap to bless.
#define JIT26_MIRROR_REGION_SIZE (0xf000000u + 0x400000u)
// Big mirror preflight: reserve + prove a full-size executable region
// and offer it to the script (brk cmd 5) so libjvm serves it for its own
// CodeCache request. Returns YES with *outAddr set when a region was
// blessed and proven executable. See jit_vm_remap_hook.m for the strategies.
BOOL JIT26MirrorRegionPreflight(size_t size, void **outAddr);
void init_hookFunctions();
void init_hookUIKitConstructor();
void init_setupMultiDir();
void init_setupUniversalJITScript(BOOL copyToClipboard);
void JITReportInit(void);
void JITReportLine(NSString *format, ...);
NSString* WitchHardwareMachine(void);
// Friendly Apple SoC name from MobileGestalt's ChipID, or nil when
// MobileGestalt is unavailable on this system.
NSString* WitchChipName(void);
// Last dyld-bypass outcome, for the one-page JIT report (-1/NO = not attempted).
extern int g_dyldMmapMatches, g_dyldFcntlMatches;
extern BOOL g_dyldMmapOK, g_dyldFcntlOK;

BOOL PLPatchMachOPlatformForFile(const char *path);

UIViewController* currentVC();
void openLink(UIViewController* sender, NSURL* link);

NSString* localize(NSString* key, NSString* comment);
NSMutableDictionary* parseJSONFromFile(NSString *path);
NSError* saveJSONToFile(NSDictionary *dict, NSString *path);
void customNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...);

// Launcher-owned support files live in POJAV_HOME/.amethyst so the visible
// Documents folder only shows the user's game data (mods, worlds, screenshots).
// Returns POJAV_HOME/.amethyst[/subpath]; the .amethyst folder is created on
// demand. Use the dir variant when subpath is a folder.
NSString* amethyst_hidden_path(NSString* subpath);
NSString* amethyst_hidden_dir(NSString* subpath);
// One-time migration of legacy root-level items (accounts, controlmap,
// cursors, caches, background media, prefs) into .amethyst, plus cleanup of
// obsolete staging folders. Idempotent; call once before loadPreferences().
void amethyst_migrate_legacy_home(void);

static inline CGFloat clamp(CGFloat x, CGFloat lower, CGFloat upper) {
    return fmin(upper, fmax(x, lower));
}
CGFloat MathUtils_dist(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2);
CGFloat MathUtils_map(CGFloat x, CGFloat in_min, CGFloat in_max, CGFloat out_min, CGFloat out_max);
CGFloat dpToPx(CGFloat dp);
CGFloat pxToDp(CGFloat px);
void setButtonPointerInteraction(UIButton *button);
void _CGDataProviderReleaseBytePointerCallback(void *info,const void *pointer);

jboolean attachThread(bool isAndroid, JNIEnv** secondJNIEnvPtr);

// Last stdout/stderr-flush timestamp (monotonic ms). Defined in main.m.
uint64_t pojavLastLogWriteMs(void);

void sendData(short type, int i1, int i2, short i3, short i4);
void sendDataFloat(short type, float i1, float i2, short i3, short i4);

void closeGLFWWindow();
void callback_LauncherViewController_installMinecraft();
void callback_SurfaceViewController_launchMinecraft(int width, int height);
int callback_SurfaceViewController_touchHotbar(CGFloat x, CGFloat y);

void CallbackBridge_nativeSetInputReady(BOOL inputReady);
BOOL CallbackBridge_nativeSendChar(jchar codepoint /* jint codepoint */);
BOOL CallbackBridge_nativeSendCharMods(jchar codepoint, int mods);
void CallbackBridge_nativeSendCursorPos(char event, CGFloat x, CGFloat y);
void CallbackBridge_nativeSendKey(int key, int scancode, int action, int mods);
void CallbackBridge_nativeSendMouseButton(int button, int action, int mods);
void CallbackBridge_nativeSendScreenSize(int width, int height);
void CallbackBridge_nativeSendScroll(CGFloat xoffset, CGFloat yoffset);
void CallbackBridge_nativeSetWindowFocused(BOOL focused, BOOL iconified);
void CallbackBridge_sendKeycode(int keycode, jchar keychar, int scancode, int modifiers, BOOL isDown);
void CallbackBridge_pauseGameIfNeed();
void AASDL_NoteKey();
double AASDL_LastGrabChangeAge();
bool AASDL_HardwareKeySeenWithin(double seconds);
