#import "TelexInput.h"
#import "TelexComposer.h"
#import "../utils.h"
#import "../LauncherPreferences.h"

#include "../glfw_keycodes.h"

/*
 * Hardware keyboard glue for the in-app Vietnamese (Telex) engine.
 *
 * iOS never materializes hardware-keyboard text into the launcher's tracked
 * UITextField (no UIFieldEditor text session is created for it on these iOS
 * versions - see TrackedTextField instrumentation), so system-level
 * Vietnamese composition is impossible. Instead the engine applies the Telex
 * rules itself and streams the composed text into the game through the same
 * charMods path the on-screen keyboard uses.
 *
 * The engine is the ONLY writer of the text it owns:
 *  - it sends the delete events itself, so the raw backspace key event must
 *    not be forwarded to the game as well (the game removes one character
 *    per backspace key event, forwarding both deleted two characters per
 *    press and the composition drifted away from the text on screen);
 *  - whenever something else edits the field (the on-screen keyboard, a
 *    screen switch) the mirror is dropped, so the engine never rewrites text
 *    that is not there anymore.
 *
 * Vietnamese composition only runs when the keyboard layout asks for it: with
 * an English layout the keys are streamed verbatim. The control.keyboard_input_mode
 * preference ("auto" / "vi" / "en") overrides the automatic detection.
 */

@implementation TelexInput

static TelexComposer *gComposer;

+ (TelexComposer *)composer {
    if (gComposer == nil) {
        gComposer = [[TelexComposer alloc] init];
        gComposer.sendBackspaces = ^(int count) {
            for (int i = 0; i < count; i++) {
                CallbackBridge_nativeSendKey(GLFW_KEY_BACKSPACE, 0, 1, 0);
                CallbackBridge_nativeSendKey(GLFW_KEY_BACKSPACE, 0, 0, 0);
            }
        };
        gComposer.sendChar = ^(unichar ch) {
            CallbackBridge_nativeSendCharMods(ch, 0);
        };
    }
    return gComposer;
}

/*
 * YES when the Vietnamese rules have to be applied. "auto" follows the
 * keyboard layout reported by the responder chain (the input language of the
 * active input mode), the other values force it on or off.
 */
+ (BOOL)shouldCompose:(NSString *)inputLanguage {
    id pref = getPrefObject(@"control.keyboard_input_mode");
    NSString *mode = [pref isKindOfClass:[NSString class]] ? [pref lowercaseString] : @"auto";
    if ([mode isEqualToString:@"vi"]) return YES;
    if ([mode isEqualToString:@"en"]) return NO;
    NSString *language = [inputLanguage lowercaseString];
    return [language hasPrefix:@"vi"];
}

+ (BOOL)consumesKey:(UIKey *)key {
    if (key == nil) return NO;
    return key.keyCode == UIKeyboardHIDUsageKeyboardDeleteOrBackspace;
}

+ (BOOL)handleKey:(UIKey *)key inputLanguage:(NSString *)inputLanguage {
    if (key == nil) return NO;
    TelexComposer *composer = [self composer];

    if (key.keyCode == UIKeyboardHIDUsageKeyboardDeleteOrBackspace) {
        [composer deleteBackward];
        // The engine sent the delete events: the raw key event must not be
        // forwarded, the game would delete a second character.
        return YES;
    }
    if (key.keyCode == UIKeyboardHIDUsageKeyboardDeleteForward) {
        // Forward delete does not touch the end of the text, the game can
        // handle it on its own.
        return NO;
    }

    NSString *chars = key.characters;
    if (chars == nil || chars.length == 0) return NO;

    BOOL compose = [self shouldCompose:inputLanguage];
    if (compose != composer.composeVietnamese) {
        // The input method changed: the raw buffer no longer describes what is
        // on screen, start over (the game keeps the text it already has).
        [composer reset];
        composer.composeVietnamese = compose;
    }

    [composer insertCharacters:chars];
    return NO;
}

+ (void)reset {
    [[self composer] reset];
}

@end
