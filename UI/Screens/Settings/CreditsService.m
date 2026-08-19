#import "CreditsService.h"

static NSString *const CreditsURLString = @"https://raw.githubusercontent.com/Ynnyny/Angel-Aura-Amethyst-iOS/refs/heads/main/credits.md";
static NSString *const CreditsCacheFileName = @"credits_cache.md";
static NSString *const CreditsLastUpdateKey = @"credits_last_update";

NSNotificationName const CreditsDidUpdateNotification = @"CreditsDidUpdateNotification";

@implementation CreditsComponent
@end

@implementation CreditsSocial
@end

@interface CreditsService ()
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, copy) NSArray<CreditsComponent *> *components;
@property (nonatomic, copy) NSArray<CreditsSocial *> *socials;
@property (nonatomic) BOOL hasData;
@property (nonatomic) BOOL didRefresh;
@end

@implementation CreditsService

+ (instancetype)shared {
    static CreditsService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CreditsService alloc] init];
    });
    return instance;
}

- (NSString *)cachePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:CreditsCacheFileName];
}

- (void)refreshIfNeeded {
    if (self.didRefresh) return;
    self.didRefresh = YES;
    [self loadCached];
    [self fetchCredits];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _authorName = @"DuyAnh662 (Za_d626)";
    }
    return self;
}

- (void)loadCached {
    NSString *path = [self cachePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
    NSError *error = nil;
    NSString *markdown = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error || markdown.length == 0) return;
    [self parseMarkdown:markdown];
}

- (void)fetchCredits {
    NSURL *url = [NSURL URLWithString:CreditsURLString];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) return;
        NSString *markdown = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (markdown.length == 0) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self parseMarkdown:markdown];
            [markdown writeToFile:[self cachePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [NSUserDefaults.standardUserDefaults setDouble:NSDate.date.timeIntervalSince1970 forKey:CreditsLastUpdateKey];
            [[NSNotificationCenter defaultCenter] postNotificationName:CreditsDidUpdateNotification object:nil];
        });
    }];
    [task resume];
}

- (void)parseMarkdown:(NSString *)markdown {
    NSMutableArray<CreditsComponent *> *components = [NSMutableArray array];
    NSMutableArray<CreditsSocial *> *socials = [NSMutableArray array];
    NSString *author = @"";

    NSString *currentSection = @"";
    NSArray<NSString *> *lines = [markdown componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if ([line hasPrefix:@"## "]) {
            currentSection = [[line substringFromIndex:3] lowercaseString];
            continue;
        }
        if ([currentSection isEqualToString:@"author"]) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                author = trimmed;
                currentSection = @"";
            }
            continue;
        }
        if ([currentSection isEqualToString:@"socials"]) {
            CreditsSocial *social = [self socialFromLine:line];
            if (social) [socials addObject:social];
            continue;
        }
        if ([currentSection containsString:@"third party components"]) {
            CreditsComponent *component = [self componentFromLine:line];
            if (component) [components addObject:component];
        }
    }

    self.authorName = author.length > 0 ? author : @"DuyAnh662 (Za_d626)";
    self.components = components;
    self.socials = socials;
    self.hasData = components.count > 0 || socials.count > 0;
}

// Extracts "[Label](url)" pairs from a line. Lines like
// "[Discord](https://...)" or "- [Youtube](https://...)" both work.
// Placeholder URLs ("your-invite", "your-username", ...) are skipped so
// rows only appear once real links are set on GitHub.
- (CreditsSocial *)socialFromLine:(NSString *)line {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\((https?:[^)]+)\\)" options:0 error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (!result || result.numberOfRanges < 3) return nil;
    NSString *label = [line substringWithRange:[result rangeAtIndex:1]];
    NSString *url = [line substringWithRange:[result rangeAtIndex:2]];
    if ([url containsString:@"your-invite"] || [url containsString:@"your-username"] || [url containsString:@"your-channel"]) {
        return nil;
    }
    CreditsSocial *social = [[CreditsSocial alloc] init];
    social.label = label;
    social.url = url;
    return social;
}

// Parses "- [Name](url): [License](licenseUrl)" lines.
- (CreditsComponent *)componentFromLine:(NSString *)line {
    if (![line hasPrefix:@"- "]) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\((https?:[^)]+)\\)" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
    if (matches.count == 0) return nil;

    CreditsComponent *component = [[CreditsComponent alloc] init];
    NSTextCheckingResult *nameMatch = matches.firstObject;
    component.name = [line substringWithRange:[nameMatch rangeAtIndex:1]];
    component.url = [line substringWithRange:[nameMatch rangeAtIndex:2]];

    if (matches.count >= 2) {
        NSTextCheckingResult *licenseMatch = matches[1];
        component.license = [line substringWithRange:[licenseMatch rangeAtIndex:1]];
        component.licenseUrl = [line substringWithRange:[licenseMatch rangeAtIndex:2]];
    } else {
        component.license = @"";
    }
    return component;
}

@end