#import "BackupManager.h"
#import <AVFoundation/AVFoundation.h>
#import <GameController/GameController.h>
#import <objc/runtime.h>

#import "authenticator/BaseAuthenticator.h"
#import "customcontrols/ControlButton.h"
#import "customcontrols/ControlDrawer.h"
#import "customcontrols/ControlSubButton.h"
#import "customcontrols/CustomControlsUtils.h"

#import "input/ControllerInput.h"
#import "input/GyroInput.h"
#import "input/KeyboardInput.h"
#import "input/TelexInput.h"

#import "JavaLauncher.h"
#import "LauncherPreferences.h"
#import "MinecraftResourceUtils.h"
#import "PerfRecorder.h"
#import "PLProfiles.h"
#import "SurfaceViewController.h"
#import "SurfaceViewController+HangDetect.h"
#import "SurfaceViewController+LaunchSplash.h"
#import "GameLaunchChecks.h"
#import "TrackedTextField.h"
#import "UIKit+hook.h"
#import "ios_uikit_bridge.h"

#import "touchcontroller_jni_bridge.h"
#import "touchcontroller_launcher.h"
#import "CursorManager.h"
#import "CursorTypeManager.h"

#include "glfw_keycodes.h"
#include "utils.h"

#include <dlfcn.h>
#include <stdatomic.h>

// Latched (in pressesBegan:) the first time any physical key is seen. Some
// Bluetooth keyboards are not exposed via GameController, so this is the
// most reliable "hardware keyboard attached" signal for focus management.
static atomic_bool hardwareKeyboardSeen = false;

// Tracks grab transitions so the Telex composition engine is reset whenever
// the game switches between gameplay and a GUI screen.
static BOOL lastGrabStateInited = NO;
static BOOL lastGrabState = NO;

// libaudio_capture.dylib is a standalone JNI library that only gets loaded
// when the game JVM starts (System.loadLibrary). The launcher needs its mic
// helpers earlier, and must not reference them directly: an undefined symbol
// in the executable aborts the whole app at launch ("missing symbol called").
// Load it on demand and resolve the two entry points.
static void *aac_library(void) {
    static void *handle;
    static BOOL tried = NO;
    if (!tried) {
        tried = YES;
        NSString *path = [NSBundle.mainBundle.privateFrameworksPath
            stringByAppendingPathComponent:@"libaudio_capture.dylib"];
        handle = dlopen(path.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            NSLog(@"[AudioCapture] dlopen failed: %s", dlerror());
        }
    }
    return handle;
}

void aac_requestMicrophonePermission(void) {
    void *handle = aac_library();
    void (*request)(void) = handle
        ? (void (*)(void))dlsym(handle, "aac_requestMicrophonePermission") : NULL;
    if (request) request();
}

BOOL aac_isCapturing(void) {
    void *handle = aac_library();
    BOOL (*capturing)(void) = handle
        ? (BOOL (*)(void))dlsym(handle, "aac_isCapturing") : NULL;
    return capturing ? capturing() : NO;
}

int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT        6

static int currentHotbarSlot = -1;
static GameSurfaceView* pojavWindow;

@interface SurfaceViewController ()<UITextFieldDelegate, UIGestureRecognizerDelegate> {
    // TouchController integration
    NSUInteger nextTouchControllerIndex;
    // Retains UITouch keys so we can safely inspect their phase during the
    // stale-touch sweep (see sendTouchControllerStaleUps).
    NSMapTable<id, NSNumber*>* touchControllerIndexMap;
    
    // Hover gesture tracking for click detection
    CGPoint hoverStartPoint;
    BOOL hoverMoved;

    // Last surface size used to refresh the game framebuffer metrics after
    // the initial layout/rotation, not just on explicit preference changes.
    CGSize lastSurfaceSize;
}

@property(nonatomic) NSDictionary* metadata;

@property(nonatomic) TrackedTextField *inputTextField;
@property(nonatomic) NSMutableArray* swipeableButtons;
@property(nonatomic) ControlButton* swipingButton;
@property(nonatomic) UITouch *primaryTouch, *hotbarTouch;

@property(nonatomic) UILongPressGestureRecognizer* longPressGesture, *longPressTwoGesture;
@property(nonatomic) UITapGestureRecognizer *tapGesture, *doubleTapGesture;

@property(nonatomic) id mouseConnectCallback, mouseDisconnectCallback;
@property(nonatomic) id controllerConnectCallback, controllerDisconnectCallback;
@property(nonatomic) id cursorTypeCallback, mouseScaleCallback, controlScaleCallback;
@property(nonatomic) CADisplayLink *gamepadDisplayLink;

@property(nonatomic) CGFloat screenScale;
@property(nonatomic) CGFloat mouseSpeed;
@property(nonatomic) CGFloat cameraSensitivity;
@property(nonatomic) CGRect clickRange;
@property(nonatomic) BOOL isMacCatalystApp, shouldHideControlsFromRecording,
    shouldTriggerClick, shouldTriggerHaptic, slideableHotbar, toggleHidden;

@property(nonatomic) BOOL enableMouseGestures, enableHotbarGestures;
@property(nonatomic) BOOL enableHoldGesture, enableDoubleTapOffhand;
@property(nonatomic) UIToolbar *keyboardToolbar;

@property(nonatomic) UIImpactFeedbackGenerator *lightHaptic;
@property(nonatomic) UIImpactFeedbackGenerator *mediumHaptic;

@property(nonatomic) NSString *jarPath;
@property(nonatomic) NSArray<NSString *> *jarArgs;
@property(nonatomic) int jarMinJavaVersion;

@end

@implementation SurfaceViewController

@synthesize keyboardToolbar = _keyboardToolbar;

- (instancetype)initWithMetadata:(NSDictionary *)metadata {
    self = [super init];
    self.metadata = metadata;
    self.jarPath = nil;
    return self;
}

- (instancetype)initWithJarPath:(NSString *)jarPath {
    return [self initWithJarPath:jarPath args:nil minJavaVersion:8];
}

- (instancetype)initWithJarPath:(NSString *)jarPath args:(NSArray<NSString *> *)args minJavaVersion:(int)minJavaVersion {
    self = [super init];
    self.metadata = nil;
    self.jarPath = jarPath;
    self.jarArgs = args;
    self.jarMinJavaVersion = minJavaVersion > 0 ? minJavaVersion : 8;
    return self;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return amethyst_orientation_mask();
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    isControlModifiable = NO;
    self.isMacCatalystApp = NSProcessInfo.processInfo.isMacCatalystApp;
    // Load MetalHUD library
    dlopen("/usr/lib/libMTLHud.dylib", 0);

    self.lightHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleLight)];
    self.mediumHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleMedium)];

    //setPrefBool(@"internal.internal_launch_on_boot", NO);

    UIApplication.sharedApplication.idleTimerDisabled = YES;
    BOOL isTVOS = realUIIdiom == UIUserInterfaceIdiomTV;
    if (!isTVOS) {
        [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }

    // Perform Gamepad joystick ticking, while also controlling frame rate?
    id tickInput = ^{
        [GyroInput tick];
        [ControllerInput tick];
    };
    // Invalidate any leftover link from a previous session before adding a
    // new one; otherwise each game session leaks one run-loop entry.
    if (self.gamepadDisplayLink) {
        [self.gamepadDisplayLink invalidate];
        self.gamepadDisplayLink = nil;
    }
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:tickInput selector:@selector(invoke)];
    if (@available(iOS 15.0, tvOS 15.0, *)) {
        float maxFPS = UIScreen.mainScreen.maximumFramesPerSecond;
        displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30, maxFPS, maxFPS);
    }
    [displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    self.gamepadDisplayLink = displayLink;

    CGFloat screenScale = UIScreen.mainScreen.scale;

    [self updateSavedResolution];

    self.rootView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width + 30.0, self.view.frame.size.height)];
    [self.view addSubview:self.rootView];

    self.ctrlView = [[ControlLayout alloc] initWithFrame:getSafeArea(self.view.frame)];

    [self performSelector:@selector(initCategory_Navigation)];
    
    // Initialize TouchController touch tracking
    nextTouchControllerIndex = 1;
    touchControllerIndexMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                                      valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
    
    self.surfaceView = [[GameSurfaceView alloc] initWithFrame:self.view.frame];
    self.surfaceView.layer.contentsScale = screenScale * resolutionScale;
    self.surfaceView.layer.magnificationFilter = self.surfaceView.layer.minificationFilter = kCAFilterNearest;
    self.surfaceView.multipleTouchEnabled = YES;
    pojavWindow = self.surfaceView;

    self.touchView = [[UIView alloc] initWithFrame:self.view.frame];
    self.touchView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
    self.touchView.multipleTouchEnabled = YES;
    [self.touchView addSubview:self.surfaceView];

    [self.rootView addSubview:self.touchView];
    [self.rootView addSubview:self.ctrlView];

    [self performSelector:@selector(setupCategory_Navigation)];

    
    UIHoverGestureRecognizer *hoverGesture = [[NSClassFromString(@"UIHoverGestureRecognizer") alloc] initWithTarget:self action:@selector(surfaceOnHover:)];
    [self.touchView addGestureRecognizer:hoverGesture];

    self.tapGesture = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(surfaceOnClick:)];
    self.tapGesture.allowedTouchTypes = @[@(UITouchTypeDirect)];
    self.tapGesture.delegate = self;
    self.tapGesture.numberOfTapsRequired = 1;
    self.tapGesture.numberOfTouchesRequired = 1;
    self.tapGesture.cancelsTouchesInView = NO;
    [self.touchView addGestureRecognizer:self.tapGesture];

    self.doubleTapGesture = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(surfaceOnDoubleClick:)];
    self.doubleTapGesture.allowedTouchTypes = @[@(UITouchTypeDirect)];
    self.doubleTapGesture.delegate = self;
    self.doubleTapGesture.numberOfTapsRequired = 2;
    self.doubleTapGesture.numberOfTouchesRequired = 1;
    self.doubleTapGesture.cancelsTouchesInView = NO;
    [self.touchView addGestureRecognizer:self.doubleTapGesture];

    self.longPressGesture = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(surfaceOnLongpress:)];
    self.longPressGesture.allowedTouchTypes = @[@(UITouchTypeDirect)];
    self.longPressGesture.cancelsTouchesInView = NO;
    self.longPressGesture.delegate = self;
    [self.touchView addGestureRecognizer:self.longPressGesture];
    
    self.longPressTwoGesture = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(keyboardGesture:)];
    self.longPressTwoGesture.numberOfTouchesRequired = 2;
    self.longPressTwoGesture.allowedTouchTypes = @[@(UITouchTypeDirect)];
    self.longPressTwoGesture.cancelsTouchesInView = NO;
    self.longPressTwoGesture.delegate = self;
    [self.touchView addGestureRecognizer:self.longPressTwoGesture];

    self.scrollPanGesture = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(surfaceOnTouchesScroll:)];
    self.scrollPanGesture.allowedTouchTypes = @[@(UITouchTypeDirect)];
    self.scrollPanGesture.delegate = self;
    self.scrollPanGesture.minimumNumberOfTouches = 2;
    self.scrollPanGesture.maximumNumberOfTouches = 2;
    [self.touchView addGestureRecognizer:self.scrollPanGesture];

    // Virtual mouse
    virtualMouseEnabled = getPrefBool(@"control.virtmouse_enable");
    virtualMouseFrame = CGRectMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2, 18, 27);
    self.mousePointerView = [[UIImageView alloc] initWithFrame:virtualMouseFrame];
    self.mousePointerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin |UIViewAutoresizingFlexibleBottomMargin;
    self.mousePointerView.hidden = !virtualMouseEnabled;
    self.mousePointerView.userInteractionEnabled = NO;
    self.mousePointerView.contentMode = UIViewContentModeScaleAspectFit;
    self.mousePointerView.layer.minificationFilter = kCAFilterLinear;
    self.mousePointerView.layer.magnificationFilter = kCAFilterLinear;
    NSString *initialTypeId = [CursorTypeManager currentActiveTypeId];
    CGRect initialDisplayFrame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:initialTypeId];
    self.mousePointerView.image = [CursorTypeManager imageForType:initialTypeId displaySize:initialDisplayFrame.size];
    [self.touchView addSubview:self.mousePointerView];
    self.mousePointerView.frame = initialDisplayFrame;
    AmethystSetSystemPointerHidden(self.view, virtualMouseEnabled);

    // Keep the tracked field inside the visible bounds: iOS attaches the
    // hardware-keyboard text input session (UIFieldEditor) only when the first
    // responder is within the key window's visible area. Alpha is kept just
    // above zero so the field stays invisible but technically "visible" to
    // UIKit (alpha 0 or hidden views can drop the input session).
    self.inputTextField = [[TrackedTextField alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 30.0)];
    self.inputTextField.alpha = 0.02f;
    self.inputTextField.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.inputTextField.delegate = self;
    self.inputTextField.font = [UIFont fontWithName:@"Menlo-Regular" size:20];
    self.inputTextField.clearsOnBeginEditing = YES;
    self.inputTextField.textAlignment = NSTextAlignmentCenter;
    // Game chat must receive exactly what the keyboard produced. iOS smart
    // punctuation/autocorrection can otherwise change or duplicate text.
    self.inputTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.inputTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.inputTextField.smartQuotesType = UITextSmartQuotesTypeNo;
    self.inputTextField.smartDashesType = UITextSmartDashesTypeNo;
    self.inputTextField.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    self.inputTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputTextField.sendChar = ^(jchar keychar){
        CallbackBridge_nativeSendChar(keychar);
    };
    self.inputTextField.sendCharMods = ^(jchar keychar, int mods){
        CallbackBridge_nativeSendCharMods(keychar, mods);
    };
    self.inputTextField.sendKey = ^(int key, int scancode, int action, int mods) {
        CallbackBridge_nativeSendKey(key, scancode, action, mods);
    };

    self.swipeableButtons = [[NSMutableArray alloc] init];

    [KeyboardInput initKeycodeTable];
    __weak typeof(self) weakSelf = self;
    self.mouseConnectCallback = [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSLog(@"Input: Mouse connected!");
        GCMouse* mouse = note.object;
        [strongSelf registerMouseCallbacks:mouse];
        virtualMouseEnabled = YES;
        strongSelf.mousePointerView.hidden = isGrabbing;
        AmethystSetSystemPointerHidden(strongSelf.view, YES);
        [strongSelf setNeedsUpdateOfPrefersPointerLocked];
    }];
    self.mouseDisconnectCallback = [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSLog(@"Input: Mouse disconnected!");
        GCMouse* mouse = note.object;
        mouse.mouseInput.mouseMovedHandler = nil;
        mouse.mouseInput.leftButton.pressedChangedHandler = nil;
        mouse.mouseInput.middleButton.pressedChangedHandler = nil;
        mouse.mouseInput.rightButton.pressedChangedHandler = nil;
        [mouse.mouseInput.auxiliaryButtons makeObjectsPerformSelector:@selector(setPressedChangedHandler:) withObject:nil];
        [strongSelf setNeedsUpdateOfPrefersPointerLocked];
        if (getPrefBool(@"control.hardware_hide")) {
            strongSelf.ctrlView.hidden = NO;
        }
    }];
    if (GCMouse.current != nil) {
        [self registerMouseCallbacks:GCMouse.current];
    }

    // Observe cursor type changes from the game (via GLFW/SDL3 JNI calls)
    self.cursorTypeCallback = [[NSNotificationCenter defaultCenter] addObserverForName:CursorTypeDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!virtualMouseEnabled) return;
        NSString *typeId = note.userInfo[@"typeId"];
        if (typeId) {
            CGRect displayFrame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:typeId];
            strongSelf.mousePointerView.image = [CursorTypeManager imageForType:typeId displaySize:displayFrame.size];
            strongSelf.mousePointerView.frame = displayFrame;
        }
    }];

    // Live update for mouse/button scale sliders (Settings -> Controls)
    // Previous bug: slider saved pref but never refreshed virtualMouseFrame / mousePointerView until relaunch.
    // Now observe and apply immediately, including hitbox-aware displayFrame recalculation.
    self.mouseScaleCallback = [[NSNotificationCenter defaultCenter] addObserverForName:@"MouseScaleDidChangeNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf handleControlScaleChange];
    }];
    self.controlScaleCallback = [[NSNotificationCenter defaultCenter] addObserverForName:@"ControlScaleDidChangeNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf handleControlScaleChange];
    }];

    // TODO: deal with multiple controllers by letting users decide which one to use?
    self.controllerConnectCallback = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSLog(@"Input: Controller connected!");
        GCController* controller = note.object;
        [ControllerInput initKeycodeTable];
        [ControllerInput registerControllerCallbacks:controller];
        strongSelf.mousePointerView.hidden = isGrabbing;
        virtualMouseEnabled = YES;
        AmethystSetSystemPointerHidden(strongSelf.view, YES);
        if (getPrefBool(@"control.hardware_hide")) {
            strongSelf.ctrlView.hidden = YES;
        }
    }];
    self.controllerDisconnectCallback = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSLog(@"Input: Controller disconnected!");
        GCController* controller = note.object;
        [ControllerInput unregisterControllerCallbacks:controller];
        if (getPrefBool(@"control.hardware_hide")) {
            strongSelf.ctrlView.hidden = NO;
        }
    }];
    if (GCController.controllers.count == 1) {
        [ControllerInput initKeycodeTable];
        [ControllerInput registerControllerCallbacks:GCController.controllers.firstObject];
    }

    [self.rootView addSubview:self.inputTextField];

    [self performSelector:@selector(initCategory_LogView)];
    [self performSelector:@selector(installOverlayLogGestureIfEnabled)];

    // [self setPreferredFramesPerSecond:1000];
    [self updateJetsamControl];
    [self updatePreferenceChanges];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSavedResolution) name:@"ResolutionDidChangeNotification" object:nil];
    [self loadCustomControls];
    [self performSelector:@selector(setupCategory_Widget)];

    if (UIApplication.sharedApplication.connectedScenes.count > 1 &&
      getPrefBool(@"video.fullscreen_airplay")) {
        [self switchToExternalDisplay];
    }

    [self launchMinecraft];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.surfaceView.superview == nil) return;
    CGSize size = self.surfaceView.superview.bounds.size;
    if (!CGSizeEqualToSize(size, lastSurfaceSize)) {
        lastSurfaceSize = size;
        [self updateSavedResolution];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    AmethystSetSystemPointerHidden(self.view, isGrabbing || virtualMouseEnabled);
    [self setNeedsUpdateOfPrefersPointerLocked];
}

// Invalidate every timer/observer/display link this session created. Called
// when the game session ends (viewWillDisappear) and again from dealloc as a
// safety net. Without this, block-based observers and the 0.25s sweep timer
// retain the whole view controller after the game is gone.
- (void)witch_teardownGameSession {
    // Let UIKit restore the launcher root first; BackupManager refuses to run
    // while SurfaceViewController is still the window root.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[BackupManager shared] backupIfNeededForTrigger:@"exit" completion:nil];
    });
    if (self.gamepadDisplayLink) {
        [self.gamepadDisplayLink invalidate];
        self.gamepadDisplayLink = nil;
    }
    if (staleTouchSweepTimer) {
        [staleTouchSweepTimer invalidate];
        staleTouchSweepTimer = nil;
    }
    [self performSelector:@selector(widgetStopTimer)];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:@"ResolutionDidChangeNotification" object:nil];
    id tokens[] = {
        self.mouseConnectCallback,
        self.mouseDisconnectCallback,
        self.controllerConnectCallback,
        self.controllerDisconnectCallback,
        self.cursorTypeCallback,
        self.mouseScaleCallback,
        self.controlScaleCallback,
    };
    for (size_t i = 0; i < sizeof(tokens) / sizeof(tokens[0]); i++) {
        if (tokens[i]) {
            [nc removeObserver:tokens[i]];
        }
    }
    self.mouseConnectCallback = nil;
    self.mouseDisconnectCallback = nil;
    self.controllerConnectCallback = nil;
    self.controllerDisconnectCallback = nil;
    self.cursorTypeCallback = nil;
    self.mouseScaleCallback = nil;
    self.controlScaleCallback = nil;

    // If a hardware mouse is still attached it owns block handlers that
    // reference this controller; clear them so the mouse singleton does not
    // pin the view controller after the game session ends.
    if (GCMouse.current) {
        GCMouse *mouse = GCMouse.current;
        mouse.mouseInput.mouseMovedHandler = nil;
        mouse.mouseInput.leftButton.pressedChangedHandler = nil;
        mouse.mouseInput.middleButton.pressedChangedHandler = nil;
        mouse.mouseInput.rightButton.pressedChangedHandler = nil;
        [mouse.mouseInput.auxiliaryButtons makeObjectsPerformSelector:@selector(setPressedChangedHandler:) withObject:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Do NOT tear the session down here: this also fires for temporary
    // presentations (share sheet, crash screen, settings over the game).
    // Session cleanup belongs to dealloc, which runs when UIKit releases
    // this controller after UIKit_returnToSplitView changes rootVC.
}

- (void)dealloc {
    [self witch_teardownGameSession];
}

- (void)updateAudioSettings {
    NSError *sessionError = nil;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    // Deactivate before changing category to avoid audio glitches
    [session setActive:NO error:nil];

    // Keep recording available while a mod holds a capture line, otherwise
    // this would drop the session back to Playback under its feet.
    BOOL wantMic = getPrefBool(@"video.allow_microphone") || aac_isCapturing();

    AVAudioSessionCategory category;
    AVAudioSessionCategoryOptions options = 0;
    if(wantMic) {
        category = AVAudioSessionCategoryPlayAndRecord;
        options |= AVAudioSessionCategoryOptionAllowAirPlay | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker;
    } else {
        category = AVAudioSessionCategoryPlayback;
    }
    if(!getPrefBool(@"video.silence_other_audio")) {
        options |= AVAudioSessionCategoryOptionMixWithOthers;
    }
    [session setCategory:category withOptions:options error:&sessionError];

    if(wantMic) {
        [session setPreferredSampleRate:48000.0 error:&sessionError];
        [session setPreferredIOBufferDuration:0.005 error:&sessionError];
    }

    [session setActive:YES error:&sessionError];

    if(wantMic) {
        [self selectMicrophoneSource];
    }

    // Voice chat mods open a capture line whenever they like; resolve the
    // permission now so the first attempt already sees a hardware format
    // (AVAudioEngine terminates the process otherwise).
    aac_requestMicrophonePermission();
}

- (void)selectMicrophoneSource {
    NSError *error = nil;
    AVAudioSession *session = AVAudioSession.sharedInstance;

    AVAudioSessionPortDescription *builtInMic = nil;
    for (AVAudioSessionPortDescription *input in session.availableInputs) {
        if ([input.portType isEqualToString:AVAudioSessionPortBuiltInMic]) {
            builtInMic = input;
            break;
        }
    }

    if (!builtInMic || builtInMic.dataSources.count == 0) {
        NSLog(@"[MicSource] No built-in mic or no data sources available");
        return;
    }

    NSString *source = getPrefObject(@"video.microphone_source");
    NSArray<NSString *> *preferredOrder = nil;
    if (!source || [source isEqualToString:@"auto"]) {
        preferredOrder = @[@"Front", @"Bottom", @"Back"];
    } else if ([source isEqualToString:@"front"]) {
        preferredOrder = @[@"Front"];
    } else if ([source isEqualToString:@"bottom"]) {
        preferredOrder = @[@"Bottom"];
    } else if ([source isEqualToString:@"back"]) {
        preferredOrder = @[@"Back"];
    }

    for (NSString *prefName in preferredOrder) {
        for (AVAudioSessionDataSourceDescription *dataSource in builtInMic.dataSources) {
            if ([dataSource.dataSourceName localizedCaseInsensitiveContainsString:prefName]) {
                [session setPreferredInput:builtInMic error:&error];
                [builtInMic setPreferredDataSource:dataSource error:&error];
                NSLog(@"[MicSource] Selected: %@", dataSource.dataSourceName);
                return;
            }
        }
    }

    NSLog(@"[MicSource] No matching data source found, using system default");
}

- (void)updateJetsamControl {
    if (!getEntitlementValue(@"com.apple.private.memorystatus")) {
        return;
    }
    // More 1024MB is necessary for other memory regions (native, Java GC, etc.)
    int limit = getPrefInt(@"java.allocated_memory") + 1024;
    if (memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, getpid(), limit, NULL, 0) == -1) {
        NSLog(@"Failed to set Jetsam task limit: error: %s", strerror(errno));
    } else {
        NSLog(@"Successfully set Jetsam task limit");
    }
}

- (void)updatePreferenceChanges {
    // Update UITextField auto correction
    if (getPrefBool(@"debug.debug_auto_correction")) {
        self.inputTextField.autocorrectionType = UITextAutocorrectionTypeDefault;
    } else {
        self.inputTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }

    [self applyKeyboardToolbarPreference];

    BOOL gyroEnabled = getPrefBool(@"control.gyroscope_enable");
    BOOL gyroInvertX = getPrefBool(@"control.gyroscope_invert_x_axis");
    int gyroSensitivity = getPrefInt(@"control.gyroscope_sensitivity");
    [GyroInput updateSensitivity:gyroEnabled?gyroSensitivity:0 invertXAxis:gyroInvertX];

    self.mouseSpeed = getPrefFloat(@"control.mouse_speed") / 100.0;
    CGFloat cameraSensitivity = getPrefFloat(@"control.camera_sensitivity");
    self.cameraSensitivity = cameraSensitivity > 0 ? cameraSensitivity / 100.0 : 1.0;

    virtualMouseEnabled = getPrefBool(@"control.virtmouse_enable");
    self.mousePointerView.hidden = isGrabbing || !virtualMouseEnabled;
    AmethystSetSystemPointerHidden(self.view, isGrabbing || virtualMouseEnabled);

    // Update virtual mouse scale
    CGFloat mouseScale = getPrefFloat(@"control.mouse_scale") / 100.0;
    virtualMouseFrame = CGRectMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2, 18.0 * mouseScale, 27 * mouseScale);
    NSString *activeTypeId = [CursorTypeManager currentActiveTypeId];
    CGRect displayFrame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:activeTypeId];
    self.mousePointerView.image = [CursorTypeManager imageForType:activeTypeId displaySize:displayFrame.size];
    self.mousePointerView.frame = displayFrame;

    self.shouldHideControlsFromRecording = getPrefFloat(@"control.recording_hide");
    [self.ctrlView hideViewFromCapture:self.shouldHideControlsFromRecording];
    self.ctrlView.frame = getSafeArea(self.view.frame);

    // Update gestures state
    self.slideableHotbar = getPrefBool(@"control.slideable_hotbar");
    self.enableMouseGestures = getPrefBool(@"control.gesture_mouse");
    self.enableHotbarGestures = getPrefBool(@"control.gesture_hotbar");
    self.enableHoldGesture = getPrefBool(@"control.gesture_hold");
    self.enableDoubleTapOffhand = getPrefBool(@"control.doubletap_offhand");
    self.shouldTriggerHaptic = !getPrefBool(@"control.disable_haptics");

    self.scrollPanGesture.enabled = self.enableMouseGestures;
    self.doubleTapGesture.enabled = self.enableHotbarGestures;
    self.longPressGesture.minimumPressDuration = getPrefFloat(@"control.press_duration") / 1000.0;

    // Update audio settings
    [self updateAudioSettings];
    // Update resolution
    [self updateSavedResolution];
    // Update performance HUD visibility
    if (@available(iOS 16, tvOS 16, *)) {
        if ([self.surfaceView.layer isKindOfClass:CAMetalLayer.class]) {
            BOOL perfHUDEnabled = getPrefBool(@"video.performance_hud");
            ((CAMetalLayer *)self.surfaceView.layer).developerHUDProperties = perfHUDEnabled ? @{@"mode": @"default"} : nil;
        }
    }
    // Update pointer lock state
    [self setNeedsUpdateOfPrefersPointerLocked];
}

- (void)applyKeyboardToolbarPreference {
    UIToolbar *editingToolbar = getPrefBool(@"control.keyboard_editing_toolbar") ? self.keyboardToolbar : nil;
    if (self.inputTextField.inputAccessoryView != editingToolbar) {
        self.inputTextField.inputAccessoryView = editingToolbar;
        if (self.inputTextField.isFirstResponder) {
            [self.inputTextField reloadInputViews];
        }
    }
}

- (UIBarButtonItem *)keyboardBarButtonWithImage:(NSString *)imageName
                                           title:(NSString *)title
                                          action:(SEL)action {
    UIImage *image = [UIImage systemImageNamed:imageName];
    UIBarButtonItem *item = image
        ? [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:action]
        : [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:action];
    item.accessibilityLabel = title;
    return item;
}

- (UIToolbar *)keyboardToolbar {
    if (_keyboardToolbar) {
        return _keyboardToolbar;
    }

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    toolbar.translucent = YES;

    UIBarButtonItem *flexibleA = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flexibleB = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    toolbar.items = @[
        [self keyboardBarButtonWithImage:@"arrow.uturn.backward" title:localize(@"keyboard.action.undo", nil) action:@selector(keyboardUndo:)],
        [self keyboardBarButtonWithImage:@"arrow.uturn.forward" title:localize(@"keyboard.action.redo", nil) action:@selector(keyboardRedo:)],
        flexibleA,
        [self keyboardBarButtonWithImage:@"scissors" title:localize(@"keyboard.action.cut", nil) action:@selector(keyboardCut:)],
        [self keyboardBarButtonWithImage:@"doc.on.doc" title:localize(@"keyboard.action.copy", nil) action:@selector(keyboardCopy:)],
        [self keyboardBarButtonWithImage:@"doc.on.clipboard" title:localize(@"keyboard.action.paste", nil) action:@selector(keyboardPaste:)],
        flexibleB,
        [self keyboardBarButtonWithImage:@"selection.pin.in.out" title:localize(@"keyboard.action.select_all", nil) action:@selector(keyboardSelectAll:)],
        [self keyboardBarButtonWithImage:@"keyboard.chevron.compact.down" title:localize(@"keyboard.action.hide", nil) action:@selector(keyboardHide:)],
    ];
    [toolbar sizeToFit];
    _keyboardToolbar = toolbar;
    return _keyboardToolbar;
}

- (void)keyboardUndo:(id)sender {
    [self.inputTextField.undoManager undo];
}

- (void)keyboardRedo:(id)sender {
    [self.inputTextField.undoManager redo];
}

- (void)keyboardCut:(id)sender {
    [self.inputTextField cut:sender];
}

- (void)keyboardCopy:(id)sender {
    [self.inputTextField copy:sender];
}

- (void)keyboardPaste:(id)sender {
    [self.inputTextField paste:sender];
}

- (void)keyboardSelectAll:(id)sender {
    [self.inputTextField selectAll:sender];
}

- (void)keyboardHide:(id)sender {
    [self.inputTextField resignFirstResponder];
}

- (void)handleControlScaleChange {
    // Live update for Settings sliders: mouse_scale, button_scale, mouse_speed
    // Called via MouseScaleDidChangeNotification / ControlScaleDidChangeNotification
    // Keeps virtualMouseFrame size in sync and re-applies hitbox-aware displayFrame.
    CGFloat mouseScale = getPrefFloat(@"control.mouse_scale") / 100.0;
    if (mouseScale < 0.3) mouseScale = 1.0;
    // Preserve current center, update size to 18x27 * scale (same as updatePreferenceChanges)
    CGPoint center = CGPointMake(CGRectGetMidX(virtualMouseFrame), CGRectGetMidY(virtualMouseFrame));
    // Fallback if virtualMouseFrame was never initialized (zero rect at launch)
    if (virtualMouseFrame.size.width == 0 || virtualMouseFrame.size.height == 0) {
        center = CGPointMake(self.view.frame.size.width * 0.5, self.view.frame.size.height * 0.5);
    }
    CGFloat w = 18.0 * mouseScale;
    CGFloat h = 27.0 * mouseScale;
    virtualMouseFrame = CGRectMake(center.x - w*0.5, center.y - h*0.5, w, h);
    virtualMouseFrame.origin.x = clamp(virtualMouseFrame.origin.x, 0, self.view.frame.size.width - w);
    virtualMouseFrame.origin.y = clamp(virtualMouseFrame.origin.y, 0, self.view.frame.size.height - h);
    NSString *activeTypeId = [CursorTypeManager currentActiveTypeId];
    CGRect displayFrame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:activeTypeId];
    self.mousePointerView.image = [CursorTypeManager imageForType:activeTypeId displaySize:displayFrame.size];
    self.mousePointerView.frame = displayFrame;
    self.mousePointerView.hidden = isGrabbing || !getPrefBool(@"control.virtmouse_enable");
    AmethystSetSystemPointerHidden(self.view, isGrabbing || getPrefBool(@"control.virtmouse_enable"));
    self.mouseSpeed = getPrefFloat(@"control.mouse_speed") / 100.0;
    CGFloat cameraSensitivity = getPrefFloat(@"control.camera_sensitivity");
    self.cameraSensitivity = cameraSensitivity > 0 ? cameraSensitivity / 100.0 : 1.0;
    // Button scale live update: refresh control layout (ControlButton reads control.button_scale)
    for (UIView *v in self.ctrlView.subviews) {
        if ([v respondsToSelector:@selector(update)]) {
            [(id)v update];
        }
    }
    [self.ctrlView setNeedsLayout];
    [self.ctrlView layoutIfNeeded];
    NSLog(@"[SurfaceViewController] handleControlScaleChange mouseScale=%.2f buttonScale=%.2f mouseSpeed=%.2f -> virtualMouseFrame %@ displayFrame %@",
          mouseScale, getPrefFloat(@"control.button_scale")/100.0, self.mouseSpeed,
          NSStringFromCGRect(virtualMouseFrame), NSStringFromCGRect(self.mousePointerView.frame));
}

- (void)updateSavedResolution {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes.allObjects) {
        self.screenScale = scene.screen.scale;
        if (scene.session.role != UIWindowSceneSessionRoleApplication) {
            break;
        }
    }

    resolutionScale = getPrefFloat(@"video.resolution") / 100.0;

    // viewDidLoad calls this before creating surfaceView; don't publish a
    // zero-sized framebuffer to the game and don't overwrite valid metrics.
    if (self.surfaceView == nil) {
        return;
    }

    if (self.surfaceView.superview != nil) {
        self.surfaceView.frame = self.surfaceView.superview.frame;
    }

    self.surfaceView.layer.contentsScale = self.screenScale * resolutionScale;

    physicalWidth = roundf(self.surfaceView.frame.size.width * self.screenScale);
    physicalHeight = roundf(self.surfaceView.frame.size.height * self.screenScale);
    windowWidth = roundf(physicalWidth * resolutionScale);
    windowHeight = roundf(physicalHeight * resolutionScale);
    lastSurfaceSize = self.surfaceView.superview.bounds.size;
    // Resolution should not be odd
    if ((windowWidth % 2) != 0) {
        --windowWidth;
    }
    if ((windowHeight % 2) != 0) {
        --windowHeight;
    }
    CallbackBridge_nativeSendScreenSize(windowWidth, windowHeight);
}

- (void)updateControlHiddenState:(BOOL)hide {
    for (UIView *view in self.ctrlView.subviews) {
        ControlButton *button = (ControlButton *)view;
        if (!button.canBeHidden) continue;
        BOOL hidden = hide || !(
            (isGrabbing && [button.properties[@"displayInGame"] boolValue]) ||
            (!isGrabbing && [button.properties[@"displayInMenu"] boolValue]));
        if (!hidden && ![button isKindOfClass:ControlSubButton.class]) {
            button.hidden = hidden;
            if ([button isKindOfClass:ControlDrawer.class]) {
                [(ControlDrawer *)button restoreButtonVisibility];
            }
        } else if (hidden) {
            button.hidden = hidden;
        }
    }
}

- (void)updateGrabState {
    // A grab transition means the game's screen changed (chat/menu opened or
    // closed); the game-side text field content no longer matches the Telex
    // engine mirror, so forget the composition state.
    BOOL grabbingNow = (isGrabbing == JNI_TRUE);
    if (!lastGrabStateInited || grabbingNow != lastGrabState) {
        lastGrabStateInited = YES;
        lastGrabState = grabbingNow;
        [TelexInput reset];
        // Returning to gameplay: dismiss the on-screen keyboard if it was up
        // (chat/menu closed). The game-side mod will resend a keyboard-show
        // request if it is still needed.
        if (grabbingNow && self.inputTextField.isFirstResponder) {
            [self.inputTextField resignFirstResponder];
        }
    }

    // Update cursor position
    if (isGrabbing == JNI_TRUE) {
        CGFloat screenScale = self.surfaceView.layer.contentsScale;
        CallbackBridge_nativeSendCursorPos(ACTION_DOWN, lastVirtualMousePoint.x * screenScale, lastVirtualMousePoint.y * screenScale);
        virtualMouseFrame.origin.x = self.view.frame.size.width / 2;
        virtualMouseFrame.origin.y = self.view.frame.size.height / 2;
        NSString *activeTypeId = [CursorTypeManager currentActiveTypeId];
        self.mousePointerView.frame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:activeTypeId];
    }
    
    // Update cursor type based on grab state
    [CursorTypeManager setCursorHidden:(isGrabbing == JNI_TRUE)];

    self.scrollPanGesture.enabled = self.enableMouseGestures && !isGrabbing;
    self.mousePointerView.hidden = isGrabbing || !virtualMouseEnabled;
    AmethystSetSystemPointerHidden(self.view, isGrabbing || virtualMouseEnabled);
    [self setNeedsUpdateOfPrefersPointerLocked];

    // Update buttons visibility
    [self updateControlHiddenState:NO];
}

- (void)launchMinecraft {
    // Pre-launch setting checks (e.g. known-broken renderer configurations).
    // A visible notice defers the JVM launch; "continue anyway" resumes here
    // through beginMinecraftLaunch, "revert & exit" goes back to the launcher.
    if ([GameLaunchChecks presentFirstIssueIn:self.view onContinue:^{
        [self beginMinecraftLaunch];
    }]) {
        return;
    }
    [self beginMinecraftLaunch];
}

- (void)beginMinecraftLaunch {
    [self startBlackScreenWatchdog];
    [self presentLaunchSplash];
    [[PerfRecorder shared] startWithMetadata:@{
        @"version": self.metadata[@"id"] ?: @"",
        @"instance": self.metadata[@"instanceName"] ?: @""
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int ret;
        if (self.jarPath) {
            ret = launchJVMWithArgs(
                BaseAuthenticator.current.authData[@"username"] ?: @"Player",
                self.jarPath,
                windowWidth, windowHeight,
                self.jarMinJavaVersion,
                self.jarArgs
            );
        } else {
            int minVersion = [self.metadata[@"javaVersion"][@"majorVersion"] intValue];
            if (minVersion == 0) {
                minVersion = [self.metadata[@"javaVersion"][@"version"] intValue];
            }
            ret = launchJVM(
                BaseAuthenticator.current.authData[@"username"],
                self.metadata,
                windowWidth, windowHeight,
                minVersion
            );
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[PerfRecorder shared] stopWithReason:PerfStopReasonExited];
            UIKit_returnToSplitView();
        });
    });
}

- (void)loadCustomControls {
    self.edgeGesture.enabled = YES;
    [self.swipeableButtons removeAllObjects];
    NSString *controlFile = [PLProfiles resolveKeyForCurrentProfile:@"defaultTouchCtrl"];
    [self.ctrlView loadControlFile:controlFile];

    ControlButton *menuButton;
    for (ControlButton *button in self.ctrlView.subviews) {
        BOOL isSwipeable = [button.properties[@"isSwipeable"] boolValue];

        button.canBeHidden = YES;
        BOOL isMenuButton = NO;
        for (int i = 0; i < 4; i++) {
            int keycodeInt = [button.properties[@"keycodes"][i] intValue];
            button.canBeHidden &= keycodeInt != SPECIALBTN_TOGGLECTRL && keycodeInt != SPECIALBTN_VIRTUALMOUSE;
            if (keycodeInt == SPECIALBTN_MENU) {
                menuButton = button;
            }
        }

        [button addTarget:self action:@selector(executebtn_down:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(executebtn_up_inside:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(executebtn_up_outside:) forControlEvents:UIControlEventTouchUpOutside];

        if (isSwipeable) {
            UIPanGestureRecognizer *panRecognizerButton = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(executebtn_swipe:)];
            panRecognizerButton.delegate = self;
            [button addGestureRecognizer:panRecognizerButton];
            [self.swipeableButtons addObject:button];
        }
    }

    [self updateControlHiddenState:self.toggleHidden];

    if (menuButton) {
        __weak typeof(self) weakSelf = self;
        NSMutableArray *items = [NSMutableArray new];
        for (int i = 0; i < self.menuArray.count; i++) {
            UIAction *item = [UIAction actionWithTitle:localize(self.menuArray[i], nil) image:nil identifier:nil
                handler:^(id action) { [weakSelf didSelectMenuItem:i]; }];
            [items addObject:item];
        }
        menuButton.menu = [UIMenu menuWithTitle:@"" image:nil identifier:nil
            options:UIMenuOptionsDisplayInline children:items];
        menuButton.showsMenuAsPrimaryAction = YES;
        self.edgeGesture.enabled = NO;
    }

    // loadCustomControls is also called after editing controls in-game, and
    // it re-enables the edge recognizer above. Widget mode must keep that
    // recognizer off, otherwise the game can be swiped into the navigation
    // menu whose swipe strip is hidden in widget mode.
    if (getPrefBool(@"general.widget_menu")) {
        self.edgeGesture.enabled = NO;
        self.menuSwipeView.hidden = YES;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.rootView.bounds = CGRectMake(0, 0, size.width + 30.0, size.height);

        CGRect frame = self.view.frame;
        frame.size = size;
        self.touchView.frame = frame;
        self.inputTextField.frame = CGRectMake(0, 0, size.width, 30.0);
        [self viewWillTransitionToSize_Navigation:frame];

        // Update custom controls button position
        self.ctrlView.frame = getSafeArea(self.view.frame);
        [self.ctrlView.subviews makeObjectsPerformSelector:@selector(update)];

        // Reposition in-game widget (keeps user's relative position)
        [self performSelector:@selector(widgetRepositionFromDefaults)];

        // Update game resolution
        [self updateSavedResolution];
        [GyroInput updateOrientation];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        NSString *activeTypeId = [CursorTypeManager currentActiveTypeId];
        virtualMouseFrame = [CursorManager mouseFrameForDisplayFrame:self.mousePointerView.frame typeId:activeTypeId];
    }];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - Input: send touch utilities

- (BOOL)isTouchInactive:(UITouch *)touch {
    return touch == nil || touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled;
}

- (void)sendTouchPoint:(CGPoint)location withEvent:(int)event
{
    CGFloat screenScale = self.screenScale;
    if (!isGrabbing) {
        screenScale *= resolutionScale;
        if (virtualMouseEnabled) {
            if (event == ACTION_MOVE) {
                virtualMouseFrame.origin.x += (location.x - lastVirtualMousePoint.x) * self.mouseSpeed;
                virtualMouseFrame.origin.y += (location.y - lastVirtualMousePoint.y) * self.mouseSpeed;
            } else if (event == ACTION_MOVE_MOTION) {
                event = ACTION_MOVE;
                virtualMouseFrame.origin.x += location.x * self.mouseSpeed;
                virtualMouseFrame.origin.y += location.y * self.mouseSpeed;
            }
            virtualMouseFrame.origin.x = clamp(virtualMouseFrame.origin.x, 0, self.surfaceView.frame.size.width);
            virtualMouseFrame.origin.y = clamp(virtualMouseFrame.origin.y, 0, self.surfaceView.frame.size.height);
            lastVirtualMousePoint = location;
            NSString *activeTypeId = [CursorTypeManager currentActiveTypeId];
            self.mousePointerView.frame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:activeTypeId];
            
            CallbackBridge_nativeSendCursorPos(event, virtualMouseFrame.origin.x * screenScale, virtualMouseFrame.origin.y * screenScale);
            return;
        }
        lastVirtualMousePoint = location;
    }
    if (isGrabbing && event == ACTION_MOVE_MOTION) {
        CGFloat cameraSensitivity = self.cameraSensitivity > 0 ? self.cameraSensitivity : 1.0;
        location.x *= cameraSensitivity;
        location.y *= cameraSensitivity;
    }
    CallbackBridge_nativeSendCursorPos(event, location.x * screenScale, location.y * screenScale);
}

#pragma mark - Input: on-surface functions

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] ||
        [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        return NO;
    }
    return YES;
}

- (void)keyboardGesture:(UIGestureRecognizer*)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        if (self.inputTextField.isFirstResponder) {
            [self.inputTextField resignFirstResponder];
        } else {
            [self applyKeyboardToolbarPreference];
            [self.inputTextField becomeFirstResponder];
            // Insert an undeletable space
            self.inputTextField.text = @" ";
        }
    }
}

#import "touchcontroller_jni_bridge.h"

- (void)sendTouchEvent:(UITouch *)touchEvent withUIEvent:(UIEvent *)uievent withEvent:(int)event
{
    CGPoint locationInView = [touchEvent locationInView:self.rootView];

    // Convert to normalized coordinates [0, 1] relative to game view
    CGFloat gameWidth = self.surfaceView.frame.size.width;
    CGFloat gameHeight = self.surfaceView.frame.size.height;
    float normX = locationInView.x / gameWidth;
    float normY = locationInView.y / gameHeight;
    normX = MAX(0.0f, MIN(1.0f, normX));
    normY = MAX(0.0f, MIN(1.0f, normY));

    // TouchController integration
    if (event == ACTION_DOWN) {
        // UIKit can drop the matching touchesEnded during a frame stall, which
        // would leave this touch's pointer held down in the mod forever. The
        // system may also reuse the same UITouch object for a later sequence,
        // so before assigning a fresh index, release any leftover pointer that
        // is still mapped to this exact key. onTouchUp is a no-op if the mod
        // already released it, so this is always safe.
        NSNumber* existingTouchIndex = [touchControllerIndexMap objectForKey:touchEvent];
        if (existingTouchIndex != nil) {
            touchcontroller_onTouchUp([existingTouchIndex intValue]);
        }
        int index = touchcontroller_onTouchDown(normX, normY);
        if (index >= 0) {
            [touchControllerIndexMap setObject:@(index) forKey:touchEvent];
        }
    } else if (event == ACTION_MOVE || event == ACTION_MOVE_MOTION) {
        NSNumber* indexObj = [touchControllerIndexMap objectForKey:touchEvent];
        if (indexObj) {
            touchcontroller_onTouchMove([indexObj intValue], normX, normY);
        }
    } else if (event == ACTION_UP || event == ACTION_CANCEL) {
        NSNumber* indexObj = [touchControllerIndexMap objectForKey:touchEvent];
        if (indexObj) {
            touchcontroller_onTouchUp([indexObj intValue]);
            [touchControllerIndexMap removeObjectForKey:touchEvent];
        }
    }

    //if (touchEvent.view == self.surfaceView) {
        switch (event) {
            case ACTION_DOWN:
                self.clickRange = CGRectMake(locationInView.x - 2, locationInView.y - 2, 5, 5);
                self.shouldTriggerClick = YES;
                break;

            case ACTION_MOVE:
                if (self.shouldTriggerClick && !CGRectContainsPoint(self.clickRange, locationInView)) {
                    self.shouldTriggerClick = NO;
                }
                break;
        }

        if (touchEvent == self.hotbarTouch && self.slideableHotbar && ![self isTouchInactive:self.hotbarTouch]) {
            CGPoint hotbarPoint = [touchEvent locationInView:self.surfaceView];
            CGFloat screenScale = self.screenScale;
            int slot = self.enableHotbarGestures ?
            callback_SurfaceViewController_touchHotbar(hotbarPoint.x * screenScale, hotbarPoint.y * screenScale) : -1;
            /* Select on the initial press too. Previously currentHotbarSlot
             * was set in touchesBegan, so this condition was false for the
             * first slot and a drag that never crossed a slot boundary (most
             * visibly slot 1) produced no key at all. */
            if (slot != -1 && (event == ACTION_DOWN || currentHotbarSlot != slot)) {
                currentHotbarSlot = slot;
                CallbackBridge_nativeSendKey(slot, 0, 1, 0);
                CallbackBridge_nativeSendKey(slot, 0, 0, 0);
                return;
            } /* else if ((event == ACTION_MOVE || event == ACTION_UP) && slot == -1 && currentHotbarSlot != -1) {
                return;
            } */
            
            if (event == ACTION_DOWN && slot == -1) {
                currentHotbarSlot = -1;
            }
            /*
            if (currentHotbarSlot != -1) {
                return;
            }
            */
            return;
        }

        if (touchEvent == self.primaryTouch) {
            if ([self isTouchInactive:self.primaryTouch]) return; // FIXME: should be? ACTION_UP will never be sent
            if (event == ACTION_MOVE && isGrabbing) {
                event = ACTION_MOVE_MOTION;
                CGPoint prevLocationInView = [touchEvent previousLocationInView:self.rootView];
                float deltaX = locationInView.x - prevLocationInView.x;
                float deltaY = locationInView.y - prevLocationInView.y;
                locationInView.x -= prevLocationInView.x;
                locationInView.y -= prevLocationInView.y;

                // TouchController: once the mod's transport is live it owns
                // camera rotation (its View widget accumulates raw pointer
                // deltas itself). Injecting raw MoveView for every primary
                // drag here would also rotate the camera while dragging the
                // mod's joystick/buttons, because the launcher cannot know
                // the mod's layout. Only fall back to this channel during the
                // boot window before the mod has drained its first message.
                if (touchcontroller_launcher_mod_active() == 0) {
                    // TouchController: Send view movement for camera rotation
                    CGFloat gameWidth = self.surfaceView.frame.size.width;
                    CGFloat gameHeight = self.surfaceView.frame.size.height;
                    float normDeltaX = deltaX / gameWidth;
                    float normDeltaY = deltaY / gameHeight;
                    touchcontroller_onViewMove(normDeltaY, normDeltaX); // pitch = Y, yaw = X
                }
            }
            [self sendTouchPoint:locationInView withEvent:event];
        }
    //}
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    // Hardware-keyboard text is composed in-app by the Telex engine and
    // streamed straight to the game; iOS never delivers external-keyboard
    // text into the tracked field (see TrackedTextField instrumentation).
    // Resign any on-screen keyboard session the game started so physical keys
    // don't fall into the dead UIKit text path and the OSK hides.
    if (self.inputTextField.isFirstResponder) {
        [self.inputTextField resignFirstResponder];
        self.inputTextField.text = @" ";
    }
    for (UIPress *press in presses) {
        if (press.key != nil) {
            // A physical key press proves a hardware keyboard is attached.
            if (!hardwareKeyboardSeen) {
                hardwareKeyboardSeen = true;
            }
            // When a GUI screen is open (mouse grab released) text-producing
            // keys go through the Telex engine, which composes Vietnamese and
            // sends chars/backspaces to the game. During gameplay only
            // keycodes are sent (movement, menus), as before.
            if (isInputReady && isGrabbing != JNI_TRUE) {
                [TelexInput handleKey:press.key];
            }
            if ([KeyboardInput sendKeyEvent:press.key down:YES sendChars:NO]) {
                handled = YES;
            }
        }
    }
    if (!handled) {
        [super pressesBegan:presses withEvent:event];
    }
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    for (UIPress *press in presses) {
        if (press.key != nil && [KeyboardInput sendKeyEvent:press.key down:NO sendChars:NO]) {
            handled = YES;
        }
    }
    if (!handled) {
        [super pressesEnded:presses withEvent:event];
    }
}

- (BOOL)prefersPointerLocked {
    return GCMouse.mice.count > 0 && (isGrabbing || virtualMouseEnabled);
}

- (void)registerMouseCallbacks:(GCMouse *)mouse {
    NSLog(@"Input: Got mouse %@", mouse);
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float deltaX, float deltaY) {
        CGPoint delta = CGPointMake(deltaX, -deltaY);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendTouchPoint:delta withEvent:ACTION_MOVE_MOTION];
        });
    };

    mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, pressed, 0);
    };
    mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_MIDDLE, pressed, 0);
    };
    mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_RIGHT, pressed, 0);
    };
    // GLFW can handle up to 8 mouse buttons, the first 3 buttons are reserved for left,middle,right
    for (int i = 0; i < MIN(mouse.mouseInput.auxiliaryButtons.count, 5); i++) {
        mouse.mouseInput.auxiliaryButtons[i].pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_4 + i, pressed, 0);
        };
    }

    mouse.mouseInput.scroll.xAxis.valueChangedHandler = ^(GCControllerAxisInput * _Nonnull axis, float value) {
        CallbackBridge_nativeSendScroll(value, 0);
    };
    mouse.mouseInput.scroll.yAxis.valueChangedHandler = ^(GCControllerAxisInput * _Nonnull axis, float value) {
        CallbackBridge_nativeSendScroll(0, -value);
    };

    if (getPrefBool(@"control.hardware_hide")) {
        self.ctrlView.hidden = YES;
    }
}

- (void)surfaceOnClick:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded){
        if(self.shouldTriggerHaptic) {
            [self.lightHaptic impactOccurred];
        }
    }

    if (!self.shouldTriggerClick) return;

    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (currentHotbarSlot == -1) {
            if (!self.enableMouseGestures || !self.enableHoldGesture) return;
            CallbackBridge_nativeSendMouseButton(isGrabbing == JNI_TRUE ?
                GLFW_MOUSE_BUTTON_RIGHT : GLFW_MOUSE_BUTTON_LEFT, 1, 0);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 33 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                CallbackBridge_nativeSendMouseButton(isGrabbing == JNI_TRUE ?
                    GLFW_MOUSE_BUTTON_RIGHT : GLFW_MOUSE_BUTTON_LEFT, 0, 0);
            });
        } else if (!self.slideableHotbar) {
            /* Slideable hotbars already select on the initial ACTION_DOWN;
             * only the non-slideable path needs the tap recognizer. */
            CallbackBridge_nativeSendKey(currentHotbarSlot, 0, 1, 0);
            CallbackBridge_nativeSendKey(currentHotbarSlot, 0, 0, 0);
        }
    }
}

- (void)surfaceOnDoubleClick:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded){
        if(self.shouldTriggerHaptic) {
            [self.lightHaptic impactOccurred];
        }
    }
    
    if (sender.state == UIGestureRecognizerStateRecognized && isGrabbing) {
        CGFloat screenScale = self.screenScale;
        CGPoint point = [sender locationInView:self.surfaceView];
        int hotbarSlot = self.enableHotbarGestures ?
            callback_SurfaceViewController_touchHotbar(point.x * screenScale, point.y * screenScale) : -1;
        if (self.enableDoubleTapOffhand && hotbarSlot != -1 && currentHotbarSlot == hotbarSlot) {
            CallbackBridge_nativeSendKey(GLFW_KEY_F, 0, 1, 0);
            CallbackBridge_nativeSendKey(GLFW_KEY_F, 0, 0, 0);
        }
    }
}

- (void)surfaceOnHover:(UIGestureRecognizer *)sender {
    if (isGrabbing) return;
    
    CGPoint point = [sender locationInView:self.rootView];
    // NSLog(@"Mouse move!!");
    // NSLog(@"Mouse pos = %f, %f", point.x, point.y);
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            NSLog(@"[Input] Pointer hover began");
            hoverStartPoint = point;
            hoverMoved = NO;
            [self sendTouchPoint:point withEvent:ACTION_DOWN];
            break;
        case UIGestureRecognizerStateChanged:
            [self sendTouchPoint:point withEvent:ACTION_MOVE];
            if (hypotf(point.x - hoverStartPoint.x, point.y - hoverStartPoint.y) > 5.0) {
                hoverMoved = YES;
            }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self sendTouchPoint:point withEvent:ACTION_UP];
            // Send click if hover didn't move much (click detection for hover/mouse)
            if (!hoverMoved && virtualMouseEnabled) {
                CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, 1, 0);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 33 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                    CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, 0, 0);
                });
            }
            // Reset cursor to normal when mouse leaves the game area
            if (virtualMouseEnabled) {
                NSString *normalTypeId = @"normal";
                CGRect displayFrame = [CursorManager displayFrameForMouseFrame:virtualMouseFrame typeId:normalTypeId];
                self.mousePointerView.image = [CursorTypeManager imageForType:normalTypeId displaySize:displayFrame.size];
                self.mousePointerView.frame = displayFrame;
                // Notify the game to reset cursor shape
                [CursorTypeManager handleCursorShapeChange:0x6001 isSDL3:NO]; // GLFW_ARROW_CURSOR
            }
            break;
        default:
            // point = CGPointMake(-1, -1);
            break;
    }
}

-(void)surfaceOnLongpress:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded){
        if(self.shouldTriggerHaptic) {
            [self.mediumHaptic impactOccurred];
        }
    }
    
    if (!self.slideableHotbar) {
        CGPoint location = [sender locationInView:self.surfaceView];
        CGFloat screenScale = self.screenScale;
        currentHotbarSlot = self.enableHotbarGestures ?
            callback_SurfaceViewController_touchHotbar(location.x * screenScale, location.y * screenScale) : -1;
    }
    if (sender.state == UIGestureRecognizerStateBegan) {
        self.shouldTriggerClick = NO;
        if (currentHotbarSlot == -1) {

            if (self.enableMouseGestures && self.enableHoldGesture)
                CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, 1, 0);
        } else {
            CallbackBridge_nativeSendKey(GLFW_KEY_Q, 0, 1, 0);
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        // Nothing to do here, already handled in touchesMoved
    } else if (sender.state == UIGestureRecognizerStateCancelled
        || sender.state == UIGestureRecognizerStateFailed
            || sender.state == UIGestureRecognizerStateEnded)
    {
        if (currentHotbarSlot == -1) {
            if (self.enableMouseGestures && self.enableHoldGesture)
                CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, 0, 0);
        } else {
            CallbackBridge_nativeSendKey(GLFW_KEY_Q, 0, 0, 0);
        }
    }
}

- (void)surfaceOnTouchesScroll:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded){
        if(self.shouldTriggerHaptic) {
            [self.lightHaptic impactOccurred];
        }
    }
    
    if (isGrabbing) return;
    if (sender.state == UIGestureRecognizerStateBegan ||
        sender.state == UIGestureRecognizerStateChanged ||
        sender.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [sender velocityInView:self.rootView];
        if (velocity.x != 0.0f || velocity.y != 0.0f) {
            CallbackBridge_nativeSendScroll(velocity.x/self.view.frame.size.width, velocity.y/self.view.frame.size.height);
        }
    }
}

#pragma mark - Input view stuff

// An on-screen keyboard session takes ownership of the game field's text;
// the Telex engine mirror must not survive into the next hardware-keyboard
// session.
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [TelexInput reset];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    CallbackBridge_nativeSendKey(GLFW_KEY_ENTER, 0, 1, 0);
    CallbackBridge_nativeSendKey(GLFW_KEY_ENTER, 0, 0, 0);
    textField.text = @" ";
    return YES;
}

#pragma mark - On-screen button functions

- (void)executebtn:(ControlButton *)sender withAction:(int)action {
    int held = action == ACTION_DOWN;
    for (int i = 0; i < 4; i++) {
        int keycode = ((NSNumber *)sender.properties[@"keycodes"][i]).intValue;
        if (keycode < 0) {
            switch (keycode) {
                case SPECIALBTN_KEYBOARD:
                    if (held == 0) {
                        if (self.inputTextField.isFirstResponder) {
                            [self.inputTextField resignFirstResponder];
                        } else {
                            [self applyKeyboardToolbarPreference];
                            [self.inputTextField becomeFirstResponder];
                            // Insert an undeletable space
                            self.inputTextField.text = @" ";
                        }
                    }
                    break;

                case SPECIALBTN_MOUSEPRI:
                    CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_LEFT, held, 0);
                    break;

                case SPECIALBTN_MOUSESEC:
                    CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_RIGHT, held, 0);
                    break;

                case SPECIALBTN_MOUSEMID:
                    CallbackBridge_nativeSendMouseButton(GLFW_MOUSE_BUTTON_MIDDLE, held, 0);
                    break;

                case SPECIALBTN_TOGGLECTRL:
                    [self executebtn_special_togglebtn:held];
                    break;

                case SPECIALBTN_SCROLLDOWN:
                    if (!held) {
                        CallbackBridge_nativeSendScroll(0.0, 1.0);
                    }
                    break;

                case SPECIALBTN_SCROLLUP:
                    if (!held) {
                        CallbackBridge_nativeSendScroll(0.0, -1.0);
                    }
                    break;

                case SPECIALBTN_VIRTUALMOUSE:
                    if (!isGrabbing && !held) {
                        virtualMouseEnabled = !virtualMouseEnabled;
                        self.mousePointerView.hidden = !virtualMouseEnabled;
                        setPrefBool(@"control.virtmouse_enable", virtualMouseEnabled);
                        AmethystSetSystemPointerHidden(self.view, virtualMouseEnabled);
                        [self setNeedsUpdateOfPrefersPointerLocked];
                    }
                    break;

                case SPECIALBTN_MENU:
                    if (!held) {
                        [self actionOpenNavigationMenu];
                    }
                    break;

                default:
                    NSLog(@"Warning: button %@ sent unknown special keycode: %d", sender.titleLabel.text, keycode);
                    break;
            }
        } else if (keycode > 0) {
            // there's no key id 0, but we accidentally used -1 as a special key id, so we had to do that
            // if (keycode == 0) { keycode = -1; }
            // at the moment, send unknown keycode does nothing, may even cause performance issue, so ignore it
            CallbackBridge_nativeSendKey(keycode, 0, held, 0);
        }
    }
}

- (void)executebtn_down:(ControlButton *)sender
{
    if(self.shouldTriggerHaptic) {
        [self.lightHaptic impactOccurred];
    }
    
    if (sender.savedBackgroundColor == nil) {
        [self executebtn:sender withAction:ACTION_DOWN];
    }
    if ([self.swipeableButtons containsObject:sender]) {
        self.swipingButton = sender;
    }
}

- (void)executebtn_swipe:(UIPanGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateCancelled || sender.state == UIGestureRecognizerStateEnded) {
        [self executebtn_up:self.swipingButton isOutside:NO];
        return;
    }
    CGPoint location = [sender locationInView:self.ctrlView];
    for (ControlButton *button in self.swipeableButtons) {
        if (CGRectContainsPoint(button.frame, location) && (ControlButton *)self.swipingButton != button) {
            [self executebtn_up:self.swipingButton isOutside:NO];
            self.swipingButton = (ControlButton *)button;
            [self executebtn:self.swipingButton withAction:ACTION_DOWN];
            break;
        }
    }
}

- (void)executebtn_up:(ControlButton *)sender isOutside:(BOOL)isOutside
{
    if (self.swipingButton == sender) {
        [self executebtn:self.swipingButton withAction:ACTION_UP];
        self.swipingButton = nil;
    } else if (sender.savedBackgroundColor == nil) {
        [self executebtn:sender withAction:ACTION_UP];
        return;
    }

    if (isOutside || sender.savedBackgroundColor == nil) {
        return;
    }

    sender.isToggleOn = !sender.isToggleOn;
    if (sender.isToggleOn) {
        sender.backgroundColor = [self.view.tintColor colorWithAlphaComponent:CGColorGetAlpha(sender.savedBackgroundColor.CGColor)];
        [self executebtn:sender withAction:ACTION_DOWN];
    } else {
        sender.backgroundColor = sender.savedBackgroundColor;
        [self executebtn:sender withAction:ACTION_UP];
    }

    if(self.shouldTriggerHaptic) {
        [self.lightHaptic impactOccurred];
    }
}

- (void)executebtn_up_inside:(ControlButton *)sender {
    [self executebtn_up:sender isOutside:NO];
}

- (void)executebtn_up_outside:(ControlButton *)sender {
    [self executebtn_up:sender isOutside:YES];
}

- (void)executebtn_special_togglebtn:(int)held {
    if (held) return;
    self.toggleHidden = !self.toggleHidden;
    [self updateControlHiddenState:self.toggleHidden];
}

#pragma mark - Input: On-screen touch events

int touchesMovedCount;

// TouchController: sweep the index map for touches that ended/cancelled
// without a matching ACTION_UP (UIKit can drop touchesEnded during stalls),
// which would otherwise leave the mod holding a button forever. Re-sending an
// Up for an already-released index is harmless (the mod's removePointer is a
// no-op once the pointer is already Released).
- (void)sendTouchControllerStaleUps
{
    NSMutableArray* staleTouches = [NSMutableArray array];
    for (id key in [touchControllerIndexMap keyEnumerator]) {
        UITouch* touch = (UITouch*)key;
        if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            [staleTouches addObject:touch];
        }
    }
    for (UITouch* touch in staleTouches) {
        NSNumber* indexObj = [touchControllerIndexMap objectForKey:touch];
        if (indexObj) {
            touchcontroller_onTouchUp([indexObj intValue]);
            [touchControllerIndexMap removeObjectForKey:touch];
        }
    }
}

// Lazy 0.25s sweep timer, so a stuck pointer is recovered even if the user
// stops touching entirely. No-op when the index map is empty. 0.5s was too
// slow at the game's ~14fps (7+ render frames of stuck hold/break).
static NSTimer* staleTouchSweepTimer = nil;

- (void)ensureTouchControllerSweepTimer
{
    if (staleTouchSweepTimer != nil) return;
    __weak typeof(self) weakSelf = self;
    staleTouchSweepTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer* timer) {
        [weakSelf sendTouchControllerStaleUps];
    }];
}

// Equals to Android ACTION_DOWN
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self ensureTouchControllerSweepTimer];
    [self sendTouchControllerStaleUps];
    int i = 0;
    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeIndirectPointer) {
            continue; // handle this in a different place
        }
        CGPoint locationInView = [touch locationInView:self.surfaceView];
        CGFloat screenScale = self.screenScale;
        currentHotbarSlot = self.enableHotbarGestures ?
            callback_SurfaceViewController_touchHotbar(locationInView.x * screenScale, locationInView.y * screenScale) : -1;
        if ([self isTouchInactive:self.hotbarTouch] && currentHotbarSlot != -1) {
            self.hotbarTouch = touch;
        }
        if ([self isTouchInactive:self.primaryTouch] && currentHotbarSlot == -1) {
            self.primaryTouch = touch;
        }
        [self sendTouchEvent:touch withUIEvent:event withEvent:ACTION_DOWN];
        break;
    }
}

// Equals to Android ACTION_MOVE
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self sendTouchControllerStaleUps];

    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeIndirectPointer) {
            if (!isGrabbing && !virtualMouseEnabled) {
                CGPoint point = [touch locationInView:self.rootView];
                [self sendTouchPoint:point withEvent:ACTION_MOVE];
            }
            continue; // handle this in a different place
        }
        if (self.hotbarTouch != touch && [self isTouchInactive:self.primaryTouch]) {
            // Replace the inactive touch with the current active touch
            self.primaryTouch = touch;
            [self sendTouchEvent:touch withUIEvent:event withEvent:ACTION_DOWN];
        }
        [self sendTouchEvent:touch withUIEvent:event withEvent:ACTION_MOVE];
    }
}

// For ACTION_UP and ACTION_CANCEL
- (void)touchesEndedGlobal:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeIndirectPointer) {
            continue; // handle this in a different place
        }
        [self sendTouchEvent:touch withUIEvent:event withEvent:ACTION_UP];
    }
    [self sendTouchControllerStaleUps];
}

// Equals to Android ACTION_UP
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self touchesEndedGlobal:touches withEvent:event];
}

// Equals to Android ACTION_CANCEL
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self touchesEndedGlobal:touches withEvent:event];
    
    // Cancel all TouchController pointers
    touchcontroller_onTouchCancel();
}

+ (BOOL)isRunning {
    return [UIWindow.mainWindow.rootViewController isKindOfClass:SurfaceViewController.class];
}

+ (GameSurfaceView *)surface {
    return pojavWindow;
}

@end
