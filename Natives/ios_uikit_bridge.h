#pragma once
#import <UIKit/UIKit.h>
#include "jni.h"

#define CLIPBOARD_COPY 2000
#define CLIPBOARD_PASTE 2001

UIViewController* tmpRootVC;

void showDialog(NSString* title, NSString* message);
UIInterfaceOrientationMask amethyst_orientation_mask(void);
jstring UIKit_accessClipboard(JNIEnv* env, jint action, jstring copySrc);
void UIKit_launchMinecraftSurfaceVC(UIWindow *window, NSDictionary *metadata);
void UIKit_launchJarFile(UIWindow *window, NSString *jarPath);
void UIKit_launchJarFileWithArgs(UIWindow *window, NSString *jarPath, NSArray<NSString *> *args, int minJavaVersion);
void UIKit_returnToSplitView();
void launchInitialViewController(UIWindow *window);

void AWTInputBridge_sendKey(int keycode);
