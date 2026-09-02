cmake_minimum_required(VERSION 3.6)
project(Witch)

configure_file(${CMAKE_CURRENT_LIST_DIR}/config.h.in ${CMAKE_CURRENT_LIST_DIR}/config.h)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -target arm64-apple-ios -mcpu=apple-a9 -fcommon -fobjc-arc -ObjC -Wno-error=implicit-function-declaration -F'${CMAKE_OSX_SYSROOT}/System/Cryptexes/OS/System/Library/Frameworks' -mios-version-min=14.0")
set(CMAKE_C_FLAGS_DEBUG "-funwind-tables -g")

if("${CMAKE_HOST_SYSTEM_NAME}" MATCHES "Linux|^GNU$|Android")
set(GLOBAL_LDFLAGS "-isysroot ${CMAKE_OSX_SYSROOT} -Wl,-syslibroot,${CMAKE_OSX_SYSROOT} -fuse-ld=lld")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${GLOBAL_LDFLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${GLOBAL_LDFLAGS}")
endif()

include_directories(
  "."
  "external/AFNetworking/AFNetworking"
  "external/AFNetworking/UIKit+AFNetworking"
  "external/DBNumberedSlider/Classes"
  "external/NRFileManager"
  "external/UnzipKit/Source"
  "external/fishhook"
  "external/lzma"
  "external/mesa"
  "external/AltKit"
  "external/Apple"
  "external/ballpa1n"
  "external/ballpa1n/wrapped"
  "external/mach"
  "../UI"
  "../UI/Common"
  "../UI/Common/MMMarkdown"
  "../UI/Root"
  "../UI/App"
  "../UI/Managers"
  "../UI/Screens/MainMenu"
  "../UI/Screens/CrashLog"
  "../UI/Screens/Game"
  "../UI/Screens/Mod"
  "../UI/Screens/Modpack"
  "../UI/Screens/Shader"
  "../UI/Screens/Server"
   "../UI/Screens/Settings"
   "../UI/Screens/Account"
   "../UI/Screens/Download"
   "../UI/Screens/FileBrowser"
   "../UI/Screens/ProfileSettings"
   "../UI/Screens/AI"
  "installer/modpack"
)

# For cacio support library
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -rpath @loader_path -rpath @executable_path/java_runtimes/java-8-openjdk/lib -rpath /usr/lib/jvm/java-8-openjdk/lib")

# EXT: stub library, delete after compile awt_xawt
add_library(awt_headless SHARED
  awt_xawt/empty.m
)
target_link_libraries(awt_headless)

# EXT: cacio support library
add_library(awt_xawt SHARED
  awt_xawt/xawt_fake.m
)
target_link_libraries(awt_xawt
  "-L'${CMAKE_CURRENT_LIST_DIR}/build'"
  awt_headless
)

set(CMAKE_FRAMEWORK_PATH "${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks")

# Flat namespace so LTW's eglGetProcAddress/gl* wrappers shadow ANGLE's
# (LTW is dlopen'd after ANGLE, so flat ns gives LTW priority).
# This mirrors Android's symbol resolution and is required for LTW's
# wrapper layer to intercept GL function lookups from LWJGL.
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -rpath @executable_path/Frameworks -rpath @loader_path/Frameworks -Wl,-flat_namespace -Wl,-undefined,dynamic_lookup")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -rpath @executable_path/Frameworks -rpath @loader_path/Frameworks")

# ANGLE wrapper for 1.17+
add_library(tinygl4angle SHARED
  external/gl4es/string_utils.c
  external/gl4es/tinygl4angle.c
)
target_link_libraries(tinygl4angle
  "${GLOBAL_LDFLAGS}"
  "-F'${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks'"
  "-framework libEGL"
  "-framework libGLESv2"
)

# LTW (Large Thin Wrapper) - OpenGL core-to-ES wrapper
set(LTW_DIR "${CMAKE_CURRENT_LIST_DIR}/external/LTW/ltw/src/main/tinywrapper")
set(LTW_INCLUDES
  "${LTW_DIR}"
  "${LTW_DIR}/GL"
  "${CMAKE_CURRENT_LIST_DIR}/cmake/ltw_compat"
  "${LTW_DIR}/glsl_optimizer/include"
  "${LTW_DIR}/glsl_optimizer/src"
  "${LTW_DIR}/vgpu_shaderconv"
  "${LTW_DIR}/unordered_map"
  "${CMAKE_CURRENT_LIST_DIR}/external/MobileGlues/src/main/cpp/include"
)

include(cmake/ltw_sources.cmake)

file(GLOB_RECURSE GLSL_OPTIMIZER_SRC
  "${LTW_DIR}/glsl_optimizer/src/*.c"
  "${LTW_DIR}/glsl_optimizer/src/*.cpp"
)
list(FILTER GLSL_OPTIMIZER_SRC EXCLUDE REGEX ".*u_debug_stack_android\\.cpp$")

add_library(glsl_optimizer STATIC ${GLSL_OPTIMIZER_SRC})
target_include_directories(glsl_optimizer PRIVATE ${LTW_INCLUDES})
set_target_properties(glsl_optimizer PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  CXX_STANDARD 17
  C_STANDARD 11
)
target_compile_definitions(glsl_optimizer PRIVATE
  _LIB NOMINMAX _USE_MATH_DEFINES __STDC_NO_THREADS__
  __STDC_LIMIT_MACROS __STDC_FORMAT_MACROS __STDC_CONSTANT_MACROS
  UTL_ARCH_LITTLE_ENDIAN UNIX
  HAVE_OPENGL HAVE_OPENGL_ES_1 HAVE_OPENGL_ES_2
  HAVE_TIMESPEC_GET HAVE_STRUCT_TIMESPEC
  VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK=VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK_EXT
)

add_library(ltw SHARED ${LTW_CORE_SRC})
target_include_directories(ltw PRIVATE ${LTW_INCLUDES})
target_link_libraries(ltw
  "${GLOBAL_LDFLAGS}"
  -Wl,-force_load,$<TARGET_FILE:glsl_optimizer>
  glsl_optimizer
  "-F'${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks'"
  "-framework libEGL"
  "-framework libGLESv2"
)
set_target_properties(ltw PROPERTIES
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)
target_compile_definitions(ltw PRIVATE
  _LIB NOMINMAX _USE_MATH_DEFINES __STDC_NO_THREADS__
  __STDC_LIMIT_MACROS __STDC_FORMAT_MACROS __STDC_CONSTANT_MACROS
  UTL_ARCH_LITTLE_ENDIAN UNIX
  HAVE_OPENGL HAVE_OPENGL_ES_1 HAVE_OPENGL_ES_2
)

# AFNetworking
add_library(AFNetworking SHARED
  external/AFNetworking/AFNetworking/AFSecurityPolicy.m
  external/AFNetworking/AFNetworking/AFHTTPSessionManager.m
  external/AFNetworking/AFNetworking/AFURLRequestSerialization.m
  external/AFNetworking/AFNetworking/AFURLSessionManager.m
  external/AFNetworking/AFNetworking/AFNetworkReachabilityManager.m
  external/AFNetworking/AFNetworking/AFURLResponseSerialization.m
  external/AFNetworking/UIKit+AFNetworking/AFNetworkActivityIndicatorManager.m
  external/AFNetworking/UIKit+AFNetworking/AFAutoPurgingImageCache.m
  external/AFNetworking/UIKit+AFNetworking/AFImageDownloader.m
  external/AFNetworking/UIKit+AFNetworking/UIButton+AFNetworking.m
  external/AFNetworking/UIKit+AFNetworking/UIImageView+AFNetworking.m
)
target_link_libraries(AFNetworking
  "-framework CoreGraphics"
  "-framework CoreServices"
  "-framework Security"
  "-framework SystemConfiguration"
  "-framework UIKit"
)

# MinecraftAccount JNI
add_library(AmethystAccountJNI SHARED
  authenticator/MinecraftAccountJNI.m
)
target_link_libraries(AmethystAccountJNI)

# Audio capture JNI bridge
add_library(audio_capture SHARED
  audio_capture_bridge.m
)
target_link_libraries(audio_capture
  "-framework AVFoundation"
)

# TouchController bridge: launcher-side JNI (IosSocketTransport/vibration/
# keyboard) lives in its OWN dylib so the launcher can System.load() it
# without registering the main executable with the launcher classloader.
# The game's Knot classloader must be the one that System.load()s
# Witch (via LWJGL's Library.<clinit>) so the game-side JNI
# stubs (top.fifthlight.touchcontroller...) resolve; loading the executable
# from the launcher first makes Knot's second System.load() fail with
# "already loaded in another classloader" and the game then crashes with
# UnsatisfiedLinkError on the first GLFW native call.
add_library(TouchControllerBridge SHARED
  touchcontroller_launcher.c
  touchcontroller_jni_bridge.c
  touchcontroller_vibration.m
  touchcontroller_keyboard.m
)
target_link_libraries(TouchControllerBridge
  "${GLOBAL_LDFLAGS}"
  "-framework UIKit"
  "-framework Foundation"
  "-framework QuartzCore"
)
set_target_properties(TouchControllerBridge PROPERTIES
  MACOSX_RPATH TRUE
  INSTALL_NAME_DIR "@rpath"
)

# TouchController game-side JNI bridge: stubs for
# top.fifthlight.touchcontroller.common.platform.ios.Transport, loaded by the
# game's Knot classloader (via LWJGL's Library.<clinit>). It MUST be a dylib:
# the launcher loads the main executable first (UIKit static init), so a Knot
# System.load of the executable fails with "already loaded in another
# classloader" and the game can never resolve JNI symbols that live in the
# executable (as seen with Transport.new -> UnsatisfiedLinkError).
add_library(TouchControllerGameBridge SHARED
  touchcontroller_game_bridge.c
)
target_link_libraries(TouchControllerGameBridge
  "${GLOBAL_LDFLAGS}"
  "-Wl,-undefined,dynamic_lookup"
)
set_target_properties(TouchControllerGameBridge PROPERTIES
  MACOSX_RPATH TRUE
  INSTALL_NAME_DIR "@rpath"
)

# Witch
add_executable(Witch
  dyld_bypass_validation.m
  dyld_patch_platform.m
  jit_vm_remap_hook.m
  main.m
  main_hook.m
  JavaLauncher.m
  external/fishhook/fishhook.c
  UIKit+hook.m

  authenticator/BaseAuthenticator.m
  authenticator/LocalAuthenticator.m
  authenticator/MicrosoftAuthenticator.m
  authenticator/ElyAuthenticator.m

  ctxbridges/gl_bridge.m
  ctxbridges/osm_bridge.m
  ctxbridges/vk_bridge.m

  framegen/framegen.mm
  framegen/framegen_jni_bridge.m

  debug/DebugServer.m
 
  customcontrols/ControlButton.m
  customcontrols/ControlDrawer.m
  customcontrols/ControlJoystick.m
  customcontrols/ControlLayout.m
  customcontrols/ControlSubButton.m
  customcontrols/CustomControlsUtils.m
  customcontrols/NSPredicateUtilitiesExternal.m

  external/DBNumberedSlider/Classes/DBNumberedSlider.m
  external/NRFileManager/NSFileManager+NRFileManager.m
  external/ballpa1n/HostManager.c
  external/ballpa1n/wrapped/HostManagerBridge.m
  external/mach/mach_excServer.c

  installer/FabricUtils.m
  installer/modpack/ModpackUtils.m
  installer/modpack/ModpackAPI.m

  input/ControllerInput.m
  input/GyroInput.m
  input/KeyboardInput.m
  input/TelexInput.m

  AccountListViewController.m
  AppDelegate.m
  CustomControlsViewController.m
  CustomControlsViewController+UndoManager.m
  DownloadProgressViewController.m
  FileListViewController.m
  GameSurfaceView.m
  JavaGUIViewController.m
  LauncherPreferences.m
  LauncherPrefContCfgViewController.m
  LauncherPrefGameDirViewController.m
  LauncherPrefManageJREViewController.m
  MinecraftResourceDownloadTask.m
  MinecraftResourceUtils.m
  PickTextField.m
  PLLogOutputView.m
  PLPickerView.m
  PLPreferences.m
  PLProfiles.m
  SceneDelegate.m
  SceneExternalDelegate.m
  SurfaceViewController.m
  SurfaceViewController+ExternalDisplay.m
  SurfaceViewController+LogView.m
  SurfaceViewController+Navigation.m
  SurfaceViewController+Widget.m
  TrackedTextField.m
  system_monitor.m
egl_bridge.m
    ZinkConfig.m
    input_bridge_v3.m
    ios_uikit_bridge.m
    utils.m

   # UI
   ../UI/Common/ThemeManager.m
   ../UI/Common/MarkdownRenderer.m
   ../UI/Common/MMMarkdown/MMDocument.m
   ../UI/Common/MMMarkdown/MMElement.m
   ../UI/Common/MMMarkdown/MMGenerator.m
   ../UI/Common/MMMarkdown/MMHTMLParser.m
   ../UI/Common/MMMarkdown/MMMarkdown.m
   ../UI/Common/MMMarkdown/MMParser.m
   ../UI/Common/MMMarkdown/MMScanner.m
   ../UI/Common/MMMarkdown/MMSpanParser.m
   ../UI/Common/HapticManager.m
   ../UI/Common/ElySkinHead.m
   ../UI/Common/CustomButton.m
   ../UI/Common/CustomSlider.m
   ../UI/Common/BlurContainerView.m
   ../UI/Common/TransitionAnimator.m
   ../UI/Common/UIView+AmethystExtensions.m
   ../UI/Common/DownloadProgressOverlay.m
   ../UI/Common/InstallerProgressViewController.m
    ../UI/Common/AmethystProjectCell.m
    ../UI/Common/UIView+LiquidGlass.m
    ../UI/Common/AmethystBlurView.m
   ../UI/Common/BlurredDialog.m
    ../UI/Root/AmethystRootViewController.m
   ../UI/Root/TopBarView.m
   ../UI/Root/SidebarViewController.m
   ../UI/Root/RightPanelViewController.m
   ../UI/App/MainCoordinator.m
   ../UI/Managers/VersionDirectoryManager.m
   ../UI/Managers/DownloadManager.m
    ../UI/Managers/CursorManager.m
    ../UI/Managers/CursorTypeManager.m
    ../UI/Managers/InstalledModsManager.m
   ../UI/Screens/MainMenu/MainMenuViewController.m
    WitchAIService.m
    WitchLogReporter.m
    WitchAppAttest.m
   ../UI/Screens/CrashLog/CrashLogAnalyzer.m
   ../UI/Screens/CrashLog/CrashScreenViewController.m
   ../UI/Screens/AI/WitchAIChatViewController.m
   ../UI/Screens/Game/GameListViewController.m
   ../UI/Screens/Mod/ModListViewController.m
   ../UI/Screens/Mod/ModDetailViewController.m
   ../UI/Screens/Mod/MrpackInstaller.m
   ../UI/Screens/Mod/ModrinthService.m
   ../UI/Screens/Mod/CurseForgeService.m
   ../UI/Screens/Modpack/ModpackListViewController.m
   ../UI/Screens/Shader/ShaderListViewController.m
   ../UI/Screens/Server/ServerListViewController.m
   ../UI/Screens/Settings/SettingsViewController.m
   ../UI/Screens/Settings/CreditsService.m
    ../UI/Screens/Settings/CursorSettingsViewController.m
    ../UI/Screens/Settings/CursorTypeDetailViewController.m
    ../UI/Screens/Settings/CursorHitboxEditorViewController.m
   ../UI/Screens/Account/AccountViewController.m
   ../UI/Screens/ProfileSettings/ProfileSettingsViewController.m
   ../UI/Screens/Download/DownloadHubViewController.m
   ../UI/Screens/Download/VersionBrowserViewController.m
    ../UI/Screens/Download/MapListViewController.m
    ../UI/Screens/Download/ResourcePackListViewController.m
    ../UI/Screens/FileBrowser/FileBrowserViewController.m
)

if("${CMAKE_HOST_SYSTEM_NAME}" MATCHES "Linux|^GNU$|Android")
target_sources(Witch PUBLIC non_darwin_utils.m)
endif()

target_link_libraries(Witch
  PUBLIC AFNetworking
  TouchControllerBridge
  lzma
  "-F'${CMAKE_CURRENT_LIST_DIR}/build'"
  "-F'${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks'"
  "-framework AltKit"
  "-framework AuthenticationServices"
  "-framework AVFoundation"
  "-framework BackgroundTasks"
  "-framework CAltKit"
  "-framework CoreFoundation"
  "-framework CoreGraphics"
  "-framework CoreImage"
  "-framework CoreMotion"
  "-framework GameController"
  "-framework IOSurface"
  "-framework IOKit"
  "-framework PhotosUI"
  "-framework QuartzCore"
  "-framework Security"
  "-framework Metal"
  "-framework MetalKit"
  "-framework UIKit"
  "-framework UniformTypeIdentifiers"
  "-framework UnzipKit"
  "-framework WebKit"
  "-framework DeviceCheck"
  "-weak_framework SafariServices"
)
set_target_properties(Witch PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_FRAMEWORK_IDENTIFIER org.cmake.ExecutableTarget
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist")
