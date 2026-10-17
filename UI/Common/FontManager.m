#import "FontManager.h"
#import <CoreText/CoreText.h>
#import <objc/runtime.h>
#import "ThemeManager.h"
#import "utils.h"

static NSString *const kFontPathPrefKey = @"amethyst_font_path";
static NSString *const kFontNamePrefKey = @"amethyst_font_name";

static UIFont *(*orig_systemFontOfSize)(id, SEL, CGFloat);
static UIFont *(*orig_systemFontOfSizeWeight)(id, SEL, CGFloat, UIFontWeight);

@interface FontManager ()
@property (nonatomic) NSString *fontPath;
@property (nonatomic) NSString *postScriptName;
@property (nonatomic) NSString *systemFamilyName;
@property (nonatomic) BOOL installed;
@property (nonatomic) BOOL registered;
@property (nonatomic) NSCache<NSNumber *, UIFont *> *fontCache;
- (UIFont *)customFontOfSize:(CGFloat)size;
@end

// iOS 26 SDK removed CTFontCreateWithURL; descriptor-from-URL is the
// supported replacement and also validates the file as a real font.
static NSString *amethyst_postScriptNameFromFontFile(NSString *path) {
    if (path.length == 0) return nil;
    CFArrayRef descs = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)[NSURL fileURLWithPath:path]);
    if (!descs) return nil;
    NSString *ps = nil;
    if (CFArrayGetCount(descs) > 0) {
        CTFontDescriptorRef desc = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descs, 0);
        CTFontRef font = CTFontCreateWithFontDescriptor(desc, 12, NULL);
        if (font) {
            ps = (__bridge_transfer NSString *)CTFontCopyPostScriptName(font);
            CFRelease(font);
        }
    }
    CFRelease(descs);
    return ps;
}


@interface UIFont (AmethystFont)
+ (UIFont *)amethyst_systemFontOfSize:(CGFloat)size;
+ (UIFont *)amethyst_systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
@end

@implementation UIFont (AmethystFont)

+ (UIFont *)amethyst_systemFontOfSize:(CGFloat)size {
    UIFont *custom = [FontManager.shared customFontOfSize:size];
    if (custom) return custom;
    return orig_systemFontOfSize(self, @selector(systemFontOfSize:), size);
}

+ (UIFont *)amethyst_systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *custom = [FontManager.shared customFontOfSize:size];
    if (custom) return custom;
    return orig_systemFontOfSizeWeight(self, @selector(systemFontOfSize:weight:), size, weight);
}

@end

@implementation FontManager

+ (FontManager *)shared {
    static FontManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fontCache = [[NSCache alloc] init];
        _fontCache.countLimit = 64;
    }
    return self;
}

#pragma mark - Install / swizzle

+ (void)install {
    FontManager *m = self.shared;
    if (m.installed) return;
    m.installed = YES;

    // Capture the real system family *before* the swizzle can kick in; the
    // view-walker uses it to replace only system-font labels.
    UIFont *probe = [UIFont systemFontOfSize:10];
    m.systemFamilyName = probe.familyName;

    Method origSize = class_getClassMethod(UIFont.class, @selector(systemFontOfSize:));
    Method newSize = class_getClassMethod(UIFont.class, @selector(amethyst_systemFontOfSize:));
    orig_systemFontOfSize = (void *)method_getImplementation(origSize);
    if (origSize && newSize) {
        method_exchangeImplementations(origSize, newSize);
    }

    Method origWeight = class_getClassMethod(UIFont.class, @selector(systemFontOfSize:weight:));
    Method newWeight = class_getClassMethod(UIFont.class, @selector(amethyst_systemFontOfSize:weight:));
    orig_systemFontOfSizeWeight = (void *)method_getImplementation(origWeight);
    if (origWeight && newWeight) {
        method_exchangeImplementations(origWeight, newWeight);
    }

    // Load the saved font, if the file still exists.
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:kFontPathPrefKey];
    if (path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *ps = [[NSUserDefaults standardUserDefaults] stringForKey:kFontNamePrefKey];
        m.fontPath = path;
        m.postScriptName = ps;
        m.registered = NO;
        [m registerCurrentFontIfNeeded];
    }
}

#pragma mark - Custom font

- (BOOL)isEnabled {
    return self.postScriptName.length > 0 && [self customFontOfSize:12] != nil;
}

- (NSString *)displayName {
    if (!self.isEnabled) return localize(@"appearance.font_default", nil);
    UIFont *f = [self customFontOfSize:12];
    return f.familyName.length > 0 ? f.familyName : self.postScriptName;
}

- (void)registerCurrentFontIfNeeded {
    if (self.registered || self.fontPath.length == 0) return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.fontPath]) return;

    CFErrorRef cfError = NULL;
    BOOL ok = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)[NSURL fileURLWithPath:self.fontPath],
                                               kCTFontManagerScopeProcess, &cfError);
    if (cfError) CFRelease(cfError);
    if (!ok) {
        NSLog(@"[FontManager] register failed for %@", self.fontPath);
        return;
    }

    // Re-derive the PostScript name from the file: stored value may be stale
    // after a re-import.
    NSString *ps = amethyst_postScriptNameFromFontFile(self.fontPath);
    if (ps.length > 0 && ![ps isEqualToString:self.postScriptName]) {
        self.postScriptName = ps;
        [[NSUserDefaults standardUserDefaults] setObject:ps forKey:kFontNamePrefKey];
    }
    [self.fontCache removeAllObjects];
    self.registered = YES;
}

- (UIFont *)customFontOfSize:(CGFloat)size {
    if (self.postScriptName.length == 0) return nil;
    if (!self.registered) [self registerCurrentFontIfNeeded];
    if (!self.registered) return nil;

    NSNumber *key = @(size);
    UIFont *cached = [self.fontCache objectForKey:key];
    if (cached) return cached;

    UIFont *font = [UIFont fontWithName:self.postScriptName size:size];
    // A named font still goes through the swizzle-free path: fontWithName
    // never routes back into systemFontOfSize.
    if (font) [self.fontCache setObject:font forKey:key];
    return font;
}

#pragma mark - Import / reset

- (BOOL)importFontAtURL:(NSURL *)url error:(NSError **)error {
    if (!url) {
        if (error) *error = [NSError errorWithDomain:@"FontManager" code:-1
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }
    NSString *fontsDir = amethyst_hidden_dir(@"fonts");
    if (fontsDir.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"FontManager" code:-1
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }

    NSString *ext = url.pathExtension.lowercaseString;
    if (!([ext isEqualToString:@"ttf"] || [ext isEqualToString:@"otf"] || [ext isEqualToString:@"ttc"])) {
        if (error) *error = [NSError errorWithDomain:@"FontManager" code:-2
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }

    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSString *dest = [fontsDir stringByAppendingPathComponent:url.lastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:dest error:nil];
    NSError *copyError = nil;
    BOOL copied = [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&copyError];
    if (!copied) {
        NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&copyError];
        if (data) copied = [data writeToFile:dest atomically:YES];
    }
    if (accessing) [url stopAccessingSecurityScopedResource];
    if (!copied) {
        if (error) *error = copyError ?: [NSError errorWithDomain:@"FontManager" code:-3
                                                            userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }

    // Validate + resolve PostScript name before committing the preference.
    NSString *ps = amethyst_postScriptNameFromFontFile(dest);
    if (ps.length == 0) {
        [fm removeItemAtPath:dest error:nil];
        if (error) *error = [NSError errorWithDomain:@"FontManager" code:-4
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }

    self.fontPath = dest;
    self.postScriptName = ps;
    self.registered = NO;
    [self.fontCache removeAllObjects];
    [self registerCurrentFontIfNeeded];
    if (!self.registered) {
        if (error) *error = [NSError errorWithDomain:@"FontManager" code:-5
                                               userInfo:@{NSLocalizedDescriptionKey: localize(@"appearance.font_failed", nil)}];
        return NO;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:dest forKey:kFontPathPrefKey];
    [defaults setObject:ps forKey:kFontNamePrefKey];
    [self refreshAllViews];
    return YES;
}

- (void)useSystemFont {
    self.fontPath = nil;
    self.postScriptName = nil;
    self.registered = NO;
    [self.fontCache removeAllObjects];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kFontPathPrefKey];
    [defaults removeObjectForKey:kFontNamePrefKey];
    [self refreshAllViews];
}

#pragma mark - Apply to existing views

- (void)refreshAllViews {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            [self refreshViewTree:window];
        }
        // Rebuild table cells / re-run per-screen layout with the new font.
        [ThemeManager.shared broadcastThemeChange];
    });
}

- (void)refreshViewTree:(UIView *)view {
    UIFont *replacement = nil;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        replacement = [self replacementForFont:label.font];
        if (replacement) label.font = replacement;
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        replacement = [self replacementForFont:tf.font];
        if (replacement) tf.font = replacement;
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *tv = (UITextView *)view;
        replacement = [self replacementForFont:tv.font];
        if (replacement) tv.font = replacement;
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        UIFont *font = [btn titleLabel].font;
        if (font) {
            replacement = [self replacementForFont:font];
            if (replacement) btn.titleLabel.font = replacement;
        }
    }
    for (UIView *sub in view.subviews) {
        [self refreshViewTree:sub];
    }
}

// Swap only fonts that came from the system family (leaves Menlo/log/custom
// fonts alone). When disabling, swap our custom family back to system.
- (UIFont *)replacementForFont:(UIFont *)font {
    if (!font) return nil;
    NSString *family = font.familyName;
    if (self.isEnabled) {
        if ([family isEqualToString:self.systemFamilyName]) {
            return [self customFontOfSize:font.pointSize];
        }
        return nil;
    }
    // Disabled: put back system font for previously customized views.
    UIFont *custom = [UIFont fontWithName:self.savedPostScriptNameForRestore size:font.pointSize];
    if (custom && [family isEqualToString:custom.familyName]) {
        return [UIFont systemFontOfSize:font.pointSize];
    }
    return nil;
}

// After useSystemFont the preference is already cleared; keep the last name
// around long enough to undo existing views in the same session.
- (NSString *)savedPostScriptNameForRestore {
    static NSString *last = nil;
    if (self.postScriptName.length > 0) last = self.postScriptName;
    return last;
}

@end
