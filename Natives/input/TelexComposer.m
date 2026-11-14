#import "TelexComposer.h"

/*
 * Vietnamese (Telex) composition rules and the state machine that keeps the
 * game side text field in sync with them.
 */

static const unichar telexTones[12][6] = {
    { 0x61, 0xE1, 0xE0, 0x1EA3, 0xE3, 0x1EA1 }, // a  á   à   ả   ã   ạ
    { 0x103, 0x1EAF, 0x1EB1, 0x1EB3, 0x1EB5, 0x1EB7 }, // ă ắ ằ ẳ ẵ ặ
    { 0xE2, 0x1EA5, 0x1EA7, 0x1EA9, 0x1EAB, 0x1EAD }, // â ấ ầ ẩ ẫ ậ
    { 0x65, 0xE9, 0xE8, 0x1EBB, 0x1EBD, 0x1EB9 }, // e  é   è   ẻ   ẽ   ẹ
    { 0xEA, 0x1EBF, 0x1EC1, 0x1EC3, 0x1EC5, 0x1EC7 }, // ê ế ề ể ễ ệ
    { 0x69, 0xED, 0xEC, 0x1EC9, 0x129, 0x1ECB }, // i  í   ì   ỉ   ĩ   ị
    { 0x6F, 0xF3, 0xF2, 0x1ECF, 0xF5, 0x1ECD }, // o  ó   ò   ỏ   õ   ọ
    { 0xF4, 0x1ED1, 0x1ED3, 0x1ED5, 0x1ED7, 0x1ED9 }, // ô ố ồ ổ ỗ ộ
    { 0x1A1, 0x1EDB, 0x1EDD, 0x1EDF, 0x1EE1, 0x1EE3 }, // ơ ớ ờ ở ỡ ợ
    { 0x75, 0xFA, 0xF9, 0x1EE7, 0x169, 0x1EE5 }, // u  ú   ù   ủ   ũ   ụ
    { 0x1B0, 0x1EE9, 0x1EEB, 0x1EED, 0x1EEF, 0x1EF1 }, // ư ứ ừ ử ữ ự
    { 0x79, 0xFD, 0x1EF3, 0x1EF5, 0x1EF7, 0x1EF9 }, // y  ý   ỳ   ỷ   ỹ   ỵ
};

static unichar lowercaseVowel(unichar c) {
    if (c >= 'A' && c <= 'Z') return c + 32;
    switch (c) {
        case 0xC1: return 0xE1; case 0xC0: return 0xE0; case 0x1EA2: return 0x1EA3;
        case 0xC3: return 0xE3; case 0x1EA0: return 0x1EA1;
        case 0x1EAE: return 0x1EAF; case 0x1EB0: return 0x1EB1; case 0x1EB2: return 0x1EB3;
        case 0x1EB4: return 0x1EB5; case 0x1EB6: return 0x1EB7;
        case 0x1EA4: return 0x1EA5; case 0x1EA6: return 0x1EA7; case 0x1EA8: return 0x1EA9;
        case 0x1EAA: return 0x1EAB; case 0x1EAC: return 0x1EAD;
        case 0xC9: return 0xE9; case 0xC8: return 0xE8; case 0x1EBA: return 0x1EBB;
        case 0x1EBC: return 0x1EBD; case 0x1EB8: return 0x1EB9;
        case 0x1EBE: return 0x1EBF; case 0x1EC0: return 0x1EC1; case 0x1EC2: return 0x1EC3;
        case 0x1EC4: return 0x1EC5; case 0x1EC6: return 0x1EC7;
        case 0xCD: return 0xED; case 0xCC: return 0xEC; case 0x1EC8: return 0x1EC9;
        case 0x128: return 0x129; case 0x1ECA: return 0x1ECB;
        case 0xD3: return 0xF3; case 0xD2: return 0xF2; case 0x1ECE: return 0x1ECF;
        case 0xD5: return 0xF5; case 0x1ECC: return 0x1ECD;
        case 0x1ED0: return 0x1ED1; case 0x1ED2: return 0x1ED3; case 0x1ED4: return 0x1ED5;
        case 0x1ED6: return 0x1ED7; case 0x1ED8: return 0x1ED9;
        case 0x1EDA: return 0x1EDB; case 0x1EDC: return 0x1EDD; case 0x1EDE: return 0x1EDF;
        case 0x1EE0: return 0x1EE1; case 0x1EE2: return 0x1EE3;
        case 0xDA: return 0xFA; case 0xD9: return 0xF9; case 0x1EE6: return 0x1EE7;
        case 0x168: return 0x169; case 0x1EE4: return 0x1EE5;
        case 0x1EE8: return 0x1EE9; case 0x1EEA: return 0x1EEB; case 0x1EEC: return 0x1EED;
        case 0x1EEE: return 0x1EEF; case 0x1EF0: return 0x1EF1;
        case 0xDD: return 0xFD; case 0x1EF2: return 0x1EF3; case 0x1EF4: return 0x1EF5;
        case 0x1EF6: return 0x1EF7; case 0x1EF8: return 0x1EF9;
        case 0x102: return 0x103; case 0xC2: return 0xE2; case 0xCA: return 0xEA;
        case 0xD4: return 0xF4; case 0x1A0: return 0x1A1; case 0x1AF: return 0x1B0;
        case 0x110: return 0x111;
    }
    return c;
}

static unichar uppercaseVowel(unichar c) {
    if (c >= 'a' && c <= 'z') return c - 32;
    switch (c) {
        case 0xE1: return 0xC1; case 0xE0: return 0xC0; case 0x1EA3: return 0x1EA2;
        case 0xE3: return 0xC3; case 0x1EA1: return 0x1EA0;
        case 0x1EAF: return 0x1EAE; case 0x1EB1: return 0x1EB0; case 0x1EB3: return 0x1EB2;
        case 0x1EB5: return 0x1EB4; case 0x1EB7: return 0x1EB6;
        case 0x1EA5: return 0x1EA4; case 0x1EA7: return 0x1EA6; case 0x1EA9: return 0x1EA8;
        case 0x1EAB: return 0x1EAA; case 0x1EAD: return 0x1EAC;
        case 0xE9: return 0xC9; case 0xE8: return 0xC8; case 0x1EBB: return 0x1EBA;
        case 0x1EBD: return 0x1EBC; case 0x1EB9: return 0x1EB8;
        case 0x1EBF: return 0x1EBE; case 0x1EC1: return 0x1EC0; case 0x1EC3: return 0x1EC2;
        case 0x1EC5: return 0x1EC4; case 0x1EC7: return 0x1EC6;
        case 0xED: return 0xCD; case 0xEC: return 0xCC; case 0x1EC9: return 0x1EC8;
        case 0x129: return 0x128; case 0x1ECB: return 0x1ECA;
        case 0xF3: return 0xD3; case 0xF2: return 0xD2; case 0x1ECF: return 0x1ECE;
        case 0xF5: return 0xD5; case 0x1ECD: return 0x1ECC;
        case 0x1ED1: return 0x1ED0; case 0x1ED3: return 0x1ED2; case 0x1ED5: return 0x1ED4;
        case 0x1ED7: return 0x1ED6; case 0x1ED9: return 0x1ED8;
        case 0x1EDB: return 0x1EDA; case 0x1EDD: return 0x1EDC; case 0x1EDF: return 0x1EDE;
        case 0x1EE1: return 0x1EE0; case 0x1EE3: return 0x1EE2;
        case 0xFA: return 0xDA; case 0xF9: return 0xD9; case 0x1EE7: return 0x1EE6;
        case 0x169: return 0x168; case 0x1EE5: return 0x1EE4;
        case 0x1EE9: return 0x1EE8; case 0x1EEB: return 0x1EEA; case 0x1EED: return 0x1EEC;
        case 0x1EEF: return 0x1EEE; case 0x1EF1: return 0x1EF0;
        case 0xFD: return 0xDD; case 0x1EF3: return 0x1EF2; case 0x1EF5: return 0x1EF4;
        case 0x1EF7: return 0x1EF6; case 0x1EF9: return 0x1EF8;
        case 0x103: return 0x102; case 0xE2: return 0xC2; case 0xEA: return 0xCA;
        case 0xF4: return 0xD4; case 0x1A1: return 0x1A0; case 0x1B0: return 0x1AF;
        case 0x111: return 0x110;
    }
    return c;
}

static BOOL isUpper(unichar c) {
    return lowercaseVowel(c) != c;
}

static unichar baseVowel(unichar c) {
    unichar l = lowercaseVowel(c);
    for (int row = 0; row < 12; row++) {
        for (int col = 1; col < 6; col++) {
            if (telexTones[row][col] == l) return telexTones[row][0];
        }
    }
    return l;
}

// Maps any Vietnamese vowel (hatted base or accented) to its plain letter.
static unichar plainVowel(unichar c) {
    unichar b = baseVowel(c);
    switch (b) {
        case 0x103: case 0xE2: return 'a'; // ă â
        case 0xEA: return 'e';              // ê
        case 0xF4: case 0x1A1: return 'o';  // ô ơ
        case 0x1B0: return 'u';             // ư
    }
    return b;
}

static BOOL isVowel(unichar c) {
    switch (plainVowel(c)) {
        case 'a': case 'e': case 'i': case 'o': case 'u': case 'y':
            return YES;
    }
    return NO;
}

static int toneOf(unichar c) {
    unichar l = lowercaseVowel(c);
    for (int row = 0; row < 12; row++) {
        for (int col = 1; col < 6; col++) {
            if (telexTones[row][col] == l) return col;
        }
    }
    return 0;
}

static BOOL isWordChar(unichar c) {
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) return YES;
    if (c == 0x111 || c == 0x110) return YES; // đ Đ
    return isVowel(c);
}

/*
 * Index of the vowel that carries the tone, following Vietnamese
 * orthographic rules (quy tắc đặt dấu thanh).
 */
static NSInteger mainVowelIndex(NSString *word) {
    NSInteger len = (NSInteger) word.length;
    if (len == 0) return -1;

    NSInteger runEnd = len - 1;
    while (runEnd >= 0 && !isVowel([word characterAtIndex:runEnd])) runEnd--;
    if (runEnd < 0) return -1;

    NSInteger runStart = runEnd;
    while (runStart > 0 && isVowel([word characterAtIndex:runStart - 1])) runStart--;
    NSInteger runLen = runEnd - runStart + 1;

    // "qu" is a consonant cluster: the u right after q is not a vowel.
    if (runStart > 0 && lowercaseVowel([word characterAtIndex:runStart - 1]) == 'q' &&
        baseVowel([word characterAtIndex:runStart]) == 'u') {
        runStart++;
        runLen = runEnd - runStart + 1;
        if (runLen <= 0) return -1;
    }

    // A consonant after the vowel run (final consonant) puts the tone on the
    // last vowel of the run: "toan" -> a, "buon" -> ô.
    if (runEnd < len - 1) return runEnd;

    if (runLen == 1) return runStart;
    if (runLen >= 3) return runStart + 1; // iêu -> ê, ươu -> ơ, uôi -> ô

    // Two-vowel ending: place per the pair rules. For "uy" the tone goes on
    // the u ("thủy"), matching Unikey and common usage; "quý" keeps the tone
    // on y because the qu cluster skips the u above.
    unichar c1 = baseVowel([word characterAtIndex:runStart]);
    unichar c2 = baseVowel([word characterAtIndex:runEnd]);
    if (c2 == 'i' || c2 == 'y') return runStart;        // ai, oi, ôi, ơi, ui, ưi, uy, ay
    if (c1 == 'i' || c1 == 'y') {
        return (c2 == 'a') ? runStart : runEnd;         // ia -> i, iê -> ê
    }
    if (c1 == 'u') {
        return (c2 == 'a') ? runStart : runEnd;         // ua -> u, uô/uâ/uơ/uê -> last
    }
    if (c1 == 0x1B0) {
        return (c2 == 'a') ? runStart : runEnd;         // ưa -> ư, ươ -> ơ
    }
    if (c1 == 'o' && (c2 == 'a' || c2 == 'e')) return runEnd; // oa, oe -> last
    return runStart;                                    // ao, au, eo, êu, ... -> first
}

static void applyToneToWord(NSMutableString *word, int toneIdx) {
    NSInteger idx = mainVowelIndex(word);
    if (idx < 0) return;
    unichar orig = [word characterAtIndex:idx];
    if (toneOf(orig) == toneIdx) {
        // Same tone again: cycle back to the base vowel.
        unichar base = baseVowel(orig);
        [word replaceCharactersInRange:NSMakeRange(idx, 1)
                            withString:[NSString stringWithCharacters:&base length:1]];
        return;
    }
    unichar base = baseVowel(orig);
    unichar lower = lowercaseVowel(base);
    int row = -1;
    for (int r = 0; r < 12; r++) {
        if (telexTones[r][0] == lower) { row = r; break; }
    }
    if (row < 0) return;
    unichar accented = telexTones[row][toneIdx];
    if (isUpper(orig)) accented = uppercaseVowel(accented);
    [word replaceCharactersInRange:NSMakeRange(idx, 1)
                        withString:[NSString stringWithCharacters:&accented length:1]];
}

static int toneIndexFor(unichar c) {
    switch (c) {
        case 's': return 1; // sắc
        case 'f': return 2; // huyền
        case 'r': return 3; // hỏi
        case 'x': return 4; // ngã
        case 'j': return 5; // nặng
    }
    return 0;
}

/*
 * Apply Telex rules to the raw keystroke string.
 */
static NSString *composeRaw(NSString *raw) {
    NSMutableString *result = [NSMutableString string];
    NSMutableString *word = [NSMutableString string];

    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if (!isWordChar(c)) {
            [result appendString:word];
            [result appendFormat:@"%C", c];
            [word setString:@""];
            continue;
        }
        unichar l = lowercaseVowel(c);

        if (toneIndexFor(l) > 0) {
            BOOL hasVowel = NO;
            for (NSUInteger k = 0; k < word.length; k++) {
                if (isVowel([word characterAtIndex:k])) { hasVowel = YES; break; }
            }
            if (hasVowel) {
                applyToneToWord(word, toneIndexFor(l));
            } else {
                [word appendFormat:@"%C", c];
            }
        } else if (l == 'z') {
            BOOL hasTone = NO;
            for (NSUInteger k = 0; k < word.length; k++) {
                if (toneOf([word characterAtIndex:k]) > 0) { hasTone = YES; break; }
            }
            if (hasTone) {
                applyToneToWord(word, toneOf([word characterAtIndex:mainVowelIndex(word)]));
            } else {
                [word appendFormat:@"%C", c];
            }
        } else {
            BOOL merged = NO;
            if (word.length > 0) {
                unichar last = [word characterAtIndex:word.length - 1];
                unichar lastLower = lowercaseVowel(last);
                unichar mergedChar = 0;
                switch (l) {
                    case 'a':
                        if (lastLower == 'a') mergedChar = 0xE2;        // aa -> â
                        else if (lastLower == 0xE2) mergedChar = 'a';   // aaa -> a
                        else if (lastLower == 'w') mergedChar = 0x103;  // aw -> ă
                        break;
                    case 'w':
                        if (lastLower == 'a') mergedChar = 0x103;       // aw -> ă
                        else if (lastLower == 0x103) mergedChar = 0xE2; // ăw -> â
                        else if (lastLower == 'o') mergedChar = 0x1A1;  // ow -> ơ
                        else if (lastLower == 'u') mergedChar = 0x1B0;  // uw -> ư
                        break;
                    case 'e':
                        if (lastLower == 'e') mergedChar = 0xEA;
                        else if (lastLower == 0xEA) mergedChar = 'e';   // eee -> e
                        break;
                    case 'o':
                        if (lastLower == 'o') mergedChar = 0xF4;
                        else if (lastLower == 0xF4) mergedChar = 'o';   // ooo -> o
                        break;
                    case 'd':
                        if (lastLower == 'd') mergedChar = 0x111;       // dd -> đ
                        break;
                }
                if (mergedChar) {
                    if (isUpper(last)) mergedChar = uppercaseVowel(mergedChar);
                    [word replaceCharactersInRange:NSMakeRange(word.length - 1, 1)
                                        withString:[NSString stringWithCharacters:&mergedChar length:1]];
                    merged = YES;
                }
            }
            if (!merged) [word appendFormat:@"%C", c];
        }
    }
    [result appendString:word];
    return result;
}

@implementation TelexComposer {
    NSMutableString *_raw;
    NSString *_sent;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _raw = [NSMutableString string];
        _sent = @"";
    }
    return self;
}

- (NSString *)sentText {
    return _sent;
}

- (void)reset {
    [_raw setString:@""];
    _sent = @"";
}

/*
 * Rewrites the tail of the game side text field so it ends with newText.
 * oldText is what the engine believes is there, so oldText.length - prefix
 * characters have to be removed before the new characters are typed in.
 */
- (void)syncFrom:(NSString *)oldText to:(NSString *)newText {
    if (oldText == nil) oldText = @"";
    if (newText == nil) newText = @"";
    if ([oldText isEqualToString:newText]) return;
    NSUInteger prefix = 0;
    NSUInteger minLen = MIN(oldText.length, newText.length);
    while (prefix < minLen &&
           [oldText characterAtIndex:prefix] == [newText characterAtIndex:prefix]) {
        prefix++;
    }
    if (self.sendBackspaces) {
        self.sendBackspaces((int)(oldText.length - prefix));
    }
    if (self.sendChar) {
        for (NSUInteger i = prefix; i < newText.length; i++) {
            self.sendChar([newText characterAtIndex:i]);
        }
    }
}

/*
 * Pushes the current composition to the game. The engine only ever owns the
 * tail it wrote itself, so the delta is computed against that mirror.
 */
- (void)pushComposedText {
    // Copy the raw buffer: _sent must not alias the mutable buffer.
    NSString *newText = self.composeVietnamese ? composeRaw(_raw) : [_raw copy];
    [self syncFrom:_sent to:newText];
    _sent = newText;
}

- (void)insertCharacters:(NSString *)characters {
    if (characters == nil || characters.length == 0) return;
    BOOL changed = NO;
    for (NSUInteger i = 0; i < characters.length; i++) {
        unichar c = [characters characterAtIndex:i];
        if (c < 0x20) continue; // control chars (Enter/Tab/Esc) go via keycodes
        [_raw appendString:[NSString stringWithCharacters:&c length:1]];
        changed = YES;
    }
    if (changed) {
        [self pushComposedText];
    }
}

/*
 * Deletes exactly one character from the game side text field.
 *
 * When the engine owns text there, the last raw keystroke is dropped and the
 * whole word is recomposed, so the field keeps showing the composed form
 * ("chao" + f -> "chào", backspace -> "chao"). When the engine owns nothing
 * (the text came from the on-screen keyboard or from the game itself) a
 * single delete event is sent and the mirror stays empty.
 */
- (void)deleteBackward {
    if (_raw.length == 0) {
        // Nothing of ours is in the field; let the game delete exactly one of
        // its own characters.
        if (self.sendBackspaces) {
            self.sendBackspaces(1);
        }
        return;
    }
    [_raw deleteCharactersInRange:NSMakeRange(_raw.length - 1, 1)];
    [self pushComposedText];
}

@end
