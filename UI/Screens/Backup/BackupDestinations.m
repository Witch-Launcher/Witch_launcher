#import "BackupDestinations.h"
#import "BackupConfig.h"
#import "BackupHTTP.h"
#import "BackupKeychain.h"
#import "BackupOAuth.h"
#import "LauncherPreferences.h"
#import "utils.h"

static NSString *const kBackupDestinationErrorDomain = @"WitchBackupDestinationErrorDomain";

static NSError *BDError(NSString *message, NSInteger code) {
    return [NSError errorWithDomain:kBackupDestinationErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Cloud storage error"}];
}

static NSString *BDString(id object) {
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

static BOOL BDDestinationEnabled(NSString *identifier) {
    return getPrefBool([NSString stringWithFormat:@"backup.dest_%@_enabled", identifier]);
}

static void BDSetDestinationEnabled(NSString *identifier, BOOL enabled) {
    setPrefBool([NSString stringWithFormat:@"backup.dest_%@_enabled", identifier], enabled);
}

static NSMutableURLRequest *BDJSONRequest(NSURL *url, NSString *method, NSString *token, id body) {
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:url method:method];
    if (token.length > 0) [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    if (body) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    return request;
}

static NSString *BDBasicAuth(NSString *username, NSString *password) {
    NSString *pair = [NSString stringWithFormat:@"%@:%@", username ?: @"", password ?: @""];
    NSData *data = [pair dataUsingEncoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"Basic %@", [data base64EncodedStringWithOptions:0]];
}

#pragma mark - Files / Cloud folder

@interface BackupFolderDestination ()
@property (nonatomic, strong) NSURL *cachedURL;
@end

@implementation BackupFolderDestination

- (NSString *)identifier { return @"folder"; }
- (NSString *)displayName { return localize(@"Files / Cloud folder", nil); }
- (BOOL)enabled { return BDDestinationEnabled(self.identifier); }
- (void)setEnabled:(BOOL)enabled { BDSetDestinationEnabled(self.identifier, enabled); }

- (NSURL *)folderURL {
    if (self.cachedURL) return self.cachedURL;
    NSData *data = getPrefObject(@"backup.folder_bookmark");
    if (![data isKindOfClass:[NSData class]]) return nil;
    BOOL stale = NO;
    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:data
                                           options:0
                                     relativeToURL:nil
                               bookmarkDataIsStale:&stale
                                             error:&error];
    if (!url) return nil;
    if (stale) {
        NSData *newData = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
        if (newData) setPrefObject(@"backup.folder_bookmark", newData);
    }
    self.cachedURL = url;
    return url;
}

- (BOOL)setFolderURL:(NSURL *)url error:(NSError **)error {
    if (!url) {
        if (error) *error = BDError(localize(@"No folder selected.", nil), 1);
        return NO;
    }
    NSData *bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:error];
    if (!bookmark) return NO;
    setPrefObject(@"backup.folder_bookmark", bookmark);
    self.cachedURL = url;
    return YES;
}

- (void)clearFolder {
    setPrefObject(@"backup.folder_bookmark", @"");
    self.cachedURL = nil;
}

- (BOOL)configured {
    return [self folderURL] != nil;
}

- (NSString *)detailText {
    NSURL *url = [self folderURL];
    if (!url) return localize(@"Not connected", nil);
    return url.lastPathComponent.length > 0 ? url.lastPathComponent : url.path;
}

- (NSURL *)remoteFolderURLWithError:(NSError **)error {
    NSURL *root = [self folderURL];
    if (!root) {
        if (error) *error = BDError(localize(@"Choose a backup folder first.", nil), 2);
        return nil;
    }
    [root startAccessingSecurityScopedResource];
    NSURL *folder = [root URLByAppendingPathComponent:[BackupConfig remoteFolderName] isDirectory:YES];
    NSError *createError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&createError]) {
        if (error) *error = createError;
        [root stopAccessingSecurityScopedResource];
        return nil;
    }
    return folder;
}

- (void)uploadFileAtPath:(NSString *)path
                  record:(BackupRecord *)record
              completion:(void (^)(NSDictionary *, NSError *))completion {
    NSError *folderError = nil;
    NSURL *folder = [self remoteFolderURLWithError:&folderError];
    if (!folder) {
        if (completion) completion(nil, folderError);
        return;
    }
    NSURL *destination = [folder URLByAppendingPathComponent:record.fileName];
    __block NSError *coordinationError = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateWritingItemAtURL:destination
                                    options:NSFileCoordinatorWritingForReplacing
                                      error:&coordinationError
                                 byAccessor:^(NSURL *newURL) {
        [[NSFileManager defaultManager] removeItemAtURL:newURL error:nil];
        NSError *copyError = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:path] toURL:newURL error:&copyError]) {
            coordinationError = copyError;
        }
    }];
    [[self folderURL] stopAccessingSecurityScopedResource];
    if (coordinationError) {
        if (completion) completion(nil, coordinationError);
        return;
    }
    if (completion) completion(@{@"name": record.fileName, @"path": destination.path ?: @""}, nil);
}

- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    NSError *folderError = nil;
    NSURL *folder = [self remoteFolderURLWithError:&folderError];
    if (!folder) {
        if (completion) completion(nil, folderError);
        return;
    }
    NSError *listError = nil;
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:folder
                                                            includingPropertiesForKeys:@[NSURLFileSizeKey, NSURLContentModificationDateKey]
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   error:&listError];
    [[self folderURL] stopAccessingSecurityScopedResource];
    if (!urls) {
        if (completion) completion(nil, listError);
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    for (NSURL *url in urls) {
        if (![url.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
        NSDictionary *values = [url resourceValuesForKeys:@[NSURLFileSizeKey, NSURLContentModificationDateKey] error:nil];
        [items addObject:@{
            @"name": url.lastPathComponent ?: @"",
            @"size": values[NSURLFileSizeKey] ?: @0,
            @"modified": values[NSURLContentModificationDateKey] ?: [NSDate date],
            @"path": url.path ?: @"",
        }];
    }
    if (completion) completion(items, nil);
}

- (void)downloadFileNamed:(NSString *)name
                   toPath:(NSString *)path
               completion:(void (^)(NSError *))completion {
    NSError *folderError = nil;
    NSURL *folder = [self remoteFolderURLWithError:&folderError];
    if (!folder) {
        if (completion) completion(folderError);
        return;
    }
    NSURL *source = [folder URLByAppendingPathComponent:name];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL:source toURL:[NSURL fileURLWithPath:path] error:&error]) {
        [[self folderURL] stopAccessingSecurityScopedResource];
        if (completion) completion(error);
        return;
    }
    [[self folderURL] stopAccessingSecurityScopedResource];
    if (completion) completion(nil);
}

- (void)deleteFileNamed:(NSString *)name completion:(void (^)(NSError *))completion {
    NSError *folderError = nil;
    NSURL *folder = [self remoteFolderURLWithError:&folderError];
    if (!folder) {
        if (completion) completion(folderError);
        return;
    }
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:[folder URLByAppendingPathComponent:name] error:&error];
    [[self folderURL] stopAccessingSecurityScopedResource];
    if (error && [error.domain isEqualToString:NSCocoaErrorDomain] &&
        (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError)) {
        error = nil;
    }
    if (completion) completion(error);
}

@end

#pragma mark - WebDAV

@interface WebDAVMultistatusParser : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *items;
@property (nonatomic, strong) NSMutableDictionary *current;
@property (nonatomic, copy) NSString *currentElement;
@property (nonatomic, strong) NSMutableString *text;
@end

@implementation WebDAVMultistatusParser

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        _text = [NSMutableString string];
    }
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    NSString *name = elementName.lowercaseString;
    if ([name isEqualToString:@"response"]) {
        self.current = [NSMutableDictionary dictionary];
    }
    if ([name isEqualToString:@"href"] || [name isEqualToString:@"getcontentlength"] || [name isEqualToString:@"getlastmodified"]) {
        self.currentElement = name;
        [self.text setString:@""];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.currentElement) [self.text appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSString *name = elementName.lowercaseString;
    if (self.currentElement && [name isEqualToString:self.currentElement]) {
        NSString *value = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name isEqualToString:@"href"]) {
            self.current[@"href"] = [value stringByRemovingPercentEncoding] ?: value;
        } else if ([name isEqualToString:@"getcontentlength"]) {
            self.current[@"size"] = @(value.longLongValue);
        } else if ([name isEqualToString:@"getlastmodified"]) {
            self.current[@"modified"] = value;
        }
        self.currentElement = nil;
    }
    if ([name isEqualToString:@"response"] && self.current) {
        [self.items addObject:self.current];
        self.current = nil;
    }
}

@end

@interface BackupWebDAVDestination ()
@property (nonatomic, strong) WebDAVMultistatusParser *parser;
@end

@implementation BackupWebDAVDestination

- (NSString *)identifier { return @"webdav"; }
- (NSString *)displayName { return @"WebDAV"; }
- (BOOL)enabled { return BDDestinationEnabled(self.identifier); }
- (void)setEnabled:(BOOL)enabled { BDSetDestinationEnabled(self.identifier, enabled); }

- (NSString *)baseURLString {
    NSString *url = getPrefObject(@"backup.webdav_url");
    if (![url isKindOfClass:[NSString class]]) return @"";
    return [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)username {
    NSString *value = getPrefObject(@"backup.webdav_username");
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

- (NSString *)password {
    return [BackupKeychain stringForKey:@"backup.webdav.password"] ?: @"";
}

- (BOOL)configured {
    return self.baseURLString.length > 0;
}

- (NSString *)detailText {
    if (self.baseURLString.length == 0) return localize(@"Not configured", nil);
    return self.baseURLString;
}

- (NSString *)folderURLString {
    NSString *base = [self.baseURLString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [base stringByAppendingFormat:@"/%@", [BackupHTTP urlEncode:[BackupConfig remoteFolderName]]];
}

- (void)applyAuth:(NSMutableURLRequest *)request {
    if (self.username.length > 0 || self.password.length > 0) {
        [request setValue:BDBasicAuth(self.username, self.password) forHTTPHeaderField:@"Authorization"];
    }
}

- (void)ensureFolderWithCompletion:(void (^)(NSError *))completion {
    if (!self.configured) {
        if (completion) completion(BDError(localize(@"Set the WebDAV server URL first.", nil), 10));
        return;
    }
    NSString *urlString = [self.baseURLString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    urlString = [urlString stringByAppendingFormat:@"/%@", [BackupHTTP urlEncode:[BackupConfig remoteFolderName]]];
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"MKCOL"];
    [self applyAuth:request];
    [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSInteger status = response.statusCode;
        if ((status >= 200 && status < 300) || status == 405 || status == 301 || status == 302) {
            if (completion) completion(nil);
        } else {
            if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not create the WebDAV folder.", nil)]);
        }
    }];
}

- (void)uploadFileAtPath:(NSString *)path record:(BackupRecord *)record completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        NSString *urlString = [self.folderURLString stringByAppendingFormat:@"/%@", [BackupHTTP urlEncode:record.fileName]];
        NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"PUT"];
        [self applyAuth:request];
        [request setValue:@"application/zip" forHTTPHeaderField:@"Content-Type"];
        [BackupHTTP uploadRequest:request fromFile:path completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
            } else if (![BackupHTTP isSuccess:response]) {
                if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"WebDAV upload failed.", nil)]);
            } else {
                if (completion) completion(@{@"name": record.fileName, @"path": urlString}, nil);
            }
        }];
    }];
}

- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    NSString *urlString = self.folderURLString;
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"PROPFIND"];
    [self applyAuth:request];
    [request setValue:@"1" forHTTPHeaderField:@"Depth"];
    [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSString *body = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><d:propfind xmlns:d=\"DAV:\"><d:prop><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>";
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (![BackupHTTP isSuccess:response] && response.statusCode != 207) {
            if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not list WebDAV files.", nil)]);
            return;
        }
        WebDAVMultistatusParser *parser = [[WebDAVMultistatusParser alloc] init];
        NSXMLParser *xml = [[NSXMLParser alloc] initWithData:data ?: [NSData data]];
        xml.delegate = parser;
        [xml parse];
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *item in parser.items) {
            NSString *href = BDString(item[@"href"]);
            NSString *name = href.lastPathComponent;
            if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
            [items addObject:@{
                @"name": name,
                @"size": item[@"size"] ?: @0,
                @"modified": item[@"modified"] ?: @"",
                @"path": href ?: @"",
            }];
        }
        if (completion) completion(items, nil);
    }];
}

- (void)downloadFileNamed:(NSString *)name toPath:(NSString *)path completion:(void (^)(NSError *))completion {
    NSString *urlString = [self.folderURLString stringByAppendingFormat:@"/%@", [BackupHTTP urlEncode:name]];
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"GET"];
    [self applyAuth:request];
    [BackupHTTP downloadRequest:request toPath:path completion:completion];
}

- (void)deleteFileNamed:(NSString *)name completion:(void (^)(NSError *))completion {
    NSString *urlString = [self.folderURLString stringByAppendingFormat:@"/%@", [BackupHTTP urlEncode:name]];
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"DELETE"];
    [self applyAuth:request];
    [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(error);
        } else if (![BackupHTTP isSuccess:response] && response.statusCode != 404) {
            if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not delete the WebDAV backup.", nil)]);
        } else {
            if (completion) completion(nil);
        }
    }];
}

@end

#pragma mark - Google Drive

@interface BackupGoogleDriveDestination ()
@property (nonatomic, copy) NSString *folderID;
@end

@implementation BackupGoogleDriveDestination

- (NSString *)identifier { return @"gdrive"; }
- (NSString *)displayName { return @"Google Drive"; }
- (BOOL)enabled { return BDDestinationEnabled(self.identifier); }
- (void)setEnabled:(BOOL)enabled { BDSetDestinationEnabled(self.identifier, enabled); }
- (BOOL)configured { return [BackupOAuth.shared isAuthorizedForProvider:BackupOAuthProviderGoogleDrive]; }
- (NSString *)detailText {
    if (![BackupConfig googleConfigured]) return localize(@"Not available in this build", nil);
    return self.configured ? localize(@"Connected", nil) : localize(@"Not connected", nil);
}

- (void)withToken:(void (^)(NSString *, NSError *))completion {
    [BackupOAuth.shared accessTokenForProvider:BackupOAuthProviderGoogleDrive completion:completion];
}

- (void)ensureFolderWithCompletion:(void (^)(NSString *, NSError *))completion {
    NSString *cached = getPrefObject(@"backup.gdrive_folderID");
    if ([cached isKindOfClass:[NSString class]] && cached.length > 0) {
        if (completion) completion(cached, nil);
        return;
    }
    [self withToken:^(NSString *token, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSString *query = @"name='Witch Backups' and mimeType='application/vnd.google-apps.folder' and trashed=false";
        NSString *urlString = [NSString stringWithFormat:@"https://www.googleapis.com/drive/v3/files?q=%@&fields=files(id,name)&spaces=drive", [BackupHTTP urlEncode:query]];
        NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"GET", token, nil);
        [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
            if (requestError) {
                if (completion) completion(nil, requestError);
                return;
            }
            if (![BackupHTTP isSuccess:response]) {
                if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not access Google Drive.", nil)]);
                return;
            }
            NSArray *files = [json isKindOfClass:[NSDictionary class]] ? json[@"files"] : nil;
            if ([files isKindOfClass:[NSArray class]] && files.count > 0) {
                NSString *folderID = BDString(files.firstObject[@"id"]);
                if (folderID.length > 0) {
                    setPrefObject(@"backup.gdrive_folderID", folderID);
                    if (completion) completion(folderID, nil);
                    return;
                }
            }
            [self createFolderWithToken:token completion:completion];
        }];
    }];
}

- (void)createFolderWithToken:(NSString *)token completion:(void (^)(NSString *, NSError *))completion {
    NSURL *url = [NSURL URLWithString:@"https://www.googleapis.com/drive/v3/files?fields=id"];
    NSDictionary *body = @{@"name": [BackupConfig remoteFolderName], @"mimeType": @"application/vnd.google-apps.folder"};
    NSMutableURLRequest *request = BDJSONRequest(url, @"POST", token, body);
    [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSString *folderID = [json isKindOfClass:[NSDictionary class]] ? BDString(json[@"id"]) : nil;
        if (![BackupHTTP isSuccess:response] || folderID.length == 0) {
            if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not create the Google Drive folder.", nil)]);
            return;
        }
        setPrefObject(@"backup.gdrive_folderID", folderID);
        if (completion) completion(folderID, nil);
    }];
}

- (void)uploadFileAtPath:(NSString *)path record:(BackupRecord *)record completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSString *folderID, NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
            NSDictionary *metadata = @{
                @"name": record.fileName,
                @"parents": @[folderID],
                @"appProperties": @{@"witchBackup": @"1"},
            };
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:@"https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,size,createdTime"], @"POST", token, metadata);
            [request setValue:@"application/zip" forHTTPHeaderField:@"X-Upload-Content-Type"];
            [request setValue:[NSString stringWithFormat:@"%llu", size] forHTTPHeaderField:@"X-Upload-Content-Length"];
            [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(nil, requestError);
                    return;
                }
                NSString *location = response.allHeaderFields[@"Location"];
                if (![BackupHTTP isSuccess:response] || location.length == 0) {
                    if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not start the Google Drive upload.", nil)]);
                    return;
                }
                NSMutableURLRequest *upload = [BackupHTTP requestWithURL:[NSURL URLWithString:location] method:@"PUT"];
                [upload setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
                [upload setValue:@"application/zip" forHTTPHeaderField:@"Content-Type"];
                [BackupHTTP uploadRequest:upload fromFile:path completion:^(NSData *uploadData, NSHTTPURLResponse *uploadResponse, NSError *uploadError) {
                    if (uploadError) {
                        if (completion) completion(nil, uploadError);
                    } else if (![BackupHTTP isSuccess:uploadResponse]) {
                        if (completion) completion(nil, [BackupHTTP errorFromData:uploadData response:uploadResponse fallback:localize(@"Google Drive upload failed.", nil)]);
                    } else {
                        id json = uploadData.length > 0 ? [NSJSONSerialization JSONObjectWithData:uploadData options:0 error:nil] : nil;
                        if (completion) completion([json isKindOfClass:[NSDictionary class]] ? json : @{@"name": record.fileName}, nil);
                    }
                }];
            }];
        }];
    }];
}

- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSString *folderID, NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSString *query = [NSString stringWithFormat:@"'%@' in parents and trashed=false", folderID];
            NSString *urlString = [NSString stringWithFormat:@"https://www.googleapis.com/drive/v3/files?q=%@&fields=files(id,name,size,createdTime)&orderBy=createdTime desc&pageSize=1000", [BackupHTTP urlEncode:query]];
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"GET", token, nil);
            [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(nil, requestError);
                    return;
                }
                if (![BackupHTTP isSuccess:response]) {
                    if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not list Google Drive backups.", nil)]);
                    return;
                }
                NSArray *files = [json isKindOfClass:[NSDictionary class]] ? json[@"files"] : nil;
                NSMutableArray *items = [NSMutableArray array];
                for (NSDictionary *file in files ?: @[]) {
                    if (![file isKindOfClass:[NSDictionary class]]) continue;
                    NSString *name = BDString(file[@"name"]);
                    if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
                    [items addObject:@{
                        @"name": name,
                        @"size": file[@"size"] ?: @0,
                        @"modified": file[@"createdTime"] ?: @"",
                        @"id": file[@"id"] ?: @"",
                    }];
                }
                if (completion) completion(items, nil);
            }];
        }];
    }];
}

- (void)downloadFileNamed:(NSString *)name toPath:(NSString *)path completion:(void (^)(NSError *))completion {
    [self listWithCompletion:^(NSArray<NSDictionary *> *items, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSString *fileID = nil;
        for (NSDictionary *item in items) {
            if ([item[@"name"] isEqualToString:name]) { fileID = BDString(item[@"id"]); break; }
        }
        if (fileID.length == 0) {
            if (completion) completion(BDError(localize(@"Backup not found in Google Drive.", nil), 20));
            return;
        }
        [self withToken:^(NSString *token, NSError *tokenError) {
            if (tokenError) {
                if (completion) completion(tokenError);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://www.googleapis.com/drive/v3/files/%@?alt=media", [BackupHTTP urlEncode:fileID]];
            NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"GET"];
            [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
            [BackupHTTP downloadRequest:request toPath:path completion:completion];
        }];
    }];
}

- (void)deleteFileNamed:(NSString *)name completion:(void (^)(NSError *))completion {
    [self listWithCompletion:^(NSArray<NSDictionary *> *items, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSString *fileID = nil;
        for (NSDictionary *item in items) {
            if ([item[@"name"] isEqualToString:name]) { fileID = BDString(item[@"id"]); break; }
        }
        if (fileID.length == 0) {
            if (completion) completion(nil);
            return;
        }
        [self withToken:^(NSString *token, NSError *tokenError) {
            if (tokenError) {
                if (completion) completion(tokenError);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://www.googleapis.com/drive/v3/files/%@", [BackupHTTP urlEncode:fileID]];
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"DELETE", token, nil);
            [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(requestError);
                } else if (![BackupHTTP isSuccess:response] && response.statusCode != 404) {
                    if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not delete the Google Drive backup.", nil)]);
                } else {
                    if (completion) completion(nil);
                }
            }];
        }];
    }];
}

@end

#pragma mark - OneDrive

@implementation BackupOneDriveDestination

- (NSString *)identifier { return @"onedrive"; }
- (NSString *)displayName { return @"OneDrive"; }
- (BOOL)enabled { return BDDestinationEnabled(self.identifier); }
- (void)setEnabled:(BOOL)enabled { BDSetDestinationEnabled(self.identifier, enabled); }
- (BOOL)configured { return [BackupOAuth.shared isAuthorizedForProvider:BackupOAuthProviderOneDrive]; }
- (NSString *)detailText {
    if (![BackupConfig azureConfigured]) return localize(@"Not available in this build", nil);
    return self.configured ? localize(@"Connected", nil) : localize(@"Not connected", nil);
}

- (void)withToken:(void (^)(NSString *, NSError *))completion {
    [BackupOAuth.shared accessTokenForProvider:BackupOAuthProviderOneDrive completion:completion];
}

- (NSString *)folderPath {
    return [BackupHTTP urlEncode:[BackupConfig remoteFolderName]];
}

- (void)ensureFolderWithCompletion:(void (^)(NSError *))completion {
    [self withToken:^(NSString *token, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/v1.0/me/drive/root:/%@", self.folderPath];
        NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"GET", token, nil);
        [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
            if (requestError) {
                if (completion) completion(requestError);
                return;
            }
            if ([BackupHTTP isSuccess:response]) {
                if (completion) completion(nil);
                return;
            }
            if (response.statusCode != 404) {
                if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not access OneDrive.", nil)]);
                return;
            }
            NSDictionary *body = @{@"name": [BackupConfig remoteFolderName], @"folder": @{}, @"@microsoft.graph.conflictBehavior": @"fail"};
            NSMutableURLRequest *create = BDJSONRequest([NSURL URLWithString:@"https://graph.microsoft.com/v1.0/me/drive/root/children"], @"POST", token, body);
            [BackupHTTP dataRequest:create completion:^(NSData *createData, NSHTTPURLResponse *createResponse, NSError *createError) {
                if (createError) {
                    if (completion) completion(createError);
                } else if (![BackupHTTP isSuccess:createResponse] && createResponse.statusCode != 409) {
                    if (completion) completion([BackupHTTP errorFromData:createData response:createResponse fallback:localize(@"Could not create the OneDrive folder.", nil)]);
                } else {
                    if (completion) completion(nil);
                }
            }];
        }];
    }];
}

- (void)uploadFileAtPath:(NSString *)path record:(BackupRecord *)record completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/v1.0/me/drive/root:/%@/%@:/createUploadSession", self.folderPath, [BackupHTTP urlEncode:record.fileName]];
            NSDictionary *body = @{@"item": @{@"@microsoft.graph.conflictBehavior": @"replace", @"name": record.fileName}};
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"POST", token, body);
            [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(nil, requestError);
                    return;
                }
                NSString *uploadURL = [json isKindOfClass:[NSDictionary class]] ? BDString(json[@"uploadUrl"]) : nil;
                if (![BackupHTTP isSuccess:response] || uploadURL.length == 0) {
                    if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not start the OneDrive upload.", nil)]);
                    return;
                }
                [self uploadChunksToURL:uploadURL filePath:path token:token completion:completion];
            }];
        }];
    }];
}

- (void)uploadChunksToURL:(NSString *)uploadURL
                 filePath:(NSString *)filePath
                    token:(NSString *)token
               completion:(void (^)(NSDictionary *, NSError *))completion {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    unsigned long long total = [attrs[NSFileSize] unsignedLongLongValue];
    if (!handle || total == 0) {
        [handle closeFile];
        if (completion) completion(nil, BDError(localize(@"Could not read the backup file.", nil), 30));
        return;
    }
    [handle seekToFileOffset:0];
    [self sendChunkFromHandle:handle
                    uploadURL:uploadURL
                     filePath:filePath
                        token:token
                        total:total
                       offset:0
                   completion:completion];
}

- (void)sendChunkFromHandle:(NSFileHandle *)handle
                  uploadURL:(NSString *)uploadURL
                   filePath:(NSString *)filePath
                      token:(NSString *)token
                      total:(unsigned long long)total
                     offset:(unsigned long long)offset
                 completion:(void (^)(NSDictionary *, NSError *))completion {
    const NSUInteger chunkSize = 10 * 1024 * 1024;
    unsigned long long remaining = total - offset;
    NSUInteger length = (NSUInteger)MIN((unsigned long long)chunkSize, remaining);
    NSData *chunk = [handle readDataOfLength:length];
    if (chunk.length == 0) {
        [handle closeFile];
        if (completion) completion(nil, BDError(localize(@"OneDrive upload ended unexpectedly.", nil), 31));
        return;
    }
    unsigned long long end = offset + chunk.length - 1;
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:uploadURL] method:@"PUT"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"bytes %llu-%llu/%llu", offset, end, total] forHTTPHeaderField:@"Content-Range"];
    request.HTTPBody = chunk;
    [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            [handle closeFile];
            if (completion) completion(nil, error);
            return;
        }
        NSInteger status = response.statusCode;
        if (status == 200 || status == 201) {
            [handle closeFile];
            id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (completion) completion([json isKindOfClass:[NSDictionary class]] ? json : @{@"name": filePath.lastPathComponent}, nil);
            return;
        }
        if (status == 202 || status == 204) {
            [self sendChunkFromHandle:handle uploadURL:uploadURL filePath:filePath token:token total:total offset:offset + chunk.length completion:completion];
            return;
        }
        [handle closeFile];
        if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"OneDrive upload failed.", nil)]);
    }];
}

- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/v1.0/me/drive/root:/%@:/children?$select=id,name,size,createdDateTime,file&$top=999", self.folderPath];
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"GET", token, nil);
            [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(nil, requestError);
                    return;
                }
                if (![BackupHTTP isSuccess:response]) {
                    if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not list OneDrive backups.", nil)]);
                    return;
                }
                NSArray *values = [json isKindOfClass:[NSDictionary class]] ? json[@"value"] : nil;
                NSMutableArray *items = [NSMutableArray array];
                for (NSDictionary *file in values ?: @[]) {
                    if (![file isKindOfClass:[NSDictionary class]]) continue;
                    NSString *name = BDString(file[@"name"]);
                    if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
                    [items addObject:@{
                        @"name": name,
                        @"size": file[@"size"] ?: @0,
                        @"modified": file[@"createdDateTime"] ?: @"",
                        @"id": file[@"id"] ?: @"",
                    }];
                }
                if (completion) completion(items, nil);
            }];
        }];
    }];
}

- (void)downloadFileNamed:(NSString *)name toPath:(NSString *)path completion:(void (^)(NSError *))completion {
    [self listWithCompletion:^(NSArray<NSDictionary *> *items, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSString *fileID = nil;
        for (NSDictionary *item in items) {
            if ([item[@"name"] isEqualToString:name]) { fileID = BDString(item[@"id"]); break; }
        }
        if (fileID.length == 0) {
            if (completion) completion(BDError(localize(@"Backup not found in OneDrive.", nil), 32));
            return;
        }
        [self withToken:^(NSString *token, NSError *tokenError) {
            if (tokenError) {
                if (completion) completion(tokenError);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/v1.0/me/drive/items/%@/content", [BackupHTTP urlEncode:fileID]];
            NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:urlString] method:@"GET"];
            [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
            [BackupHTTP downloadRequest:request toPath:path completion:completion];
        }];
    }];
}

- (void)deleteFileNamed:(NSString *)name completion:(void (^)(NSError *))completion {
    [self listWithCompletion:^(NSArray<NSDictionary *> *items, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSString *fileID = nil;
        for (NSDictionary *item in items) {
            if ([item[@"name"] isEqualToString:name]) { fileID = BDString(item[@"id"]); break; }
        }
        if (fileID.length == 0) {
            if (completion) completion(nil);
            return;
        }
        [self withToken:^(NSString *token, NSError *tokenError) {
            if (tokenError) {
                if (completion) completion(tokenError);
                return;
            }
            NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/v1.0/me/drive/items/%@", [BackupHTTP urlEncode:fileID]];
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:urlString], @"DELETE", token, nil);
            [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(requestError);
                } else if (![BackupHTTP isSuccess:response] && response.statusCode != 404) {
                    if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not delete the OneDrive backup.", nil)]);
                } else {
                    if (completion) completion(nil);
                }
            }];
        }];
    }];
}

@end

#pragma mark - Dropbox

@implementation BackupDropboxDestination

- (NSString *)identifier { return @"dropbox"; }
- (NSString *)displayName { return @"Dropbox"; }
- (BOOL)enabled { return BDDestinationEnabled(self.identifier); }
- (void)setEnabled:(BOOL)enabled { BDSetDestinationEnabled(self.identifier, enabled); }
- (BOOL)configured { return [BackupOAuth.shared isAuthorizedForProvider:BackupOAuthProviderDropbox]; }
- (NSString *)detailText {
    if (![BackupConfig dropboxConfigured]) return localize(@"Not available in this build", nil);
    return self.configured ? localize(@"Connected", nil) : localize(@"Not connected", nil);
}

- (void)withToken:(void (^)(NSString *, NSError *))completion {
    [BackupOAuth.shared accessTokenForProvider:BackupOAuthProviderDropbox completion:completion];
}

- (NSString *)remotePathForName:(NSString *)name {
    return [NSString stringWithFormat:@"/%@/%@", [BackupConfig remoteFolderName], name];
}

- (void)ensureFolderWithCompletion:(void (^)(NSError *))completion {
    [self withToken:^(NSString *token, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:@"https://api.dropboxapi.com/2/files/create_folder_v2"], @"POST", token, @{@"path": [NSString stringWithFormat:@"/%@", [BackupConfig remoteFolderName]], @"autorename": @NO});
        [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
            if (requestError) {
                if (completion) completion(requestError);
                return;
            }
            if ([BackupHTTP isSuccess:response] || response.statusCode == 409) {
                if (completion) completion(nil);
            } else {
                if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not create the Dropbox folder.", nil)]);
            }
        }];
    }];
}

- (void)uploadFileAtPath:(NSString *)path record:(BackupRecord *)record completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
            if (size <= 140ULL * 1024 * 1024) {
                [self simpleUploadFileAtPath:path record:record token:token completion:completion];
            } else {
                [self sessionUploadFileAtPath:path record:record token:token completion:completion];
            }
        }];
    }];
}

- (void)simpleUploadFileAtPath:(NSString *)path record:(BackupRecord *)record token:(NSString *)token completion:(void (^)(NSDictionary *, NSError *))completion {
    NSDictionary *arg = @{@"path": [self remotePathForName:record.fileName], @"mode": @"overwrite", @"autorename": @YES, @"mute": @YES};
    NSData *argData = [NSJSONSerialization dataWithJSONObject:arg options:0 error:nil];
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload"] method:@"POST"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:[[NSString alloc] initWithData:argData encoding:NSUTF8StringEncoding] forHTTPHeaderField:@"Dropbox-API-Arg"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [BackupHTTP uploadRequest:request fromFile:path completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
        } else if (![BackupHTTP isSuccess:response]) {
            if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Dropbox upload failed.", nil)]);
        } else {
            id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (completion) completion([json isKindOfClass:[NSDictionary class]] ? json : @{@"name": record.fileName}, nil);
        }
    }];
}

- (void)sessionUploadFileAtPath:(NSString *)path record:(BackupRecord *)record token:(NSString *)token completion:(void (^)(NSDictionary *, NSError *))completion {
    NSMutableURLRequest *start = [BackupHTTP requestWithURL:[NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload_session/start"] method:@"POST"];
    [start setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [start setValue:@"{\"close\":false}" forHTTPHeaderField:@"Dropbox-API-Arg"];
    [start setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    start.HTTPBody = [NSData data];
    [BackupHTTP dataRequest:start completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *sessionID = [json isKindOfClass:[NSDictionary class]] ? BDString(json[@"session_id"]) : nil;
        if (![BackupHTTP isSuccess:response] || sessionID.length == 0) {
            if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not start the Dropbox upload.", nil)]);
            return;
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        unsigned long long total = [attrs[NSFileSize] unsignedLongLongValue];
        [self sendDropboxChunkFromHandle:handle sessionID:sessionID token:token offset:0 total:total commitPath:[self remotePathForName:record.fileName] completion:completion];
    }];
}

- (void)sendDropboxChunkFromHandle:(NSFileHandle *)handle
                         sessionID:(NSString *)sessionID
                             token:(NSString *)token
                            offset:(unsigned long long)offset
                             total:(unsigned long long)total
                        commitPath:(NSString *)commitPath
                        completion:(void (^)(NSDictionary *, NSError *))completion {
    const NSUInteger chunkSize = 8 * 1024 * 1024;
    unsigned long long remaining = total - offset;
    NSUInteger length = (NSUInteger)MIN((unsigned long long)chunkSize, remaining);
    NSData *chunk = [handle readDataOfLength:length];
    if (chunk.length == 0) {
        [handle closeFile];
        if (completion) completion(nil, BDError(localize(@"Dropbox upload ended unexpectedly.", nil), 40));
        return;
    }
    BOOL last = (offset + chunk.length >= total);
    NSDictionary *arg;
    NSString *endpoint;
    if (last) {
        endpoint = @"https://content.dropboxapi.com/2/files/upload_session/finish";
        arg = @{
            @"cursor": @{@"session_id": sessionID, @"offset": @(offset)},
            @"commit": @{@"path": commitPath, @"mode": @"overwrite", @"autorename": @YES, @"mute": @YES},
        };
    } else {
        endpoint = @"https://content.dropboxapi.com/2/files/upload_session/append_v2";
        arg = @{@"cursor": @{@"session_id": sessionID, @"offset": @(offset)}, @"close": @NO};
    }
    NSData *argData = [NSJSONSerialization dataWithJSONObject:arg options:0 error:nil];
    NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:endpoint] method:@"POST"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:[[NSString alloc] initWithData:argData encoding:NSUTF8StringEncoding] forHTTPHeaderField:@"Dropbox-API-Arg"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = chunk;
    [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error) {
            [handle closeFile];
            if (completion) completion(nil, error);
            return;
        }
        if (![BackupHTTP isSuccess:response]) {
            [handle closeFile];
            if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Dropbox upload failed.", nil)]);
            return;
        }
        if (last) {
            [handle closeFile];
            id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (completion) completion([json isKindOfClass:[NSDictionary class]] ? json : @{@"name": commitPath.lastPathComponent}, nil);
        } else {
            [self sendDropboxChunkFromHandle:handle sessionID:sessionID token:token offset:offset + chunk.length total:total commitPath:commitPath completion:completion];
        }
    }];
}

- (void)listWithCompletion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    [self ensureFolderWithCompletion:^(NSError *folderError) {
        if (folderError) {
            if (completion) completion(nil, folderError);
            return;
        }
        [self withToken:^(NSString *token, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:@"https://api.dropboxapi.com/2/files/list_folder"], @"POST", token, @{@"path": [NSString stringWithFormat:@"/%@", [BackupConfig remoteFolderName]], @"limit": @2000});
            [BackupHTTP jsonRequest:request completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
                if (requestError) {
                    if (completion) completion(nil, requestError);
                    return;
                }
                if (![BackupHTTP isSuccess:response]) {
                    if (completion) completion(nil, [BackupHTTP errorFromData:data response:response fallback:localize(@"Could not list Dropbox backups.", nil)]);
                    return;
                }
                NSArray *entries = [json isKindOfClass:[NSDictionary class]] ? json[@"entries"] : nil;
                NSMutableArray *items = [NSMutableArray array];
                for (NSDictionary *entry in entries ?: @[]) {
                    if (![entry isKindOfClass:[NSDictionary class]]) continue;
                    NSString *name = BDString(entry[@"name"]);
                    if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
                    [items addObject:@{
                        @"name": name,
                        @"size": entry[@"size"] ?: @0,
                        @"modified": entry[@"server_modified"] ?: @"",
                        @"path": entry[@"path_lower"] ?: @"",
                    }];
                }
                if (completion) completion(items, nil);
            }];
        }];
    }];
}

- (void)downloadFileNamed:(NSString *)name toPath:(NSString *)path completion:(void (^)(NSError *))completion {
    [self withToken:^(NSString *token, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSDictionary *arg = @{@"path": [self remotePathForName:name]};
        NSData *argData = [NSJSONSerialization dataWithJSONObject:arg options:0 error:nil];
        NSMutableURLRequest *request = [BackupHTTP requestWithURL:[NSURL URLWithString:@"https://content.dropboxapi.com/2/files/download"] method:@"POST"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        [request setValue:[[NSString alloc] initWithData:argData encoding:NSUTF8StringEncoding] forHTTPHeaderField:@"Dropbox-API-Arg"];
        [BackupHTTP downloadRequest:request toPath:path completion:completion];
    }];
}

- (void)deleteFileNamed:(NSString *)name completion:(void (^)(NSError *))completion {
    [self withToken:^(NSString *token, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        NSMutableURLRequest *request = BDJSONRequest([NSURL URLWithString:@"https://api.dropboxapi.com/2/files/delete_v2"], @"POST", token, @{@"path": [self remotePathForName:name]});
        [BackupHTTP dataRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *requestError) {
            if (requestError) {
                if (completion) completion(requestError);
                return;
            }
            if ([BackupHTTP isSuccess:response] || response.statusCode == 404) {
                if (completion) completion(nil);
                return;
            }
            // Dropbox reports an already-deleted path as 409 with
            // error_summary "path_lookup/not_found/..."; that is success here.
            id json = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSString *summary = [json isKindOfClass:[NSDictionary class]] ? json[@"error_summary"] : nil;
            if ([summary isKindOfClass:[NSString class]] && [summary containsString:@"not_found"]) {
                if (completion) completion(nil);
                return;
            }
            if (completion) completion([BackupHTTP errorFromData:data response:response fallback:localize(@"Could not delete the Dropbox backup.", nil)]);
        }];
    }];
}

@end
