#import "TrackedTextField.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#include "glfw_keycodes.h"

extern bool isUseStackQueueCall;

@interface UITextField(private)
- (NSRange)insertFilteredText:(NSString *)text;
- (id) replaceRangeWithTextWithoutClosingTyping:(UITextRange *)range replacementText:(NSString *)text;
@end

@interface TrackedTextField()
@property(nonatomic) int lastTextPos;
@property(nonatomic) int lastMarkedLength;
@property(nonatomic) CGFloat lastPointX;
@end

@implementation TrackedTextField

// Never intercept touches: this field must not steal taps from the game view
// (it is kept inside the visible area so the hardware-keyboard input session
// stays attached). It is focused only programmatically (becomeFirstResponder).
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (BOOL)becomeFirstResponder {
    // A stale skipNextTextInsertion (set by hardware keypresses while the
    // field was NOT focused) must not eat the first keystroke of a new
    // typing session (e.g. when chat opens and the game shows the keyboard).
    self.skipNextTextInsertion = NO;
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    return [super resignFirstResponder];
}

- (void)insertText:(NSString *)text {
    [super insertText:text];
}

- (void)sendMultiBackspaces:(int)times {
    for (int i = 0; i < times; i++) {
        self.sendKey(GLFW_KEY_BACKSPACE, 0, 1, 0);
        self.sendKey(GLFW_KEY_BACKSPACE, 0, 0, 0);
    }
}

- (void)paste:(id)sender {
    [super paste:sender];
    [self sendText:UIPasteboard.generalPasteboard.string];
}

- (void)sendText:(NSString *)text {
    for (int i = 0; i < text.length; i++) {
        unichar theChar = [text characterAtIndex:i];

        if (self.sendCharMods != nil) {
            self.sendCharMods(theChar, 0);
        } else {
            self.sendChar(theChar);
        }
    }
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    [super beginFloatingCursorAtPoint:point];
    self.lastPointX = point.x;
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
    [super updateFloatingCursorAtPoint:point];

    if (self.lastPointX == 0 || (self.lastTextPos > 0 && self.lastTextPos < self.text.length)) {
        return;
    }

    CGFloat diff = point.x - self.lastPointX;
    if (ABS(diff) < 8) {
        return;
    }
    self.lastPointX = point.x;

    int key = (diff > 0) ? GLFW_KEY_DPAD_RIGHT : GLFW_KEY_DPAD_LEFT;
    self.sendKey(key, 0, 1, 0);
    self.sendKey(key, 0, 0, 0);
}

- (void)endFloatingCursor {
    [super endFloatingCursor];
    self.lastPointX = 0;
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point {
    UITextPosition *position = [super closestPositionToPoint:point];
    int start = [self offsetFromPosition:self.beginningOfDocument toPosition:position];
    if (start - self.lastTextPos != 0) {
        int key = (start - self.lastTextPos > 0) ? GLFW_KEY_DPAD_RIGHT : GLFW_KEY_DPAD_LEFT;
        self.sendKey(key, 0, 1, 0);
        self.sendKey(key, 0, 0, 0);
    }
    self.lastTextPos = start;
    return position;
}

- (void)deleteBackward {
    if (self.lastMarkedLength > 0) {
        self.lastMarkedLength--;
    }

    if (self.text.length > 1) {
        [super deleteBackward];
    } else {
        self.text = @" ";
    }
    self.lastTextPos = [super offsetFromPosition:self.beginningOfDocument toPosition:self.selectedTextRange.start];

    [self sendMultiBackspaces:1];
}

- (BOOL)hasText {
    self.lastTextPos = MAX(self.lastTextPos, 1);
    return YES;
}

- (NSRange)insertFilteredText:(NSString *)text {
    if (self.skipNextTextInsertion) {
        self.skipNextTextInsertion = NO;
        return [super insertFilteredText:text];
    }

    int base = self.lastTextPos;
    if (self.lastMarkedLength > 0) {
        [self sendMultiBackspaces:self.lastMarkedLength];
        base -= self.lastMarkedLength;
        self.lastMarkedLength = 0;
    }

    int cursorPos = [super offsetFromPosition:self.beginningOfDocument toPosition:self.selectedTextRange.start];
    NSLog(@"[TrackedTextField] insert len=%lu text=%@ marked=%d last=%d cursor=%d",
          (unsigned long)text.length, text, self.lastMarkedLength, self.lastTextPos, cursorPos);

    int off = base - cursorPos;
    if (off > 0) {
        [self sendMultiBackspaces:off];
        base -= off;
    }

    [self sendText:text];
    self.lastTextPos = base + (int)text.length;

    NSRange range = [super insertFilteredText:text];
    return range;
}

- (id)replaceRangeWithTextWithoutClosingTyping:(UITextRange *)range replacementText:(NSString *)text
{
    int oldLength = [super offsetFromPosition:range.start toPosition:range.end];
    [self sendMultiBackspaces:oldLength];
    [self sendText:text];
    self.lastTextPos += (int)text.length - oldLength;
    self.lastMarkedLength = 0;

    return [super replaceRangeWithTextWithoutClosingTyping:range replacementText:text];
}

- (void)setAttributedMarkedText:(NSAttributedString *)markedText selectedRange:(NSRange)selectedRange {
    int oldMarkedLength = self.lastMarkedLength;
    NSLog(@"[TrackedTextField] marked old=%d new=%lu last=%d",
          oldMarkedLength, (unsigned long)markedText.length, self.lastTextPos);
    if (oldMarkedLength > 0) {
        [self sendMultiBackspaces:oldMarkedLength];
        self.lastTextPos = MAX(0, self.lastTextPos - oldMarkedLength);
    }

    [super setAttributedMarkedText:markedText selectedRange:selectedRange];

    self.lastMarkedLength = (int)markedText.length;
    [self sendText:markedText.string];
    self.lastTextPos += self.lastMarkedLength;
}

- (void)setText:(NSString *)text {
    NSLog(@"[TrackedTextField] setText len=%lu text=%@", (unsigned long)text.length, text);
    [super setText:text];
    self.lastTextPos = (int)text.length;
    self.lastMarkedLength = 0;
}

@end