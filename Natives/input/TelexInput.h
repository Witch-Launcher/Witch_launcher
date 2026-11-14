#import <UIKit/UIKit.h>

@interface TelexInput : NSObject

/*
 * Handles one hardware key press.
 *
 * Returns YES when the engine consumed the key. The caller must then NOT
 * forward the raw GLFW key event for it: the engine already sent the
 * equivalent events to the game, and a second delete event would remove one
 * character too many (the game deletes a character on every backspace key
 * event it receives).
 */
+ (BOOL)handleKey:(UIKey *)key inputLanguage:(NSString *)inputLanguage;

/*
 * YES for the keys handleKey: consumes (backspace). The matching key-up
 * event has to be suppressed as well, otherwise the game would see a key
 * release without a press.
 */
+ (BOOL)consumesKey:(UIKey *)key;

/*
 * The game side text field changed behind our back (the game switched screen,
 * the on-screen keyboard edited the text, ...). Drop the composition state so
 * the engine starts from a clean slate instead of rewriting stale text.
 */
+ (void)reset;

@end
