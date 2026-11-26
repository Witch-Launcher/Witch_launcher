#import <Foundation/Foundation.h>

/*
 * Vietnamese (Telex) composition engine, free of any UIKit dependency so it
 * can be unit tested on its own.
 *
 * The engine owns the text it types into the game: it keeps the raw
 * keystrokes, recomposes them with the Telex rules and streams the difference
 * to the game (delete events + characters). The game removes one character
 * per delete event, so the number of delete events has to match exactly what
 * changed, otherwise the game side text drifts away from the composition.
 */
@interface TelexComposer : NSObject

/* Sends "count" delete events to the game. */
@property(nonatomic, copy) void(^sendBackspaces)(int count);
/* Sends a single character to the game. */
@property(nonatomic, copy) void(^sendChar)(unichar ch);

/*
 * YES when the Vietnamese rules have to be applied. With NO the keystrokes
 * are streamed verbatim (English layout).
 */
@property(nonatomic) BOOL composeVietnamese;

/* Appends raw keystrokes and syncs the game side text. */
- (void)insertCharacters:(NSString *)characters;

/* Deletes exactly one character from the game side text. */
- (void)deleteBackward;

/* Forgets the state: the game side text changed behind our back. */
- (void)reset;

/* The composed text the engine believes is at the end of the game field. */
@property(nonatomic, readonly) NSString *sentText;

@end
