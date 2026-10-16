#import "ModMetadataReader.h"
#import "InstalledModsManager.h"
#import "UnzipKit.h"
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

NSString * const ModContentKindWorld = @"world";
NSString * const ModContentKindDatapack = @"datapack";
NSString * const ModContentKindPlugin = @"plugin";

@interface ModMetadataReader ()
@property (nonatomic) NSCache *memCache;
@property (nonatomic) dispatch_queue_t ioQueue;
@end

@implementation ModMetadataReader

+ (ModMetadataReader *)shared {
    static ModMetadataReader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memCache = [[NSCache alloc] init];
        _memCache.countLimit = 150;
        _ioQueue = dispatch_queue_create("com.angelic.modmetadata", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

+ (NSString *)placeholderSystemImageForCategory:(NSString *)category {
    if ([category isEqualToString:InstalledItemCategoryResourcePack]) return @"paintpalette";
    if ([category isEqualToString:InstalledItemCategoryShaderPack]) return @"paintbrush.pointed";
    if ([category isEqualToString:ModContentKindWorld]) return @"globe";
    if ([category isEqualToString:ModContentKindDatapack]) return @"shippingbox";
    if ([category isEqualToString:ModContentKindPlugin]) return @"plug";
    return @"puzzlepiece.extension";
}

+ (NSString *)displayVersionForPackFormat:(NSString *)packFormat {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{@"1":@"1.6 – 1.8", @"2":@"1.9 – 1.10", @"3":@"1.11 – 1.12",
                @"4":@"1.13 – 1.14", @"5":@"1.15 – 1.16.1", @"6":@"1.16.2+",
                @"7":@"1.17", @"8":@"1.18", @"9":@"1.19 – 1.19.2",
                @"12":@"1.19.3", @"13":@"1.19.4", @"15":@"1.20.2+",
                @"18":@"1.20.3+", @"22":@"1.20.5+", @"34":@"1.21+",
                @"42":@"1.21.2+", @"48":@"1.21.4+", @"55":@"1.21.6+"};
    });
    NSString *mc = map[packFormat];
    if (mc) return [NSString stringWithFormat:@"MC %@", mc];
    if (packFormat.length > 0) return [NSString stringWithFormat:@"Format %@", packFormat];
    return @"";
}

#pragma mark - Archive helpers

+ (UZKArchive *)archiveForPath:(NSString *)path {
    if (path.length == 0) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    NSError *err = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:path error:&err];
    if (err || !archive) return nil;
    return archive;
}

+ (NSArray<NSString *> *)filenamesInArchiveAtPath:(NSString *)filePath {
    UZKArchive *archive = [self archiveForPath:filePath];
    if (!archive) return @[];
    NSError *err = nil;
    NSArray *names = [archive listFilenames:&err];
    if (err || ![names isKindOfClass:[NSArray class]]) return @[];
    return names;
}

// First JSON dict found at any of the candidate paths.
+ (NSDictionary *)jsonDictInArchive:(UZKArchive *)archive paths:(NSArray<NSString *> *)paths {
    for (NSString *p in paths) {
        NSData *d = [archive extractDataFromFile:p error:nil];
        if (!d) continue;
        id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]]) return json;
    }
    return nil;
}

+ (void)mergeInto:(NSMutableDictionary *)dst from:(NSDictionary *)src {
    if (![src isKindOfClass:[NSDictionary class]]) return;
    for (NSString *k in src) {
        id existing = dst[k];
        BOOL empty = (existing == nil) || ([existing isKindOfClass:[NSString class]] && [(NSString *)existing length] == 0);
        if (empty && src[k] != nil) dst[k] = src[k];
    }
}

+ (NSString *)joinedAuthors:(id)authors {
    if ([authors isKindOfClass:[NSString class]]) return authors;
    if ([authors isKindOfClass:[NSArray class]]) {
        NSMutableArray *names = [NSMutableArray array];
        for (id a in (NSArray *)authors) {
            if ([a isKindOfClass:[NSString class]] && [(NSString *)a length] > 0) [names addObject:a];
            else if ([a isKindOfClass:[NSDictionary class]]) {
                NSString *n = a[@"name"];
                if ([n isKindOfClass:[NSString class]] && n.length > 0) [names addObject:n];
            }
        }
        return [names componentsJoinedByString:@", "];
    }
    return @"";
}

#pragma mark - Top entry

+ (NSDictionary *)metadataForFileAtPath:(NSString *)filePath category:(NSString *)category {
    NSMutableDictionary *meta = [NSMutableDictionary dictionary];
    if (filePath.length == 0) return meta;
    UZKArchive *archive = [self archiveForPath:filePath];
    if (!archive) {
        meta[@"title"] = [[filePath.lastPathComponent stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        meta[@"kind"] = @"unknown";
        return meta;
    }

    if ([category isEqualToString:InstalledItemCategoryResourcePack] ||
        [category isEqualToString:InstalledItemCategoryShaderPack] ||
        [category isEqualToString:ModContentKindDatapack]) {
        [self parsePack:archive meta:meta category:category];
    } else if ([category isEqualToString:ModContentKindPlugin]) {
        [self parsePlugin:archive meta:meta];
        if (!meta[@"title"]) [self parseManifest:archive meta:meta];
    } else {
        // Mod jar: loader manifests first, generic fallbacks later.
        [self parseFabric:archive meta:meta];
        if (!meta[@"title"] || !meta[@"icon_path"]) [self parseQuilt:archive meta:meta];
        [self parseForge:archive meta:meta];
        [self parseMcmodInfo:archive meta:meta];
        [self parseManifest:archive meta:meta];
        // Resolve ${file.jarVersion}-style placeholders from MANIFEST data.
        NSString *ver = meta[@"version"];
        if ([ver isKindOfClass:[NSString class]] && [ver containsString:@"${"] && meta[@"manifest_version"]) {
            meta[@"version"] = meta[@"manifest_version"];
        }
    }

    if (!meta[@"title"] || [(NSString *)meta[@"title"] length] == 0) {
        meta[@"title"] = [[filePath.lastPathComponent stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    }
    if (!meta[@"kind"]) meta[@"kind"] = @"unknown";
    return meta;
}

#pragma mark - Fabric / Quilt

+ (void)parseFabric:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSDictionary *json = [self jsonDictInArchive:archive paths:@[@"fabric.mod.json"]];
    if (!json) return;
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    if ([json[@"name"] isKindOfClass:[NSString class]]) m[@"title"] = json[@"name"];
    if ([json[@"id"] isKindOfClass:[NSString class]]) m[@"mod_id"] = json[@"id"];
    if ([json[@"version"] isKindOfClass:[NSString class]]) m[@"version"] = json[@"version"];
    if ([json[@"description"] isKindOfClass:[NSString class]]) m[@"description"] = json[@"description"];
    NSString *authors = [self joinedAuthors:json[@"authors"]];
    if (authors.length > 0) m[@"authors"] = authors;
    id icon = json[@"icon"];
    if ([icon isKindOfClass:[NSString class]]) {
        m[@"icon_path"] = icon;
    } else if ([icon isKindOfClass:[NSDictionary class]]) {
        NSArray *prefer = @[@"512x512", @"256x256", @"128x128", @"64x64", @"32x32", @"16x16", @""];
        for (NSString *size in prefer) {
            id v = ((NSDictionary *)icon)[size];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) { m[@"icon_path"] = v; break; }
        }
        if (!m[@"icon_path"]) {
            for (id key in (NSDictionary *)icon) {
                id v = ((NSDictionary *)icon)[key];
                if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) { m[@"icon_path"] = v; break; }
            }
        }
    }
    m[@"kind"] = @"fabric";
    [self mergeInto:meta from:m];
}

+ (void)parseQuilt:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSDictionary *json = [self jsonDictInArchive:archive paths:@[@"quilt.mod.json"]];
    if (!json) return;
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    id loader = json[@"quilt_loader"];
    if ([loader isKindOfClass:[NSDictionary class]]) {
        if ([loader[@"id"] isKindOfClass:[NSString class]]) m[@"mod_id"] = loader[@"id"];
        if ([loader[@"version"] isKindOfClass:[NSString class]]) m[@"version"] = loader[@"version"];
    }
    id md = json[@"metadata"];
    if ([md isKindOfClass:[NSDictionary class]]) {
        if ([md[@"name"] isKindOfClass:[NSString class]]) m[@"title"] = md[@"name"];
        if ([md[@"description"] isKindOfClass:[NSString class]]) m[@"description"] = md[@"description"];
        NSString *authors = [self joinedAuthors:md[@"authors"] ?: md[@"contributors"]];
        if (authors.length > 0) m[@"authors"] = authors;
        if ([md[@"icon"] isKindOfClass:[NSString class]]) {
            m[@"icon_path"] = md[@"icon"];
        } else if ([md[@"icons"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *icons = md[@"icons"];
            id single = icons[@"single"];
            if ([single isKindOfClass:[NSString class]]) m[@"icon_path"] = single;
            else {
                for (id key in icons) {
                    id v = icons[key];
                    if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) { m[@"icon_path"] = v; break; }
                }
            }
        }
    }
    m[@"kind"] = @"quilt";
    [self mergeInto:meta from:m];
}

#pragma mark - Forge / NeoForge (mods.toml)

+ (NSString *)stripTomlString:(NSString *)raw {
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (([s hasPrefix:@"\"\"\""] && [s hasSuffix:@"\"\"\""] && s.length >= 6) ||
        ([s hasPrefix:@"'''"] && [s hasSuffix:@"'''"] && s.length >= 6)) {
        return [[s substringWithRange:NSMakeRange(3, s.length - 6)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (s.length >= 2 && (([s hasPrefix:@"\""] && [s hasSuffix:@"\""]) || ([s hasPrefix:@"'"] && [s hasSuffix:@"'"]))) {
        return [s substringWithRange:NSMakeRange(1, s.length - 2)];
    }
    return s;
}

// Remove trailing # comment (outside quotes).
+ (NSString *)stripTomlComment:(NSString *)line {
    BOOL inStr = NO;
    unichar quote = 0;
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        if (inStr) {
            if (c == quote) inStr = NO;
        } else if (c == '"' || c == '\'') {
            inStr = YES; quote = c;
        } else if (c == '#') {
            return [line substringToIndex:i];
        }
    }
    return line;
}

+ (void)parseForge:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSArray *paths = @[@"META-INF/neoforge.mods.toml", @"META-INF/mods.toml", @"mods.toml"];
    NSData *tomlData = nil;
    BOOL isNeoForge = NO;
    for (NSUInteger i = 0; i < paths.count; i++) {
        tomlData = [archive extractDataFromFile:paths[i] error:nil];
        if (tomlData) { isNeoForge = (i == 0); break; }
    }
    if (!tomlData) return;
    NSString *text = [[NSString alloc] initWithData:tomlData encoding:NSUTF8StringEncoding];
    if (!text) return;

    // Only parse inside [[mods]] blocks; supports '''multiline''' values.
    NSMutableArray *blocks = [NSMutableArray array];
    NSMutableDictionary *current = nil;
    BOOL inMods = NO;
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    for (NSUInteger li = 0; li < lines.count; li++) {
        NSString *line = [lines[li] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0 || [line hasPrefix:@"#"]) continue;
        if ([line hasPrefix:@"[["]) {
            if ([line hasPrefix:@"[[mods]]"]) {
                current = [NSMutableDictionary dictionary];
                [blocks addObject:current];
                inMods = YES;
            } else {
                inMods = NO; current = nil;
            }
            continue;
        }
        if ([line hasPrefix:@"["]) { inMods = NO; current = nil; continue; }
        if (!inMods || !current) continue;
        NSRange eq = [line rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:eq.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *val = [[line substringFromIndex:eq.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        // Multiline '''/""" accumulation
        for (NSString *q in @[@"'''", @"\"\"\""]) {
            if ([val hasPrefix:q] && ![val hasSuffix:q]) {
                NSMutableString *acc = [val mutableCopy];
                while (++li < lines.count) {
                    [acc appendString:@"\n"];
                    [acc appendString:lines[li]];
                    if ([lines[li] containsString:q]) break;
                }
                val = acc;
                break;
            }
        }
        val = [self stripTomlComment:val];
        if ([key isEqualToString:@"authors"]) {
            NSString *t = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([t hasPrefix:@"["]) {
                // ["a", "b"] -> join
                NSMutableArray *names = [NSMutableArray array];
                NSScanner *sc = [NSScanner scannerWithString:t];
                while (!sc.isAtEnd) {
                    NSString *s = nil;
                    [sc scanUpToString:@"\"" intoString:nil];
                    if ([sc scanString:@"\"" intoString:nil] && [sc scanUpToString:@"\"" intoString:&s]) {
                        [sc scanString:@"\"" intoString:nil];
                        if (s.length > 0) [names addObject:s];
                    } else { break; }
                }
                current[@"authors"] = [names componentsJoinedByString:@", "];
            } else {
                current[@"authors"] = [self stripTomlString:val];
            }
        } else {
            current[key] = [self stripTomlString:val];
        }
    }
    // First block with a displayName/modId wins.
    NSDictionary *best = nil;
    for (NSDictionary *b in blocks) {
        if (b[@"modId"] || b[@"displayName"]) { best = b; break; }
    }
    if (!best) best = blocks.firstObject;
    if (![best isKindOfClass:[NSDictionary class]]) return;
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    if ([best[@"displayName"] isKindOfClass:[NSString class]]) m[@"title"] = best[@"displayName"];
    if ([best[@"modId"] isKindOfClass:[NSString class]]) m[@"mod_id"] = best[@"modId"];
    if ([best[@"version"] isKindOfClass:[NSString class]]) m[@"version"] = best[@"version"];
    if ([best[@"description"] isKindOfClass:[NSString class]]) m[@"description"] = best[@"description"];
    if ([best[@"authors"] isKindOfClass:[NSString class]]) m[@"authors"] = best[@"authors"];
    if ([best[@"logoFile"] isKindOfClass:[NSString class]]) m[@"icon_path"] = best[@"logoFile"];
    m[@"kind"] = isNeoForge ? @"neoforge" : @"forge";
    [self mergeInto:meta from:m];
}

#pragma mark - Legacy mcmod.info / MANIFEST.MF

+ (void)parseMcmodInfo:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSData *d = [archive extractDataFromFile:@"mcmod.info" error:nil];
    if (!d) d = [archive extractDataFromFile:@"META-INF/mcmod.info" error:nil];
    if (!d) return;
    id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    NSArray *arr = nil;
    if ([json isKindOfClass:[NSArray class]]) arr = json;
    else if ([json isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in @[@"modList", @"modlist", @"mods"]) {
            if ([json[k] isKindOfClass:[NSArray class]]) { arr = json[k]; break; }
        }
    }
    NSDictionary *entry = nil;
    for (id e in arr ?: @[]) {
        if ([e isKindOfClass:[NSDictionary class]] && [e[@"name"] isKindOfClass:[NSString class]]) { entry = e; break; }
    }
    if (!entry) return;
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    m[@"title"] = entry[@"name"];
    if ([entry[@"modid"] isKindOfClass:[NSString class]]) m[@"mod_id"] = entry[@"modid"];
    if ([entry[@"version"] isKindOfClass:[NSString class]]) m[@"version"] = entry[@"version"];
    if ([entry[@"mcversion"] isKindOfClass:[NSString class]]) m[@"mc_hint"] = entry[@"mcversion"];
    if ([entry[@"description"] isKindOfClass:[NSString class]]) m[@"description"] = entry[@"description"];
    NSString *authors = [self joinedAuthors:entry[@"authorList"] ?: entry[@"author"]];
    if (authors.length > 0) m[@"authors"] = authors;
    if ([entry[@"logoFile"] isKindOfClass:[NSString class]]) m[@"icon_path"] = entry[@"logoFile"];
    if (!m[@"kind"]) m[@"kind"] = @"legacy";
    [self mergeInto:meta from:m];
}

+ (void)parseManifest:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSData *d = [archive extractDataFromFile:@"META-INF/MANIFEST.MF" error:nil];
    if (!d) return;
    NSString *text = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
    if (!text) return;
    NSMutableDictionary *mf = [NSMutableDictionary dictionary];
    NSString *lastKey = nil;
    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
        if (line.length == 0) continue;
        if (([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) && lastKey) {
            mf[lastKey] = [(mf[lastKey] ?: @"") stringByAppendingString:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            continue;
        }
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:colon.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *val = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (key.length > 0) { mf[key] = val; lastKey = key; }
    }
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    NSString *title = mf[@"Implementation-Title"];
    if (![title isKindOfClass:[NSString class]] || title.length == 0) title = mf[@"Bundle-Name"];
    if (![title isKindOfClass:[NSString class]] || title.length == 0) title = mf[@"Automatic-Module-Name"];
    NSString *version = mf[@"Implementation-Version"];
    if (![version isKindOfClass:[NSString class]] || version.length == 0) version = mf[@"Bundle-Version"];
    if ([title isKindOfClass:[NSString class]] && title.length > 0) m[@"title"] = title;
    if ([version isKindOfClass:[NSString class]] && version.length > 0) {
        m[@"version"] = version;
        m[@"manifest_version"] = version;
    }
    [self mergeInto:meta from:m];
}

#pragma mark - Packs (resource / shader / datapack)

+ (id)packTextFromComponent:(id)node {
    if ([node isKindOfClass:[NSString class]]) return node;
    if ([node isKindOfClass:[NSArray class]]) {
        NSMutableString *s = [NSMutableString string];
        for (id e in (NSArray *)node) {
            id t = [self packTextFromComponent:e];
            if ([t isKindOfClass:[NSString class]]) [s appendString:t];
        }
        return s;
    }
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSMutableString *s = [NSMutableString string];
        id text = ((NSDictionary *)node)[@"text"];
        if ([text isKindOfClass:[NSString class]]) [s appendString:text];
        id extra = ((NSDictionary *)node)[@"extra"];
        if (extra) {
            id t = [self packTextFromComponent:extra];
            if ([t isKindOfClass:[NSString class]]) [s appendString:t];
        }
        id translate = ((NSDictionary *)node)[@"translate"];
        if ([translate isKindOfClass:[NSString class]] && s.length == 0) {
            // No lang table here; show key plus "with" args.
            [s appendString:translate];
            id with = ((NSDictionary *)node)[@"with"];
            if (with) {
                id t = [self packTextFromComponent:with];
                if ([t isKindOfClass:[NSString class]] && [(NSString *)t length] > 0) {
                    [s appendFormat:@" (%@)", t];
                }
            }
        }
        return s;
    }
    return @"";
}

+ (void)parsePack:(UZKArchive *)archive meta:(NSMutableDictionary *)meta category:(NSString *)category {
    NSDictionary *json = [self jsonDictInArchive:archive paths:@[@"pack.mcmeta"]];
    if ([json isKindOfClass:[NSDictionary class]]) {
        id pack = json[@"pack"];
        if ([pack isKindOfClass:[NSDictionary class]]) {
            id desc = [self packTextFromComponent:pack[@"description"]];
            if ([desc isKindOfClass:[NSString class]] && [(NSString *)desc length] > 0) meta[@"description"] = desc;
            if (pack[@"pack_format"]) {
                NSString *pf = [NSString stringWithFormat:@"%@", pack[@"pack_format"]];
                meta[@"pack_format"] = pf;
                NSString *disp = [self displayVersionForPackFormat:pf];
                if (disp.length > 0) meta[@"version"] = disp;
            }
        }
    }
    // Shader detection: shaders/ dir at root.
    NSError *err = nil;
    NSArray *names = [archive listFilenames:&err];
    BOOL hasShaders = NO;
    if (!err && [names isKindOfClass:[NSArray class]]) {
        for (NSString *n in names) {
            if ([n hasPrefix:@"shaders/"] && n.length > 8) { hasShaders = YES; break; }
        }
    }
    if ([category isEqualToString:InstalledItemCategoryShaderPack] || hasShaders) {
        meta[@"kind"] = @"shader";
    } else if ([category isEqualToString:ModContentKindDatapack]) {
        meta[@"kind"] = @"datapack";
    } else {
        meta[@"kind"] = @"resource";
    }
}

#pragma mark - Server plugins (plugin.yml)

+ (void)parsePlugin:(UZKArchive *)archive meta:(NSMutableDictionary *)meta {
    NSData *d = [archive extractDataFromFile:@"plugin.yml" error:nil];
    if (!d) d = [archive extractDataFromFile:@"paper-plugin.yml" error:nil];
    if (!d) return;
    NSString *text = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (!text) return;
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    NSMutableArray *authors = [NSMutableArray array];
    BOOL inAuthors = NO;
    NSString *descKey = nil;
    NSMutableString *descAcc = nil;
    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
        if (line.length == 0 || [line hasPrefix:@"#"]) continue;
        BOOL indented = ([rawLine hasPrefix:@" "] || [rawLine hasPrefix:@"\t"]);
        if (indented && descAcc) {
            NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([t hasPrefix:@"- "]) t = [t substringFromIndex:2];
            if (descAcc.length > 0) [descAcc appendString:@" "];
            [descAcc appendString:t];
            continue;
        }
        descAcc = nil;
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:colon.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *val = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        inAuthors = [key isEqualToString:@"authors"];
        if ([key isEqualToString:@"name"]) m[@"title"] = [self stripTomlString:val];
        else if ([key isEqualToString:@"version"]) m[@"version"] = [self stripTomlString:val];
        else if ([key isEqualToString:@"author"]) [authors addObject:[self stripTomlString:val]];
        else if ([key isEqualToString:@"description"]) {
            if (val.length > 0 && ![val isEqualToString:@"|"] && ![val isEqualToString:@">"]) {
                m[@"description"] = [self stripTomlString:val];
            } else {
                descKey = key; descAcc = [NSMutableString string];
            }
        }
        else if ([key isEqualToString:@"main"] || [key isEqualToString:@"bootstrapper"]) m[@"plugin_main"] = val;
        else if ([key isEqualToString:@"api-version"]) m[@"mc_hint"] = val;
        (void)descKey;
    }
    // "- author" list items under authors:
    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"]) {
        NSString *t = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (inAuthors && [t hasPrefix:@"- "]) [authors addObject:[t substringFromIndex:2]];
    }
    if (descAcc && descAcc.length > 0) m[@"description"] = descAcc;
    if (authors.count > 0) m[@"authors"] = [authors componentsJoinedByString:@", "];
    m[@"kind"] = @"plugin";
    [self mergeInto:meta from:m];
}

#pragma mark - Worlds (level.dat NBT + icon.png)

+ (NSData *)gunzipData:(NSData *)data {
    if (!data || data.length < 2) return nil;
    const uint8_t *b = data.bytes;
    if (b[0] != 0x1f || b[1] != 0x8b) return data; // not gzipped
    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = (Bytef *)data.bytes;
    strm.avail_in = (uInt)data.length;
    if (inflateInit2(&strm, 16 + MAX_WBITS) != Z_OK) return nil;
    NSMutableData *out = [NSMutableData dataWithLength:data.length * 3];
    int status;
    do {
        if (strm.total_out >= out.length) [out increaseLengthBy:data.length * 2];
        strm.next_out = (Bytef *)out.mutableBytes + strm.total_out;
        strm.avail_out = (uInt)(out.length - strm.total_out);
        status = inflate(&strm, Z_SYNC_FLUSH);
    } while (status == Z_OK);
    inflateEnd(&strm);
    if (status != Z_STREAM_END) return nil;
    out.length = strm.total_out;
    return out;
}

typedef struct { const uint8_t *p; const uint8_t *end; } NBTCursor;

static uint16_t nbtU16(NBTCursor *c) {
    if (c->p + 2 > c->end) return 0;
    uint16_t v = ((uint16_t)c->p[0] << 8) | c->p[1];
    c->p += 2; return v;
}
static uint32_t nbtU32(NBTCursor *c) {
    if (c->p + 4 > c->end) return 0;
    uint32_t v = ((uint32_t)c->p[0] << 24) | ((uint32_t)c->p[1] << 16) | ((uint32_t)c->p[2] << 8) | c->p[3];
    c->p += 4; return v;
}
static uint64_t nbtU64(NBTCursor *c) {
    if (c->p + 8 > c->end) return 0;
    uint64_t v = 0;
    for (int i = 0; i < 8; i++) v = (v << 8) | c->p[i];
    c->p += 8; return v;
}
static NSString *nbtString(NBTCursor *c) {
    uint16_t len = nbtU16(c);
    if (c->p + len > c->end) { c->p = c->end; return @""; }
    NSString *s = [[NSString alloc] initWithBytes:c->p length:len encoding:NSUTF8StringEncoding] ?: @"";
    c->p += len; return s;
}
// Skip one full payload of the given tag type.
static void nbtSkipPayload(NBTCursor *c, uint8_t type) {
    switch (type) {
        case 1: if (c->p + 1 <= c->end) c->p += 1; break;
        case 2: if (c->p + 2 <= c->end) c->p += 2; break;
        case 3: case 5: if (c->p + 4 <= c->end) c->p += 4; break;
        case 4: case 6: if (c->p + 8 <= c->end) c->p += 8; break;
        case 7: { uint32_t n = nbtU32(c); if (c->p + n <= c->end) c->p += n; else c->p = c->end; break; }
        case 8: (void)nbtString(c); break;
        case 9: {
            if (c->p + 1 > c->end) { c->p = c->end; break; }
            uint8_t et = *c->p++;
            uint32_t n = nbtU32(c);
            for (uint32_t i = 0; i < n && c->p < c->end; i++) nbtSkipPayload(c, et);
            break;
        }
        case 10: {
            while (c->p < c->end) {
                uint8_t t = *c->p++;
                if (t == 0) break;
                (void)nbtString(c);
                nbtSkipPayload(c, t);
            }
            break;
        }
        case 11: { uint32_t n = nbtU32(c); if (n > 100000000) { c->p = c->end; break; } if (c->p + (size_t)n * 4 <= (size_t)(c->end - c->p)) c->p += (size_t)n * 4; else c->p = c->end; break; }
        case 12: { uint32_t n = nbtU32(c); if (n > 100000000) { c->p = c->end; break; } if (c->p + (size_t)n * 8 <= (size_t)(c->end - c->p)) c->p += (size_t)n * 8; else c->p = c->end; break; }
        default: c->p = c->end; break;
    }
}

+ (NSDictionary *)parseLevelDat:(NSData *)raw {
    NSData *data = [self gunzipData:raw];
    if (!data || data.length < 10) return @{};
    NBTCursor c = { data.bytes, (const uint8_t *)data.bytes + data.length };
    if (c.p + 3 > c.end) return @{};
    uint8_t rootType = *c.p++;
    if (rootType != 10) return @{};
    (void)nbtString(&c); // root name (usually "")
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    // Walk root compound entries, descend into "Data" and "Version".
    while (c.p < c.end) {
        uint8_t t = *c.p++;
        if (t == 0) break;
        NSString *name = nbtString(&c);
        if (([name isEqualToString:@"Data"] || [name isEqualToString:@"Version"]) && t == 10) {
            BOOL isData = [name isEqualToString:@"Data"];
            while (c.p < c.end) {
                uint8_t st = *c.p++;
                if (st == 0) break;
                NSString *sname = nbtString(&c);
                if (isData && [sname isEqualToString:@"LevelName"] && st == 8) {
                    out[@"title"] = nbtString(&c);
                } else if (isData && [sname isEqualToString:@"LastPlayed"] && st == 4) {
                    uint64_t v = nbtU64(&c);
                    out[@"last_played_ms"] = @(v);
                } else if (isData && [sname isEqualToString:@"DayTime"] && st == 4) {
                    out[@"day_time"] = @(nbtU64(&c));
                } else if (isData && [sname isEqualToString:@"GameType"] && st == 3) {
                    if (c.p + 4 <= c.end) { uint32_t v = nbtU32(&c); out[@"game_type"] = @(v); }
                } else if (!isData && [sname isEqualToString:@"Name"] && st == 8) {
                    out[@"version"] = nbtString(&c);
                } else if (!isData && [sname isEqualToString:@"Id"] && st == 3) {
                    if (c.p + 4 <= c.end) { out[@"data_version"] = @(nbtU32(&c)); }
                } else {
                    nbtSkipPayload(&c, st);
                }
            }
        } else {
            nbtSkipPayload(&c, t);
        }
    }
    return out;
}

+ (NSDictionary *)worldInfoForWorldDir:(NSString *)worldDir {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"kind"] = @"world";
    NSString *fallback = worldDir.lastPathComponent;
    info[@"title"] = fallback;
    if (worldDir.length == 0) return info;
    NSString *levelPath = [worldDir stringByAppendingPathComponent:@"level.dat"];
    NSData *raw = [NSData dataWithContentsOfFile:levelPath];
    if (raw) {
        NSDictionary *nbt = [self parseLevelDat:raw];
        if ([nbt[@"title"] isKindOfClass:[NSString class]] && [(NSString *)nbt[@"title"] length] > 0) info[@"title"] = nbt[@"title"];
        if (nbt[@"version"]) info[@"version"] = [NSString stringWithFormat:@"%@", nbt[@"version"]];
        if (nbt[@"last_played_ms"]) info[@"last_played_ms"] = nbt[@"last_played_ms"];
        if (nbt[@"game_type"]) info[@"game_type"] = nbt[@"game_type"];
    }
    NSString *iconPath = [worldDir stringByAppendingPathComponent:@"icon.png"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
        info[@"icon_path"] = iconPath;
        UIImage *img = [UIImage imageWithContentsOfFile:iconPath];
        if (img) info[@"icon_image"] = img;
    }
    // Datapacks inside the world.
    NSString *dpDir = [worldDir stringByAppendingPathComponent:@"datapacks"];
    NSArray *dpFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dpDir error:nil] ?: @[];
    NSMutableArray *dps = [NSMutableArray array];
    for (NSString *f in dpFiles) {
        if ([f hasSuffix:@".zip"]) [dps addObject:f];
    }
    if (dps.count > 0) info[@"datapacks"] = dps;
    return info;
}

+ (NSDictionary *)worldInfoForWorldZip:(NSString *)zipPath {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"kind"] = @"world";
    info[@"title"] = [[zipPath.lastPathComponent stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    UZKArchive *archive = [self archiveForPath:zipPath];
    if (!archive) return info;
    NSError *err = nil;
    NSArray *names = [archive listFilenames:&err];
    if (err || ![names isKindOfClass:[NSArray class]]) return info;
    // level.dat at depth 0 preferred, else depth 1 (TopFolder/level.dat).
    NSString *levelEntry = nil;
    NSString *prefix = @"";
    for (NSString *n in names) {
        if ([n isEqualToString:@"level.dat"]) { levelEntry = n; prefix = @""; break; }
    }
    if (!levelEntry) {
        for (NSString *n in names) {
            if ([n hasSuffix:@"/level.dat"] && [[n componentsSeparatedByString:@"/"] count] == 2) {
                levelEntry = n; prefix = [[n stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
                break;
            }
        }
    }
    if (levelEntry) {
        NSData *raw = [archive extractDataFromFile:levelEntry error:nil];
        if (raw) {
            NSDictionary *nbt = [self parseLevelDat:raw];
            if ([nbt[@"title"] isKindOfClass:[NSString class]] && [(NSString *)nbt[@"title"] length] > 0) info[@"title"] = nbt[@"title"];
            if (nbt[@"version"]) info[@"version"] = [NSString stringWithFormat:@"%@", nbt[@"version"]];
            if (nbt[@"last_played_ms"]) info[@"last_played_ms"] = nbt[@"last_played_ms"];
        }
        NSString *iconEntry = [prefix stringByAppendingString:@"icon.png"];
        NSData *iconData = [archive extractDataFromFile:iconEntry error:nil];
        if (iconData) {
            UIImage *img = [UIImage imageWithData:iconData];
            if (img) info[@"icon_image"] = img;
        }
    }
    return info;
}

#pragma mark - Disk cache + async icons

- (NSString *)diskCacheDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"ModIcons"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)cacheKeyForFilePath:(NSString *)path {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSString *raw = [NSString stringWithFormat:@"%@|%@|%@", path, attrs[NSFileModificationDate] ?: @"", attrs[NSFileSize] ?: @""];
    const char *c = raw.UTF8String;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(c, (CC_LONG)strlen(c), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (NSString *)cacheKeyForURLString:(NSString *)url {
    const char *c = url.UTF8String ?: "";
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(c, (CC_LONG)strlen(c), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return [@"remote-" stringByAppendingString:hex];
}

- (void)iconForFileAtPath:(NSString *)filePath
                 category:(NSString *)category
               completion:(void(^)(UIImage * _Nullable, NSDictionary *))completion {
    if (filePath.length == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, @{}); });
        return;
    }
    NSString *key = [self cacheKeyForFilePath:filePath];
    UIImage *mem = [self.memCache objectForKey:key];
    if (mem) {
        NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:filePath category:category];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(mem, meta); });
        return;
    }
    NSString *diskPath = [[self diskCacheDir] stringByAppendingPathComponent:[key stringByAppendingPathExtension:@"png"]];
    NSData *diskData = [NSData dataWithContentsOfFile:diskPath];
    if (diskData) {
        UIImage *img = [UIImage imageWithData:diskData];
        if (img) [self.memCache setObject:img forKey:key];
        NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:filePath category:category];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(img, meta); });
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        NSDictionary *meta = [ModMetadataReader metadataForFileAtPath:filePath category:category];
        UIImage *icon = [weakSelf extractIconFromArchive:filePath meta:meta category:category];
        if (icon) {
            [weakSelf.memCache setObject:icon forKey:key];
            NSData *png = UIImagePNGRepresentation(icon);
            if (png) [png writeToFile:diskPath atomically:YES];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(icon, meta);
        });
    });
}

- (UIImage *)extractIconFromArchive:(NSString *)filePath meta:(NSDictionary *)meta category:(NSString *)category {
    UZKArchive *archive = [ModMetadataReader archiveForPath:filePath];
    if (!archive) return nil;

    // Packs & worlds: pack.png / icon.png at root (or next to level.dat).
    if ([category isEqualToString:InstalledItemCategoryResourcePack] ||
        [category isEqualToString:InstalledItemCategoryShaderPack] ||
        [category isEqualToString:ModContentKindDatapack]) {
        NSData *packPng = [archive extractDataFromFile:@"pack.png" error:nil];
        if (!packPng) {
            // Case-insensitive fallback (Pack.png, PACK.PNG, ...).
            NSString *found = [self findEntry:archive named:@"pack.png"];
            if (found) packPng = [archive extractDataFromFile:found error:nil];
        }
        if (packPng) {
            UIImage *img = [UIImage imageWithData:packPng];
            if (img) return img;
        }
        return [self scanIcon:archive modId:nil];
    }
    if ([category isEqualToString:ModContentKindWorld]) {
        NSDictionary *info = [ModMetadataReader worldInfoForWorldZip:filePath];
        UIImage *img = info[@"icon_image"];
        if ([img isKindOfClass:[UIImage class]]) return img;
        return nil;
    }

    // 1) Explicit icon path from any manifest (icon / icons.single / logoFile).
    NSString *iconPath = meta[@"icon_path"];
    if ([iconPath isKindOfClass:[NSString class]] && iconPath.length > 0) {
        NSString *p = [iconPath hasPrefix:@"/"] ? [iconPath substringFromIndex:1] : iconPath;
        // logoFile is relative to jar root.
        NSData *d = [archive extractDataFromFile:p error:nil];
        if (!d) {
            // Try case-insensitive match via listing.
            NSString *found = [self findEntry:archive named:p];
            if (found) d = [archive extractDataFromFile:found error:nil];
        }
        if (d) {
            UIImage *img = [UIImage imageWithData:d];
            if (img) return img;
        }
    }
    // 2) Scan listing for icon-like images.
    NSString *modId = meta[@"mod_id"];
    if (![modId isKindOfClass:[NSString class]]) modId = nil;
    return [self scanIcon:archive modId:modId];
}

// Case-insensitive exact lookup.
- (NSString *)findEntry:(UZKArchive *)archive named:(NSString *)name {
    NSError *err = nil;
    NSArray *names = [archive listFilenames:&err];
    if (err || ![names isKindOfClass:[NSArray class]]) return nil;
    NSString *lower = name.lowercaseString;
    for (NSString *n in names) {
        if ([n.lowercaseString isEqualToString:lower]) return n;
    }
    return nil;
}

- (UIImage *)scanIcon:(UZKArchive *)archive modId:(NSString *)modId {
    NSError *err = nil;
    NSArray *names = [archive listFilenames:&err];
    if (err || ![names isKindOfClass:[NSArray class]]) return nil;
    NSArray *exts = @[@".png", @".jpg", @".jpeg", @".webp"];
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSString *n in names) {
        if ([n hasSuffix:@"/"]) continue;
        NSString *lower = n.lowercaseString;
        BOOL hasImgExt = NO;
        for (NSString *e in exts) {
            if ([lower hasSuffix:e]) { hasImgExt = YES; break; }
        }
        if (!hasImgExt) continue;
        NSString *base = lower.lastPathComponent;
        BOOL looksIcon = ([base containsString:@"icon"] || [base containsString:@"logo"] || [base isEqualToString:@"pack.png"]);
        if (!looksIcon) continue;
        // Score: assets/<modid> first, then root, then shallow paths.
        NSInteger score = 100 + (NSInteger)n.length;
        if (modId && [lower containsString:[@"assets/" stringByAppendingString:modId.lowercaseString]]) score = 0;
        else if (![n containsString:@"/"]) score = 10;
        else if ([lower hasPrefix:@"assets/"]) score = 20;
        [candidates addObject:@{@"name": n, @"score": @(score)}];
    }
    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"score"] compare:b[@"score"]];
    }];
    NSInteger tried = 0;
    for (NSDictionary *c in candidates) {
        if (++tried > 12) break;
        NSData *d = [archive extractDataFromFile:c[@"name"] error:nil];
        if (!d || d.length == 0 || d.length > 2 * 1024 * 1024) continue;
        UIImage *img = [UIImage imageWithData:d];
        if (img) return img;
    }
    return nil;
}

- (void)remoteIconForURLString:(NSString *)urlString
                   completion:(void(^)(UIImage * _Nullable))completion {
    if (![urlString isKindOfClass:[NSString class]] || urlString.length == 0) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSString *key = [self cacheKeyForURLString:urlString];
    UIImage *mem = [self.memCache objectForKey:key];
    if (mem) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(mem); });
        return;
    }
    NSString *diskPath = [[self diskCacheDir] stringByAppendingPathComponent:[key stringByAppendingPathExtension:@"png"]];
    NSData *diskData = [NSData dataWithContentsOfFile:diskPath];
    if (diskData) {
        UIImage *img = [UIImage imageWithData:diskData];
        if (img) [self.memCache setObject:img forKey:key];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(img); });
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Witch/1.0" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        UIImage *img = nil;
        if ([data isKindOfClass:[NSData class]] && data.length > 0 && !err) {
            img = [UIImage imageWithData:data];
            if (img) {
                [weakSelf.memCache setObject:img forKey:key];
                [data writeToFile:diskPath atomically:YES];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(img);
        });
    }] resume];
}

@end
