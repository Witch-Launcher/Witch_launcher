/*
 * Standalone check of the Telex composition engine (Natives/input/TelexComposer.m).
 * The "game" is simulated with a text buffer that removes one character per
 * delete event, exactly like Minecraft's EditBox does on a backspace key
 * event.
 */
#import <Foundation/Foundation.h>
#import "TelexComposer.h"

static NSMutableString *gField;
static int gDeleteEvents;
static int gCharEvents;
static int gFailures;

static TelexComposer *makeComposer(BOOL compose) {
    gField = [NSMutableString string];
    gDeleteEvents = 0;
    gCharEvents = 0;
    TelexComposer *c = [[TelexComposer alloc] init];
    c.composeVietnamese = compose;
    c.sendBackspaces = ^(int count) {
        for (int i = 0; i < count; i++) {
            gDeleteEvents++;
            if (gField.length > 0) {
                [gField deleteCharactersInRange:NSMakeRange(gField.length - 1, 1)];
            }
        }
    };
    c.sendChar = ^(unichar ch) {
        gCharEvents++;
        [gField appendString:[NSString stringWithCharacters:&ch length:1]];
    };
    return c;
}

static void check(NSString *what, NSString *expected, NSString *actual) {
    if ([expected isEqualToString:actual]) {
        printf("  ok   %-42s -> '%s'\n", what.UTF8String, actual.UTF8String);
    } else {
        gFailures++;
        printf("  FAIL %-42s -> '%s' (expected '%s')\n", what.UTF8String, actual.UTF8String, expected.UTF8String);
    }
}

static void checkInt(NSString *what, int expected, int actual) {
    if (expected == actual) {
        printf("  ok   %-42s -> %d\n", what.UTF8String, actual);
    } else {
        gFailures++;
        printf("  FAIL %-42s -> %d (expected %d)\n", what.UTF8String, actual, expected);
    }
}

int main(void) {
    @autoreleasepool {
        printf("== Vietnamese composition ==\n");
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"o"];
            check(@"type o", @"o", gField);
            [c insertCharacters:@"o"];
            check(@"type o again", @"ô", gField);
            [c insertCharacters:@"o"];
            check(@"type o a third time (replaces)", @"o", gField);
            [c insertCharacters:@"o"];
            check(@"type o a fourth time", @"ô", gField);
        }
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"chao"];
            [c insertCharacters:@"f"];
            check(@"chao + f", @"chào", gField);
            int before = gDeleteEvents;
            [c deleteBackward];
            check(@"backspace undoes the tone", @"chao", gField);
            // "chào" -> "chao" changes two characters, so the engine rewrites
            // them. The word keeps its length: the user does not see a
            // character disappear.
            checkInt(@"backspace delete events", 2, gDeleteEvents - before);
            check(@"word length kept", @"4", [NSString stringWithFormat:@"%lu", (unsigned long)gField.length]);
        }
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"aa"];
            check(@"aa", @"â", gField);
            [c insertCharacters:@"a"];
            check(@"aaa", @"a", gField);
        }
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"ow"];
            check(@"ow", @"ơ", gField);
            [c insertCharacters:@"w"];
            check(@"oww", @"ơw", gField);
        }
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"dd"];
            check(@"dd", @"đ", gField);
        }
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"dodong"];
            [c insertCharacters:@"f"];
            check(@"dodong + f", @"dodòng", gField);
        }
        {
            // "f" is the huyền (grave) tone key.
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"toan"];
            [c insertCharacters:@"f"];
            check(@"toan + f", @"toàn", gField);
        }
        {
            // Known limitation of the rule set: the "u" + "o" sequence is not
            // rewritten to "uô" yet ("buồn" would need it), the tone lands on
            // the plain "o".
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"buon"];
            [c insertCharacters:@"f"];
            check(@"buon + f", @"buòn", gField);
        }

        printf("== backspace deletes exactly one character ==\n");
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"hello"];
            check(@"typed", @"hello", gField);
            for (int i = 0; i < 5; i++) {
                int before = gDeleteEvents;
                [c deleteBackward];
                checkInt([NSString stringWithFormat:@"backspace %d delete events", i + 1], 1, gDeleteEvents - before);
            }
            check(@"field after 5 backspaces", @"", gField);
        }
        {
            // The engine owns nothing: the field content comes from the game.
            TelexComposer *c = makeComposer(YES);
            [gField setString:@"abc"];
            int before = gDeleteEvents;
            [c deleteBackward];
            checkInt(@"blind backspace delete events", 1, gDeleteEvents - before);
            check(@"blind backspace removed one char", @"ab", gField);
        }

        printf("== english layout stays english ==\n");
        {
            TelexComposer *c = makeComposer(NO);
            [c insertCharacters:@"oo"];
            check(@"oo without composition", @"oo", gField);
            [c insertCharacters:@"dd"];
            check(@"dd without composition", @"oodd", gField);
            [c deleteBackward];
            check(@"backspace", @"ood", gField);
        }

        printf("== external edits do not make the engine eat the text ==\n");
        {
            TelexComposer *c = makeComposer(YES);
            [c insertCharacters:@"abc"];
            check(@"typed", @"abc", gField);
            // The on-screen keyboard rewrote the field: the engine must not
            // touch it anymore.
            [c reset];
            [gField setString:@"xyz"];
            [c insertCharacters:@"o"];
            check(@"typing after an external edit", @"xyzo", gField);
            [c deleteBackward];
            check(@"backspace after an external edit", @"xyz", gField);
        }

        printf("\n%s (%d failures)\n", gFailures == 0 ? "ALL TESTS PASSED" : "TESTS FAILED", gFailures);
        return gFailures == 0 ? 0 : 1;
    }
}
