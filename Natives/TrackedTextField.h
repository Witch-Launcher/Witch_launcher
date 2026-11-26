#import <UIKit/UIKit.h>

#include "jni.h"

@interface TrackedTextField : UITextField

@property(nonatomic, copy) void(^sendChar)(jchar codepoint);
@property(nonatomic, copy) void(^sendCharMods)(jchar codepoint, int mods);
@property(nonatomic, copy) void(^sendKey)(int key, int scancode, int action, int mods);

// Set when a hardware key was already forwarded to the game by the Telex
// engine: the matching UIKit text change has to be dropped, otherwise the
// character would be typed twice (or deleted twice).
@property(nonatomic) BOOL ignoreNextTextChange;

@end
